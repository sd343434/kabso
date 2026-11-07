import { Inject, Injectable } from '@nestjs/common';
import { uuidv7 } from '../levels/uuidv7.js';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { isUuid } from '../auth/tokens.js';
import { limitedStaffSql } from '../live/live-staff.js';
import { MediaService } from '../media/media.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { Notifier } from '../notifications/notifier.js';
import { formatStaffId, parseStaffId, staffIdsAmong } from '../users/staff-ids.js';
import {
  FEEDBACK_CATEGORIES,
  FEEDBACK_DAILY_LIMIT,
  FEEDBACK_KINDS,
  FEEDBACK_MAX_IMAGES,
  FEEDBACK_STATUSES,
  FEEDBACK_TEXT_MAX,
  FEEDBACK_WINDOW_MS,
  feedbackImageKey,
  type FeedbackKind,
  type FeedbackStatus,
} from './owner-core.js';
import type { OwnerMeta } from './owner-profile.service.js';

/** A stored picture is at most this large (re-encoded WebP ≤ 1 080 px). */
const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
const PAGE_SIZE = 50;

export const createFeedbackSchema = z
  .strictObject({
    kind: z.enum(FEEDBACK_KINDS),
    text: z.string().trim().min(1).max(FEEDBACK_TEXT_MAX),
    imageUploadIds: z
      .array(z.string().refine(isUuid, { params: { issue: 'invalid_value' } }))
      .max(4)
      .optional(),
    staffUserId: z
      .string()
      .refine(isUuid, { params: { issue: 'invalid_value' } })
      .optional(),
    category: z.enum(FEEDBACK_CATEGORIES).optional(),
  })
  .superRefine((v, ctx) => {
    if ((v.imageUploadIds?.length ?? 0) > FEEDBACK_MAX_IMAGES[v.kind]) {
      ctx.addIssue({ code: 'custom', path: ['imageUploadIds'], params: { issue: 'too_big' } });
    }
    if (v.kind === 'STAFF_REPORT') {
      if (v.staffUserId === undefined) {
        ctx.addIssue({ code: 'custom', path: ['staffUserId'], params: { issue: 'required' } });
      }
      if (v.category === undefined) {
        ctx.addIssue({ code: 'custom', path: ['category'], params: { issue: 'required' } });
      }
    } else {
      if (v.staffUserId !== undefined) {
        ctx.addIssue({ code: 'custom', path: ['staffUserId'], params: { issue: 'unknown_field' } });
      }
      if (v.category !== undefined) {
        ctx.addIssue({ code: 'custom', path: ['category'], params: { issue: 'unknown_field' } });
      }
    }
  });

const staffQuerySchema = z.strictObject({ q: z.string().trim().max(64).optional() });
const inboxQuerySchema = z.strictObject({
  status: z.enum(FEEDBACK_STATUSES).optional(),
  kind: z.enum(FEEDBACK_KINDS).optional(),
  cursor: z.string().max(200).optional(),
});
const statusSchema = z.strictObject({ status: z.enum(FEEDBACK_STATUSES) });

/** `OwnerFeedbackStaff`. */
export interface FeedbackStaffDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  staffId: string | null;
}

interface PersonDto {
  id: string;
  username: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  staffId: string | null;
}

/** `OwnerInboxItem`. */
export interface OwnerInboxItemDto {
  id: string;
  kind: FeedbackKind;
  status: FeedbackStatus;
  text: string;
  category: string | null;
  sender: PersonDto;
  staff: PersonDto | null;
  imageCount: number;
  createdAt: string;
  readAt: string | null;
  doneAt: string | null;
}

const ITEM_INCLUDE = {
  sender: {
    select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } },
  },
  staff: {
    select: { id: true, profile: { select: { username: true, displayName: true, avatarUrl: true } } },
  },
} satisfies Prisma.OwnerFeedbackInclude;
type ItemRow = Prisma.OwnerFeedbackGetPayload<{ include: typeof ITEM_INCLUDE }>;

function parse<T extends z.ZodType>(schema: T, body: unknown): z.output<T> {
  const parsed = schema.safeParse(body ?? {});
  if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
  return parsed.data;
}

const encodeCursor = (at: Date, id: string) => Buffer.from(`${at.toISOString()}|${id}`).toString('base64url');
function decodeCursor(raw: string | undefined): { at: Date; id: string } | null {
  if (raw === undefined) return null;
  const [iso, id] = Buffer.from(raw, 'base64url').toString('utf8').split('|');
  const at = new Date(iso ?? '');
  if (Number.isNaN(at.getTime()) || !id || !isUuid(id)) {
    throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
  }
  return { at, id };
}

/**
 * v1.95-social (D301, CONVENTIONS §10.112.5): «اقترح ميزة / أبلغ عن موظف» → «صندوق المؤسس». Anyone ACTIVE sends (3 in
 * any 24 hours); only the app owners are told and only the panel's `owner.inbox` (OWNER) reads. A staff report is
 * confidential: the reported staff member is never notified and no staff route reads it.
 */
@Injectable()
export class OwnerFeedbackService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly notifier: Notifier,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  /** `GET /owner/feedback/staff?q=`: the Kabso Team accounts a report may name (never an OWNER). */
  async staff(query: unknown): Promise<{ data: FeedbackStaffDto[] }> {
    const q = (parse(staffQuerySchema, query).q ?? '').replace(/^@/, '');
    const number = q === '' ? null : parseStaffId(q);
    const like = `${q.toLowerCase().replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const contains = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const rows = await this.prisma.$queryRaw<
      {
        id: string;
        username: string;
        display_name: string;
        avatar_url: string | null;
        number: number | null;
      }[]
    >`
      SELECT u.id::text AS id, p.username, p.display_name, p.avatar_url, s.number
        FROM users u
        JOIN user_profiles p ON p.user_id = u.id
        LEFT JOIN staff_ids s ON s.user_id = u.id
       WHERE ${limitedStaffSql(Prisma.sql`u.id`)}
         AND (${q} = '' OR p.username LIKE ${like} OR p.display_name ILIKE ${contains}
              OR (${number}::int IS NOT NULL AND s.number = ${number}::int))
       ORDER BY s.number NULLS LAST, p.username
       LIMIT 20`;
    return {
      data: rows.map((r) => ({
        id: r.id,
        username: r.username,
        displayName: r.display_name,
        avatarUrl: r.avatar_url,
        staffId: r.number === null ? null : formatStaffId(r.number),
      })),
    };
  }

  /** 429 `RATE_LIMITED` (with Retry-After) when `senderId` already sent 3 in the last 24 hours. */
  private async assertUnderLimit(db: Prisma.TransactionClient | PrismaService, senderId: string, now: Date) {
    const recent = await db.ownerFeedback.findMany({
      where: { senderId, createdAt: { gt: new Date(now.getTime() - FEEDBACK_WINDOW_MS) } },
      orderBy: { createdAt: 'asc' },
      select: { createdAt: true },
    });
    if (recent.length < FEEDBACK_DAILY_LIMIT) return;
    const freeAt = recent[recent.length - FEEDBACK_DAILY_LIMIT]!.createdAt.getTime() + FEEDBACK_WINDOW_MS;
    throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
      'Retry-After': String(Math.max(1, Math.ceil((freeAt - now.getTime()) / 1000))),
    });
  }

  /** `POST /owner/feedback`. */
  async create(
    senderId: string,
    body: unknown,
    meta: OwnerMeta,
  ): Promise<{ id: string; kind: FeedbackKind; createdAt: string }> {
    const input = parse(createFeedbackSchema, body);
    const active = await this.prisma.user.count({ where: { id: senderId, status: 'ACTIVE' } });
    if (active === 0) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const now = this.clock.now();
    await this.assertUnderLimit(this.prisma, senderId, now);
    let staffUserId: string | null = null;
    if (input.kind === 'STAFF_REPORT') {
      staffUserId = input.staffUserId!.toLowerCase();
      const [row] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
        SELECT ${limitedStaffSql(staffUserId)} AS ok`;
      if (row?.ok !== true) throw AppException.validation([{ field: 'staffUserId', issue: 'invalid_value' }]);
    }
    const id = uuidv7();
    const uploads = [...new Set((input.imageUploadIds ?? []).map((u) => u.toLowerCase()))];
    const keys: string[] = [];
    for (const [index, uploadId] of uploads.entries()) {
      const key = feedbackImageKey(id, index);
      if (!(await this.media.consumePrivateImage(senderId, uploadId, 'OWNER_FEEDBACK_IMAGE', key))) {
        await this.media.deletePrivateObjects(keys).catch(() => undefined);
        throw AppException.validation([{ field: 'imageUploadIds', issue: 'invalid_value' }]);
      }
      keys.push(key);
    }
    try {
      const created = await this.prisma.$transaction(async (tx) => {
        // Serializes one sender's submissions, so a burst cannot pass the limit together.
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:owner-feedback'), hashtext(${senderId}::text))`;
        await this.assertUnderLimit(tx, senderId, now);
        const row = await tx.ownerFeedback.create({
          data: {
            id,
            senderId,
            kind: input.kind,
            text: input.text,
            staffUserId,
            category: input.kind === 'STAFF_REPORT' ? input.category! : null,
            imageKeys: keys,
            createdAt: now,
            updatedAt: now,
          },
        });
        await this.notifier.ownerFeedback(tx, row.id);
        await this.audit.recordIn(tx, {
          action: AuditAction.OWNER_FEEDBACK_CREATE,
          actorUserId: senderId,
          targetType: 'owner_feedback',
          targetId: row.id,
          // Never the text; never who the report is about (the panel shows it to the owner).
          metadata: { kind: input.kind, images: keys.length },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        return row;
      });
      return { id: created.id, kind: input.kind, createdAt: created.createdAt.toISOString() };
    } catch (err) {
      await this.media.deletePrivateObjects(keys).catch(() => undefined);
      throw err;
    }
  }

  // ---- the panel «صندوق المؤسس» (owner.inbox) -----------------------------------------------------------------------

  private async toItems(rows: ItemRow[]): Promise<OwnerInboxItemDto[]> {
    const staffIds = await staffIdsAmong(
      this.prisma,
      rows.flatMap((r) => (r.staff ? [r.staff.id] : [])),
    );
    const person = (u: ItemRow['sender'] | null, staffId: string | null): PersonDto | null =>
      u
        ? {
            id: u.id,
            username: u.profile?.username ?? null,
            displayName: u.profile?.displayName ?? null,
            avatarUrl: u.profile?.avatarUrl ?? null,
            staffId,
          }
        : null;
    return rows.map((r) => ({
      id: r.id,
      kind: r.kind === 'STAFF_REPORT' ? 'STAFF_REPORT' : 'FEATURE',
      status: (FEEDBACK_STATUSES as readonly string[]).includes(r.status)
        ? (r.status as FeedbackStatus)
        : 'NEW',
      text: r.text,
      category: r.category,
      sender: person(r.sender, null)!,
      staff: person(r.staff, r.staff ? (staffIds.get(r.staff.id) ?? null) : null),
      imageCount: r.imageKeys.length,
      createdAt: r.createdAt.toISOString(),
      readAt: r.readAt?.toISOString() ?? null,
      doneAt: r.doneAt?.toISOString() ?? null,
    }));
  }

  async list(query: unknown) {
    const q = parse(inboxQuerySchema, query);
    const after = decodeCursor(q.cursor);
    const where: Prisma.OwnerFeedbackWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(q.kind ? { kind: q.kind } : {}),
      ...(after
        ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
        : {}),
    };
    const [rows, grouped] = await Promise.all([
      this.prisma.ownerFeedback.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: PAGE_SIZE + 1,
        include: ITEM_INCLUDE,
      }),
      this.prisma.ownerFeedback.groupBy({ by: ['status'], _count: { _all: true } }),
    ]);
    const page = rows.slice(0, PAGE_SIZE);
    const last = page[page.length - 1];
    const counts = { NEW: 0, READ: 0, DONE: 0 };
    for (const g of grouped) {
      if (g.status === 'NEW' || g.status === 'READ' || g.status === 'DONE') counts[g.status] = g._count._all;
    }
    return {
      data: await this.toItems(page),
      counts,
      nextCursor: rows.length > PAGE_SIZE && last ? encodeCursor(last.createdAt, last.id) : null,
    };
  }

  private async rowOf(id: string): Promise<ItemRow> {
    if (!isUuid(id)) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.prisma.ownerFeedback.findUnique({
      where: { id: id.toLowerCase() },
      include: ITEM_INCLUDE,
    });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** One item; a NEW item becomes READ. Audited `admin.owner_inbox.view`. */
  async detail(admin: AdminContext, id: string): Promise<OwnerInboxItemDto> {
    const row = await this.rowOf(id);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      if (row.status === 'NEW') {
        await tx.ownerFeedback.updateMany({
          where: { id: row.id, status: 'NEW' },
          data: { status: 'READ', readAt: now, updatedAt: now },
        });
      }
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_OWNER_INBOX_VIEW,
        actorUserId: admin.userId,
        targetType: 'owner_feedback',
        targetId: row.id,
        metadata: { via: admin.via ?? 'panel' },
        ip: admin.ip,
        requestId: admin.requestId,
      });
    });
    return (await this.toItems([await this.rowOf(row.id)]))[0]!;
  }

  async setStatus(admin: AdminContext, id: string, body: unknown): Promise<OwnerInboxItemDto> {
    const { status } = parse(statusSchema, body);
    const row = await this.rowOf(id);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.ownerFeedback.update({
        where: { id: row.id },
        data: {
          status,
          updatedAt: now,
          ...(status === 'NEW' ? { readAt: null, doneAt: null } : {}),
          ...(status === 'READ' ? { readAt: row.readAt ?? now, doneAt: null } : {}),
          ...(status === 'DONE' ? { readAt: row.readAt ?? now, doneAt: now } : {}),
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_OWNER_INBOX_STATUS,
        actorUserId: admin.userId,
        targetType: 'owner_feedback',
        targetId: row.id,
        metadata: { from: row.status, to: status, via: admin.via ?? 'panel' },
        ip: admin.ip,
        requestId: admin.requestId,
      });
    });
    return (await this.toItems([await this.rowOf(row.id)]))[0]!;
  }

  /**
   * Owner (PP-58): items and their pictures are kept until the owner deletes them — `DELETE /admin/owner-inbox/{id}`
   * removes the row (its notifications with it) and the private pictures from storage. Audited
   * `admin.owner_inbox.delete` (the kind and the picture count, never the text).
   */
  async remove(admin: AdminContext, id: string): Promise<void> {
    const row = await this.rowOf(id);
    await this.prisma.$transaction(async (tx) => {
      await tx.ownerFeedback.delete({ where: { id: row.id } });
      await this.audit.recordIn(tx, {
        action: AuditAction.ADMIN_OWNER_INBOX_DELETE,
        actorUserId: admin.userId,
        targetType: 'owner_feedback',
        targetId: row.id,
        metadata: { kind: row.kind, images: row.imageKeys.length, via: admin.via ?? 'panel' },
        ip: admin.ip,
        requestId: admin.requestId,
      });
    });
    await this.media.deletePrivateObjects(row.imageKeys);
  }

  /** A picture of an item (private; `index` 0-based). */
  async image(id: string, rawIndex: string): Promise<Buffer> {
    const row = await this.rowOf(id);
    const index = /^[0-3]$/.test(rawIndex) ? Number(rawIndex) : -1;
    const key = row.imageKeys[index];
    if (index < 0 || !key) throw new AppException(ErrorCode.NOT_FOUND);
    const bytes = await this.storage.get(key, MAX_IMAGE_BYTES);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return bytes;
  }
}
