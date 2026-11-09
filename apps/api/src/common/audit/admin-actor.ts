/**
 * Who runs a shared admin rule (v1.60-social, D191, CONVENTIONS §10.54.4): the command line (`via: 'cli'`, no
 * actor) or the admin panel (`via: 'panel'`, the signed-in admin with the request's IP). The rules in
 * `recharge-core`, `withdrawal-admin`, `avatar-admin` and `special-usernames` write their audit rows with it, so a
 * CLI change and a panel change are the same code and leave the same row, told apart only by `via` and the actor.
 */
export interface AdminVia {
  /** v1.68-live (D273): `app` — a staff member's tools in the app after the step-up (§10.96.6). */
  readonly via: 'cli' | 'panel' | 'app' | 'system';
  readonly actorUserId: string | null;
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

/** v1.110-social (D345): the server itself (a store refund's automatic ban): no actor. */
export const SYSTEM_VIA: AdminVia = { via: 'system', actorUserId: null };

/** The command line: no actor (the operator is on the server). */
export const CLI_VIA: AdminVia = { via: 'cli', actorUserId: null };

/** The audit row's actor, IP and request id for {@link AdminVia}. */
export function auditBy(by: AdminVia): {
  actorUserId: string | null;
  ip: string | null;
  requestId: string | null;
} {
  return { actorUserId: by.actorUserId, ip: by.ip?.slice(0, 64) ?? null, requestId: by.requestId ?? null };
}
