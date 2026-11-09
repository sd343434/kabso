import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AccessTokenService } from '../auth/access-token.service.js';
import { activeDeviceBanOf } from '../auth/device-bans.js';
import { SessionsService } from '../auth/sessions.service.js';
import { generateSecret, sha256Hex } from '../auth/tokens.js';
import { PaymentSettingsStore } from '../payment-settings/payment-settings.store.js';
import { activeRestrictionOf } from '../users/account-control.js';
import { appLinkShownFor, type TopupLocale } from './topup-rules.js';

/** v1.109-social (D344): how long a minted code can be exchanged (the contract's maximum is 60 s). */
export const TOPUP_HANDOFF_TTL_SECONDS = 60;

/** A code is 32 random bytes in base64url (43 characters). */
const CODE = /^[A-Za-z0-9_-]{43}$/;

/** `TopupWebsiteSession` (openapi v1.109-social). */
export interface TopupWebsiteSessionDto {
  /** The website page with the one-time code in the fragment (`#h=…`, never sent to a server or logged). */
  websiteUrl: string;
  expiresAt: string;
}

/** `TopupHandoffSession` (openapi v1.109-social): only what the page keeps (no refresh token). */
export interface TopupHandoffSessionDto {
  accessToken: string;
  accessTokenExpiresAt: string;
  username: string;
}

export interface HandoffRequestInfo {
  readonly ip: string | null;
  readonly userAgent: string | null;
  readonly requestId: string;
}

const exchangeSchema = z.strictObject({ handoff: z.string().regex(CODE) });

/**
 * v1.109-social (D344, CONVENTIONS §10.143; owner: «اريد جعل الشحن من الموقع يفتح من نفس التطبيق ويدخل اليوزر والباسورد
 * تلقائي دون ملاحظة الشخص»). The app's signed-in session mints a single-use code (60 s, only its SHA-256 stored); the
 * website top-up page exchanges it once for its own short web session (an access token in the tab's sessionStorage,
 * as after its own sign-in). The password is never involved. The code is honoured only while the minting session is
 * live, the account ACTIVE and not locked, and the session's device not banned — so signing out, a revoked session,
 * a suspension, a deletion request or a device ban void every pending code. Every refusal is the same 410
 * `TOKEN_EXPIRED` (the page then shows its normal sign-in).
 */
@Injectable()
export class TopupHandoffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sessions: SessionsService,
    private readonly accessTokens: AccessTokenService,
    private readonly payments: PaymentSettingsStore,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `POST /wallet/topup-session`. 503 `TOPUP_UNAVAILABLE` when top-ups or the link are off for this platform. */
  async mint(
    userId: string,
    sessionId: string,
    lang: TopupLocale,
    info: HandoffRequestInfo,
  ): Promise<TopupWebsiteSessionDto> {
    const resolved = await this.payments.resolved();
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { platform: true, installSource: true },
    });
    if (
      !resolved.stripe ||
      !appLinkShownFor(session, {
        enabled: resolved.options.appLinkEnabled,
        platforms: this.config.topup.appLinkPlatforms,
        sources: this.config.topup.appLinkSources,
      })
    ) {
      throw new AppException(ErrorCode.TOPUP_UNAVAILABLE);
    }
    const now = this.clock.now();
    const code = generateSecret();
    const expiresAt = new Date(now.getTime() + TOPUP_HANDOFF_TTL_SECONDS * 1000);
    await this.prisma.$transaction(async (tx) => {
      // Bounded table: the caller's old codes go, and a session has one live code at a time.
      await tx.topupHandoff.deleteMany({
        where: { userId, OR: [{ expiresAt: { lte: now } }, { sessionId, consumedAt: null }] },
      });
      const created = await tx.topupHandoff.create({
        data: { userId, sessionId, codeHash: sha256Hex(code), createdAt: now, expiresAt },
        select: { id: true },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.TOPUP_HANDOFF_MINT,
        actorUserId: userId,
        targetType: 'session',
        targetId: sessionId,
        metadata: { handoffId: created.id, platform: session?.platform ?? null },
        ip: info.ip,
        requestId: info.requestId,
      });
    });
    return {
      websiteUrl: `${resolved.stripe.publicBaseUrl}/topup?lang=${lang}#h=${code}`,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** `POST /topup/handoff` (public): the code once → a new web session of the code's account. */
  async exchange(body: unknown, info: HandoffRequestInfo): Promise<TopupHandoffSessionDto> {
    const parsed = exchangeSchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const resolved = await this.payments.resolved();
    if (!resolved.stripe) throw new AppException(ErrorCode.TOPUP_UNAVAILABLE);
    const now = this.clock.now();
    const codeHash = sha256Hex(parsed.data.handoff);
    // Single use: only one request can flip `consumed_at` (row lock of the UPDATE).
    const claimed = await this.prisma.$queryRaw<{ id: string; user_id: string; session_id: string }[]>`
      UPDATE topup_handoffs SET consumed_at = ${now}
       WHERE code_hash = ${codeHash} AND consumed_at IS NULL AND expires_at > ${now}
      RETURNING id, user_id, session_id`;
    const hit = claimed[0];
    if (!hit) {
      const known = await this.prisma.topupHandoff.findUnique({
        where: { codeHash },
        select: { id: true, userId: true, consumedAt: true },
      });
      if (known) {
        await this.refused(known.userId, known.id, known.consumedAt ? 'used' : 'expired', info);
      }
      throw new AppException(ErrorCode.TOKEN_EXPIRED);
    }
    const minting = await this.prisma.session.findUnique({
      where: { id: hit.session_id },
      select: {
        revokedAt: true,
        expiresAt: true,
        absoluteExpiresAt: true,
        deviceHash: true,
        installId: true,
        user: { select: { status: true, profile: { select: { username: true } } } },
      },
    });
    const reason = !minting
      ? 'session_gone'
      : minting.revokedAt !== null || minting.expiresAt <= now || minting.absoluteExpiresAt <= now
        ? 'session_revoked'
        : minting.user.status !== 'ACTIVE'
          ? 'account_not_active'
          : (await activeRestrictionOf(this.prisma, hit.user_id, 'LOCK', now))
            ? 'account_locked'
            : (await activeDeviceBanOf(this.prisma, [minting.deviceHash], now))
              ? 'device_banned'
              : null;
    if (reason !== null || !minting) {
      await this.refused(hit.user_id, hit.id, reason ?? 'session_gone', info);
      throw new AppException(ErrorCode.TOKEN_EXPIRED);
    }
    const web = await this.prisma.$transaction(async (tx) => {
      const issued = await this.sessions.create(
        tx,
        hit.user_id,
        {
          device: { platform: 'web', name: 'Kabso website (app)' },
          ip: info.ip,
          userAgent: info.userAgent,
        },
        now,
      );
      // The app's device stays on the web session (a device ban ends it too; D250).
      await tx.session.update({
        where: { id: issued.sessionId },
        data: { deviceHash: minting.deviceHash, installId: minting.installId },
      });
      await tx.topupHandoff.update({ where: { id: hit.id }, data: { webSessionId: issued.sessionId } });
      await this.audit.recordIn(tx, {
        action: AuditAction.TOPUP_HANDOFF_EXCHANGE,
        actorUserId: hit.user_id,
        targetType: 'session',
        targetId: issued.sessionId,
        metadata: { handoffId: hit.id, appSessionId: hit.session_id },
        ip: info.ip,
        requestId: info.requestId,
      });
      return issued;
    });
    const access = await this.accessTokens.sign({ userId: hit.user_id, sessionId: web.sessionId }, now);
    return {
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      username: minting.user.profile?.username ?? '',
    };
  }

  private async refused(userId: string, handoffId: string, reason: string, info: HandoffRequestInfo) {
    await this.audit.record({
      action: AuditAction.TOPUP_HANDOFF_REFUSED,
      actorUserId: userId,
      targetType: 'topup_handoff',
      targetId: handoffId,
      metadata: { reason },
      ip: info.ip,
      requestId: info.requestId,
    });
  }
}
