# CP-005 — Four independent level systems (owner-directed; formal approval pending)

**Status:** drafted 2026-10-20 from the owner's master brief (D72). The brief asks for the
endpoints, so this branch implements them as **contract v1.4-levels (draft)**: the paths and
schemas are added to `openapi.yaml`, tagged `levels` and `admin-levels`, and marked *draft*.
Nothing here changes an existing path, schema or error code. The owner signs off this document
(and the business decisions in §9) before the branch is merged.

## 1. Repository audit (what exists today)

| Needed by the brief | Found in the code (`fc86537`) |
| --- | --- |
| Gift transactions, gift catalogue | **None.** No `gifts` module, table or endpoint. The app shows placeholder gifts with no price (`KGiftPanel.preview`). |
| Wallet / virtual currency ledger | **None** (B5: purchases blocked; `docs/KNOWN_LIMITATIONS.md`). |
| Lucky-gift mechanics | **None.** |
| Games and game spending | **None.** |
| Existing levels, XP, badges, ranks | **None** in the API. The mobile previews show a test "weekly rank" chip only. |
| Admin dashboard | **None** (`apps/admin` is Phase 10, `docs/IMPLEMENTATION_PLAN.md`). |
| RBAC | `users.role` (`USER`, `ADMIN`) exists; no guard reads it yet. |
| Notifications | **None.** |
| Audit trail | `audit_logs` (append-only, `AuditService`). Reused. |
| Background jobs | `BackgroundTasks` (in-process). No queue or broker. |

Consequences:

1. The engine can be built and tested end to end, but **nothing in production can earn points
   until a gifts / wallet / games module commits transactions** and calls the engine (§6).
2. Admin features ship as **admin API endpoints** guarded by `role = ADMIN`; the admin web UI
   arrives with the Phase 10 panel.
3. Level-up notifications are recorded (`level_history.notified_at` stays null) for the future
   notification service; nothing is pushed today.

## 2. Categories

Stable codes: `ATTRACTIVENESS`, `SUPPORT`, `WIZARD`, `GAMING` (paths use them in lower case).
Each has its own versioned configuration, multiplier, thresholds, user state, ledger entries
and history. One activity never credits a category that it does not qualify for (§5).

## 3. Points

`points = floor(sourceValue × multiplier)` per qualifying source transaction and category.

- `sourceValue` is a non-negative integer in the category's `valueUnit` (only `COIN` is
  defined: the smallest unit of the future wallet). No floating point anywhere: the API stores
  `NUMERIC(18,6)` multipliers and `BIGINT` points, and computes with exact decimal arithmetic.
- Rounding is **down** (never over-award); a value that rounds to 0 creates no entry.
- Amounts travel as strings in JSON (`"12500"`) so 64-bit values survive JavaScript clients.

## 4. Configuration versions

A category has at most one `PUBLISHED` version at a time; versions are `DRAFT → PUBLISHED →
ARCHIVED` and a published version is never edited. A draft holds:

- `multiplier` (> 0, ≤ 1 000 000, at most 6 decimals) and `valueUnit` (`COIN`);
- `levels`: 1–200 rows `{levelNumber, nameAr, nameEn, requiredPoints, iconKey}`; level numbers
  are 1..n with no gaps, level 1 requires 0, and thresholds strictly increase;
- `reversalPolicy`: `REVERSE_POINTS` (a refund subtracts what it earned; the level follows the
  points) or `KEEP_LEVEL` (points are subtracted but the shown level never drops);
- `luckyGiftsCountAsSupport` (SUPPORT only, default **false**, see §9).

Publishing takes `recalculation`: `PRESERVE_POINTS` (default: totals stay, levels are
re-evaluated against the new thresholds) or `RECOMPUTE_FROM_LEDGER` (every user's total is
rebuilt as Σ `floor(sourceValue × newMultiplier)` over their ledger, through compensating
`ADJUSTMENT` entries; history rows record any level change with reason `CONFIG_PUBLISHED`).
`GET …/preview` shows the user distribution per level under a draft before publishing.

A category with no published version, or disabled, is `UNAVAILABLE`: user endpoints return it
with no level, and the engine ignores its events (they are recorded as `SKIPPED`).

## 5. Activity → category mapping

| Source event (server-side only) | ATTRACTIVENESS | SUPPORT | WIZARD | GAMING |
| --- | --- | --- | --- | --- |
| `GIFT_COMMITTED`, normal gift | recipient | sender | — | — |
| `GIFT_COMMITTED`, lucky gift | recipient | sender **only if** `luckyGiftsCountAsSupport` | sender | — |
| `GAME_SPEND_COMMITTED` | — | — | — | spender |
| `GIFT_REVERSED` / `GAME_SPEND_REVERSED` | reverses exactly the entries the original created, per the category's `reversalPolicy` |
| Lucky-gift winnings, game prizes or rewards | never an event; never points |
| Failed / cancelled / uncommitted transactions | never an event; never points |

Wizard counts the **value of lucky gifts sent**, never what they return. (The asset pack's
`levels.json` labels the magic track "هدايا الحظ (المردود)" — lucky-gift *returns*; the brief
overrides it, and the app's copy says "lucky gifts you send".)

## 6. Ingestion (no public endpoint)

Producers (the future gifts and games modules) call `LevelEventsService.ingest(event)` inside
or right after their own committed transaction:

```
{ type: GIFT_COMMITTED,      sourceTransactionId, senderUserId, recipientUserId, value, lucky }
{ type: GAME_SPEND_COMMITTED, sourceTransactionId, userUserId, value }
{ type: GIFT_REVERSED | GAME_SPEND_REVERSED, sourceTransactionId }
```

- Each event is recorded once in `level_source_events` (unique `(type, source_transaction_id)`).
- A `SourceTransactionVerifier` port confirms the transaction is committed and matches the
  payload (users, value, lucky flag). Until a gifts/games module provides it, the default
  verifier rejects everything (`SOURCE_UNAVAILABLE`), so no production path can award points
  from unverified data. Clients can never submit events, points or levels.
- `points_ledger` has unique `(category_id, source_type, source_transaction_id, entry_type)`
  for `EARN` and `REVERSAL`, so retries, duplicate deliveries and parallel workers cannot
  credit or reverse twice. The user's state row is locked (`SELECT … FOR UPDATE`) while its
  total and level change.

## 7. Endpoints (bearer auth on all; admin ones need `role = ADMIN`)

User:

- `GET /api/v1/levels/me` → the four summaries.
- `GET /api/v1/levels/me/{category}` → summary + the level ladder.
- `GET /api/v1/levels/me/history?category&cursor&limit` → level transitions.
- `GET /api/v1/levels/me/points-history?category&cursor&limit` → ledger entries (public
  fields only: no source ids, no admin reasons).

Admin (`/api/v1/admin/levels/…`): list/get/patch categories; create, get, replace, validate,
preview and publish versions; a user's four states; recalculate a user; manual adjustment
(`reason` required, `Idempotency-Key` required); reconciliation (`DRY_RUN` / `REPAIR`) and its
report; failed events list and retry; level reports; level audit log. Every mutation is
written to `audit_logs` with before/after values.

New error codes: `LEVEL_CONFIG_INVALID` (422, `details` list the problems),
`LEVEL_VERSION_NOT_DRAFT` (409). Existing codes cover the rest (`AUTH_FORBIDDEN` for non-admins,
`NOT_FOUND`, `VALIDATION_FAILED`, `IDEMPOTENCY_CONFLICT`).

## 8. Data (migration `20261020090000_levels`, additive)

`level_categories`, `level_category_versions`, `level_definitions`, `user_level_states`,
`points_ledger` (append-only: runtime role has no UPDATE/DELETE), `level_history`
(append-only), `level_source_events`, `level_reconciliation_runs`. The four categories are
seeded **disabled with no version**; no multiplier or threshold is seeded.

## 9. Business decisions the owner must approve before activation

1. **Multiplier and unit per category** (e.g. 1 point per coin?). Not seeded.
2. **Thresholds and number of levels** per category (the asset pack draws 11 tiers over levels
   1–100: 1–9, 10–19 … 90–99, 100). Not seeded.
3. **Refund policy**: `REVERSE_POINTS` or `KEEP_LEVEL`.
4. **Lucky gifts in Support** as well as Wizard (default no).
5. **On a new version**: `PRESERVE_POINTS` or `RECOMPUTE_FROM_LEDGER`.
6. **Benefits**: are levels display-only, or do they unlock anything? (Display-only here.)
7. **Visibility**: are a user's levels public on their profile? (Only `/me` here.)
8. **Granular admin permissions** (view / edit drafts / publish / adjust / reconcile) — today
   every admin endpoint needs `role = ADMIN`; finer roles come with the Phase 10 RBAC work.

### 9.1 Owner answers (2026-10-20)

| # | Answer | Effect |
| --- | --- | --- |
| 1 | Multiplier **0.1** (1 point per 10 coins) | In the preset drafts (`pnpm levels:admin draft-preset`) |
| 2 | 100 levels, the pack's 11 tiers; difficulty by band (1–10 extremely easy … 81–99 hard, 100 very hard; "11–40" read as 31–40) | `level-preset.ts`: 10 / 50 / 150 / 400 / 1,000 / 2,500 / 6,000 / 15,000 / 100,000 points per level; level 100 = 546,090 points (5,460,900 coins). Level names follow the tiers (Iron … Legend) |
| 3 | Gifts are never refunded | Reversal events stay supported for corrections only |
| 4 | Lucky gifts: sender's Wizard only (not Support); the recipient's Attractiveness still counts | `luckyGiftsCountAsSupport` false; mapping unchanged |
| 5 | A new version keeps points (`PRESERVE_POINTS`) | Admins publish with `PRESERVE_POINTS`; `RECOMPUTE_FROM_LEDGER` stays available but is not the policy |
| 6 | Display only | No benefits |
| 7 | Levels are public on the profile | `GET /users/{username}/levels` (levels, never points); badges under the name on every profile |
| 8 | Granular admin permissions | `LEVELS_VIEW`, `LEVELS_EDIT`, `LEVELS_PUBLISH` (also enabling/disabling a category), `LEVELS_ADJUST`, `LEVELS_RECONCILE`; role ADMIN **and** the permission; granted only by the migration role (`pnpm levels:admin grant`) and audited |
