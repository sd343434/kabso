/**
 * Exact points arithmetic (CP-005 §3). No floating point: multipliers are scaled integers with
 * 6 decimals, points and source values are bigint.
 */

export const MULTIPLIER_DECIMALS = 6;
const SCALE = 1_000_000n;
/** PostgreSQL BIGINT. */
export const MAX_POINTS = 9_223_372_036_854_775_807n;
export const MAX_MULTIPLIER = 1_000_000n * SCALE;

const MULTIPLIER_PATTERN = /^(0|[1-9][0-9]{0,6})(?:\.([0-9]{1,6}))?$/;
const POINTS_PATTERN = /^-?(0|[1-9][0-9]{0,18})$/;

/** A multiplier text ("1", "0.5") as an integer scaled by 10^6, or null when invalid or ≤ 0. */
export function parseMultiplier(text: string): bigint | null {
  const match = MULTIPLIER_PATTERN.exec(text);
  if (!match) return null;
  const whole = BigInt(match[1] ?? '0');
  const fraction = BigInt((match[2] ?? '').padEnd(MULTIPLIER_DECIMALS, '0'));
  const scaled = whole * SCALE + fraction;
  return scaled > 0n && scaled <= MAX_MULTIPLIER ? scaled : null;
}

/** The canonical text of a scaled multiplier: no trailing zeros ("1", "0.5", "2.125"). */
export function formatMultiplier(scaled: bigint): string {
  const whole = scaled / SCALE;
  const fraction = (scaled % SCALE).toString().padStart(MULTIPLIER_DECIMALS, '0').replace(/0+$/, '');
  return fraction === '' ? whole.toString() : `${whole.toString()}.${fraction}`;
}

/** `floor(sourceValue × multiplier)`; throws RangeError when it does not fit a BIGINT. */
export function pointsFor(sourceValue: bigint, scaledMultiplier: bigint): bigint {
  if (sourceValue < 0n) throw new RangeError('negative source value');
  if (scaledMultiplier <= 0n) throw new RangeError('non-positive multiplier');
  const points = (sourceValue * scaledMultiplier) / SCALE;
  if (points > MAX_POINTS) throw new RangeError('points overflow');
  return points;
}

/** A points amount as text ("12", "-3"), or null when malformed or outside BIGINT. */
export function parsePoints(text: string): bigint | null {
  if (!POINTS_PATTERN.test(text)) return null;
  const value = BigInt(text);
  return value <= MAX_POINTS && value >= -MAX_POINTS ? value : null;
}

/** `a + b`, throwing RangeError when the result leaves BIGINT. */
export function addPoints(a: bigint, b: bigint): bigint {
  const sum = a + b;
  if (sum > MAX_POINTS || sum < -MAX_POINTS) throw new RangeError('points overflow');
  return sum;
}
