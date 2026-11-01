import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma, type KycCheck, type KycPurpose, type KycStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { Notifier } from '../notifications/notifier.js';
import {
  DiditKeyRejectedError,
  DiditRequestError,
  DiditUnreachableError,
  type DiditApi,
} from './didit-api.js';
import { approvedCheckIn } from './kyc-core.js';
import {
  ageOn,
  DECIDED,
  documentHash,
  factsOf,
  KYC_CALLBACK_URL,
  KYC_MIN_AGE,
  KYC_PURPOSES,
  KYC_WEBHOOK_EVENT_RETENTION_DAYS,
  startKycSchema,
  statusOf,
  UNFINISHED,
  UUID_PATTERN,
  verifyWebhook,
  workflowFor,
  type KycSettingsRow,
} from './kyc.rules.js';
import { KycSettingsStore } from './kyc.store.js';

const DAY_MS = 86_400_000;

/** `KycCheck` (openapi v1.80-kyc): what the person sees of a check (no personal field). */
export interface KycCheckDto {
  id: string;
  purpose: KycPurpose;
  status: KycStatus;
  reasons: string[];
  createdAt: string;
  decidedAt: string | null;
}

export type KycRefusal = 'ALREADY_APPROVED' | 'IN_REVIEW' | 'DAILY_LIMIT' | 'ACCOUNT_NOT_ACTIVE';

/** `KycPurposeState`. */
export interface KycPurposeStateDto {
  purpose: KycPurpose;
  /** An approved check counts for this purpose. */
  approved: boolean;
  /** The check shown for this purpose: the approved one, else the newest made for it. */
  check: KycCheckDto | null;
  canStart: boolean;
  refusal: KycRefusal | null;
}

/** `MyKyc` (`getMyKyc`). */
export interface MyKycDto {
  enabled: boolean;
  maxSessionsPerDay: number;
  startedLast24h: number;
  purposes: KycPurposeStateDto[];
}

/** `KycSessionStart` (`startKycSession`). */
export interface KycSessionStartDto {
  check: KycCheckDto;
  url: string;
  callbackUrl: string;
}

export function checkDto(c: KycCheck): KycCheckDto {
  return {
    id: c.id,
    purpose: c.purpose,
    status: c.status,
    reasons: c.status === 'DECLINED' || c.status === 'IN_REVIEW' ? c.reasons : [],
    createdAt: c.createdAt.toISOString(),
    decidedAt: c.decidedAt?.toISOString() ?? null,
  };
}

/** What happened to one delivery (logged; the response is always `{received: true}`). */
export type WebhookOutcome =
  'applied' | 'duplicate' | 'unknown_session' | 'ignored_type' | 'stale' | 'unchanged';

function didit503(err: unknown): never {
  if (err instanceof DiditUnreachableError || err instanceof DiditKeyRejectedError) {
    throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, 'Didit cannot be reached right now.');
  }
  if (err instanceof DiditRequestError) {
    throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, `Didit refused the request (HTTP ${err.status}).`);
  }
  throw err;
}

/**
 * «تأكيد الهوية» (v1.80-kyc, D227, CONVENTIONS §10.77): a person starts a Didit session for one of the three
 * applications; Didit's hosted flow (ID document, passive liveness, 1:1 face match) runs in the app's WebView; the
 * decision arrives by the signed webhook (or the app's «sync» after the flow) and is kept as the minimum; the person
 * is notified. Owns `kyc_checks` and `kyc_webhook_events`.
 */
@Injectable()
export class KycService {
  private readonly logger = new Logger(KycService.name);
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly store: KycSettingsStore,
    private readonly clock: Clock,
  ) {}

  private async startedSince(me: string, since: Date): Promise<number> {
    return this.prisma.kycCheck.count({ where: { userId: me, createdAt: { gte: since } } });
  }

  /** `GET /me/kyc`. */
  async mine(me: string): Promise<MyKycDto> {
    const r = await this.store.resolved();
    const row = r.row;
    const now = this.clock.now();
    const max = row?.maxSessionsPerDay ?? 3;
    const [started, checks, user] = await Promise.all([
      this.startedSince(me, new Date(now.getTime() - DAY_MS)),
      this.prisma.kycCheck.findMany({
        where: { userId: me },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: 50,
      }),
      this.prisma.user.findUnique({ where: { id: me }, select: { status: true, deletedAt: true } }),
    ]);
    const active = !!user && user.deletedAt === null && user.status === 'ACTIVE';
    const purposes: KycPurposeStateDto[] = [];
    for (const purpose of KYC_PURPOSES) {
      const approved = await approvedCheckIn(this.prisma, me, purpose, row);
      const own = checks.find((c) => c.purpose === purpose) ?? null;
      const refusal = this.refusal({ active, approved, own, started, max });
      purposes.push({
        purpose,
        approved: approved !== null,
        check: approved ? checkDto(approved) : own ? checkDto(own) : null,
        canStart: r.enabled && refusal === null,
        refusal,
      });
    }
    return { enabled: r.enabled, maxSessionsPerDay: max, startedLast24h: started, purposes };
  }

  private refusal(v: {
    active: boolean;
    approved: KycCheck | null;
    own: KycCheck | null;
    started: number;
    max: number;
  }): KycRefusal | null {
    if (!v.active) return 'ACCOUNT_NOT_ACTIVE';
    if (v.approved) return 'ALREADY_APPROVED';
    if (v.own?.status === 'IN_REVIEW') return 'IN_REVIEW';
    // An unfinished session is opened again (Didit returns the same one): not a new one, no limit.
    if (v.own && UNFINISHED.has(v.own.status)) return null;
    if (v.started >= v.max) return 'DAILY_LIMIT';
    return null;
  }

  /**
   * `POST /me/kyc/sessions`. Order: 400 body → 503 KYC_UNAVAILABLE (Didit off) → 409 KYC_NOT_ALLOWED (the refusal)
   * → Didit (503 SERVICE_UNAVAILABLE when it fails) → 201 a new check, 200 the unfinished one opened again (Didit
   * returns the session already open for the same person and workflow).
   */
  async start(me: string, body: unknown): Promise<{ created: boolean; result: KycSessionStartDto }> {
    const parsed = startKycSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { purpose, language } = parsed.data;
    const r = await this.store.resolved();
    if (!r.enabled || !r.apiKey) throw new AppException(ErrorCode.KYC_UNAVAILABLE);
    const row = r.row!;
    const workflowId = workflowFor(row, purpose);
    if (!workflowId) throw new AppException(ErrorCode.KYC_UNAVAILABLE);
    const now = this.clock.now();
    const [user, approved, own, started] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { status: true, deletedAt: true } }),
      approvedCheckIn(this.prisma, me, purpose, row),
      this.prisma.kycCheck.findFirst({
        where: { userId: me, purpose },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      }),
      this.startedSince(me, new Date(now.getTime() - DAY_MS)),
    ]);
    const refusal = this.refusal({
      active: !!user && user.deletedAt === null && user.status === 'ACTIVE',
      approved,
      own,
      started,
      max: row.maxSessionsPerDay,
    });
    if (refusal) {
      throw new AppException(ErrorCode.KYC_NOT_ALLOWED, undefined, [{ field: 'purpose', issue: refusal }]);
    }
    const api = this.store.api(r.apiKey);
    const session = await Promise.resolve()
      .then(() =>
        api.createSession({
          workflowId,
          // Didit's «User»: one per person (its duplicate checks and the reuse of an unfinished session use it).
          vendorData: me,
          callback: KYC_CALLBACK_URL,
          language: language ?? null,
          metadata: { purpose },
        }),
      )
      .catch(didit503);
    if (!UUID_PATTERN.test(session.sessionId)) {
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, 'Didit answered an unexpected session id.');
    }
    const sessionId = session.sessionId.toLowerCase();
    const existing = await this.prisma.kycCheck.findUnique({ where: { sessionId } });
    if (existing) {
      if (existing.userId !== me) {
        throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, 'Didit answered a session of another person.');
      }
      return {
        created: false,
        result: { check: checkDto(existing), url: session.url, callbackUrl: KYC_CALLBACK_URL },
      };
    }
    // A new session: if it still is the newest unfinished one of another workflow, it simply stays (it expires at
    // Didit; its webhook still lands on its row).
    if (started >= row.maxSessionsPerDay) {
      throw new AppException(ErrorCode.KYC_NOT_ALLOWED, undefined, [
        { field: 'purpose', issue: 'DAILY_LIMIT' },
      ]);
    }
    const status = statusOf(session.status) ?? 'NOT_STARTED';
    const id = uuidv7(now.getTime());
    let check: KycCheck;
    try {
      check = await this.prisma.$transaction(async (tx) => {
        const made = await tx.kycCheck.create({
          data: {
            id,
            userId: me,
            purpose,
            status: UNFINISHED.has(status) ? status : 'NOT_STARTED',
            sessionId,
            sessionNumber: session.sessionNumber,
            workflowId: (session.workflowId && UUID_PATTERN.test(session.workflowId)
              ? session.workflowId
              : workflowId
            ).toLowerCase(),
            providerStatus: session.status.slice(0, 32),
            createdAt: now,
            updatedAt: now,
          },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.KYC_SESSION_START,
          actorUserId: me,
          targetType: 'kyc_check',
          targetId: id,
          metadata: { purpose, sessionNumber: session.sessionNumber, workflowId },
        });
        return made;
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const raced = await this.prisma.kycCheck.findUnique({ where: { sessionId } });
        if (raced && raced.userId === me) {
          return {
            created: false,
            result: { check: checkDto(raced), url: session.url, callbackUrl: KYC_CALLBACK_URL },
          };
        }
      }
      throw err;
    }
    return {
      created: true,
      result: { check: checkDto(check), url: session.url, callbackUrl: KYC_CALLBACK_URL },
    };
  }

  /**
   * `POST /me/kyc/checks/{checkId}/sync`: after the hosted flow, reads the decision from Didit and applies it like a
   * webhook (for a webhook that is late or lost). 404 another person's check; 503 Didit off or unreachable.
   */
  async sync(me: string, checkId: string): Promise<KycCheckDto> {
    if (!UUID_PATTERN.test(checkId)) throw new AppException(ErrorCode.NOT_FOUND);
    const check = await this.prisma.kycCheck.findUnique({ where: { id: checkId } });
    if (!check || check.userId !== me) throw new AppException(ErrorCode.NOT_FOUND);
    const r = await this.store.resolved();
    if (!r.apiKey || !r.row?.enabled) throw new AppException(ErrorCode.KYC_UNAVAILABLE);
    const api = this.store.api(r.apiKey);
    const decision = await Promise.resolve()
      .then(() => api.decision(check.sessionId))
      .catch(didit503);
    await this.apply(check.sessionId, decision.status, decision.body, this.clock.now(), 'sync');
    const after = await this.prisma.kycCheck.findUniqueOrThrow({ where: { id: check.id } });
    return checkDto(after);
  }

  /**
   * `POST /kyc/didit/webhook` (public, signed). Verifies `X-Timestamp` (±300 s) and `X-Signature-V2` / `X-Signature`
   * with the webhook secret saved in the panel → 401 when not; then `status.updated` / `data.updated` are applied once
   * per `event_id` (a retry is a no-op), an event older than the last one applied is ignored, an unknown session is
   * acknowledged and dropped. 503 when no webhook secret is saved (Didit retries).
   */
  async webhook(
    raw: unknown,
    headers: { timestamp?: string; signatureV2?: string; signature?: string },
  ): Promise<{ received: true }> {
    if (!Buffer.isBuffer(raw)) {
      throw AppException.validation([{ field: 'body', issue: 'invalid_value' }]);
    }
    const r = await this.store.resolved();
    if (!r.webhookSecret) throw new AppException(ErrorCode.KYC_UNAVAILABLE);
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw.toString('utf8'));
    } catch {
      throw AppException.validation([{ field: 'body', issue: 'invalid_value' }]);
    }
    const verdict = verifyWebhook(
      {
        raw,
        parsed,
        timestamp: headers.timestamp,
        signatureV2: headers.signatureV2,
        signature: headers.signature,
      },
      [r.webhookSecret.reveal()],
      this.clock.now().getTime(),
    );
    if (!verdict.ok) {
      this.logger.warn(`Didit webhook refused (${verdict.issue}).`);
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED, 'The webhook signature is not valid.', [
        {
          field:
            verdict.issue === 'missing_timestamp' || verdict.issue === 'stale_timestamp'
              ? 'X-Timestamp'
              : 'X-Signature-V2',
          issue: verdict.issue,
        },
      ]);
    }
    const outcome = await this.receive(parsed);
    this.logger.log(`Didit webhook: ${outcome}.`);
    return { received: true };
  }

  private async receive(body: unknown): Promise<WebhookOutcome> {
    const b = (body ?? {}) as Record<string, unknown>;
    const type = typeof b.webhook_type === 'string' ? b.webhook_type.slice(0, 48) : '';
    const sessionRaw = typeof b.session_id === 'string' ? b.session_id.toLowerCase() : null;
    const sessionId = sessionRaw && UUID_PATTERN.test(sessionRaw) ? sessionRaw : null;
    const status = typeof b.status === 'string' ? b.status.slice(0, 32) : null;
    const eventIdRaw = typeof b.event_id === 'string' && b.event_id !== '' ? b.event_id.slice(0, 64) : null;
    // Without an event id (older payloads): the session, the status and Didit's timestamp identify the delivery.
    const eventId =
      eventIdRaw ??
      `${sessionId ?? 'none'}:${status ?? ''}:${typeof b.timestamp === 'number' || typeof b.timestamp === 'string' ? b.timestamp : ''}`.slice(
        0,
        64,
      );
    const now = this.clock.now();
    const fresh = await this.prisma.kycWebhookEvent.createMany({
      data: [{ eventId, sessionId, type: type || 'unknown', status, receivedAt: now }],
      skipDuplicates: true,
    });
    if (fresh.count === 0) return 'duplicate';
    // Old deliveries are forgotten (Didit retries within minutes).
    await this.prisma.kycWebhookEvent
      .deleteMany({
        where: { receivedAt: { lt: new Date(now.getTime() - KYC_WEBHOOK_EVENT_RETENTION_DAYS * DAY_MS) } },
      })
      .catch(() => undefined);
    if (type !== 'status.updated' && type !== 'data.updated') return 'ignored_type';
    if (!sessionId || !status) return 'unknown_session';
    const createdAt =
      typeof b.created_at === 'number' ? b.created_at : typeof b.timestamp === 'number' ? b.timestamp : null;
    const at = createdAt !== null && Number.isFinite(createdAt) ? new Date(createdAt * 1000) : now;
    return this.apply(sessionId, status, b.decision ?? null, at, 'webhook');
  }

  /**
   * Applies a session status (and its decision when there is one) to the check, in one transaction under the row's
   * lock: older than the last event → ignored; the decision's minimum kept (the document number only as its HMAC);
   * an Approved session under {@link KYC_MIN_AGE} (or without a date of birth) is stored DECLINED; the same document
   * hash on another account flags both (never an automatic decline); the person is notified when the status becomes
   * APPROVED, DECLINED or IN_REVIEW. Audited `kyc.check.decision` (no personal field).
   */
  async apply(
    sessionId: string,
    diditStatus: string,
    decision: unknown,
    at: Date,
    via: 'webhook' | 'sync',
  ): Promise<WebhookOutcome> {
    const next = statusOf(diditStatus);
    const facts = factsOf(diditStatus, decision);
    const key = this.store.documentKey();
    const now = this.clock.now();
    return this.prisma.$transaction(async (tx) => {
      const [locked] = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM kyc_checks WHERE session_id = ${sessionId}::uuid FOR UPDATE`;
      if (!locked) return 'unknown_session';
      const check = await tx.kycCheck.findUniqueOrThrow({ where: { id: locked.id } });
      if (check.lastEventAt && at < check.lastEventAt) return 'stale';
      if (next === null) {
        await tx.kycCheck.update({
          where: { id: check.id },
          data: { providerStatus: facts.providerStatus, lastEventAt: at, updatedAt: now },
        });
        return 'unchanged';
      }
      let status: KycStatus = next;
      const reasons = [...facts.reasons];
      const hasDecision = decision !== null && typeof decision === 'object';
      const data: Prisma.KycCheckUncheckedUpdateInput = {
        providerStatus: facts.providerStatus,
        lastEventAt: at,
        updatedAt: now,
      };
      if (facts.sessionNumber !== null) data.sessionNumber = facts.sessionNumber;
      if (
        hasDecision &&
        (facts.fullName || facts.dateOfBirth || facts.documentCountry || facts.documentNumber)
      ) {
        data.fullName = facts.fullName;
        data.dateOfBirth = facts.dateOfBirth;
        data.documentCountry = facts.documentCountry;
        data.documentHash =
          key && facts.documentNumber ? documentHash(key, facts.documentCountry, facts.documentNumber) : null;
      }
      if (status === 'APPROVED') {
        const dob = facts.dateOfBirth ?? (hasDecision ? null : check.dateOfBirth);
        if (!dob) {
          status = 'DECLINED';
          reasons.push('DATE_OF_BIRTH_MISSING');
        } else if (ageOn(dob, now) < KYC_MIN_AGE) {
          status = 'DECLINED';
          reasons.push('UNDER_MIN_AGE');
        }
      }
      data.status = status;
      data.reasons = status === 'DECLINED' || status === 'IN_REVIEW' ? reasons.slice(0, 20) : [];
      if (DECIDED.has(status))
        data.decidedAt = check.status === status && check.decidedAt ? check.decidedAt : now;
      else data.decidedAt = null;
      // The same document on another account: flagged to the team on both checks.
      const hash = (data.documentHash as string | null | undefined) ?? check.documentHash;
      let duplicateOf: string[] = [];
      if (hash) {
        const others = await tx.kycCheck.findMany({
          where: { documentHash: hash, userId: { not: check.userId } },
          select: { id: true, userId: true },
        });
        duplicateOf = [...new Set(others.map((o) => o.userId))];
        if (others.length > 0) {
          data.duplicateDocument = true;
          await tx.kycCheck.updateMany({
            where: { id: { in: others.map((o) => o.id) } },
            data: { duplicateDocument: true },
          });
        }
      }
      const after = await tx.kycCheck.update({ where: { id: check.id }, data });
      const changed = after.status !== check.status;
      if (changed) {
        await this.audit.recordIn(tx, {
          action: AuditAction.KYC_CHECK_DECISION,
          actorUserId: null,
          targetType: 'kyc_check',
          targetId: check.id,
          metadata: {
            user: check.userId,
            purpose: check.purpose,
            before: check.status,
            after: after.status,
            providerStatus: facts.providerStatus,
            reasons: after.reasons,
            via,
          },
        });
        if (after.status === 'APPROVED' || after.status === 'DECLINED' || after.status === 'IN_REVIEW') {
          const active = await tx.user.count({ where: { id: check.userId, status: 'ACTIVE' } });
          if (active > 0) {
            await this.notifier.system(tx, {
              type:
                after.status === 'APPROVED'
                  ? 'KYC_APPROVED'
                  : after.status === 'DECLINED'
                    ? 'KYC_DECLINED'
                    : 'KYC_IN_REVIEW',
              recipientId: check.userId,
            });
          }
        }
      }
      if (duplicateOf.length > 0 && !check.duplicateDocument) {
        await this.audit.recordIn(tx, {
          action: AuditAction.KYC_DUPLICATE_DOCUMENT,
          actorUserId: null,
          targetType: 'kyc_check',
          targetId: check.id,
          metadata: { user: check.userId, otherUsers: duplicateOf.slice(0, 10), via },
        });
      }
      return changed ? 'applied' : 'unchanged';
    });
  }

  /** For the tests and the panel: the settings row (null when never saved). */
  async settingsRow(): Promise<KycSettingsRow | null> {
    return (await this.store.resolved()).row;
  }

  /** Didit's client now (the panel's media fetch). */
  async apiNow(): Promise<DiditApi | null> {
    const r = await this.store.resolved();
    return r.apiKey ? this.store.api(r.apiKey) : null;
  }
}
