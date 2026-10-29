# CP-024 — Me hub programs: Task Center, Event Center, VIP and SVIP (PROPOSAL)

**Status:** proposal, **not approved, nothing built.** Written for D164 (owner, 2026-10-29: «اجعل
الوكيل يعمل على أزرار قريباً في أنا»). D164 built the three «قريباً» buttons of the Me hub that only
show data Kabso already stores (Wallet, Earn money, Creator Center, CONVENTIONS §10.40). The four
below need **business rules only the owner can set** — rewards, prices, benefits, events — so their
hub rows stay «قريباً» until the owner answers the questions at the end. Everything marked
*proposed default* is a suggestion with its reasoning, not a decision.

## Ground rules for all four (proposed)

- **Coins only, server-side.** Every price and reward is a server config value (like
  `LIVE_BOOST_PRICES`, `GIFT_HOST_SHARE_PERCENTS`), changed without an app release; every coin
  movement is a `wallet_ledger` row with its own reason (`TASK_REWARD`, `VIP_PURCHASE`, …), so the
  wallet history of D164 shows it with no extra work.
- **No real money in these programs** until B5 (store purchases, legal review) is done: VIP is bought
  with coins; rewards are coins or bag items.
- **Abuse limits first.** Rewards that can be farmed (watch time, follows, gifts between friends) get a
  daily cap per account and per device, count only ACTIVE accounts, and never count actions between
  two accounts that keep exchanging the same reward.
- **Honest UI.** A program with nothing configured shows an empty state, never sample tasks or events.

## 1. Task Center «مركز المهام»

**What it is.** Daily and weekly tasks that reward coins (or a bag item) once done; the person taps
«استلام» to claim. Progress comes from events the server already records — nothing is self-reported.

**Proposed default tasks** (rewards are placeholders sized against existing prices: a bullet message
costs 15 coins, the cheapest quip 99):

| # | Task | Period | Counts from (existing data) | Proposed reward |
|---|------|--------|-----------------------------|-----------------|
| T1 | Open the app (check-in) | daily | sign-in / session refresh | 5 coins |
| T2 | Watch lives for 10 minutes in total | daily | `live_room_audience.watch_ms` | 10 coins |
| T3 | Send 1 gift | daily | `live_gifts` (sender) | 10 coins |
| T4 | Comment on 3 posts | daily | `comments` | 5 coins |
| T5 | Follow 3 new people | daily | `follows` (still standing at claim time) | 5 coins |
| T6 | Publish a post or a reel | weekly | `posts` (published, not removed) | 30 coins |
| T7 | Go live for 60 minutes in total (hosts) | weekly | `live_summaries.duration_seconds` | 100 coins |
| T8 | Receive gifts worth 1 000 coins (hosts) | weekly | `live_gift_recipients` | 100 coins |

- Day and week boundaries in `LIVE_RANKINGS_TIME_ZONE` (the same clock as the boards).
- Tables: `task_definitions` (admin-managed: code, period, target, reward, enabled, order) and
  `task_claims` (user, task, period start — unique, so a reward is paid once). Reward credited in the
  claim's transaction with ledger reason `TASK_REWARD`.
- API sketch: `GET /me/tasks` (today's and this week's tasks with progress), `POST /me/tasks/{code}/claim`.
- Cost guard: a daily total cap per account (proposed 50 coins/day) whatever the configuration.

## 2. Event Center «مركز الفعاليات»

**What it is.** Time-limited events created by the team: a banner, dates, rules text and a
leaderboard computed from existing points, with optional rewards for the top places.

**Proposed design.**
- Admin creates an event (CLI first, like `banner-admin`): title ar/en, banner image (uploaded like
  home banners, D124), starts/ends, rules ar/en, **metric** (one of: gift coins received, gift coins
  sent, live minutes, taps received, new followers), audience (everyone / hosts only), and prizes per
  rank (coins and/or a bag item / medal).
- The leaderboard is computed from the same tables as the popularity board and the data center for
  the event's window — no new counting path. Top 100 shown, the caller's own rank always.
- At the end the server freezes the board (a snapshot row per rank) and pays prizes once (ledger
  reason `EVENT_PRIZE`, unique per event and user); an admin can review before payout (proposed: a
  24-hour review window, then automatic).
- The hub's Event Center lists running, upcoming and ended (30 days) events; the home banner can link
  to one.
- API sketch: `GET /events`, `GET /events/{id}`, `GET /events/{id}/leaderboard`.

## 3. VIP «شراء VIP»

**What it is.** A monthly membership bought with coins that gives visible perks.

**Proposed tiers** (prices are placeholders; the owner sets them — compare a 10-minute traffic card at
10 000 coins):

| Tier | Proposed price (30 days) | Proposed perks |
|------|--------------------------|----------------|
| VIP 1 | 3 000 coins | VIP badge next to the name (chat, profile, viewer list); 1 exclusive avatar frame |
| VIP 2 | 8 000 coins | VIP 1 + coloured name in live chat; entry banner when joining a live |
| VIP 3 | 20 000 coins | VIP 2 + entry effect (animation); 1 free bullet message a day; priority in the viewer list |

- **Not proposed:** "no ads" (the app has no ad system today, so it would be an empty perk),
  changing gift odds, or anything that changes scores, rankings or lucky-gift chances (a paid
  advantage there is unfair and a regulatory risk).
- Renewal: manual (tap to renew) — no automatic charge, because coins can run out and a silent
  charge surprises people. A reminder notification 3 days before the end (as premium usernames, D146).
- Upgrading mid-period: pay the difference pro rata (proposed) or start a new 30 days (simpler).
- Frames and effects need **Kabso-owned art** (no third-party assets): a design task before launch.
- Tables: `vip_memberships` (user, tier, starts, ends, source), ledger reason `VIP_PURCHASE`.

## 4. SVIP «SVIP»

**What it is.** A higher, scarcer tier above VIP 3, for the biggest supporters.

**Proposed design.**
- Not bought directly: **earned** by monthly spending (e.g. ≥ 100 000 coins spent on gifts in a
  calendar month gives SVIP for the next month), so it rewards real support and is not a second price
  list. Alternative: a fixed price (e.g. 60 000 coins / 30 days) — the owner chooses.
- Perks: everything in VIP 3 + a unique SVIP badge and frame, a premium entry effect, a monthly
  bag gift (e.g. one traffic card), and a "SVIP" filter on the supporter boards.
- Spending already exists in the ledger (`LIVE_GIFT`, `LUCKY_GIFT`, `DM_GIFT`, `CP_GIFT`), so the
  qualification needs no new tracking.

## Not in this proposal

Real-money purchases (B5), withdrawals / payouts (D149), agencies, ads.

## Questions for the owner

1. **Task Center:** approve the task list T1–T8 (add, remove or change any)? What reward for each, and
   what daily cap per account (proposed 50 coins)?
2. Should task rewards be coins only, or also bag items / medals?
3. Day/week reset time: the boards' time zone (`LIVE_RANKINGS_TIME_ZONE`) — which zone and hour?
4. **Event Center:** which metrics may events use (gifts received, gifts sent, live minutes, taps, new
   followers)? Hosts-only events, everyone, or both?
5. Who creates events — only the team via the server tool at first (proposed), or an admin web page?
6. Prizes: coins, bag items, medals? Paid automatically after a 24-hour review (proposed) or only by
   hand?
7. **VIP:** how many tiers (proposed 3) and the monthly price of each in coins?
8. Which perks per tier from: badge, avatar frame, coloured chat name, entry banner, entry effect,
   free daily bullet, viewer-list priority? Any others you want?
9. Manual renewal with a reminder (proposed), or automatic renewal from coins?
10. Upgrade mid-month: pay the difference, or start a new 30 days?
11. **SVIP:** earned by monthly spending (proposed, threshold?) or bought at a fixed price (how much)?
12. SVIP perks: anything beyond VIP 3 + unique badge/frame/effect + a monthly gift?
13. Art: do you have frames / badges / effects for VIP and SVIP, or should the team design Kabso-owned
    ones?
