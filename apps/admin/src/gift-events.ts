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
/** v1.101-social (D325): the types the v2 editor offers — D303's and free pieces of the event's own gift. */
export function prizeTypesV2For(kind: BoardKind): PrizeType[] {
  return [...prizeTypesFor(kind), 'GIFT_PIECES'];
}
export type PrizeType = (typeof PRIZE_TYPES)[number] | 'GIFT_PIECES';

/** v1.101-social (D325, §10.127): the v2 choices. */
export const EVENT_AUDIENCES = ['EVERYONE', 'HOSTS', 'CREATORS', 'AGENCIES', 'CP'] as const;
export type EventAudience = (typeof EVENT_AUDIENCES)[number];
export const RECURRENCES = ['NONE', 'WEEKLY', 'MONTHLY'] as const;
export const SCORINGS = ['MULTIPLIER', 'COINS'] as const;
export const COUNTED_GIFTS = ['EVENT_GIFTS', 'ALL_GIFTS'] as const;

/** v1.101-social (D325): a milestone «مرحلة» as edited. */
export interface MilestoneForm {
  board: BoardKind;
  points: string;
  items: PrizeItemForm[];
}

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
  /** v1.101-social (D325): the prize's display picture (an uploaded `prize` key) and its preview URL. */
  displayKey?: string;
  displayUrl?: string;
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
  audience: EventAudience;
  featured: boolean;
  /** v1.101-social (D325, §10.127): the lifecycle, the time shape, the scoring method and the counted gifts. */
  status: 'DRAFT' | 'PUBLISHED';
  permanent: boolean;
  recurrence: (typeof RECURRENCES)[number];
  scoring: (typeof SCORINGS)[number];
  countedGifts: (typeof COUNTED_GIFTS)[number];
  /** The Live home banner (a `banner` upload's media id), "" for none. */
  bannerMediaId: string;
  milestones: MilestoneForm[];
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
    /** v1.101-social (D325): the event this exclusive gift belongs to. */
    eventId?: string | null;
    imageUrl?: string | null;
    fullscreen?: boolean;
    hasEffect?: boolean;
  }[];
  bagItems: {
    code: string;
    category: string;
    nameAr: string;
    nameEn: string;
    /** v1.101-social (D325): an event-exclusive prize item's event and its still. */
    eventId?: string | null;
    stillUrl?: string | null;
  }[];
  /** v1.101-social (D325): the ordinary tabs an event's own gift may go in. */
  giftCategories?: { code: string; nameAr: string; nameEn: string }[];
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
    status: 'PUBLISHED',
    permanent: false,
    recurrence: 'NONE',
    scoring: 'MULTIPLIER',
    countedGifts: 'EVENT_GIFTS',
    bannerMediaId: '',
    milestones: [],
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

/** One prize item of the form as its `PrizeItemInput` (the display picture only when set). */
export function prizeItemBody(i: PrizeItemForm): Record<string, unknown> {
  const int = (v: string) => Number.parseInt(v, 10);
  const base =
    i.type === 'COINS' || i.type === 'CHERRIES'
      ? { type: i.type, amount: int(i.value) }
      : i.type === 'CP_MONEY'
        ? { type: i.type, cherries: int(i.cherries ?? '0'), coins: int(i.coins ?? '0') }
        : i.type === 'BAG_ITEM'
          ? { type: i.type, itemCode: i.code, days: i.permanent ? null : int(i.value) }
          : i.type === 'BADGE'
            ? { type: i.type, badgeCode: i.code, level: int(i.level ?? '1'), days: i.permanent ? null : int(i.value) }
            : i.type === 'GIFT_PIECES'
              ? { type: i.type, giftCode: i.code, count: int(i.value) }
              : { type: i.type, tierCode: i.code, days: int(i.value) };
  return i.displayKey ? { ...base, displayKey: i.displayKey } : base;
}

/** v1.101-social (D325): a local wall time, or null when empty (a draft without dates). */
function instantOrNull(local: string, zone: string): string | null {
  return local ? zonedToIso(local, zone) : null;
}

/** The `GiftEventInput` body (openapi) of the form. */
export function giftEventBody(f: GiftEventFormState) {
  const int = (v: string) => Number.parseInt(v, 10);
  return {
    status: f.status,
    permanent: f.permanent,
    recurrence: f.recurrence,
    scoring: f.scoring,
    countedGifts: f.countedGifts,
    bannerMediaId: f.bannerMediaId || null,
    milestones: f.milestones.map((m) => ({ board: m.board, points: int(m.points), prizes: m.items.map(prizeItemBody) })),
    titleAr: f.titleAr.trim(),
    titleEn: f.titleEn.trim(),
    rulesAr: f.rulesAr.trim(),
    rulesEn: f.rulesEn.trim(),
    startsAt: instantOrNull(f.startsAt, f.timeZone),
    endsAt: f.permanent ? null : instantOrNull(f.endsAt, f.timeZone),
    timeZone: f.timeZone,
    audience: f.audience,
    featured: f.featured,
    bannerUrl: f.bannerUrl.trim() || null,
    backgroundKey: f.backgroundKey || null,
    backgroundPosterKey: f.backgroundPosterKey || null,
    titleKey: f.titleKey || null,
    overlayKey: f.overlayKey || null,
    gifts: f.gifts
      .filter((g) => f.status === 'PUBLISHED' || g.giftCode !== '')
      .map((g) => ({
        giftCode: g.giftCode,
        // v1.101-social (D325): a decimal multiplier (×1.2).
        pointsPerCoin: Math.round(Number(g.pointsPerCoin) * 100) / 100,
        pointsPerGift: int(g.pointsPerGift),
      })),
    boards: f.boards.map((b) => ({
      kind: b.kind,
      minPoints: int(b.minPoints),
      prizes: b.prizes.map((l) => ({
        rankFrom: int(l.rankFrom),
        rankTo: int(l.rankTo),
        items: l.items.map(prizeItemBody),
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
    startsAt: string | null;
    endsAt: string | null;
    timeZone: string | null;
    audience: string;
    featured: boolean;
    bannerUrl: string | null;
    status?: string;
    permanent?: boolean;
    recurrence?: string;
    scoring?: string;
    countedGifts?: string;
    bannerMediaId?: string | null;
    milestones?: { board: string; points: number; prizes: Record<string, unknown>[] }[];
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
    startsAt: form.startsAt ? isoToZoned(form.startsAt, zone) : '',
    endsAt: form.endsAt ? isoToZoned(form.endsAt, zone) : '',
    timeZone: zone,
    audience: (form.audience as GiftEventFormState['audience']) ?? 'EVERYONE',
    featured: form.featured,
    status: form.status === 'DRAFT' ? 'DRAFT' : 'PUBLISHED',
    permanent: form.permanent ?? false,
    recurrence: (form.recurrence as GiftEventFormState['recurrence']) ?? 'NONE',
    scoring: (form.scoring as GiftEventFormState['scoring']) ?? 'MULTIPLIER',
    countedGifts: (form.countedGifts as GiftEventFormState['countedGifts']) ?? 'EVENT_GIFTS',
    bannerMediaId: form.bannerMediaId ?? '',
    milestones: (form.milestones ?? []).map((m) => ({
      board: m.board as BoardKind,
      points: String(m.points),
      items: m.prizes.map(itemFromServer),
    })),
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
        items: l.items.map(itemFromServer),
      })),
    })),
    reason: '',
  };
}

/** A stored prize item back into the form. */
function itemFromServer(i: Record<string, unknown>): PrizeItemForm {
  return {
    type: i.type as PrizeType,
    value: String(i.amount ?? i.count ?? i.days ?? ''),
    code: String(i.itemCode ?? i.tierCode ?? i.badgeCode ?? i.giftCode ?? ''),
    ...((i.type === 'BAG_ITEM' || i.type === 'BADGE') && i.days === null ? { permanent: true } : {}),
    ...(i.type === 'BADGE' ? { level: String(i.level ?? 1) } : {}),
    ...(i.type === 'CP_MONEY' ? { cherries: String(i.cherries ?? 0), coins: String(i.coins ?? 0) } : {}),
    ...(typeof i.displayKey === 'string' ? { displayKey: i.displayKey } : {}),
  };
}

/** What blocks saving, as translation keys (the server has the final word). */
export function giftEventProblems(f: GiftEventFormState): string[] {
  const out: string[] = [];
  const whole = (v: string, min: number) => /^\d+$/.test(v.trim()) && Number(v) >= min;
  // v1.101-social (D325): a multiplier with at most two decimals (×1.2).
  const decimal = (v: string) => /^\d+(\.\d{1,2})?$/.test(v.trim()) && Number(v) <= 1000;
  // v1.101-social (D325): a draft may wait for its dates, gifts and boards.
  const draft = f.status === 'DRAFT';
  const gifts = draft ? f.gifts.filter((g) => g.giftCode !== '') : f.gifts;
  if (!f.titleAr.trim() || !f.titleEn.trim()) out.push('gevNeedTitles');
  if (!draft && (!f.startsAt || (!f.endsAt && !f.permanent))) out.push('gevNeedDates');
  else if (f.startsAt && f.endsAt && !f.permanent && f.endsAt <= f.startsAt) out.push('gevEndAfterStart');
  if (!draft && f.countedGifts === 'EVENT_GIFTS' && (gifts.length === 0 || gifts.some((g) => !g.giftCode)))
    out.push('gevNeedGifts');
  if (new Set(gifts.map((g) => g.giftCode)).size !== gifts.length) out.push('gevGiftTwice');
  if (
    gifts.some(
      (g) =>
        !decimal(g.pointsPerCoin) ||
        !whole(g.pointsPerGift, 0) ||
        (f.scoring === 'MULTIPLIER' && Number(g.pointsPerCoin) === 0 && Number(g.pointsPerGift) === 0),
    )
  )
    out.push('gevBadPoints');
  if (!draft && f.boards.length === 0) out.push('gevNeedBoard');
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
        if (i.type === 'GIFT_PIECES') return !i.code || !whole(i.value, 1) || Number(i.value) > 100000;
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
  // v1.101-social (D325): milestones — a board the event has, whole points, distinct, and valid items.
  const kinds = f.boards.map((b) => b.kind);
  const steps = f.milestones.map((m) => `${m.board}:${m.points.trim()}`);
  if (new Set(steps).size !== steps.length) out.push('evMilestoneTwice');
  for (const m of f.milestones) {
    if (!whole(m.points, 1) || (!draft && !kinds.includes(m.board))) out.push('evBadMilestone');
    else if (
      m.items.length === 0 ||
      m.items.some(
        (i) =>
          (MONEY.includes(i.type) && !BOARD_MONEY[m.board].includes(i.type)) ||
          (i.type === 'GIFT_PIECES' ? !i.code || !whole(i.value, 1) : !i.code && !MONEY.includes(i.type)),
      )
    )
      out.push('evBadMilestone');
  }
  if (f.reason.trim().length < 3) out.push('gevNeedReason');
  return [...new Set(out)];
}
