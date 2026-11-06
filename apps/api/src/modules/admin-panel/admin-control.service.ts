import { randomInt } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import type { AccountRestrictionKind, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AuthService } from '../auth/auth.service.js';
import { PasswordHasher } from '../auth/password-hasher.service.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { LiveRoomsService } from '../live/live-rooms.service.js';
import { syncHostFrameIn } from '../economy/host-frames.js';
import { Notifier } from '../notifications/notifier.js';
import { activeLeaseOf, lockName, lockUser, nameInUse } from '../premium-usernames/premium-username-ops.js';
import { regularUsernameIssue } from '../premium-usernames/premium-username-rules.js';
import {
  AccountControlError,
  activeRestrictionsOf,
  adjustBalanceIn,
  liftIn,
  requirePasswordChangeIn,
  restrictIn,
  restrictionEnd,
  type AdjustCurrency,
  type RestrictionView,
} from '../users/account-control.js';
import { cancelDeletionIn, requestDeletionIn } from '../users/account-deletion.js';
import { containsReservedTerm } from '../users/confusables.js';
import { activeSpecialOf, specialHolderOf } from '../users/special-usernames.js';
import { isReservedUsername } from '../users/username.js';
import { dayStart } from '../recharge/recharge-rules.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import type { ContentType } from './admin-control.schemas.js';
import { isPanelRole } from './admin-permissions.js';
import { refused, viaOf } from './admin-users.service.js';

type Tx = Prisma.TransactionClient;

/** «a***@example.com»: what the audit rows and the panel keep of an address. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  return `${email.slice(0, 1)}***${email.slice(at)}`;
}

/** No 0/O, 1/l/I: read aloud or typed from a screen without mistakes. */
const TEMP_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

/** A temporary password: 4 groups of 4 (≈ 91 bits), e.g. `Kb7m-Qx4p-Zt9w-Hn3r`. */
export function temporaryPassword(): string {
  const groups: string[] = [];
  for (let g = 0; g < 4; g++) {
    let part = '';
    for (let i = 0; i < 4; i++) part += TEMP_ALPHABET[randomInt(TEMP_ALPHABET.length)];
    groups.push(part);
  }
  return groups.join('-');
}

function restrictionDto(r: RestrictionView, now: Date) {
  const active = r.liftedAt === null && r.startsAt <= now && r.endsAt > now;
  return {
    id: r.id,
    kind: r.kind,
    reason: r.reason,
    startsAt: r.startsAt.toISOString(),
    endsAt: r.endsAt.toISOString(),
    via: r.via,
    active,
    liftedAt: r.liftedAt?.toISOString() ?? null,
    liftReason: r.liftReason,
    createdAt: r.createdAt.toISOString(),
  };
}

function controlError(err: unknown): never {
  if (err instanceof AccountControlError) {
    if (err.issue === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
    throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, err.message, [{ field: '', issue: err.issue }]);
  }
  throw err;
}

/**
 * The account controls of the admin panel «تحكم كامل» (v1.72-social, D208, CONVENTIONS §10.67): lock / unlock,
 * restrictions, the password (reset link, temporary password, forced change), the profile, the email, content,
 * balance adjustments and the account's deletion (D193). Every action is capability-checked by the guard, needs a
 * reason, writes its audit row with `via: panel` (actor, IP, before / after), and — destructive or money — asks for
 * the authenticator code again. The rules are the shared ones in `account-control` (and `account-deletion`), so the
 * `control-admin` CLI does the same.
 */
@Injectable()
export class AdminControlService {
  private readonly logger = new Logger(AdminControlService.name);
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly adminAuth: AdminAuthService,
    private readonly auth: AuthService,
    private readonly passwords: PasswordHasher,
    private readonly live: LiveRoomsService,
    private readonly liveMedia: LiveMediaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** The account an action targets: not one's own; a panel admin only by an OWNER. */
  private async target(id: string, ctx: AdminContext) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        status: true,
        role: true,
        emailVerifiedAt: true,
        adminPermissions: { select: { permission: true } },
      },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === ctx.userId) throw refused('You cannot do this to your own account.');
    const isAdmin = user.role === 'ADMIN' && user.adminPermissions.some((p) => isPanelRole(p.permission));
    if (isAdmin && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return user;
  }

  private async withControl<T>(run: () => Promise<T>): Promise<T> {
    try {
      return await run();
    } catch (err) {
      controlError(err);
    }
  }

  // ---- state -----------------------------------------------------------------------------------------------------

  /** What the user page's action groups show: current locks and restrictions with history, password and email. */
  async state(id: string, ctx: AdminContext, now = new Date()) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        status: true,
        email: true,
        emailVerifiedAt: true,
        passwordChangeRequiredAt: true,
        profile: { select: { gender: true } },
      },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const since = dayStart(now, this.config.adminPanel.dashboardTimeZone);
    const [active, history, deletion, used, adjustments] = await Promise.all([
      activeRestrictionsOf(this.prisma, id, now),
      this.prisma.accountRestriction.findMany({
        where: { userId: id },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 50,
      }),
      this.prisma.accountDeletionRequest.findFirst({
        where: { userId: id, status: 'PENDING' },
        select: { requestedAt: true, purgeAfter: true, requestedVia: true },
      }),
      this.prisma.$queryRaw<{ currency: string; used: bigint }[]>`
        SELECT currency, sum(abs(delta))::bigint AS used FROM admin_balance_adjustments
         WHERE actor_user_id = ${ctx.userId}::uuid AND created_at >= ${since}::timestamptz
         GROUP BY currency`,
      this.prisma.adminBalanceAdjustment.findMany({
        where: { userId: id },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 20,
        select: {
          id: true,
          currency: true,
          delta: true,
          balanceBefore: true,
          balanceAfter: true,
          reason: true,
          createdAt: true,
          actor: { select: { profile: { select: { username: true } } } },
        },
      }),
    ]);
    const usedOf = (c: string) => Number(used.find((u) => u.currency === c)?.used ?? 0n);
    const lock = active.find((r) => r.kind === 'LOCK') ?? null;
    return {
      status: user.status,
      lock: lock ? restrictionDto(lock, now) : null,
      restrictions: active.filter((r) => r.kind !== 'LOCK').map((r) => restrictionDto(r, now)),
      history: history.map((r) => restrictionDto(r, now)),
      password: { changeRequired: user.passwordChangeRequiredAt !== null },
      email: { address: user.email, verified: user.emailVerifiedAt !== null },
      gender: user.profile?.gender ?? null,
      /** Profile covers do not exist (only the photo); kept so the panel can say so. */
      cover: null,
      deletion: deletion
        ? {
            requestedAt: deletion.requestedAt.toISOString(),
            purgeAfter: deletion.purgeAfter.toISOString(),
            requestedVia: deletion.requestedVia,
          }
        : null,
      adjustToday: {
        coins: usedOf('COINS'),
        cherries: usedOf('CHERRIES'),
        capCoins: this.config.adminPanel.adjustDailyCap.coins,
        capCherries: this.config.adminPanel.adjustDailyCap.cherries,
      },
      adjustments: adjustments.map((a) => ({
        id: a.id,
        currency: a.currency,
        delta: Number(a.delta),
        before: Number(a.balanceBefore),
        after: Number(a.balanceAfter),
        reason: a.reason,
        actor: a.actor?.profile?.username ?? null,
        createdAt: a.createdAt.toISOString(),
      })),
    };
  }

  // ---- lock and restrictions -------------------------------------------------------------------------------------

  /** Ends the person's live (end reason ADMIN) and frees their seats; returns the rooms to close after the commit. */
  private async endLiveIn(tx: Tx, id: string): Promise<string[]> {
    const rooms = await this.live.endByAdminIn(tx, { hostUserId: id });
    await this.live.releaseSeatsOfUserIn(tx, id);
    return rooms;
  }

  private async closeRooms(rooms: readonly string[]): Promise<void> {
    for (const roomId of rooms) {
      try {
        await this.liveMedia.closeMedia(roomId);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err), roomId }, 'Media session could not be closed');
      }
    }
  }

  async restrict(
    id: string,
    kind: AccountRestrictionKind,
    body: { days?: number | undefined; until?: string | undefined; reason: string },
    ctx: AdminContext,
  ) {
    await this.target(id, ctx);
    const now = new Date();
    return this.withControl(async () => {
      const endsAt = restrictionEnd(now, {
        days: body.days,
        until: body.until === undefined ? undefined : new Date(body.until),
      });
      let rooms: string[] = [];
      const result = await this.prisma.$transaction(async (tx) => {
        const out = await restrictIn(tx, id, kind, endsAt, body.reason, viaOf(ctx), now);
        if (kind === 'LOCK' || kind === 'NO_LIVE') rooms = await this.endLiveIn(tx, id);
        return out;
      });
      await this.closeRooms(rooms);
      return {
        restriction: restrictionDto(result.restriction, now),
        replaced: result.replaced ? restrictionDto(result.replaced, now) : null,
        sessions: result.sessions,
        livesEnded: rooms.length,
      };
    });
  }

  async lift(id: string, kind: AccountRestrictionKind, reason: string, ctx: AdminContext) {
    await this.target(id, ctx);
    const now = new Date();
    return this.withControl(async () => {
      const lifted = await this.prisma.$transaction((tx) => liftIn(tx, id, kind, reason, viaOf(ctx), now));
      return { restriction: restrictionDto(lifted, now) };
    });
  }

  // ---- password --------------------------------------------------------------------------------------------------

  /** «إرسال رابط إعادة تعيين»: the existing reset email to the account's address (the admin never sees the link). */
  async sendResetLink(id: string, reason: string, ctx: AdminContext) {
    const user = await this.target(id, ctx);
    if (user.status !== 'ACTIVE' && user.status !== 'PENDING_DELETION') {
      throw refused(`The account is ${user.status}.`);
    }
    await this.auth.forgotPassword(user.email, {
      ip: ctx.ip,
      ipBucket: ctx.ip ?? 'admin',
      userAgent: null,
      requestId: ctx.requestId ?? '',
    });
    await this.audit.record({
      action: AuditAction.ADMIN_PASSWORD_RESET_LINK,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: id,
      metadata: { reason, to: maskEmail(user.email), via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { sent: true, to: maskEmail(user.email) };
  }

  /**
   * «تعيين كلمة مرور مؤقتة»: generated here and returned ONCE (never stored in the clear, never logged); every session
   * ends and the next sign-in must choose a new one. The authenticator code again.
   */
  async temporaryPassword(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    const user = await this.target(id, ctx);
    if (user.status === 'DELETED') throw new AppException(ErrorCode.NOT_FOUND);
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    const password = temporaryPassword();
    const hash = await this.passwords.hash(password);
    return this.withControl(async () => {
      const out = await this.prisma.$transaction((tx) =>
        requirePasswordChangeIn(tx, id, body.reason, viaOf(ctx), { endSessions: true, passwordHash: hash }),
      );
      return { temporaryPassword: password, sessions: out.sessions };
    });
  }

  /** «فرض تغيير كلمة المرور في الدخول القادم». */
  async requirePasswordChange(id: string, body: { reason: string; endSessions: boolean }, ctx: AdminContext) {
    await this.target(id, ctx);
    return this.withControl(async () => {
      const out = await this.prisma.$transaction((tx) =>
        requirePasswordChangeIn(tx, id, body.reason, viaOf(ctx), { endSessions: body.endSessions }),
      );
      return { changeRequired: true, sessions: out.sessions };
    });
  }

  // ---- profile ---------------------------------------------------------------------------------------------------

  /**
   * The display name (§6 rules, reserved terms), the username (the D146 regular rule; refused while a special or
   * premium username is shown, and when reserved or anyone else's), the bio, the country and the gender. The person
   * gets PROFILE_EDITED_BY_TEAM. Fields that do not change are not written.
   */
  async editProfile(
    id: string,
    body: {
      displayName?: string | undefined;
      username?: string | undefined;
      bio?: string | null | undefined;
      country?: string | null | undefined;
      gender?: 'MALE' | 'FEMALE' | 'UNDISCLOSED' | undefined;
      reason: string;
    },
    ctx: AdminContext,
  ) {
    const user = await this.target(id, ctx);
    if (user.status === 'DELETED') throw new AppException(ErrorCode.NOT_FOUND);
    if (
      body.displayName !== undefined &&
      containsReservedTerm(
        body.displayName,
        this.config.reservedDisplayNameTerms,
        this.config.reservedDisplayNameBrandTerms,
      )
    ) {
      throw AppException.validation([{ field: 'displayName', issue: 'reserved_term' }]);
    }
    const name = body.username;
    if (name !== undefined) {
      const issue = regularUsernameIssue(name);
      if (issue) throw AppException.validation([{ field: 'username', issue }]);
    }
    const now = new Date();
    const changed = await this.prisma.$transaction(async (tx) => {
      if (name !== undefined) {
        await lockUser(tx, id);
        await lockName(tx, name);
      }
      const [before] = await tx.$queryRaw<
        {
          username: string;
          display_name: string;
          bio: string | null;
          country_code: string | null;
          gender: string | null;
        }[]
      >`
        SELECT username, display_name, bio, country_code, gender::text AS gender
          FROM user_profiles WHERE user_id = ${id}::uuid FOR UPDATE`;
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      const data: Prisma.UserProfileUpdateInput = {};
      const fields: string[] = [];
      const was: Record<string, string | null> = {};
      const now_: Record<string, string | null> = {};
      const note = (field: string, from: string | null, to: string | null) => {
        fields.push(field);
        was[field] = from;
        now_[field] = to;
      };
      if (body.displayName !== undefined && body.displayName !== before.display_name) {
        data.displayName = body.displayName;
        note('displayName', before.display_name, body.displayName);
      }
      if (body.bio !== undefined && body.bio !== before.bio) {
        data.bio = body.bio;
        note('bio', before.bio, body.bio);
      }
      if (body.country !== undefined && body.country !== before.country_code) {
        data.countryCode = body.country;
        note('country', before.country_code, body.country);
      }
      if (body.gender !== undefined && body.gender !== before.gender) {
        data.gender = body.gender;
        note('gender', before.gender, body.gender);
      }
      if (name !== undefined && name !== before.username) {
        if (await activeSpecialOf(tx, id)) throw refused('A special username is shown now; revoke it first.');
        if (await activeLeaseOf(tx, id))
          throw refused('The person rents a premium username; it must end first.');
        if (isReservedUsername(name) || (await nameInUse(tx, name, id, now))) {
          throw new AppException(ErrorCode.USERNAME_TAKEN);
        }
        data.username = name;
        data.premiumTier = null;
        note('username', before.username, name);
      }
      let heldUntil: Date | null = null;
      if (fields.length === 0) return [];
      await tx.userProfile.update({ where: { userId: id }, data });
      if (data.username !== undefined)
        heldUntil = await this.holdOldUsernameIn(tx, id, before.username, data.username as string, now);
      if (data.gender !== undefined) {
        // The active-host frame follows the gender (D186), as when the person changes it.
        await syncHostFrameIn(tx, id, now, this.config.economy, this.config.live.rankingsTimeZone);
      }
      await this.notifier.system(tx, { type: 'PROFILE_EDITED_BY_TEAM', recipientId: id });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_PROFILE_EDIT,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: id,
        metadata: {
          reason: body.reason,
          fields,
          before: was,
          after: now_,
          ...(heldUntil ? { oldUsernameHeldUntil: heldUntil.toISOString() } : {}),
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return fields;
    });
    return { changed };
  }

  /**
   * v1.72-social (D208, owner 2026-10-31): the old username stays the person's for ADMIN_USERNAME_RENAME_HOLD_DAYS —
   * the special-username hold (a GRACE row: every «taken» check honours it, old @mentions still lead to the person,
   * the person may take it back, the sweeper releases it at `grace_until`). An own hold of the name is extended.
   */
  private async holdOldUsernameIn(
    tx: Tx,
    id: string,
    old: string,
    next: string,
    now: Date,
  ): Promise<Date | null> {
    const days = this.config.adminPanel.renameHoldDays;
    if (days <= 0) return null;
    const until = new Date(now.getTime() + days * 86_400_000);
    const own = await tx.specialUsername.findFirst({ where: { userId: id, username: old, status: 'GRACE' } });
    if (own) {
      await tx.specialUsername.update({
        where: { id: own.id },
        data: {
          baseUsername: next,
          graceUntil: own.graceUntil && own.graceUntil > until ? own.graceUntil : until,
        },
      });
      return until;
    }
    if ((await specialHolderOf(tx, old, id)) !== null) return null;
    await tx.specialUsername.create({
      data: {
        userId: id,
        username: old,
        baseUsername: next,
        source: 'ADMIN_GIFT',
        status: 'GRACE',
        locked: true,
        grantedAt: now,
        endedAt: now,
        endReason: 'RENAMED',
        graceUntil: until,
        reason: 'held after a rename by the team',
      },
    });
    return until;
  }

  // ---- email -----------------------------------------------------------------------------------------------------

  /**
   * A new address: verified by a link sent to it (the existing verification email), or — OWNER only — marked verified
   * at once. Outstanding verification and reset links of the old address stop working. The authenticator code again.
   */
  async changeEmail(
    id: string,
    body: { email: string; markVerified: boolean; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    const user = await this.target(id, ctx);
    if (user.status === 'DELETED') throw new AppException(ErrorCode.NOT_FOUND);
    if (body.markVerified && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (body.email === user.email) throw refused('That is the current address.');
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    const now = new Date();
    try {
      await this.prisma.$transaction(async (tx) => {
        const taken = await tx.user.count({ where: { email: body.email, id: { not: id } } });
        if (taken > 0) throw refused('Another account uses that address.');
        await tx.user.update({
          where: { id },
          data: { email: body.email, emailVerifiedAt: body.markVerified ? now : null },
        });
        await tx.verificationToken.updateMany({
          where: { userId: id, consumedAt: null },
          data: { consumedAt: now },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.ADMIN_EMAIL_CHANGE,
          actorUserId: ctx.userId,
          targetType: 'user',
          targetId: id,
          metadata: {
            reason: body.reason,
            before: { email: maskEmail(user.email), verified: user.emailVerifiedAt !== null },
            after: { email: maskEmail(body.email), verified: body.markVerified },
            via: 'panel',
          },
          ip: ctx.ip,
          requestId: ctx.requestId,
        });
      });
    } catch (err) {
      if ((err as { code?: string }).code === 'P2002') throw refused('Another account uses that address.');
      throw err;
    }
    if (!body.markVerified) await this.auth.resendVerification(id);
    return { email: body.email, verified: body.markVerified, verificationSent: !body.markVerified };
  }

  async resendVerification(id: string, reason: string, ctx: AdminContext) {
    const user = await this.target(id, ctx);
    if (user.emailVerifiedAt !== null) throw refused('The address is already verified.');
    if (user.status !== 'ACTIVE') throw refused(`The account is ${user.status}.`);
    await this.auth.resendVerification(id);
    await this.audit.record({
      action: AuditAction.ADMIN_EMAIL_VERIFICATION_RESEND,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: id,
      metadata: { reason, to: maskEmail(user.email), via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return { sent: true, to: maskEmail(user.email) };
  }

  // ---- content ---------------------------------------------------------------------------------------------------

  /** A user's stories or comments (any state), newest first — the posts and reels are `listAdminUserPosts`. */
  async userContent(id: string, kind: 'stories' | 'comments', page: number, pageSize: number) {
    if (!(await this.prisma.user.findUnique({ where: { id }, select: { id: true } }))) {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    const skip = (page - 1) * pageSize;
    if (kind === 'stories') {
      const where = { authorId: id };
      const [rows, total] = await Promise.all([
        this.prisma.story.findMany({
          where,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          skip,
          take: pageSize,
          select: {
            id: true,
            text: true,
            createdAt: true,
            expiresAt: true,
            removedAt: true,
            deletedAt: true,
          },
        }),
        this.prisma.story.count({ where }),
      ]);
      return {
        data: rows.map((s) => ({
          id: s.id,
          text: s.text,
          state: s.deletedAt ? 'DELETED' : s.removedAt ? 'HIDDEN' : 'VISIBLE',
          expiresAt: s.expiresAt.toISOString(),
          createdAt: s.createdAt.toISOString(),
        })),
        total,
        page,
        pageSize,
      };
    }
    const where = { authorId: id };
    const [rows, total] = await Promise.all([
      this.prisma.comment.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip,
        take: pageSize,
        select: { id: true, text: true, postId: true, createdAt: true, deletedAt: true },
      }),
      this.prisma.comment.count({ where }),
    ]);
    return {
      data: rows.map((c) => ({
        id: c.id,
        text: c.text,
        postId: c.postId,
        state: c.deletedAt ? 'DELETED' : 'VISIBLE',
        createdAt: c.createdAt.toISOString(),
      })),
      total,
      page,
      pageSize,
    };
  }

  /** The author of a post, story or comment (404 when none), checked like any target. */
  private async contentAuthor(type: ContentType, contentId: string, ctx: AdminContext): Promise<string> {
    const row =
      type === 'post'
        ? await this.prisma.post.findUnique({ where: { id: contentId }, select: { authorId: true } })
        : type === 'story'
          ? await this.prisma.story.findUnique({ where: { id: contentId }, select: { authorId: true } })
          : await this.prisma.comment.findUnique({ where: { id: contentId }, select: { authorId: true } });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    await this.target(row.authorId, ctx);
    return row.authorId;
  }

  private async closeReportsIn(
    tx: Tx,
    type: ContentType,
    contentId: string,
    ctx: AdminContext,
    note: string,
  ) {
    const where: Prisma.ReportWhereInput =
      type === 'post'
        ? { targetPostId: contentId }
        : type === 'story'
          ? { targetStoryId: contentId }
          : { targetCommentId: contentId };
    const closed = await tx.report.updateMany({
      where: { ...where, status: 'OPEN' },
      data: { status: 'ACTIONED', resolvedAt: new Date(), resolvedById: ctx.userId, resolutionNote: note },
    });
    return closed.count;
  }

  /** A comment removed (soft, with its replies; the post's counts follow) — the same as the report action. */
  private async removeCommentIn(tx: Tx, commentId: string): Promise<boolean> {
    const target = await tx.comment.findUnique({ where: { id: commentId }, select: { postId: true } });
    if (!target) return false;
    await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${target.postId}::uuid FOR UPDATE`;
    const [row] = await tx.$queryRaw<{ id: string; parent_id: string | null }[]>`
      SELECT id::text AS id, parent_id::text AS parent_id FROM comments
       WHERE id = ${commentId}::uuid AND deleted_at IS NULL FOR UPDATE`;
    if (!row) return false;
    const now = new Date();
    const replies = await tx.comment.updateMany({
      where: { parentId: row.id, deletedAt: null },
      data: { deletedAt: now, pinnedAt: null },
    });
    await tx.comment.update({ where: { id: row.id }, data: { deletedAt: now, pinnedAt: null } });
    await tx.post.update({
      where: { id: target.postId },
      data: { commentCount: { decrement: 1 + replies.count } },
    });
    if (row.parent_id) {
      await tx.comment.update({ where: { id: row.parent_id }, data: { replyCount: { decrement: 1 } } });
    }
    return true;
  }

  /**
   * `hide` (posts, reels, stories: hidden from everyone, restorable; a comment is removed — comments cannot be
   * restored), `restore` (a hidden post or story back), `delete` (a post or story for good: the author's own delete;
   * v1.78-live, D288: no authenticator code any more — the capability, the rate limit and the audit). Hiding and deleting close the item's open reports (ACTIONED) and tell the author
   * (CONTENT_REMOVED).
   */
  async content(
    type: ContentType,
    contentId: string,
    op: 'hide' | 'restore' | 'delete',
    body: { reason: string },
    ctx: AdminContext,
  ) {
    if (type === 'comment' && op !== 'hide') throw refused('A comment can only be removed.');
    const authorId = await this.contentAuthor(type, contentId, ctx);
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      let before: string;
      let after: string;
      let notify = false;
      if (type === 'post') {
        await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${contentId}::uuid FOR UPDATE`;
        const post = await tx.post.findUniqueOrThrow({
          where: { id: contentId },
          select: { moderation: true, deletedAt: true },
        });
        before = post.deletedAt ? 'DELETED' : post.moderation;
        if (post.deletedAt) throw refused('The post is already deleted.');
        if (op === 'hide') {
          if (post.moderation === 'REMOVED') throw refused('The post is already hidden.');
          await tx.post.update({ where: { id: contentId }, data: { moderation: 'REMOVED' } });
          await tx.postPin.deleteMany({ where: { postId: contentId } });
          after = 'REMOVED';
          notify = true;
        } else if (op === 'restore') {
          if (post.moderation !== 'REMOVED') throw refused('The post is not hidden.');
          await tx.post.update({ where: { id: contentId }, data: { moderation: 'VISIBLE' } });
          after = 'VISIBLE';
        } else {
          await tx.post.update({ where: { id: contentId }, data: { deletedAt: now, moderation: 'REMOVED' } });
          await tx.postPin.deleteMany({ where: { postId: contentId } });
          after = 'DELETED';
          notify = post.moderation !== 'REMOVED';
        }
        if (notify) {
          await this.notifier.system(tx, {
            type: 'CONTENT_REMOVED',
            recipientId: authorId,
            postId: contentId,
          });
        }
      } else if (type === 'story') {
        const story = await tx.story.findUniqueOrThrow({
          where: { id: contentId },
          select: { removedAt: true, deletedAt: true },
        });
        before = story.deletedAt ? 'DELETED' : story.removedAt ? 'HIDDEN' : 'VISIBLE';
        if (story.deletedAt) throw refused('The story is already deleted.');
        if (op === 'hide') {
          if (story.removedAt) throw refused('The story is already hidden.');
          await tx.story.update({ where: { id: contentId }, data: { removedAt: now } });
          after = 'HIDDEN';
          notify = true;
        } else if (op === 'restore') {
          if (!story.removedAt) throw refused('The story is not hidden.');
          await tx.story.update({ where: { id: contentId }, data: { removedAt: null } });
          after = 'VISIBLE';
        } else {
          await tx.story.update({
            where: { id: contentId },
            data: { deletedAt: now, removedAt: story.removedAt ?? now },
          });
          after = 'DELETED';
          notify = story.removedAt === null;
        }
        if (notify) {
          await this.notifier.system(tx, {
            type: 'CONTENT_REMOVED',
            recipientId: authorId,
            storyId: contentId,
          });
        }
      } else {
        const comment = await tx.comment.findUniqueOrThrow({
          where: { id: contentId },
          select: { postId: true, deletedAt: true },
        });
        before = comment.deletedAt ? 'DELETED' : 'VISIBLE';
        if (!(await this.removeCommentIn(tx, contentId))) throw refused('The comment is already removed.');
        after = 'DELETED';
        await this.notifier.system(tx, {
          type: 'CONTENT_REMOVED',
          recipientId: authorId,
          postId: comment.postId,
          commentId: contentId,
        });
      }
      const reportsClosed =
        op === 'restore' ? 0 : await this.closeReportsIn(tx, type, contentId, ctx, body.reason);
      await this.audit.recordIn(tx, {
        action:
          op === 'hide'
            ? AuditAction.ADMIN_CONTENT_HIDE
            : op === 'restore'
              ? AuditAction.ADMIN_CONTENT_RESTORE
              : AuditAction.ADMIN_CONTENT_DELETE,
        actorUserId: ctx.userId,
        targetType: type,
        targetId: contentId,
        metadata: { reason: body.reason, authorId, before, after, reportsClosed, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
      return { state: after, reportsClosed };
    });
    return result;
  }

  // ---- money -----------------------------------------------------------------------------------------------------

  async adjust(
    id: string,
    body: {
      currency: AdjustCurrency;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      allowNegative: boolean;
      reason: string;
      totpCode: string;
    },
    ctx: AdminContext,
  ) {
    await this.target(id, ctx);
    if (body.allowNegative && !ctx.roles.includes('OWNER')) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (body.allowNegative && body.direction !== 'DEBIT')
      throw refused('«Allow negative» is for a debit only.');
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    const amount = BigInt(body.amount);
    const caps = this.config.adminPanel.adjustDailyCap;
    return this.withControl(async () => {
      const out = await this.prisma.$transaction((tx) =>
        adjustBalanceIn(
          tx,
          {
            userId: id,
            currency: body.currency,
            delta: body.direction === 'CREDIT' ? amount : -amount,
            allowNegative: body.allowNegative,
            reason: body.reason,
            dailyCap: BigInt(body.currency === 'COINS' ? caps.coins : caps.cherries),
            zone: this.config.adminPanel.dashboardTimeZone,
          },
          viaOf(ctx),
        ),
      );
      return {
        adjustmentId: out.adjustmentId,
        currency: out.currency,
        delta: Number(out.delta),
        before: Number(out.before),
        after: Number(out.after),
        usedToday: Number(out.usedToday),
      };
    });
  }

  // ---- deletion (D193) -------------------------------------------------------------------------------------------

  /**
   * Starts the D193 grace period for the account (as `account-admin request`); ends a live. v1.78-live (D288, owner):
   * no authenticator code any more — `users.delete` (OWNER) on every request, the reason, `admin:ip` and the audit
   * `account.deletion.requested` {reason, via} protect it (the grace period still lets it be cancelled).
   */
  async requestDeletion(id: string, body: { reason: string }, ctx: AdminContext) {
    await this.target(id, ctx);
    const now = new Date();
    let rooms: string[] = [];
    const out = await this.prisma.$transaction(async (tx) => {
      const r = await requestDeletionIn(tx, id, now, this.config.accountDeletion.graceDays, {
        via: 'ADMIN',
        actorUserId: ctx.userId,
        reason: body.reason,
        ip: ctx.ip,
        requestId: ctx.requestId,
        auditVia: 'panel',
      });
      if (r.outcome === 'requested') rooms = await this.live.endByAdminIn(tx, { hostUserId: id });
      return r;
    });
    await this.closeRooms(rooms);
    if (out.outcome === 'not_active') throw refused('The account is not ACTIVE.');
    if (out.outcome === 'already_pending') throw refused('A deletion is already pending.');
    if (out.outcome === 'blocked') {
      throw new AppException(
        ErrorCode.ACCOUNT_DELETION_BLOCKED,
        undefined,
        out.blockers.map((b) => ({ field: 'blocker', issue: b })),
      );
    }
    return {
      purgeAfter: out.request.purgeAfter.toISOString(),
      sessions: out.revokedSessions,
      livesEnded: rooms.length,
    };
  }

  async cancelDeletion(id: string, reason: string, ctx: AdminContext) {
    await this.target(id, ctx);
    const ok = await this.prisma.$transaction((tx) =>
      cancelDeletionIn(tx, id, new Date(), {
        via: 'ADMIN',
        actorUserId: ctx.userId,
        reason,
        ip: ctx.ip,
        requestId: ctx.requestId,
        auditVia: 'panel',
      }),
    );
    if (!ok) throw refused('No deletion is pending.');
    return { status: 'ACTIVE' as const };
  }
}
