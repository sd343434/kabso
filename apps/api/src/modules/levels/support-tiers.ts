import { SUPPORT_FRAME_COUNT, supportFrameCode } from '../bag/bag.catalogue.js';

/**
 * The support level's badge tiers (owner D169, 2026-10-30; the app's `KLevelArt.supportTier`
 * draws the same): 21 tiers over the 100-level ladder — tiers 1–20 are levels 1–5, 6–10 … 91–95,
 * 96–99 and tier 21 is level 100 alone. A default the owner may change.
 */
export const SUPPORT_TIERS = 21;

/** The support tier (1–21) of `level` (≥ 1). */
export function supportTier(level: number): number {
  if (level >= 100) return SUPPORT_TIERS;
  return Math.floor((Math.min(Math.max(level, 1), 99) - 1) / 5) + 1;
}

/**
 * The avatar frames a user at support `level` has earned: the frame of every tier reached so far
 * (frame n for tier n, tiers 1–21; owner 2026-10-30: tier 21 has its own frame). Null or 0 =
 * none.
 */
export function supportFramesFor(level: number | null): string[] {
  if (level === null || level < 1) return [];
  const last = Math.min(supportTier(level), SUPPORT_FRAME_COUNT);
  return Array.from({ length: last }, (_, i) => supportFrameCode(i + 1));
}

/**
 * The support frames a fraud demotion from `from` to `to` takes back (owner D169: the only way a
 * frame is removed): the frames of the tiers above the new level's tier. Other categories: none.
 */
export function lostSupportFrames(category: string, from: number | null, to: number | null): string[] {
  if (category !== 'SUPPORT') return [];
  const kept = new Set(supportFramesFor(to));
  return supportFramesFor(from).filter((code) => !kept.has(code));
}
