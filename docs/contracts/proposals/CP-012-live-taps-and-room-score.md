# CP-012 — Live taps and the room score (APPROVED)

**Status:** approved by the owner on 2026-10-23 (D95), with these decisions:

- **Every live has a score** shown in the host's room bar.
- **One tap = 1 point.** A viewer taps the live to cheer the host.
- **One support coin = 100 points.** Support (gifts paid in coins) arrives with L3; until
  then the support part of the score stays 0.
- **Tap limits:** at most **10 taps a second** and **10 000 taps in one live** from each
  viewer. Taps past a limit are not counted. They are not an error.
- **Who counts (owner, Q3):** seated guests' and moderators' taps **count**. Only the
  **host's** own taps never count.
- **Hub and trending (owner, Q4):** the score shows on the hub cards and **"Popular" is
  sorted by it**, so that rooms compete to rise in the trend.

## Why

The owner wants the live's "strength" to be visible to the host and viewers. It encourages
viewers to take part (tapping and supporting), as on other live platforms. Taps are free, so
the server counts them and enforces the limits. A client cannot raise the score by itself.

## Scope

In scope:

- tapping a live, counted by the server, with the limits above;
- the room score (taps and support, apart and in total) on the room;
- the score reaching everyone in the room live;
- the support part defined now: it is written by L3 (gifts, wallet) with the gift itself.

Not in this proposal: gifts, coins and the wallet (L3), ranking lists of tappers or
supporters, the score counting towards levels (Q2: not now), tap effects other than the
app's own animation.

## Proposed contract (v1.8-live, additive; tag `live`)

### 1. The score on the room

`LiveRoom` gains `scoreParts` (as applied: `score` on the summary is the total):

```yaml
scoreParts:   # LiveScore
  type: object
  required: [total, tapPoints, supportPoints]
  properties:
    total:         { type: integer, format: int64, minimum: 0 } # tapPoints + supportPoints
    tapPoints:     { type: integer, format: int64, minimum: 0 } # 1 per counted tap
    supportPoints: { type: integer, format: int64, minimum: 0 } # 100 per coin (L3); 0 until then
```

`LiveRoomSummary` (hub cards) gains `score` (the total only, `int64`).

**Popular (owner, Q4):** `GET /live/rooms?tab=popular` orders live rooms by `score.total`,
highest first; ties by the newer start, then the room id (a stable order for the signed
cursor, CONVENTIONS §5). The cursor carries the score and the start of the last room.
Because the score changes while someone pages, a room can move between pages: the app
already drops duplicates by id (v1.3), and a room may be missed until the next refresh.
`new` and `following` keep their order.

The score belongs to one live (room). A new live starts at 0. An ended room keeps its final
score.

### 2. Tapping: `POST /live/rooms/{roomId}/taps`

- Signed-in viewers only. Guests without an account get 401 (Q1).
- The app batches taps and sends at most one request a second:

```yaml
LiveTapsRequest:
  required: [count]
  properties:
    count: { type: integer, minimum: 1, maximum: 50 } # taps since the last batch
LiveTapsResult:
  required: [accepted, score]
  properties:
    accepted: { type: integer, minimum: 0 } # taps counted from this batch
    score:    { $ref: LiveScore }           # the room's score after this batch
```

- **Counting rules (server):**
  - **10 a second:** the server keeps, per viewer and room, the time of the last counted
    batch. A batch may add at most `10 × seconds since then`, and at most 50. The first batch
    counts in full, up to 10.
  - **10 000 a live:** a viewer's counted taps in one room never go above 10 000.
  - **No self-cheering:** the host's own taps count 0. Seated guests and moderators count
    like any viewer (owner, Q3).
  - Taps past a limit are dropped. The answer is still 200 with `accepted` lower than
    `count`, so the app learns it hit the limit.
- Errors: 404 for an unknown room or one the caller may not see; 409 `LIVE_ROOM_ENDED` once
  the room has ended; 401 without an account.

### 3. Reading the score

- `GET /live/rooms/{roomId}` returns the current `score`.
- **Live updates:** the server writes the total into the media room's metadata as
  `score`, next to `seatsVersion` (CP-011), at most once every 2 seconds. Everyone in the
  room, guests included, sees the number change without polling.

### 4. Support (L3, defined now)

When L3 sends a gift paid in coins, the same database transaction adds `coins × 100` to
`supportPoints`. Nothing else may write it. Refunded or reversed gifts take their points
back. L3's proposal will spell this out; this proposal fixes the rate (100 points a coin).

### 5. Rate limit (CONVENTIONS §7)

| Endpoint | Limit |
| -------- | ----- |
| `POST /live/rooms/{roomId}/taps` | 120 / min per user (expected 60 / min at one batch a second; 2× headroom) |

### 6. Compatibility

Additive: new fields and one new path. Older apps ignore `score`. No change to existing
answers or codes.

## Data (DB)

- `live_room_scores`: `room_id` (PK, FK `live_rooms`), `tap_points` bigint, `support_points`
  bigint, `updated_at`.
- `live_room_tappers`: `room_id`, `user_id` (PK together), `counted` int (≤ 10 000),
  `last_batch_at` timestamptz. This table is what the 10-a-second and 10 000 limits are
  checked against, in the same transaction as the update to the score.
- Rows go with the room under the existing room retention.

## The app (not part of the contract)

- **Room bar:** under the title, a 🔥 and the total in the short form (12.4K), in place of the
  `@username` line while the live has points. Tapping it shows the split: taps and support.
- **Viewers tap** anywhere on the empty part of the live, with small rising hearts. In audio
  rooms that is the empty part of the stage; in video rooms the video. Taps are batched every
  second.
- When `accepted` is lower than `count` the hearts still show for the viewer. The number
  follows the server.

## Open questions for the owner

- **Q1. Guests without an account — decided:** **no** (they watch only).
- **Q2. Levels — decided:** **not now**; the score stays per live.
- **Q3. Seated guests and moderators — decided:** their taps **count**; the host's do not.
- **Q4. Hub — decided:** the score shows on the hub cards and **"Popular" is sorted by it**.
- **Q5. Abuse watch (new, follows Q3/Q4):** with the trend at stake, a host could fill seats
  with friends who tap. Each one is still held to 10 a second and 10 000 a live.
  Recommendation: also record taps per viewer so an admin can see the room's top tappers
  when a room looks suspicious. This stays in the database, with no public list and no
  contract change now.

## Work (after approval)

1. Contract: `openapi.yaml` (v1.8-live), CONVENTIONS §5 (popular order and cursor), §7
   row, §9 changelog, §10 rules; board decision.
2. API: migration (two tables and an index for the popular order), the taps endpoint with
   the limits, `score` on the room and summary, the popular order, metadata updates
   through the media provider; e2e tests for the limits (10 a second, 10 000, host 0,
   seated guest counted, guest 401, ended 409), the popular order and paging, and the real
   LiveKit metadata.
3. App: the room bar score, the split sheet, viewer tapping with hearts and batching (seated
   guests too), the score on hub cards; widget tests and goldens (Arabic, English, 360 dp).
