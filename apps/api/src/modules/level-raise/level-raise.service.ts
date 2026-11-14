import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma, type LevelRaiseRequest, type LevelRaiseSourceApp } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminAuthService } from '../admin-panel/admin-auth.service.js';
import { can } from '../admin-panel/admin-permissions.js';
import { refused, viaOf } from '../admin-panel/admin-users.service.js';
import { loadCategory } from '../levels/level-catalog.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { MediaService } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import {
  DEFAULT_SETTINGS_DTO,
  appMath,
  evidenceDto,
  evidenceIn,
  proposalDto,
  settingsDto,
  settingsOf,
  settingsRowIn,
  sourceAppDto,
  sourceAppOption,
  type EvidenceDto,
  type ProposalDto,
  type RaiseSettingsDto,
  type SourceAppDto,
  type SourceAppOptionDto,
} from './level-raise-core.js';
import { approvalIssue, proposeLevel, type RaiseSettings } from './level-raise-math.js';
import { accountKey, exactApp, sourceAppKey, suggest } from './level-raise-names.js';

type Tx = Prisma.TransactionClient;

/** `LevelRaisePerson`. */
export interface PersonDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}

/** `LevelRaiseRequest`. */
export interface LevelRaiseRequestDto {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  via: 'app' | 'panel';
  supporter: PersonDto;
  requestedBy: PersonDto;
  sourceApp: SourceAppOptionDto | null;
  sourceAppName: string;
  sourceAccountId: string;
  sourceLevel: number;
  note: string | null;
  /** The video's evidence (kept after the video is deleted at the decision: `deletedAt`, `posterUrl` null). */
  video: {
    id: string;
    durationMs: number | null;
    width: number;
    height: number;
    byteSize: number;
    posterUrl: string | null;
    deletedAt: string | null;
  };
  /** «سبق رفض طلب بنفس الحساب»: the latest REJECTED request for the same source account when this one was made. */
  previousRejection: {
    id: string;
    createdAt: string;
    decidedAt: string | null;
    rejectReason: string | null;
    requestedBy: PersonDto;
  } | null;
  createdAt: string;
  decidedAt: string | null;
  decidedBy: PersonDto | null;
  rejectReason: string | null;
  proposedLevel: number | null;
  approvedLevel: number | null;
  levelBefore: number | null;
  levelAfter: number | null;
}

/** `LevelRaiseRequestDetail`: the request, the supporter's evidence now and the proposal with its reasoning. */
export interface LevelRaiseDetailDto {
  request: LevelRaiseRequestDto;
  /** PENDING: computed now; decided: as it was at the decision. */
  proposal: ProposalDto | null;
  evidence: EvidenceDto;
}

const PERSON_SELECT = {
  id: true,
  profile: { select: { username: true, displayName: true, avatarUrl: true } },
} as const satisfies Prisma.UserSelect;

const REQUEST_INCLUDE = {
  supporter: { select: PERSON_SELECT },
  requestedBy: { select: PERSON_SELECT },
  decidedBy: { select: PERSON_SELECT },
  sourceApp: true,
  video: { select: { posterKey: true } },
  previousRejected: {
    select: {
      id: true,
      createdAt: true,
      decidedAt: true,
      rejectReason: true,
      requestedBy: { select: PERSON_SELECT },
    },
  },
} as const satisfies Prisma.LevelRaiseRequestInclude;
type RequestRow = Prisma.LevelRaiseRequestGetPayload<{ include: typeof REQUEST_INCLUDE }>;

function person(u: {
  id: string;
  profile: { username: string; displayName: string; avatarUrl: string | null } | null;
}) {
  return {
    id: u.id,
    username: u.profile?.username ?? '',
    displayName: u.profile?.displayName ?? '',
    avatarUrl: u.profile?.avatarUrl ?? null,
  };
}

const username = z
  .string()
  .trim()
  .min(1)
  .max(40)
  .transform((u) => u.replace(/^@/, '').toLowerCase());
const reason = z.string().trim().min(1).max(500);

export const createBody = z.strictObject({
  username,
  sourceApp: z
    .string()
    .trim()
    .regex(/^[A-Z0-9_]{2,32}$/),
  /** Required for the "other" app (its name as the staff member typed it); ignored otherwise. */
  sourceAppName: z.string().trim().min(1).max(60).optional(),
  sourceAccountId: z.string().trim().min(1).max(64),
  sourceLevel: z.number().int().min(1).max(999),
  videoId: z.uuid(),
  note: z.string().trim().max(500).optional(),
});
export type CreateBody = z.infer<typeof createBody>;

export const approveBody = z.strictObject({
  level: z.number().int().min(1).max(100),
  reason: z.string().trim().max(500).optional(),
});
export const rejectBody = z.strictObject({ reason });
export const statusQuery = z.strictObject({ status: z.enum(['PENDING', 'APPROVED', 'REJECTED']).optional() });
export const checkQuery = z.strictObject({ username });

const money = (max: number, decimals: number) =>
  z
    .number()
    .positive()
    .max(max)
    .refine((v) => Math.abs(v * 10 ** decimals - Math.round(v * 10 ** decimals)) < 1e-6, {
      message: `at most ${String(decimals)} decimals`,
    });
const xpPoint = z.strictObject({
  level: z.number().int().min(1).max(999),
  xp: z.number().int().min(0).max(1e15),
  confidence: z.enum(['CONFIRMED', 'ESTIMATE']),
});
const appFields = {
  nameAr: z.string().trim().min(1).max(60),
  nameEn: z.string().trim().min(1).max(60),
  mode: z.enum(['MONEY', 'FACTOR']),
  usdPerMillion: money(1_000_000, 2).nullable().optional(),
  coinsPerXp: money(1_000_000, 3).nullable().optional(),
  xpTable: z.array(xpPoint).max(200).optional(),
  factor: money(2, 3).nullable().optional(),
  confidence: z.enum(['CONFIRMED', 'ESTIMATE']),
  sourceNote: z.string().trim().max(1000).default(''),
  sourceUrl: z
    .url({ protocol: /^https$/ })
    .max(500)
    .nullable()
    .optional(),
  sourceDate: z.iso.date().nullable().optional(),
  enabled: z.boolean().optional(),
  sort: z.number().int().min(0).max(10_000).optional(),
  aliases: z.array(z.string().trim().min(1).max(60)).max(20).optional(),
  reason,
};
export const createAppBody = z.strictObject({
  code: z
    .string()
    .trim()
    .regex(/^[A-Z0-9_]{2,32}$/),
  ...appFields,
});
export const updateAppBody = z.strictObject(appFields);
type AppBody = z.infer<typeof updateAppBody>;

const level40 = z.number().int().min(0).max(40);
const bonus = z.number().int().min(0).max(10);
export const settingsBody = z
  .strictObject({
    minRechargeCoins: z.number().int().min(0).max(1e12).optional(),
    firstDays: z.number().int().min(1).max(90).optional(),
    anchorCoins: z.number().int().min(1).max(1e12).optional(),
    firstDaysBaseLevel: level40.optional(),
    totalBaseLevel: level40.optional(),
    levelsPerDoubling: z.number().min(0).max(20).optional(),
    supportBonusPer10Levels: bonus.optional(),
    supportBonusMax: bonus.optional(),
    charmBonusPer10Levels: bonus.optional(),
    charmBonusMax: bonus.optional(),
    belowTableExponent: z.number().min(1).max(10).optional(),
    reason,
  })
  .refine((v) => Object.keys(v).some((k) => k !== 'reason'), { message: 'at least one setting' });

function parse<T extends z.ZodType>(schema: T, raw: unknown): z.infer<T> {
  const r = schema.safeParse(raw ?? {});
  if (!r.success) throw AppException.validation(zodErrorToDetails(r.error));
  return r.data;
}

/** 400 VALIDATION_FAILED on one field. */
function invalid(field: string, issue = 'invalid_value'): AppException {
  return AppException.validation([{ field, issue }]);
}

/**
 * v1.89-social (D290, CONVENTIONS §10.103): level-raise requests «طلب رفع ليفيل». Staff (MODERATION / SUPPORT; the app
 * and the panel) send a supporter recruited from another app with a video of that app's profile; the OWNER sees the
 * proposal with its reasoning and approves (≤ the proposal, ≤ 40, ≥ the current level) or rejects. Approval raises
 * the SUPPORT level through the levels engine: one ADJUSTMENT ledger entry (`LevelProgressService.apply`, the same
 * path as the panel's points adjustment, D72) that brings the level points to the approved level's threshold.
 */
@Injectable()
export class LevelRaiseService {
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly progress: LevelProgressService,
    private readonly auth: AdminAuthService,
    private readonly clock: Clock,
  ) {}

  // ---- reading ---------------------------------------------------------------------------------------------------

  async settings(): Promise<RaiseSettings> {
    return settingsOf(await settingsRowIn(this.prisma));
  }

  /** The enabled apps for the form (the "other" app last). */
  async appOptions(): Promise<{ data: SourceAppOptionDto[] }> {
    const rows = await this.prisma.levelRaiseSourceApp.findMany({
      where: { enabled: true },
      orderBy: [{ isOther: 'asc' }, { sort: 'asc' }, { code: 'asc' }],
    });
    return { data: rows.map(sourceAppOption) };
  }

  /** The form's live check: who the username is, their recharge and levels, and whether a request is open. */
  async check(raw: unknown) {
    const q = parse(checkQuery, raw);
    const user = await this.findSupporter(this.prisma, q.username);
    if (!user)
      return { found: false, supporter: null, evidence: null, openRequest: false, staffAccount: false };
    const s = await this.settings();
    const staff = await this.isStaffAccount(user.id);
    const [evidence, open] = await Promise.all([
      evidenceIn(this.prisma, user.id, s),
      this.prisma.levelRaiseRequest.count({ where: { supporterUserId: user.id, status: 'PENDING' } }),
    ]);
    return {
      found: true,
      supporter: person(user),
      evidence: evidenceDto(evidence, s),
      openRequest: open > 0,
      staffAccount: staff,
    };
  }

  private async findSupporter(db: Tx | PrismaService, name: string) {
    if (!/^[a-z0-9._]{1,40}$/.test(name)) return null;
    const profile = await db.userProfile.findUnique({ where: { username: name }, select: { userId: true } });
    if (!profile) return null;
    return db.user.findFirst({
      where: { id: profile.userId, status: 'ACTIVE' },
      select: PERSON_SELECT,
    });
  }

  /** D283: a limited staff account (any panel role but OWNER) has no levels. */
  private async isStaffAccount(userId: string): Promise<boolean> {
    const roles = await this.auth.rolesOf(userId);
    return roles.some((r) => r !== 'OWNER');
  }

  private dto(row: RequestRow): LevelRaiseRequestDto {
    return {
      id: row.id,
      status: row.status,
      via: row.via === 'app' ? 'app' : 'panel',
      supporter: person(row.supporter),
      requestedBy: person(row.requestedBy),
      sourceApp: row.sourceApp ? sourceAppOption(row.sourceApp) : null,
      sourceAppName: row.sourceAppName,
      sourceAccountId: row.sourceAccountId,
      sourceLevel: row.sourceLevel,
      note: row.note,
      video: {
        id: row.videoAssetId,
        durationMs: row.videoDurationMs,
        width: row.videoWidth,
        height: row.videoHeight,
        byteSize: row.videoByteSize,
        posterUrl:
          row.videoDeletedAt === null && row.video?.posterKey
            ? `${this.media.publicBaseUrl ?? ''}/${row.video.posterKey}`
            : null,
        deletedAt: row.videoDeletedAt?.toISOString() ?? null,
      },
      previousRejection: row.previousRejected
        ? {
            id: row.previousRejected.id,
            createdAt: row.previousRejected.createdAt.toISOString(),
            decidedAt: row.previousRejected.decidedAt?.toISOString() ?? null,
            rejectReason: row.previousRejected.rejectReason,
            requestedBy: person(row.previousRejected.requestedBy),
          }
        : null,
      createdAt: row.createdAt.toISOString(),
      decidedAt: row.decidedAt?.toISOString() ?? null,
      decidedBy: row.decidedBy ? person(row.decidedBy) : null,
      rejectReason: row.rejectReason,
      proposedLevel: row.proposedLevel,
      approvedLevel: row.approvedLevel,
      levelBefore: row.levelBefore,
      levelAfter: row.levelAfter,
    };
  }

  private async row(id: string): Promise<RequestRow> {
    const row = await this.prisma.levelRaiseRequest.findUnique({ where: { id }, include: REQUEST_INCLUDE });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** The caller's own requests (app «طلباتي» and the panel for MODERATION / SUPPORT), newest first. */
  async mine(userId: string, raw: unknown): Promise<{ data: LevelRaiseRequestDto[] }> {
    const q = parse(statusQuery, raw);
    const rows = await this.prisma.levelRaiseRequest.findMany({
      where: { requestedById: userId, ...(q.status ? { status: q.status } : {}) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 200,
      include: REQUEST_INCLUDE,
    });
    return { data: rows.map((r) => this.dto(r)) };
  }

  /** The panel's list: every request for the OWNER (`levels.raise.decide`), one's own otherwise. */
  async list(ctx: AdminContext, raw: unknown): Promise<{ data: LevelRaiseRequestDto[] }> {
    if (!can(ctx.roles, 'levels.raise.decide')) return this.mine(ctx.userId, raw);
    const q = parse(statusQuery, raw);
    const rows = await this.prisma.levelRaiseRequest.findMany({
      where: q.status ? { status: q.status } : {},
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: 500,
      include: REQUEST_INCLUDE,
    });
    return { data: rows.map((r) => this.dto(r)) };
  }

  /** The proposal now for a PENDING request (inside `db`, so the approval uses exactly what it checks). */
  private async proposalNow(
    db: Tx | PrismaService,
    row: LevelRaiseRequest & { sourceApp: LevelRaiseSourceApp | null },
  ) {
    const settings = settingsOf(await settingsRowIn(db));
    const evidence = await evidenceIn(db, row.supporterUserId, settings);
    const appRow =
      row.sourceApp ?? (await db.levelRaiseSourceApp.findFirst({ where: { isOther: true } })) ?? null;
    if (!appRow) throw new Error('level_raise_source_apps has no "other" row');
    const category = await loadCategory(db, 'SUPPORT');
    const version = category.version;
    const math = appMath(appRow);
    const proposal = proposeLevel({
      app: math,
      sourceLevel: row.sourceLevel,
      ladder: version?.levels ?? [],
      multiplierScaled: version?.multiplier ?? 100_000n,
      totalRechargeCoins: evidence.totalRechargeCoins,
      firstDaysRechargeCoins: evidence.firstDaysRechargeCoins,
      currentSupportLevel: evidence.supportLevel,
      currentCharmLevel: evidence.charmLevel,
      settings,
    });
    return {
      settings,
      evidence,
      proposal,
      version,
      dto: proposalDto(
        proposal,
        { code: appRow.code, name: row.sourceAppName, math },
        row.sourceLevel,
        evidence,
        settings,
      ),
    };
  }

  /** The OWNER's review: the request, the evidence and the proposal with its reasoning. */
  async detail(id: string): Promise<LevelRaiseDetailDto> {
    const row = await this.row(id);
    if (row.status === 'PENDING') {
      const now = await this.proposalNow(this.prisma, row);
      return { request: this.dto(row), proposal: now.dto, evidence: evidenceDto(now.evidence, now.settings) };
    }
    const saved = row.proposal as unknown as ProposalDto | null;
    const settings = await this.settings();
    const evidence =
      saved?.evidence ?? evidenceDto(await evidenceIn(this.prisma, row.supporterUserId, settings), settings);
    return { request: this.dto(row), proposal: saved, evidence };
  }

  /** The stored video of a request (the panel plays it through the API: its CSP allows no storage origin). */
  async video(id: string): Promise<{ key: string; contentType: string; size: number }> {
    const row = await this.prisma.levelRaiseRequest.findUnique({
      where: { id },
      select: { videoDeletedAt: true, video: { select: { largeKey: true, byteSize: true } } },
    });
    // D290: the video is deleted after the decision («حُذف الفيديو بعد القرار»).
    if (!row || row.videoDeletedAt !== null || !row.video) throw new AppException(ErrorCode.NOT_FOUND);
    const key = row.video.largeKey;
    return {
      key,
      contentType: key.endsWith('.mov') ? 'video/quicktime' : 'video/mp4',
      size: row.video.byteSize,
    };
  }

  readVideoRange(key: string, offset: number, length: number) {
    return this.media.readRange(key, offset, length);
  }

  // ---- creating --------------------------------------------------------------------------------------------------

  /**
   * A staff member's request (`via` app or panel). Created even before the supporter reaches the recharge threshold
   * (the OWNER cannot approve until then); one PENDING request per supporter; the video is the caller's own unattached
   * `LEVEL_RAISE_VIDEO` (younger than 24 h) and is attached to this request only.
   */
  async create(ctx: AdminContext, raw: unknown): Promise<LevelRaiseRequestDto> {
    const body = parse(createBody, raw);
    const by = viaOf(ctx);
    // The canonical source first: a listed app by code, or "other" — whose typed name may be a listed app's spelling
    // (alias), then that app (§10.103.8).
    const chosen = await this.prisma.levelRaiseSourceApp.findUnique({ where: { code: body.sourceApp } });
    if (!chosen || !chosen.enabled) throw invalid('sourceApp');
    if (chosen.isOther && !body.sourceAppName) throw invalid('sourceAppName', 'required');
    const app =
      chosen.isOther && body.sourceAppName
        ? (exactApp(
            await this.prisma.levelRaiseSourceApp.findMany({ where: { enabled: true } }),
            body.sourceAppName,
          ) ?? chosen)
        : chosen;
    const appKey = sourceAppKey(app, body.sourceAppName ?? null);
    const accKey = accountKey(body.sourceAccountId);
    // Before anything else (owner): the same source account already PENDING / APPROVED → 409 LEVEL_RAISE_DUPLICATE.
    await this.refuseDuplicate(appKey, accKey);
    const previous = await this.prisma.levelRaiseRequest.findFirst({
      where: { sourceAppKey: appKey, sourceAccountKey: accKey, status: 'REJECTED' },
      orderBy: [{ decidedAt: 'desc' }, { id: 'desc' }],
      select: { id: true },
    });
    let id: string;
    try {
      id = await this.prisma.$transaction(async (tx) => {
        const supporter = await this.findSupporter(tx, body.username);
        if (!supporter) throw invalid('username', 'not_found');
        if (supporter.id === ctx.userId)
          throw refused('A staff member cannot ask for their own level', 'level_raise_self', 'rule');
        if (await this.isStaffAccount(supporter.id)) {
          throw refused('Kabso Team accounts have no levels (D283)', 'level_raise_staff_account', 'rule');
        }
        const open = await tx.levelRaiseRequest.count({
          where: { supporterUserId: supporter.id, status: 'PENDING' },
        });
        if (open > 0)
          throw refused('This supporter already has an open request', 'level_raise_open_exists', 'rule');
        const claimed = await this.media.claimAssetsIn(tx, ctx.userId, [body.videoId], 'LEVEL_RAISE_VIDEO');
        const video = claimed?.[0];
        if (!video) throw invalid('videoId');
        const created = await tx.levelRaiseRequest.create({
          data: {
            supporterUserId: supporter.id,
            requestedById: ctx.userId,
            via: by.via === 'app' ? 'app' : 'panel',
            sourceAppId: app.id,
            sourceAppName: app.isOther ? body.sourceAppName! : app.nameEn,
            sourceAccountId: body.sourceAccountId,
            sourceAppKey: appKey,
            sourceAccountKey: accKey,
            previousRejectedId: previous?.id ?? null,
            sourceLevel: body.sourceLevel,
            videoMediaId: video.id,
            videoAssetId: video.id,
            videoDurationMs: video.durationMs,
            videoByteSize: video.byteSize,
            videoWidth: video.width,
            videoHeight: video.height,
            note: body.note && body.note !== '' ? body.note : null,
          },
        });
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: AuditAction.LEVEL_RAISE_REQUEST,
            targetType: 'level_raise_request',
            targetId: created.id,
            metadata: {
              supporter: supporter.id,
              app: app.code,
              appName: created.sourceAppName,
              sourceAppKey: appKey,
              sourceAccountId: body.sourceAccountId,
              sourceLevel: body.sourceLevel,
              video: { mediaId: video.id, durationMs: video.durationMs, byteSize: video.byteSize },
              previousRejected: previous?.id ?? null,
              via: by.via,
            },
          },
        });
        return created.id;
      });
    } catch (err) {
      // A unique index lost a race: the same source account (another staff member's concurrent request) or a second
      // PENDING request for the supporter.
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        await this.refuseDuplicate(appKey, accKey);
        throw refused('This supporter already has an open request', 'level_raise_open_exists', 'rule');
      }
      throw err;
    }
    return this.dto(await this.row(id));
  }

  /** 409 LEVEL_RAISE_DUPLICATE with the existing request's status, date and staff member, when there is one. */
  private async refuseDuplicate(appKey: string, accKey: string): Promise<void> {
    const existing = await this.prisma.levelRaiseRequest.findFirst({
      where: { sourceAppKey: appKey, sourceAccountKey: accKey, status: { in: ['PENDING', 'APPROVED'] } },
      orderBy: [{ createdAt: 'desc' }],
      select: { status: true, createdAt: true, requestedBy: { select: PERSON_SELECT } },
    });
    if (!existing) return;
    throw new AppException(ErrorCode.LEVEL_RAISE_DUPLICATE, undefined, [
      { field: 'status', issue: existing.status },
      { field: 'createdAt', issue: existing.createdAt.toISOString() },
      {
        field: 'requestedBy',
        issue: person(existing.requestedBy).displayName || existing.requestedBy.profile?.username || '',
      },
    ]);
  }

  /**
   * «هل تقصد: …؟» — the listed apps (any spelling: names, code, aliases) and the names typed for "other" apps in earlier
   * requests (the first spelling of each), matching the typed text ignoring case, spaces and diacritics.
   */
  async suggest(raw: unknown) {
    const q = parse(z.strictObject({ q: z.string().max(60) }), raw);
    const apps = await this.prisma.levelRaiseSourceApp.findMany({
      where: { enabled: true },
      orderBy: [{ sort: 'asc' }, { code: 'asc' }],
    });
    const earlier = await this.prisma.$queryRaw<{ key: string; name: string; count: bigint }[]>`
      SELECT substr(source_app_key, 6) AS key,
             (array_agg(source_app_name ORDER BY created_at, id))[1] AS name,
             count(*)::bigint AS count
        FROM level_raise_requests
       WHERE source_app_key LIKE 'NAME:%'
       GROUP BY source_app_key
       ORDER BY count(*) DESC
       LIMIT 500`;
    const found = suggest(
      q.q,
      apps,
      earlier.map((e) => ({ key: e.key, name: e.name, count: Number(e.count) })),
    );
    return {
      data: found.map((f) =>
        f.kind === 'APP'
          ? { kind: 'APP' as const, app: sourceAppOption(f.app), name: null, count: null }
          : { kind: 'NAME' as const, app: null, name: f.name, count: f.count },
      ),
    };
  }

  /** The panel's raw video upload (no presigned PUT in the panel); ≤ 100 MiB, kept in memory once. */
  async uploadPanelVideo(ctx: AdminContext, body: unknown) {
    if (!Buffer.isBuffer(body)) throw AppException.validation([{ field: 'body', issue: 'required' }]);
    if (body.length > PANEL_VIDEO_MAX_BYTES)
      throw AppException.validation([{ field: 'body', issue: 'too_big' }]);
    const asset = await this.media.storeRawVideo(ctx.userId, body, 'LEVEL_RAISE_VIDEO');
    return { videoId: asset.id, durationMs: asset.durationMs ?? 0, width: asset.width, height: asset.height };
  }

  // ---- deciding --------------------------------------------------------------------------------------------------

  private async lockPending(tx: Tx, id: string) {
    const locked = await tx.$queryRaw<{ id: string }[]>`
      SELECT id FROM level_raise_requests WHERE id = ${id}::uuid FOR UPDATE`;
    if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await tx.levelRaiseRequest.findUniqueOrThrow({ where: { id }, include: { sourceApp: true } });
    if (row.status !== 'PENDING')
      throw refused('The request was already decided', 'level_raise_not_pending', 'rule');
    return row;
  }

  /**
   * Approves at `level` (the proposal or lower; never above 40, never below the current level). Refused until the
   * supporter's recharge reaches the threshold. Raises the SUPPORT level through the engine and notifies the staff
   * member and (when the level rose) the supporter, in the same transaction.
   */
  async approve(ctx: AdminContext, id: string, raw: unknown): Promise<LevelRaiseDetailDto> {
    const body = parse(approveBody, raw);
    const by = viaOf(ctx);
    await this.prisma.$transaction(async (tx) => {
      const row = await this.lockPending(tx, id);
      const now = await this.proposalNow(tx, row);
      if (!now.version)
        throw refused('The support levels are not published', 'level_raise_levels_unavailable', 'rule');
      if (!now.proposal.eligible) {
        throw refused('The supporter has not recharged enough yet', 'level_raise_not_eligible', 'rule');
      }
      const before = now.evidence.supportLevel;
      const issue = approvalIssue(body.level, now.proposal.proposedLevel, before);
      if (issue) throw refused(`Level ${String(body.level)} is not allowed`, issue, 'level');

      let ledgerEntryId: string | null = null;
      let after = before;
      if (body.level > before) {
        const category = await loadCategory(tx, 'SUPPORT', 'share');
        const target = category.version?.levels.find((l) => l.levelNumber === body.level);
        if (!target) throw refused('No such support level', 'level_raise_levels_unavailable', 'rule');
        const state = await tx.userLevelState.findUnique({
          where: { userId_categoryId: { userId: row.supporterUserId, categoryId: category.id } },
          select: { totalPoints: true, carriedPoints: true },
        });
        const have = (state?.totalPoints ?? 0n) + (state?.carriedPoints ?? 0n);
        const delta = target.requiredPoints - have;
        if (delta > 0n) {
          const result = await this.progress.apply(tx, category, {
            userId: row.supporterUserId,
            entryType: 'ADJUSTMENT',
            sourceType: 'ADMIN',
            pointsDelta: delta,
            idempotencyKey: `level-raise:${row.id}`,
            reason:
              `D290 level raise ${row.id} to level ${String(body.level)}${body.reason ? `: ${body.reason}` : ''}`.slice(
                0,
                500,
              ),
            createdById: ctx.userId,
          });
          if (result.kind !== 'applied') throw new Error('level raise entry not applied');
          ledgerEntryId = result.entry.id;
          after = result.state.currentLevel ?? before;
        }
      }
      const decidedAt = this.clock.now();
      await tx.levelRaiseRequest.update({
        where: { id: row.id },
        data: {
          status: 'APPROVED',
          decidedAt,
          decidedById: ctx.userId,
          proposedLevel: now.proposal.proposedLevel,
          approvedLevel: body.level,
          levelBefore: before,
          levelAfter: after,
          ledgerEntryId,
          proposal: now.dto as unknown as Prisma.InputJsonValue,
          // D290 (owner): the video goes after the decision; the evidence columns stay.
          videoDeletedAt: decidedAt,
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.LEVEL_RAISE_APPROVE,
          targetType: 'level_raise_request',
          targetId: row.id,
          metadata: {
            supporter: row.supporterUserId,
            approvedLevel: body.level,
            proposedLevel: now.proposal.proposedLevel,
            before,
            after,
            ledgerEntry: ledgerEntryId,
            totalRechargeCoins: Number(now.evidence.totalRechargeCoins),
            firstDaysRechargeCoins: Number(now.evidence.firstDaysRechargeCoins),
            reason: body.reason ?? null,
            video: videoEvidence(row, decidedAt),
            via: by.via,
          },
        },
      });
      await this.notifier.levelRaise(tx, {
        type: 'LEVEL_RAISE_APPROVED',
        recipientId: row.requestedById,
        requestId: row.id,
      });
      if (after > before) {
        await this.notifier.levelRaise(tx, {
          type: 'LEVEL_RAISED',
          recipientId: row.supporterUserId,
          requestId: row.id,
        });
      }
    });
    await this.media.purgeLevelRaiseVideos([id]);
    return this.detail(id);
  }

  /** Rejects with a reason (audited; the staff member is told; the supporter is not — owner default). */
  async reject(ctx: AdminContext, id: string, raw: unknown): Promise<LevelRaiseDetailDto> {
    const body = parse(rejectBody, raw);
    const by = viaOf(ctx);
    await this.prisma.$transaction(async (tx) => {
      const row = await this.lockPending(tx, id);
      const now = await this.proposalNow(tx, row);
      const decidedAt = this.clock.now();
      await tx.levelRaiseRequest.update({
        where: { id: row.id },
        data: {
          status: 'REJECTED',
          videoDeletedAt: decidedAt,
          decidedAt,
          decidedById: ctx.userId,
          rejectReason: body.reason,
          proposedLevel: now.proposal.proposedLevel,
          proposal: now.dto as unknown as Prisma.InputJsonValue,
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.LEVEL_RAISE_REJECT,
          targetType: 'level_raise_request',
          targetId: row.id,
          metadata: {
            supporter: row.supporterUserId,
            proposedLevel: now.proposal.proposedLevel,
            reason: body.reason,
            video: videoEvidence(row, decidedAt),
            via: by.via,
          },
        },
      });
      await this.notifier.levelRaise(tx, {
        type: 'LEVEL_RAISE_REJECTED',
        recipientId: row.requestedById,
        requestId: row.id,
      });
    });
    await this.media.purgeLevelRaiseVideos([id]);
    return this.detail(id);
  }

  // ---- the source-app data and the weights (OWNER) ---------------------------------------------------------------

  async apps(): Promise<{ data: SourceAppDto[] }> {
    const rows = await this.prisma.levelRaiseSourceApp.findMany({
      orderBy: [{ isOther: 'asc' }, { sort: 'asc' }, { code: 'asc' }],
    });
    return { data: rows.map(sourceAppDto) };
  }

  private appData(body: AppBody, isOther: boolean) {
    const usd = body.usdPerMillion ?? null;
    const perXp = body.coinsPerXp ?? null;
    const factor = body.factor ?? null;
    if (body.mode === 'MONEY') {
      if ((body.usdPerMillion ?? null) === null) throw invalid('usdPerMillion', 'required');
      if ((body.coinsPerXp ?? null) === null) throw invalid('coinsPerXp', 'required');
      if (!body.xpTable || body.xpTable.length === 0) throw invalid('xpTable', 'required');
    } else if ((body.factor ?? null) === null) {
      throw invalid('factor', 'required');
    }
    if (body.xpTable && new Set(body.xpTable.map((p) => p.level)).size !== body.xpTable.length) {
      throw invalid('xpTable', 'duplicate_level');
    }
    // CONFIRMED needs a cited source (the owner, or a page and its date).
    if (body.confidence === 'CONFIRMED' && body.sourceNote.trim() === '')
      throw invalid('sourceNote', 'required');
    if (isOther && (body.mode !== 'FACTOR' || body.enabled === false)) {
      throw refused('The default for other apps stays an enabled factor', 'level_raise_other_app', 'rule');
    }
    return {
      nameAr: body.nameAr,
      nameEn: body.nameEn,
      mode: body.mode,
      usdPerMillionCents: usd === null ? null : BigInt(Math.round(usd * 100)),
      coinsPerXpMilli: perXp === null ? null : BigInt(Math.round(perXp * 1000)),
      xpTable: (body.xpTable ?? []).sort((a, b) => a.level - b.level) as unknown as Prisma.InputJsonValue,
      factorMilli: factor === null ? null : Math.round(factor * 1000),
      confidence: body.confidence,
      sourceNote: body.sourceNote,
      sourceUrl: body.sourceUrl ?? null,
      sourceDate: body.sourceDate ? new Date(`${body.sourceDate}T00:00:00Z`) : null,
      ...(body.enabled !== undefined ? { enabled: body.enabled } : {}),
      ...(body.sort !== undefined ? { sort: body.sort } : {}),
      ...(body.aliases !== undefined ? { aliases: [...new Set(body.aliases)] } : {}),
    };
  }

  async createApp(ctx: AdminContext, raw: unknown): Promise<SourceAppDto> {
    const body = parse(createAppBody, raw);
    const by = viaOf(ctx);
    const data = this.appData(body, false);
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        const created = await tx.levelRaiseSourceApp.create({
          data: { ...data, code: body.code, updatedById: ctx.userId, updatedAt: this.clock.now() },
        });
        await this.auditApp(tx, by, AuditAction.LEVEL_RAISE_APP_CREATE, created, null, body.reason);
        return created;
      });
      return sourceAppDto(row);
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002')
        throw invalid('code', 'taken');
      throw err;
    }
  }

  async updateApp(ctx: AdminContext, id: string, raw: unknown): Promise<SourceAppDto> {
    const body = parse(updateAppBody, raw);
    const by = viaOf(ctx);
    const row = await this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string }[]>`
        SELECT id FROM level_raise_source_apps WHERE id = ${id}::uuid FOR UPDATE`;
      if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
      const before = await tx.levelRaiseSourceApp.findUniqueOrThrow({ where: { id } });
      const after = await tx.levelRaiseSourceApp.update({
        where: { id },
        data: { ...this.appData(body, before.isOther), updatedById: ctx.userId, updatedAt: this.clock.now() },
      });
      await this.auditApp(tx, by, AuditAction.LEVEL_RAISE_APP_UPDATE, after, before, body.reason);
      return after;
    });
    return sourceAppDto(row);
  }

  private async auditApp(
    tx: Tx,
    by: AdminVia,
    action: AuditAction,
    after: LevelRaiseSourceApp,
    before: LevelRaiseSourceApp | null,
    why: string,
  ) {
    const plain = (r: LevelRaiseSourceApp) => sourceAppDto(r) as unknown as Prisma.InputJsonValue;
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action,
        targetType: 'level_raise_source_app',
        targetId: after.id,
        metadata: { before: before ? plain(before) : null, after: plain(after), reason: why, via: by.via },
      },
    });
  }

  async settingsView(): Promise<{
    settings: RaiseSettingsDto;
    defaults: RaiseSettingsDto;
    updatedAt: string;
  }> {
    const row = await settingsRowIn(this.prisma);
    return {
      settings: settingsDto(settingsOf(row)),
      defaults: DEFAULT_SETTINGS_DTO,
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  async updateSettings(ctx: AdminContext, raw: unknown) {
    const body = parse(settingsBody, raw);
    const by = viaOf(ctx);
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT 1 FROM level_raise_settings WHERE id = 1 FOR UPDATE`;
      const before = settingsDto(settingsOf(await settingsRowIn(tx)));
      const after = await tx.levelRaiseSettings.update({
        where: { id: 1 },
        data: {
          ...(body.minRechargeCoins !== undefined ? { minRechargeCoins: BigInt(body.minRechargeCoins) } : {}),
          ...(body.firstDays !== undefined ? { firstDays: body.firstDays } : {}),
          ...(body.anchorCoins !== undefined ? { anchorCoins: BigInt(body.anchorCoins) } : {}),
          ...(body.firstDaysBaseLevel !== undefined ? { firstDaysBaseLevel: body.firstDaysBaseLevel } : {}),
          ...(body.totalBaseLevel !== undefined ? { totalBaseLevel: body.totalBaseLevel } : {}),
          ...(body.levelsPerDoubling !== undefined
            ? { levelsPerDoublingTenths: Math.round(body.levelsPerDoubling * 10) }
            : {}),
          ...(body.supportBonusPer10Levels !== undefined
            ? { supportBonusPer10: body.supportBonusPer10Levels }
            : {}),
          ...(body.supportBonusMax !== undefined ? { supportBonusMax: body.supportBonusMax } : {}),
          ...(body.charmBonusPer10Levels !== undefined
            ? { charmBonusPer10: body.charmBonusPer10Levels }
            : {}),
          ...(body.charmBonusMax !== undefined ? { charmBonusMax: body.charmBonusMax } : {}),
          ...(body.belowTableExponent !== undefined
            ? { belowTableExponentTenths: Math.round(body.belowTableExponent * 10) }
            : {}),
          updatedAt: this.clock.now(),
          updatedById: ctx.userId,
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.LEVEL_RAISE_SETTINGS_UPDATE,
          targetType: 'level_raise_settings',
          targetId: '1',
          metadata: {
            before: before as unknown as Prisma.InputJsonValue,
            after: settingsDto(settingsOf(after)) as unknown as Prisma.InputJsonValue,
            reason: body.reason,
            via: by.via,
          },
        },
      });
    });
    return this.settingsView();
  }
}

/** The panel's raw video upload limit (the bytes are held in memory once; the app's presigned upload allows 200 MiB). */
export const PANEL_VIDEO_MAX_BYTES = 100 * 1024 * 1024;

/** The video's evidence for the decision's audit row (the video itself is deleted after the decision). */
function videoEvidence(
  row: {
    videoAssetId: string;
    videoDurationMs: number | null;
    videoByteSize: number;
    videoWidth: number;
    videoHeight: number;
  },
  deletedAt: Date,
) {
  return {
    mediaId: row.videoAssetId,
    durationMs: row.videoDurationMs,
    byteSize: row.videoByteSize,
    width: row.videoWidth,
    height: row.videoHeight,
    // The media module keeps no checksum of an upload (the bytes go straight to storage): none to record.
    sha256: null,
    deletedAt: deletedAt.toISOString(),
  };
}
