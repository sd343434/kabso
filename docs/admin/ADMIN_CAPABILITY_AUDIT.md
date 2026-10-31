# Admin capability audit «تحكم كامل» (D208, 2026-10-31)

The owner's request: «حاول دراسة لوحة الادمن واجعله يملك صلاحية لكل شيء مثل قفل حساب شخص او حظره او تغير كلمة المرور والخ».

This is the audit of what the team can do today, area by area, on branch `claude/kl-int6` (D191 panel, D196
payments, D197 panel v2) plus D208. Contract: CONVENTIONS §10.54 (panel), §10.60 (v2), §10.67 (D208).

Columns:

- **User:** what a user can do in the app.
- **Panel:** what the admin panel can do (operation ids or sections). **D208** marks what this change adds.
- **CLI only:** what only a command-line tool on the server can do (`pnpm <x>:admin …`).
- **Nobody:** what nobody can do today.

Gaps are listed at the end with a priority: P1 = done in D208, P2 / P3 = for the owner to choose.

> **Privacy limit.** The admin panel never reads private direct messages. A DM is visible to the team only as the
> snapshot attached to a report (§11.13, `reports.view`), and D208 adds no way to read conversations. Private
> fields of recharge-agent applications are shown only with `recharge.applications` and every view is audited.

## 1. Capability matrix

| Area | User | Panel | CLI only | Nobody |
|---|---|---|---|---|
| **Accounts and auth** | register, log in, sessions list / revoke, forgot / reset password, verify email, delete account (D193) | search, user page, **ban / unban** (permanent, D191), sessions list + sign out one / all (D197); **D208:** lock for a while (1 / 3 / 7 / 30 days or a date) and unlock, reset email, temporary password (shown once, code again), force a change at next log-in, change email (code again; mark verified OWNER), resend verification, delete (D193 grace, code again) and cancel, full timeline | `account-admin` purge-now, legal holds (`holds`, `hold-show`); `admin-admin` grant / revoke / reset-2fa (also in Team, D197); `control-admin` (D208) | change a user's role outside the panel roles; merge accounts; 2-step verification for users |
| **Profile** | name, bio, country, gender, category, links, photo, username (D146 rule) | remove photo (D191); special username gift / revoke (D185); **D208:** edit name, username, bio, country, gender | `profile-admin remove-avatar`, `username-admin`, `premium-admin` (premium names) | remove a single profile link (only via a report of it); there is no cover / background to remove |
| **Follows / blocks** | follow, requests, block, mute, hide | — | — | see or undo a user's follows / blocks (P3) |
| **Posts / reels / stories / comments** | create, edit, delete, pin, like, comment, save, share, report | report queue: remove target / dismiss / warn / ban (D191); a user's posts (read, D197); **D208:** hide / restore / delete for good (code again) posts, reels and stories, remove comments, from the user's Content tab; stories and comments lists | `search-admin` hide / block-word / top | edit someone's text; bulk actions over many posts (P3) |
| **DMs** | send, request, accept, delete for everyone (1 h), report | the reported message's snapshot only (privacy limit) | — | read conversations (by design) |
| **Lives (video, audio, seats, chat, PK, tools)** | go live (hosting permission), seats, chat, kicks, mutes, PK, second camera, music, recorder | lives now + details, **end a live** with reason, hosting permission grant / revoke (D197); **D208:** «منع البث» restriction (ends the current live) | `pk-admin` end / show; `boost-admin` | delete one chat message outside a report (P2); see a live's chat history (P3) |
| **Gifts / lucky / quips** | send gifts, lucky gifts, quips | catalogue CRUD, enable / disable (D197); **D208:** «منع إرسال الهدايا» | `gift-admin` lucky-day, lucky-wins, pk-boosters / quips seed | lucky odds editing in the panel (P3) |
| **Bag / frames / entrances / badges** | equip, send bag items | give / take a bag item to a user (D197) | `bag-admin`, `medals-admin backfill` | — |
| **Levels** | earn | read the ladder (D197) | `levels-admin` grant / revoke / publish | grant levels from the panel (P2) |
| **Families / CP** | create, join, leave, disband, CP requests | — | — | disband a family, rename it, remove a member, break a CP (P2) |
| **Economy — coins and cherries** | spend, earn, withdraw cherries | balances and ledgers (D191 / D197), withdrawals pay / reject (code again), card refunds (code again), Stripe cases, financial report; **D208:** coin / cherry adjustments with `ADMIN_ADJUSTMENT` (FINANCE / OWNER, code again, never below 0 unless OWNER allows, daily cap per admin) | `wallet-admin` grant / revoke, `economy-admin reverse-gift`, `payments-admin` reverse-gift / unfreeze | reverse a gift from the panel (P2); unfreeze a frozen buyer from the panel (P2) |
| **Agencies / recharge agents / recharge orders** | apply, sell, buy | applications approve / reject, agents top-up (code again), suspend, cap (D191); agencies create / suspend / complaints / evaluation (D197) | `economy-admin agency-parent`, `recharge-admin purge` | recharge orders (D204) are on another branch, not in this one |
| **Tasks / events / SVIP** | claim tasks, events | read tasks (D197), events create / end / hold (D197) | `task-admin` set / bands, `event-admin style` | edit task rewards in the panel (P3) |
| **Notifications / push** | inbox, settings, push token | — (D208 sends system notifications for its actions) | — | broadcast a message to all users (P2) |
| **Banners** | — | enable / disable / remove (D197) | `banner-admin add` (upload), `feature-admin` | upload a banner from the panel (P3) |
| **Reports / safety** | report | queue with remove / dismiss / warn / ban (D191) | — | assign reports to a moderator (P3) |
| **Site settings / payments** | — | site settings (D191/D192), Stripe keys and options (D196) | `legal-admin publish`, `privacy-admin export` | publish legal versions from the panel (P3) |
| **Waitlist** | join on the website | read (OWNER, audited) | `waitlist-admin export` | — |

## 2. Gaps

### P1 — done in D208 (CONVENTIONS §10.67)

1. Lock / suspend for a while (1 / 3 / 7 / 30 days or a date), refused log-in with the reason and the end, all
   sessions ended, unlock early — separate from the permanent ban.
2. Password: the reset email; a temporary password generated by the server and shown once (OWNER / SUPPORT, code +
   reason), all sessions ended, change required at the next log-in; force a change at the next log-in. The admin never
   sees or receives a user's own password.
3. Profile edit: display name, username (D146 rule and the special-username rules), bio, country, gender. (No cover
   exists; photo removal already existed.)
4. Email change with a verification to the new address or mark-verified (OWNER), and resend verification.
5. Restrictions with an end: chat mute everywhere (live chats, bullets, comments, DMs), no going live, no sending
   gifts, no posting — each told to the user with its end.
6. Content: hide / restore / delete posts, reels, stories; remove comments; reports closed.
7. Balance adjustments (coins / cherries, `ADMIN_ADJUSTMENT`, code again, no negative unless OWNER allows, daily cap).
8. Devices: «تسجيل الخروج من كل الأجهزة» (already existed; now in the Security group).
9. Delete an account through D193's lifecycle (OWNER, code again) and cancel.
10. The user's full timeline: the rows about the account, by the account, and on its content.

Every P1 action is capability-checked on the server, needs a reason, writes an audit row (actor, IP, `via: panel`,
before / after), notifies the user where it applies, and has a `control-admin` CLI command where a CLI exists (lock,
unlock, restrict, lift, forced change, adjust; deletion is `account-admin`; the temporary password and the reset email
are panel-only).

### P2 — next, for the owner to choose

- Reverse a gift and unfreeze a frozen card buyer from the panel (today CLI only).
- Families and CP: disband / rename a family, remove a member, break a CP.
- Delete one live chat message or comment from a live's page (outside a report).
- Grant / revoke levels from the panel.
- Broadcast a system notification to all users or a segment.
- Ban by device (the app has no device id beyond the session's name).

### P3 — later

- See / undo a user's follows and blocks; bulk content actions; a live's chat history; lucky odds and task rewards
  editing; banner upload; legal versions publishing; report assignment.
