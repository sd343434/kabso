import { Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isUuid } from '../auth/tokens.js';
import type { PostDto } from '../posts/post-views.js';
import { PostViews } from '../posts/post-views.js';
import { PostsService } from '../posts/posts.service.js';
import {
  ANNOUNCEMENT_FANOUT_BATCH,
  ANNOUNCEMENT_FANOUT_INTERVAL_MS,
  assertKabsoOwner,
  queueAnnouncementIn,
} from './owner-core.js';
import type { OwnerMeta } from './owner-profile.service.js';

const caption = z.string().trim().min(1).max(2200);
export const createAnnouncementSchema = z.strictObject({
  textAr: caption,
  textEn: caption,
  mediaIds: z.array(z.uuid()).max(10).optional(),
});
export const updateAnnouncementSchema = z
  .strictObject({ textAr: caption.optional(), textEn: caption.optional() })
  .refine((v) => v.textAr !== undefined || v.textEn !== undefined, { params: { issue: 'required' } });

function parse<T extends z.ZodType>(schema: T, body: unknown): z.output<T> {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

/**
 * v1.95-social (D301 follow-up, owner 2026-11-07: «اعلان التي يقوم المؤسس نشرها تكون دائماً في اول منشور ويتم نشرها
 * بلغتين … ويصل اشعار لكل المستخدمين لها حتى المشرفين»; CONVENTIONS §10.112.7): the owner's bilingual official
 * announcement — composed in Arabic and English (the same pictures), published as an official post; the posts feed shows
 * the latest one first; every ACTIVE account (staff too) is told once, by a batched fan-out after the request.
 */
@Injectable()
export class OwnerAnnouncementsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OwnerAnnouncementsService.name);
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly views: PostViews,
    private readonly audit: AuditService,
    private readonly background: BackgroundTasks,
  ) {}

  onModuleInit(): void {
    this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.drain()
        .catch((err: unknown) =>
          this.logger.error({ error: safeErrorLog(err) }, 'Announcement fan-out failed'),
        )
        .finally(() => {
          this.inFlight = null;
          if (this.timer) this.schedule();
        });
    }, ANNOUNCEMENT_FANOUT_INTERVAL_MS);
    this.timer.unref();
  }

  /** Steps every queued fan-out until none is left (bounded steps per call). */
  async drain(maxSteps = 200): Promise<number> {
    let written = 0;
    for (let i = 0; i < maxSteps; i++) {
      const step = await this.fanOutOnce();
      if (step === null) break;
      written += step;
    }
    return written;
  }

  /**
   * One fan-out step: the oldest queued announcement (its row locked `SKIP LOCKED`, so several API instances share the
   * work), the next {@link ANNOUNCEMENT_FANOUT_BATCH} ACTIVE accounts after its cursor (by id; never the owner who
   * published it), one OWNER_ANNOUNCEMENT row each (`ON CONFLICT DO NOTHING`: a retried step writes nothing twice), the
   * cursor moved; done when a step finds fewer accounts. Returns the rows written, or null when nothing is queued.
   */
  async fanOutOnce(batch = ANNOUNCEMENT_FANOUT_BATCH): Promise<number | null> {
    return this.prisma.$transaction(async (tx) => {
      const [job] = await tx.$queryRaw<{ post_id: string; cursor: string | null; author_id: string }[]>`
        SELECT f.post_id::text AS post_id, f.cursor_user_id::text AS cursor, p.author_id::text AS author_id
          FROM owner_announcement_fanouts f JOIN posts p ON p.id = f.post_id
         WHERE f.done_at IS NULL
         ORDER BY f.started_at
         LIMIT 1
         FOR UPDATE OF f SKIP LOCKED`;
      if (!job) return null;
      const ids = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM users
         WHERE status = 'ACTIVE'::user_status AND id <> ${job.author_id}::uuid
           AND (${job.cursor}::uuid IS NULL OR id > ${job.cursor}::uuid)
         ORDER BY id
         LIMIT ${batch}`;
      let written = 0;
      if (ids.length > 0) {
        written = await tx.$executeRaw`
          INSERT INTO notifications (id, recipient_id, type, post_id, created_at, updated_at)
          SELECT gen_random_uuid(), u.id, 'OWNER_ANNOUNCEMENT'::notification_type, ${job.post_id}::uuid, now(), now()
            FROM unnest(${ids.map((r) => r.id)}::uuid[]) AS u(id)
          ON CONFLICT (recipient_id, post_id) WHERE type = 'OWNER_ANNOUNCEMENT'::notification_type DO NOTHING`;
      }
      const done = ids.length < batch;
      await tx.ownerAnnouncementFanout.update({
        where: { postId: job.post_id },
        data: {
          ...(ids.length > 0 ? { cursorUserId: ids[ids.length - 1]!.id } : {}),
          recipients: { increment: written },
          ...(done ? { doneAt: new Date() } : {}),
        },
      });
      if (done) {
        const row = await tx.ownerAnnouncementFanout.findUniqueOrThrow({ where: { postId: job.post_id } });
        await this.audit.recordIn(tx, {
          action: AuditAction.OWNER_ANNOUNCEMENT_FANOUT_DONE,
          actorUserId: null,
          targetType: 'post',
          targetId: job.post_id,
          metadata: { recipients: row.recipients },
        });
      }
      return written;
    });
  }

  /** Starts the fan-out right after the response (the sweeper also picks it up). */
  private kick(): void {
    this.background.run('owner-announcement', async () => {
      await this.drain();
    });
  }

  /**
   * `POST /owner/announcements` (owner): the Arabic and the English caption (both required) and the optional pictures
   * of `POST /posts`; published at once as an official post (`text` the Arabic caption, `text_en` the English one).
   */
  async create(ownerId: string, idempotencyKey: string, body: unknown, meta: OwnerMeta): Promise<PostDto> {
    await assertKabsoOwner(this.prisma, ownerId);
    const input = parse(createAnnouncementSchema, body);
    const created = await this.posts.create(ownerId, idempotencyKey, {
      text: input.textAr,
      ...(input.mediaIds?.length ? { mediaIds: input.mediaIds } : {}),
    });
    await this.prisma.$transaction(async (tx) => {
      const [row] = await tx.$queryRaw<{ official: boolean }[]>`
        SELECT official_at IS NOT NULL AS official FROM posts WHERE id = ${created.id}::uuid FOR UPDATE`;
      await tx.post.update({
        where: { id: created.id },
        data: { textEn: input.textEn, ...(row?.official ? {} : { officialAt: new Date() }) },
      });
      await queueAnnouncementIn(tx, created.id, ownerId, meta);
    });
    this.kick();
    return this.views.one(ownerId, created.id);
  }

  /** `PATCH /owner/announcements/{postId}` (owner, his own official post): either caption; never notifies again. */
  async update(ownerId: string, postId: string, body: unknown, meta: OwnerMeta): Promise<PostDto> {
    await assertKabsoOwner(this.prisma, ownerId);
    const input = parse(updateAnnouncementSchema, body);
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = postId.toLowerCase();
    const post = await this.prisma.post.findFirst({
      where: { id, authorId: ownerId, officialAt: { not: null }, deletedAt: null },
      select: { id: true },
    });
    if (!post) throw new AppException(ErrorCode.NOT_FOUND);
    if (input.textAr !== undefined) await this.posts.update(ownerId, id, { text: input.textAr });
    await this.prisma.$transaction(async (tx) => {
      if (input.textEn !== undefined) await tx.post.update({ where: { id }, data: { textEn: input.textEn } });
      await this.audit.recordIn(tx, {
        action: AuditAction.OWNER_ANNOUNCEMENT_UPDATE,
        actorUserId: ownerId,
        targetType: 'post',
        targetId: id,
        metadata: { fields: Object.keys(input) },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    });
    return this.views.one(ownerId, id);
  }
}
