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
