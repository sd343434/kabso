import type { AdminPermission } from '../../generated/prisma/client.js';

/**
 * The admin panel's roles and what each may do (v1.60-social, D191, owner 2026-10-31, CONVENTIONS §10.54.1). The
 * roles are values of the existing `admin_permission` (granular permissions, CP-005 §9.8) held by a user whose
 * `users.role` is ADMIN: OWNER, MODERATION (the panel's moderator «مشرف»), SUPPORT «دعم», FINANCE «مالية». They are
 * granted only with `admin-admin grant` (audited). Every panel route names one capability and the server checks it on
 * every request (a demotion applies at once); the panel only hides what the session's capabilities do not include.
 */
export const PANEL_ROLES = [
  'OWNER',
  'MODERATION',
  'SUPPORT',
  'FINANCE',
] as const satisfies readonly AdminPermission[];
export type PanelRole = (typeof PANEL_ROLES)[number];

export const CAPABILITIES = {
  'dashboard.view': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  'users.view': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** Balances and the recent coin and cherry ledger of a user. */
  'users.balances': ['OWNER', 'SUPPORT', 'FINANCE'],
  'users.ban': ['OWNER', 'MODERATION'],
  'users.avatar': ['OWNER', 'MODERATION'],
  'users.special_username': ['OWNER', 'SUPPORT'],
  /** Applications with their private fields and pictures (each view audited, D185). */
  'recharge.applications': ['OWNER', 'SUPPORT'],
  'recharge.decide': ['OWNER', 'SUPPORT'],
  'recharge.agents': ['OWNER', 'SUPPORT', 'FINANCE'],
  'recharge.topup': ['OWNER', 'FINANCE'],
  'recharge.status': ['OWNER', 'SUPPORT'],
  'recharge.cap': ['OWNER', 'FINANCE'],
  'withdrawals.view': ['OWNER', 'FINANCE'],
  'withdrawals.decide': ['OWNER', 'FINANCE'],
  'reports.view': ['OWNER', 'MODERATION'],
  'reports.act': ['OWNER', 'MODERATION'],
  'site.settings': ['OWNER'],
} as const satisfies Record<string, readonly PanelRole[]>;

export type Capability = keyof typeof CAPABILITIES;

export function isPanelRole(p: string): p is PanelRole {
  return (PANEL_ROLES as readonly string[]).includes(p);
}

/** The capabilities of a set of roles, in the table's order. */
export function capabilitiesOf(roles: readonly string[]): Capability[] {
  return (Object.keys(CAPABILITIES) as Capability[]).filter((cap) =>
    (CAPABILITIES[cap] as readonly string[]).some((r) => roles.includes(r)),
  );
}

export function can(roles: readonly string[], cap: Capability): boolean {
  return (CAPABILITIES[cap] as readonly string[]).some((r) => roles.includes(r));
}
