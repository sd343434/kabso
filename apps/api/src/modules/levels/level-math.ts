/** Level resolution and progress (CP-005 §4, brief §9). Pure; levels sorted by levelNumber. */

export interface LevelRow {
  readonly levelNumber: number;
  readonly requiredPoints: bigint;
}

export interface LevelProgress<L extends LevelRow> {
  readonly current: L | null;
  readonly next: L | null;
  readonly pointsToNext: bigint | null;
  /** 0–100 with one decimal, floored; 100 at the top level. */
  readonly progressPercent: number;
  readonly maxLevel: boolean;
}

/** The highest level whose threshold is ≤ points (null when below every threshold). */
export function levelFor<L extends LevelRow>(levels: readonly L[], points: bigint): L | null {
  let found: L | null = null;
  for (const level of levels) {
    if (level.requiredPoints <= points) found = level;
    else break;
  }
  return found;
}

/**
 * v1.46-levels (owner D169, §10.43): levels never go down — the higher of the level kept so far
 * and the level the points reach (null = none yet).
 */
export function keptLevel(kept: number | null, reached: number | null): number | null {
  if (kept === null) return reached;
  if (reached === null) return kept;
  return Math.max(kept, reached);
}

/**
 * Progress for `points`. `floorLevel` is a level number the user keeps although their points no
 * longer reach it (reversal policy KEEP_LEVEL); progress then counts from that level's threshold
 * and is 0 while the points are below it.
 */
export function progressFor<L extends LevelRow>(
  levels: readonly L[],
  points: bigint,
  floorLevel: number | null = null,
): LevelProgress<L> {
  let current = levelFor(levels, points);
  if (floorLevel !== null && (current === null || current.levelNumber < floorLevel)) {
    current = levels.find((l) => l.levelNumber === floorLevel) ?? current;
  }
  const index = current === null ? -1 : levels.indexOf(current);
  const next = levels[index + 1] ?? null;
  if (next === null) {
    return {
      current,
      next: null,
      pointsToNext: null,
      progressPercent: current ? 100 : 0,
      maxLevel: current !== null,
    };
  }
  const base = current?.requiredPoints ?? 0n;
  const span = next.requiredPoints - base;
  const done = points - base;
  const permille = done <= 0n || span <= 0n ? 0n : (done * 1000n) / span;
  return {
    current,
    next,
    pointsToNext: next.requiredPoints - points > 0n ? next.requiredPoints - points : 0n,
    progressPercent: Number(permille > 1000n ? 1000n : permille) / 10,
    maxLevel: false,
  };
}

/**
 * D194 (§10.57): a ladder change keeps every level (owner D169) — `carried` level points are
 * credited so that `total + carried` sits at the kept level's threshold on the NEW ladder, plus the
 * points the user had already made inside that level (`total + oldCarry` above its old
 * threshold), capped one below the new step so the carry never lifts anyone a level. Progress then
 * follows the new ladder from there. Whoever already reaches the level on the new ladder carries
 * nothing. `kept` = the stored level (null = none yet).
 */
export function carryAtSwitch(input: {
  readonly oldLevels: readonly LevelRow[];
  readonly newLevels: readonly LevelRow[];
  readonly total: bigint;
  readonly oldCarry: bigint;
  readonly kept: number | null;
}): { readonly level: number | null; readonly carried: bigint } {
  const reached = levelFor(input.newLevels, input.total)?.levelNumber ?? null;
  const level = keptLevel(input.kept, reached);
  const at = input.newLevels.findIndex((l) => l.levelNumber === level);
  const here = input.newLevels[at];
  // Nothing to carry for whoever already stands at the level on the new ladder.
  if (level === null || !here || input.total >= here.requiredPoints) return { level, carried: 0n };
  const next = input.newLevels[at + 1];
  const old = input.oldLevels.find((l) => l.levelNumber === level);
  let inside = 0n;
  if (old && next) {
    inside = input.total + input.oldCarry - old.requiredPoints;
    const cap = next.requiredPoints - here.requiredPoints - 1n;
    inside = inside < 0n ? 0n : inside > cap ? cap : inside;
  }
  const carried = here.requiredPoints + inside - input.total;
  return { level, carried: carried > 0n ? carried : 0n };
}

/**
 * D194: a fraud deduction takes the same share of the carried points as of the real ones
 * (`carried × after / before`, floored), so a deduction of everything leaves nothing carried.
 */
export function carryAfterFraud(carried: bigint, before: bigint, after: bigint): bigint {
  if (carried <= 0n || before <= 0n || after <= 0n) return 0n;
  return after >= before ? carried : (carried * after) / before;
}
