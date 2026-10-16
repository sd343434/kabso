# KL-035b: live room visual review package (KL-034)

These are real screenshots of the **live room** (`/live/room/:roomId`, KL-034) in the running
app, captured the same way as KL-035a (see
[`../2026-10-16-home-live/README.md`](../2026-10-16-home-live/README.md) §1).

**The analysis, gaps and prioritized changes are in
[`../../KABSO_LIVE_VISUAL_REVIEW.md`](../../KABSO_LIVE_VISUAL_REVIEW.md) §8.**

| | |
| --- | --- |
| App revision | `b3c1911` (`claude/amazing-tesla-5aj3um`; contains KL-034 `c683631`). A fresh scratch copy of `apps/mobile`, built with `flutter create --platforms=web` and `flutter build web --profile --dart-define=API_BASE_URL=http://localhost:3103`, served on 8135 |
| API revision | `b3c1911`, `apps/api` built with `pnpm build` and run on 3103 with Redis DB 3 against `kabso_kl013_dev` |
| Database schema | **`prisma migrate deploy` was not run.** HEAD adds `20261016130000_per_database_runtime_group`, which needs an admin bootstrap this environment doesn't have. It changes grants only, not schema. The API ran on the existing migrated schema (the one used for KL-035a) |
| API boot | The API started normally. Its boot-time role check logged a **warning** that the runtime login is not yet a member of the new per-database runtime group, i.e. the grant migration above has not run. Outside production this check is logged, not enforced. No other behaviour difference was observed |
| Captured | 2026-10-16. Toolchain as in KL-035a (Flutter 3.47.7, Playwright 1.56.1 with Chromium 141) |
| Viewports / locales | 393×852 and 360×800 @3x; `ar` (RTL) and `en` (LTR) |

## Labels

| Folder | Label | Meaning |
| ------ | ----- | ------- |
| [`local-api/`](local-api/) | **Local API data** | The real app against the real API with `LIVE_HOSTING_ENABLED=true` and labelled local test accounts. A file name ending in **`-simulated`** or **`-proxy-502`** marks a condition imposed by the browser, not by the API |
| [`fixtures/`](fixtures/) | **Test fixture render — not live data** | The 44 new `room.*` goldens, copied unchanged from `apps/mobile/test/goldens/png/` (`phone` → `.393`, `android` → `.360`). 1× renders; the 393 renders carry 59/34 insets |

There is no `production/` folder; see "States not captured" below.

## How the states were produced

**Data**
- The same local accounts as KL-035a: the reviewer and 8 hosts with labelled test names.
- The same 3 "Local test" categories (inserted earlier as the migrator; there is no admin API).
- The 8 hosts went live through `POST /live/rooms`, and a heartbeat loop kept them live.
- For setup only, the login rate limits were raised by environment variable, because the
  scripts log the hosts in repeatedly.
- Viewer counts are 0 (there is no presence), so the room shows no viewer count.
- The database was not edited.

**Driving the app**
- Each sequence runs in each of the four persistent browser profiles (`en-393`, `en-360`,
  `ar-393`, `ar-360`), whose sessions were logged in through the app's own login screen
  (KL-035a).
- Taps go through Flutter's semantics tree.
- **Script:** `scratchpad/kl035a/capture.mjs` (not committed). Plans: `room-main.json`,
  `room-ended-open.json`, `room-loading.json`, `room-notfound.json`, `room-offline.json`,
  `room-5xx.json`. API actions: `room-ctl.mjs`.

| File stem (`local-api/`) | How |
| ------------------------ | --- |
| `room.live` | Live hub → tap Nora Test's card ("Learning Arabic calligraphy, lesson 3", no category). Shows the video-unavailable stage, host pill with Follow and "0 followers", title chip, chat notice and gift button |
| `room.followed` | Follow tapped. This is a **real** `PUT /users/test.nora/follow`: the chip collapses and the second line shows "1 follower" |
| `room.host-sheet` | Host pill tapped. The host sheet shows avatar, name, @username, follower count and a "Following" toggle |
| `room.host-sheet-unfollowed` | "Following" tapped in the sheet. This is a **real** unfollow: "0 followers" and Follow again. A real API unfollow before each profile reset the state |
| `room.gifts` | Gift button tapped. The non-dimming sheet shows Kabso preview gifts, no prices, Send disabled and "Gifts can't be sent yet." |
| `room.ended-stale-card` | Room closed. Then `test.ali` ended its room through the **real** `POST /live/rooms/{id}/end`, and the still-listed card was tapped. The ended overlay shows "The host ended this live." with Follow and "Back to live rooms". The host then went live again for the next profile |
| `room.ended-while-open` (393 only) | Hana's room was open when `test.hana` ended it through the API. Captured **15 s later: the screen still shows the room as live** (gap RR-01) |
| `room.ended-reopened` (393 only) | Close, then reopen the same card: ended overlay |
| `room.loading` | **Simulated:** the browser held `GET /live/rooms/{id}` for 20 s; captured 2.5 s after the tap |
| `room.not-found-deep-link` | Hash deep link to `/live/room/3f1c9a52-7b0e-4d6a-9c1e-5a8b2f4d7e10`, a random uuid with no room. The real API answered 404 |
| `room.offline-simulated` | **Simulated:** the hub loaded online, then browser network emulation went offline before the card tap |
| `room.error-proxy-502` | **Simulated proxy fault:** the browser answered `GET /live/rooms/{id}` with a bare 502 |

Every stem exists as `.{ar,en}.{393,360}.png` except the two marked "393 only".

**Fixtures** (`fixtures/room.*`):
- `populated` (chat, viewers, share);
- `pk.split`;
- `multi_guest`;
- `gifts`;
- `loading`, `video_unavailable`, `ended`, `error`;
- `state.weak`, `state.reconnecting`, `state.camera_off`.

## States not captured from the running app, and why

| State | Why |
| ----- | --- |
| A **production** (hosting-off) room | With `LIVE_HOSTING_ENABLED=false` the hub lists no rooms, so no card leads to a room. Only a deep link could, and it would show the same ended or not-found states as `local-api/`. No separate production capture was made |
| Video playing, viewer avatars and count, chat messages, comment composer, share | No media provider (B1), presence, chat API or room-link domain exists. Shown in fixtures only (`fixtures/room.populated.*`) |
| PK split, multi-guest seats | No API support. Fixtures only (`room.pk.split`, `room.multi_guest`) |
| Weak connection, reconnecting, camera off | These need a media SDK. Fixtures only (`room.state.*`) |
| Ended because of a heartbeat timeout, as seen from the room | Not captured separately. The overlay is the same; only the reason line differs ("The live stopped after the host's connection was lost.") |
| Gift with a price, sending a gift | No catalogue or wallet (B5) |

## Rules followed

- No reference images are included, and the owner's reference image was not looked for.
- No similarity to any third-party app is claimed.
- No credentials are recorded: local throwaway values only, none written here.
- Reference comparison: **pending — no authorized references supplied**.
