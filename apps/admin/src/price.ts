/**
 * The owner's wholesale price of a top-up, as the API computes it (recharge-rules `topUpPrice`): the highest tier
 * whose minimum the coins reach; coins × price / 1 000 000 rounded half up to a cent. Shown before the admin
 * confirms; the server decides.
 */
export interface PriceTier {
  readonly minCoins: number;
  readonly minorPerMillion: number;
}

export function tierFor(coins: bigint, tiers: readonly PriceTier[]): PriceTier | null {
  if (coins <= 0n || tiers.length === 0) return null;
  let chosen = tiers[0]!;
  for (const t of tiers) if (coins >= BigInt(t.minCoins)) chosen = t;
  return chosen;
}

export function expectedMinor(coins: bigint, tier: PriceTier): bigint {
  return (coins * BigInt(tier.minorPerMillion) + 500_000n) / 1_000_000n;
}

/** "360" / "360.5" / "360.00" → minor units, or null (as the API's parseMoneyMinor). */
export function parseUsd(raw: string): bigint | null {
  const m = /^([0-9]{1,10})(?:\.([0-9]{1,2}))?$/.exec(raw.trim());
  if (!m) return null;
  return BigInt(m[1]!) * 100n + BigInt((m[2] ?? '').padEnd(2, '0'));
}

export function minorToUsd(minor: bigint): string {
  const cents = minor % 100n;
  return `${(minor / 100n).toString()}.${cents.toString().padStart(2, '0')}`;
}
