# CP-041 — PK with four hosts «PK رباعي»: 2 v 2 and every host for themselves

**Status: APPROVED by the owner (2026-11-13, answers in §9) — phase 2 implemented (D391, v1.118-live, CONVENTIONS §10.180; branch `claude/pk-4way`, not merged); phases 3–4 not started.** Owner (2026-11-13): «الان هناك pk رباعي لم
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
    left → that host wins at once. In a DARES match the dare goes to the **lowest place still on air** (owner: «ان كان
    حكم ينفذ الثالث الحكم» — the 4th left, so the 3rd does it).
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
  is a **win**, every other place a **loss** (owner); equal first places → a draw for them, a loss for the others. The history keeps
  the four hosts, the format, the scores and the places.
- PK points for the «نقاط PK» stage (D276): as in 1 v 1, per host.

## 7. «PK أحكام» and «جولة أخرى»

- **Dares (type `DARES`):** TEAMS → the **losing team** gets one dare drawn as in §10.80, done by both its hosts; the
  winning team judges (either winner's vote counts). FREE_FOR_ALL → the **4th place** does the dare (or, if the 4th left the
  match, the lowest place still on air); 1st place judges. A draw → no dare.
- **Rematch «جولة أخرى»:** any host offers it in RESULT; it starts only when **all four** accept within
  **`PK_REMATCH_ACCEPT_SECONDS` = 15**. Same hosts, same teams, same format; `PK_REMATCH_MAX` applies.

## 8. Media, layout and cost

- **No new LiveKit room.** As in 1 v 1, each viewer and host opens **subscribe-only connections to the other rooms**
  — here **three** instead of one (`createLivePk4MediaToken` per other room; identity `pk4:<matchId>:<id>`; never
  counted as viewers).
- **Cost:** about **three extra LiveKit participants per viewer** during a 4-way PK (1 v 1: one). Owner: accepted,
  **keep it as low as possible**:
  - viewers subscribe to the **lowest simulcast layer** of the three other hosts (a quarter-screen pane; about 180p,
    15 fps), the hosts to the middle layer;
  - a pane that is off screen or covered (the app in the background, a full-screen sheet) is **paused** (video
    unsubscribed, sound kept);
  - the extra connections are opened only for the BATTLE and RESULT phases and closed at once when the match ends;
  - a server cap `PK4_MAX_WATCHERS_PER_ROOM` (default 0 = no cap) can stop new viewers from opening the other rooms'
    video (they then see the four names and the scores, with their own host's video only).
- **Sound:** viewers hear all four hosts; each host can **mute any of the other three** for their own room (one switch
  per pane).
- **PK guests:** a host's guests (seats 1–3) stay in their own room but are **not shown** in the 2 × 2 grid (no room);
  they are back when the PK ends.
- **App:** the «PK رباعي» entry in the PK sheet (format, invitations, lobby with four places and their state), the
  2 × 2 stage of D71 wired to the real match, the two bars, the result card for four, the new messages
  (`pk4-match`, `pk4-lobby`, `pk4-queue` on the `pk` topic).
- **Panel:** 4-way matches in the live monitor and the moderator's end.

## 9. The owner's answers (2026-11-13; rows 9–13 after the phase 2 review)

| # | Question | Answer |
|---|---|---|
| 1 | Lobby 120 s, invitation 30 s, random wait 120 s | «موافق» |
| 2 | Single round only | «موافق» |
| 3 | TEAMS boosters shared by the team | «الاثنين» — shared: a gift in either teammate's room activates it for both |
| 4 | FREE_FOR_ALL records | «الأول فوز والباقي خسارة» — 1st a win, every other place a loss |
| 5 | Dares: the losing team together; FFA the 4th place | «موافق» |
| 6 | A host who leaves | «نعم» — and in a DARES FFA the dare goes to the 3rd when the 4th left («ان كان حكم ينفذ الثالث الحكم») |
| 7 | Guests hidden during a 4-way PK | «نعم» |
| 8 | Media cost about 3× per viewer | «نعم قللها» — accepted, reduced as in §8 |
| 9 | All four hosts gone → a draw that is void for records (1 v 1 counts both-absent as a draw) | «موافق» — kept void |
| 10 | A host who left still gets the team's result | «موافق» |
| 11 | 4-way matches in the PK history list and the PK_BATTLES / PK_WINS tasks | «موافق» — later, with phase 4 |
| 12 | Ending a 1 v 1 PK from the panel (today CLI only) | «موافق» — later |
| 13 | The panel's «watch» view showing the other three rooms | «موافق» — later |

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
