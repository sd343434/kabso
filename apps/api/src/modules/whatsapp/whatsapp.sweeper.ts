import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';

const BATCH = 100;

/**
 * v1.116-social (D355, CONVENTIONS §10.151.8): privacy — a conversation with no message for `WHATSAPP_RETENTION_DAYS`
 * (180) is deleted with its messages, notes, assignment history and media files; so is every conversation whose
 * linked Kabso account was purged (`purge_after`, set by the account purge). Runs every
 * `WHATSAPP_SWEEP_INTERVAL_SECONDS` (also when WhatsApp is off: the stored data still ages out). Audited
 * `whatsapp.retention.purge` with the counts only.
 */
@Injectable()
export class WhatsAppSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('WhatsApp');
  private timer: NodeJS.Timeout | undefined;
  private running: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  onModuleInit(): void {
    const every = this.config.whatsapp.sweepIntervalSeconds;
    if (every <= 0) return;
    this.timer = setInterval(() => {
      if (this.running) return;
      this.running = this.purgeOnce()
        .catch((err: unknown) => this.logger.error({ error: safeErrorLog(err) }, 'WhatsApp retention failed'))
        .finally(() => {
          this.running = null;
        });
    }, every * 1000);
    this.timer.unref();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearInterval(this.timer);
    await this.running?.catch(() => undefined);
  }

  /** One pass; returns the conversations deleted. */
  async purgeOnce(): Promise<{ conversations: number; messages: number; media: number }> {
    const now = this.clock.now();
    const before = new Date(now.getTime() - this.config.whatsapp.retentionDays * 86_400_000);
    const total = { conversations: 0, messages: 0, media: 0 };
    for (;;) {
      const due = await this.prisma.waConversation.findMany({
        where: { OR: [{ lastMessageAt: { lt: before } }, { purgeAfter: { lte: now } }] },
        select: { id: true },
        take: BATCH,
      });
      if (due.length === 0) break;
      const ids = due.map((d) => d.id);
      const media = await this.prisma.waMessage.findMany({
        where: { conversationId: { in: ids }, mediaKey: { not: null } },
        select: { mediaKey: true },
      });
      const keys = media.map((m) => m.mediaKey!).filter((k) => k.startsWith('private/whatsapp/'));
      // v1.137-social (D385, §10.174.7): an in-app thread's pictures and voice clips (the person's uploads).
      const assets = (
        await this.prisma.waMessage.findMany({
          where: { conversationId: { in: ids }, mediaAssetId: { not: null } },
          select: { mediaAsset: { select: { id: true, largeKey: true, thumbKey: true } } },
        })
      )
        .map((m) => m.mediaAsset)
        .filter((a): a is { id: string; largeKey: string; thumbKey: string } => a !== null);
      const assetKeys = [...new Set(assets.flatMap((a) => [a.largeKey, a.thumbKey]))];
      // Files first: a row without its file is harmless, a file without its row would never be found again.
      if (keys.length > 0) await this.storage.delete(keys);
      if (assetKeys.length > 0) await this.storage.delete(assetKeys);
      const messages = await this.prisma.waMessage.count({ where: { conversationId: { in: ids } } });
      await this.prisma.waConversation.deleteMany({ where: { id: { in: ids } } });
      if (assets.length > 0)
        await this.prisma.mediaAsset.deleteMany({ where: { id: { in: assets.map((a) => a.id) } } });
      total.conversations += ids.length;
      total.messages += messages;
      total.media += keys.length + assets.length;
      if (due.length < BATCH) break;
    }
    if (total.conversations > 0) {
      await this.audit.record({
        action: AuditAction.WHATSAPP_PURGE,
        actorUserId: null,
        targetType: 'whatsapp',
        metadata: { ...total, retentionDays: this.config.whatsapp.retentionDays },
      });
    }
    return total;
  }
}
