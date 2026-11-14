import { timingSafeEqual } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { Prisma, type IapProduct, type IapPurchase } from '../../generated/prisma/client.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { activeDeviceBanOf, deviceBannedError } from '../auth/device-bans.js';
import { SessionsService } from '../auth/sessions.service.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import { AppleJwsError, verifyAppleJws } from './apple-jws.js';
import {
  consumptionOfIn,
  iapSettingsIn,
  onceLimitReachedIn,
  recordPurchaseIn,
  recordRefundEventIn,
  refundPurchaseIn,
  type PurchaseFacts,
} from './iap-core.js';
import {
  accountTokenOf,
  CONSUMPTION_DEADLINE_MS,
  dollarsBucket,
  PLATFORM_OF,
  refundReasonText,
  tenureBucket,
  tokenHash,
  userStatusCode,
  VOIDED_REASONS,
  VOIDED_SOURCE_DEVELOPER,
  voidedWindow,
  type AppPlatform,
  type IapPlatformName,
} from './iap-rules.js';
import type { VerifyIapInput } from './iap.schemas.js';
import {
  IAP_STORE_CLIENTS,
  StoreApiError,
  type AppleConsumptionBody,
  type IapStoreClients,
} from './store-clients.js';

/** `StoreIapCatalog` (openapi v1.110-social). */
export interface IapCatalogDto {
  available: boolean;
  unavailableReason: 'OFF' | 'DEVICE_BANNED' | 'LIMIT_REACHED' | null;
  platform: AppPlatform;
  products: { productId: string; coins: number }[];
  consentVersion: string;
  oncePerAccountDevice: boolean;
  accountToken: string;
}

/** `StoreIapPurchaseResult`. */
export interface IapPurchaseResultDto {
  purchaseId: string;
  platform: AppPlatform;
  productId: string;
  coins: number;
  status: 'CREDITED' | 'REJECTED' | 'REFUNDED';
  rejectReason: string | null;
  environment: 'PRODUCTION' | 'SANDBOX';
  balance: number;
  alreadyProcessed: boolean;
}

export interface VoidedSyncResult {
  checked: number;
  refunded: number;
  unknown: number;
  from: string;
  to: string;
}

const APP_PLATFORM_OF: Record<IapPlatformName, AppPlatform> = { GOOGLE_PLAY: 'ANDROID', APP_STORE: 'IOS' };
/** How far back an RTDN void triggers a poll (the notification itself is never trusted). */
const RTDN_POLL_BACK_MS = 3 * 86_400_000;
const MAX_CONSUMPTION_ATTEMPTS = 10;

function failed(field: string, issue: string): AppException {
  return new AppException(ErrorCode.STORE_IAP_VERIFICATION_FAILED, undefined, [{ field, issue }]);
}

function isUnique(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

/**
 * v1.110-social (D345, CONVENTIONS §10.144): coins from the stores — the app's catalogue and purchase verification, the
 * App Store's signed notifications (REFUND, CONSUMPTION_REQUEST), Google's RTDN and voided purchases, and the sweeper's
 * steps (the daily voided poll, consumption-request retries, consume retries). Every store answer is verified by the
 * server; the client's word never credits a coin.
 */
@Injectable()
export class IapService {
  private readonly logger = new Logger(IapService.name);
  private voidedRunning: Promise<VoidedSyncResult> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly sessions: SessionsService,
    private readonly lifecycle: AccountLifecycleService,
    private readonly background: BackgroundTasks,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(IAP_STORE_CLIENTS) private readonly clients: IapStoreClients,
  ) {}

  private get iap() {
    return this.config.storeIap;
  }

  private configured(platform: IapPlatformName): boolean {
    return platform === 'GOOGLE_PLAY' ? this.clients.google !== null : this.clients.apple !== null;
  }

  /** Which stores are on, for the panel's overview. */
  status() {
    return {
      googlePlay: {
        configured: this.clients.google !== null,
        packageName: this.iap.google?.packageName ?? null,
        rtdnEnabled: this.clients.google !== null && (this.iap.google?.rtdnToken ?? null) !== null,
      },
      appStore: {
        configured: this.clients.apple !== null,
        bundleId: this.iap.apple?.bundleId ?? null,
        roots: this.clients.apple?.roots.length ?? 0,
      },
      acceptSandbox: this.iap.acceptSandbox,
      voidedPollHours: this.iap.voidedPollHours,
      consentVersion: this.iap.consentVersion,
    };
  }

  private async sessionDevice(sessionId: string): Promise<string | null> {
    const s = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { deviceHash: true },
    });
    return s?.deviceHash?.trim() ?? null;
  }

  // ---- the app ---------------------------------------------------------------------------------------------------

  async catalog(userId: string, sessionId: string, platform: AppPlatform): Promise<IapCatalogDto> {
    const store = PLATFORM_OF[platform];
    const settings = await iapSettingsIn(this.prisma);
    const base: IapCatalogDto = {
      available: false,
      unavailableReason: 'OFF',
      platform,
      products: [],
      consentVersion: this.iap.consentVersion,
      oncePerAccountDevice: settings.oncePerAccountDevice,
      accountToken: accountTokenOf(platform, userId),
    };
    if (!this.configured(store)) return base;
    const device = await this.sessionDevice(sessionId);
    if (await activeDeviceBanOf(this.prisma, [device], this.clock.now())) {
      return { ...base, unavailableReason: 'DEVICE_BANNED' };
    }
    if (settings.oncePerAccountDevice && (await onceLimitReachedIn(this.prisma, userId, device))) {
      return { ...base, unavailableReason: 'LIMIT_REACHED' };
    }
    const products = await this.prisma.iapProduct.findMany({
      where: { platform: store, enabled: true },
      orderBy: [{ sortOrder: 'asc' }, { coins: 'asc' }],
    });
    return {
      ...base,
      available: products.length > 0,
      unavailableReason: products.length > 0 ? null : 'OFF',
      products: products.map((p) => ({ productId: p.productId, coins: Number(p.coins) })),
    };
  }

  private async balanceOf(userId: string): Promise<number> {
    const w = await this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } });
    return Number(w?.coins ?? 0n);
  }

  private async resultOf(p: IapPurchase, alreadyProcessed: boolean): Promise<IapPurchaseResultDto> {
    return {
      purchaseId: p.id,
      platform: APP_PLATFORM_OF[p.platform],
      productId: p.productId,
      coins: Number(p.coins),
      status: p.status,
      rejectReason: p.rejectReason,
      environment: p.environment,
      balance: await this.balanceOf(p.userId),
      alreadyProcessed,
    };
  }

  /** The stored purchase when it was verified before: the same account gets it back, another gets 409. */
  private async existing(
    userId: string,
    where: Prisma.IapPurchaseWhereInput,
  ): Promise<IapPurchaseResultDto | null> {
    const found = await this.prisma.iapPurchase.findFirst({ where });
    if (!found) return null;
    if (found.userId !== userId) throw new AppException(ErrorCode.STORE_IAP_PURCHASE_CONFLICT);
    return this.resultOf(found, true);
  }

  async verify(
    userId: string,
    sessionId: string,
    input: VerifyIapInput,
    locale: string | null,
  ): Promise<IapPurchaseResultDto> {
    const store = PLATFORM_OF[input.platform];
    if (!this.configured(store)) throw new AppException(ErrorCode.STORE_IAP_UNAVAILABLE);
    const now = this.clock.now();
    const sessionHash = await this.sessionDevice(sessionId);
    const bodyHash = this.sessions.deviceHashOf(input.device?.deviceKey);
    const ban = await activeDeviceBanOf(this.prisma, [sessionHash, bodyHash], now);
    if (ban) throw deviceBannedError(ban);
    if (input.consent.version !== this.iap.consentVersion) {
      throw AppException.validation([{ field: 'consent.version', issue: 'stale' }]);
    }
    const product = await this.prisma.iapProduct.findUnique({
      where: { platform_productId: { platform: store, productId: input.productId } },
    });
    if (!product) throw failed('productId', 'unknown');
    const deviceHash = sessionHash ?? bodyHash;
    const consent = { version: input.consent.version, shareData: input.consent.shareConsumptionData, locale };
    const facts =
      store === 'GOOGLE_PLAY'
        ? await this.googleFacts(userId, product, input.purchaseToken!)
        : this.appleFacts(userId, product, input.signedTransaction!, now);
    if ('done' in facts) return facts.done;
    const settings = await iapSettingsIn(this.prisma);
    const limited =
      settings.oncePerAccountDevice && (await onceLimitReachedIn(this.prisma, userId, deviceHash));
    const full: PurchaseFacts = {
      ...facts.facts,
      userId,
      product,
      deviceHash,
      consent,
      reject: limited && store === 'GOOGLE_PLAY' ? 'ONCE_LIMIT' : null,
      limitExceeded: limited && store === 'APP_STORE',
    };
    let recorded: IapPurchase;
    try {
      recorded = (
        await this.prisma.$transaction((tx) =>
          recordPurchaseIn(
            tx,
            full,
            { ...this.config.recharge.badges, cherriesPerCoin: this.config.economy.cherriesPerCoin },
            now,
          ),
        )
      ).purchase;
    } catch (err) {
      if (!isUnique(err)) throw err;
      // A concurrent verification of the same purchase won: answer with its result.
      const again = await this.existing(userId, {
        platform: store,
        OR: [
          { transactionId: full.transactionId },
          ...(full.purchaseTokenHash ? [{ purchaseTokenHash: full.purchaseTokenHash }] : []),
        ],
      });
      if (again) return again;
      throw err;
    }
    if (store === 'GOOGLE_PLAY' && recorded.status === 'CREDITED') await this.consume(recorded);
    return this.resultOf(recorded, false);
  }

  private async googleFacts(
    userId: string,
    product: IapProduct,
    token: string,
  ): Promise<
    | { done: IapPurchaseResultDto }
    | {
        facts: Omit<
          PurchaseFacts,
          'userId' | 'product' | 'deviceHash' | 'consent' | 'reject' | 'limitExceeded'
        >;
      }
  > {
    const hash = tokenHash(token);
    const before = await this.existing(userId, { platform: 'GOOGLE_PLAY', purchaseTokenHash: hash });
    if (before) return { done: before };
    let gp;
    try {
      gp = await this.clients.google!.getProductPurchase(product.productId, token);
    } catch (err) {
      if (err instanceof StoreApiError && err.status >= 400 && err.status < 500) {
        throw failed('purchaseToken', 'rejected');
      }
      this.logger.warn({ error: safeErrorLog(err) }, 'Google Play verification unavailable');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    if (gp.purchaseState === 2) throw new AppException(ErrorCode.STORE_IAP_PENDING);
    if (gp.purchaseState !== 0) throw failed('purchaseToken', 'not_purchased');
    if (
      gp.obfuscatedExternalAccountId !== undefined &&
      gp.obfuscatedExternalAccountId !== accountTokenOf('ANDROID', userId)
    ) {
      throw new AppException(ErrorCode.STORE_IAP_PURCHASE_CONFLICT);
    }
    const sandbox = gp.purchaseType === 0;
    if (sandbox && !this.iap.acceptSandbox) throw failed('environment', 'sandbox');
    const transactionId = str(gp.orderId) ?? `token:${hash}`;
    const dup = await this.existing(userId, { platform: 'GOOGLE_PLAY', transactionId });
    if (dup) return { done: dup };
    const ms = Number(gp.purchaseTimeMillis);
    return {
      facts: {
        platform: 'GOOGLE_PLAY',
        transactionId,
        originalTransactionId: null,
        purchaseToken: token,
        purchaseTokenHash: hash,
        environment: sandbox ? 'SANDBOX' : 'PRODUCTION',
        priceMilli: null,
        currency: null,
        purchasedAt: Number.isFinite(ms) && ms > 0 ? new Date(ms) : this.clock.now(),
      },
    };
  }

  private appleFacts(
    userId: string,
    product: IapProduct,
    jws: string,
    now: Date,
  ):
    | { done: IapPurchaseResultDto }
    | {
        facts: Omit<
          PurchaseFacts,
          'userId' | 'product' | 'deviceHash' | 'consent' | 'reject' | 'limitExceeded'
        >;
      } {
    const tx = this.verifyApple(jws, now, 'signedTransaction');
    if (tx.bundleId !== this.iap.apple!.bundleId) throw failed('signedTransaction', 'bundle');
    if (tx.productId !== product.productId) throw failed('productId', 'mismatch');
    if (tx.type !== 'Consumable') throw failed('signedTransaction', 'type');
    if (tx.revocationDate !== undefined) throw failed('signedTransaction', 'revoked');
    const env = this.appleEnvironment(tx.environment);
    if (env === null) throw failed('environment', 'sandbox');
    const account = str(tx.appAccountToken);
    if (account !== null && account.toLowerCase() !== accountTokenOf('IOS', userId)) {
      throw new AppException(ErrorCode.STORE_IAP_PURCHASE_CONFLICT);
    }
    const transactionId = str(tx.transactionId);
    if (!transactionId || !/^[0-9A-Za-z._-]{1,200}$/.test(transactionId)) {
      throw failed('signedTransaction', 'transaction');
    }
    const price = typeof tx.price === 'number' && Number.isSafeInteger(tx.price) ? BigInt(tx.price) : null;
    const currency = str(tx.currency);
    const purchased = typeof tx.purchaseDate === 'number' ? new Date(tx.purchaseDate) : now;
    return {
      facts: {
        platform: 'APP_STORE',
        transactionId,
        originalTransactionId: str(tx.originalTransactionId),
        purchaseToken: null,
        purchaseTokenHash: null,
        environment: env,
        priceMilli: price,
        currency: currency && /^[A-Z]{3}$/.test(currency) ? currency : null,
        purchasedAt: purchased,
      },
    };
  }

  /** Synchronous lookup is not possible (Prisma is async): {@link verify} checks the transaction id right after. */
  private verifyApple(jws: string, now: Date, field: string): Record<string, unknown> {
    try {
      return verifyAppleJws(jws, this.clients.apple!.roots, now);
    } catch (err) {
      if (err instanceof AppleJwsError) throw failed(field, err.issue);
      throw err;
    }
  }

  /** PRODUCTION, SANDBOX (when accepted) or null (refused). */
  private appleEnvironment(env: unknown): 'PRODUCTION' | 'SANDBOX' | null {
    if (env === 'Production') return 'PRODUCTION';
    if ((env === 'Sandbox' || env === 'Xcode' || env === 'LocalTesting') && this.iap.acceptSandbox)
      return 'SANDBOX';
    return null;
  }

  /** Consumes a credited Google purchase (consuming also acknowledges); a failure is left to the sweeper. */
  private async consume(p: IapPurchase): Promise<boolean> {
    if (!this.clients.google || !p.purchaseToken) return false;
    try {
      await this.clients.google.consume(p.productId, p.purchaseToken);
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err), purchase: p.id },
        'Google Play consume failed (retried later)',
      );
      return false;
    }
    await this.prisma.iapPurchase.update({ where: { id: p.id }, data: { consumedAt: this.clock.now() } });
    return true;
  }

  // ---- App Store Server Notifications v2 -------------------------------------------------------------------------

  async appleNotification(signedPayload: string): Promise<{ received: true }> {
    if (!this.clients.apple) throw new AppException(ErrorCode.STORE_IAP_UNAVAILABLE);
    const now = this.clock.now();
    const payload = this.verifyApple(signedPayload, now, 'signedPayload');
    const type = str(payload.notificationType) ?? 'UNKNOWN';
    const subtype = str(payload.subtype);
    const uuid = str(payload.notificationUUID);
    const data = (typeof payload.data === 'object' && payload.data !== null ? payload.data : {}) as Record<
      string,
      unknown
    >;
    if (!uuid) throw failed('signedPayload', 'notificationUUID');
    const apple = this.iap.apple!;
    if (data.bundleId !== undefined && data.bundleId !== apple.bundleId)
      throw failed('signedPayload', 'bundle');
    const appId =
      typeof data.appAppleId === 'number' || typeof data.appAppleId === 'string'
        ? String(data.appAppleId)
        : null;
    if (apple.appAppleId && appId !== null && appId !== apple.appAppleId) {
      throw failed('signedPayload', 'app');
    }
    let tx: Record<string, unknown> | null = null;
    const signedTx = str(data.signedTransactionInfo);
    if (signedTx) {
      tx = this.verifyApple(signedTx, now, 'signedTransactionInfo');
      if (tx.bundleId !== apple.bundleId) throw failed('signedTransactionInfo', 'bundle');
    }
    const transactionId = tx ? str(tx.transactionId) : null;
    const env = this.appleEnvironment(data.environment ?? tx?.environment);
    let sendConsumption: string | null = null;
    try {
      await this.prisma.$transaction(async (db) => {
        const outcome = env === null ? 'sandbox_ignored' : await this.applyApple(db, type, uuid, tx, now);
        if (outcome.startsWith('consumption:')) sendConsumption = outcome.slice('consumption:'.length);
        await db.iapNotification.create({
          data: {
            platform: 'APP_STORE',
            notificationId: uuid,
            type: type.slice(0, 64),
            subtype: subtype?.slice(0, 64) ?? null,
            transactionId: transactionId?.slice(0, 200) ?? null,
            outcome: (outcome.startsWith('consumption:') ? 'consumption_pending' : outcome).slice(0, 64),
            receivedAt: now,
          },
        });
      });
    } catch (err) {
      if (isUnique(err)) return { received: true }; // already applied (a retry of the same notification)
      throw err;
    }
    if (sendConsumption) await this.sendConsumption(sendConsumption);
    return { received: true };
  }

  /** One notification's effect inside its transaction; returns the outcome recorded. */
  private async applyApple(
    db: Prisma.TransactionClient,
    type: string,
    uuid: string,
    tx: Record<string, unknown> | null,
    now: Date,
  ): Promise<string> {
    const transactionId = tx ? str(tx.transactionId) : null;
    const purchase = transactionId
      ? await db.iapPurchase.findUnique({
          where: { platform_transactionId: { platform: 'APP_STORE', transactionId } },
        })
      : null;
    if (type === 'REFUND') {
      if (!purchase) {
        await recordRefundEventIn(db, null, {
          platform: 'APP_STORE',
          type,
          transaction: transactionId,
          known: false,
        });
        return 'refund_unknown';
      }
      const at = typeof tx?.revocationDate === 'number' ? new Date(tx.revocationDate) : now;
      const reasonCode =
        typeof tx?.revocationReason === 'number' ? `revocationReason ${tx.revocationReason}` : null;
      const result = await refundPurchaseIn(
        db,
        purchase.id,
        {
          source: 'APPLE_REFUND',
          refundedAt: at,
          reasonText: refundReasonText('APP_STORE', at, purchase.transactionId, reasonCode),
          ban: true,
          detail: {
            notification: uuid,
            revocationReason: (tx?.revocationReason as number | undefined) ?? null,
          },
        },
        (t, userId) => this.lifecycle.suspendIn(t, userId),
        now,
      );
      if (!result.applied) {
        await recordRefundEventIn(db, purchase.id, { platform: 'APP_STORE', type, status: purchase.status });
        return 'refund_not_credited';
      }
      return 'refunded';
    }
    if (type === 'CONSUMPTION_REQUEST') {
      const id = await this.openConsumptionIn(db, uuid, transactionId ?? '', purchase, now);
      return id ? `consumption:${id}` : purchase ? 'consumption_no_consent' : 'consumption_unknown';
    }
    if (type === 'REFUND_DECLINED' || type === 'REFUND_REVERSED') {
      await recordRefundEventIn(db, purchase?.id ?? null, {
        platform: 'APP_STORE',
        type,
        transaction: transactionId,
        known: purchase !== null,
      });
      return type.toLowerCase();
    }
    return 'recorded';
  }

  /**
   * Stores a CONSUMPTION_REQUEST with its context; returns its id when it is to be sent (the buyer consented), else
   * null (`SKIPPED_NO_CONSENT` / `SKIPPED_UNKNOWN`: Apple is not answered).
   */
  private async openConsumptionIn(
    db: Prisma.TransactionClient,
    uuid: string,
    transactionId: string,
    purchase: IapPurchase | null,
    now: Date,
  ): Promise<string | null> {
    const deadline = new Date(now.getTime() + CONSUMPTION_DEADLINE_MS);
    if (!purchase) {
      await db.iapConsumptionRequest.create({
        data: {
          notificationId: uuid,
          transactionId: transactionId.slice(0, 200),
          status: 'SKIPPED_UNKNOWN',
          receivedAt: now,
          deadlineAt: deadline,
        },
      });
      return null;
    }
    const context = await this.consumptionContextIn(db, purchase, now);
    const row = await db.iapConsumptionRequest.create({
      data: {
        notificationId: uuid,
        purchaseId: purchase.id,
        transactionId: purchase.transactionId,
        status: purchase.consentShareData ? 'PENDING' : 'SKIPPED_NO_CONSENT',
        context,
        receivedAt: now,
        deadlineAt: deadline,
      },
    });
    await db.auditLog.create({
      data: {
        action: AuditAction.STORE_IAP_CONSUMPTION,
        targetType: 'iap_purchase',
        targetId: purchase.id,
        metadata: { request: row.id, status: row.status, via: 'system' },
      },
    });
    return purchase.consentShareData ? row.id : null;
  }

  /** ConsumptionRequestV1's facts, kept for the team (not sent: Apple's current body has no such fields). */
  private async consumptionContextIn(db: Prisma.TransactionClient, p: IapPurchase, now: Date) {
    const user = await db.user.findUnique({
      where: { id: p.userId },
      select: { createdAt: true, status: true },
    });
    const rows = await db.$queryRaw<{ status: string; cents: bigint | null }[]>`
      SELECT p.status::text AS status, sum(COALESCE(sp.reference_usd_cents, 0))::bigint AS cents
        FROM iap_purchases p JOIN iap_products sp ON sp.id = p.store_product_id
       WHERE p.user_id = ${p.userId}::uuid AND p.status IN ('CREDITED', 'REFUNDED')
       GROUP BY p.status`;
    const purchased = rows.reduce((n, r) => n + Number(r.cents ?? 0n), 0);
    const refunded = Number(rows.find((r) => r.status === 'REFUNDED')?.cents ?? 0n);
    const days = user ? Math.floor((now.getTime() - user.createdAt.getTime()) / 86_400_000) : 0;
    return {
      accountTenure: tenureBucket(days),
      lifetimeDollarsPurchased: dollarsBucket(purchased),
      lifetimeDollarsRefunded: dollarsBucket(refunded),
      userStatus: userStatusCode(user?.status ?? ''),
      playTime: 0,
      platform: 1,
    };
  }

  /** Sends (or retries) one consumption request; never throws (a failure is recorded and retried by the sweeper). */
  async sendConsumption(requestId: string): Promise<'SENT' | 'FAILED' | 'PENDING' | 'SKIPPED'> {
    const now = this.clock.now();
    const row = await this.prisma.iapConsumptionRequest.findUnique({
      where: { id: requestId },
      include: { purchase: true },
    });
    if (!row || row.status !== 'PENDING' || !row.purchase || !this.clients.apple) return 'SKIPPED';
    if (!row.purchase.consentShareData) return 'SKIPPED';
    if (row.deadlineAt.getTime() <= now.getTime()) {
      await this.prisma.iapConsumptionRequest.update({
        where: { id: row.id },
        data: { status: 'FAILED', lastError: 'deadline passed' },
      });
      return 'FAILED';
    }
    const delivered = row.purchase.status !== 'REJECTED';
    const percentage = delivered ? await consumptionOfIn(this.prisma, row.purchase) : 0;
    const body: AppleConsumptionBody = delivered
      ? {
          customerConsented: true,
          consumptionPercentage: percentage,
          deliveryStatus: 'DELIVERED',
          refundPreference: 'DECLINE',
          sampleContentProvided: false,
        }
      : {
          customerConsented: true,
          consumptionPercentage: 0,
          deliveryStatus: 'UNDELIVERED_OTHER',
          sampleContentProvided: false,
        };
    try {
      await this.clients.apple.api.sendConsumption(
        row.purchase.transactionId,
        row.purchase.environment === 'SANDBOX',
        body,
      );
    } catch (err) {
      const attempts = row.attempts + 1;
      const status = attempts >= MAX_CONSUMPTION_ATTEMPTS ? 'FAILED' : 'PENDING';
      await this.prisma.iapConsumptionRequest.update({
        where: { id: row.id },
        data: {
          attempts,
          status,
          payload: body as unknown as Prisma.InputJsonObject,
          lastError: (err instanceof StoreApiError ? `HTTP ${err.status}` : 'error').slice(0, 300),
        },
      });
      return status;
    }
    await this.prisma.$transaction(async (db) => {
      await db.iapConsumptionRequest.update({
        where: { id: row.id },
        data: {
          status: 'SENT',
          attempts: row.attempts + 1,
          payload: body as unknown as Prisma.InputJsonObject,
          sentAt: now,
          lastError: null,
        },
      });
      await db.auditLog.create({
        data: {
          action: AuditAction.STORE_IAP_CONSUMPTION,
          targetType: 'iap_purchase',
          targetId: row.purchase!.id,
          metadata: {
            request: row.id,
            status: 'SENT',
            consumptionPercentage: body.consumptionPercentage,
            deliveryStatus: body.deliveryStatus,
            refundPreference: body.refundPreference ?? null,
            via: 'system',
          },
        },
      });
    });
    return 'SENT';
  }

  // ---- Google Play: RTDN and voided purchases ---------------------------------------------------------------------

  async googleRtdn(
    token: string | undefined,
    body: { message: Record<string, unknown> },
  ): Promise<{ received: true }> {
    const expected = this.iap.google?.rtdnToken ?? null;
    if (!this.clients.google || expected === null) throw new AppException(ErrorCode.STORE_IAP_UNAVAILABLE);
    const a = Buffer.from(token ?? '');
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const messageId = str(body.message.messageId) ?? str(body.message.message_id);
    let note: Record<string, unknown> = {};
    try {
      const raw = str(body.message.data);
      if (raw) note = JSON.parse(Buffer.from(raw, 'base64').toString('utf8')) as Record<string, unknown>;
    } catch {
      note = {};
    }
    const type = note.voidedPurchaseNotification
      ? 'VOIDED_PURCHASE'
      : note.oneTimeProductNotification
        ? 'ONE_TIME_PRODUCT'
        : note.testNotification
          ? 'TEST'
          : note.subscriptionNotification
            ? 'SUBSCRIPTION'
            : 'UNKNOWN';
    const ours = note.packageName === undefined || note.packageName === this.iap.google!.packageName;
    const outcome = !ours ? 'other_package' : type === 'VOIDED_PURCHASE' ? 'poll_triggered' : 'recorded';
    if (messageId) {
      try {
        await this.prisma.iapNotification.create({
          data: {
            platform: 'GOOGLE_PLAY',
            notificationId: messageId,
            type,
            outcome,
            receivedAt: this.clock.now(),
          },
        });
      } catch (err) {
        if (isUnique(err)) return { received: true };
        throw err;
      }
    }
    if (outcome === 'poll_triggered') {
      // The notification only triggers a poll: what is refunded is what the Voided Purchases API says.
      this.background.run('iap:rtdn-voided-poll', async () => {
        await this.syncVoided({ backMs: RTDN_POLL_BACK_MS });
      });
    }
    return { received: true };
  }

  /**
   * Polls Google's voided purchases (≤ 30 days, paged) and refunds each matching credited purchase once. One poll at a
   * time in this process (a concurrent call waits for it); the refund itself is idempotent across processes.
   */
  async syncVoided(options: { backMs?: number } = {}): Promise<VoidedSyncResult> {
    if (!this.clients.google) throw new AppException(ErrorCode.STORE_IAP_UNAVAILABLE);
    if (this.voidedRunning) return this.voidedRunning;
    this.voidedRunning = this.runVoided(options.backMs ?? null).finally(() => {
      this.voidedRunning = null;
    });
    return this.voidedRunning;
  }

  private async runVoided(backMs: number | null): Promise<VoidedSyncResult> {
    const now = this.clock.now();
    const settings = await iapSettingsIn(this.prisma);
    const [start, end] = voidedWindow(settings.voidedPolledUntil, now, backMs);
    const result: VoidedSyncResult = {
      checked: 0,
      refunded: 0,
      unknown: 0,
      from: new Date(start).toISOString(),
      to: new Date(end).toISOString(),
    };
    try {
      let page: string | null = null;
      for (let i = 0; i < 100; i += 1) {
        const { voided, nextPageToken } = await this.clients.google!.listVoided(start, end, page);
        for (const v of voided) {
          result.checked += 1;
          if (await this.applyVoided(v, now)) result.refunded += 1;
          else if (!(await this.knownVoided(v))) result.unknown += 1;
        }
        if (!nextPageToken) break;
        page = nextPageToken;
      }
    } catch (err) {
      await this.prisma.iapSettings.update({
        where: { id: 1 },
        data: {
          voidedLastRunAt: now,
          voidedLastError: err instanceof StoreApiError ? `HTTP ${err.status}` : 'error',
        },
      });
      throw err instanceof StoreApiError ? new AppException(ErrorCode.SERVICE_UNAVAILABLE) : err;
    }
    const until =
      backMs === null || settings.voidedPolledUntil === null ? new Date(end) : settings.voidedPolledUntil; // a short RTDN poll never moves the full poll's mark
    await this.prisma.iapSettings.update({
      where: { id: 1 },
      data: {
        voidedPolledUntil: backMs === null ? new Date(end) : until,
        voidedLastRunAt: now,
        voidedLastError: null,
      },
    });
    if (result.refunded > 0) this.logger.log({ ...result }, 'Google voided purchases applied');
    return result;
  }

  private voidedWhere(v: { orderId?: string; purchaseToken: string }): Prisma.IapPurchaseWhereInput {
    return {
      platform: 'GOOGLE_PLAY',
      OR: [
        ...(v.orderId ? [{ transactionId: v.orderId }] : []),
        { purchaseTokenHash: tokenHash(v.purchaseToken) },
      ],
    };
  }

  private async knownVoided(v: { orderId?: string; purchaseToken: string }): Promise<boolean> {
    return (await this.prisma.iapPurchase.count({ where: this.voidedWhere(v) })) > 0;
  }

  private async applyVoided(
    v: {
      orderId?: string;
      purchaseToken: string;
      voidedTimeMillis: string;
      voidedSource?: number;
      voidedReason?: number;
    },
    now: Date,
  ): Promise<boolean> {
    const purchase = await this.prisma.iapPurchase.findFirst({ where: this.voidedWhere(v) });
    if (!purchase || purchase.status !== 'CREDITED') return false;
    const ms = Number(v.voidedTimeMillis);
    const at = Number.isFinite(ms) && ms > 0 ? new Date(ms) : now;
    const reasonName = v.voidedReason !== undefined ? (VOIDED_REASONS[v.voidedReason] ?? null) : null;
    const developer = v.voidedSource === VOIDED_SOURCE_DEVELOPER;
    const result = await this.prisma.$transaction((tx) =>
      refundPurchaseIn(
        tx,
        purchase.id,
        {
          source: 'GOOGLE_VOIDED',
          refundedAt: at,
          reasonText: refundReasonText(
            'GOOGLE_PLAY',
            at,
            v.orderId ?? purchase.transactionId,
            developer ? 'developer' : reasonName,
          ),
          ban: !developer,
          detail: {
            voidedSource: v.voidedSource ?? null,
            voidedReason: v.voidedReason ?? null,
            reason: reasonName,
          },
        },
        (t, userId) => this.lifecycle.suspendIn(t, userId),
        now,
      ),
    );
    return result.applied;
  }

  // ---- the sweeper ------------------------------------------------------------------------------------------------

  /** One sweeper step: the due voided poll, pending consumption requests, unconsumed Google purchases. */
  async sweep(): Promise<{ voided: boolean; consumptions: number; consumed: number }> {
    const now = this.clock.now();
    let voided = false;
    if (this.clients.google && this.iap.voidedPollHours > 0) {
      const s = await iapSettingsIn(this.prisma);
      const due =
        !s.voidedLastRunAt ||
        now.getTime() - s.voidedLastRunAt.getTime() >= this.iap.voidedPollHours * 3_600_000;
      if (due) {
        try {
          await this.syncVoided();
          voided = true;
        } catch (err) {
          this.logger.warn({ error: safeErrorLog(err) }, 'Google voided poll failed (retried next tick)');
        }
      }
    }
    let consumptions = 0;
    const pending = await this.prisma.iapConsumptionRequest.findMany({
      where: { status: 'PENDING' },
      select: { id: true },
      take: 50,
    });
    for (const r of pending) if ((await this.sendConsumption(r.id)) === 'SENT') consumptions += 1;
    let consumed = 0;
    if (this.clients.google) {
      const left = await this.prisma.iapPurchase.findMany({
        where: { platform: 'GOOGLE_PLAY', status: 'CREDITED', consumedAt: null },
        take: 50,
      });
      for (const p of left) if (await this.consume(p)) consumed += 1;
    }
    return { voided, consumptions, consumed };
  }
}
