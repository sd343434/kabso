/**
 * v1.115-social (D354, owner «اجعل كل الخيارات متاحة», CONVENTIONS §10.150): the event page designer — how a gift
 * event's page looks in the app, chosen per event by the team (`GiftEventForm.design`, `EventDetail.design`). Version 1:
 * the page layout, the leaderboard style, the countdown, the card preset, the rules button, the sections (order and
 * visibility), the leaderboard background (an `EVENT_BOARD_BG` asset), the rewards tab's rank tiers and the motion.
 *
 * Null (every event made before D354, and any event the team does not design) = today's page. Older apps ignore the
 * field. The rules here are pure (the body alone); the service adds the stored «عدد المعروضين» and the asset.
 *
 * The rewards tiers carry NO prize data: a tier is a rank range of one board plus which of that board's prize items
 * are «featured»; the prizes themselves are the board's prize line covering the range (`event_boards.prizes`), so the
 * prize table is written once (§10.150.4).
 */
import { z } from 'zod';

/** The board kinds (as `EVENT_BOARD_KINDS` in `gift-events.ts`; kept here so this module has no import cycle). */
export const DESIGN_BOARD_KINDS = ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'] as const;
type BoardKind = (typeof DESIGN_BOARD_KINDS)[number];

export const EVENT_DESIGN_VERSION = 1;
export const DESIGN_LAYOUTS = ['HERO_PODIUM', 'STAGE', 'DECK'] as const;
export const DESIGN_LEADERBOARDS = ['THRONE', 'PODIUM', 'CARDS_ROW', 'SPOTLIGHT', 'SHIELD_CREST'] as const;
/** CLASSIC = today's simple pill; the other five are the large hero countdowns. */
export const DESIGN_COUNTDOWNS = ['CLASSIC', 'FLIP', 'RING', 'COINS', 'NEON', 'RIBBON'] as const;
/** CLASSIC = today's cards; the other five are the card presets. */
export const DESIGN_PRESETS = [
  'CLASSIC',
  'LUXURY_GOLD',
  'GLASS',
  'DARK_MINIMAL',
  'NEON',
  'KABSO_RED',
] as const;
export const DESIGN_RULES_BUTTONS = [
  'EDGE_RIBBON',
  'ROUND_ICON',
  'GOLD_PILL',
  'GLASS_CHIP',
  'SIDE_TAB',
  'APP_BAR_LINK',
] as const;
export const DESIGN_EDGES = ['START', 'END'] as const;
export const DESIGN_SECTIONS = ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'] as const;
export const DESIGN_ENTRANCES = ['FADE', 'SLIDE', 'SCALE', 'NONE'] as const;
export type DesignSectionId = (typeof DESIGN_SECTIONS)[number];

export const DESIGN_LIMITS = {
  /** Tiers over all boards. */
  tiers: 40,
  /** Featured items per tier. */
  featured: 3,
  labelLength: 24,
  entranceMaxMs: 1500,
} as const;

/** A board's places when nothing smaller is known (`EVENT_BOARD_SHOWN_MAX`). */
const SHOWN_MAX = 100;

const DEFAULT_SECTIONS = DESIGN_SECTIONS.map((id) => ({ id, visible: true }));

const motionSchema = z.strictObject({
  entrance: z.enum(DESIGN_ENTRANCES).default('FADE'),
  /** The entrance's length (0 = instant; reduce-motion always instant). */
  durationMs: z.number().int().min(0).max(DESIGN_LIMITS.entranceMaxMs).default(450),
  /** The light sweep over frames and plates. */
  shimmer: z.boolean().default(true),
  /** The gentle pulse of the first place. */
  pulseFirst: z.boolean().default(true),
  /** The event overlay's playback speed and opacity. */
  overlaySpeed: z.number().min(0.25).max(2).default(1),
  overlayOpacity: z.number().min(0).max(1).default(1),
});

const tierSchema = z.strictObject({
  board: z.enum(DESIGN_BOARD_KINDS),
  from: z.number().int().min(1).max(SHOWN_MAX),
  to: z.number().int().min(1).max(SHOWN_MAX),
  labelAr: z.string().trim().min(1).max(DESIGN_LIMITS.labelLength).nullable().optional(),
  labelEn: z.string().trim().min(1).max(DESIGN_LIMITS.labelLength).nullable().optional(),
  /** Indexes into the items of the board's prize line covering the tier (0-based), shown large. */
  featured: z.array(z.number().int().min(0).max(5)).max(DESIGN_LIMITS.featured).default([]),
});

/** `EventPageDesign` (input; the response adds `leaderboardBackgroundUrl`). */
export const eventDesignSchema = z.strictObject({
  v: z.literal(EVENT_DESIGN_VERSION),
  layout: z.enum(DESIGN_LAYOUTS),
  leaderboard: z.enum(DESIGN_LEADERBOARDS).default('THRONE'),
  countdown: z.enum(DESIGN_COUNTDOWNS).default('CLASSIC'),
  preset: z.enum(DESIGN_PRESETS).default('CLASSIC'),
  rulesButton: z
    .strictObject({ style: z.enum(DESIGN_RULES_BUTTONS), edge: z.enum(DESIGN_EDGES).default('END') })
    .nullable()
    .default(null),
  sections: z
    .array(z.strictObject({ id: z.enum(DESIGN_SECTIONS), visible: z.boolean() }))
    .length(DESIGN_SECTIONS.length)
    .default(DEFAULT_SECTIONS),
  leaderboardBackgroundMediaId: z.uuid().nullable().default(null),
  rewards: z
    .strictObject({ tiers: z.array(tierSchema).min(1).max(DESIGN_LIMITS.tiers) })
    .nullable()
    .default(null),
  motion: motionSchema.default(() => motionSchema.parse({})),
});
export type EventDesign = z.infer<typeof eventDesignSchema>;

/** What the design rules need of a board: its kind, its prize ranges (with their item counts) and its places. */
export interface DesignBoard {
  readonly kind: BoardKind;
  readonly lines: readonly { readonly rankFrom: number; readonly rankTo: number; readonly items: number }[];
  /** «عدد المعروضين»; null when the body leaves it to the stored value (then the service checks it). */
  readonly shown: number | null;
}

export interface DesignProblem {
  readonly field: string;
  readonly issue: string;
  readonly message: string;
}

/**
 * The cross-field rules of a design against the event's boards (§10.150.3). Empty when fine:
 * - every section listed exactly once (`design_sections`);
 * - the rules reachable: RULES hidden only with a rules button (`design_rules_unreachable`);
 * - BOARDS visible when the event has boards (`design_boards_required`);
 * - tiers: a board of the event (`design_tier_board`), `from` ≤ `to`, within the board's places (`design_tier_range`),
 *   in order without overlap per board (`design_tier_overlap`), inside ONE prize line of that board
 *   (`design_tier_prize`), featured items of that line, each once (`design_tier_featured`).
 */
export function designProblems(design: EventDesign, boards: readonly DesignBoard[]): DesignProblem[] {
  const out: DesignProblem[] = [];
  const ids = design.sections.map((s) => s.id);
  if (new Set(ids).size !== DESIGN_SECTIONS.length) {
    out.push({
      field: 'design.sections',
      issue: 'design_sections',
      message: `List each section once: ${DESIGN_SECTIONS.join(', ')}.`,
    });
  }
  const visible = (id: DesignSectionId) => design.sections.find((s) => s.id === id)?.visible ?? true;
  if (!visible('RULES') && design.rulesButton === null) {
    out.push({
      field: 'design.rulesButton',
      issue: 'design_rules_unreachable',
      message: 'The rules section is hidden: add a rules button so the rules stay reachable.',
    });
  }
  if (!visible('BOARDS') && boards.length > 0) {
    out.push({
      field: 'design.sections',
      issue: 'design_boards_required',
      message: 'The event has boards: the boards section cannot be hidden.',
    });
  }
  const tiers = design.rewards?.tiers ?? [];
  const last = new Map<BoardKind, number>();
  tiers.forEach((t, i) => {
    const field = `design.rewards.tiers.${String(i)}`;
    const board = boards.find((b) => b.kind === t.board);
    if (!board) {
      out.push({
        field,
        issue: 'design_tier_board',
        message: `Tier ${String(i + 1)}: the event has no ${t.board} board.`,
      });
      return;
    }
    const places = board.shown ?? SHOWN_MAX;
    if (t.to < t.from || t.to > places) {
      out.push({
        field,
        issue: 'design_tier_range',
        message: `Tier ${String(i + 1)} (${String(t.from)}–${String(t.to)}): ranks 1–${String(places)}, the start first.`,
      });
      return;
    }
    if (t.from <= (last.get(t.board) ?? 0)) {
      out.push({
        field,
        issue: 'design_tier_overlap',
        message: `Tier ${String(i + 1)} (${String(t.from)}–${String(t.to)}) overlaps or is out of order on ${t.board}.`,
      });
    }
    last.set(t.board, Math.max(last.get(t.board) ?? 0, t.to));
    const line = board.lines.find((l) => t.from >= l.rankFrom && t.to <= l.rankTo);
    if (!line) {
      out.push({
        field,
        issue: 'design_tier_prize',
        message: `Tier ${String(i + 1)} (${String(t.from)}–${String(t.to)}) must lie inside one prize line of ${t.board}.`,
      });
      return;
    }
    if (new Set(t.featured).size !== t.featured.length || t.featured.some((f) => f >= line.items)) {
      out.push({
        field,
        issue: 'design_tier_featured',
        message: `Tier ${String(i + 1)}: a featured item is not one of the ${String(line.items)} prizes of its line, or is listed twice.`,
      });
    }
  });
  return out;
}

/** A stored design (`events.design`) or null when none or no longer valid (the app then shows today's page). */
export function parseStoredDesign(value: unknown): EventDesign | null {
  if (value === null || value === undefined) return null;
  const parsed = eventDesignSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}

/** The design as stored and audited (every default written out). */
export function designJson(design: EventDesign): EventDesign {
  return JSON.parse(JSON.stringify(design)) as EventDesign;
}

/** A short audit summary of a design (null when none). */
export function designAudit(design: EventDesign | null) {
  if (design === null) return null;
  return {
    v: design.v,
    layout: design.layout,
    leaderboard: design.leaderboard,
    countdown: design.countdown,
    preset: design.preset,
    rulesButton: design.rulesButton ? `${design.rulesButton.style}:${design.rulesButton.edge}` : null,
    sections: design.sections.map((s) => `${s.id}${s.visible ? '' : ':hidden'}`),
    leaderboardBackgroundMediaId: design.leaderboardBackgroundMediaId,
    tiers: (design.rewards?.tiers ?? []).map((t) => `${t.board}:${String(t.from)}-${String(t.to)}`),
    motion: design.motion,
  };
}

/** `EventOptions.designChoices` (v1.115-social): every choice and limit of a version-1 design, for the panel. */
export function designChoices() {
  return {
    v: EVENT_DESIGN_VERSION,
    layouts: [...DESIGN_LAYOUTS],
    leaderboards: [...DESIGN_LEADERBOARDS],
    countdowns: [...DESIGN_COUNTDOWNS],
    presets: [...DESIGN_PRESETS],
    rulesButtons: [...DESIGN_RULES_BUTTONS],
    edges: [...DESIGN_EDGES],
    sections: [...DESIGN_SECTIONS],
    entrances: [...DESIGN_ENTRANCES],
    limits: { ...DESIGN_LIMITS, entranceMinMs: 0, overlaySpeedMin: 0.25, overlaySpeedMax: 2 },
  };
}
