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
  /** A user's balances, read-only (owner 2026-10-31: the moderator «مشرف» sees them too). */
  'users.balances': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** The recent coin and cherry ledger rows of a user. */
  'users.ledger': ['OWNER', 'SUPPORT', 'FINANCE'],
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
  /** v1.64-social (D196): the Stripe keys and top-up options «الدفع (Stripe)». */
  'payments.settings': ['OWNER'],
  // ---- v1.65-social (D197, CONVENTIONS §10.60): the panel v2 sections ---------------------------------------
  /** The users table and its CSV export (audited), a user's content tab. */
  'users.list': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** Owner answer CP-039 Q2: the users table (with emails) as CSV is OWNER only. */
  'users.export': ['OWNER'],
  /** A user's app sessions (devices) and signing them out. */
  'users.sessions': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** Host agencies: the list, an agency's page and the complaints queue. */
  'agencies.view': ['OWNER', 'SUPPORT', 'FINANCE'],
  /** Create, suspend / reinstate, resolve a complaint, run the rank evaluation. */
  'agencies.manage': ['OWNER', 'SUPPORT'],
  /** v1.70-social (D206): a self-opened agency's application (private fields + pictures, every view audited). */
  'agencies.applications': ['OWNER', 'SUPPORT'],
  /** v1.70-social (D206): extend a probation, close or reopen an agency (with the authenticator code again). */
  'agencies.probation': ['OWNER'],
  /** Lives now, a live's details, the hosting permissions. */
  'lives.view': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** End a live with a reason; give / take back the hosting permission. */
  'lives.manage': ['OWNER', 'MODERATION'],
  /** The gift catalogue, bag items, banners and events (read). */
  'catalog.view': ['OWNER', 'SUPPORT', 'FINANCE'],
  /** Gift CRUD, banners, events. */
  'catalog.manage': ['OWNER'],
  /** Give / take back a bag item (frames, profile cards) to a user. */
  'items.grant': ['OWNER', 'SUPPORT'],
  /** Agent top-ups history, card orders, Stripe cases; the financial reports and their CSV. */
  'finance.view': ['OWNER', 'FINANCE'],
  /** A team refund of a card order (TOTP), closing a Stripe case. */
  'finance.refund': ['OWNER', 'FINANCE'],
  /** The audit log viewer (and a user's «السجل» tab). */
  'audit.view': ['OWNER'],
  /** The team: list, grant / revoke panel roles, reset an authenticator (TOTP + reason). */
  'team.manage': ['OWNER'],
  /** Tasks and levels (read, with USD values), special usernames list. */
  'programs.view': ['OWNER', 'SUPPORT', 'FINANCE'],
  /** The website's waitlist (personal data; every read audited). */
  'waitlist.view': ['OWNER'],
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
