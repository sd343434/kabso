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
  /**
   * v1.75-live (D285, CONVENTIONS §10.96.13; owner: «دور جديد للاستقطاب فقط»): business development «تطوير الأعمال» —
   * recruits agencies, recharge agents, hosts and creators and sees only its own recruits and earnings
   * («استقطاباتي»). No moderation power at all: no live tools, no shift, no reports, no hidden watch.
   */
  'BD',
] as const satisfies readonly AdminPermission[];
export type PanelRole = (typeof PANEL_ROLES)[number];

export const CAPABILITIES = {
  'dashboard.view': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  'users.view': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** A user's balances, read-only (owner 2026-10-31: the moderator «مشرف» sees them too). */
  'users.balances': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** The recent coin and cherry ledger rows of a user (D275: the moderator «مشرف» reads them too, read-only). */
  'users.ledger': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  'users.ban': ['OWNER', 'MODERATION'],
  'users.avatar': ['OWNER', 'MODERATION'],
  'users.special_username': ['OWNER', 'SUPPORT'],
  /** Applications with their private fields and pictures (each view audited, D185). */
  'recharge.applications': ['OWNER', 'SUPPORT'],
  'recharge.decide': ['OWNER', 'SUPPORT'],
  /** The recharge agents list and the exchange rates (read). D275: MODERATION reads them too, with no action. */
  'recharge.agents': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /**
   * D275 (owner): the top-up records, read-only — the agents' top-ups «شحن الوكلاء» and the users' card top-ups (the
   * orders, not the Stripe cases). Split out of `finance.view` so the moderator «مشرف» sees the transactions without
   * the financial report or the cases. Owner «نعم»: the CSV of either list too (audited `admin.export.csv`).
   */
  'recharge.topups.view': ['OWNER', 'MODERATION', 'FINANCE'],
  /** Send coins to an agent (code again). Never MODERATION (D275). */
  'recharge.topup': ['OWNER', 'FINANCE'],
  'recharge.status': ['OWNER', 'SUPPORT'],
  'recharge.cap': ['OWNER', 'FINANCE'],
  'withdrawals.view': ['OWNER', 'FINANCE'],
  'withdrawals.decide': ['OWNER', 'FINANCE'],
  'reports.view': ['OWNER', 'MODERATION'],
  'reports.act': ['OWNER', 'MODERATION'],
  'site.settings': ['OWNER'],
  /**
   * v1.69-social (D204): «نزاعات الشحن» — read a disputed order with its chat and pictures (audited) and post as
   * «الإدارة»; the decision (coins to the buyer or back to the agent) needs `recharge.disputes.resolve` (the money
   * roles, like a top-up or a withdrawal) and the code. D275 (owner): the moderator «مشرف» views and decides
   * disputes too — the only coin movement a moderator can cause (no top-up, cap, status, rates or withdrawals).
   */
  'recharge.disputes': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  'recharge.disputes.resolve': ['OWNER', 'MODERATION', 'FINANCE'],
  /** v1.69-social (D204): the exchange rates per country «أسعار الصرف» (read by every recharge role). */
  'recharge.rates': ['OWNER', 'FINANCE'],
  /** v1.64-social (D196): the Stripe keys and top-up options «الدفع (Stripe)». */
  'payments.settings': ['OWNER'],
  /** v1.75-social (D222, §10.72): the media storage (R2 / S3) keys, buckets and switch «التخزين (R2 / S3)». */
  'storage.settings': ['OWNER'],
  /** v1.80-kyc (D227, §10.77): the Didit API key, webhook secret, workflows and switch «التحقق من الهوية (Didit)». */
  'kyc.settings': ['OWNER'],
  /** v1.81-social (D245, §10.87): the paid exchange-rate provider and its API key «مزوّد أسعار الصرف». */
  'fx.settings': ['OWNER'],
  /** v1.80-kyc (D227): a person's identity check (name, birth date, document country, duplicates; images via Didit). */
  'kyc.view': ['OWNER', 'SUPPORT'],
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
  /**
   * v1.73-social (D209, §10.68): the applications «كن مضيفاً مع الإدارة» — the list and an application's fields
   * (every view audited). MODERATION may look; the ID pictures and the decision are OWNER + SUPPORT (no
   * authenticator code again: it moves no money).
   */
  'hosts.applications': ['OWNER', 'SUPPORT', 'MODERATION'],
  'hosts.applications.photos': ['OWNER', 'SUPPORT'],
  'hosts.applications.decide': ['OWNER', 'SUPPORT'],
  /** Lives now, a live's details, the hosting permissions. */
  'lives.view': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** End a live with a reason; give / take back the hosting permission. */
  'lives.manage': ['OWNER', 'MODERATION'],
  /** The gift catalogue, bag items, banners and events (read). */
  'catalog.view': ['OWNER', 'SUPPORT', 'FINANCE'],
  /** Gift CRUD (v1.71-social, D207: with uploading the gift's image / effect / sound), banners, events. */
  'catalog.manage': ['OWNER'],
  /** v1.71-social (D207, §10.66): the gift categories — add, rename / reorder / icon, on / off, delete (move). */
  'gifts.categories': ['OWNER'],
  /** Give / take back a bag item (frames, profile cards) to a user. */
  'items.grant': ['OWNER', 'SUPPORT'],
  /**
   * The financial report and its CSV, the Stripe cases, the dashboard's money cards; the CSV of the top-up records
   * (their reading is `recharge.topups.view`, D275).
   */
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
  // ---- v1.72-social (D208, CONVENTIONS §10.67): the account controls «تحكم كامل» --------------------------------
  /** A user's control state: locks, restrictions, password / email state, deletion, adjustments. */
  'users.control_view': ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'],
  /** Lock «قفل» for a while and unlock early. */
  'users.lock': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** Chat mute, no live, no gifts, no posting for a while; lift early. */
  'users.restrict': ['OWNER', 'MODERATION'],
  /** Send the reset link, a temporary password (code again), force a change at the next sign-in. */
  'users.password': ['OWNER', 'SUPPORT'],
  /** Change the email (code again; mark it verified: OWNER only), resend the verification. */
  'users.email': ['OWNER', 'SUPPORT'],
  /** Edit the display name, username, bio, country, gender. */
  'users.profile_edit': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** Hide / restore a post, reel, story; remove a comment; delete a post or story for good (code again). */
  'users.content': ['OWNER', 'MODERATION'],
  /** Coin and cherry adjustments (code again, daily cap). */
  'users.balance_adjust': ['OWNER', 'FINANCE'],
  /** Start the account's deletion (D193 grace period, code again) and cancel it. */
  'users.delete': ['OWNER'],
  // ---- v1.74-social (D217, CONVENTIONS §10.71): «الدعوات» -----------------------------------------------------------
  /** The referrals, their rewards and the settings (read; a referral's detail is audited). */
  'referrals.view': ['OWNER', 'SUPPORT', 'FINANCE'],
  /** Approve or void a referral (money: the authenticator code again). */
  'referrals.decide': ['OWNER', 'FINANCE'],
  /** Change the amounts and rules (money: the authenticator code again). */
  'referrals.settings': ['OWNER', 'FINANCE'],
  // ---- v1.78-social (D223, CONVENTIONS §10.75): accounts per device --------------------------------------------------
  /** The accounts created on a user's sign-up device, and its exception (read; audited). */
  'users.device_view': ['OWNER', 'SUPPORT'],
  /** Grant or remove a device's exception to the accounts-per-device limit (the authenticator code again). */
  'users.device_exception': ['OWNER'],
  // ---- v1.50-live (D229, CONVENTIONS §10.80): «أحكام PK» ---------------------------------------------------------------
  /** The dare library, the reported queue and the PK points settings (read). D274 (owner): OWNER only. */
  'pk_dares.view': ['OWNER'],
  /** Add, edit, disable / enable, import, clear reports; the PK points and dare settings. D274: OWNER only. */
  'pk_dares.edit': ['OWNER'],
  // ---- v1.71-live (D281, CONVENTIONS §10.62.2): «الأهداف الذكية» -----------------------------------------------------
  /** The smart targets' knobs, the catalogues' size and a host's targets with the reasons (read; the host read audited). */
  'host_targets.view': ['OWNER'],
  /** Change the knobs (the percentiles, the reward shares, the no-repeat days…); audited with a reason. */
  'host_targets.edit': ['OWNER'],
  // ---- v1.60-live (D250, CONVENTIONS §10.91): live moderation «مراقبة البث» ---------------------------------------------
  /** Watch a live as a hidden observer (muted card previews and the watch view); every token audited. */
  'lives.watch': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** The reported lives «لايفات مبلّغ عنها» (counts, the red dots), a live's reports with the reporter, its chat. */
  'lives.reports': ['OWNER', 'MODERATION', 'SUPPORT'],
  /** D250b (owner 2026-11-02): SUPPORT watches and reads the reports (above) but takes no action (below). */
  /** End a live, ban its host from going live / suspend the account for a while, dismiss its reports — with a reason. */
  'lives.moderate': ['OWNER', 'MODERATION'],
  /** Ban the host's devices «حظر جهاز» (the authenticator code again), the device-ban list and lifting a ban. */
  'devices.ban': ['OWNER', 'MODERATION'],
  // ---- v1.64-live (D260, CONVENTIONS §10.96): staff presence in lives ----------------------------------------------
  /**
   * Watch HIDDEN «مراقبة خفية» (the D250 observer, for undercover checks); a watch is otherwise VISIBLE (listed in the
   * live with the «فريق كابسو» badge). The shift «في المناوبة» and «بثوثي» go with `lives.watch`.
   */
  'lives.watch.hidden': ['OWNER', 'MODERATION'],
  /** Who is on shift and how many lives each watches (OWNER). */
  'staff.shifts': ['OWNER'],
  // ---- v1.75-live (D285, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب» --------------------------------------
  /** «استقطاباتي»: the caller's own recruits and commissions (the recruiters: MODERATION and BD). */
  'recruits.mine': ['MODERATION', 'BD'],
  /** Every staff member's recruits, each recruit's profit and the commissions paid; the shares (read). */
  'recruits.view': ['OWNER'],
  /** Reassign a recruit to another recruiter, change the shares per type (the code again and a reason). */
  'recruits.manage': ['OWNER'],
  /** The creator programme's applications «صناع المحتوى» (the list and an application's fields). */
  'creators.applications': ['OWNER', 'SUPPORT'],
  /** Approve or reject a creator application (approving activates the creator and attributes a named recruiter). */
  'creators.decide': ['OWNER', 'SUPPORT'],
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
