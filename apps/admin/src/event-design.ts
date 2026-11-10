/**
 * D356 (CONVENTIONS §10.152): the panel's side of the event page designer «مصمم صفحة الفعالية» (the contract is D354's
 * v1.115-social `design`, §10.150 — unchanged). Pure functions, tested without a browser:
 * - the editable design, its body and its reading from the server;
 * - the same rules as the server (`apps/api/src/modules/programs/event-design.ts`), so a refusal is seen before saving,
 *   and the server's 400 `design_*` issues mapped back to their fields;
 * - the draft event the live preview draws (`EventDetail` JSON) and the postMessage protocol with the preview bundle;
 * - the contrast warning «قد يصعب قراءة النص» from the presets' fills and a background's measured luminance.
 */
import { ApiError } from './api';
import {
  BOARD_SHOWN_DEFAULT,
  prizeItemBody,
  type BoardForm,
  type BoardKind,
  type EventOptions,
  type GiftEventFormState,
  type PrizeItemForm,
} from './gift-events';

export const DESIGN_LAYOUTS = ['HERO_PODIUM', 'STAGE', 'DECK'] as const;
export const DESIGN_LEADERBOARDS = ['THRONE', 'PODIUM', 'CARDS_ROW', 'SPOTLIGHT', 'SHIELD_CREST'] as const;
export const DESIGN_COUNTDOWNS = ['CLASSIC', 'FLIP', 'RING', 'COINS', 'NEON', 'RIBBON'] as const;
export const DESIGN_PRESETS = ['CLASSIC', 'LUXURY_GOLD', 'GLASS', 'DARK_MINIMAL', 'NEON', 'KABSO_RED'] as const;
export const DESIGN_RULES_BUTTONS = ['EDGE_RIBBON', 'ROUND_ICON', 'GOLD_PILL', 'GLASS_CHIP', 'SIDE_TAB', 'APP_BAR_LINK'] as const;
export const DESIGN_EDGES = ['START', 'END'] as const;
export const DESIGN_SECTIONS = ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'] as const;
export const DESIGN_ENTRANCES = ['FADE', 'SLIDE', 'SCALE', 'NONE'] as const;

export type DesignLayout = (typeof DESIGN_LAYOUTS)[number];
export type DesignLeaderboard = (typeof DESIGN_LEADERBOARDS)[number];
export type DesignCountdown = (typeof DESIGN_COUNTDOWNS)[number];
export type DesignPreset = (typeof DESIGN_PRESETS)[number];
export type DesignRulesStyle = (typeof DESIGN_RULES_BUTTONS)[number];
export type DesignEdge = (typeof DESIGN_EDGES)[number];
export type DesignSection = (typeof DESIGN_SECTIONS)[number];
export type DesignEntrance = (typeof DESIGN_ENTRANCES)[number];

/** The server's limits (`EventOptions.designChoices.limits`, the same numbers). */
export const DESIGN_LIMITS = { tiers: 40, featured: 3, labelLength: 24, entranceMaxMs: 1500 } as const;

/** `EventOptions.designChoices` (v1.115-social): the server's lists; the panel falls back to its own. */
export interface DesignChoices {
  v: number;
  layouts: string[];
  leaderboards: string[];
  countdowns: string[];
  presets: string[];
  rulesButtons: string[];
  edges: string[];
  sections: string[];
  entrances: string[];
  limits: Record<string, number>;
}

/** The choices to offer: the panel's own, limited to what the server lists (an older server lists nothing new). */
export function offered<T extends string>(own: readonly T[], server: string[] | undefined): T[] {
  return server ? own.filter((x) => server.includes(x)) : [...own];
}

export interface TierForm {
  board: BoardKind;
  from: string;
  to: string;
  labelAr: string;
  labelEn: string;
  /** Indexes into the items of the board's prize line covering the tier. */
  featured: number[];
}

export interface MotionForm {
  entrance: DesignEntrance;
  durationMs: number;
  shimmer: boolean;
  pulseFirst: boolean;
  overlaySpeed: number;
  overlayOpacity: number;
}

/** The design as edited. `GiftEventFormState.design`: undefined = not loaded (not sent: kept), null = today's page. */
export interface DesignForm {
  layout: DesignLayout;
  leaderboard: DesignLeaderboard;
  countdown: DesignCountdown;
  preset: DesignPreset;
  rulesButton: { style: DesignRulesStyle; edge: DesignEdge } | null;
  sections: { id: DesignSection; visible: boolean }[];
  /** An `EVENT_BOARD_BG` media id (a `board_background` upload), null for the style's own background. */
  backgroundMediaId: string | null;
  /** Its picture (not sent; for the preview and the contrast check). */
  backgroundUrl: string | null;
  /** Null: one tier per prize line of each board (the server's default). */
  tiers: TierForm[] | null;
  motion: MotionForm;
}

export const DEFAULT_MOTION: MotionForm = {
  entrance: 'FADE',
  durationMs: 450,
  shimmer: true,
  pulseFirst: true,
  overlaySpeed: 1,
  overlayOpacity: 1,
};

/** «إعادة إلى التصميم الافتراضي»: the server's defaults (the background is kept: it is an upload, not a choice). */
export function defaultDesign(keep?: Pick<DesignForm, 'backgroundMediaId' | 'backgroundUrl'>): DesignForm {
  return {
    layout: 'HERO_PODIUM',
    leaderboard: 'THRONE',
    countdown: 'CLASSIC',
    preset: 'CLASSIC',
    rulesButton: null,
    sections: DESIGN_SECTIONS.map((id) => ({ id, visible: true })),
    backgroundMediaId: keep?.backgroundMediaId ?? null,
    backgroundUrl: keep?.backgroundUrl ?? null,
    tiers: null,
    motion: { ...DEFAULT_MOTION },
  };
}

const pick = <T extends string>(list: readonly T[], v: unknown, d: T): T =>
  (list as readonly unknown[]).includes(v) ? (v as T) : d;
const num = (v: unknown, min: number, max: number, d: number) =>
  typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : d;

/** `AdminGiftEvent.form.design` (or `EventDetail.design`) back into the form; null / unknown version = none. */
export function designFromServer(json: unknown, backgroundUrl: string | null = null): DesignForm | null {
  if (!json || typeof json !== 'object') return null;
  const d = json as Record<string, unknown>;
  if (d.v !== 1 || !(DESIGN_LAYOUTS as readonly unknown[]).includes(d.layout)) return null;
  const rb = d.rulesButton as Record<string, unknown> | null | undefined;
  const sections: DesignForm['sections'] = [];
  for (const s of Array.isArray(d.sections) ? (d.sections as Record<string, unknown>[]) : []) {
    const id = s?.id;
    if ((DESIGN_SECTIONS as readonly unknown[]).includes(id) && !sections.some((x) => x.id === id)) {
      sections.push({ id: id as DesignSection, visible: s.visible !== false });
    }
  }
  for (const id of DESIGN_SECTIONS) if (!sections.some((x) => x.id === id)) sections.push({ id, visible: true });
  const rewards = d.rewards as { tiers?: Record<string, unknown>[] } | null | undefined;
  const m = (d.motion ?? {}) as Record<string, unknown>;
  return {
    layout: d.layout as DesignLayout,
    leaderboard: pick(DESIGN_LEADERBOARDS, d.leaderboard, 'THRONE'),
    countdown: pick(DESIGN_COUNTDOWNS, d.countdown, 'CLASSIC'),
    preset: pick(DESIGN_PRESETS, d.preset, 'CLASSIC'),
    rulesButton:
      rb && (DESIGN_RULES_BUTTONS as readonly unknown[]).includes(rb.style)
        ? { style: rb.style as DesignRulesStyle, edge: rb.edge === 'START' ? 'START' : 'END' }
        : null,
    sections,
    backgroundMediaId: typeof d.leaderboardBackgroundMediaId === 'string' ? d.leaderboardBackgroundMediaId : null,
    backgroundUrl:
      backgroundUrl ?? (typeof d.leaderboardBackgroundUrl === 'string' ? d.leaderboardBackgroundUrl : null),
    tiers: Array.isArray(rewards?.tiers)
      ? rewards.tiers.map((t) => ({
          board: t.board as BoardKind,
          from: String(t.from ?? ''),
          to: String(t.to ?? ''),
          labelAr: typeof t.labelAr === 'string' ? t.labelAr : '',
          labelEn: typeof t.labelEn === 'string' ? t.labelEn : '',
          featured: Array.isArray(t.featured) ? (t.featured as unknown[]).filter((x): x is number => typeof x === 'number') : [],
        }))
      : null,
    motion: {
      entrance: pick(DESIGN_ENTRANCES, m.entrance, 'FADE'),
      durationMs: Math.round(num(m.durationMs, 0, DESIGN_LIMITS.entranceMaxMs, 450)),
      shimmer: m.shimmer !== false,
      pulseFirst: m.pulseFirst !== false,
      overlaySpeed: num(m.overlaySpeed, 0.25, 2, 1),
      overlayOpacity: num(m.overlayOpacity, 0, 1, 1),
    },
  };
}

/** The `EventPageDesignInput` body (v1.115-social) of the form, null for today's page. */
export function designBody(d: DesignForm | null) {
  if (d === null) return null;
  const int = (v: string) => Number.parseInt(v, 10);
  return {
    v: 1 as const,
    layout: d.layout,
    leaderboard: d.leaderboard,
    countdown: d.countdown,
    preset: d.preset,
    rulesButton: d.rulesButton ? { ...d.rulesButton } : null,
    sections: d.sections.map((s) => ({ ...s })),
    leaderboardBackgroundMediaId: d.backgroundMediaId,
    rewards:
      d.tiers === null || d.tiers.length === 0
        ? null
        : {
            tiers: d.tiers.map((t) => ({
              board: t.board,
              from: int(t.from),
              to: int(t.to),
              labelAr: t.labelAr.trim() || null,
              labelEn: t.labelEn.trim() || null,
              featured: [...t.featured],
            })),
          },
    motion: { ...d.motion },
  };
}

// ---- the rules (mirror the server's, §10.150.3) -----------------------------------------------------------------

export type DesignIssue =
  | 'design_sections'
  | 'design_rules_unreachable'
  | 'design_boards_required'
  | 'design_tier_board'
  | 'design_tier_range'
  | 'design_tier_overlap'
  | 'design_tier_prize'
  | 'design_tier_featured'
  | 'design_tier_label'
  | 'design_tiers_many'
  | 'invalid_value';

export interface DesignProblem {
  /** The server's field: `design.sections`, `design.rulesButton`, `design.rewards.tiers.N`, … */
  field: string;
  issue: DesignIssue;
  /** The tier's index for a tier problem. */
  tier?: number;
}

/** A board's places: «عدد المعروضين» as typed, else 20 (as the server reads the body). */
export function boardPlaces(b: BoardForm): number {
  const n = Number(b.shown);
  return b.shown !== undefined && b.shown.trim() !== '' && Number.isInteger(n) && n >= 1 ? n : BOARD_SHOWN_DEFAULT;
}

/** The prize line of [b] that holds ranks from…to, or null. */
export function coveringLine(b: BoardForm, from: number, to: number) {
  return (
    b.prizes.find((l) => from >= Number(l.rankFrom) && to <= Number(l.rankTo)) ?? null
  );
}

/** The design's problems against the event's boards — the server's rules, plus the label length its schema checks. */
export function designProblems(d: DesignForm, boards: readonly BoardForm[]): DesignProblem[] {
  const out: DesignProblem[] = [];
  const ids = d.sections.map((s) => s.id);
  if (new Set(ids).size !== DESIGN_SECTIONS.length || ids.length !== DESIGN_SECTIONS.length) {
    out.push({ field: 'design.sections', issue: 'design_sections' });
  }
  const visible = (id: DesignSection) => d.sections.find((s) => s.id === id)?.visible ?? true;
  if (!visible('RULES') && d.rulesButton === null) {
    out.push({ field: 'design.rulesButton', issue: 'design_rules_unreachable' });
  }
  if (!visible('BOARDS') && boards.length > 0) out.push({ field: 'design.sections', issue: 'design_boards_required' });
  const tiers = d.tiers ?? [];
  if (tiers.length > DESIGN_LIMITS.tiers) out.push({ field: 'design.rewards.tiers', issue: 'design_tiers_many' });
  const last = new Map<BoardKind, number>();
  tiers.forEach((t, i) => {
    const field = `design.rewards.tiers.${String(i)}`;
    const problem = (issue: DesignIssue) => out.push({ field, issue, tier: i });
    if (t.labelAr.trim().length > DESIGN_LIMITS.labelLength || t.labelEn.trim().length > DESIGN_LIMITS.labelLength) {
      problem('design_tier_label');
    }
    const board = boards.find((b) => b.kind === t.board);
    if (!board) return problem('design_tier_board');
    const from = Number(t.from);
    const to = Number(t.to);
    const places = boardPlaces(board);
    if (!/^\d+$/.test(t.from.trim()) || !/^\d+$/.test(t.to.trim()) || from < 1 || to < from || to > places) {
      return problem('design_tier_range');
    }
    if (from <= (last.get(t.board) ?? 0)) problem('design_tier_overlap');
    last.set(t.board, Math.max(last.get(t.board) ?? 0, to));
    const line = coveringLine(board, from, to);
    if (!line) return problem('design_tier_prize');
    if (
      t.featured.length > DESIGN_LIMITS.featured ||
      new Set(t.featured).size !== t.featured.length ||
      t.featured.some((f) => f < 0 || f >= line.items.length)
    ) {
      problem('design_tier_featured');
    }
  });
  return out;
}

/** The server's 400 `design*` issues by field (the step shows each where it belongs). */
export function designServerProblems(err: unknown): DesignProblem[] {
  if (!(err instanceof ApiError) || err.code !== 'VALIDATION_FAILED') return [];
  return err.details
    .filter((x) => x.field === 'design' || x.field.startsWith('design.'))
    .map((x) => {
      const m = /^design\.rewards\.tiers\.(\d+)/.exec(x.field);
      return { field: x.field, issue: x.issue as DesignIssue, ...(m ? { tier: Number(m[1]) } : {}) };
    });
}

/** Problems of one place: the sections list, the rules button, a tier, the background. */
export function problemsAt(problems: readonly DesignProblem[], where: 'sections' | 'rules' | 'background' | number) {
  return problems.filter((p) =>
    where === 'sections'
      ? p.field === 'design.sections'
      : where === 'rules'
        ? p.field === 'design.rulesButton'
        : where === 'background'
          ? p.field === 'design.leaderboardBackgroundMediaId'
          : p.tier === where,
  );
}

// ---- sections: order and visibility ------------------------------------------------------------------------------

/** Moves the section at [from] to [to] (drag and drop, or the ↑ / ↓ buttons). */
export function moveSection(d: DesignForm, from: number, to: number): DesignForm {
  if (from === to || from < 0 || to < 0 || from >= d.sections.length || to >= d.sections.length) return d;
  const sections = [...d.sections];
  const [s] = sections.splice(from, 1);
  sections.splice(to, 0, s!);
  return { ...d, sections };
}

/** Why a section's visibility cannot change now (an i18n key's issue), or null. */
export function sectionLock(d: DesignForm, id: DesignSection, hasBoards: boolean): DesignIssue | null {
  const s = d.sections.find((x) => x.id === id);
  if (!s?.visible) return null; // showing is always allowed
  if (id === 'BOARDS' && hasBoards) return 'design_boards_required';
  if (id === 'RULES' && d.rulesButton === null) return 'design_rules_unreachable';
  return null;
}

/** Shows or hides a section; a hide the rules refuse leaves the design as it is. */
export function setSectionVisible(d: DesignForm, id: DesignSection, visible: boolean, hasBoards: boolean): DesignForm {
  if (!visible && sectionLock(d, id, hasBoards)) return d;
  return { ...d, sections: d.sections.map((s) => (s.id === id ? { ...s, visible } : s)) };
}

/** Sets the rules button; without one the rules section comes back (the rules must stay reachable). */
export function setRulesButton(d: DesignForm, rulesButton: DesignForm['rulesButton']): DesignForm {
  return {
    ...d,
    rulesButton,
    sections: rulesButton === null ? d.sections.map((s) => (s.id === 'RULES' ? { ...s, visible: true } : s)) : d.sections,
  };
}

// ---- rewards tiers -------------------------------------------------------------------------------------------------

/** The server's default for a board, as editable tiers: one per prize line (within its places). */
export function tiersFromLines(b: BoardForm): TierForm[] {
  const places = boardPlaces(b);
  return b.prizes
    .filter((l) => Number(l.rankFrom) <= places)
    .map((l) => ({
      board: b.kind,
      from: l.rankFrom,
      to: String(Math.min(Number(l.rankTo), places)),
      labelAr: '',
      labelEn: '',
      featured: [],
    }));
}

/** A new tier after the board's last one, inside the line that holds that rank (one rank wide). */
export function nextTier(d: DesignForm, b: BoardForm): TierForm | null {
  const mine = (d.tiers ?? []).filter((t) => t.board === b.kind);
  const after = Math.max(0, ...mine.map((t) => Number(t.to) || 0)) + 1;
  if (after > boardPlaces(b) || !coveringLine(b, after, after)) return null;
  return { board: b.kind, from: String(after), to: String(after), labelAr: '', labelEn: '', featured: [] };
}

/** The tiers with a board's own sorted by rank (other boards keep their places). */
export function withTier(d: DesignForm, tier: TierForm): DesignForm {
  return { ...d, tiers: [...(d.tiers ?? []), tier] };
}

// ---- the live preview ------------------------------------------------------------------------------------------

export const PREVIEW_RENDER = 'kabso.eventPreview.render';
export const PREVIEW_READY = 'kabso.eventPreview.ready';
export const PREVIEW_RENDERED = 'kabso.eventPreview.rendered';
export const PREVIEW_ERROR = 'kabso.eventPreview.error';
export const PREVIEW_STATES = ['UPCOMING', 'RUNNING', 'FINAL_HOUR', 'ENDED'] as const;
export type PreviewState = (typeof PREVIEW_STATES)[number];
export const PREVIEW_DEVICES = [
  { id: 'phone', width: 393, height: 852 },
  { id: 'android', width: 360, height: 800 },
] as const;
export type PreviewDevice = (typeof PREVIEW_DEVICES)[number]['id'];

export interface PreviewSettings {
  language: 'ar' | 'en';
  theme: 'dark' | 'light';
  state: PreviewState;
  device: PreviewDevice;
  reduceMotion: boolean;
}

/** The art URLs the panel knows (`AdminGiftEvent.artUrls` and fresh uploads). */
export type PreviewArtUrls = Partial<Record<'background' | 'backgroundPoster' | 'title' | 'overlay', string | null>>;

/** One prize item of the form as the app reads it (`EventPrizeItem`), names from the event options. */
export function previewItem(i: PrizeItemForm, options: EventOptions, lang: 'ar' | 'en'): Record<string, unknown> {
  const name = (o?: { nameAr: string; nameEn: string }) => (o ? (lang === 'ar' ? o.nameAr : o.nameEn) : null);
  const int = (v: string | undefined) => Number.parseInt(v ?? '0', 10) || 0;
  const days = i.permanent ? null : int(i.value);
  const display = i.displayUrl ? { displayUrl: i.displayUrl } : {};
  switch (i.type) {
    case 'COINS':
    case 'CHERRIES':
      return { type: i.type, amount: int(i.value), ...display };
    case 'CP_MONEY':
      return { type: i.type, cherries: int(i.cherries), coins: int(i.coins), ...display };
    case 'BAG_ITEM': {
      const b = options.bagItems.find((x) => x.code === i.code);
      return { type: i.type, code: i.code, name: name(b), category: b?.category ?? null, days, stillUrl: b?.stillUrl ?? null, ...display };
    }
    case 'VIP': {
      const v = options.vipTiers.find((x) => x.code === i.code);
      return { type: i.type, code: i.code, name: name(v), category: 'VIP', days: int(i.value), ...display };
    }
    case 'BADGE': {
      const b = options.badges?.find((x) => x.code === i.code);
      const level = int(i.level ?? '1') || 1;
      return {
        type: i.type,
        code: i.code,
        name: name(b),
        category: 'BADGE',
        level,
        days,
        imageUrl: b?.levels.find((l) => l.level === level)?.imageUrl ?? null,
        ...display,
      };
    }
    case 'GIFT_PIECES': {
      const g = options.gifts.find((x) => x.code === i.code);
      return { type: i.type, amount: int(i.value), code: i.code, name: name(g), category: 'GIFT', assetKey: i.code, imageUrl: g?.imageUrl ?? null, ...display };
    }
  }
}

/**
 * The draft as the app's `EventDetail` (what `GET /events/{id}` would answer once saved) for the preview: the form's
 * titles, rules, gifts, boards, prize lines, milestones and art, and the design (`null` = today's page). The dates
 * and status come from the preview's state switch, not from here.
 */
export function previewEvent(
  f: GiftEventFormState,
  options: EventOptions,
  urls: PreviewArtUrls,
  lang: 'ar' | 'en',
  eventId?: string,
): Record<string, unknown> {
  const ar = lang === 'ar';
  const pick2 = (a: string, b: string) => (ar ? a || b : b || a).trim();
  const video = /\.(mp4|mov)$/.test(f.backgroundKey ?? '');
  const overlay = urls.overlay ?? null;
  const items = (list: PrizeItemForm[]) => list.map((i) => previewItem(i, options, lang));
  const design = f.design ? { ...designBody(f.design), leaderboardBackgroundUrl: f.design.backgroundUrl } : null;
  return {
    id: eventId ?? 'preview',
    title: pick2(f.titleAr, f.titleEn) || '—',
    rules: pick2(f.rulesAr, f.rulesEn),
    metric: 'EVENT_GIFTS',
    audience: f.audience === 'HOSTS' ? 'HOSTS' : 'EVERYONE',
    permanent: f.permanent,
    featured: f.featured,
    timeZone: f.timeZone,
    bannerUrl: null,
    art: {
      background: urls.background
        ? {
            kind: video ? 'VIDEO' : /\.(gif|anim\.webp)$/.test(f.backgroundKey ?? '') ? 'ANIMATED' : 'IMAGE',
            url: urls.background,
            posterUrl: video ? (urls.backgroundPoster ?? null) : null,
          }
        : null,
      titleUrl: urls.title ?? null,
      overlay: overlay ? { url: overlay, format: /\.json$/.test(f.overlayKey ?? '') ? 'LOTTIE' : 'SVGA' } : null,
    },
    gifts: f.gifts
      .filter((g) => g.giftCode)
      .map((g) => {
        const o = options.gifts.find((x) => x.code === g.giftCode);
        const perCoin = Number(g.pointsPerCoin) || 0;
        const perGift = Number.parseInt(g.pointsPerGift, 10) || 0;
        const price = o?.priceCoins ?? 0;
        return {
          code: g.giftCode,
          name: o ? (ar ? o.nameAr : o.nameEn) : g.giftCode,
          priceCoins: price,
          assetKey: g.giftCode,
          imageUrl: o?.imageUrl ?? null,
          pointsPerCoin: perCoin,
          pointsPerGift: perGift,
          pointsEach: Math.round(price * perCoin + perGift),
        };
      }),
    boards: f.boards.map((b) => ({
      kind: b.kind,
      minPoints: Number.parseInt(b.minPoints, 10) || 0,
      shown: boardPlaces(b),
      prizes: b.prizes.map((l) => ({
        rankFrom: Number.parseInt(l.rankFrom, 10) || 0,
        rankTo: Number.parseInt(l.rankTo, 10) || 0,
        items: items(l.items),
      })),
    })),
    milestones: f.milestones.map((m) => ({ board: m.board, points: Number.parseInt(m.points, 10) || 0, prize: items(m.items) })),
    prizes: [],
    paidAt: null,
    payoutDueAt: null,
    design,
  };
}

let seq = 0;

/** The render message (JSON text, the preview's protocol v1). */
export function previewMessage(event: Record<string, unknown>, s: PreviewSettings): string {
  seq += 1;
  return JSON.stringify({
    type: PREVIEW_RENDER,
    v: 1,
    seq,
    language: s.language,
    theme: s.theme,
    state: s.state,
    reduceMotion: s.reduceMotion,
    event,
  });
}

export type PreviewReply =
  | { type: typeof PREVIEW_READY }
  | { type: typeof PREVIEW_RENDERED; seq: number; designed: boolean }
  | { type: typeof PREVIEW_ERROR; seq?: number; reason: string };

/** A reply from the preview — only from its own window and origin (anything else is not ours). */
export function previewReply(
  e: { data: unknown; origin: string; source: unknown },
  expected: { origin: string; window: unknown },
): PreviewReply | null {
  if (e.source !== expected.window || e.source === null || e.origin !== expected.origin) return null;
  if (typeof e.data !== 'string') return null;
  try {
    const m = JSON.parse(e.data) as Record<string, unknown>;
    if (m.v !== 1) return null;
    if (m.type === PREVIEW_READY) return { type: PREVIEW_READY };
    if (m.type === PREVIEW_RENDERED && typeof m.seq === 'number') {
      return { type: PREVIEW_RENDERED, seq: m.seq, designed: m.designed === true };
    }
    if (m.type === PREVIEW_ERROR) {
      return { type: PREVIEW_ERROR, ...(typeof m.seq === 'number' ? { seq: m.seq } : {}), reason: String(m.reason ?? '') };
    }
  } catch {
    return null;
  }
  return null;
}

/** Where the preview bundle is: /event-preview/ on the panel's origin (VITE_EVENT_PREVIEW_URL in development). */
export function previewUrl(env: string | undefined, origin: string): URL {
  return new URL(env && env.trim() ? env : '/event-preview/', origin);
}

// ---- contrast «قد يصعب قراءة النص» ------------------------------------------------------------------------------

type Rgba = [number, number, number, number];
const hex = (argb: number): Rgba => [(argb >>> 16) & 255, (argb >>> 8) & 255, argb & 255, ((argb >>> 24) & 255) / 255];

/**
 * The presets' cards as the app draws them (apps/mobile event_page_theme.dart `EventPageTheme.*` and the CLASSIC card
 * of event_designed_page.dart): the card fill's gradient stops and the card's text colour. The check uses the most
 * transparent stop (the worst place).
 */
export const PRESET_CARDS: Record<DesignPreset, { fill: number[]; text: number }> = {
  CLASSIC: { fill: [0xe6400810, 0xe61e0307], text: 0xffffffff },
  LUXURY_GOLD: { fill: [0xeb5a0a10, 0xf22a0508], text: 0xffffffff },
  GLASS: { fill: [0x66202026, 0x8c0b0b0d], text: 0xffffffff },
  DARK_MINIMAL: { fill: [0xf216161a, 0xf216161a], text: 0xffffffff },
  NEON: { fill: [0xe60b0b0d, 0xe60b0b0d], text: 0xffffffff },
  KABSO_RED: { fill: [0xf2b80710, 0xf28a050c], text: 0xffffffff },
};

/**
 * The leaderboard's dimming over an uploaded background (event_leaderboard_styles.dart `_BgPainter`): THRONE a
 * gradient whose middle is 20 % black (the rows' part), every other style 40 % black. The rows' names are white.
 */
export const BOARD_SCRIM: Record<DesignLeaderboard, number> = {
  THRONE: 0.2,
  PODIUM: 0.4,
  CARDS_ROW: 0.4,
  SPOTLIGHT: 0.4,
  SHIELD_CREST: 0.4,
};

/** The page's own backdrop where no art is uploaded (gift_event_sections.dart: #1A1208). */
export const PAGE_BACKDROP: [number, number, number] = [0x1a, 0x12, 0x08];

const channel = (c: number) => {
  const s = c / 255;
  return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
};
/** WCAG relative luminance of an sRGB colour. */
export function luminance([r, g, b]: readonly number[]): number {
  return 0.2126 * channel(r!) + 0.7152 * channel(g!) + 0.0722 * channel(b!);
}
/** WCAG contrast ratio of two luminances (1 … 21). */
export function contrastRatio(a: number, b: number): number {
  const [hi, lo] = a > b ? [a, b] : [b, a];
  return (hi + 0.05) / (lo + 0.05);
}
/** [over] (alpha) painted on [under] (opaque), in sRGB as the GPU blends. */
export function composite(over: readonly number[], alpha: number, under: readonly number[]): [number, number, number] {
  return [0, 1, 2].map((i) => over[i]! * alpha + under[i]! * (1 - alpha)) as [number, number, number];
}

/**
 * A picture's light parts: the colour at the 90th percentile of luminance of its pixels (RGBA bytes, e.g. a canvas's
 * `getImageData` of the picture drawn small). White text is hardest to read there; one bright pixel does not count.
 */
export function brightColour(rgba: ArrayLike<number>): [number, number, number] {
  const px: { l: number; c: [number, number, number] }[] = [];
  for (let i = 0; i + 3 < rgba.length; i += 4) {
    const a = rgba[i + 3]! / 255;
    // A transparent pixel shows the page's backdrop.
    const c = composite([rgba[i]!, rgba[i + 1]!, rgba[i + 2]!], a, PAGE_BACKDROP);
    px.push({ l: luminance(c), c });
  }
  if (px.length === 0) return PAGE_BACKDROP;
  px.sort((x, y) => x.l - y.l);
  return px[Math.min(px.length - 1, Math.floor(px.length * 0.9))]!.c;
}

/** One readability check below 4.5 : 1 (WCAG AA for normal text). */
export interface ContrastWarning {
  where: 'cards' | 'board';
  ratio: number;
}

export const CONTRAST_MIN = 4.5;

/**
 * «قد يصعب قراءة النص»: the cards' text over the preset's fill on the page background, and the rows' names over the
 * uploaded leaderboard background under its scrim. A background not measured (none, or not readable) is not judged
 * (the page's own dark backdrop for the cards). Never blocks saving.
 */
export function contrastWarnings(
  preset: DesignPreset,
  leaderboard: DesignLeaderboard,
  page: [number, number, number] | null,
  board: [number, number, number] | null,
): ContrastWarning[] {
  const out: ContrastWarning[] = [];
  const card = PRESET_CARDS[preset];
  const under = page ?? PAGE_BACKDROP;
  const worst = Math.min(
    ...card.fill.map((f) => {
      const [r, g, b, a] = hex(f);
      return contrastRatio(luminance(hex(card.text)), luminance(composite([r, g, b], a, under)));
    }),
  );
  if (worst < CONTRAST_MIN) out.push({ where: 'cards', ratio: worst });
  if (board) {
    const behind = composite([0, 0, 0], BOARD_SCRIM[leaderboard], board);
    const ratio = contrastRatio(1, luminance(behind));
    if (ratio < CONTRAST_MIN) out.push({ where: 'board', ratio });
  }
  return out;
}

/** The section's label key, for the list. */
export const SECTION_KEY = (id: DesignSection) => `dsgSection_${id}` as const;

/** For the featured picker: a board's covering line items as `PrizeItemInput`s (what `prizeText` words). */
export function lineItems(b: BoardForm, t: TierForm): Record<string, unknown>[] {
  const line = coveringLine(b, Number(t.from), Number(t.to));
  return line ? line.items.map(prizeItemBody) : [];
}
