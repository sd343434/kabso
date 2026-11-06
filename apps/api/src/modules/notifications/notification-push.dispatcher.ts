import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PushService } from '../push/push.service.js';
import { notificationBody, PUSH_TITLE } from '../push/push-texts.js';
import { PushThrottle } from '../push/push-throttle.js';
import { NotificationsService, type NotificationDto } from './notifications.service.js';

/** Activity older than this is never pushed (a backlog after downtime stays in the inbox). */
export const PUSH_MAX_AGE_MS = 10 * 60_000;
/** One notification row (a growing like group) is pushed at most once per this many seconds. */
export const PUSH_PER_NOTIFICATION_SECONDS = 60;
/** Rows claimed per round. */
const BATCH = 200;
/** Without a Firebase key the outbox is still drained (so it stays small), but rarely. */
const DISABLED_INTERVAL_MS = 60_000;

interface Claimed {
  id: string;
  recipient_id: string;
  updated_at: Date;
  read_at: Date | null;
}

/** The FCM data of a general push (strings only; absent when null). */
export function notificationPushData(dto: NotificationDto): Record<string, string> {
  const data: Record<string, string> = {
    kind: 'notification',
    channel: 'general',
    notificationId: dto.id,
    type: dto.type,
  };
  if (dto.target) {
    data.targetType = dto.target.type;
    data.targetId = dto.target.id;
    if (dto.target.postId !== null) data.targetPostId = dto.target.postId;
    // v1.69-social (D204): what happened on the recharge order (the push's wording and the app's route).
    if (dto.target.orderEvent !== undefined) data.orderEvent = dto.target.orderEvent;
  }
  const actor = dto.actors[0];
  if (actor) data.actorUsername = actor.username;
  return data;
}

/**
 * v1.30-live (D152, CONVENTIONS §11.12): the general push. `notifications.pushed_at` is an outbox:
 * a row is waiting while it is NULL or older than `updated_at` (created, or a new actor joined
 * the group). Every round claims waiting rows (`FOR UPDATE SKIP LOCKED`, so several API instances
 * never push one twice), marks them handled and pushes those still unread, recent and visible to
 * their recipient — so the in-app rules (blocks, mutes, settings, removed targets) decide.
 */
@Injectable()
export class NotificationPushDispatcher implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('Push');
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly push: PushService,
    private readonly throttle: PushThrottle,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly audit: AuditService,
  ) {}

  onModuleInit(): void {
    if (this.config.push.dispatchIntervalMs > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    await this.inFlight?.catch(() => undefined);
  }

  /** One round; returns how many notifications were pushed (tests call it directly). */
  async dispatchOnce(): Promise<number> {
    const claimed = await this.prisma.$queryRaw<Claimed[]>`
      WITH due AS (
        SELECT id FROM notifications
         WHERE pushed_at IS NULL OR pushed_at < updated_at
         ORDER BY updated_at
         LIMIT ${BATCH}
         FOR UPDATE SKIP LOCKED)
      UPDATE notifications n SET pushed_at = n.updated_at
        FROM due WHERE n.id = due.id
      RETURNING n.id, n.recipient_id, n.updated_at, n.read_at`;
    if (!this.push.enabled) return 0;
    const now = this.clock.now().getTime();
    let pushed = 0;
    for (const row of claimed) {
      if (row.read_at !== null || now - row.updated_at.getTime() > PUSH_MAX_AGE_MS) continue;
      try {
        if (await this.pushOne(row)) pushed += 1;
      } catch (err) {
        this.logger.error({ error: safeErrorLog(err) }, 'Notification push failed');
      }
    }
    return pushed;
  }

  private async pushOne(row: Claimed): Promise<boolean> {
    const dto = await this.notifications.visible(row.recipient_id, row.id);
    if (!dto || dto.read) return false;
    // v1.68-live (D273, §10.96.8): a report alert to a staff member on shift always goes out (never held back by the
    // general gap between pushes); off shift (the OWNERs' fallback) it follows the usual rules.
    const staffAlert = dto.type === 'LIVE_STAFF_REPORT';
    const onShift = staffAlert && (await this.onShift(row.recipient_id));
    if (!onShift && !(await this.throttle.allow(`n:${row.id}`, PUSH_PER_NOTIFICATION_SECONDS))) return false;
    if (!onShift && !(await this.throttle.allow(`g:${row.recipient_id}`, this.config.push.generalGapSeconds)))
      return false;
    const actor = dto.actors[0];
    const sent = await this.push.deliver({
      userIds: [row.recipient_id],
      channel: 'general',
      tag: `n:${dto.id}`,
      data: notificationPushData(dto),
      text: (locale) => {
        const body = notificationBody(
          {
            type: dto.type,
            actorName: actor?.displayName ?? null,
            actorCount: dto.actorCount,
            targetType: dto.target?.type ?? null,
            targetId: dto.target?.id ?? null,
            targetText: dto.target?.orderEvent ?? dto.target?.text ?? null,
            activatedHosts: dto.target?.activatedHosts ?? null,
            requiredHosts: dto.target?.requiredHosts ?? null,
            probationDays: this.config.economy.probationDays,
            moderation: dto.target?.moderation ?? null,
            medalLevel: dto.target?.medalLevel ?? null,
          },
          locale,
        );
        return body === null ? null : { title: PUSH_TITLE[locale], body };
      },
    });
    if (staffAlert) {
      await this.audit.record({
        action: AuditAction.LIVE_STAFF_REPORT_PUSH,
        actorUserId: null,
        targetType: 'live_room',
        targetId: dto.target?.id,
        metadata: { recipientId: row.recipient_id, notificationId: row.id, sent, onShift },
      });
    }
    return sent > 0;
  }

  private async onShift(userId: string): Promise<boolean> {
    const shift = await this.prisma.adminShift.findUnique({ where: { userId }, select: { onShift: true } });
    return shift?.onShift === true;
  }

  private schedule(): void {
    const every = this.push.enabled
      ? this.config.push.dispatchIntervalMs
      : Math.max(this.config.push.dispatchIntervalMs, DISABLED_INTERVAL_MS);
    this.timer = setTimeout(() => {
      this.inFlight = this.dispatchOnce()
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Push dispatch failed');
        })
        .finally(() => {
          this.inFlight = null;
          if (this.timer !== undefined) this.schedule();
        });
    }, every);
    this.timer.unref();
  }
}
