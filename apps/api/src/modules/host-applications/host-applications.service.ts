import { createHash } from 'node:crypto';
import { kycOn, kycSettingsIn } from '../kyc/kyc-core.js';
import { takeIdPictures } from '../kyc/id-pictures.js';
import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type HostApplication, type LiveHostSource } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { displayNameSchema } from '../auth/auth.schemas.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { MediaService } from '../media/media.service.js';
import {
  ageOn,
  cancelPendingHostApplicationIn,
  hostApplicationPictureKey,
} from './host-applications.core.js';
import { refuseLimitedStaff } from '../live/live-staff.js';
import { recruiterOfForm } from '../recruits/recruit-core.js';

const DAY_MS = 86_400_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** No control characters (shown to the team). */
const PLAIN = /^[^\p{Cc}\p{Cs}]*$/u;

/** v1.73-social (D209, §10.68): why the caller may not apply now (`HostingApplyRule.refusal`). */
export type HostingApplyRefusal =
  'ACCOUNT_NOT_ACTIVE' | 'ALREADY_HOST' | 'HOST_OF_AGENCY' | 'OWNS_AGENCY' | 'PENDING' | 'REAPPLY_COOLDOWN';

/** Refused only when submitting (the date of birth is in the form). */
export type HostingApplySubmitRefusal = HostingApplyRefusal | 'UNDER_MIN_AGE';

function calendarDay(raw: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const d = new Date(`${raw}T00:00:00.000Z`);
  return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== raw ? null : d;
}

/** v1.73-social (D209, §10.68): `HostingApplicationRequest`. */
export const hostingApplicationBodySchema = z.strictObject({
  /** The name the person hosts under (the §6 display-name rules; the app fills in the profile's). */
  displayName: displayNameSchema,
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((c) => c.toUpperCase()),
  dateOfBirth: z
    .string()
    .refine((v) => {
      const d = calendarDay(v);
      return d !== null && d.getUTCFullYear() >= 1900;
    })
    .transform((v) => calendarDay(v)!),
  contact: z.strictObject({
    type: z.enum(['WHATSAPP', 'TELEGRAM', 'PHONE', 'EMAIL', 'OTHER']),
    value: z.string().trim().min(3).max(100).regex(PLAIN),
  }),
  bio: z
    .string()
    .trim()
    .min(10)
    .max(300)
    // Line breaks are allowed in the bio; no other control character.
    .refine((v) => PLAIN.test(v.replace(/\n/gu, ' '))),
  links: z
    .array(
      z
        .string()
        .trim()
        .max(200)
        .refine((v) => {
          try {
            const u = new URL(v);
            return u.protocol === 'https:' && u.hostname.includes('.');
          } catch {
            return false;
          }
        }),
    )
    .max(3)
    .optional(),
  acceptRules: z.literal(true),
  /** v1.80-kyc (D227): required only while Didit is off (with Didit on, ignored: the identity check replaces them). */
  photoUploadId: z.string().regex(UUID).optional(),
  selfieUploadId: z.string().regex(UUID).optional(),
  /** v1.75-live (D285): «إن كنت تابعاً لمشرف، ضع معرّفه هنا» — a staff ID or username (optional). */
  recruiter: z.string().trim().max(64).optional(),
});
export type HostingApplicationBody = z.infer<typeof hostingApplicationBodySchema>;

/** `HostingApplication`: the caller's latest application (no private field but the name and country). */
export interface HostingApplicationDto {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED';
  displayName: string;
  country: string;
  createdAt: string;
  decidedAt: string | null;
  rejectReason: string | null;
  cancelReason: 'USER' | 'AGENCY' | 'ACCOUNT' | null;
  /** REJECTED only: when the person may apply again. */
  reapplyAt: string | null;
}

/** `MyHostingApplication` (`getMyHostingApplication`). */
export interface MyHostingApplicationDto {
  /** The caller's hosting permission now (any source), or null. */
  host: { source: LiveHostSource; grantedAt: string } | null;
  application: HostingApplicationDto | null;
  rule: {
    canApply: boolean;
    refusal: HostingApplyRefusal | null;
    minAge: number;
    reapplyDays: number;
  };
}

function idempotencyKey(raw: string | undefined): string {
  if (raw === undefined || raw === '')
    throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
  if (!UUID.test(raw)) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
  return raw.toLowerCase();
}

/** The request's fingerprint for the Idempotency-Key (the same key with another body → 409). */
function requestHash(b: HostingApplicationBody): string {
  const canonical = JSON.stringify([
    b.displayName,
    b.country,
    b.dateOfBirth.toISOString().slice(0, 10),
    b.contact.type,
    b.contact.value,
    b.bio,
    b.links ?? [],
    (b.photoUploadId ?? '').toLowerCase(),
    (b.selfieUploadId ?? '').toLowerCase(),
  ]);
  return createHash('sha256').update(canonical).digest('hex');
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

/**
 * «كن مضيفاً مع الإدارة» (v1.73-social, D209, CONVENTIONS §10.68, owner 2026-10-31): on «الوكالة», a person who is
 * not a host and in no agency applies to host directly with the Kabso team — the name they host under, country, date
 * of birth (≥ HOST_APPLICATION_MIN_AGE), a contact method, a short bio, up to three links to streaming accounts, the
 * mandatory ID card + selfie (the D185 private uploads) and the host rules accepted. One PENDING application per user;
 * the team decides in the panel or with `host-admin` (host-applications.core.ts).
 */
@Injectable()
export class HostApplicationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private reapplyAt(app: Pick<HostApplication, 'status' | 'decidedAt'>): Date | null {
    if (app.status !== 'REJECTED' || app.decidedAt === null) return null;
    return new Date(app.decidedAt.getTime() + this.config.economy.hostApplyReapplyDays * DAY_MS);
  }

  private dto(a: HostApplication): HostingApplicationDto {
    return {
      id: a.id,
      status: a.status,
      displayName: a.displayName,
      country: a.country,
      createdAt: a.createdAt.toISOString(),
      decidedAt: a.decidedAt?.toISOString() ?? null,
      rejectReason: a.status === 'REJECTED' ? a.rejectReason : null,
      cancelReason:
        a.status === 'CANCELLED' ? (a.cancelReason as HostingApplicationDto['cancelReason']) : null,
      reapplyAt: this.reapplyAt(a)?.toISOString() ?? null,
    };
  }

  /** The caller's open application if any, else the newest one. */
  private async latest(me: string): Promise<HostApplication | null> {
    const pending = await this.prisma.hostApplication.findFirst({ where: { userId: me, status: 'PENDING' } });
    return (
      pending ??
      this.prisma.hostApplication.findFirst({
        where: { userId: me },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      })
    );
  }

  /** Why the caller may not apply now (null: they may), in the documented order. */
  private async refusal(me: string, latest: HostApplication | null): Promise<HostingApplyRefusal | null> {
    const [user, host, links, owned] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { status: true, deletedAt: true } }),
      this.prisma.liveHost.count({ where: { userId: me } }),
      this.prisma.agencyHost.count({ where: { hostUserId: me, status: 'ACTIVE' } }),
      this.prisma.agency.count({ where: { ownerUserId: me, status: 'OPEN' } }),
    ]);
    if (!user || user.deletedAt !== null || user.status !== 'ACTIVE') return 'ACCOUNT_NOT_ACTIVE';
    if (host > 0) return 'ALREADY_HOST';
    if (links > 0) return 'HOST_OF_AGENCY';
    if (owned > 0) return 'OWNS_AGENCY';
    if (latest?.status === 'PENDING') return 'PENDING';
    const again = latest ? this.reapplyAt(latest) : null;
    if (again !== null && this.clock.now() < again) return 'REAPPLY_COOLDOWN';
    return null;
  }

  /** `GET /me/hosting-application`. */
  async mine(me: string): Promise<MyHostingApplicationDto> {
    const [host, latest] = await Promise.all([
      this.prisma.liveHost.findUnique({ where: { userId: me }, select: { source: true, grantedAt: true } }),
      this.latest(me),
    ]);
    const refusal = await this.refusal(me, latest);
    return {
      host: host ? { source: host.source, grantedAt: host.grantedAt.toISOString() } : null,
      application: latest ? this.dto(latest) : null,
      rule: {
        canApply: refusal === null,
        refusal,
        minAge: this.config.economy.hostApplyMinAge,
        reapplyDays: this.config.economy.hostApplyReapplyDays,
      },
    };
  }

  /**
   * `POST /me/hosting-application` (Idempotency-Key). Order: 400 header / body → the same key again (200 the same
   * body, 409 IDEMPOTENCY_CONFLICT another) → 503 MEDIA_UPLOADS_UNAVAILABLE → 409 HOST_APPLICATION_NOT_ALLOWED
   * (`details[0].issue` = the refusal, `UNDER_MIN_AGE` last) → 400 an upload that is not the caller's pending one →
   * 201.
   */
  async apply(
    me: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: MyHostingApplicationDto }> {
    const key = idempotencyKey(rawKey);
    // v1.72-live (D283, §10.96.10): a Kabso Team account never goes live, so it never applies to host.
    await refuseLimitedStaff(this.prisma, me, 'live');
    const parsed = hostingApplicationBodySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const hash = requestHash(input);
    const replay = async () => {
      const prior = await this.prisma.hostApplication.findUnique({
        where: { userId_clientKey: { userId: me, clientKey: key } },
        select: { requestHash: true },
      });
      if (!prior) return null;
      if (prior.requestHash !== hash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
      return { created: false, result: await this.mine(me) };
    };
    const before = await replay();
    if (before) return before;
    // v1.75-live (D285, §10.96.13): the optional recruiter field (400 `recruiter` when it names no recruiter).
    const recruiter = await recruiterOfForm(this.prisma, input.recruiter, me);
    // v1.80-kyc (D227): with Didit on the ID pictures are not asked (the identity check replaces them).
    const kyc = kycOn(await kycSettingsIn(this.prisma));
    if (!kyc) await this.media.assertEnabled();
    const refused = (issue: HostingApplySubmitRefusal) =>
      new AppException(ErrorCode.HOST_APPLICATION_NOT_ALLOWED, undefined, [{ field: 'application', issue }]);
    const refusal = await this.refusal(me, await this.latest(me));
    if (refusal) throw refused(refusal);
    const now = this.clock.now();
    if (ageOn(input.dateOfBirth, now) < this.config.economy.hostApplyMinAge) throw refused('UNDER_MIN_AGE');

    const id = uuidv7();
    const { photoKey, selfieKey } = await takeIdPictures(
      this.media,
      me,
      input,
      { photo: hostApplicationPictureKey(id, 'photo'), selfie: hostApplicationPictureKey(id, 'selfie') },
      kyc,
    );
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.hostApplication.create({
          data: {
            id,
            userId: me,
            clientKey: key,
            requestHash: hash,
            displayName: input.displayName,
            country: input.country,
            dateOfBirth: input.dateOfBirth,
            contactType: input.contact.type,
            contactValue: input.contact.value,
            bio: input.bio,
            links: input.links ?? [],
            photoKey,
            selfieKey,
            rulesAcceptedAt: now,
            createdAt: now,
            recruiterUserId: recruiter,
          },
        });
        // The application's private fields never go to the audit trail.
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.HOST_APPLICATION_SUBMIT,
            targetType: 'host_application',
            targetId: id,
            metadata: {
              country: input.country,
              links: (input.links ?? []).length,
              idCheck: kyc ? 'didit' : 'pictures',
              after: 'PENDING',
            },
          },
        });
      });
    } catch (err) {
      const taken = [photoKey, selfieKey].filter((k): k is string => k !== null);
      if (taken.length > 0) await this.media.deletePrivateObjects(taken).catch(() => undefined);
      if (isUniqueViolation(err)) {
        // The same key raced (→ its answer), or another submit made the one pending application meanwhile.
        const raced = await replay();
        if (raced) return raced;
        throw refused('PENDING');
      }
      throw err;
    }
    return { created: true, result: await this.mine(me) };
  }

  /** `POST /me/hosting-application/cancel`: the caller's PENDING application → CANCELLED (404: none pending). */
  async cancel(me: string): Promise<MyHostingApplicationDto> {
    const id = await this.prisma.$transaction((tx) =>
      cancelPendingHostApplicationIn(tx, me, 'USER', this.clock.now()),
    );
    if (id === null) throw new AppException(ErrorCode.NOT_FOUND);
    return this.mine(me);
  }
}
