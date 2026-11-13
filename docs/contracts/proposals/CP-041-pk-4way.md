# CP-041 — PK with four hosts «PK رباعي»: 2 v 2 and every host for themselves

**Status: PROPOSED — waiting for the owner's answers (§9).** No code yet. Owner (2026-11-13): «الان هناك pk رباعي لم
نقم بتفعيله»; answers the same day: **both formats** (2 v 2 teams *and* all four against each other), started **by
invitation and by random matching**, built in phases (this document first). Builds on CP-038 / §10.58 (PK 1 v 1),
§10.62 (settings, best of three, auto-start), §10.70 (random friends), §10.80 (PK أحكام), §10.85 (rematch) and D71
(the 2 × 2 layout in the debug preview; until now **only a design** — the server knows two sides).

Every number below is a **default the owner can change** (server config, as in CP-038).

## 1. What stays exactly as it is

- PK 1 v 1 (`PkMatch`, its tables, routes, messages, boosters, dares, rematch, records). Nothing in it changes; a
  host in a 1 v 1 PK is busy for a 4-way PK and the reverse.
- Who may take part: a host of a LIVE **SOLO video** room, present, fresh heartbeat (§10.58 "eligible"); never
  MULTI, AUDIO, podcast or streamer lives. `PK_ENABLED` switches 4-way PK off too, with its own
  `PK4_ENABLED` (default true).
- **Gifts and money**: a viewer sends gifts to their own room as today; the wallet, host earnings, cherries, live
  score, boards, charm and levels are written from the real value. Multipliers affect only PK points (§10.58).
- Each room keeps its own chat, viewers, seats and gifts.

## 2. The two formats

| | «2 ضد 2» `TEAMS` | «الكل ضد الكل» `FREE_FOR_ALL` |
|---|---|---|
| Players | 4 hosts in 2 teams of 2 | 4 hosts, each alone |
| Score | each host's PK points as in 1 v 1; **the team's score is the sum of its two hosts** | each host's own PK points |
| Winner | the team with the higher sum; equal sums → a **draw** | the highest score; places 1 to 4 by score; equal scores share a place; equal first place → a draw between them |
| Bar | `KabsoPkBar` with the two team colours (Kabso red / blazing orange, D71); each host's own score under their pane | a new four-part bar, one colour per host, the leader first |
| Layout | the D71 2 × 2 grid: the caller's team on the start side (top and bottom), the opponents on the other side | 2 × 2 grid, the caller's own pane at the top start, the others by seat |

## 3. Starting a 4-way PK

### 3.1 By invitation «دعوة الأصدقاء» (phase 2 for TEAMS, phase 3 for FREE_FOR_ALL)

1. A host opens «PK رباعي», picks the format and becomes the **organiser**. A **lobby** opens for
   **`PK4_LOBBY_SECONDS` = 120**.
2. The organiser invites hosts from the same candidate list as 1 v 1 (eligible, invitations on, not busy, no block
   either way **with any of the lobby's hosts**). In TEAMS the organiser invites one host **as teammate** and two **as
   opponents**; in FREE_FOR_ALL three hosts.
3. Each invitation is open **`PK4_INVITE_TTL_SECONDS` = 30** (longer than 1 v 1's 15 s: four people must agree). A
   declined or expired place can be offered to another host while the lobby is open. The organiser may cancel the
   lobby; an invited host who accepted may leave it before the start.
4. When **all four** have accepted, the battle starts (or `CONNECTED` if the organiser's auto-start is off, §10.62).
   The lobby expiring first → nothing starts, everyone is told «لم يكتمل العدد».

### 3.2 Random «مطابقة عشوائية» (phase 4)

- One queue per format. When **four** eligible waiters with no block between any two of them are in a queue, the four
  who waited longest are matched. In TEAMS the server pairs them into two teams at random (crypto random).
- The wait is **`PK4_RANDOM_WAIT_SECONDS` = 120** (then «لم نجد مضيفين كافيين»). The gender / region preferences of
  §10.62 apply between every pair. Auto Match (§10.62) stays 1 v 1 only.
- A waiter can still be invited (§10.70 behaviour), which leaves the queue.

## 4. The match

- **Phases** as in 1 v 1: `BATTLE` **`PK_BATTLE_SECONDS`** (or the organiser's round minutes), then `RESULT`
  **`PK_RESULT_SECONDS`**, then `CLOSED`. **Single round only** in 4-way (best of three stays 1 v 1; a later phase
  if wanted). The organiser's settings are used (not a random pick between four hosts).
- **A host who leaves** (ends the live, `endLivePk`, absent / away for **`PK_ABSENCE_GRACE_SECONDS` = 30**):
  - TEAMS: the host's points so far stay in the team score; the teammate carries on alone. Both hosts of a team gone
    → the other team wins at once.
  - FREE_FOR_ALL: the host is out and takes the **last free place** (4th, then 3rd …); the others carry on. One host
    left → that host wins at once.
  - Everyone gone at once → a draw (void for records, as both-absent in 1 v 1).
- **A moderator's end** (`pk-admin end`, the panel): void, as in 1 v 1.

## 5. Boosters

The same four boosters, gifts, windows and multipliers (§10.58).

- **TEAMS:** a booster is the **team's**: a booster gift sent in either teammate's room activates it for **both rooms
  of the team**; the limits (2 per booster) are **per team**; one active booster per team, a higher one replaces it.
- **FREE_FOR_ALL:** per host, exactly as in 1 v 1.
- Every room sees «فعّل فريق X تربل ×5!» (TEAMS) or «فعّل @host تربل ×5!» (FREE_FOR_ALL) and the countdown chip on
  that team / host.

## 6. Results, records and supporters

- RESULT shows the win / lose / draw animation per room (a winning room «فوز», a losing one «خسارة»), the scores and
  the **top three supporters per room** (TEAMS: per team, from both rooms).
- **Records** (`pk_host_records`): TEAMS → a win, a loss or a draw for each host as in 1 v 1. FREE_FOR_ALL → 1st place
  is a **win**, 4th place a **loss**, 2nd and 3rd neither; a new counter `ffaFirsts` / `ffaPlayed`. The history keeps
  the four hosts, the format, the scores and the places.
- PK points for the «نقاط PK» stage (D276): as in 1 v 1, per host.

## 7. «PK أحكام» and «جولة أخرى»

- **Dares (type `DARES`):** TEAMS → the **losing team** gets one dare drawn as in §10.80, done by both its hosts; the
  winning team judges (either winner's vote counts). FREE_FOR_ALL → the **4th place** does the dare; 1st place
  judges. A draw → no dare.
- **Rematch «جولة أخرى»:** any host offers it in RESULT; it starts only when **all four** accept within
  **`PK_REMATCH_ACCEPT_SECONDS` = 15**. Same hosts, same teams, same format; `PK_REMATCH_MAX` applies.

## 8. Media, layout and cost

- **No new LiveKit room.** As in 1 v 1, each viewer and host opens **subscribe-only connections to the other rooms**
  — here **three** instead of one (`createLivePk4MediaToken` per other room; identity `pk4:<matchId>:<id>`; never
  counted as viewers).
- **Cost:** about **three extra LiveKit participants per viewer** during a 4-way PK (1 v 1: one). To keep bandwidth
  sane on phones the app asks for the **lower simulcast layer** of the three other hosts (a quarter-screen pane needs
  no HD).
- **Sound:** viewers hear all four hosts; each host can **mute any of the other three** for their own room (one switch
  per pane).
- **PK guests:** a host's guests (seats 1–3) stay in their own room but are **not shown** in the 2 × 2 grid (no room);
  they are back when the PK ends.
- **App:** the «PK رباعي» entry in the PK sheet (format, invitations, lobby with four places and their state), the
  2 × 2 stage of D71 wired to the real match, the two bars, the result card for four, the new messages
  (`pk4-match`, `pk4-lobby`, `pk4-queue` on the `pk` topic).
- **Panel:** 4-way matches in the live monitor and the moderator's end.

## 9. Questions for the owner

1. The numbers: lobby **120 s**, each invitation **30 s**, random wait **120 s**, battle and result as in 1 v 1 —
   confirm or change.
2. **Single round only** for 4-way PK (no best of three) — agreed?
3. TEAMS boosters: **shared by the team** (a gift in either room activates it for both, limits per team) — or per
   host?
4. FREE_FOR_ALL records: **1st = win, 4th = loss, 2nd / 3rd neither** — or 1st win and everyone else a loss?
5. Dares: TEAMS → the **losing team** does one dare together; FREE_FOR_ALL → the **4th place** — agreed?
6. A host who leaves: TEAMS → the teammate carries on alone; FREE_FOR_ALL → the host is out and the others carry on
   — agreed?
7. PK guests hidden during a 4-way PK — agreed?
8. Media cost: three extra connections per viewer (≈ 3× the 1 v 1 PK cost per viewer) — acceptable?

## 10. Phases

| Phase | Content | Delivery |
|---|---|---|
| 1 | This document, the owner's answers | — |
| 2 | TEAMS by invitation: lobby, match, team score, team boosters, absences, result, records, media (3 connections), app stage and bars, panel | one PR |
| 3 | FREE_FOR_ALL: places, four-part bar, records, absences | one PR |
| 4 | Random matching for both formats; dares and rematch for four | one PR |

Each phase: contract first (openapi, CONVENTIONS §10.x, board row), migrations, API with e2e, app with widget tests
and goldens (2 × 2 in Arabic / English, dark / light, 360 × 800 × 1.3), panel, DEPLOYMENT notes, and a real
LiveKit check like D195's (`d195-pk-livekit-real`) with four rooms.
