import { Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AppRequest } from '../../common/http/request-context.js';
import { Clock } from '../../common/time/clock.js';
import type { LegalDocumentKind } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { RequestMeta } from '../auth/auth.service.js';
import {
  currentLegalDocuments,
  LEGAL_VERSION,
  legalDocumentDto,
  pendingLegalDocumentsIn,
  recordDocumentConsentsIn,
  type LegalDocumentDto,
  type LegalDocumentRow,
} from './legal.js';

import { CONSENT_EXEMPT_KEY } from './consent-exempt.decorator.js';
export { ConsentExempt } from './consent-exempt.decorator.js';

/** `AcceptConsentsRequest` (openapi v1.66-social). */
export const acceptConsentsSchema = z.strictObject({
  accept: z
    .array(
      z.strictObject({
        kind: z.enum(['TERMS', 'PRIVACY']),
        version: z.string().regex(LEGAL_VERSION),
      }),
    )
    .min(1)
    .max(2)
    .refine((list) => new Set(list.map((d) => d.kind)).size === list.length, {
      params: { issue: 'duplicate' },
    }),
});
export type AcceptConsentsInput = z.output<typeof acceptConsentsSchema>;

/** `ConsentStatus` (openapi). */
export interface ConsentStatusDto {
  /** The versions in force the caller still has to accept (empty: nothing to do). */
  required: LegalDocumentDto[];
  /** Every version in force (one per kind that has taken effect). */
  current: LegalDocumentDto[];
  accepted: { document: string; version: string; acceptedAt: string; method: string }[];
}

/** How long the versions in force are cached per process (a new version is enforced within this delay). */
const CURRENT_TTL_MS = 30_000;
/** How long a user's "accepted everything in force" is remembered (keyed by the documents' ids). */
const ACCEPTED_TTL_MS = 10 * 60_000;
const ACCEPTED_MAX = 50_000;

/**
 * v1.66-social (D198, CONVENTIONS §10.61.2): consent to the terms and the privacy policy in force. `getLegalDocuments`
 * (public), `getMyConsents`, `acceptConsents`, and the gate behind {@link ConsentGuard}.
 */
@Injectable()
export class ConsentsService {
  private current: { at: number; docs: Partial<Record<LegalDocumentKind, LegalDocumentRow>> } | null = null;
  /** `${userId}:${docIds}` → time remembered. Only positive answers are cached (never stale after accepting). */
  private readonly accepted = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
  ) {}

  /** The versions in force (cached {@link CURRENT_TTL_MS}). */
  async inForce(): Promise<Partial<Record<LegalDocumentKind, LegalDocumentRow>>> {
    const now = this.clock.now();
    if (this.current && now.getTime() - this.current.at < CURRENT_TTL_MS) {
      // A cached version that has not taken effect yet is never returned: effective_at is checked per call.
      return this.current.docs;
    }
    const docs = await currentLegalDocuments(this.prisma, now);
    this.current = { at: now.getTime(), docs };
    return docs;
  }

  /** Drops the cache (tests, after `legal-admin publish` in the same process). */
  forget(): void {
    this.current = null;
    this.accepted.clear();
  }

  /** `GET /legal/documents` (public): the versions in force. */
  async documents(): Promise<{ documents: LegalDocumentDto[] }> {
    const docs = await this.inForce();
    return {
      documents: (['TERMS', 'PRIVACY'] as const).flatMap((k) => (docs[k] ? [legalDocumentDto(docs[k])] : [])),
    };
  }

  /** The gate: true when the user accepted every version in force. */
  async satisfied(userId: string): Promise<{ ok: true } | { ok: false; pending: LegalDocumentRow[] }> {
    const docs = await this.inForce();
    const inForce = (['TERMS', 'PRIVACY'] as const).flatMap((k) => (docs[k] ? [docs[k]] : []));
    if (inForce.length === 0) return { ok: true };
    const key = `${userId}:${inForce.map((d) => d.id).join(',')}`;
    const seen = this.accepted.get(key);
    const now = Date.now();
    if (seen !== undefined && now - seen < ACCEPTED_TTL_MS) return { ok: true };
    const pending = await pendingLegalDocumentsIn(this.prisma, userId, docs);
    if (pending.length > 0) return { ok: false, pending };
    if (this.accepted.size >= ACCEPTED_MAX) this.accepted.clear();
    this.accepted.set(key, now);
    return { ok: true };
  }

  /** `GET /me/consents`. */
  async status(userId: string): Promise<ConsentStatusDto> {
    const docs = await this.inForce();
    const pending = await pendingLegalDocumentsIn(this.prisma, userId, docs);
    const rows = await this.prisma.userConsent.findMany({
      where: { userId },
      orderBy: { acceptedAt: 'desc' },
      take: 50,
      select: { document: true, version: true, acceptedAt: true, method: true },
    });
    return {
      required: pending.map(legalDocumentDto),
      current: (['TERMS', 'PRIVACY'] as const).flatMap((k) => (docs[k] ? [legalDocumentDto(docs[k])] : [])),
      accepted: rows.map((r) => ({
        document: r.document,
        version: r.version,
        acceptedAt: r.acceptedAt.toISOString(),
        method: r.method,
      })),
    };
  }

  /**
   * `POST /me/consents`: records the acceptance of the named versions, which must be the ones in force (409
   * CONSENT_VERSION_MISMATCH otherwise: a newer version took effect while the screen was open). Idempotent.
   */
  async accept(userId: string, input: AcceptConsentsInput, meta: RequestMeta): Promise<ConsentStatusDto> {
    // Always read the versions in force from the database here (never a stale cache for a write).
    const docs = await currentLegalDocuments(this.prisma, this.clock.now());
    const chosen: LegalDocumentRow[] = [];
    for (const want of input.accept) {
      const doc = docs[want.kind];
      if (!doc || doc.version !== want.version) {
        throw new AppException(ErrorCode.CONSENT_VERSION_MISMATCH, undefined, [
          { field: want.kind.toLowerCase(), issue: doc?.version ?? 'none' },
        ]);
      }
      chosen.push(doc);
    }
    const at = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      const added = await recordDocumentConsentsIn(tx, userId, chosen, {
        ip: meta.ip,
        userAgent: meta.userAgent,
        method: 'IN_APP',
        at,
      });
      if (added > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.CONSENT_ACCEPT,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          metadata: { documents: chosen.map((d) => `${d.kind.toLowerCase()}@${d.version}`) },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
    });
    this.current = null;
    return this.status(userId);
  }
}

/**
 * Global guard after the access-token guard (app.module): a signed-in caller who has not accepted the terms and the
 * privacy policy in force gets 428 CONSENT_REQUIRED (`details[]`: `{field: 'terms'|'privacy', issue: <version>}`),
 * except on `@ConsentExempt()` routes. Guests, public routes and the admin panel's cookie routes are not affected
 * (no `req.auth`).
 */
@Injectable()
export class ConsentGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly consents: ConsentsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const req = context.switchToHttp().getRequest<AppRequest>();
    if (!req.auth) return true;
    if (
      this.reflector.getAllAndOverride<boolean>(CONSENT_EXEMPT_KEY, [
        context.getHandler(),
        context.getClass(),
      ])
    ) {
      return true;
    }
    const result = await this.consents.satisfied(req.auth.userId);
    if (result.ok) return true;
    throw new AppException(
      ErrorCode.CONSENT_REQUIRED,
      undefined,
      result.pending.map((d) => ({ field: d.kind.toLowerCase(), issue: d.version })),
    );
  }
}
