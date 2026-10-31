/**
 * v1.66-social (D198, CONVENTIONS §10.61.1): the content of the personal-data export «تنزيل بياناتي» (GDPR Art. 15
 * access and Art. 20 portability, CCPA/CPRA right to know). Shared by the API job and `privacy-admin export`; no Nest.
 *
 * What goes in: the person's own data, machine-readable (`data/*.json`, UTF-8, BigInt amounts as strings, times in
 * ISO 8601 UTC), a README in Arabic and English, and the files of their own recharge-agent application (KYC). Media of
 * posts, reels and stories are listed with their public links (the same URLs the app shows).
 *
 * What NEVER goes in (§10.61.1, tested): another person's private data (counterparties appear as their PUBLIC
 * username only, or «deleted user»; received messages only as the person saw them), the password hash, refresh-token
 * hashes, verification tokens, push tokens, TOTP secrets and recovery codes, admin notes, payment-provider ids and any
 * internal fraud or risk signal (fraud flags, early-fraud warnings, disputes, freezes, cases).
 */
import { createHash } from 'node:crypto';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import type { ObjectStorage } from '../media/object-storage.js';
import { ZipWriter } from './zip.js';

type Db = Prisma.TransactionClient | PrismaClient;

/** At most this many rows per section (the manifest says when a section was cut). */
export const SECTION_ROW_LIMIT = 50_000;
/** A KYC picture larger than this is left out (the manifest says so). */
const MAX_FILE_BYTES = 8 * 1024 * 1024;

/** The audit actions that are the person's own sign-in history (time and IP only — never the metadata). */
const LOGIN_HISTORY_ACTIONS = [
  'auth.login.success',
  'auth.login.failure',
  'auth.logout',
  'auth.password.reset',
  'auth.email.verified',
  'auth.session.revoke',
] as const;

export const EXPORT_SECTIONS = [
  'profile',
  'settings',
  'posts',
  'stories',
  'comments',
  'messages',
  'follows',
  'blocks',
  'coins',
  'cherries',
  'levels',
  'gifts',
  'withdrawals',
  'topups',
  'recharge_agent',
  // v1.70-social (D206): the «افتح وكالة» applications (the person's own KYC) and their pictures.
  'agency_applications',
  'consents',
  'devices',
] as const;
export type ExportSection = (typeof EXPORT_SECTIONS)[number];

export interface ExportResult {
  readonly zip: Buffer;
  readonly sha256: string;
  readonly counts: Readonly<Record<ExportSection, number>>;
  readonly files: number;
}

const iso = (d: Date | null | undefined): string | null => (d ? d.toISOString() : null);
const str = (v: bigint | number | null | undefined): string | null =>
  v === null || v === undefined ? null : String(v);

/** A counterparty as the person may see them: the public username, or null with `deleted: true`. */
interface PublicRef {
  username: string | null;
  deleted: boolean;
}

async function publicRefs(db: Db, ids: Iterable<string>): Promise<Map<string, PublicRef>> {
  const unique = [...new Set(ids)];
  const out = new Map<string, PublicRef>();
  for (let i = 0; i < unique.length; i += 1000) {
    const rows = await db.user.findMany({
      where: { id: { in: unique.slice(i, i + 1000) } },
      select: { id: true, status: true, profile: { select: { username: true } } },
    });
    for (const r of rows) {
      const deleted = r.status === 'DELETED';
      out.set(r.id, { username: deleted ? null : (r.profile?.username ?? null), deleted });
    }
  }
  return out;
}

const refOf = (refs: Map<string, PublicRef>, id: string | null | undefined): PublicRef =>
  (id ? refs.get(id) : undefined) ?? { username: null, deleted: true };

/** The README (Arabic first, then English) — what each file holds and what is not included. */
export function exportReadme(generatedAt: Date, supportEmail: string): string {
  const at = generatedAt.toISOString();
  return [
    'كابسو لايف — نسخة من بياناتك',
    '================================',
    `أُنشئت في: ${at} (UTC)`,
    '',
    'هذا الملف يحوي البيانات الشخصية المرتبطة بحسابك بصيغة JSON يمكن قراءتها آلياً ونقلها إلى خدمة أخرى.',
    'المجلد data/ فيه ملف لكل قسم: الملف الشخصي والإعدادات، المنشورات والريلز والقصص (مع روابط الوسائط)، التعليقات،',
    'الرسائل التي أرسلتها والتي وصلتك (كما رأيتها)، المتابعات والحظر، سجلات العملات والكرز والمستويات، الهدايا المرسلة',
    'والمستلمة (الطرف الآخر باسم المستخدم العام فقط)، طلبات السحب (بيانات الدفع مخفية جزئياً)، طلب وكيل الشحن',
    '(بياناتك أنت وصورك في المجلد files/)، الموافقات على الشروط والخصوصية، وسجل الأجهزة وتسجيل الدخول.',
    'لا يحوي هذا الملف كلمة المرور أو أي رموز سرية، ولا بيانات خاصة لأشخاص آخرين، ولا مؤشرات داخلية لمكافحة الاحتيال.',
    'الملف manifest.json يذكر عدد السجلات في كل قسم.',
    `للاستفسار أو لتصحيح بياناتك: ${supportEmail}`,
    '',
    'Kabso Live — a copy of your data',
    '================================',
    `Generated: ${at} (UTC)`,
    '',
    'This archive holds the personal data linked to your account as machine-readable JSON you can move to another',
    'service. The data/ folder has one file per section: profile and settings; posts, reels and stories (with links to',
    'their media); comments; messages you sent and received (as you saw them); follows and blocks; coin, cherry and level',
    'ledgers; gifts sent and received (the other person by public username only); withdrawals (payout details partly',
    'masked); your recharge-agent application (your own data, pictures in files/); your acceptances of the terms and the',
    'privacy policy; and the device and sign-in history we keep.',
    "It does not contain your password or any secret token, other people's private data, or internal fraud signals.",
    'manifest.json lists how many records each section has. Amounts are strings (exact integers); times are UTC.',
    `Questions, or to correct your data: ${supportEmail}`,
    '',
  ].join('\n');
}

export interface BuildExportOptions {
  readonly userId: string;
  readonly now: Date;
  readonly mediaBaseUrl: string;
  readonly supportEmail: string;
  /** Reads the KYC pictures; null = leave them out (listed as not included). */
  readonly storage: ObjectStorage | null;
}

export const exportObjectKey = (userId: string, exportId: string) =>
  `private/data-exports/${userId}/${exportId}.zip`;
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');

/** The time from which a new export may be asked for (null: now). FAILED jobs do not count. */
export async function nextExportAllowedAt(
  db: Db,
  userId: string,
  minIntervalHours: number,
): Promise<Date | null> {
  const last = await db.dataExport.findFirst({
    where: { userId, status: { not: 'FAILED' } },
    orderBy: { requestedAt: 'desc' },
    select: { requestedAt: true, status: true },
  });
  if (!last) return null;
  return new Date(last.requestedAt.getTime() + minIntervalHours * 3_600_000);
}

/** Builds the export ZIP for one account (read-only). */
export async function buildDataExport(db: Db, o: BuildExportOptions): Promise<ExportResult> {
  const u = o.userId;
  const L = SECTION_ROW_LIMIT;
  const mediaUrl = (key: string | null | undefined) => (key ? `${o.mediaBaseUrl}/${key}` : null);
  const cut: string[] = [];
  const limited = <T>(section: string, rows: T[]): T[] => {
    if (rows.length > L) {
      cut.push(section);
      return rows.slice(0, L);
    }
    return rows;
  };

  const user = await db.user.findUniqueOrThrow({
    where: { id: u },
    select: {
      id: true,
      email: true,
      emailVerifiedAt: true,
      status: true,
      createdAt: true,
      lastActiveAt: true,
      profile: {
        select: {
          username: true,
          displayName: true,
          bio: true,
          avatarUrl: true,
          locale: true,
          countryCode: true,
          gender: true,
          showGender: true,
          category: true,
          premiumTier: true,
          createdAt: true,
          updatedAt: true,
        },
      },
      settings: { select: { isPrivate: true } },
      privacySettings: {
        select: {
          whoCanMention: true,
          defaultWhoCanComment: true,
          showActivityStatus: true,
          whoCanMessage: true,
        },
      },
      notificationPrefs: {
        select: {
          likes: true,
          comments: true,
          mentions: true,
          follows: true,
          reposts: true,
          lives: true,
          messages: true,
        },
      },
      wallet: { select: { coins: true } },
      cherryWallet: { select: { cherries: true } },
    },
  });
  const links = await db.userProfileLink.findMany({
    where: { userId: u },
    orderBy: { position: 'asc' },
    select: { url: true, label: true, position: true },
  });
  const special = await db.specialUsername.findMany({
    where: { userId: u, status: 'ACTIVE' },
    select: { baseUsername: true },
  });

  const profile = {
    id: user.id,
    email: user.email,
    emailVerifiedAt: iso(user.emailVerifiedAt),
    status: user.status,
    createdAt: iso(user.createdAt),
    lastActiveAt: iso(user.lastActiveAt),
    username: user.profile?.username ?? null,
    baseUsername: special[0]?.baseUsername ?? null,
    displayName: user.profile?.displayName ?? null,
    bio: user.profile?.bio ?? null,
    avatarUrl: user.profile?.avatarUrl ?? null,
    locale: user.profile?.locale ?? null,
    countryCode: user.profile?.countryCode ?? null,
    gender: user.profile?.gender ?? null,
    showGender: user.profile?.showGender ?? null,
    category: user.profile?.category ?? null,
    premiumTier: user.profile?.premiumTier ?? null,
    links,
  };
  const settings = {
    privateAccount: user.settings?.isPrivate ?? false,
    privacy: user.privacySettings ?? null,
    notifications: user.notificationPrefs ?? null,
  };

  // -- Posts, reels, stories (own, not deleted) with their media links.
  const posts = limited(
    'posts',
    await db.post.findMany({
      where: { authorId: u, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: {
        id: true,
        text: true,
        format: true,
        location: true,
        status: true,
        publishAt: true,
        publishedAt: true,
        editedAt: true,
        createdAt: true,
        commentsEnabled: true,
        whoCanComment: true,
        hideLikeCount: true,
        likeCount: true,
        commentCount: true,
        repostCount: true,
        saveCount: true,
        viewCount: true,
        media: {
          orderBy: { position: 'asc' },
          select: {
            mediaAsset: {
              select: {
                kind: true,
                largeKey: true,
                posterKey: true,
                width: true,
                height: true,
                durationMs: true,
              },
            },
          },
        },
      },
    }),
  ).map((p) => ({
    id: p.id,
    format: p.format,
    text: p.text,
    location: p.location,
    status: p.status,
    scheduledFor: iso(p.publishAt),
    publishedAt: iso(p.publishedAt),
    editedAt: iso(p.editedAt),
    createdAt: iso(p.createdAt),
    commentsEnabled: p.commentsEnabled,
    whoCanComment: p.whoCanComment,
    hideLikeCount: p.hideLikeCount,
    counts: {
      likes: p.likeCount,
      comments: p.commentCount,
      reposts: p.repostCount,
      saves: p.saveCount,
      views: p.viewCount,
    },
    media: p.media.map((m) => ({
      kind: m.mediaAsset.kind,
      url: mediaUrl(m.mediaAsset.largeKey),
      posterUrl: mediaUrl(m.mediaAsset.posterKey),
      width: m.mediaAsset.width,
      height: m.mediaAsset.height,
      durationMs: m.mediaAsset.durationMs,
    })),
  }));
  const stories = limited(
    'stories',
    await db.story.findMany({
      where: { authorId: u, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: {
        id: true,
        text: true,
        viewCount: true,
        createdAt: true,
        expiresAt: true,
        removedAt: true,
        mediaAsset: { select: { kind: true, largeKey: true, posterKey: true, durationMs: true } },
      },
    }),
  ).map((s) => ({
    id: s.id,
    text: s.text,
    views: s.viewCount,
    createdAt: iso(s.createdAt),
    expiresAt: iso(s.expiresAt),
    removedByModeration: s.removedAt !== null,
    media: {
      kind: s.mediaAsset.kind,
      url: mediaUrl(s.mediaAsset.largeKey),
      posterUrl: mediaUrl(s.mediaAsset.posterKey),
      durationMs: s.mediaAsset.durationMs,
    },
  }));

  const comments = limited(
    'comments',
    await db.comment.findMany({
      where: { authorId: u, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: { id: true, postId: true, parentId: true, text: true, likeCount: true, createdAt: true },
    }),
  ).map((c) => ({
    id: c.id,
    postId: c.postId,
    replyTo: c.parentId,
    text: c.text,
    likes: c.likeCount,
    createdAt: iso(c.createdAt),
  }));

  // -- Direct messages (they expire 24 h after sending: only those still kept). Received ones as the person saw them.
  const dmRows = limited(
    'messages',
    await db.dmMessage.findMany({
      where: { OR: [{ senderId: u }, { recipientId: u }] },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: {
        id: true,
        conversationId: true,
        senderId: true,
        recipientId: true,
        kind: true,
        text: true,
        token: true,
        mediaId: true,
        asRequest: true,
        createdAt: true,
        expiresAt: true,
        gift: { select: { giftCode: true, quantity: true } },
      },
    }),
  );

  // -- Social graph.
  const following = limited(
    'follows',
    await db.follow.findMany({
      where: { followerId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: { followeeId: true, createdAt: true },
    }),
  );
  const followers = limited(
    'follows',
    await db.follow.findMany({
      where: { followeeId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: { followerId: true, createdAt: true },
    }),
  );
  const blocked = limited(
    'blocks',
    await db.userBlock.findMany({
      where: { blockerId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: { blockedId: true, createdAt: true },
    }),
  );
  const muted = limited(
    'blocks',
    await db.userMute.findMany({
      where: { muterId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: { mutedId: true, createdAt: true },
    }),
  );

  // -- Gifts sent and received (counterparties by public username only).
  const sent = limited(
    'gifts',
    await db.liveGift.findMany({
      where: { senderId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: {
        id: true,
        giftCode: true,
        quantity: true,
        source: true,
        totalCoins: true,
        coinsCharged: true,
        createdAt: true,
        recipients: { select: { userId: true, coins: true } },
      },
    }),
  );
  const received = limited(
    'gifts',
    await db.liveGiftRecipient.findMany({
      where: { userId: u },
      orderBy: { gift: { createdAt: 'asc' } },
      take: L + 1,
      select: {
        coins: true,
        gift: {
          select: { id: true, senderId: true, giftCode: true, quantity: true, source: true, createdAt: true },
        },
      },
    }),
  );

  const refs = await publicRefs(db, [
    ...dmRows.flatMap((m) => [m.senderId, m.recipientId]),
    ...following.map((f) => f.followeeId),
    ...followers.map((f) => f.followerId),
    ...blocked.map((b) => b.blockedId),
    ...muted.map((m) => m.mutedId),
    ...sent.flatMap((g) => g.recipients.map((r) => r.userId)),
    ...received.map((r) => r.gift.senderId),
  ]);
  const messages = dmRows.map((m) => {
    const mine = m.senderId === u;
    return {
      id: m.id,
      conversationId: m.conversationId,
      direction: mine ? 'sent' : 'received',
      with: refOf(refs, mine ? m.recipientId : m.senderId),
      kind: m.kind,
      text: m.text,
      emoji: m.kind === 'EMOJI' ? m.token : null,
      hasAttachment: m.mediaId !== null,
      gift: m.gift ? { code: m.gift.giftCode, quantity: m.gift.quantity } : null,
      asRequest: m.asRequest,
      createdAt: iso(m.createdAt),
      expiresAt: iso(m.expiresAt),
    };
  });
  const follows = {
    following: following.map((f) => ({ ...refOf(refs, f.followeeId), since: iso(f.createdAt) })),
    followers: followers.map((f) => ({ ...refOf(refs, f.followerId), since: iso(f.createdAt) })),
  };
  const blocks = {
    blocked: blocked.map((b) => ({ ...refOf(refs, b.blockedId), since: iso(b.createdAt) })),
    muted: muted.map((m) => ({ ...refOf(refs, m.mutedId), since: iso(m.createdAt) })),
  };
  const gifts = {
    sent: sent.map((g) => ({
      id: g.id,
      code: g.giftCode,
      quantity: g.quantity,
      source: g.source,
      totalCoins: str(g.totalCoins),
      coinsCharged: str(g.coinsCharged),
      at: iso(g.createdAt),
      to: g.recipients.map((r) => ({ ...refOf(refs, r.userId), coins: str(r.coins) })),
    })),
    received: received.map((r) => ({
      id: r.gift.id,
      code: r.gift.giftCode,
      quantity: r.gift.quantity,
      source: r.gift.source,
      coins: str(r.coins),
      at: iso(r.gift.createdAt),
      from: refOf(refs, r.gift.senderId),
    })),
  };

  // -- Ledgers (no internal fraud flags, no admin ids).
  const coins = {
    balance: str(user.wallet?.coins ?? 0n),
    ledger: limited(
      'coins',
      await db.walletLedgerEntry.findMany({
        where: { userId: u },
        orderBy: { createdAt: 'asc' },
        take: L + 1,
        select: { id: true, delta: true, balanceAfter: true, reason: true, createdAt: true },
      }),
    ).map((e) => ({
      id: e.id,
      delta: str(e.delta),
      balanceAfter: str(e.balanceAfter),
      reason: e.reason,
      at: iso(e.createdAt),
    })),
  };
  const cherries = {
    balance: str(user.cherryWallet?.cherries ?? 0n),
    ledger: limited(
      'cherries',
      await db.cherryLedgerEntry.findMany({
        where: { userId: u },
        orderBy: { createdAt: 'asc' },
        take: L + 1,
        select: { id: true, delta: true, balanceAfter: true, reason: true, createdAt: true },
      }),
    ).map((e) => ({
      id: e.id,
      delta: str(e.delta),
      balanceAfter: str(e.balanceAfter),
      reason: e.reason,
      at: iso(e.createdAt),
    })),
  };
  const levelStates = await db.userLevelState.findMany({
    where: { userId: u },
    select: {
      totalPoints: true,
      lifetimeEarnedPoints: true,
      currentLevel: true,
      category: { select: { code: true } },
    },
  });
  const pointRows = limited(
    'levels',
    await db.pointsLedgerEntry.findMany({
      where: { userId: u },
      orderBy: { createdAt: 'asc' },
      take: L + 1,
      select: {
        id: true,
        entryType: true,
        sourceType: true,
        pointsDelta: true,
        createdAt: true,
        category: { select: { code: true } },
      },
    }),
  );
  const levels = {
    current: levelStates.map((s) => ({
      category: s.category.code,
      level: s.currentLevel,
      points: str(s.totalPoints),
      lifetimePoints: str(s.lifetimeEarnedPoints),
    })),
    ledger: pointRows.map((e) => ({
      id: e.id,
      category: e.category.code,
      type: e.entryType,
      source: e.sourceType,
      points: str(e.pointsDelta),
      at: iso(e.createdAt),
    })),
  };

  // -- Withdrawals: payout details masked to the last 4 characters; no admin note.
  const withdrawals = (
    await db.cherryWithdrawal.findMany({
      where: { userId: u },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        cherries: true,
        amountMinor: true,
        currency: true,
        payoutDetails: true,
        status: true,
        createdAt: true,
        decidedAt: true,
      },
    })
  ).map((w) => ({
    id: w.id,
    cherries: str(w.cherries),
    amountMinor: str(w.amountMinor),
    currency: w.currency,
    payoutDetails: maskTail(w.payoutDetails),
    status: w.status,
    requestedAt: iso(w.createdAt),
    decidedAt: iso(w.decidedAt),
  }));

  // -- Website card top-ups (D190): the order, never Stripe ids, early-fraud warnings, disputes or freezes.
  const topups = (
    await db.topupOrder.findMany({
      where: { userId: u },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        coins: true,
        amountMinor: true,
        currency: true,
        status: true,
        paymentMethodType: true,
        createdAt: true,
        creditedAt: true,
        refundedMinor: true,
      },
    })
  ).map((t) => ({
    id: t.id,
    coins: str(t.coins),
    amountMinor: t.amountMinor,
    currency: t.currency,
    status: t.status,
    paymentMethod: t.paymentMethodType,
    createdAt: iso(t.createdAt),
    creditedAt: iso(t.creditedAt),
    refundedMinor: t.refundedMinor,
  }));

  // -- The recharge-agent application (the person's own KYC) and its pictures.
  const zip = new ZipWriter(o.now);
  let files = 0;
  const notIncluded: string[] = [];
  const applications = await db.rechargeAgentApplication.findMany({
    where: { userId: u },
    orderBy: { createdAt: 'asc' },
    select: {
      id: true,
      status: true,
      fullName: true,
      phone: true,
      photoKey: true,
      selfieKey: true,
      locations: true,
      paymentMethods: true,
      rejectReason: true,
      createdAt: true,
      decidedAt: true,
      purgedAt: true,
    },
  });
  const rechargeAgent = [];
  for (const a of applications) {
    const pictures: Record<string, string | null> = { photo: null, selfie: null };
    for (const [which, key] of [
      ['photo', a.photoKey],
      ['selfie', a.selfieKey],
    ] as const) {
      if (!key) continue;
      const bytes = o.storage ? await o.storage.get(key, MAX_FILE_BYTES).catch(() => null) : null;
      if (bytes) {
        const path = `files/recharge-agent/${a.id}/${which}.webp`;
        zip.add(path, bytes);
        pictures[which] = path;
        files++;
      } else {
        notIncluded.push(`recharge-agent ${a.id} ${which}`);
      }
    }
    rechargeAgent.push({
      id: a.id,
      status: a.status,
      fullName: a.fullName,
      phone: a.phone,
      locations: a.locations,
      paymentMethods: a.paymentMethods,
      rejectReason: a.rejectReason,
      submittedAt: iso(a.createdAt),
      decidedAt: iso(a.decidedAt),
      personalDataDeletedAt: iso(a.purgedAt),
      pictures,
    });
  }

  // -- v1.70-social (D206): the «افتح وكالة» applications and their pictures.
  const agencyApps = await db.agencyApplication.findMany({
    where: { userId: u },
    orderBy: { createdAt: 'asc' },
  });
  const agencyApplications = [];
  for (const a of agencyApps) {
    const pictures: Record<string, string | null> = { idCard: null, selfie: null };
    for (const [which, key] of [
      ['idCard', a.photoKey],
      ['selfie', a.selfieKey],
    ] as const) {
      if (!key) continue;
      const bytes = o.storage ? await o.storage.get(key, MAX_FILE_BYTES).catch(() => null) : null;
      if (bytes) {
        const path = `files/agency-application/${a.id}/${which}.webp`;
        zip.add(path, bytes);
        pictures[which] = path;
        files++;
      } else {
        notIncluded.push(`agency-application ${a.id} ${which}`);
      }
    }
    agencyApplications.push({
      id: a.id,
      agencyName: a.name,
      country: a.country,
      contactType: a.contactType,
      contactValue: a.contactValue,
      expectedHosts: a.expectedHosts,
      bio: a.bio,
      submittedAt: iso(a.createdAt),
      personalDataDeletedAt: iso(a.purgedAt),
      pictures,
    });
  }

  // -- Consents (D198), the top-up terms (D190) and the lucky gifts' 18+ statement (D132).
  const consents = {
    acceptances: (
      await db.userConsent.findMany({
        where: { userId: u },
        orderBy: { acceptedAt: 'asc' },
        select: {
          document: true,
          version: true,
          acceptedAt: true,
          method: true,
          ipTruncated: true,
          userAgent: true,
        },
      })
    ).map((c) => ({
      document: c.document,
      version: c.version,
      acceptedAt: iso(c.acceptedAt),
      method: c.method,
      ipTruncated: c.ipTruncated,
      userAgent: c.userAgent,
    })),
    topupTerms: (
      await db.topupTermsAcceptance.findMany({
        where: { userId: u },
        orderBy: { acceptedAt: 'asc' },
        select: { termsVersion: true, termsText: true, locale: true, acceptedAt: true },
      })
    ).map((t) => ({
      version: t.termsVersion,
      text: t.termsText,
      locale: t.locale,
      acceptedAt: iso(t.acceptedAt),
    })),
    luckyGiftAge18: iso(
      (await db.luckyGiftAgeConfirmation.findUnique({ where: { userId: u }, select: { confirmedAt: true } }))
        ?.confirmedAt,
    ),
  };

  // -- Devices and sign-in history (the person's own IPs; never a token or its hash).
  const devices = {
    sessions: (
      await db.session.findMany({
        where: { userId: u },
        orderBy: { createdAt: 'asc' },
        take: L,
        select: {
          deviceName: true,
          platform: true,
          appVersion: true,
          ip: true,
          userAgent: true,
          createdAt: true,
          lastUsedAt: true,
          expiresAt: true,
          revokedAt: true,
          revokedReason: true,
        },
      })
    ).map((s) => ({
      device: s.deviceName,
      platform: s.platform,
      appVersion: s.appVersion,
      ip: s.ip,
      userAgent: s.userAgent,
      signedInAt: iso(s.createdAt),
      lastUsedAt: iso(s.lastUsedAt),
      expiresAt: iso(s.expiresAt),
      signedOutAt: iso(s.revokedAt),
      signOutReason: s.revokedReason,
    })),
    pushDevices: (
      await db.deviceToken.findMany({
        where: { userId: u },
        select: { platform: true, appVersion: true, createdAt: true, lastSeenAt: true },
      })
    ).map((d) => ({
      platform: d.platform,
      appVersion: d.appVersion,
      since: iso(d.createdAt),
      lastSeenAt: iso(d.lastSeenAt),
    })),
    signInHistory: (
      await db.auditLog.findMany({
        where: {
          action: { in: [...LOGIN_HISTORY_ACTIONS] },
          OR: [{ actorUserId: u }, { targetType: 'user', targetId: u }],
        },
        orderBy: { createdAt: 'asc' },
        take: L,
        select: { action: true, ip: true, createdAt: true },
      })
    ).map((a) => ({ event: a.action.replace(/^auth\./, ''), ip: a.ip, at: iso(a.createdAt) })),
  };

  const sections: Record<ExportSection, unknown> = {
    profile,
    settings,
    posts,
    stories,
    comments,
    messages,
    follows,
    blocks,
    coins,
    cherries,
    levels,
    gifts,
    withdrawals,
    topups,
    recharge_agent: rechargeAgent,
    agency_applications: agencyApplications,
    consents,
    devices,
  };
  const counts = {
    profile: 1,
    settings: 1,
    posts: posts.length,
    stories: stories.length,
    comments: comments.length,
    messages: messages.length,
    follows: follows.following.length + follows.followers.length,
    blocks: blocks.blocked.length + blocks.muted.length,
    coins: coins.ledger.length,
    cherries: cherries.ledger.length,
    levels: levels.ledger.length,
    gifts: gifts.sent.length + gifts.received.length,
    withdrawals: withdrawals.length,
    topups: topups.length,
    recharge_agent: rechargeAgent.length,
    agency_applications: agencyApplications.length,
    consents: consents.acceptances.length + consents.topupTerms.length,
    devices: devices.sessions.length,
  } satisfies Record<ExportSection, number>;

  zip.add('README.txt', exportReadme(o.now, o.supportEmail));
  for (const name of EXPORT_SECTIONS)
    zip.add(`data/${name}.json`, `${JSON.stringify(sections[name], null, 2)}\n`);
  zip.add(
    'manifest.json',
    `${JSON.stringify(
      {
        format: 'kabso-data-export',
        formatVersion: 1,
        generatedAt: o.now.toISOString(),
        account: user.id,
        sections: counts,
        truncatedSections: [...new Set(cut)],
        rowLimitPerSection: L,
        filesIncluded: files,
        filesNotIncluded: notIncluded,
      },
      null,
      2,
    )}\n`,
  );
  const bytes = zip.finish();
  return { zip: bytes, sha256: createHash('sha256').update(bytes).digest('hex'), counts, files };
}

/** `…` + the last 4 characters (payout details); short values become `…`. */
export function maskTail(value: string): string {
  if (value.startsWith('…')) return value;
  const chars = [...value.trim()];
  return chars.length <= 4 ? '…' : `…${chars.slice(-4).join('')}`;
}
