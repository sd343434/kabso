import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { FamilyRole, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { MediaService } from '../media/media.service.js';
import { awardMedalsIn } from '../medals/medal-awards.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { blockedEitherWayIn } from '../social/pair-lock.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import {
  FAMILY_CAPACITY,
  FAMILY_CREATE_COST_COINS,
  FAMILY_LEVELS,
  FAMILY_REQUEST_TTL_MS,
  familyNextLevelPoints,
  type FamilyLevelStep,
} from './families.constants.js';
import {
  createFamilySchema,
  setFamilyRoleSchema,
  transferFamilySchema,
  updateFamilySchema,
  type FamilySearchQuery,
} from './families.schemas.js';
import { familyNameIssue, familyNameKey, normalizeFamilyName } from './family-name.js';

type Tx = Prisma.TransactionClient;

// ---- Response shapes (openapi v1.21-live, CP-018) ----------------------------------------------

/** `FamilyCard`: a family in lists. */
export interface FamilyCardDto {
  id: string;
  number: number;
  name: string;
  emblemUrl: string | null;
  level: number;
  points: number;
  memberCount: number;
  capacity: number;
}

/** `Family`: one family, with the caller's place in it. */
export interface FamilyDto extends FamilyCardDto {
  nextLevelPoints: number | null;
  leader: UserSummaryDto | null;
  createdAt: string;
  /** The caller's role in this family, or null. */
  myRole: FamilyRole | null;
  /** The caller's pending join request to this family, or null. */
  myRequestId: string | null;
}

/** `FamilyMember`. */
export interface FamilyMemberDto {
  user: UserSummaryDto;
  role: FamilyRole;
  joinedAt: string;
  /** Family points this member gave while in the family. */
  points: number;
}

/** `FamilyJoinRequest`. */
export interface FamilyJoinRequestDto {
  id: string;
  family: FamilyCardDto;
  user: UserSummaryDto;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';
  createdAt: string;
  expiresAt: string;
}

/** `CreateFamilyResult`: the family and the creator's balance after the charge. */
export interface CreateFamilyResultDto {
  family: FamilyDto;
  coins: number;
}

/** `FamilyConfig`. */
export interface FamilyConfigDto {
  createCost: number;
  capacity: number;
  requestTtlDays: number;
  levels: FamilyLevelStep[];
}

/** `ProfileFamily`: a user's family on their public profile (§10.5, §10.21). */
export interface ProfileFamilyDto {
  id: string;
  number: number;
  name: string;
  level: number;
  emblemUrl: string | null;
  role: FamilyRole;
}

export interface RequestMeta {
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

const FAMILY_SELECT = {
  id: true,
  number: true,
  name: true,
  emblemUrl: true,
  level: true,
  points: true,
  memberCount: true,
  createdAt: true,
} as const satisfies Prisma.FamilySelect;
type FamilyRow = Prisma.FamilyGetPayload<{ select: typeof FAMILY_SELECT }>;

const REQUEST_INCLUDE = {
  family: { select: FAMILY_SELECT },
  user: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.FamilyJoinRequestInclude;
type RequestRow = Prisma.FamilyJoinRequestGetPayload<{ include: typeof REQUEST_INCLUDE }>;

const ROLE_ORDER: readonly FamilyRole[] = ['LEADER', 'DEPUTY', 'MEMBER'];
const DAY_MS = 24 * 3600_000;
const SWEEP_BATCH = 1000;
/** Attempts at drawing a free family number (a clash is about 1 in 90 million per family). */
const NUMBER_ATTEMPTS = 3;

function card(row: FamilyRow): FamilyCardDto {
  return {
    id: row.id,
    number: row.number,
    name: row.name,
    emblemUrl: row.emblemUrl,
    level: row.level,
    points: Number(row.points),
    memberCount: row.memberCount,
    capacity: FAMILY_CAPACITY,
  };
}

function requestDto(row: RequestRow, now: Date): FamilyJoinRequestDto {
  const expired = row.status === 'PENDING' && row.expiresAt <= now;
  return {
    id: row.id,
    family: card(row.family),
    user: userSummary(row.user),
    status: expired ? 'EXPIRED' : row.status,
    createdAt: row.createdAt.toISOString(),
    expiresAt: row.expiresAt.toISOString(),
  };
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * Families (العائلة, CP-018, owner D106, CONVENTIONS §10.21). A user creates one for
 * {@link FAMILY_CREATE_COST_COINS} coins and leads it; others ask to join and the leader or a
 * deputy accepts; at most {@link FAMILY_CAPACITY} members; a user is in at most one family. The
 * family's points are the coins its members spend in the app while in it (family-points.ts), and
 * its level follows {@link FAMILY_LEVELS}. Join requests expire after 7 days (lazily, and by the
 * sweeper).
 */
@Injectable()
export class FamiliesService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(FamiliesService.name);
  private readonly cursors: SocialCursorCodec;
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly wallet: WalletService,
    private readonly media: MediaService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.social.bondsSweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /** `GET /families/config`. */
  configDto(): FamilyConfigDto {
    return {
      createCost: FAMILY_CREATE_COST_COINS,
      capacity: FAMILY_CAPACITY,
      requestTtlDays: FAMILY_REQUEST_TTL_MS / DAY_MS,
      levels: FAMILY_LEVELS.map((step) => ({ ...step })),
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Reading

  /** The full `Family` for `callerId`. */
  private async familyDto(callerId: string, row: FamilyRow): Promise<FamilyDto> {
    const [leader, mine, request] = await Promise.all([
      this.prisma.familyMember.findFirst({
        where: { familyId: row.id, role: 'LEADER' },
        select: { user: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.familyMember.findUnique({
        where: { userId: callerId },
        select: { familyId: true, role: true },
      }),
      this.prisma.familyJoinRequest.findFirst({
        where: { familyId: row.id, userId: callerId, status: 'PENDING', expiresAt: { gt: this.clock.now() } },
        select: { id: true },
      }),
    ]);
    return {
      ...card(row),
      nextLevelPoints: familyNextLevelPoints(row.level),
      leader: leader ? userSummary(leader.user) : null,
      createdAt: row.createdAt.toISOString(),
      myRole: mine?.familyId === row.id ? mine.role : null,
      myRequestId: request?.id ?? null,
    };
  }

  private async visibleRow(familyId: string): Promise<FamilyRow> {
    if (!isUuid(familyId)) throw notFound();
    const row = await this.prisma.family.findFirst({
      where: { id: familyId.toLowerCase(), disbandedAt: null },
      select: FAMILY_SELECT,
    });
    if (!row) throw notFound();
    return row;
  }

  /** `GET /families/{familyId}`: a disbanded, unknown or malformed id → 404. */
  async get(callerId: string, familyId: string): Promise<FamilyDto> {
    return this.familyDto(callerId, await this.visibleRow(familyId));
  }

  /** `GET /family-numbers/{number}`. */
  async getByNumber(callerId: string, number: string): Promise<FamilyDto> {
    if (!/^\d{8}$/.test(number)) throw notFound();
    const row = await this.prisma.family.findFirst({
      where: { number: Number(number), disbandedAt: null },
      select: FAMILY_SELECT,
    });
    if (!row) throw notFound();
    return this.familyDto(callerId, row);
  }

  /** `GET /families/me`: the caller's family, or null. */
  async mine(callerId: string): Promise<{ family: FamilyDto | null }> {
    const member = await this.prisma.familyMember.findUnique({
      where: { userId: callerId },
      select: { family: { select: FAMILY_SELECT } },
    });
    return { family: member ? await this.familyDto(callerId, member.family) : null };
  }

  /**
   * `GET /families`: families by points (highest first, then id). `q` filters by name (contains,
   * case-insensitive) or, when it is 1–8 digits, also by the exact family number.
   */
  async search(query: FamilySearchQuery): Promise<PageDto<FamilyCardDto>> {
    const q = query.q ?? '';
    const scope = `families:${familyNameKey(q)}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after || after.n === undefined) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
    }
    const filter: Prisma.FamilyWhereInput =
      q === ''
        ? {}
        : {
            OR: [
              { nameKey: { contains: familyNameKey(q) } },
              ...(/^\d{1,8}$/.test(q) ? [{ number: Number(q) }] : []),
            ],
          };
    const rows = await this.prisma.family.findMany({
      where: {
        AND: [
          { disbandedAt: null },
          filter,
          after
            ? {
                OR: [
                  { points: { lt: BigInt(after.n ?? 0) } },
                  { points: BigInt(after.n ?? 0), id: { lt: after.id } },
                ],
              }
            : {},
        ],
      },
      orderBy: [{ points: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: FAMILY_SELECT,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map(card),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, { at: last.createdAt, id: last.id, n: Number(last.points) })
            : null,
      },
    };
  }

  /**
   * `GET /families/{familyId}/members`: the leader, then deputies, then members, each by join
   * time (ACTIVE accounts only).
   */
  async members(familyId: string, query: PageQuery): Promise<PageDto<FamilyMemberDto>> {
    const family = await this.visibleRow(familyId);
    const scope = `family-members:${family.id}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after || after.n === undefined || ROLE_ORDER[after.n] === undefined) {
        throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      }
    }
    let position: Prisma.FamilyMemberWhereInput = {};
    if (after) {
      const role = ROLE_ORDER[after.n ?? 0]!;
      position = {
        OR: [
          { role: { in: ROLE_ORDER.slice((after.n ?? 0) + 1) } },
          { role, joinedAt: { gt: after.at } },
          { role, joinedAt: after.at, userId: { gt: after.id } },
        ],
      };
    }
    const rows = await this.prisma.familyMember.findMany({
      where: { AND: [{ familyId: family.id, user: { status: 'ACTIVE' } }, position] },
      orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }, { userId: 'asc' }],
      take: query.limit + 1,
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((m) => ({
        user: userSummary(m.user),
        role: m.role,
        joinedAt: m.joinedAt.toISOString(),
        points: Number(m.points),
      })),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, {
                at: last.joinedAt,
                id: last.userId,
                n: ROLE_ORDER.indexOf(last.role),
              })
            : null,
      },
    };
  }

  /** A user's family on their public profile (§10.5), or null. */
  async profileFamily(userId: string): Promise<ProfileFamilyDto | null> {
    const member = await this.prisma.familyMember.findUnique({
      where: { userId },
      select: { role: true, family: { select: FAMILY_SELECT } },
    });
    if (!member) return null;
    const f = member.family;
    return {
      id: f.id,
      number: f.number,
      name: f.name,
      level: f.level,
      emblemUrl: f.emblemUrl,
      role: member.role,
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Creating, editing, disbanding

  /**
   * `POST /families`. Order after auth and rate limit: 400 body (`name` text rules, `clientId`); a
   * retry with the same `clientId` → 200 with the family (409 IDEMPOTENCY_CONFLICT when it was
   * disbanded since); 503 MEDIA_UPLOADS_UNAVAILABLE for an emblem while uploads are off; 409
   * ALREADY_IN_FAMILY; 400 `emblemMediaId` / `invalid_value`; 409 FAMILY_NAME_TAKEN; 409
   * INSUFFICIENT_COINS. The family, the leader's membership, the 500-coin charge (ledger
   * FAMILY_CREATE, reference the family id), the family points it gives, the FIRST_FAMILY medal
   * and the audit row are one transaction.
   */
  async create(
    callerId: string,
    body: unknown,
    meta: RequestMeta,
  ): Promise<{ created: boolean; result: CreateFamilyResultDto }> {
    const parsed = createFamilySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const issue = familyNameIssue(
      parsed.data.name,
      this.config.reservedDisplayNameTerms,
      this.config.reservedDisplayNameBrandTerms,
    );
    if (issue) throw AppException.validation([{ field: 'name', issue }]);
    const name = normalizeFamilyName(parsed.data.name);
    const clientId = parsed.data.clientId.toLowerCase();
    const emblemId = parsed.data.emblemMediaId?.toLowerCase() ?? null;

    const replay = await this.replayCreate(callerId, clientId);
    if (replay) return { created: false, result: replay };
    if (emblemId !== null) this.media.assertEnabled();

    for (let attempt = 1; ; attempt++) {
      try {
        const created = await this.prisma.$transaction((tx) =>
          this.createIn(tx, callerId, { name, clientId, emblemId }, meta),
        );
        return {
          created: true,
          result: { family: await this.familyDto(callerId, created.family), coins: Number(created.coins) },
        };
      } catch (err) {
        const index = violatedUniqueIndex(err);
        if (index === null) throw err;
        if (index.includes('families_create_once')) {
          const raced = await this.replayCreate(callerId, clientId);
          if (raced) return { created: false, result: raced };
        }
        if (index.includes('families_name_key_active') || index === 'name_key') {
          throw new AppException(ErrorCode.FAMILY_NAME_TAKEN);
        }
        if (index.includes('family_members_pkey') || index === 'user_id') {
          throw new AppException(ErrorCode.ALREADY_IN_FAMILY);
        }
        if ((index.includes('families_number_key') || index === 'number') && attempt < NUMBER_ATTEMPTS)
          continue;
        throw err;
      }
    }
  }

  private async createIn(
    tx: Tx,
    callerId: string,
    input: { name: string; clientId: string; emblemId: string | null },
    meta: RequestMeta,
  ): Promise<{ family: FamilyRow; coins: bigint }> {
    const now = this.clock.now();
    if ((await tx.familyMember.count({ where: { userId: callerId } })) > 0) {
      throw new AppException(ErrorCode.ALREADY_IN_FAMILY);
    }
    let emblemUrl: string | null = null;
    if (input.emblemId !== null) {
      const claimed = await this.media.claimAssetsIn(tx, callerId, [input.emblemId], 'FAMILY_EMBLEM');
      if (!claimed) throw AppException.validation([{ field: 'emblemMediaId', issue: 'invalid_value' }]);
      emblemUrl = this.media.largeUrl(claimed[0]!);
    }
    const family = await tx.family.create({
      data: {
        name: input.name,
        nameKey: familyNameKey(input.name),
        emblemMediaId: input.emblemId,
        emblemUrl,
        memberCount: 1,
        createdById: callerId,
        createClientId: input.clientId,
        createdAt: now,
        updatedAt: now,
      },
      select: FAMILY_SELECT,
    });
    await tx.familyMember.create({
      data: { userId: callerId, familyId: family.id, role: 'LEADER', joinedAt: now },
    });
    // The caller now has a family: a pending request elsewhere is moot.
    await tx.familyJoinRequest.updateMany({
      where: { userId: callerId, status: 'PENDING' },
      data: { status: 'CANCELLED', handledAt: now },
    });
    const charged = await this.wallet.debitIn(
      tx,
      callerId,
      FAMILY_CREATE_COST_COINS,
      'FAMILY_CREATE',
      family.id,
    );
    if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
    await awardMedalsIn(tx, callerId, ['FIRST_FAMILY'], { at: now });
    await this.audit.recordIn(tx, {
      action: AuditAction.FAMILY_CREATE,
      actorUserId: callerId,
      targetType: 'family',
      targetId: family.id,
      metadata: { number: family.number, coins: FAMILY_CREATE_COST_COINS, ledgerId: charged.ledgerId },
      ip: meta.ip ?? null,
      requestId: meta.requestId ?? null,
    });
    const after = await tx.family.findUniqueOrThrow({ where: { id: family.id }, select: FAMILY_SELECT });
    return { family: after, coins: charged.coins };
  }

  private async replayCreate(callerId: string, clientId: string): Promise<CreateFamilyResultDto | null> {
    const row = await this.prisma.family.findUnique({
      where: { createdById_createClientId: { createdById: callerId, createClientId: clientId } },
      select: { ...FAMILY_SELECT, disbandedAt: true },
    });
    if (!row) return null;
    if (row.disbandedAt !== null) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    return { family: await this.familyDto(callerId, row), coins: (await this.wallet.mine(callerId)).coins };
  }

  /** Locks a family that is not disbanded (FOR UPDATE), else 404. */
  private async lockFamily(tx: Tx, familyId: string): Promise<{ id: string; member_count: number }> {
    if (!isUuid(familyId)) throw notFound();
    const [row] = await tx.$queryRaw<{ id: string; member_count: number }[]>`
      SELECT id::text AS id, member_count FROM families
       WHERE id = ${familyId.toLowerCase()}::uuid AND disbanded_at IS NULL
         FOR UPDATE`;
    if (!row) throw notFound();
    return row;
  }

  /** The caller's role in `familyId`, or null. */
  private async roleIn(tx: Tx, familyId: string, userId: string): Promise<FamilyRole | null> {
    const row = await tx.familyMember.findUnique({
      where: { userId },
      select: { familyId: true, role: true },
    });
    return row?.familyId === familyId ? row.role : null;
  }

  /** `PATCH /families/{familyId}`: the leader sets (or with null removes) the emblem. */
  async update(callerId: string, familyId: string, body: unknown): Promise<FamilyDto> {
    const parsed = updateFamilySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const emblemId = parsed.data.emblemMediaId?.toLowerCase() ?? null;
    if (emblemId !== null) this.media.assertEnabled();
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await this.roleIn(tx, family.id, callerId)) !== 'LEADER')
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const current = await tx.family.findUniqueOrThrow({
        where: { id: family.id },
        select: { emblemMediaId: true },
      });
      if (current.emblemMediaId === emblemId) return [];
      let emblemUrl: string | null = null;
      if (emblemId !== null) {
        const claimed = await this.media.claimAssetsIn(tx, callerId, [emblemId], 'FAMILY_EMBLEM');
        if (!claimed) throw AppException.validation([{ field: 'emblemMediaId', issue: 'invalid_value' }]);
        emblemUrl = this.media.largeUrl(claimed[0]!);
      }
      await tx.family.update({
        where: { id: family.id },
        data: { emblemMediaId: emblemId, emblemUrl, updatedAt: this.clock.now() },
      });
      return this.deleteAssetIn(tx, current.emblemMediaId);
    });
    await this.media.deleteObjects(oldKeys);
    return this.get(callerId, familyId);
  }

  private async deleteAssetIn(tx: Tx, assetId: string | null): Promise<string[]> {
    if (assetId === null) return [];
    const gone = await tx.mediaAsset.delete({
      where: { id: assetId },
      select: { largeKey: true, thumbKey: true },
    });
    return [gone.largeKey, gone.thumbKey];
  }

  /**
   * `DELETE /families/{familyId}`: the leader disbands a family that has only them (else 409
   * FAMILY_NOT_EMPTY). The row stays (`disbanded_at`; its name becomes free), the membership and
   * pending requests go, the emblem is deleted; audited `family.disband`. No coins come back.
   */
  async disband(callerId: string, familyId: string, meta: RequestMeta): Promise<void> {
    const oldKeys = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await this.roleIn(tx, family.id, callerId)) !== 'LEADER')
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      if (family.member_count > 1) throw new AppException(ErrorCode.FAMILY_NOT_EMPTY);
      const now = this.clock.now();
      await tx.familyMember.deleteMany({ where: { familyId: family.id } });
      await tx.familyJoinRequest.updateMany({
        where: { familyId: family.id, status: 'PENDING' },
        data: { status: 'CANCELLED', handledAt: now },
      });
      const before = await tx.family.findUniqueOrThrow({
        where: { id: family.id },
        select: { emblemMediaId: true },
      });
      await tx.family.update({
        where: { id: family.id },
        data: { disbandedAt: now, memberCount: 0, emblemMediaId: null, emblemUrl: null, updatedAt: now },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.FAMILY_DISBAND,
        actorUserId: callerId,
        targetType: 'family',
        targetId: family.id,
        ip: meta.ip ?? null,
        requestId: meta.requestId ?? null,
      });
      return this.deleteAssetIn(tx, before.emblemMediaId);
    });
    await this.media.deleteObjects(oldKeys);
  }

  // ---------------------------------------------------------------------------------------------
  // Membership

  /** `POST /families/{familyId}/leave`: a member or deputy leaves; the leader cannot (409). */
  async leave(callerId: string, familyId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      const role = await this.roleIn(tx, family.id, callerId);
      if (role === null) throw notFound();
      if (role === 'LEADER') throw new AppException(ErrorCode.FAMILY_LEADER_CANNOT_LEAVE);
      await tx.familyMember.delete({ where: { userId: callerId } });
      await tx.family.update({ where: { id: family.id }, data: { memberCount: { decrement: 1 } } });
    });
  }

  /** A member of `familyId` by username (ACTIVE), locked with the family; else 404. */
  private async memberByUsername(
    tx: Tx,
    familyId: string,
    username: string,
  ): Promise<{ id: string; role: FamilyRole }> {
    const target = await this.users.lockActiveByUsername(tx, username);
    if (!target) throw notFound();
    const role = await this.roleIn(tx, familyId, target.id);
    if (role === null) throw notFound();
    return { id: target.id, role };
  }

  /**
   * `DELETE /families/{familyId}/members/{username}`: the leader removes a deputy or a member
   * (403 for anyone else; the leader cannot remove themselves: 400 `username`). Audited.
   */
  async removeMember(callerId: string, familyId: string, username: string, meta: RequestMeta): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await this.roleIn(tx, family.id, callerId)) !== 'LEADER')
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const target = await this.memberByUsername(tx, family.id, username);
      if (target.id === callerId)
        throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
      await tx.familyMember.delete({ where: { userId: target.id } });
      await tx.family.update({ where: { id: family.id }, data: { memberCount: { decrement: 1 } } });
      await this.audit.recordIn(tx, {
        action: AuditAction.FAMILY_MEMBER_REMOVE,
        actorUserId: callerId,
        targetType: 'user',
        targetId: target.id,
        metadata: { familyId: family.id },
        ip: meta.ip ?? null,
        requestId: meta.requestId ?? null,
      });
    });
  }

  /** `PUT /families/{familyId}/members/{username}/role`: the leader makes someone DEPUTY or MEMBER. */
  async setRole(
    callerId: string,
    familyId: string,
    username: string,
    body: unknown,
  ): Promise<FamilyMemberDto> {
    const parsed = setFamilyRoleSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const userId = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await this.roleIn(tx, family.id, callerId)) !== 'LEADER')
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const target = await this.memberByUsername(tx, family.id, username);
      if (target.id === callerId)
        throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
      await tx.familyMember.update({ where: { userId: target.id }, data: { role: parsed.data.role } });
      return target.id;
    });
    return this.memberDto(userId);
  }

  private async memberDto(userId: string): Promise<FamilyMemberDto> {
    const m = await this.prisma.familyMember.findUniqueOrThrow({
      where: { userId },
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return {
      user: userSummary(m.user),
      role: m.role,
      joinedAt: m.joinedAt.toISOString(),
      points: Number(m.points),
    };
  }

  /**
   * `POST /families/{familyId}/transfer`: the leader hands the family to another member, who
   * becomes LEADER; the old leader becomes DEPUTY. Audited `family.transfer`.
   */
  async transfer(callerId: string, familyId: string, body: unknown, meta: RequestMeta): Promise<FamilyDto> {
    const parsed = transferFamilySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await this.roleIn(tx, family.id, callerId)) !== 'LEADER')
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const target = await this.memberByUsername(tx, family.id, parsed.data.username);
      if (target.id === callerId)
        throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
      await tx.familyMember.update({ where: { userId: callerId }, data: { role: 'DEPUTY' } });
      await tx.familyMember.update({ where: { userId: target.id }, data: { role: 'LEADER' } });
      await this.audit.recordIn(tx, {
        action: AuditAction.FAMILY_TRANSFER,
        actorUserId: callerId,
        targetType: 'family',
        targetId: family.id,
        metadata: { to: target.id },
        ip: meta.ip ?? null,
        requestId: meta.requestId ?? null,
      });
    });
    return this.get(callerId, familyId);
  }

  // ---------------------------------------------------------------------------------------------
  // Join requests

  /**
   * `POST /families/{familyId}/join-requests`. Order: 404 family; 409 ALREADY_IN_FAMILY (the
   * caller has a family, this one included); a pending request to this family → 200 with it; 409
   * FAMILY_REQUEST_PENDING (a pending request to another family; cancel it first); 403
   * AUTH_FORBIDDEN (the caller and the leader blocked each other, either way); 409 FAMILY_FULL.
   */
  async requestJoin(
    callerId: string,
    familyId: string,
  ): Promise<{ created: boolean; request: FamilyJoinRequestDto }> {
    const now = this.clock.now();
    const result = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      if ((await tx.familyMember.count({ where: { userId: callerId } })) > 0) {
        throw new AppException(ErrorCode.ALREADY_IN_FAMILY);
      }
      // A request that ran out of time is EXPIRED, not pending.
      await tx.familyJoinRequest.updateMany({
        where: { userId: callerId, status: 'PENDING', expiresAt: { lte: now } },
        data: { status: 'EXPIRED', handledAt: now },
      });
      const pending = await tx.familyJoinRequest.findFirst({
        where: { userId: callerId, status: 'PENDING' },
        select: { id: true, familyId: true },
      });
      if (pending?.familyId === family.id) return { created: false, id: pending.id };
      if (pending) throw new AppException(ErrorCode.FAMILY_REQUEST_PENDING);
      const leader = await tx.familyMember.findFirst({
        where: { familyId: family.id, role: 'LEADER' },
        select: { userId: true },
      });
      if (leader && (await blockedEitherWayIn(tx, callerId, leader.userId))) {
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      }
      if (family.member_count >= FAMILY_CAPACITY) throw new AppException(ErrorCode.FAMILY_FULL);
      const created = await tx.familyJoinRequest.create({
        data: {
          familyId: family.id,
          userId: callerId,
          createdAt: now,
          expiresAt: new Date(now.getTime() + FAMILY_REQUEST_TTL_MS),
        },
        select: { id: true },
      });
      return { created: true, id: created.id };
    });
    return { created: result.created, request: await this.requestById(result.id) };
  }

  private async requestById(id: string): Promise<FamilyJoinRequestDto> {
    const row = await this.prisma.familyJoinRequest.findUniqueOrThrow({
      where: { id },
      include: REQUEST_INCLUDE,
    });
    return requestDto(row, this.clock.now());
  }

  /** `GET /me/family-join-request`: the caller's pending join request, or null. */
  async myRequest(callerId: string): Promise<{ request: FamilyJoinRequestDto | null }> {
    const row = await this.prisma.familyJoinRequest.findFirst({
      where: { userId: callerId, status: 'PENDING', expiresAt: { gt: this.clock.now() } },
      include: REQUEST_INCLUDE,
    });
    return { request: row ? requestDto(row, this.clock.now()) : null };
  }

  /** `DELETE /me/family-join-request`: the caller cancels their pending request (none → no-op). */
  async cancelMyRequest(callerId: string): Promise<void> {
    const now = this.clock.now();
    await this.prisma.familyJoinRequest.updateMany({
      where: { userId: callerId, status: 'PENDING', expiresAt: { lte: now } },
      data: { status: 'EXPIRED', handledAt: now },
    });
    await this.prisma.familyJoinRequest.updateMany({
      where: { userId: callerId, status: 'PENDING' },
      data: { status: 'CANCELLED', handledAt: now },
    });
  }

  /** `GET /families/{familyId}/join-requests`: pending requests, oldest first (leader, deputies). */
  async listRequests(
    callerId: string,
    familyId: string,
    query: PageQuery,
  ): Promise<PageDto<FamilyJoinRequestDto>> {
    const family = await this.visibleRow(familyId);
    const role = await this.roleIn(this.prisma, family.id, callerId);
    if (role !== 'LEADER' && role !== 'DEPUTY') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const now = this.clock.now();
    const scope = `family-requests:${family.id}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const rows = await this.prisma.familyJoinRequest.findMany({
      where: {
        AND: [
          { familyId: family.id, status: 'PENDING', expiresAt: { gt: now }, user: { status: 'ACTIVE' } },
          after
            ? { OR: [{ createdAt: { gt: after.at } }, { createdAt: after.at, id: { gt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: query.limit + 1,
      include: REQUEST_INCLUDE,
    });
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: page.map((r) => requestDto(r, now)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /** Locks a request of `familyId` (404 otherwise). */
  private async lockRequest(
    tx: Tx,
    familyId: string,
    requestId: string,
  ): Promise<{ id: string; user_id: string; status: string; expires_at: Date }> {
    if (!isUuid(requestId)) throw notFound();
    const [row] = await tx.$queryRaw<{ id: string; user_id: string; status: string; expires_at: Date }[]>`
      SELECT id::text AS id, user_id::text AS user_id, status::text AS status, expires_at
        FROM family_join_requests
       WHERE id = ${requestId.toLowerCase()}::uuid AND family_id = ${familyId}::uuid
         FOR UPDATE`;
    if (!row) throw notFound();
    return row;
  }

  /**
   * `POST /families/{familyId}/join-requests/{requestId}/accept` (leader or deputy). Order: 404
   * family; 403 not leader or deputy; 404 request; 409 FAMILY_REQUEST_NOT_PENDING (handled,
   * cancelled or expired); 409 ALREADY_IN_FAMILY (the requester joined another family meanwhile;
   * the request is closed as CANCELLED); 409 FAMILY_FULL (the request stays pending). The member,
   * the request, the FIRST_FAMILY medal and the `FAMILY_JOIN_ACCEPTED` notification are one
   * transaction.
   */
  async accept(callerId: string, familyId: string, requestId: string): Promise<FamilyMemberDto> {
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      const role = await this.roleIn(tx, family.id, callerId);
      if (role !== 'LEADER' && role !== 'DEPUTY') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const request = await this.lockRequest(tx, family.id, requestId);
      if (request.status !== 'PENDING') return { userId: null, error: ErrorCode.FAMILY_REQUEST_NOT_PENDING };
      if (request.expires_at <= now) {
        await tx.familyJoinRequest.update({
          where: { id: request.id },
          data: { status: 'EXPIRED', handledAt: now },
        });
        return { userId: null, error: ErrorCode.FAMILY_REQUEST_NOT_PENDING };
      }
      const active = await this.users.lockActiveById(tx, request.user_id);
      if (!active || (await tx.familyMember.count({ where: { userId: request.user_id } })) > 0) {
        await tx.familyJoinRequest.update({
          where: { id: request.id },
          data: { status: 'CANCELLED', handledAt: now, handledById: callerId },
        });
        return {
          userId: null,
          error: active ? ErrorCode.ALREADY_IN_FAMILY : ErrorCode.FAMILY_REQUEST_NOT_PENDING,
        };
      }
      if (family.member_count >= FAMILY_CAPACITY) throw new AppException(ErrorCode.FAMILY_FULL);
      await tx.familyMember.create({ data: { userId: request.user_id, familyId: family.id, joinedAt: now } });
      await tx.family.update({ where: { id: family.id }, data: { memberCount: { increment: 1 } } });
      await tx.familyJoinRequest.update({
        where: { id: request.id },
        data: { status: 'ACCEPTED', handledAt: now, handledById: callerId },
      });
      await awardMedalsIn(tx, request.user_id, ['FIRST_FAMILY'], { at: now });
      await this.notifier.notify(tx, {
        type: 'FAMILY_JOIN_ACCEPTED',
        recipientId: request.user_id,
        actorId: callerId,
        familyId: family.id,
      });
      return { userId: request.user_id, error: null };
    });
    if (outcome.error !== null) throw new AppException(outcome.error);
    return this.memberDto(outcome.userId);
  }

  /** `POST /families/{familyId}/join-requests/{requestId}/decline` (leader or deputy) → 204. */
  async decline(callerId: string, familyId: string, requestId: string): Promise<void> {
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx) => {
      const family = await this.lockFamily(tx, familyId);
      const role = await this.roleIn(tx, family.id, callerId);
      if (role !== 'LEADER' && role !== 'DEPUTY') throw new AppException(ErrorCode.AUTH_FORBIDDEN);
      const request = await this.lockRequest(tx, family.id, requestId);
      if (request.status !== 'PENDING') return 'not_pending';
      if (request.expires_at <= now) {
        await tx.familyJoinRequest.update({
          where: { id: request.id },
          data: { status: 'EXPIRED', handledAt: now },
        });
        return 'not_pending';
      }
      await tx.familyJoinRequest.update({
        where: { id: request.id },
        data: { status: 'DECLINED', handledAt: now, handledById: callerId },
      });
      await this.notifier.notify(tx, {
        type: 'FAMILY_JOIN_DECLINED',
        recipientId: request.user_id,
        actorId: callerId,
        familyId: family.id,
      });
      return 'ok';
    });
    if (outcome === 'not_pending') throw new AppException(ErrorCode.FAMILY_REQUEST_NOT_PENDING);
  }

  // ---------------------------------------------------------------------------------------------
  // Expiry

  /** Marks join requests older than 7 days EXPIRED (bounded batches). Returns how many. */
  async sweepExpired(now: Date = this.clock.now()): Promise<number> {
    let total = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        UPDATE family_join_requests SET status = 'EXPIRED', handled_at = ${now.toISOString()}::timestamptz
         WHERE id IN (SELECT id FROM family_join_requests
                       WHERE status = 'PENDING' AND expires_at <= ${now.toISOString()}::timestamptz
                       LIMIT ${SWEEP_BATCH})`;
      total += n;
      if (n < SWEEP_BATCH) return total;
    }
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweepExpired()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Family request sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.social.bondsSweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
