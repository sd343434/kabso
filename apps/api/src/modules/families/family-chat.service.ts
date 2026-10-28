import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { FamilyRole, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { maskBlockedWords } from '../live/live-blocked-words.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { familyChatSendSchema, type FamilyChatQuery } from './families.schemas.js';
import { FamilyChatPush } from './family-chat-push.js';

/** `FamilyChatMessage` (v1.25-live). */
export interface FamilyChatMessageDto {
  id: string;
  familyId: string;
  author: UserSummaryDto;
  /** The author's role in the family now; null when they are no longer a member. */
  authorRole: FamilyRole | null;
  /** The leader's live blocked words are masked (each character → `*`). */
  text: string;
  createdAt: string;
}

/** `FamilyChatPage` (v1.25-live): newest first, with the caller's state in this chat. */
export interface FamilyChatPageDto extends PageDto<FamilyChatMessageDto> {
  /** The caller is muted here (the composer is off). */
  muted: boolean;
  /** The caller is the leader or a deputy (may delete others' messages and mute members). */
  canModerate: boolean;
}

const INCLUDE = {
  author: { select: USER_SUMMARY_SELECT },
} as const satisfies Prisma.FamilyChatMessageInclude;
type Row = Prisma.FamilyChatMessageGetPayload<{ include: typeof INCLUDE }>;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

function forbidden(): AppException {
  return new AppException(ErrorCode.AUTH_FORBIDDEN);
}

/**
 * The family chat (مراسلة العائلة, CP-022, owner D116, CONVENTIONS §10.25): one text conversation
 * per family, members only. The open chat reads the newest page again (polling) and pages back
 * with the cursor; since v1.30-live (D152) the other members get a push ({@link FamilyChatPush}).
 * Messages follow the live chat text rules
 * (1–200 code points, one line) with the leader's live blocked words masked; the author, the
 * leader or a deputy deletes one (a deputy never deletes the leader's or another deputy's); the
 * leader and deputies mute members (a deputy never mutes a deputy; nobody mutes the leader);
 * members report messages (`POST /reports`, `FAMILY_CHAT_MESSAGE`). A reader never gets messages
 * of people they blocked or who blocked them.
 */
@Injectable()
export class FamilyChatService {
  private readonly cursors: SocialCursorCodec;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly clock: Clock,
    private readonly chatPush: FamilyChatPush,
    private readonly background: BackgroundTasks,
    @Inject(APP_CONFIG) config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  /** A family that is not disbanded (404 otherwise) and the caller's role in it (null: not a member). */
  private async access(familyId: string, callerId: string): Promise<{ id: string; role: FamilyRole | null }> {
    if (!isUuid(familyId)) throw notFound();
    const id = familyId.toLowerCase();
    const family = await this.prisma.family.findFirst({
      where: { id, disbandedAt: null },
      select: { id: true },
    });
    if (!family) throw notFound();
    const member = await this.prisma.familyMember.findUnique({
      where: { userId: callerId },
      select: { familyId: true, role: true },
    });
    return { id, role: member?.familyId === id ? member.role : null };
  }

  private async toDtos(familyId: string, rows: readonly Row[]): Promise<FamilyChatMessageDto[]> {
    const roles = await this.prisma.familyMember.findMany({
      where: { familyId, userId: { in: [...new Set(rows.map((r) => r.authorId))] } },
      select: { userId: true, role: true },
    });
    const roleOf = new Map(roles.map((r) => [r.userId, r.role]));
    return rows.map((r) => ({
      id: r.id,
      familyId: r.familyId,
      author: userSummary(r.author),
      authorRole: roleOf.get(r.authorId) ?? null,
      text: r.text,
      createdAt: r.createdAt.toISOString(),
    }));
  }

  /** `GET /families/{familyId}/chat`: newest first (404 family → 403 not a member). */
  async list(callerId: string, familyId: string, query: FamilyChatQuery): Promise<FamilyChatPageDto> {
    const family = await this.access(familyId, callerId);
    if (family.role === null) throw forbidden();
    const scope = `family-chat:${family.id}:${callerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const [rows, mute] = await Promise.all([
      this.prisma.familyChatMessage.findMany({
        where: {
          familyId: family.id,
          deletedAt: null,
          author: {
            status: 'ACTIVE',
            blocking: { none: { blockedId: callerId } },
            blockedBy: { none: { blockerId: callerId } },
          },
          ...(after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        include: INCLUDE,
      }),
      this.prisma.familyChatMute.count({ where: { familyId: family.id, userId: callerId } }),
    ]);
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    return {
      data: await this.toDtos(family.id, page),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
      muted: mute > 0,
      canModerate: family.role === 'LEADER' || family.role === 'DEPUTY',
    };
  }

  /**
   * `POST /families/{familyId}/chat`. Order after auth and the rate limit: 404 family → 400 body
   * (text rules, `clientId`) → a retry with the same `clientId` → 200 with the first message (even
   * if the text differs) → 403 `AUTH_FORBIDDEN` (not a member) → 403 `FAMILY_CHAT_MUTED`.
   */
  async send(
    callerId: string,
    familyId: string,
    body: unknown,
  ): Promise<{ created: boolean; message: FamilyChatMessageDto }> {
    const family = await this.access(familyId, callerId);
    const parsed = familyChatSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const clientId = parsed.data.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first && first.familyId === family.id) {
      return { created: false, message: (await this.toDtos(family.id, [first]))[0]! };
    }
    if (first) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    if (family.role === null) throw forbidden();
    if ((await this.prisma.familyChatMute.count({ where: { familyId: family.id, userId: callerId } })) > 0) {
      throw new AppException(ErrorCode.FAMILY_CHAT_MUTED);
    }
    const leader = await this.prisma.familyMember.findFirst({
      where: { familyId: family.id, role: 'LEADER' },
      select: { user: { select: { liveHost: { select: { blockedWords: true } } } } },
    });
    const text = maskBlockedWords(parsed.data.text, leader?.user.liveHost?.blockedWords ?? []);
    try {
      const row = await this.prisma.familyChatMessage.create({
        data: { familyId: family.id, authorId: callerId, clientId, text, createdAt: this.clock.now() },
        include: INCLUDE,
      });
      // D152 (§11.12): the push to the other members, after the response.
      this.background.run('push.familyChat', async () => {
        await this.chatPush.newMessage({ familyId: family.id, messageId: row.id, authorId: callerId, text });
      });
      return { created: true, message: (await this.toDtos(family.id, [row]))[0]! };
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null && index.includes('family_chat_messages_client_once')) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced?.familyId === family.id) {
          return { created: false, message: (await this.toDtos(family.id, [raced]))[0]! };
        }
      }
      throw err;
    }
  }

  private byClientId(authorId: string, clientId: string): Promise<Row | null> {
    return this.prisma.familyChatMessage.findUnique({
      where: { authorId_clientId: { authorId, clientId } },
      include: INCLUDE,
    });
  }

  /**
   * `DELETE /families/{familyId}/chat/{messageId}` → 204 (soft; already deleted → 204). The author
   * (a member), the leader or a deputy; a deputy never deletes the leader's or another deputy's
   * message. Order: 404 family → 403 not a member → 404 message → 403.
   */
  async remove(callerId: string, familyId: string, messageId: string): Promise<void> {
    const family = await this.access(familyId, callerId);
    if (family.role === null) throw forbidden();
    if (!isUuid(messageId)) throw notFound();
    const row = await this.prisma.familyChatMessage.findFirst({
      where: { id: messageId.toLowerCase(), familyId: family.id },
      select: { id: true, authorId: true, deletedAt: true },
    });
    if (!row) throw notFound();
    if (row.authorId !== callerId) {
      if (family.role === 'MEMBER') throw forbidden();
      if (family.role === 'DEPUTY') {
        const author = await this.prisma.familyMember.findUnique({
          where: { userId: row.authorId },
          select: { familyId: true, role: true },
        });
        if (author?.familyId === family.id && author.role !== 'MEMBER') throw forbidden();
      }
    }
    if (row.deletedAt !== null) return;
    await this.prisma.familyChatMessage.updateMany({
      where: { id: row.id, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: callerId },
    });
  }

  /**
   * `PUT` / `DELETE /families/{familyId}/chat/mutes/{username}` → 204 (idempotent). The leader or a
   * deputy; the target must be a member (404), not the caller (400 `username` / `invalid_value`),
   * not the leader, and for a deputy not another deputy (403).
   */
  async setMuted(callerId: string, familyId: string, username: string, muted: boolean): Promise<void> {
    const family = await this.access(familyId, callerId);
    if (family.role !== 'LEADER' && family.role !== 'DEPUTY') throw forbidden();
    const target = await this.users.findActivePublicUser(username);
    if (!target) throw notFound();
    const member = await this.prisma.familyMember.findUnique({
      where: { userId: target.id },
      select: { familyId: true, role: true },
    });
    if (member?.familyId !== family.id) throw notFound();
    if (target.id === callerId)
      throw AppException.validation([{ field: 'username', issue: 'invalid_value' }]);
    if (member.role === 'LEADER' || (family.role === 'DEPUTY' && member.role === 'DEPUTY')) throw forbidden();
    if (muted) {
      await this.prisma.familyChatMute.createMany({
        data: [{ familyId: family.id, userId: target.id, mutedById: callerId, createdAt: this.clock.now() }],
        skipDuplicates: true,
      });
    } else {
      await this.prisma.familyChatMute.deleteMany({ where: { familyId: family.id, userId: target.id } });
    }
  }
}
