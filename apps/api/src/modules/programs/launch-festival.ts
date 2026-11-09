/**
 * v1.101-social (D325, owner 2026-11-09; CONVENTIONS §10.127.10): «مهرجان انطلاقة Kabso» — the launch festival as a
 * DRAFT, ready to be finished in the panel: the owner uploads each gift's art and the page design, reviews the prize
 * table, sets the start and end, then publishes. Nothing is seeded in production: this runs only when the team asks for
 * it, from the panel («قالب مهرجان الانطلاقة», `POST /admin/gift-events/launch-festival`) or the command line
 * (`event-admin festival-draft --reason …`), through the ordinary rules (`createGiftEventIn`), audited.
 *
 * The four exclusive gifts and their multipliers are the owner's (2026-11-09, «method 2»: ×1, ×1, ×1.2, ×1.5; names
 * proposed and not objected to). The prize table and milestones below are a PROPOSAL for the owner to change in the
 * panel before publishing (the notes held no amounts): pieces of the festival's own gifts on every board, coins for
 * the supporters, cherries for the hosts and creators.
 */
import type { AdminVia } from '../../common/audit/admin-actor.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { addGiftByAdminIn } from '../gifts/gift-admin-rules.js';
import { EventAdminError } from './event-admin-rules.js';
import { createGiftEventIn, giftEventInputSchema, updateGiftEventIn, type PrizeItem } from './gift-events.js';

type Tx = Prisma.TransactionClient;

/** The festival's four gifts (owner): code, names, price in coins and the points multiplier. */
export const LAUNCH_FESTIVAL_GIFTS = [
  {
    code: 'kabso_launch_flame',
    nameAr: 'شعلة الانطلاق',
    nameEn: 'Launch Flame',
    priceCoins: 50_000,
    multiplier: 1,
  },
  {
    code: 'kabso_launch_rocket',
    nameAr: 'صاروخ Kabso',
    nameEn: 'Kabso Rocket',
    priceCoins: 250_000,
    multiplier: 1,
  },
  {
    code: 'kabso_launch_crown',
    nameAr: 'تاج الافتتاح',
    nameEn: 'Opening Crown',
    priceCoins: 1_000_000,
    multiplier: 1.2,
  },
  {
    code: 'kabso_launch_night',
    nameAr: 'ليلة المهرجان',
    nameEn: 'Festival Night',
    priceCoins: 3_000_000,
    multiplier: 1.5,
  },
] as const;

const [FLAME, ROCKET, CROWN, NIGHT] = LAUNCH_FESTIVAL_GIFTS.map((g) => g.code) as [
  string,
  string,
  string,
  string,
];

const pieces = (giftCode: string, count: number): PrizeItem => ({ type: 'GIFT_PIECES', giftCode, count });

/** The proposed prize lines of a board whose money is `money` (amounts for ranks 1, 2, 3, 4–10, 11–20). */
function lines(money: 'COINS' | 'CHERRIES', amounts: readonly [number, number, number, number, number]) {
  const m = (amount: number): PrizeItem => ({ type: money, amount });
  return [
    { rankFrom: 1, rankTo: 1, items: [m(amounts[0]), pieces(NIGHT, 3)] },
    { rankFrom: 2, rankTo: 2, items: [m(amounts[1]), pieces(CROWN, 5)] },
    { rankFrom: 3, rankTo: 3, items: [m(amounts[2]), pieces(CROWN, 3)] },
    { rankFrom: 4, rankTo: 10, items: [m(amounts[3]), pieces(ROCKET, 5)] },
    { rankFrom: 11, rankTo: 20, items: [m(amounts[4]), pieces(FLAME, 10)] },
  ];
}

/** The draft's body (`GiftEventInput`): no dates, the three boards, the milestones. */
export function launchFestivalInput(reason: string) {
  return giftEventInputSchema.parse({
    status: 'DRAFT',
    titleAr: 'مهرجان انطلاقة Kabso',
    titleEn: 'Kabso Launch Festival',
    rulesAr:
      'أرسل هدايا المهرجان الأربع لتجمع النقاط: كل كوينز = نقطة، وتاج الافتتاح ×1.2 وليلة المهرجان ×1.5. ' +
      'ترتيب الداعمين للمرسلين، وترتيب المضيفين وصناع المحتوى للمستلمين. الجوائز تصل تلقائياً عند نهاية المهرجان، ' +
      'وهدايا المهرجان الحصرية تصل الفائزين قطعاً مجانية في الحقيبة.',
    rulesEn:
      'Send the four festival gifts to collect points: each coin is a point, the Opening Crown ×1.2 and the Festival ' +
      'Night ×1.5. Supporters rank by what they send; hosts and creators by what they receive. Prizes arrive ' +
      'automatically at the end, and the festival’s exclusive gifts arrive as free pieces in the winners’ bag.',
    startsAt: null,
    endsAt: null,
    recurrence: 'NONE',
    scoring: 'MULTIPLIER',
    countedGifts: 'EVENT_GIFTS',
    audience: 'EVERYONE',
    featured: true,
    gifts: LAUNCH_FESTIVAL_GIFTS.map((g) => ({
      giftCode: g.code,
      pointsPerCoin: g.multiplier,
      pointsPerGift: 0,
    })),
    boards: [
      {
        kind: 'SENDERS',
        minPoints: 1_000_000,
        prizes: lines('COINS', [500_000, 300_000, 200_000, 50_000, 20_000]),
      },
      {
        kind: 'RECEIVERS',
        minPoints: 1_000_000,
        prizes: lines('CHERRIES', [5_000_000, 3_000_000, 2_000_000, 500_000, 200_000]),
      },
      {
        kind: 'CREATORS',
        minPoints: 500_000,
        prizes: lines('CHERRIES', [3_000_000, 2_000_000, 1_000_000, 300_000, 100_000]),
      },
    ],
    milestones: [
      { board: 'SENDERS', points: 1_000_000, prizes: [pieces(FLAME, 5)] },
      { board: 'SENDERS', points: 5_000_000, prizes: [pieces(ROCKET, 5)] },
      { board: 'SENDERS', points: 20_000_000, prizes: [pieces(CROWN, 3)] },
      { board: 'SENDERS', points: 50_000_000, prizes: [pieces(NIGHT, 1)] },
    ],
    reason,
  });
}

/**
 * Creates the festival's draft and its four exclusive gifts (without art: the panel uploads each gift's picture and
 * effect — they are listed only while the published festival runs). Refused (409) when its gifts exist already (the
 * draft was made before). The gifts go into the panel tab `category` (default EVENT).
 */
export async function createLaunchFestivalDraftIn(
  tx: Tx,
  by: AdminVia,
  now: Date,
  reason: string,
  zone: string,
  category = 'EVENT',
): Promise<{ id: string; gifts: string[] }> {
  const tab = await tx.giftCategory.findUnique({ where: { code: category } });
  if (!tab || tab.kind !== 'NORMAL') {
    throw new EventAdminError(`No ordinary gift tab ${category} for the festival gifts (choose one).`);
  }
  const existing = await tx.gift.findMany({
    where: { code: { in: LAUNCH_FESTIVAL_GIFTS.map((g) => g.code) } },
    select: { code: true },
  });
  if (existing.length > 0) {
    throw new EventAdminError(
      `The festival gifts exist already (${existing.map((g) => g.code).join(', ')}).`,
    );
  }
  const input = launchFestivalInput(reason);
  // The gifts first (the draft lists them), then the event; each gift is tied to the event once it exists.
  for (const [i, g] of LAUNCH_FESTIVAL_GIFTS.entries()) {
    await addGiftByAdminIn(
      tx,
      g.code,
      {
        category,
        nameAr: g.nameAr,
        nameEn: g.nameEn,
        priceCoins: g.priceCoins,
        assetKey: g.code,
        animationKey: null,
        sortOrder: i,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      },
      by,
      reason,
      now,
    );
  }
  const created = await createGiftEventIn(
    tx,
    { ...input, gifts: [], milestones: [], boards: [] },
    now,
    by,
    zone,
  );
  await tx.gift.updateMany({
    where: { code: { in: LAUNCH_FESTIVAL_GIFTS.map((g) => g.code) } },
    data: { eventId: created.id },
  });
  // Now the gifts are the event's own: the full draft (gift pieces need their event).
  await updateGiftEventIn(tx, created.id, input, now, by, zone);
  return { id: created.id, gifts: LAUNCH_FESTIVAL_GIFTS.map((g) => g.code) };
}
