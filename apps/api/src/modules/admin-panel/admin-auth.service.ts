import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { AdminSession } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PasswordHasher } from '../auth/password-hasher.service.js';
import { normalizeEmail } from '../users/username.js';
import {
  AdminSecretBox,
  newRecoveryCode,
  randomToken,
  RECOVERY_CODE_COUNT,
  recoveryCodeHash,
  sha256Hex,
} from './admin-crypto.js';
import { capabilitiesOf, isPanelRole, type Capability, type PanelRole } from './admin-permissions.js';
import { matchTotp, newTotpSecret, otpauthUri } from './totp.js';

/** The cookie of a panel session (`__Host-`: Secure, Path=/, no Domain — admin.<domain> only). */
export const ADMIN_COOKIE = '__Host-kabso_admin';
export const CSRF_HEADER = 'x-csrf-token';

export interface AdminMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

/** What the guard attaches to a request with a valid panel session. */
export interface AdminContext {
  readonly sessionId: string;
  readonly userId: string;
  readonly stage: 'PASSWORD' | 'ACTIVE';
  readonly roles: PanelRole[];
  readonly capabilities: Capability[];
  readonly ip: string | null;
  readonly requestId: string | null;
}

/** A session token for the cookie and when the cookie should expire. */
export interface IssuedSession {
  readonly token: string;
  readonly csrfToken: string;
  readonly maxAgeSeconds: number;
  readonly stage: 'PASSWORD' | 'ACTIVE';
}

export type SecondFactor = { readonly code: string } | { readonly recoveryCode: string };

const LOGIN_BUCKET = 'admin_login:account';

/**
 * Sign-in to the admin panel (v1.60-social, D191, CONVENTIONS §10.54.2): an existing admin account's email and
 * password, then the authenticator code — enrolled with a QR code on the first sign-in, with ten single-use recovery
 * codes. Sessions live behind an HttpOnly, Secure, SameSite=Strict cookie; changes also need the CSRF token (an HMAC
 * of the cookie). Failed passwords lock the email (the same for every email, so the lock reveals nothing); failed
 * codes lock the admin account (`admin_credentials.locked_until`) and end its sessions. Nothing secret is logged:
 * audit rows carry ids and reasons only.
 */
@Injectable()
export class AdminAuthService {
  private readonly box: AdminSecretBox | null;
  private readonly csrfKey: Buffer | null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
    private readonly audit: AuditService,
    private readonly limiter: RateLimitService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    const key = config.adminPanel.totpKey;
    this.box = key ? new AdminSecretBox(key) : null;
    this.csrfKey = key
      ? Buffer.from(hkdfSync('sha256', Buffer.from(key, 'utf8'), Buffer.alloc(0), 'admin-csrf/v1', 32))
      : null;
  }

  /** 503 ADMIN_PANEL_UNAVAILABLE while ADMIN_TOTP_KEY is not set. */
  requireOn(): void {
    if (!this.box) throw new AppException(ErrorCode.ADMIN_PANEL_UNAVAILABLE);
  }

  csrfFor(token: string): string {
    this.requireOn();
    return createHmac('sha256', this.csrfKey!).update(token).digest('base64url');
  }

  csrfMatches(token: string, given: string | undefined): boolean {
    if (!given) return false;
    const want = Buffer.from(this.csrfFor(token));
    const got = Buffer.from(given);
    return want.length === got.length && timingSafeEqual(want, got);
  }

  // ---- sessions -------------------------------------------------------------------------------------------------

  private async issue(
    userId: string,
    stage: 'PASSWORD' | 'ACTIVE',
    ip: string | null,
  ): Promise<IssuedSession> {
    const token = randomToken();
    const now = Date.now();
    const p = this.config.adminPanel;
    const ttl = stage === 'ACTIVE' ? p.sessionIdleSeconds : p.pendingSeconds;
    const max = stage === 'ACTIVE' ? p.sessionMaxSeconds : p.pendingSeconds;
    await this.prisma.adminSession.create({
      data: {
        userId,
        tokenHash: sha256Hex(token),
        stage,
        expiresAt: new Date(now + Math.min(ttl, max) * 1000),
        absoluteExpiresAt: new Date(now + max * 1000),
        ip: ip?.slice(0, 64) ?? null,
      },
    });
    return { token, csrfToken: this.csrfFor(token), maxAgeSeconds: max, stage };
  }

  /**
   * The session behind a cookie: not revoked, before both its idle and absolute expiry. Sliding: an ACTIVE session's
   * idle expiry moves on with each request (never past the absolute one).
   */
  async sessionOf(token: string | undefined): Promise<AdminSession | null> {
    this.requireOn();
    if (!token || token.length > 128) return null;
    const row = await this.prisma.adminSession.findUnique({ where: { tokenHash: sha256Hex(token) } });
    const now = new Date();
    if (!row || row.revokedAt !== null || row.expiresAt <= now || row.absoluteExpiresAt <= now) return null;
    if (row.stage === 'ACTIVE') {
      const next = new Date(
        Math.min(
          now.getTime() + this.config.adminPanel.sessionIdleSeconds * 1000,
          row.absoluteExpiresAt.getTime(),
        ),
      );
      // At most one write every 15 seconds per session.
      if (next.getTime() - row.expiresAt.getTime() > 15_000) {
        await this.prisma.adminSession.update({
          where: { id: row.id },
          data: { expiresAt: next, lastSeenAt: now },
        });
      }
    }
    return row;
  }

  /** The panel roles the user holds now (ADMIN role and an ACTIVE account required; else none). */
  async rolesOf(userId: string): Promise<PanelRole[]> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, status: true, adminPermissions: { select: { permission: true } } },
    });
    if (!user || user.role !== 'ADMIN' || user.status !== 'ACTIVE') return [];
    return user.adminPermissions.map((p) => p.permission).filter(isPanelRole);
  }

  async context(session: AdminSession, meta: AdminMeta): Promise<AdminContext | null> {
    const roles = await this.rolesOf(session.userId);
    if (roles.length === 0) return null;
    return {
      sessionId: session.id,
      userId: session.userId,
      stage: session.stage as 'PASSWORD' | 'ACTIVE',
      roles,
      capabilities: capabilitiesOf(roles),
      ip: meta.ip,
      requestId: meta.requestId,
    };
  }

  /** `AdminSessionInfo`: who is signed in, their roles and capabilities, and the CSRF token for changes. */
  async me(ctx: AdminContext, token: string) {
    const [user, session] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({
        where: { id: ctx.userId },
        select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
      }),
      this.prisma.adminSession.findUniqueOrThrow({ where: { id: ctx.sessionId } }),
    ]);
    return {
      admin: {
        id: user.id,
        email: user.email,
        username: user.profile?.username ?? '',
        displayName: user.profile?.displayName ?? '',
      },
      roles: ctx.roles,
      capabilities: ctx.capabilities,
      csrfToken: this.csrfFor(token),
      expiresAt: session.absoluteExpiresAt.toISOString(),
      idleSeconds: this.config.adminPanel.sessionIdleSeconds,
    };
  }

  /** The session just issued by a second factor, as {@link me} answers. */
  async meOfIssued(issued: IssuedSession, meta: AdminMeta) {
    const session = await this.sessionOf(issued.token);
    const ctx = session ? await this.context(session, meta) : null;
    if (!ctx) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    return this.me(ctx, issued.token);
  }

  async logout(ctx: AdminContext): Promise<void> {
    await this.prisma.adminSession.updateMany({
      where: { id: ctx.sessionId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    await this.audit.record({
      action: AuditAction.ADMIN_LOGOUT,
      actorUserId: ctx.userId,
      targetType: 'admin_session',
      targetId: ctx.sessionId,
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
  }

  // ---- password -------------------------------------------------------------------------------------------------

  async login(
    email: string,
    password: string,
    meta: AdminMeta,
  ): Promise<IssuedSession & { next: 'TOTP_ENROL' | 'TOTP_VERIFY' }> {
    this.requireOn();
    const normalized = normalizeEmail(email);
    const p = this.config.adminPanel;
    // The same lock for every email (counted before the password; a right password gives the slot back).
    const hit = await this.limiter.hit(LOGIN_BUCKET, normalized, {
      max: p.lockoutAttempts,
      windowSeconds: p.lockoutSeconds,
    });
    if (!hit.allowed) {
      await this.audit.record({
        action: AuditAction.ADMIN_LOCKED,
        metadata: { stage: 'password' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw this.locked(hit.retryAfterSeconds);
    }
    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
      select: {
        id: true,
        role: true,
        status: true,
        passwordHash: true,
        adminPermissions: { select: { permission: true } },
        adminCredential: { select: { totpEnrolledAt: true, lockedUntil: true } },
      },
    });
    const ok = user
      ? await this.passwords.verify(user.passwordHash, password)
      : await this.passwords.verifyAgainstDummy(password);
    const roles = user?.adminPermissions.map((x) => x.permission).filter(isPanelRole) ?? [];
    if (!user || !ok || user.status !== 'ACTIVE' || user.role !== 'ADMIN' || roles.length === 0) {
      await this.audit.record({
        action: AuditAction.ADMIN_LOGIN_FAILURE,
        actorUserId: user?.id ?? null,
        metadata: {
          reason: !user
            ? 'unknown'
            : !ok
              ? 'bad_password'
              : user.status !== 'ACTIVE'
                ? 'inactive'
                : 'not_admin',
        },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.AUTH_INVALID_CREDENTIALS);
    }
    await this.limiter.refund(LOGIN_BUCKET, normalized);
    const lockedUntil = user.adminCredential?.lockedUntil;
    if (lockedUntil && lockedUntil > new Date()) {
      await this.audit.record({
        action: AuditAction.ADMIN_LOCKED,
        actorUserId: user.id,
        metadata: { stage: 'password' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw this.locked(Math.ceil((lockedUntil.getTime() - Date.now()) / 1000));
    }
    const issued = await this.issue(user.id, 'PASSWORD', meta.ip);
    const next = user.adminCredential?.totpEnrolledAt ? 'TOTP_VERIFY' : 'TOTP_ENROL';
    await this.audit.record({
      action: AuditAction.ADMIN_LOGIN_PASSWORD,
      actorUserId: user.id,
      metadata: { next },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return { ...issued, next };
  }

  private locked(retryAfterSeconds: number): AppException {
    return new AppException(ErrorCode.ADMIN_LOCKED, undefined, undefined, {
      'Retry-After': String(Math.max(1, retryAfterSeconds)),
    });
  }

  // ---- second factor --------------------------------------------------------------------------------------------

  private async credentialOf(userId: string) {
    return this.prisma.adminCredential.findUnique({ where: { userId } });
  }

  private async requireNotLocked(userId: string, meta: AdminMeta): Promise<void> {
    const cred = await this.credentialOf(userId);
    if (cred?.lockedUntil && cred.lockedUntil > new Date()) {
      await this.audit.record({
        action: AuditAction.ADMIN_LOCKED,
        actorUserId: userId,
        metadata: { stage: 'code' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw this.locked(Math.ceil((cred.lockedUntil.getTime() - Date.now()) / 1000));
    }
  }

  /**
   * A failed code: counts towards the lockout. At the limit the account locks and every session of the admin ends
   * (429 ADMIN_LOCKED); before it, 403 ADMIN_TOTP_INVALID.
   */
  private async failCode(userId: string, stage: string, meta: AdminMeta): Promise<never> {
    const p = this.config.adminPanel;
    const [row] = await this.prisma.$queryRaw<{ failed_attempts: number }[]>`
      INSERT INTO admin_credentials (user_id, failed_attempts, updated_at) VALUES (${userId}::uuid, 1, now())
      ON CONFLICT (user_id) DO UPDATE SET failed_attempts = admin_credentials.failed_attempts + 1, updated_at = now()
      RETURNING failed_attempts`;
    if ((row?.failed_attempts ?? 0) >= p.lockoutAttempts) {
      const until = new Date(Date.now() + p.lockoutSeconds * 1000);
      await this.prisma.$transaction(async (tx) => {
        await tx.adminCredential.update({
          where: { userId },
          data: { failedAttempts: 0, lockedUntil: until },
        });
        await tx.adminSession.updateMany({
          where: { userId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.ADMIN_LOCKED,
          actorUserId: userId,
          metadata: { stage, seconds: p.lockoutSeconds },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      });
      throw this.locked(p.lockoutSeconds);
    }
    await this.audit.record({
      action: AuditAction.ADMIN_TOTP_FAILURE,
      actorUserId: userId,
      metadata: { stage, attempts: row?.failed_attempts ?? 0 },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    throw new AppException(ErrorCode.ADMIN_TOTP_INVALID);
  }

  /**
   * Checks an authenticator code of an enrolled admin and consumes its time step (a code works once, also across
   * concurrent requests: the step only moves forward). False when it does not match.
   */
  private async consumeTotp(userId: string, code: string): Promise<boolean> {
    const cred = await this.credentialOf(userId);
    if (!cred?.totpEnrolledAt || !cred.totpSecretEnc) return false;
    const secret = this.box!.open(cred.totpSecretEnc);
    if (secret === null) return false;
    const last = cred.lastTotpStep === null ? null : Number(cred.lastTotpStep);
    const step = matchTotp(secret, code.trim(), Date.now(), last);
    if (step === null) return false;
    const moved = await this.prisma.adminCredential.updateMany({
      where: { userId, OR: [{ lastTotpStep: null }, { lastTotpStep: { lt: BigInt(step) } }] },
      data: { lastTotpStep: BigInt(step), failedAttempts: 0 },
    });
    return moved.count === 1;
  }

  private requirePending(session: AdminSession): void {
    if (session.stage !== 'PASSWORD') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
  }

  /** First sign-in: a new authenticator secret (shown once as a QR code); replaces an unconfirmed one. */
  async enrolStart(session: AdminSession, meta: AdminMeta): Promise<{ secret: string; otpauthUri: string }> {
    this.requirePending(session);
    await this.requireNotLocked(session.userId, meta);
    const cred = await this.credentialOf(session.userId);
    if (cred?.totpEnrolledAt) {
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'The authenticator is already set up.');
    }
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: session.userId },
      select: { email: true },
    });
    const secret = newTotpSecret();
    await this.prisma.adminCredential.upsert({
      where: { userId: session.userId },
      create: { userId: session.userId, totpSecretEnc: this.box!.seal(secret) },
      update: { totpSecretEnc: this.box!.seal(secret), lastTotpStep: null },
    });
    return { secret, otpauthUri: otpauthUri(secret, user.email) };
  }

  /** Confirms the enrolment with a code from the app: ten recovery codes (shown once) and an ACTIVE session. */
  async enrolConfirm(
    session: AdminSession,
    code: string,
    meta: AdminMeta,
  ): Promise<{ issued: IssuedSession; recoveryCodes: string[] }> {
    this.requirePending(session);
    await this.requireNotLocked(session.userId, meta);
    const cred = await this.credentialOf(session.userId);
    if (cred?.totpEnrolledAt) {
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'The authenticator is already set up.');
    }
    const secret = cred?.totpSecretEnc ? this.box!.open(cred.totpSecretEnc) : null;
    if (secret === null) throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'Start the set-up first.');
    const step = matchTotp(secret, code.trim(), Date.now(), null);
    if (step === null) return this.failCode(session.userId, 'enrol', meta);
    const recoveryCodes = Array.from({ length: RECOVERY_CODE_COUNT }, newRecoveryCode);
    await this.prisma.$transaction(async (tx) => {
      const done = await tx.adminCredential.updateMany({
        where: { userId: session.userId, totpEnrolledAt: null },
        data: { totpEnrolledAt: new Date(), lastTotpStep: BigInt(step), failedAttempts: 0 },
      });
      if (done.count !== 1)
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'The authenticator is already set up.');
      await tx.adminRecoveryCode.deleteMany({ where: { userId: session.userId } });
      await tx.adminRecoveryCode.createMany({
        data: recoveryCodes.map((c) => ({ userId: session.userId, codeHash: recoveryCodeHash(c) })),
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_TOTP_ENROL,
        actorUserId: session.userId,
        metadata: { recoveryCodes: RECOVERY_CODE_COUNT },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return { issued: await this.promote(session, meta, 'enrol'), recoveryCodes };
  }

  /** The second factor of a later sign-in: an authenticator code or one unused recovery code. */
  async verify(session: AdminSession, factor: SecondFactor, meta: AdminMeta): Promise<IssuedSession> {
    this.requirePending(session);
    await this.requireNotLocked(session.userId, meta);
    const cred = await this.credentialOf(session.userId);
    if (!cred?.totpEnrolledAt)
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'Set up the authenticator first.');
    if ('recoveryCode' in factor) {
      const used = await this.prisma.adminRecoveryCode.updateMany({
        where: { userId: session.userId, codeHash: recoveryCodeHash(factor.recoveryCode), usedAt: null },
        data: { usedAt: new Date() },
      });
      if (used.count !== 1) return this.failCode(session.userId, 'recovery', meta);
      const left = await this.prisma.adminRecoveryCode.count({
        where: { userId: session.userId, usedAt: null },
      });
      await this.prisma.adminCredential.update({
        where: { userId: session.userId },
        data: { failedAttempts: 0 },
      });
      await this.audit.record({
        action: AuditAction.ADMIN_RECOVERY_CODE_USED,
        actorUserId: session.userId,
        metadata: { left },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return this.promote(session, meta, 'recovery');
    }
    if (!(await this.consumeTotp(session.userId, factor.code)))
      return this.failCode(session.userId, 'verify', meta);
    return this.promote(session, meta, 'totp');
  }

  /** The pending session ends; a new ACTIVE one (new cookie and CSRF token: no session fixation) starts. */
  private async promote(session: AdminSession, meta: AdminMeta, method: string): Promise<IssuedSession> {
    const revoked = await this.prisma.adminSession.updateMany({
      where: { id: session.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (revoked.count !== 1) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const issued = await this.issue(session.userId, 'ACTIVE', meta.ip);
    await this.audit.record({
      action: AuditAction.ADMIN_LOGIN_SUCCESS,
      actorUserId: session.userId,
      metadata: { method },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return issued;
  }

  /**
   * Financial actions (a top-up, a withdrawal paid or rejected) need the authenticator code again (§10.54.3).
   * A wrong code counts towards the lockout like at sign-in.
   */
  async reauthenticate(ctx: AdminContext, code: string | undefined): Promise<void> {
    const meta = { ip: ctx.ip, requestId: ctx.requestId };
    await this.requireNotLocked(ctx.userId, meta);
    if (!code || !(await this.consumeTotp(ctx.userId, code))) await this.failCode(ctx.userId, 'reauth', meta);
  }
}
