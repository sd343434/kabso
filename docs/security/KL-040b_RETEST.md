# KL-040b — Re-test of the KL-040 findings after KL-045

| | |
| - | - |
| Reviewer | A7 (security engineer) |
| Date | 2026-10-16 |
| Subject | KL-045 (contract v1.3.1 implementation, `4af9512`) as integrated at commit `27bfd44` |
| Environment | Local PostgreSQL 16 and Redis 7, Node 22. The scratch database `kabso_kl013_empty_test` was emptied and migrated by the migration role; the API ran as the DML-only runtime role on its own port and Redis index. No superuser role was created or used. Up to two API processes ran at once |
| **Verdict** | **PASS** — every KL-040 finding is fixed. Two new findings (Low, Info) do not block hosting (see §4) |

The repository is public (D40). New open findings are listed with id, severity, one line and
status only. Reproduction details went to the coordinator.

## 1. Verdicts

| Id | Severity | Finding (KL-040) | Verdict |
| -- | -------- | ---------------- | ------- |
| SEC-035 | Medium | Unbounded stale-room sweep on the list path and in the sweeper | **FIXED** (`4af9512`) |
| SEC-036 | Medium | Blocklist text hygiene let invisible and format characters through | **FIXED** (`4af9512`), as specified by contract v1.3.1. A residual hidden-content channel that the v1.3.1 rules allow is tracked as SEC-039 |
| SEC-037 | Low | Malformed usernames returned 500 on profile and follow | **FIXED** (`4af9512`). Never 500. Undecodable percent-encoding gives 400 (pre-existing, SEC-040) |
| SEC-038 | Info | Signed cursors accepted sort keys outside the database's range | **FIXED** (`4af9512`) |
| QA-002 | — | Existing follower re-PUT on a private account | **FIXED** |
| Observation | — | `startRoom` did not re-check account status inside its transaction (suspension race) | **FIXED** |
| Observation | — | Heartbeat rate limit not checked against the heartbeat interval | **FIXED** (production refuses to boot) |
| Observation | — | Lenient numeric environment parsing | **FIXED** |
| Observation | — | Sweep-failure log had no error class or code | **FIXED** (see §5) |

### SEC-035 and `LIVE_HOSTING_ENABLED=true`

**From the security side, SEC-035 is cleared, and it no longer blocks `LIVE_HOSTING_ENABLED=true`.**
The list does no writes and stays fast at a 100k stale backlog. The sweeper drains in bounded,
non-overlapping batches. Two API processes never end a room twice. Timeouts are explicit and
failures are logged.

This clears only KL-040 condition 1 as far as the code goes. **The PP-32 production-scale load
test and B1 (media provider) remain separate, open gates** for enabling hosting in production. The
figures below come from a local machine, not from production-sized hardware.

## 2. What was run, and the results

Everything was run against the running API. "Pass" means the result was observed.

### 2.1 Project suites (independent re-run at `27bfd44`)

| Run | Result |
| --- | ------ |
| `prisma migrate deploy` as the migration role on the emptied database | pass |
| Unit tests (27 files) | 713 / 713 pass |
| e2e `kl045-v131`, `kl037-live-discovery`, `security/kl013-db-roles` | 105 / 105 pass |

### 2.2 SEC-035: stale-room backlog

The backlog was synthetic: stale LIVE rooms inserted by the runtime role, plus one real fresh room
that sent heartbeats.

**List (`GET /live/rooms`), 20 sequential calls per tab, limits 20 and 50, sweeper off:**

| Stale rooms | popular median | new median | following median | p95 (all tabs) | 30 concurrent calls |
| ----------- | -------------- | ---------- | ---------------- | -------------- | ------------------- |
| 20,000 | 7.1 ms | 7.2 ms | 8.3 ms | ≤ 15.0 ms | all 200, 163 ms wall |
| 40,000 | 7.4 ms | 7.1 ms | 8.0 ms | ≤ 19.8 ms | all 200, 96 ms wall |
| 100,000 | 8.4 ms | 6.6 ms | 8.0 ms | ≤ 16.9 ms | all 200, 119 ms wall |

- Each size was measured again after `ANALYZE`, with the same results (medians 6.5–8.3 ms).
- In KL-040, 20k stale rooms gave 4.3–4.7 s, and 40k gave a 500 on every list call.
- **No writes:** LIVE, ENDED, audit and timeout-audit counts were identical before and after every
  window. The table write counters on `live_rooms` moved only by the real host's own heartbeats.
- The fresh room was listed on every tab. No stale room appeared on any tab.

**Other read paths** (pass):

| Read | Result |
| ---- | ------ |
| Room detail of a stale room | 200 ENDED / HEARTBEAT_TIMEOUT, `endedAt` = stored `lastHeartbeatAt`, 21 ms. Exactly one row ended and one `live.room.timeout` audit. A repeat read wrote nothing |
| Profile of a stale host | `liveRoomId: null`, 28 ms. Exactly that one room ended, with one audit |
| Following tab | Only the fresh room, with 20 stale followed hosts present |

**Sweeper with two API processes** (separate OS processes, batch sizes 500 and 317, interval 2 s),
run twice on a backlog of about 100,000 rooms:

| Check | Result |
| ----- | ------ |
| Drain time (from the first process start) | 18.6 s and 24.1 s |
| Rooms ended twice (duplicate timeout audits) | 0 |
| Timed-out rooms without exactly one audit | 0 |
| `ended_at = last_heartbeat_at` | 300,017 / 300,017 timed-out rooms |
| Rooms per transaction | Never above the configured batch size |
| Overlapping sweeper transactions inside one process | 0 (110 + 141 transactions, sampled every 15 ms) |
| Runs stopped by their per-run budget | Yes: `time_budget` after 89 batches, `batch_budget` after 100 |
| Batch transaction time | Median 52–100 ms, max 413 ms |
| List latency on both processes while sweeping | Median 43–50 ms, max 222 ms |
| Real hosts whose rooms were being swept, sending heartbeats | 409 `LIVE_ROOM_ENDED`, exactly one timeout audit each |
| A fresh room heartbeating during the sweep | Stayed LIVE |

**One process at the maximum batch size** (`LIVE_SWEEP_BATCH_SIZE=5000`, interval 15 s):

- 100k rooms drained in about 51 s.
- Each batch took 0.9–1.2 s, well under the 8 s statement timeout.
- The first run stopped at its time budget after 11 batches.

**Timeouts and failure handling:**

| Check | Result |
| ----- | ------ |
| Row of a stale room locked by another transaction; room detail and profile read it | Cancelled by the 8 s `statement_timeout` (8,038 ms, SQLSTATE 57014 in the log) |
| Same locked row, with the sweeper running | The sweeper skipped it (`SKIP LOCKED`) and drained everything else. It ended the room within one run of the lock being released |
| `audit_logs` locked for 20 s while a 3,000-room backlog waited | Each batch was cancelled at the statement timeout and rolled back: no room half-ended (3,000 LIVE / 0 ENDED throughout). Each failure was logged with error class and code. The next run after unlock ended all 3,000 with exactly 3,000 audits |

### 2.3 SEC-036: text hygiene (displayName and title)

| Check | Result |
| ----- | ------ |
| sha256 of the five vendored Unicode 17.0.0 / Emoji 17.0 files | Match the pinned values in `data/README.md` and an independent download from the same pinned `unicodetools` commit. unicode.org was unreachable from this environment |
| Regenerating `text-hygiene.generated.ts` from the vendored files, and from the independent download | Byte-identical to the committed file (83,580 bytes) |
| All 1,114,112 code points, alone and at the start, middle and end of a value, compared with an independent reference implementation of §6 rules 2–5 built from the downloaded data | 0 mismatches (title rules); displayName never accepts what the reference rejects |
| Each rejected class inside a name (`ab_cd`) and alone | Cc, Zl, Zp, Co (137,468), Cs (2,048), Cn (814,730): 0 accepted. Cf: only ZWNJ and ZWJ accepted, and only inside a name. Default_Ignorable: only ZWNJ, ZWJ and the 260 variation selectors accepted, and only inside; none accepted alone |
| Every RGI emoji sequence (3,953) after a name | All pass (title and displayName) |
| Over HTTP: the KL-040 invisible-character probe, plus 77 must-reject cases on `POST /auth/register` and `POST /live/rooms` | All rejected, `invalid_format`. Cases: fillers; U+00AD; U+034F; U+2061–U+2064; U+180E; Khmer inherent vowels; tag text; non-RGI flag tags; U+E0001; U+2028/U+2029; `\n` and `\t` at either end; U+FFF9–U+FFFB; musical format characters; U+2800, U+FFFC, U+1D159; private use; unassigned; noncharacters; lone surrogates; U+1BCA0–U+1BCA3; U+0600–U+0605; U+06DD; bidi controls; misplaced variation selectors and joiners; zalgo with a selector |
| Over HTTP: 39 must-accept cases | All accepted. Cases: Arabic (tashkeel, tatweel), Persian and Urdu with ZWNJ, Kurdish Sorani and Kurmanji, Hebrew, Devanagari and Sinhala with ZWJ, Chinese, Japanese with U+3000, an ideographic variation sequence, Korean, Thai, Mongolian free variation selector, emoji ZWJ, keycap, regional and tag flags, skin tones, an Emoji 17.0 ZWJ sequence, NBSP inside, Zs/BOM trimming |
| Length interaction | 80 graphemes / 160 code points accepted; 81 graphemes, 161 code points and 1,001 characters → `too_long`. A rejected character takes precedence over length |

### 2.4 SEC-037, SEC-038, QA-002 and the observations

| Check | Result |
| ----- | ------ |
| 28 malformed usernames (NUL anywhere, too long, upper case, separators, encoded slash, 5,000 chars, …) on GET profile, PUT and DELETE follow | 0 × 5xx. NUL and every decodable malformed name → the identical 404 body. Undecodable percent-encoding → 400 before auth (SEC-040) |
| Profile response time, 40 interleaved rounds | Unknown 6.05 ms, suspended 6.06 ms, deleted 5.87 ms (no measurable difference). Malformed names answer faster (≈ 3.9 ms) because they are refused without a query. Malformedness follows from the public username pattern, so no account information leaks |
| 33 validly signed cursors at and beyond the bounds (independent signer): `n` 0 / 2³¹−1 / 2³¹ / −1 / fractions / 1e308; `s` 0 / 9999-12-31T23:59:59.999Z / +1 ms / 8.64e15 / negative / strings / Infinity; duplicate keys; `__proto__` | At the bounds → 200; beyond them → 400 `cursor`; 0 × 500 |
| QA-002 | Existing follower re-PUT on a private account → 200, no new edge. New follower → 403. Unfollow allowed; re-follow after unfollow → 403 |
| Suspension racing go-live, using the real `AccountLifecycleService` in a second process, both orders forced with database locks | Go-live first → 201, then the suspension ends the room as `HOST_SUSPENDED` with its audit. Suspension first → go-live 401, no room created |
| Heartbeat headroom | Production refuses buckets below 2× the expected cadence (for example, the default 12/min with a 5–8 s interval). Default 15 s interval and 12/min boot |
| Numeric settings | `1e1`, `0x10`, padded, empty, leading zero, sign, `15.0`, Arabic digits, trailing newline and > 2⁵³ are all refused. `LIVE_SWEEP_BATCH_SIZE` is 1–5000, default 500 |

### 2.5 Regression of KL-040 §2

The KL-040 probe scripts were re-run unchanged. The output was the same as in KL-040, except for the
fixed items: NUL usernames now 404, the forged max-date cursor now 400, and invisible titles, tag
characters, repeated selectors and lone surrogates now rejected.

| Area | Result |
| ---- | ------ |
| IDOR: heartbeat and end on another user's / a missing / malformed / upper-case room id → identical 404; ended room → 409 for host, 404 for others; unauthenticated → 401 on every v1.3 route | pass |
| Enumeration: unknown, suspended, deleted, pending and malformed usernames → identical 404 on profile and follow; no email in any response | pass |
| Rate limits: first 429 at call 61 (follow, shared bucket, incl. no-op/404/self), 13 (heartbeat, own and others' room), 11 (go-live, valid and invalid), 31 (end), 301 (list), 301 (profile), 601 (default bucket); endpoint buckets independent of the default | pass, identical to KL-040 |
| Cursor scope and tamper checks; key separation from `RATE_LIMIT_KEY_SECRET` | pass |
| Concurrency: 10 parallel go-lives → one room; parallel heartbeat/end → one end audit; 36 concurrent follow/unfollow consistent; follow vs deactivation | pass |
| `LIVE_HOSTING_ENABLED=false`: go-live and heartbeat 503 `LIVE_HOSTING_UNAVAILABLE` for everyone; end allowed for the host, 404 for others | pass |

## 3. Open findings (new)

| Id | Severity | Description | Status |
| -- | -------- | ----------- | ------ |
| SEC-039 | Low | Some invisible code points that the v1.3.1 rules allow can carry hidden content in titles and display names: a variation selector after any base character, and some non-ignorable invisible marks such as U+16FE4. A contract patch should limit selectors to standardized or registered variation sequences | Open (contract patch, A4) |
| SEC-040 | Info | A path segment with undecodable percent-encoding (profile, follow, room id) answers 400 before authentication instead of the contract's 404. It reveals nothing and never gives a 500. Pre-existing | Open |

## 4. Conditions

1. KL-040 conditions 1–3 (SEC-035, SEC-036, SEC-037/038) are met.
2. **SEC-039** before public discovery goes live with real users. It does not block
   `LIVE_HOSTING_ENABLED=true` in internal builds. **SEC-040** in the next API patch, or record it in
   the contract as accepted behaviour.
3. Enabling hosting in production still requires PP-32 and B1 (see §1).

## 5. Observations (no finding id)

- Room detail and profile reads end a stale room themselves. If that row is locked for more than 8 s,
  the read fails with 500 at the statement timeout. Only the API's own short transactions lock
  these rows (a sweeper batch at the maximum batch size holds them for about 1 s). Falling back to the
  computed ENDED view when the row is locked would remove the case.
- The sweep-failure log records Prisma's wrapper code (for example P2039) instead of the
  PostgreSQL SQLSTATE (57014). The SQLSTATE is still in the logged error message.
- At `LIVE_SWEEP_BATCH_SIZE=5000`, list latency on the sweeping process briefly reached about
  1 s. The default of 500 showed no such effect. The batch size should stay near the default
  unless PP-32 shows otherwise.
- `AccountLifecycleService` transactions use Prisma's default 5 s timeout and no statement timeout.
- The heartbeat headroom check enforces 2×, while §7 documents 3× for the defaults. Outside
  production nothing is checked.
- Pre-existing placement rule (v1.2, internationalization only): a ZWJ at the end of a word
  (old-style Malayalam chillu) and a ZWNJ before a space are rejected.
- Unchanged from KL-040 and out of KL-045 scope: the runtime role can write `live_categories`;
  raw database status changes bypass `AccountLifecycleService`; mobile has no avatar/cover URL
  allowlist.

## 6. Not tested

- Production-sized hardware, network latency and a managed database: PP-32.
- The canonical unicode.org copies of the Unicode files, which were unreachable. Hashes were
  verified against the pinned `unicodetools` commit instead.
- Grapheme segmentation uses the runtime's ICU data, not the vendored Unicode 17 data. All 3,953
  RGI sequences pass, but how future Unicode versions segment text was not assessed.
- Clock skew between API instances (the freshness predicate assumes synchronized clocks).
