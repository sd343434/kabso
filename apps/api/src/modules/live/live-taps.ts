/**
 * CP-012 (D95, CONVENTIONS §10.10): the counting rules of live taps, as pure functions.
 *
 * Per caller and room: a batch adds at most `10 × seconds since the caller's last counted batch`
 * (whole and part seconds, millisecond precision), at most 10 for the caller's first batch in the
 * room, never more than the batch's `count`, and the caller's counted taps in the room never go
 * above 10 000. The host's own taps count 0. Taps past a limit are dropped (not an error).
 */

/** Taps a caller may add per second. */
export const TAPS_PER_SECOND = 10;
/** A caller's counted taps in one room never exceed this. */
export const MAX_TAPS_PER_ROOM = 10_000;
/** Points per counted tap. */
export const POINTS_PER_TAP = 1;
/** CP-014 (§10.12): the Contribution list shows at most this many people. */
export const LIVE_CONTRIBUTORS_MAX = 50;
/** Points per support coin: the coin value of a gift (v1.23-live, CP-020, §10.23). */
export const POINTS_PER_SUPPORT_COIN = 100;

/** What the caller has already counted in the room (null: never counted there). */
export interface TapperState {
  readonly counted: number;
  readonly lastBatchAt: Date;
}

export interface TapBatch {
  /** Taps in the batch (1–50, validated by the request schema). */
  readonly count: number;
  /** The caller hosts the room: their taps count 0. */
  readonly isHost: boolean;
  readonly tapper: TapperState | null;
  readonly now: Date;
}

/**
 * The taps of a batch the server counts. A clock that went backwards (another instance's clock)
 * counts as no time passed.
 */
export function acceptedTaps(batch: TapBatch): number {
  if (batch.isHost) return 0;
  const count = Math.max(0, Math.floor(batch.count));
  let allowance: number;
  let counted = 0;
  if (batch.tapper === null) {
    allowance = TAPS_PER_SECOND;
  } else {
    counted = batch.tapper.counted;
    const elapsedMs = Math.max(0, batch.now.getTime() - batch.tapper.lastBatchAt.getTime());
    allowance = Math.floor((elapsedMs * TAPS_PER_SECOND) / 1000);
  }
  const left = Math.max(0, MAX_TAPS_PER_ROOM - counted);
  return Math.min(count, allowance, left);
}

/** CP-016 D (D101, §10.18): counted taps of one viewer in one live per charm point of the host. */
export const TAPS_PER_CHARM_POINT = 10;

/**
 * The host's charm points from a batch: one for every multiple of {@link TAPS_PER_CHARM_POINT}
 * the viewer's counted taps in the room cross (from `countedBefore` to `countedBefore +
 * accepted`). The owner's limit (D101) is the 10 000 counted taps a live ({@link
 * MAX_TAPS_PER_ROOM}), so a viewer gives a host at most 1 000 charm points per live.
 */
export function charmPointsFor(countedBefore: number, accepted: number): number {
  if (accepted <= 0) return 0;
  return (
    Math.floor((countedBefore + accepted) / TAPS_PER_CHARM_POINT) -
    Math.floor(countedBefore / TAPS_PER_CHARM_POINT)
  );
}
