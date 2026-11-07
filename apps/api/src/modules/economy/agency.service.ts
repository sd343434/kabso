import { createHash } from 'node:crypto';
import { kycGateIn } from '../kyc/kyc-core.js';
import { takeIdPictures } from '../kyc/id-pictures.js';
import { attributeRecruitIn, recruiterOfForm } from '../recruits/recruit-core.js';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type Agency, type AgencyComplaint, type AgencyRank } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { MediaService } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import { syncAgentUsernameIn } from '../users/agent-usernames.js';
import { cancelPendingHostApplicationIn } from '../host-applications/host-applications.core.js';
import { creatorApplicationBody } from '../creator/creator-applications.js';
import { activateCreatorIn, CreatorHostConflictError, hostKindIn } from '../creator/creator-membership.js';
import { recomputeBadgesIn } from '../verification/verification-badges.js';
import { isLimitedStaff } from '../live/live-staff.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { agencyStandings, evaluateAgencyRanks, hostActivity, type RankChange } from './agency-ranks.js';
import {
  DAY_MS as PROBATION_DAY_MS,
  probationHostsAt,
  probationInstant,
  reopenAt,
  settleProbation,
  sweepAgencyProbations,
  type ProbationRules,
} from './agency-probation.js';
import {
  addMonths,
  agencyRateBps,
  dateValue,
  monthKey,
  newInviteCode,
  normalizeInviteCode,
} from './economy-math.js';
import {
  allocateHostCodeIn,
  assignMissingHostCodes,
  createAgencyIn,
  hostAgentPerksActive,
} from './host-agents.js';
import { syncHostFrames, type HostFrameChange } from './host-frames.js';

const DAY_MS = 86_400_000;

/** `AgencyPreview` (openapi v1.52-social, D179). */
export interface AgencyPreviewDto {
  inviteCode: string;
  owner: UserSummaryDto;
  rank: AgencyRank;
  hostCount: number;
}

/** `AgencyComplaint`. */
export interface AgencyComplaintDto {
  id: string;
  status: 'OPEN' | 'RESOLVED' | 'REJECTED';
  text: string;
  resolution: string | null;
  createdAt: string;
  resolvedAt: string | null;
}

/** `AgencyMembership`: the caller as a host. */
export interface AgencyMembershipDto {
  agency: AgencyPreviewDto;
  joinedAt: string;
  leaveUntil: string;
  canLeave: boolean;
  complaint: AgencyComplaintDto | null;
}

interface CommissionTotalsDto {
  thisMonth: number;
  lastMonth: number;
  total: number;
}

/** `AgencySubAgency`. */
export interface AgencySubAgencyDto {
  inviteCode: string;
  owner: UserSummaryDto;
  rank: AgencyRank;
  activeHosts: number;
  monthHostCherries: number;
  qualifies: boolean;
}

/** `OwnAgency`: the caller's own agency (the host agent's dashboard). */
export interface OwnAgencyDto {
  inviteCode: string;
  rank: AgencyRank;
  rankMonth: string | null;
  createdAt: string;
  timeZone: string;
  month: string;
  commissionRateBps: number;
  parent: AgencyPreviewDto | null;
  progress: {
    hostCount: number;
    activeHosts: number;
    requiredActiveHosts: number;
    monthHostCherries: number;
    lastMonthHostCherries: number;
    exceptionCherries: number;
    tierCherries: number;
    qualifiesNow: boolean;
    qualifiedSubAgencies: number;
    requiredSubAgencies: number;
  };
  commission: CommissionTotalsDto;
  parentCommission: CommissionTotalsDto;
  subAgencies: AgencySubAgencyDto[];
  /** v1.58-social (D189, §10.52): the owner as a host agent «وكيل مضيفين». */
  hostAgent: OwnHostAgentDto;
  /** v1.70-social (D206, §10.65): the agency's name (null: made by the team before D206). */
  name: string | null;
  /** v1.70-social (D206): the probation of a self-opened agency (null: none). */
  probation: AgencyProbationDto | null;
}

/** v1.70-social (D206): one host of an agency in its probation. */
export interface AgencyProbationHostDto {
  user: UserSummaryDto;
  joinedAt: string;
  wentLive: boolean;
  receivedGifts: boolean;
  activated: boolean;
}

/** v1.70-social (D206): `AgencyProbation`. */
export interface AgencyProbationDto {
  status: 'RUNNING' | 'PASSED';
  endsAt: string;
  passedAt: string | null;
  days: number;
  requiredHosts: number;
  activatedHosts: number;
  hosts: AgencyProbationHostDto[];
}

/** v1.70-social (D206): `ClosedAgency` — the caller's own agency, closed. */
export interface ClosedAgencyDto {
  name: string | null;
  inviteCode: string;
  closedAt: string;
  reason: 'PROBATION_FAILED' | 'ADMIN' | 'BANNED';
  activatedHosts: number | null;
  requiredHosts: number | null;
  reopenAt: string;
}

/** v1.82-live (D295, §10.108): `BANNED` — the person's agency was banned «حظر الوكالة»; it is never reopened. */
export type AgencyOpenRefusal =
  'ACCOUNT_NOT_ACTIVE' | 'HOST_OF_AGENCY' | 'OWNS_AGENCY' | 'REOPEN_COOLDOWN' | 'BANNED';
/** v1.80-kyc (D227): with Didit on, «افتح وكالة» needs an approved identity check (only at the opening). */
export type AgencyOpenSubmitRefusal = AgencyOpenRefusal | 'KYC_REQUIRED';

/** v1.70-social (D206): `AgencyOpenRule` — «افتح وكالة» (free). */
export interface AgencyOpenRuleDto {
  canOpen: boolean;
  refusal: AgencyOpenRefusal | null;
  free: true;
  probationDays: number;
  requiredHosts: number;
  reopenCooldownDays: number;
}

/** v1.58-social (D189, §10.52). */
export interface OwnHostAgentDto {
  /** `hostNN`; null until the sweeper gives an agency made before D189 its code. */
  code: string | null;
  /** The perks are on (not suspended by the team). */
  active: boolean;
  /** The code is the username shown now (false: suspended, or another special username activated first). */
  usernameShown: boolean;
}

/** `MyAgency`. */
export interface MyAgencyDto {
  membership: AgencyMembershipDto | null;
  ownAgency: OwnAgencyDto | null;
  activeHostRule: { minDays: number; minHours: number; windowDays: number };
  leaveDays: number;
  /** v1.70-social (D206): the caller's own agency when it is closed (then `ownAgency` is null). */
  closedAgency: ClosedAgencyDto | null;
  openRule: AgencyOpenRuleDto;
}

/** `AgencyHost`: one host in the agent's list. */
export interface AgencyHostDto {
  user: UserSummaryDto;
  joinedAt: string;
  liveDays: number;
  liveSeconds: number;
  active: boolean;
  monthCherries: number;
  commissionEligible: boolean;
  /**
   * v1.82-live (D295, §10.108): what the member is now — NONE (no hosting permission), HOST (a host, any source) or
   * CREATOR (a creator-programme member); the agency owner activates a NONE member as either.
   */
  hosting: 'NONE' | 'HOST' | 'CREATOR';
  /** v1.82-live (D295): this agency activated them (as a host or a creator). */
  activatedByAgency: boolean;
}

/**
 * v1.82-live (D295, §10.108): `POST /me/agency/hosts/{userId}/activate` — «مضيف» or «صانع محتوى». A creator needs the
 * creator programme's fields (country, category, 1–5 links, an optional bio) and the owner's tick on the warning
 * «إن قمت بتفعيل شخص على أنه صانع محتوى ولم يكن كذلك، سيتم حظر الوكالة وخسارة أرباحك.» (`confirmCreator: true`).
 */
export const activateMemberBodySchema = z.discriminatedUnion('as', [
  z.strictObject({ as: z.literal('HOST') }),
  z.strictObject({
    as: z.literal('CREATOR'),
    country: creatorApplicationBody.shape.country,
    category: creatorApplicationBody.shape.category,
    links: creatorApplicationBody.shape.links,
    bio: creatorApplicationBody.shape.bio,
    confirmCreator: z.literal(true),
  }),
]);

/** v1.82-live (D295): why an agency owner may not activate a member now (`details[0].issue`). */
export type AgencyActivationRefusal =
  'AGENCY_SUSPENDED' | 'ACCOUNT_NOT_ACTIVE' | 'STAFF' | 'HOST' | 'CREATOR';

export const joinBodySchema = z.strictObject({ inviteCode: z.string().min(1).max(32) });
export const complaintBodySchema = z.strictObject({ text: z.string().trim().min(1).max(1000) });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** No control characters (a name and a bio are shown to people). */
const PLAIN = /^[^\p{Cc}\p{Cs}]*$/u;

/** v1.70-social (D206, §10.65): `OpenAgencyRequest`. */
export const openAgencyBodySchema = z.strictObject({
  name: z.string().trim().min(2).max(40).regex(PLAIN),
  country: z
    .string()
    .regex(/^[A-Za-z]{2}$/)
    .transform((c) => c.toUpperCase()),
  contact: z.strictObject({
    type: z.enum(['WHATSAPP', 'TELEGRAM', 'PHONE', 'EMAIL', 'OTHER']),
    value: z.string().trim().min(3).max(100).regex(PLAIN),
  }),
  expectedHosts: z.number().int().min(1).max(10_000),
  bio: z
    .string()
    .trim()
    .max(300)
    // Line breaks are allowed in the bio; no other control character.
    .refine((v) => PLAIN.test(v.replace(/\n/gu, ' ')))
    .optional(),
  /** v1.80-kyc (D227): required only while Didit is off (with Didit on, ignored: an approved check is needed). */
  photoUploadId: z.string().regex(UUID).optional(),
  selfieUploadId: z.string().regex(UUID).optional(),
  /** v1.75-live (D285): «إن كنت تابعاً لمشرف، ضع معرّفه هنا» — a staff ID or username (optional). */
  recruiter: z.string().trim().max(64).optional(),
});
export type OpenAgencyBody = z.infer<typeof openAgencyBodySchema>;

/** The private keys of an application's two pictures (never public, `private, no-store`). */
export function agencyPictureKey(applicationId: string, which: 'photo' | 'selfie'): string {
  return `private/agency-applications/${applicationId}/${which}.webp`;
}

function idempotencyKey(raw: string | undefined): string {
  if (raw === undefined || raw === '')
    throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
  if (!UUID.test(raw)) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
  return raw.toLowerCase();
}

/** The request's fingerprint for the Idempotency-Key (the same key with another body → 409). */
function requestHash(b: OpenAgencyBody): string {
  const canonical = JSON.stringify([
    b.name,
    b.country,
    b.contact.type,
    b.contact.value,
    b.expectedHosts,
    b.bio ?? '',
    (b.photoUploadId ?? '').toLowerCase(),
    (b.selfieUploadId ?? '').toLowerCase(),
  ]);
  return createHash('sha256').update(canonical).digest('hex');
}

function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

function complaintDto(c: AgencyComplaint): AgencyComplaintDto {
  return {
    id: c.id,
    status: c.status,
    text: c.text,
    resolution: c.resolution,
    createdAt: c.createdAt.toISOString(),
    resolvedAt: c.resolvedAt?.toISOString() ?? null,
  };
}

/**
 * Host agencies «وكالة المضيفين» (v1.52-social, D179, CONVENTIONS §10.46, owner 2026-10-30): a host joins
 * with the agent's invite code and accepts; may leave within AGENCY_LEAVE_DAYS of joining, later only
 * through a complaint the admin resolves (`economy-admin`). The agent sees the rank and its progress, the
 * hosts with their activity and month cherries, the commissions and the sub-agencies. Ranks are
 * evaluated by the sweeper (month start: up or down; otherwise only up).
 */
@Injectable()
export class AgencyService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('AgencyService');
  private readonly cursors: SocialCursorCodec;
  private readonly notifier = new Notifier();
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.economy.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweepProbations()
        .then((p) => {
          const n = p.passed.length + p.closed.length + p.reminded.length;
          if (n > 0) {
            this.logger.log(
              { passed: p.passed.length, closed: p.closed.length, reminded: p.reminded.length },
              'Agency probations settled',
            );
          }
        })
        .then(() => this.evaluate())
        .then(async ({ ranks, frames }) => {
          if (ranks.length > 0) this.logger.log({ changes: ranks.length }, 'Agency ranks evaluated');
          if (frames.length > 0) this.logger.log({ changes: frames.length }, 'Host frames synced');
          // v1.58-social (D189, §10.52): agencies made before D189 get their host code (oldest first).
          const coded = await this.assignHostCodes();
          if (coded > 0) this.logger.log({ coded }, 'Host-agent codes given');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Agency rank evaluation failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.economy.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** v1.58-social (D189): the sweeper's backfill of host codes. */
  assignHostCodes(): Promise<number> {
    return assignMissingHostCodes(this.prisma, this.clock.now(), this.config.specialUsernames.graceDays);
  }

  /** v1.70-social (D206). */
  get probationRules(): ProbationRules {
    const e = this.config.economy;
    return {
      probationDays: e.probationDays,
      probationMinHosts: e.probationMinHosts,
      probationReminderHours: e.probationReminderHours,
      reopenCooldownDays: e.reopenCooldownDays,
    };
  }

  /**
   * v1.70-social (D206, §10.65): every running probation is settled — passed (enough activated hosts), closed (the
   * end came without them; hosts released) or reminded (the last day) — then the released hosts' frames follow.
   * Also `economy-admin agency-probation-sweep`.
   */
  async sweepProbations(): Promise<{ passed: string[]; closed: string[]; reminded: string[] }> {
    const r = await sweepAgencyProbations(
      this.prisma,
      this.clock.now(),
      this.probationRules,
      this.config.specialUsernames.graceDays,
    );
    if (r.releasedHosts.length > 0) await this.syncHostFrames(r.releasedHosts);
    return { passed: r.passed, closed: r.closed, reminded: r.reminded };
  }

  /** The rank evaluation (also `economy-admin agency-evaluate`). */
  evaluateRanks(): Promise<RankChange[]> {
    return evaluateAgencyRanks(this.prisma, this.clock.now(), this.config.economy, this.zone);
  }

  /**
   * The sweeper's work: the ranks, then (v1.55-social, D186) the active-host frames by the same
   * active-host test — given to hosts who became active, taken back from those who are not any more.
   */
  async evaluate(): Promise<{ ranks: RankChange[]; frames: HostFrameChange[] }> {
    const ranks = await this.evaluateRanks();
    const frames = await this.syncHostFrames();
    return { ranks, frames };
  }

  /** D186: the active-host frames of every host now, or of `userIds`. */
  syncHostFrames(userIds: readonly string[] | null = null): Promise<HostFrameChange[]> {
    return syncHostFrames(this.prisma, this.clock.now(), this.config.economy, this.zone, userIds);
  }

  private async preview(agencyId: string): Promise<AgencyPreviewDto | null> {
    const a = await this.prisma.agency.findUnique({
      where: { id: agencyId },
      select: {
        inviteCode: true,
        rank: true,
        status: true,
        owner: { select: { ...USER_SUMMARY_SELECT, status: true } },
        _count: { select: { hosts: { where: { status: 'ACTIVE' } } } },
      },
    });
    // v1.70-social (D206): a closed agency cannot be found or joined.
    if (!a || a.owner.status !== 'ACTIVE' || a.status !== 'OPEN') return null;
    return { inviteCode: a.inviteCode, owner: userSummary(a.owner), rank: a.rank, hostCount: a._count.hosts };
  }

  /** `GET /agencies/{inviteCode}`: 404 for an unknown code or an owner who is not ACTIVE. */
  async byCode(raw: string): Promise<AgencyPreviewDto> {
    const code = normalizeInviteCode(raw);
    const agency =
      code === null ? null : await this.prisma.agency.findUnique({ where: { inviteCode: code } });
    const preview = agency ? await this.preview(agency.id) : null;
    if (!preview) throw new AppException(ErrorCode.NOT_FOUND);
    return preview;
  }

  /**
   * `GET /me/agency`. v1.70-social (D206): a running probation of the caller's agency is settled first (it passes
   * as soon as enough hosts are activated; at its end it closes) — the same step as the sweeper's.
   */
  async mine(me: string): Promise<MyAgencyDto> {
    const e = this.config.economy;
    const own = await this.prisma.agency.findUnique({ where: { ownerUserId: me } });
    let agency: Agency | null = own;
    if (own && own.status === 'OPEN' && own.probationEndsAt !== null && own.probationPassedAt === null) {
      const r = await settleProbation(
        this.prisma,
        own.id,
        this.clock.now(),
        this.probationRules,
        this.config.specialUsernames.graceDays,
      );
      if (r.releasedHosts.length > 0) await this.syncHostFrames(r.releasedHosts);
      if (r.outcome !== null) agency = await this.prisma.agency.findUnique({ where: { id: own.id } });
    }
    const [membership, ownAgency, refusal] = await Promise.all([
      this.membership(me),
      agency?.status === 'OPEN' ? this.ownAgency(me, agency) : Promise.resolve(null),
      this.openRefusal(me, agency),
    ]);
    return {
      membership,
      ownAgency,
      activeHostRule: {
        minDays: e.activeHostMinDays,
        minHours: e.activeHostMinHours,
        windowDays: e.activeHostWindowDays,
      },
      leaveDays: e.leaveDays,
      closedAgency: agency?.status === 'CLOSED' ? this.closedDto(agency) : null,
      openRule: {
        canOpen: refusal === null,
        refusal,
        free: true,
        probationDays: e.probationDays,
        requiredHosts: e.probationMinHosts,
        reopenCooldownDays: e.reopenCooldownDays,
      },
    };
  }

  private closedDto(a: Agency): ClosedAgencyDto {
    const closedAt = a.closedAt ?? a.updatedAt;
    return {
      name: a.name,
      inviteCode: a.inviteCode,
      closedAt: closedAt.toISOString(),
      reason: a.closeReason ?? 'ADMIN',
      activatedHosts: a.closeReason === 'PROBATION_FAILED' ? (a.probationActivated ?? 0) : null,
      requiredHosts: a.closeReason === 'PROBATION_FAILED' ? this.config.economy.probationMinHosts : null,
      reopenAt: reopenAt(closedAt, this.probationRules).toISOString(),
    };
  }

  /** v1.70-social (D206): why the caller may not open an agency now (null: they may). */
  private async openRefusal(me: string, own: Agency | null): Promise<AgencyOpenRefusal | null> {
    const [user, hostLinks] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: me }, select: { status: true, deletedAt: true } }),
      this.prisma.agencyHost.count({ where: { hostUserId: me, status: 'ACTIVE' } }),
    ]);
    if (!user || user.deletedAt !== null || user.status !== 'ACTIVE') return 'ACCOUNT_NOT_ACTIVE';
    if (own?.status === 'OPEN') return 'OWNS_AGENCY';
    if (own?.closeReason === 'BANNED') return 'BANNED';
    if (hostLinks > 0) return 'HOST_OF_AGENCY';
    if (
      own?.status === 'CLOSED' &&
      this.clock.now() < reopenAt(own.closedAt ?? own.updatedAt, this.probationRules)
    ) {
      return 'REOPEN_COOLDOWN';
    }
    return null;
  }

  /**
   * v1.70-social (D206, §10.65): `POST /me/agency/open` (Idempotency-Key) «افتح وكالة» — free; the ID card and the
   * selfie are the D185 private uploads (`RECHARGE_AGENT_PHOTO` / `RECHARGE_AGENT_SELFIE`), consumed into this
   * application's private keys. The agency exists at once (no approval): NEW, its invite code and `hostNN` as the
   * team's agencies, with a probation of AGENCY_PROBATION_DAYS. A person whose agency closed opens the same row again
   * after the cooldown (same invite and host code, a new probation). Order: 400 header / body → the same key again
   * (200 the same body, 409 IDEMPOTENCY_CONFLICT another) → 503 MEDIA_UNAVAILABLE → 409 AGENCY_OPEN_NOT_ALLOWED
   * (`details[0].issue` = the refusal) → 400 an upload that is not the caller's pending one → 201.
   */
  async open(
    me: string,
    rawKey: string | undefined,
    body: unknown,
  ): Promise<{ created: boolean; result: MyAgencyDto }> {
    const key = idempotencyKey(rawKey);
    const parsed = openAgencyBodySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const hash = requestHash(input);
    const replay = async () => {
      const prior = await this.prisma.agencyApplication.findUnique({
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
    // v1.80-kyc (D227): with Didit on the ID pictures are not asked: an approved identity check is.
    const kycGate = await kycGateIn(this.prisma, me, 'AGENCY_OPEN');
    if (!kycGate.enabled) await this.media.assertEnabled();
    const refused = (issue: AgencyOpenSubmitRefusal) =>
      new AppException(ErrorCode.AGENCY_OPEN_NOT_ALLOWED, undefined, [{ field: 'agency', issue }]);
    const own = await this.prisma.agency.findUnique({ where: { ownerUserId: me } });
    const refusal = await this.openRefusal(me, own);
    if (refusal) throw refused(refusal);
    if (kycGate.enabled && !kycGate.approved) throw refused('KYC_REQUIRED');

    const applicationId = uuidv7();
    const { photoKey, selfieKey } = await takeIdPictures(
      this.media,
      me,
      input,
      { photo: agencyPictureKey(applicationId, 'photo'), selfie: agencyPictureKey(applicationId, 'selfie') },
      kycGate.enabled,
    );
    const now = this.clock.now();
    const e = this.config.economy;
    const grace = this.config.specialUsernames.graceDays;
    const endsAt = new Date(now.getTime() + e.probationDays * PROBATION_DAY_MS);
    const evaluateFrom = dateValue(addMonths(monthKey(now, this.zone), 2));
    try {
      for (let attempt = 0; ; attempt++) {
        const code = own ? own.inviteCode : newInviteCode();
        if (!own && (await this.prisma.agency.count({ where: { inviteCode: code } })) > 0) {
          if (attempt >= 5) throw new Error('No free invite code');
          continue;
        }
        try {
          await this.prisma.$transaction(async (tx) => {
            let agencyId: string;
            let hostCode: string;
            if (own) {
              // The closed row is opened again (the owner-once index): checked again under its lock.
              const [row] = await tx.$queryRaw<
                { status: string; closed_at: Date | null; code: string | null; banned: boolean }[]
              >`
                SELECT status::text AS status, closed_at, host_code AS code,
                       (close_reason = 'BANNED'::agency_close_reason) AS banned FROM agencies
                 WHERE id = ${own.id}::uuid FOR UPDATE`;
              if (row?.banned) throw refused('BANNED');
              if (
                !row ||
                row.status !== 'CLOSED' ||
                now < reopenAt(row.closed_at ?? now, this.probationRules)
              ) {
                throw refused(row?.status === 'OPEN' ? 'OWNS_AGENCY' : 'REOPEN_COOLDOWN');
              }
              await tx.agency.update({
                where: { id: own.id },
                data: {
                  name: input.name,
                  origin: 'SELF',
                  status: 'OPEN',
                  closedAt: null,
                  closeReason: null,
                  closeNote: null,
                  parentAgencyId: null,
                  rank: 'NEW',
                  rankMonth: null,
                  evaluateFrom,
                  probationEndsAt: endsAt,
                  probationPassedAt: null,
                  probationRemindedAt: null,
                  probationActivated: null,
                  updatedAt: now,
                },
              });
              agencyId = own.id;
              if (row.code === null) {
                hostCode = await allocateHostCodeIn(tx, own.id, now, grace, { strict: false, via: 'app' });
              } else {
                hostCode = row.code;
                await syncAgentUsernameIn(tx, me, now, grace, { strict: false });
              }
            } else {
              const made = await createAgencyIn(
                tx,
                {
                  ownerUserId: me,
                  inviteCode: code,
                  parentAgencyId: null,
                  evaluateFrom,
                  name: input.name,
                  origin: 'SELF',
                  probationEndsAt: endsAt,
                },
                now,
                grace,
                // A refused username grant (a rented premium username) keeps the code reserved (D189).
                { strict: false, via: 'app' },
              );
              agencyId = made.agencyId;
              hostCode = made.hostCode;
            }
            await tx.agencyApplication.create({
              data: {
                id: applicationId,
                agencyId,
                userId: me,
                clientKey: key,
                requestHash: hash,
                name: input.name,
                country: input.country,
                contactType: input.contact.type,
                contactValue: input.contact.value,
                expectedHosts: input.expectedHosts,
                bio: input.bio && input.bio !== '' ? input.bio : null,
                photoKey,
                selfieKey,
                createdAt: now,
                recruiterUserId: recruiter,
              },
            });
            // v1.75-live (D285, §10.96.13): the agency is active at once (no approval): the recruiter the form named
            // is attributed for good now (a reopened agency keeps its first attribution).
            await attributeRecruitIn(tx, {
              type: 'AGENCY',
              recruitUserId: me,
              recruiterUserId: recruiter,
              applicationId,
              agencyId,
              now,
              by: { via: 'app', actorUserId: me },
            });
            await this.notifier.agency(tx, { type: 'AGENCY_OPENED', recipientId: me, agencyId });
            // v1.73-social (D209, §10.68): an agency owner is not a direct host — a pending application goes.
            await cancelPendingHostApplicationIn(tx, me, 'AGENCY', now);
            // The application's private fields never go to the audit trail (the name is public).
            await tx.auditLog.create({
              data: {
                actorUserId: me,
                action: AuditAction.AGENCY_OPEN,
                targetType: 'agency',
                targetId: agencyId,
                metadata: {
                  application: applicationId,
                  inviteCode: code,
                  hostCode,
                  reopened: own !== null,
                  country: input.country,
                  expectedHosts: input.expectedHosts,
                  probationEndsAt: endsAt.toISOString(),
                  evaluateFrom: evaluateFrom.toISOString().slice(0, 10),
                },
              },
            });
          });
          break;
        } catch (err) {
          // A raced invite code: another try with a new one.
          if (!own && isUniqueViolation(err) && attempt < 5) {
            const taken = await this.prisma.agency.count({ where: { inviteCode: code } });
            if (taken > 0) continue;
          }
          throw err;
        }
      }
    } catch (err) {
      const taken = [photoKey, selfieKey].filter((k): k is string => k !== null);
      if (taken.length > 0) await this.media.deletePrivateObjects(taken).catch(() => undefined);
      if (isUniqueViolation(err)) {
        // The same key raced, or the person's agency was made meanwhile.
        const raced = await replay();
        if (raced) return raced;
        throw refused(
          (await this.openRefusal(me, await this.prisma.agency.findUnique({ where: { ownerUserId: me } }))) ??
            'OWNS_AGENCY',
        );
      }
      throw err;
    }
    return { created: true, result: await this.mine(me) };
  }

  private async membership(me: string): Promise<AgencyMembershipDto | null> {
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) return null;
    const agency = await this.preview(link.agencyId);
    if (!agency) return null;
    const complaint = await this.prisma.agencyComplaint.findFirst({
      where: { agencyHostId: link.id },
      orderBy: { createdAt: 'desc' },
    });
    const leaveUntil = new Date(link.activatedAt.getTime() + this.config.economy.leaveDays * DAY_MS);
    return {
      agency,
      joinedAt: link.activatedAt.toISOString(),
      leaveUntil: leaveUntil.toISOString(),
      canLeave: this.clock.now() < leaveUntil,
      complaint: complaint ? complaintDto(complaint) : null,
    };
  }

  private async ownAgency(me: string, agency: Agency): Promise<OwnAgencyDto> {
    const e = this.config.economy;
    const now = this.clock.now();
    const month = monthKey(now, this.zone);
    const previous = addMonths(month, -1);
    const standings = await agencyStandings(this.prisma, now, e, this.zone, [agency.id]);
    const self = standings.get(agency.id)!;
    const [months, totals, hostCount, subs, parent, profile] = await Promise.all([
      this.prisma.agencyMonth.findMany({
        where: { agencyId: agency.id, month: { in: [dateValue(month), dateValue(previous)] } },
      }),
      this.prisma.agencyMonth.aggregate({
        where: { agencyId: agency.id },
        _sum: { commission: true, parentCommission: true },
      }),
      this.prisma.agencyHost.count({ where: { agencyId: agency.id, status: 'ACTIVE' } }),
      this.prisma.agency.findMany({
        where: { parentAgencyId: agency.id },
        orderBy: { createdAt: 'asc' },
        select: { id: true, inviteCode: true, rank: true, owner: { select: USER_SUMMARY_SELECT } },
      }),
      agency.parentAgencyId ? this.preview(agency.parentAgencyId) : Promise.resolve(null),
      this.prisma.userProfile.findUnique({ where: { userId: me }, select: { username: true } }),
    ]);
    const cur = months.find((m) => m.month.toISOString().startsWith(month));
    const prev = months.find((m) => m.month.toISOString().startsWith(previous));
    return {
      inviteCode: agency.inviteCode,
      rank: agency.rank,
      rankMonth: agency.rankMonth?.toISOString().slice(0, 10) ?? null,
      createdAt: agency.createdAt.toISOString(),
      timeZone: this.zone,
      month: month.slice(0, 7),
      commissionRateBps: agencyRateBps(prev?.hostCherries ?? 0n, e),
      parent,
      progress: {
        hostCount,
        activeHosts: self.activeHosts,
        requiredActiveHosts: e.rankMinActiveHosts,
        monthHostCherries: Number(cur?.hostCherries ?? 0n),
        lastMonthHostCherries: Number(prev?.hostCherries ?? 0n),
        exceptionCherries: e.rankExceptionCherries,
        tierCherries: e.agencyTierMonthlyCherries,
        qualifiesNow: self.selfQualifies,
        qualifiedSubAgencies: self.qualifiedSubAgencies,
        requiredSubAgencies: e.adminMinSubAgencies,
      },
      commission: {
        thisMonth: Number(cur?.commission ?? 0n),
        lastMonth: Number(prev?.commission ?? 0n),
        total: Number(totals._sum.commission ?? 0n),
      },
      parentCommission: {
        thisMonth: Number(cur?.parentCommission ?? 0n),
        lastMonth: Number(prev?.parentCommission ?? 0n),
        total: Number(totals._sum.parentCommission ?? 0n),
      },
      subAgencies: subs.map((s) => {
        const st = standings.get(s.id);
        return {
          inviteCode: s.inviteCode,
          owner: userSummary(s.owner),
          rank: s.rank,
          activeHosts: st?.activeHosts ?? 0,
          monthHostCherries: Number(st?.monthHostCherries ?? 0n),
          qualifies: st?.selfQualifies ?? false,
        };
      }),
      hostAgent: {
        code: agency.hostCode,
        active: hostAgentPerksActive(agency),
        usernameShown: agency.hostCode !== null && profile?.username === agency.hostCode,
      },
      name: agency.name,
      probation: await this.probation(agency, now),
    };
  }

  /** v1.70-social (D206): the probation card's data (the hosts as of `min(now, end)`). */
  private async probation(agency: Agency, now: Date): Promise<AgencyProbationDto | null> {
    if (agency.probationEndsAt === null) return null;
    const e = this.config.economy;
    if (agency.probationPassedAt !== null) {
      return {
        status: 'PASSED',
        endsAt: agency.probationEndsAt.toISOString(),
        passedAt: agency.probationPassedAt.toISOString(),
        days: e.probationDays,
        requiredHosts: e.probationMinHosts,
        activatedHosts: agency.probationActivated ?? e.probationMinHosts,
        hosts: [],
      };
    }
    const hosts = (
      await probationHostsAt(this.prisma, agency.id, probationInstant(now, agency.probationEndsAt))
    ).slice(0, 100);
    const users = await this.prisma.user.findMany({
      where: { id: { in: hosts.map((h) => h.userId) } },
      select: USER_SUMMARY_SELECT,
    });
    const byId = new Map(users.map((u) => [u.id, u]));
    return {
      status: 'RUNNING',
      endsAt: agency.probationEndsAt.toISOString(),
      passedAt: null,
      days: e.probationDays,
      requiredHosts: e.probationMinHosts,
      activatedHosts: hosts.filter((h) => h.activated).length,
      hosts: hosts.flatMap((h) => {
        const u = byId.get(h.userId);
        return u
          ? [
              {
                user: userSummary(u),
                joinedAt: h.joinedAt.toISOString(),
                wentLive: h.wentLive,
                receivedGifts: h.receivedGifts,
                activated: h.activated,
              },
            ]
          : [];
      }),
    };
  }

  /**
   * `POST /me/agency/join {inviteCode}` — the host accepts the agency of the code. Order: 400 → 404 (unknown
   * code, owner not ACTIVE) → 409 AGENCY_JOIN_NOT_ALLOWED (the caller owns an agency) → already a host of
   * this agency → 200 → 409 AGENCY_ALREADY_MEMBER (another agency) → 201.
   */
  async join(me: string, body: unknown): Promise<{ created: boolean; result: MyAgencyDto }> {
    const parsed = joinBodySchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const code = normalizeInviteCode(parsed.data.inviteCode);
    if (code === null) throw new AppException(ErrorCode.NOT_FOUND);
    const agency = await this.prisma.agency.findUnique({
      where: { inviteCode: code },
      select: { id: true, rank: true, status: true, owner: { select: { status: true } } },
    });
    if (!agency || agency.owner.status !== 'ACTIVE' || agency.status !== 'OPEN') {
      throw new AppException(ErrorCode.NOT_FOUND);
    }
    // v1.70-social (D206): the owner of a closed agency may be a host elsewhere.
    if ((await this.prisma.agency.count({ where: { ownerUserId: me, status: 'OPEN' } })) > 0) {
      throw new AppException(ErrorCode.AGENCY_JOIN_NOT_ALLOWED);
    }
    const existing = async () => {
      const link = await this.prisma.agencyHost.findFirst({
        where: { hostUserId: me, status: 'ACTIVE' },
        select: { agencyId: true },
      });
      if (!link) return null;
      if (link.agencyId !== agency.id) throw new AppException(ErrorCode.AGENCY_ALREADY_MEMBER);
      return { created: false, result: await this.mine(me) };
    };
    const before = await existing();
    if (before) return before;
    try {
      await this.prisma.$transaction(async (tx) => {
        const id = uuidv7();
        await tx.agencyHost.create({
          data: {
            id,
            agencyId: agency.id,
            hostUserId: me,
            commissionEligible: agency.rank !== 'LAPSED',
            activatedAt: this.clock.now(),
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AGENCY_JOIN,
            targetType: 'agency',
            targetId: agency.id,
            metadata: { link: id, rank: agency.rank },
          },
        });
        // v1.73-social (D209, §10.68): an agency host is not a direct host — a pending «كن مضيفاً مع الإدارة» goes.
        await cancelPendingHostApplicationIn(tx, me, 'AGENCY', this.clock.now());
      });
    } catch (err) {
      // A concurrent join (the partial unique index `agency_hosts_one_active`).
      const raced = await existing();
      if (raced) return raced;
      throw err;
    }
    // D186: past live time counts, so a new host may be active (and get the frame) at once.
    await this.syncHostFrames([me]);
    return { created: true, result: await this.mine(me) };
  }

  /** `POST /me/agency/leave`: 404 not a host → 409 AGENCY_LEAVE_WINDOW_CLOSED → 200. */
  async leave(me: string): Promise<MyAgencyDto> {
    const now = this.clock.now();
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    if (now.getTime() >= link.activatedAt.getTime() + this.config.economy.leaveDays * DAY_MS) {
      throw new AppException(ErrorCode.AGENCY_LEAVE_WINDOW_CLOSED);
    }
    await this.prisma.$transaction(async (tx) => {
      const ended = await tx.agencyHost.updateMany({
        where: { id: link.id, status: 'ACTIVE' },
        data: { status: 'LEFT', endedAt: now },
      });
      if (ended.count === 0) return;
      // An open complaint has no object any more.
      await tx.agencyComplaint.updateMany({
        where: { agencyHostId: link.id, status: 'OPEN' },
        data: {
          status: 'RESOLVED',
          resolution: 'RELEASED',
          note: 'left in the leave window',
          resolvedAt: now,
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: me,
          action: AuditAction.AGENCY_LEAVE,
          targetType: 'agency',
          targetId: link.agencyId,
          metadata: { link: link.id },
        },
      });
    });
    // D186: no agency, no active-host frame.
    await this.syncHostFrames([me]);
    return this.mine(me);
  }

  /** `POST /me/agency/complaints {text}`: 404 not a host → 400 → an open complaint → 200 → 201. */
  async complain(me: string, body: unknown): Promise<{ created: boolean; result: AgencyComplaintDto }> {
    const link = await this.prisma.agencyHost.findFirst({ where: { hostUserId: me, status: 'ACTIVE' } });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = complaintBodySchema.safeParse(body);
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const open = () =>
      this.prisma.agencyComplaint.findFirst({ where: { agencyHostId: link.id, status: 'OPEN' } });
    const before = await open();
    if (before) return { created: false, result: complaintDto(before) };
    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const row = await tx.agencyComplaint.create({
          data: {
            id: uuidv7(),
            agencyHostId: link.id,
            hostUserId: me,
            agencyId: link.agencyId,
            text: parsed.data.text,
            createdAt: this.clock.now(),
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AGENCY_COMPLAINT,
            targetType: 'agency_complaint',
            targetId: row.id,
            metadata: { agency: link.agencyId },
          },
        });
        return row;
      });
      return { created: true, result: complaintDto(created) };
    } catch (err) {
      const raced = await open();
      if (raced) return { created: false, result: complaintDto(raced) };
      throw err;
    }
  }

  /** `GET /me/agency/hosts`: the caller's agency's ACTIVE hosts, newest first (404 without an agency). */
  async hosts(me: string, query: PageQuery): Promise<PageDto<AgencyHostDto>> {
    const agency = await this.prisma.agency.findUnique({
      where: { ownerUserId: me },
      select: { id: true, status: true },
    });
    if (!agency || agency.status !== 'OPEN') throw new AppException(ErrorCode.NOT_FOUND);
    const scope = `agency-hosts:${agency.id}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const links = await this.prisma.agencyHost.findMany({
      where: {
        agencyId: agency.id,
        status: 'ACTIVE',
        ...(after
          ? { OR: [{ activatedAt: { lt: after.at } }, { activatedAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ activatedAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: {
        id: true,
        activatedAt: true,
        commissionEligible: true,
        hostUserId: true,
        host: { select: USER_SUMMARY_SELECT },
      },
    });
    const hasMore = links.length > query.limit;
    const page = links.slice(0, query.limit);
    const now = this.clock.now();
    const ids = page.map((l) => l.hostUserId);
    const [activity, cherries] = await Promise.all([
      ids.length === 0
        ? []
        : hostActivity(this.prisma, [agency.id], now, this.config.economy, this.zone, ids),
      ids.length === 0
        ? []
        : this.prisma.agencyEarning.groupBy({
            by: ['hostUserId'],
            where: {
              agencyId: agency.id,
              month: dateValue(monthKey(now, this.zone)),
              hostUserId: { in: ids },
              reversedAt: null,
            },
            _sum: { hostCherries: true },
          }),
    ]);
    const act = new Map(activity.map((a) => [a.hostUserId, a]));
    const month = new Map(cherries.map((c) => [c.hostUserId, c._sum.hostCherries ?? 0n]));
    const kinds = await this.hostingOf(agency.id, ids);
    const last = page[page.length - 1];
    return {
      data: page.map((l) => {
        const a = act.get(l.hostUserId);
        const k = kinds.get(l.hostUserId);
        return {
          user: userSummary(l.host),
          joinedAt: l.activatedAt.toISOString(),
          liveDays: a?.liveDays ?? 0,
          liveSeconds: a?.liveSeconds ?? 0,
          active: a?.active ?? false,
          monthCherries: Number(month.get(l.hostUserId) ?? 0n),
          commissionEligible: l.commissionEligible,
          hosting: k?.hosting ?? 'NONE',
          activatedByAgency: k?.byAgency ?? false,
        };
      }),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.cursors.encode(scope, { at: last.activatedAt, id: last.id }) : null,
      },
    };
  }

  /** v1.82-live (D295): each member's hosting kind and whether this agency activated it. */
  private async hostingOf(
    agencyId: string,
    ids: readonly string[],
  ): Promise<Map<string, { hosting: 'NONE' | 'HOST' | 'CREATOR'; byAgency: boolean }>> {
    if (ids.length === 0) return new Map();
    const [hosts, creators] = await Promise.all([
      this.prisma.liveHost.findMany({
        where: { userId: { in: [...ids] } },
        select: { userId: true, source: true, grantedById: true },
      }),
      this.prisma.creatorMember.findMany({
        where: { userId: { in: [...ids] } },
        select: { userId: true, application: { select: { agencyId: true } } },
      }),
    ]);
    const owner = await this.prisma.agency.findUnique({
      where: { id: agencyId },
      select: { ownerUserId: true },
    });
    const out = new Map<string, { hosting: 'NONE' | 'HOST' | 'CREATOR'; byAgency: boolean }>();
    for (const h of hosts) {
      if (h.source !== 'CREATOR') {
        out.set(h.userId, {
          hosting: 'HOST',
          byAgency: h.source === 'AGENCY' && h.grantedById !== null && h.grantedById === owner?.ownerUserId,
        });
      }
    }
    for (const c of creators) {
      out.set(c.userId, { hosting: 'CREATOR', byAgency: c.application.agencyId === agencyId });
    }
    return out;
  }

  /**
   * v1.82-live (D295, owner, CONVENTIONS §10.108): `POST /me/agency/hosts/{userId}/activate` — the agency's owner
   * activates one of its ACTIVE members as a host «مضيف» (the hosting permission, source AGENCY) or as a content
   * creator «صانع محتوى» (a creator membership at once, recorded with the agency: «فعّله وكيل: …» in the panel; the
   * hosting permission CREATOR). Order: 404 (no OPEN agency of the caller, or not its ACTIVE member) → 400 body → 409
   * AGENCY_ACTIVATION_NOT_ALLOWED (`AGENCY_SUSPENDED`, `ACCOUNT_NOT_ACTIVE`, `STAFF`, `HOST` — a host cannot be made a
   * creator, `CREATOR` — a creator cannot be made a host) → 200 (also when already activated as asked: unchanged).
   * Audited `agency.member.activate` (+ `live.host.grant`); a pending «انضم كصانع محتوى» of the member is cancelled.
   */
  async activateMember(me: string, memberUserId: string, body: unknown): Promise<AgencyHostDto> {
    const agency = await this.prisma.agency.findUnique({
      where: { ownerUserId: me },
      select: { id: true, status: true, suspendedAt: true },
    });
    if (!agency || agency.status !== 'OPEN' || !UUID.test(memberUserId))
      throw new AppException(ErrorCode.NOT_FOUND);
    const member = memberUserId.toLowerCase();
    const link = await this.prisma.agencyHost.findFirst({
      where: { agencyId: agency.id, hostUserId: member, status: 'ACTIVE' },
      select: { id: true },
    });
    if (!link) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = activateMemberBodySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const refused = (issue: AgencyActivationRefusal) =>
      new AppException(ErrorCode.AGENCY_ACTIVATION_NOT_ALLOWED, undefined, [{ field: 'member', issue }]);
    if (agency.suspendedAt !== null) throw refused('AGENCY_SUSPENDED');
    const user = await this.prisma.user.findUnique({
      where: { id: member },
      select: { status: true, deletedAt: true },
    });
    if (!user || user.deletedAt !== null || user.status !== 'ACTIVE') throw refused('ACCOUNT_NOT_ACTIVE');
    if (await isLimitedStaff(this.prisma, member)) throw refused('STAFF');
    const now = this.clock.now();
    const by = { via: 'app' as const, actorUserId: me };
    await this.prisma.$transaction(async (tx) => {
      // The member's rows in a fixed order (as `activateCreatorIn`), so a concurrent activation waits.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`creator-host:${member}`}, 0))`;
      const kind = await hostKindIn(tx, member);
      if (input.as === 'HOST') {
        if (kind === 'CREATOR') throw refused('CREATOR');
        if (kind === 'HOST') return; // already a host: unchanged
        let created = 0;
        for (let attempt = 0; attempt < 5 && created === 0; attempt += 1) {
          created = (
            await tx.liveHost.createMany({
              data: [{ userId: member, source: 'AGENCY', grantedById: me, grantedAt: now }],
              skipDuplicates: true,
            })
          ).count;
          if (created === 0 && (await tx.liveHost.count({ where: { userId: member } })) > 0) break;
        }
        if (created === 0) return;
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.LIVE_HOST_GRANT,
            targetType: 'user',
            targetId: member,
            metadata: { source: 'AGENCY', agency: agency.id, via: 'agency' },
          },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.AGENCY_MEMBER_ACTIVATE,
            targetType: 'user',
            targetId: member,
            metadata: { agency: agency.id, member, as: 'HOST', after: 'HOST' },
          },
        });
        return;
      }
      if (kind === 'HOST') throw refused('HOST');
      if (kind === 'CREATOR') return; // already a creator: unchanged
      // A pending «انضم كصانع محتوى» of the member gives way to the agency's activation.
      await tx.creatorApplication.updateMany({
        where: { userId: member, status: 'PENDING' },
        data: { status: 'CANCELLED', decidedAt: now },
      });
      const applicationId = uuidv7();
      await tx.creatorApplication.create({
        data: {
          id: applicationId,
          userId: member,
          status: 'APPROVED',
          source: 'AGENCY',
          agencyId: agency.id,
          country: input.country,
          category: input.category,
          links: input.links,
          bio: input.bio && input.bio !== '' ? input.bio : null,
          createdAt: now,
          decidedAt: now,
          decidedById: me,
        },
      });
      try {
        await activateCreatorIn(tx, {
          userId: member,
          applicationId,
          now,
          by,
          via: 'agency',
          agencyId: agency.id,
        });
      } catch (err) {
        if (err instanceof CreatorHostConflictError) throw refused('HOST');
        throw err;
      }
      // v1.90-social (D293, §10.105): the purple creator badge at once (unless a higher one applies), as an approved
      // «انضم كصانع محتوى» application gives it.
      await recomputeBadgesIn(tx, [member], 'creator', now);
      await tx.auditLog.create({
        data: {
          actorUserId: me,
          action: AuditAction.AGENCY_MEMBER_ACTIVATE,
          targetType: 'user',
          targetId: member,
          metadata: {
            agency: agency.id,
            member,
            as: 'CREATOR',
            application: applicationId,
            country: input.country,
            category: input.category,
            links: input.links.length,
            warningConfirmed: true,
            after: 'CREATOR',
          },
        },
      });
    });
    const rows = await this.hosts(me, { limit: 50 });
    const row = rows.data.find((r) => r.user.id === member);
    if (row) return row;
    return this.memberRow(agency.id, link.id);
  }

  /** One member's row (when it is not on the first page of `hosts`). */
  private async memberRow(agencyId: string, linkId: string): Promise<AgencyHostDto> {
    const l = await this.prisma.agencyHost.findUniqueOrThrow({
      where: { id: linkId },
      select: {
        activatedAt: true,
        commissionEligible: true,
        hostUserId: true,
        host: { select: USER_SUMMARY_SELECT },
      },
    });
    const now = this.clock.now();
    const [activity, kinds] = await Promise.all([
      hostActivity(this.prisma, [agencyId], now, this.config.economy, this.zone, [l.hostUserId]),
      this.hostingOf(agencyId, [l.hostUserId]),
    ]);
    const sum = await this.prisma.agencyEarning.aggregate({
      where: {
        agencyId,
        hostUserId: l.hostUserId,
        month: dateValue(monthKey(now, this.zone)),
        reversedAt: null,
      },
      _sum: { hostCherries: true },
    });
    const a = activity[0];
    const k = kinds.get(l.hostUserId);
    return {
      user: userSummary(l.host),
      joinedAt: l.activatedAt.toISOString(),
      liveDays: a?.liveDays ?? 0,
      liveSeconds: a?.liveSeconds ?? 0,
      active: a?.active ?? false,
      monthCherries: Number(sum._sum.hostCherries ?? 0n),
      commissionEligible: l.commissionEligible,
      hosting: k?.hosting ?? 'NONE',
      activatedByAgency: k?.byAgency ?? false,
    };
  }
}
