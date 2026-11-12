import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { maskBlockedWords } from '../live/live-blocked-words.js';
import { VIP_GOLDEN_ID_CLASSES } from './vip-catalogue.js';
import {
  freeGoldenIdIn,
  goldenAuditIn,
  lockGoldenHolderIn,
  syncGoldenIdIn,
  vipGoldenIdHoldIn,
} from './vip-identity-ops.js';
import {
  VIP_GOLDEN_ID_ADD_MAX,
  VIP_GOLDEN_ID_OFFER_MAX,
  vipGoldenIdClassOf,
  vipSignatureOf,
  type VipGoldenIdClass,
} from './vip-identity.js';
import { vipHoldsPerkIn } from './vip-perks.js';

const SWEEP_BATCH = 200;

export const vipSignatureBody = z.strictObject({ signature: z.string().max(200).nullable() });
export const vipGoldenIdClaimBody = z.strictObject({ number: z.string().min(1).max(16) });
export const adminGoldenIdsQuery = z.strictObject({
  class: z.enum(VIP_GOLDEN_ID_CLASSES).optional(),
  state: z.enum(['FREE', 'HELD', 'GRACE']).optional(),
});
export const adminGoldenIdsAddBody = z.strictObject({
  numbers: z.array(z.string().min(1).max(16)).min(1).max(VIP_GOLDEN_ID_ADD_MAX),
  reason: z.string().trim().min(3).max(500),
});
export const adminGoldenIdRemoveBody = z.strictObject({ reason: z.string().trim().min(3).max(500) });

/** `VipSignature`. */
export interface VipSignatureDto {
  signature: string | null;
}

/** `VipGoldenIdHolding`: the caller's golden ID. */
export interface VipGoldenIdHoldingDto {
  number: string;
  class: VipGoldenIdClass;
  state: 'HELD' | 'GRACE';
  heldUntil: string | null;
  graceUntil: string | null;
}

/** `VipGoldenIdChoice`: what the caller may pick. */
export interface VipGoldenIdChoiceDto {
  class: VipGoldenIdClass | null;
  mine: VipGoldenIdHoldingDto | null;
  available: string[];
}

/** `AdminVipGoldenId`. */
export interface AdminVipGoldenIdDto {
  number: string;
  class: VipGoldenIdClass;
  state: 'FREE' | 'HELD' | 'GRACE';
  holder: { id: string; username: string } | null;
  heldUntil: string | null;
  graceUntil: string | null;
  claimedAt: string | null;
}

export interface AdminVipGoldenIdListDto {
  data: AdminVipGoldenIdDto[];
  classes: VipGoldenIdClass[];
}

function perkNotHeld(): AppException {
  return new AppException(ErrorCode.VIP_UNAVAILABLE, 'This VIP perk is not yours now.', [
    { field: 'perk', issue: 'not_held' },
  ]);
}

/**
 * v1.131-social (D378, owner 2026-11-11, CONVENTIONS §10.168): the identity perks the server keeps — the member's
 * ANIMATED_SIGNATURE text and the golden IDs «آيدي ذهبي» (GOLDEN_ID: the owner's stock in the panel, a holder's pick
 * from their class, the grace after the membership, the sweeper). The VIP premium username is the premium-usernames
 * module's (`vipClaim`).
 */
@Injectable()
export class VipIdentityService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(VipIdentityService.name);
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<unknown> | null = null;
  private serverWords: { at: number; words: string[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    // The premium usernames' sweep interval (0 in the tests): the same kind of lease, the same pace.
    if (this.config.premiumUsernames.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  // ---- ANIMATED_SIGNATURE -----------------------------------------------------------------------

  /** The server's blocked words (§11.11), re-read at most once a minute. */
  private async blockedWords(): Promise<string[]> {
    const nowMs = Date.now();
    if (this.serverWords === null || nowMs - this.serverWords.at > 60_000) {
      const rows = await this.prisma.searchBlockedWord.findMany({ select: { word: true } });
      this.serverWords = { at: nowMs, words: rows.map((r) => r.word) };
    }
    return this.serverWords.words;
  }

  /**
   * `PUT /me/vip/signature`: sets (or with null clears) the caller's signature. Order: 400 body → 409
   * `VIP_UNAVAILABLE` (`perk` `not_held`) without ANIMATED_SIGNATURE (clearing is always allowed while a membership
   * row exists) → 400 `signature` (`too_short`, `too_long`, `invalid_format`, `blocked_word`). Audited.
   */
  async setSignature(userId: string, body: z.output<typeof vipSignatureBody>): Promise<VipSignatureDto> {
    let text: string | null = null;
    if (body.signature !== null) {
      const checked = vipSignatureOf(body.signature);
      if (!checked.ok) throw AppException.validation([{ field: 'signature', issue: checked.issue }]);
      if (maskBlockedWords(checked.text, await this.blockedWords()) !== checked.text) {
        throw AppException.validation([{ field: 'signature', issue: 'blocked_word' }]);
      }
      text = checked.text;
    }
    return this.prisma.$transaction(async (tx) => {
      const now = this.clock.now();
      const membership = await tx.vipMembership.findUnique({ where: { userId }, select: { signature: true } });
      if (!membership) throw perkNotHeld();
      if (text !== null && !(await vipHoldsPerkIn(tx, userId, 'ANIMATED_SIGNATURE', now))) throw perkNotHeld();
      if (membership.signature !== text) {
        await tx.vipMembership.update({ where: { userId }, data: { signature: text } });
        await tx.auditLog.create({
          data: {
            action: AuditAction.VIP_SIGNATURE_SET,
            actorUserId: userId,
            targetType: 'user',
            targetId: userId,
            metadata: { before: membership.signature, after: text },
          },
        });
      }
      return { signature: text };
    });
  }

  // ---- GOLDEN_ID: the holder ----------------------------------------------------------------------

  private holding(row: {
    number: string;
    class: VipGoldenIdClass;
    state: string;
    heldUntil: Date | null;
    graceUntil: Date | null;
  }): VipGoldenIdHoldingDto {
    return {
      number: row.number,
      class: row.class,
      state: row.state === 'GRACE' ? 'GRACE' : 'HELD',
      heldUntil: row.state === 'HELD' ? (row.heldUntil?.toISOString() ?? null) : null,
      graceUntil: row.state === 'GRACE' ? (row.graceUntil?.toISOString() ?? null) : null,
    };
  }

  /**
   * `GET /me/vip/golden-ids`: the class the caller's GOLDEN_ID lets them pick (null without the perk or a class), their
   * number (HELD, or GRACE — kept for them), and up to 60 FREE numbers of the class, shortest first.
   */
  async choice(userId: string): Promise<VipGoldenIdChoiceDto> {
    const now = this.clock.now();
    const [hold, mine] = await Promise.all([
      vipGoldenIdHoldIn(this.prisma, userId, now),
      this.prisma.vipGoldenId.findUnique({ where: { holderId: userId } }),
    ]);
    const available =
      hold === null
        ? []
        : (
            await this.prisma.vipGoldenId.findMany({
              where: { class: hold.class as VipGoldenIdClass, state: 'FREE' },
              select: { number: true },
              take: 500,
            })
          )
            .map((r) => r.number)
            .sort((a, b) => a.length - b.length || a.localeCompare(b))
            .slice(0, VIP_GOLDEN_ID_OFFER_MAX);
    return {
      class: (hold?.class as VipGoldenIdClass | undefined) ?? null,
      mine: mine && mine.state !== 'FREE' ? this.holding(mine) : null,
      available,
    };
  }

  /**
   * `POST /me/vip/golden-id`: takes [number] — a FREE number of the caller's class, or their own in its grace. A held
   * number of the caller's is given back to the stock first (one number a holder). 409 `VIP_UNAVAILABLE`: `perk`
   * `not_held` (no GOLDEN_ID or no class set), `number` `not_found` (not in the stock), `class` (another class),
   * `taken` (held or kept for someone else). Audited.
   */
  async claim(userId: string, body: z.output<typeof vipGoldenIdClaimBody>): Promise<VipGoldenIdHoldingDto> {
    const number = body.number.trim();
    const refuse = (field: string, issue: string) =>
      new AppException(ErrorCode.VIP_UNAVAILABLE, 'This golden ID cannot be taken now.', [{ field, issue }]);
    return this.prisma.$transaction(async (tx) => {
      await lockGoldenHolderIn(tx, userId);
      const now = this.clock.now();
      const hold = await vipGoldenIdHoldIn(tx, userId, now);
      if (hold === null) throw perkNotHeld();
      const rows = await tx.$queryRaw<{ number: string }[]>`
        SELECT number FROM vip_golden_ids WHERE number = ${number} FOR UPDATE`;
      if (rows.length === 0) throw refuse('number', 'not_found');
      const row = await tx.vipGoldenId.findUniqueOrThrow({ where: { number } });
      if (row.class !== hold.class) throw refuse('number', 'class');
      const freeNow = row.state === 'FREE' || row.holderId === null;
      if (!freeNow && row.holderId !== userId) throw refuse('number', 'taken');
      const old = await tx.vipGoldenId.findUnique({ where: { holderId: userId } });
      if (old && old.number !== number) {
        await freeGoldenIdIn(tx, old.number, userId, 'switched');
      }
      const updated = await tx.vipGoldenId.update({
        where: { number },
        data: {
          state: 'HELD',
          holderId: userId,
          heldUntil: hold.expiresAt,
          graceUntil: null,
          claimedAt: row.holderId === userId && row.claimedAt ? row.claimedAt : now,
        },
      });
      await goldenAuditIn(tx, AuditAction.VIP_GOLDEN_ID_CLAIM, userId, {
        number,
        class: row.class,
        heldUntil: hold.expiresAt.toISOString(),
        previous: old && old.number !== number ? old.number : null,
      });
      return this.holding(updated);
    });
  }

  /** `DELETE /me/vip/golden-id`: gives the caller's number back to the stock now. Idempotent. Audited. */
  async release(userId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await lockGoldenHolderIn(tx, userId);
      const row = await tx.vipGoldenId.findUnique({ where: { holderId: userId } });
      if (!row) return;
      await freeGoldenIdIn(tx, row.number, userId, 'released');
      await goldenAuditIn(tx, AuditAction.VIP_GOLDEN_ID_RELEASE, userId, { number: row.number, class: row.class });
    });
  }

  // ---- GOLDEN_ID: the owner's stock (panel) -------------------------------------------------------

  /** `GET /admin/vip/golden-ids`: the stock (≤ 1 000), shortest numbers first. */
  async adminList(q: z.output<typeof adminGoldenIdsQuery>): Promise<AdminVipGoldenIdListDto> {
    const rows = await this.prisma.vipGoldenId.findMany({
      where: { ...(q.class ? { class: q.class } : {}), ...(q.state ? { state: q.state } : {}) },
      include: { holder: { select: { id: true, profile: { select: { username: true } } } } },
      take: 1000,
    });
    rows.sort((a, b) => a.number.length - b.number.length || a.number.localeCompare(b.number));
    return {
      data: rows.map((r) => ({
        number: r.number,
        class: r.class,
        state: r.state,
        holder: r.holder ? { id: r.holder.id, username: r.holder.profile?.username ?? '' } : null,
        heldUntil: r.heldUntil?.toISOString() ?? null,
        graceUntil: r.graceUntil?.toISOString() ?? null,
        claimedAt: r.claimedAt?.toISOString() ?? null,
      })),
      classes: [...VIP_GOLDEN_ID_CLASSES],
    };
  }

  /**
   * `POST /admin/vip/golden-ids`: adds numbers to the stock, each with the class its digits give
   * ({@link vipGoldenIdClassOf}). 400 `numbers.N` `invalid_format` (not a golden ID), `duplicate_value`, `taken`
   * (already in the stock). Audited (one row, the numbers and their classes).
   */
  async adminAdd(body: z.output<typeof adminGoldenIdsAddBody>, by: AdminVia): Promise<AdminVipGoldenIdListDto> {
    const numbers = body.numbers.map((n) => n.trim());
    const issues: { field: string; issue: string }[] = [];
    const seen = new Set<string>();
    numbers.forEach((n, i) => {
      if (vipGoldenIdClassOf(n) === null) issues.push({ field: `numbers.${String(i)}`, issue: 'invalid_format' });
      else if (seen.has(n)) issues.push({ field: `numbers.${String(i)}`, issue: 'duplicate_value' });
      seen.add(n);
    });
    if (issues.length > 0) throw AppException.validation(issues);
    await this.prisma.$transaction(async (tx) => {
      const existing = new Set(
        (await tx.vipGoldenId.findMany({ where: { number: { in: numbers } }, select: { number: true } })).map(
          (r) => r.number,
        ),
      );
      const taken = numbers.flatMap((n, i) => (existing.has(n) ? [{ field: `numbers.${String(i)}`, issue: 'taken' }] : []));
      if (taken.length > 0) throw AppException.validation(taken);
      const rows = numbers.map((n) => ({ number: n, class: vipGoldenIdClassOf(n)! }));
      await tx.vipGoldenId.createMany({ data: rows });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.VIP_GOLDEN_ID_STOCK_ADD,
          targetType: 'vip_golden_id',
          metadata: { numbers: rows.map((r) => `${r.number}:${r.class}`), reason: body.reason, via: by.via },
        },
      });
    });
    return this.adminList({});
  }

  /**
   * `POST /admin/vip/golden-ids/{number}/remove`: takes a FREE number out of the stock. 404 when not in the stock; 409
   * `ADMIN_ACTION_REFUSED` (`rule` `golden_id_held`) while someone holds it or it is kept in a grace. Audited.
   */
  async adminRemove(number: string, reason: string, by: AdminVia): Promise<AdminVipGoldenIdListDto> {
    await this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<{ state: string; holder_id: string | null }[]>`
        SELECT state::text AS state, holder_id::text AS holder_id FROM vip_golden_ids WHERE number = ${number} FOR UPDATE`;
      const row = rows[0];
      if (!row) throw new AppException(ErrorCode.NOT_FOUND);
      if (row.state !== 'FREE' && row.holder_id !== null) {
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'This golden ID is held.', [
          { field: 'rule', issue: 'golden_id_held' },
        ]);
      }
      await tx.vipGoldenId.delete({ where: { number } });
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.VIP_GOLDEN_ID_STOCK_REMOVE,
          targetType: 'vip_golden_id',
          targetId: number,
          metadata: { number, reason, via: by.via },
        },
      });
    });
    return this.adminList({});
  }

  // ---- The sweeper --------------------------------------------------------------------------------

  /**
   * One pass: every HELD or GRACE number in step with its holder's VIP ({@link syncGoldenIdIn}: the end follows a
   * renewal; the perk or the class gone → GRACE for 7 days; the class back → HELD; the grace over → FREE), and the
   * numbers of a deleted holder back to the stock. Each holder in its own short transaction.
   */
  async sweep(now: Date = this.clock.now()): Promise<{ checked: number }> {
    let checked = 0;
    let after = '';
    for (;;) {
      const rows = await this.prisma.vipGoldenId.findMany({
        where: { state: { in: ['HELD', 'GRACE'] }, number: { gt: after } },
        select: { number: true, holderId: true },
        orderBy: { number: 'asc' },
        take: SWEEP_BATCH,
      });
      for (const r of rows) {
        await this.prisma.$transaction(async (tx) => {
          if (r.holderId === null) await freeGoldenIdIn(tx, r.number, null, 'holder_gone');
          else await syncGoldenIdIn(tx, r.holderId, now);
        });
        checked += 1;
      }
      if (rows.length < SWEEP_BATCH) break;
      after = rows[rows.length - 1]!.number;
    }
    return { checked };
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Golden ID sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.premiumUsernames.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
