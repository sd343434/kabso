import { Inject, Injectable, Logger } from '@nestjs/common';
import { Clock } from '../../common/time/clock.js';
import type { LevelEventStatus, LevelSourceEvent, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isAvailable, loadCategory, type LoadedCategory } from './level-catalog.js';
import { LevelProgressService } from './level-progress.service.js';
import { qualify, type LevelSourceEventInput } from './level-qualification.js';
import { SOURCE_TYPES_BY_EVENT } from './levels.constants.js';
import { pointsFor } from './points-math.js';
import { LEVEL_SOURCE_VERIFIER, type SourceTransactionVerifier } from './source-verifier.js';
import { uuidv7 } from './uuidv7.js';

const MAX_ERROR = 300;
const ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** JSON form stored in `level_source_events.payload` (bigints as strings). */
type StoredPayload = Record<string, string | boolean>;

function toPayload(event: LevelSourceEventInput): StoredPayload {
  switch (event.type) {
    case 'GIFT_COMMITTED':
      return {
        senderUserId: event.senderUserId,
        recipientUserId: event.recipientUserId,
        value: event.value.toString(),
        lucky: event.lucky,
      };
    case 'GAME_SPEND_COMMITTED':
      return { userId: event.userId, value: event.value.toString() };
    default:
      return {};
  }
}

function fromRow(row: LevelSourceEvent): LevelSourceEventInput {
  const p = row.payload as StoredPayload;
  switch (row.type) {
    case 'GIFT_COMMITTED':
      return {
        type: 'GIFT_COMMITTED',
        sourceTransactionId: row.sourceTransactionId,
        senderUserId: String(p.senderUserId),
        recipientUserId: String(p.recipientUserId),
        value: BigInt(String(p.value)),
        lucky: p.lucky === true,
      };
    case 'GAME_SPEND_COMMITTED':
      return {
        type: 'GAME_SPEND_COMMITTED',
        sourceTransactionId: row.sourceTransactionId,
        userId: String(p.userId),
        value: BigInt(String(p.value)),
      };
    default:
      return { type: row.type, sourceTransactionId: row.sourceTransactionId };
  }
}

/** Shape check of a producer event (server-side input, but never trusted blindly). */
export function eventShapeProblem(event: LevelSourceEventInput): string | null {
  if (!ID_PATTERN.test(event.sourceTransactionId)) return 'invalid_source_transaction_id';
  if (event.type === 'GIFT_COMMITTED') {
    if (!UUID.test(event.senderUserId) || !UUID.test(event.recipientUserId)) return 'invalid_user_id';
    if (event.value < 0n) return 'negative_value';
  }
  if (event.type === 'GAME_SPEND_COMMITTED') {
    if (!UUID.test(event.userId)) return 'invalid_user_id';
    if (event.value < 0n) return 'negative_value';
  }
  return null;
}

export interface IngestResult {
  readonly event: LevelSourceEvent;
  /** True when this call found the event already processed (duplicate delivery). */
  readonly duplicate: boolean;
}

/**
 * Inbox for producer events (CP-005 §6; the brief's ActivityQualificationService). The future
 * gifts and games modules call `ingest` after committing their own transaction. There is no HTTP
 * endpoint for it: clients can never submit events, points or levels.
 */
@Injectable()
export class LevelEventsService {
  private readonly logger = new Logger(LevelEventsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly progress: LevelProgressService,
    private readonly clock: Clock,
    @Inject(LEVEL_SOURCE_VERIFIER) private readonly verifier: SourceTransactionVerifier,
  ) {}

  async ingest(event: LevelSourceEventInput): Promise<IngestResult> {
    const problem = eventShapeProblem(event);
    if (problem) throw new RangeError(`invalid level event: ${problem}`);
    const payload = toPayload(event);
    await this.prisma.$executeRaw`
      INSERT INTO level_source_events (id, type, source_transaction_id, payload)
      VALUES (${uuidv7()}::uuid, ${event.type}::level_source_event_type, ${event.sourceTransactionId},
              ${JSON.stringify(payload)}::jsonb)
      ON CONFLICT (type, source_transaction_id) DO NOTHING`;
    const row = await this.prisma.levelSourceEvent.findUniqueOrThrow({
      where: {
        type_sourceTransactionId: { type: event.type, sourceTransactionId: event.sourceTransactionId },
      },
    });
    if (JSON.stringify(row.payload) !== JSON.stringify(payload)) {
      // Same transaction reported twice with different data: keep the first, flag it.
      this.logger.warn(
        { eventId: row.id, type: row.type },
        'Level event redelivered with a different payload',
      );
    }
    if (row.status === 'PROCESSED' || row.status === 'SKIPPED') return { event: row, duplicate: true };
    return { event: await this.process(row.id), duplicate: false };
  }

  /** Processes (or re-processes) one event. Safe to repeat: the ledger dedupes. */
  async process(eventId: string): Promise<LevelSourceEvent> {
    const row = await this.prisma.levelSourceEvent.findUniqueOrThrow({ where: { id: eventId } });
    if (row.status === 'PROCESSED' || row.status === 'SKIPPED') return row;
    const event = fromRow(row);

    const verification = await this.verifier.verify(event);
    if (!verification.ok) return this.finish(row.id, 'FAILED', `source_unverified:${verification.reason}`);

    try {
      const outcome = await this.prisma.$transaction(async (tx) =>
        event.type === 'GIFT_COMMITTED' || event.type === 'GAME_SPEND_COMMITTED'
          ? this.applyActivity(tx, event)
          : this.applyReversal(tx, event),
      );
      return await this.finish(row.id, outcome.status, outcome.note);
    } catch (err) {
      this.logger.error({ eventId: row.id, error: safeErrorLog(err) }, 'Level event failed');
      const message = err instanceof Error ? err.message : 'error';
      return this.finish(row.id, 'FAILED', `error:${message}`);
    }
  }

  /**
   * Records the outcome. Conditional on the row not being final yet, so a second worker that
   * raced on the same event (and found only duplicates) cannot overwrite PROCESSED with SKIPPED.
   */
  private async finish(id: string, status: LevelEventStatus, note: string | null): Promise<LevelSourceEvent> {
    await this.prisma.levelSourceEvent.updateMany({
      where: { id, status: { in: ['PENDING', 'FAILED'] } },
      data: {
        status,
        attempts: { increment: 1 },
        lastError: note?.slice(0, MAX_ERROR) ?? null,
        processedAt: status === 'FAILED' ? null : this.clock.now(),
      },
    });
    return this.prisma.levelSourceEvent.findUniqueOrThrow({ where: { id } });
  }

  private async applyActivity(
    tx: Prisma.TransactionClient,
    event: Extract<LevelSourceEventInput, { type: 'GIFT_COMMITTED' | 'GAME_SPEND_COMMITTED' }>,
  ): Promise<{ status: LevelEventStatus; note: string | null }> {
    const support = event.type === 'GIFT_COMMITTED' ? await loadCategory(tx, 'SUPPORT', 'share') : null;
    const credits = qualify(event, {
      luckyGiftsCountAsSupport:
        support !== null && isAvailable(support) && support.version.luckyGiftsCountAsSupport,
    });
    if (typeof credits === 'string') return { status: 'SKIPPED', note: `skipped:${credits}` };

    // Lock in a fixed order (user, category) so two events never deadlock on each other's rows.
    const ordered = [...credits].sort((a, b) =>
      a.userId === b.userId ? a.category.localeCompare(b.category) : a.userId.localeCompare(b.userId),
    );
    const skipped: string[] = [];
    let applied = 0;
    const loaded = new Map<string, LoadedCategory>();
    for (const credit of ordered) {
      const category = loaded.get(credit.category) ?? (await loadCategory(tx, credit.category, 'share'));
      loaded.set(credit.category, category);
      if (!isAvailable(category)) {
        skipped.push(`${credit.category}:unavailable`);
        continue;
      }
      const points = pointsFor(credit.value, category.version.multiplier);
      if (points === 0n) {
        skipped.push(`${credit.category}:rounds_to_zero`);
        continue;
      }
      const result = await this.progress.apply(tx, category, {
        userId: credit.userId,
        entryType: 'EARN',
        sourceType: credit.sourceType,
        pointsDelta: points,
        sourceTransactionId: event.sourceTransactionId,
        sourceValue: credit.value,
        multiplierUsed: category.version.multiplier,
      });
      if (result.kind === 'applied') applied++;
      else skipped.push(`${credit.category}:${result.kind}`);
    }
    const note = skipped.length ? `skipped:${skipped.join(',')}` : null;
    return { status: applied > 0 ? 'PROCESSED' : 'SKIPPED', note };
  }

  private async applyReversal(
    tx: Prisma.TransactionClient,
    event: Extract<LevelSourceEventInput, { type: 'GIFT_REVERSED' | 'GAME_SPEND_REVERSED' }>,
  ): Promise<{ status: LevelEventStatus; note: string | null }> {
    const earns = await tx.pointsLedgerEntry.findMany({
      where: {
        sourceTransactionId: event.sourceTransactionId,
        entryType: 'EARN',
        sourceType: { in: [...SOURCE_TYPES_BY_EVENT[event.type]] },
      },
      include: { category: { select: { code: true } }, reversedBy: { select: { id: true } } },
      orderBy: [{ userId: 'asc' }, { categoryId: 'asc' }],
    });
    if (earns.length === 0) {
      // The commit may not have been processed yet (out of order): retryable.
      throw new Error('original_not_found');
    }
    let applied = 0;
    const notes: string[] = [];
    for (const earn of earns) {
      if (earn.reversedBy) {
        notes.push(`${earn.category.code}:already_reversed`);
        continue;
      }
      // Reversals apply even to a disabled category: the ledger must stay true.
      const category = await loadCategory(tx, earn.category.code, 'share');
      const result = await this.progress.apply(tx, category, {
        userId: earn.userId,
        entryType: 'REVERSAL',
        sourceType: earn.sourceType,
        pointsDelta: -earn.pointsDelta,
        sourceTransactionId: earn.sourceTransactionId,
        sourceValue: earn.sourceValue,
        reversalOfEntryId: earn.id,
      });
      if (result.kind === 'applied') applied++;
      else notes.push(`${earn.category.code}:${result.kind}`);
    }
    return {
      status: applied > 0 ? 'PROCESSED' : 'SKIPPED',
      note: notes.length ? `skipped:${notes.join(',')}` : null,
    };
  }
}
