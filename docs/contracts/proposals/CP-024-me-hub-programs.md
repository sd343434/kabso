# CP-024 — Me hub programs: Task Center, Event Center, VIP and SVIP

**Status: APPROVED WITH DEFAULTS (owner, 2026-10-29) for the Task Center, the Event Center and SVIP —
built in D166 (contract v1.44-social, CONVENTIONS §10.41). VIP (buying a tier with coins, §3) is not
part of the approval and stays «قريباً».** The decisions and every value chosen are recorded in
"Decisions (D166)" at the end; the text below is the original proposal, kept for the reasoning.

Original status line: proposal, **not approved, nothing built.** Written for D164 (owner, 2026-10-29: «اجعل
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

## Decisions (D166, owner approval 2026-10-29 «with defaults»)

The owner approved the scope the same day and asked for the reference screens he gave, in Kabso's identity.
Where the proposal left a choice, the value below was chosen; each is server config or an admin-managed row,
changeable without an app release.

| # | Question | Decision (value) | Where it lives |
|---|----------|------------------|----------------|
| 1 | Task list and rewards | The owner's reference tasks adapted to Kabso: watch a live 15 s (1×) **+5**, follow 10 people **+5**, 10 chat messages in a live **+5**, 10 paid gift sends **+15** (daily); host tasks T7 live 60 min **+100**, T8 receive gifts worth 1 000 coins **+100** (weekly, hosts only). T1 is the check-in. T3–T6 of the proposal were replaced by the reference's tasks. «Share a live room» dropped: a share is a link copied on the phone, the server cannot see it (never self-reported). | `task_definitions` (seeded by migration `20261214100000_me_programs`; `task-admin`) |
| 1b | Daily cap | **50 coins** per account per day, daily tasks + check-in together; weekly host tasks outside it (once a week each) | `TASK_DAILY_CAP_COINS` |
| 1c | Check-in | **5 coins**, **+20** on every 7th day in a row | `TASK_CHECK_IN_COINS`, `TASK_CHECK_IN_STREAK_BONUS_COINS` |
| 2 | Coins or bag items | **Coins only.** No XP: the level systems count coin value (CP-005), free points would buy levels. | — |
| 3 | Reset time | 00:00 (day) and Monday 00:00 (week) in `LIVE_RANKINGS_TIME_ZONE` | config |
| 4 | Event metrics / audience | All five metrics (gift coins received, gift coins sent, live minutes, taps received, new followers); audience everyone **or** hosts per event; optional regions (countries) | `events` |
| 5 | Who creates events | The team, with the **`event-admin` CLI** (create / list / end / hold / release) | CLI |
| 6 | Prizes | **Coins** per rank (1–100), paid automatically **24 h** after the end unless held; once per event and person (`EVENT_PRIZE`) | `events.prizes`, `EVENT_PRIZE_REVIEW_HOURS` |
| 7–10 | VIP tiers, prices, renewal | **Not decided — VIP purchase stays «قريباً»** (not in the approved scope) | — |
| 11 | SVIP | **Earned** by gift spending in a **rolling 30 days** (adapted from the reference's "top up 50 000 within 30 days", because real-money top-up is blocked, B5): **SVIP 1 50 000, SVIP 2 150 000, SVIP 3 400 000** coins; status lasts **30 days** after the last moment the threshold was met | `SVIP_TIERS`, `SVIP_WINDOW_DAYS`, `SVIP_STATUS_DAYS` |
| 12 | SVIP perks | badge, avatar frame, coloured chat name (SVIP 1); entry banner, free daily bullet (SVIP 2); entry effect, viewer-list priority, monthly bag gift (SVIP 3). **None is built yet** — listed as coming, never shown as active (follow-ups in the PR). Points redemption for anti-mute / unban (in the reference) is **not** offered: it would undermine moderation. | `SvipService` |
| 13 | Art | **Owner art needed**: SVIP emblem, badge, frames and effects; event banners; the Task Center header art. The app uses token-coloured icon compositions until then. | — |
| — | Recharge screen | Packages from config, placeholders from the reference (10+20 $0.29, 38+20 $0.99, 276+28 $6.99 was $8.00, 800+30 $19.99, 2500+30 $59.99, 4193+30 $99.99, 5197+30 $129.99) **for the owner to set**; the CTA stays disabled «الدفع قريباً» (B5). No purchase endpoint. | `WALLET_RECHARGE_PACKAGES`, `WALLET_RECHARGE_CURRENCY` |
