/**
 * v1.97-social (D303, CONVENTIONS §10.114): the panel's gift events «فعاليات الهدايا» — the editable form, its
 * `GiftEventInput` body, and the time-zone arithmetic that makes a date typed for «Asia/Riyadh» the right instant
 * whatever the browser's own zone. The server checks everything again (the same rules as the app's staff editor).
 */

export const BOARD_KINDS = ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'] as const;
export type BoardKind = (typeof BOARD_KINDS)[number];
export const PRIZE_TYPES = ['COINS', 'CHERRIES', 'CP_MONEY', 'BAG_ITEM', 'VIP', 'BADGE'] as const;

/**
 * Owner (D303 follow-ups): the money each board gives — supporters coins; hosts (and creators) and creators cherries;
 * agencies either; CP the two-amount line (cherries for a host / creator partner, coins for another). Items, VIP and
 * medals on every board. The server checks it again.
 */
export const BOARD_MONEY: Record<BoardKind, readonly PrizeType[]> = {
  SENDERS: ['COINS'],
  RECEIVERS: ['CHERRIES'],
  CREATORS: ['CHERRIES'],
  AGENCIES: ['COINS', 'CHERRIES'],
  CP: ['CP_MONEY'],
};
const MONEY: readonly PrizeType[] = ['COINS', 'CHERRIES', 'CP_MONEY'];

/** The prize types a board's editor offers. */
export function prizeTypesFor(kind: BoardKind): PrizeType[] {
  return PRIZE_TYPES.filter((t) => !MONEY.includes(t) || BOARD_MONEY[kind].includes(t));
}
export type PrizeType = (typeof PRIZE_TYPES)[number];

export interface PrizeItemForm {
  type: PrizeType;
  /** COINS / CHERRIES: the amount; BAG_ITEM / VIP: the days. */
  value: string;
  /** BAG_ITEM: the item code; VIP: the tier code; BADGE: the medal code. */
  code: string;
  /** D303 follow-ups: BAG_ITEM / BADGE «دائم» (no end; `value` ignored). */
  permanent?: boolean;
  /** BADGE: the medal level (1 … 10). */
  level?: string;
  /** CP_MONEY: the two amounts (a host / creator partner gets the cherries, another the coins). */
  cherries?: string;
  coins?: string;
}
export interface PrizeLineForm {
  rankFrom: string;
  rankTo: string;
  items: PrizeItemForm[];
}
export interface BoardForm {
  kind: BoardKind;
  minPoints: string;
  prizes: PrizeLineForm[];
}
export interface GiftForm {
  giftCode: string;
  pointsPerCoin: string;
  pointsPerGift: string;
}
export interface GiftEventFormState {
  titleAr: string;
  titleEn: string;
  rulesAr: string;
  rulesEn: string;
  /** `datetime-local` text, in `timeZone`. */
  startsAt: string;
  endsAt: string;
  timeZone: string;
  audience: 'EVERYONE' | 'HOSTS' | 'CREATORS';
  featured: boolean;
  bannerUrl: string;
  /** D303 follow-ups: the uploaded page art (keys from `POST /admin/event-uploads`), "" for none. */
  backgroundKey?: string;
  backgroundPosterKey?: string;
  titleKey?: string;
  overlayKey?: string;
  gifts: GiftForm[];
  boards: BoardForm[];
  reason: string;
}

/** `EventOptions` (openapi). */
export interface EventMediaSpec {
  kind: string;
  width: number | null;
  height: number | null;
  formats: string[];
  maxStillBytes: number | null;
  maxAnimatedBytes: number | null;
  maxDurationMs: number | null;
  transparent: boolean;
  safeZone: string | null;
}

/** One line of an art spec, as shown beside its upload field («1500 × 300 px · PNG, … · ≤ 2 MB · ≤ 10 s»). */
export function specText(spec: EventMediaSpec): string {
  const mb = (n: number | null) => (n === null ? null : `≤ ${String(Math.round((n / 1048576) * 10) / 10)} MB`);
  return [
    spec.width && spec.height ? `${String(spec.width)} × ${String(spec.height)} px` : null,
    spec.formats.join(', '),
    spec.maxStillBytes !== null ? `${mb(spec.maxStillBytes)!} (still)` : null,
    spec.maxAnimatedBytes !== null ? `${mb(spec.maxAnimatedBytes)!} (animated / video)` : null,
    spec.maxDurationMs !== null ? `≤ ${String(spec.maxDurationMs / 1000)} s` : null,
    spec.transparent ? 'transparent' : null,
  ]
    .filter((x): x is string => x !== null)
    .join(' · ');
}

export interface EventOptions {
  timeZone: string;
  boardKinds: BoardKind[];
  specs?: EventMediaSpec[];
  badges?: {
    code: string;
    nameAr: string;
    nameEn: string;
    levels: { level: number; imageUrl: string | null }[];
  }[];
  gifts: {
    code: string;
    nameAr: string;
    nameEn: string;
    priceCoins: number;
    enabled: boolean;
  }[];
  bagItems: {
    code: string;
    category: string;
    nameAr: string;
    nameEn: string;
  }[];
  vipTiers: {
    code: string;
    nameAr: string;
    nameEn: string;
    enabled: boolean;
  }[];
}

/** Ranks 1, 2, 3, 4–5, 6–10 as in the owner's reference; the bundles shrink with the rank. */
export function defaultPrizeLines(kind: BoardKind = 'SENDERS'): PrizeLineForm[] {
  const money = BOARD_MONEY[kind][0]!;
  const item = (value: string): PrizeItemForm =>
    money === 'CP_MONEY'
      ? { type: money, value, code: '', cherries: value, coins: value }
      : { type: money, value, code: '' };
  return [
    {
      rankFrom: '1',
      rankTo: '1',
      items: [item('10000')],
    },
    {
      rankFrom: '2',
      rankTo: '2',
      items: [item('5000')],
    },
    {
      rankFrom: '3',
      rankTo: '3',
      items: [item('3000')],
    },
    {
      rankFrom: '4',
      rankTo: '5',
      items: [item('1000')],
    },
    {
      rankFrom: '6',
      rankTo: '10',
      items: [item('500')],
    },
  ];
}

export function emptyGiftEvent(timeZone: string): GiftEventFormState {
  return {
    titleAr: '',
    titleEn: '',
    rulesAr: '',
    rulesEn: '',
    startsAt: '',
    endsAt: '',
    timeZone,
    audience: 'EVERYONE',
    featured: false,
    bannerUrl: '',
    gifts: [{ giftCode: '', pointsPerCoin: '1', pointsPerGift: '0' }],
    boards: [
      { kind: 'SENDERS', minPoints: '0', prizes: defaultPrizeLines() },
      {
        kind: 'RECEIVERS',
        minPoints: '0',
        prizes: defaultPrizeLines('RECEIVERS'),
      },
    ],
    reason: '',
  };
}

/** The offset of `zone` at the instant `utcMs`, in minutes east of UTC. */
export function zoneOffsetMinutes(zone: string, utcMs: number): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(new Date(utcMs));
  const n = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? 0);
  const asUtc = Date.UTC(n('year'), n('month') - 1, n('day'), n('hour'), n('minute'), n('second'));
  return Math.round((asUtc - Math.floor(utcMs / 1000) * 1000) / 60_000);
}

/** A `datetime-local` wall time in `zone` → the ISO instant (e.g. `2026-11-10T20:00` in Asia/Riyadh → 17:00Z). */
export function zonedToIso(local: string, zone: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(local);
  if (!m) throw new RangeError(`Not a local time: ${local}`);
  const wall = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]));
  let utc = wall - zoneOffsetMinutes(zone, wall) * 60_000;
  // Once more at the found instant (a daylight-saving change between the two).
  utc = wall - zoneOffsetMinutes(zone, utc) * 60_000;
  return new Date(utc).toISOString();
}

/** An ISO instant → the `datetime-local` wall time in `zone` (for editing). */
export function isoToZoned(iso: string, zone: string): string {
  const ms = new Date(iso).getTime();
  const wall = new Date(ms + zoneOffsetMinutes(zone, ms) * 60_000);
  return wall.toISOString().slice(0, 16);
}

/** The `GiftEventInput` body (openapi) of the form. */
export function giftEventBody(f: GiftEventFormState) {
  const int = (v: string) => Number.parseInt(v, 10);
  return {
    titleAr: f.titleAr.trim(),
    titleEn: f.titleEn.trim(),
    rulesAr: f.rulesAr.trim(),
    rulesEn: f.rulesEn.trim(),
    startsAt: zonedToIso(f.startsAt, f.timeZone),
    endsAt: zonedToIso(f.endsAt, f.timeZone),
    timeZone: f.timeZone,
    audience: f.audience,
    featured: f.featured,
    bannerUrl: f.bannerUrl.trim() || null,
    backgroundKey: f.backgroundKey || null,
    backgroundPosterKey: f.backgroundPosterKey || null,
    titleKey: f.titleKey || null,
    overlayKey: f.overlayKey || null,
    gifts: f.gifts.map((g) => ({
      giftCode: g.giftCode,
      pointsPerCoin: int(g.pointsPerCoin),
      pointsPerGift: int(g.pointsPerGift),
    })),
    boards: f.boards.map((b) => ({
      kind: b.kind,
      minPoints: int(b.minPoints),
      prizes: b.prizes.map((l) => ({
        rankFrom: int(l.rankFrom),
        rankTo: int(l.rankTo),
        items: l.items.map((i) =>
          i.type === 'COINS' || i.type === 'CHERRIES'
            ? { type: i.type, amount: int(i.value) }
            : i.type === 'CP_MONEY'
              ? {
                  type: i.type,
                  cherries: int(i.cherries ?? '0'),
                  coins: int(i.coins ?? '0'),
                }
              : i.type === 'BAG_ITEM'
                ? {
                    type: i.type,
                    itemCode: i.code,
                    days: i.permanent ? null : int(i.value),
                  }
                : i.type === 'BADGE'
                  ? {
                      type: i.type,
                      badgeCode: i.code,
                      level: int(i.level ?? '1'),
                      days: i.permanent ? null : int(i.value),
                    }
                  : { type: i.type, tierCode: i.code, days: int(i.value) },
        ),
      })),
    })),
    reason: f.reason.trim(),
  };
}

/** The stored form (`AdminGiftEvent.form`) back into the editable state, dates in the event's zone. */
export function formFromServer(
  form: {
    titleAr: string;
    titleEn: string;
    rulesAr: string;
    rulesEn: string;
    startsAt: string;
    endsAt: string | null;
    timeZone: string | null;
    audience: string;
    featured: boolean;
    bannerUrl: string | null;
    backgroundKey?: string | null;
    backgroundPosterKey?: string | null;
    titleKey?: string | null;
    overlayKey?: string | null;
    gifts: { giftCode: string; pointsPerCoin: number; pointsPerGift: number }[];
    boards: {
      kind: string;
      minPoints: number;
      prizes: {
        rankFrom: number;
        rankTo: number;
        items: Record<string, unknown>[];
      }[];
    }[];
  },
  fallbackZone: string,
): GiftEventFormState {
  const zone = form.timeZone ?? fallbackZone;
  return {
    titleAr: form.titleAr,
    titleEn: form.titleEn,
    rulesAr: form.rulesAr,
    rulesEn: form.rulesEn,
    startsAt: isoToZoned(form.startsAt, zone),
    endsAt: form.endsAt ? isoToZoned(form.endsAt, zone) : '',
    timeZone: zone,
    audience: (form.audience as GiftEventFormState['audience']) ?? 'EVERYONE',
    featured: form.featured,
    bannerUrl: form.bannerUrl ?? '',
    backgroundKey: form.backgroundKey ?? '',
    backgroundPosterKey: form.backgroundPosterKey ?? '',
    titleKey: form.titleKey ?? '',
    overlayKey: form.overlayKey ?? '',
    gifts: form.gifts.map((g) => ({
      giftCode: g.giftCode,
      pointsPerCoin: String(g.pointsPerCoin),
      pointsPerGift: String(g.pointsPerGift),
    })),
    boards: form.boards.map((b) => ({
      kind: b.kind as BoardKind,
      minPoints: String(b.minPoints),
      prizes: b.prizes.map((l) => ({
        rankFrom: String(l.rankFrom),
        rankTo: String(l.rankTo),
        items: l.items.map((i) => ({
          type: i.type as PrizeType,
          value: String(i.amount ?? i.days ?? ''),
          code: String(i.itemCode ?? i.tierCode ?? i.badgeCode ?? ''),
          ...((i.type === 'BAG_ITEM' || i.type === 'BADGE') && i.days === null ? { permanent: true } : {}),
          ...(i.type === 'BADGE' ? { level: String(i.level ?? 1) } : {}),
          ...(i.type === 'CP_MONEY' ? { cherries: String(i.cherries ?? 0), coins: String(i.coins ?? 0) } : {}),
        })),
      })),
    })),
    reason: '',
  };
}

/** What blocks saving, as translation keys (the server has the final word). */
export function giftEventProblems(f: GiftEventFormState): string[] {
  const out: string[] = [];
  const whole = (v: string, min: number) => /^\d+$/.test(v.trim()) && Number(v) >= min;
  if (!f.titleAr.trim() || !f.titleEn.trim()) out.push('gevNeedTitles');
  if (!f.startsAt || !f.endsAt) out.push('gevNeedDates');
  else if (f.endsAt <= f.startsAt) out.push('gevEndAfterStart');
  if (f.gifts.length === 0 || f.gifts.some((g) => !g.giftCode)) out.push('gevNeedGifts');
  if (new Set(f.gifts.map((g) => g.giftCode)).size !== f.gifts.length) out.push('gevGiftTwice');
  if (
    f.gifts.some(
      (g) =>
        !whole(g.pointsPerCoin, 0) ||
        !whole(g.pointsPerGift, 0) ||
        (Number(g.pointsPerCoin) === 0 && Number(g.pointsPerGift) === 0),
    )
  )
    out.push('gevBadPoints');
  if (f.boards.length === 0) out.push('gevNeedBoard');
  for (const b of f.boards) {
    if (!whole(b.minPoints, 0)) out.push('gevBadMin');
    let last = 0;
    for (const l of b.prizes) {
      const from = Number(l.rankFrom);
      const to = Number(l.rankTo);
      if (!whole(l.rankFrom, 1) || !whole(l.rankTo, 1) || to < from || to > 100 || from <= last) {
        out.push('gevBadRanks');
        break;
      }
      last = to;
      if (l.items.some((i) => MONEY.includes(i.type) && !BOARD_MONEY[b.kind].includes(i.type))) {
        out.push('gevWrongMoney');
        break;
      }
      const itemBad = (i: PrizeItemForm) => {
        if (i.type === 'CP_MONEY') {
          return (
            !whole(i.cherries ?? '', 0) ||
            !whole(i.coins ?? '', 0) ||
            (Number(i.cherries) === 0 && Number(i.coins) === 0)
          );
        }
        if (i.type === 'COINS' || i.type === 'CHERRIES') return !whole(i.value, 1);
        if (!i.code) return true;
        if (i.type === 'BADGE' && !(whole(i.level ?? '', 1) && Number(i.level) <= 10)) return true;
        if (i.permanent && i.type !== 'VIP') return false;
        return !whole(i.value, 1) || Number(i.value) > 365;
      };
      if (l.items.length === 0 || l.items.some(itemBad)) {
        out.push('gevBadItems');
        break;
      }
    }
  }
  if (f.reason.trim().length < 3) out.push('gevNeedReason');
  return [...new Set(out)];
}
