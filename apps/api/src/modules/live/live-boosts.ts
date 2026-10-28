/**
 * v1.33-live (D154b, CONVENTIONS §10.34): traffic cards «بطاقة الزيارات» — the arithmetic, as pure
 * functions shared by the API and the `boost-admin` CLI.
 *
 * The paid slots at the top of the live list are a FIFO queue over `slots` identical slots: a card
 * starts as soon as a slot is free (the one that frees first) and runs for its minutes; a live has
 * at most one card running or waiting at a time. With no other constraint, removing a waiting card
 * or cutting a running one short never makes a later card start later (list scheduling over
 * identical slots is monotone), so the start time told to a buyer is an honest "at the latest".
 */
import type { BoostPrice } from '../../config/env.schema.js';
import type { Prisma } from '../../generated/prisma/client.js';

/** The media data topic of `boost` messages (a traffic card used on a live). */
export const BOOST_TOPIC = 'boost';

/** A card already in the plan. */
export interface PlannedBoost {
  readonly id: string;
  readonly slot: number;
  readonly startsAt: Date;
  readonly endsAt: Date;
}

/** Where a card goes: its slot and when it runs. */
export interface BoostSlot {
  readonly slot: number;
  readonly startsAt: Date;
  readonly endsAt: Date;
}

/**
 * When each slot is free again (never before `now`), from the cards of the plan that end after
 * `now`. Index = slot.
 */
export function slotsFreeAt(now: Date, slots: number, planned: readonly PlannedBoost[]): number[] {
  const free = Array.from({ length: slots }, () => now.getTime());
  for (const b of planned) {
    if (b.slot < 0 || b.slot >= slots) continue;
    free[b.slot] = Math.max(free[b.slot]!, b.endsAt.getTime());
  }
  return free;
}

/** The slot that frees first (the lowest index on a tie) and the card's run from then. */
export function placeBoost(free: readonly number[], minutes: number): BoostSlot {
  let slot = 0;
  for (let i = 1; i < free.length; i++) if (free[i]! < free[slot]!) slot = i;
  const start = free[slot]!;
  return { slot, startsAt: new Date(start), endsAt: new Date(start + minutes * 60_000) };
}

/**
 * Plans the waiting cards again after a change (a card cancelled or cut short): the running ones keep
 * their slot and times; the waiting ones, in their order (`startsAt`, then id), each take the slot that
 * frees first. Returns the new place of every waiting card (by id).
 */
export function replanWaiting(
  now: Date,
  slots: number,
  running: readonly PlannedBoost[],
  waiting: readonly (PlannedBoost & { readonly minutes: number })[],
): Map<string, BoostSlot> {
  const free = slotsFreeAt(now, slots, running);
  const order = [...waiting].sort(
    (a, b) => a.startsAt.getTime() - b.startsAt.getTime() || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  const out = new Map<string, BoostSlot>();
  for (const b of order) {
    const place = placeBoost(free, b.minutes);
    free[place.slot] = place.endsAt.getTime();
    out.set(b.id, place);
  }
  return out;
}

/** `LiveBoostOption`: a length, its price, and what it saves against the shortest one per minute. */
export interface BoostOptionDto {
  minutes: number;
  priceCoins: number;
  /** Rounded percent saved against the shortest length's price per minute (0 for it). */
  savePercent: number;
}

/** The options of the configured prices (owner 15c: «وفّر 10/17/25%»). */
export function boostOptions(prices: readonly BoostPrice[]): BoostOptionDto[] {
  const base = prices[0];
  return prices.map((p) => {
    const full = base ? (base.coins / base.minutes) * p.minutes : p.coins;
    const save = full > 0 ? Math.round(((full - p.coins) / full) * 100) : 0;
    return { minutes: p.minutes, priceCoins: p.coins, savePercent: Math.max(0, save) };
  });
}

/** At most this many cards of one length per user (CHECK `live_boost_cards_shape`). */
export const BOOST_CARDS_MAX = 1_000_000;

/**
 * Adds `quantity` (> 0) traffic cards of `minutes` to `userId` (an admin grant, or a card given back);
 * returns how many they hold, or null when that would pass {@link BOOST_CARDS_MAX} (nothing changes).
 */
export async function addBoostCardsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  minutes: number,
  quantity: number,
): Promise<number | null> {
  if (!Number.isInteger(quantity) || quantity <= 0) throw new RangeError('A grant is positive');
  const rows = await tx.$queryRaw<{ quantity: number }[]>`
    INSERT INTO live_boost_cards (user_id, minutes, quantity, updated_at)
    VALUES (${userId}::uuid, ${minutes}, ${quantity}, now())
    ON CONFLICT (user_id, minutes) DO UPDATE
       SET quantity = live_boost_cards.quantity + EXCLUDED.quantity, updated_at = now()
     WHERE live_boost_cards.quantity + EXCLUDED.quantity <= ${BOOST_CARDS_MAX}
    RETURNING quantity`;
  return rows[0]?.quantity ?? null;
}
