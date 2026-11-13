# Kabso Live — Media Architecture Audit (Phase 0)

> **Superseded in part (2026-11-09):** the owner owns **no** Hetzner server (AX41/AX42 were options only), and the
> Hetzner prices here were search-index readings. See `PHASE_0_INFRASTRUCTURE_READINESS.md`,
> `HETZNER_SERVER_COMPARISON.md` (VERIFIED prices) and `PRODUCTION_COST_MODEL.md`.

Status: **Phase 0 only — audit and planning.** No code, server, DNS, account or purchase was touched.
Audited tree: `origin/staging` at `809063b` (2026-11-09). Companion: [`COST_MODEL.md`](./COST_MODEL.md).

Evidence labels used in this document:

- **CODE** — read in this repository (file path given).
- **SOURCED** — a published figure found through web search on 2026-11-09. Pages could **not** be fetched in this
  session (the sandbox's network blocks `hetzner.com`, `docs.hetzner.com`, `bunny.net`, `livekit.io`); the figure is the
  search index's reading of the page named. Treat it as "to be confirmed on the live page", not as VERIFIED.
- **ESTIMATE** — reasoning or arithmetic; the reasoning is shown.

Nothing in this document is labelled VERIFIED in the strict sense (fetched official page), because no official page
could be fetched. See `COST_MODEL.md` §0.

---

## 0. Executive summary

1. **What exists today is a WebRTC SFU product, not a broadcast product.** Every live mode (SOLO, PK, MULTI, AUDIO,
   PODCAST, STREAMER, the browser studio) publishes and plays over **LiveKit** (`livekit/livekit-server:v1.9.1`,
   `livekit_client 2.13.1`, `livekit-client` JS, `livekit-server-sdk`). There is **no RTMP, SRT, WHIP, HLS, DASH,
   Egress, Ingress or recording pipeline** anywhere in the repo (CODE: grep over `apps/`, `infra/`).
2. **All interactive state rides the media session.** Chat, gifts, lucky/level/gift tickers, seats, PK events, kicks,
   stickers, bullets, seat emoji, boosts, program, watch-together and streamer layout are sent by the API as LiveKit
   **reliable data messages** (`RoomService.sendData`); the score/taps, seat version, room info and streamer version
   ride **LiveKit room metadata**; seats/mute are enforced by **LiveKit participant permissions**. Clients never
   publish data (`canPublishData: false`). A viewer who is not in the LiveKit room receives none of it.
3. **Verdict on the proposed SRS/RTMP → FFmpeg → HLS → Nginx-edge network:** **not compatible as a replacement** for
   the current app. It cannot carry PK, seats/co-host, audio rooms, podcast speakers or the second camera, and it would
   put 6–15 s between a gift and the host's reaction. It is only useful as an **add-on** for (a) viewer-only
   distribution of very large SOLO/STREAMER rooms and (b) recordings/replays — and the clean way to build that add-on
   is **LiveKit Egress → HLS**, not a separate RTMP ingest tier.
4. **At the stated targets the HLS plan has a structural cost problem:** 1,000 viewers over 250 rooms is **4 viewers
   per room** on average. HLS edge caching pays off with many viewers per stream; here the network would package (and,
   for ABR, transcode) 250 streams for a cache-hit ratio near zero, while an SFU just forwards the simulcast layers the
   phone already encodes.
5. **Recommendation:** keep LiveKit (board D3). Phase 1 = **self-hosted LiveKit, multi-node over Redis, on dedicated
   Hetzner AX servers** (the owner's AX41/AX42 first), media moved off the all-in-one staging VPS, embedded TURN/TLS,
   Prometheus metrics, and three small app-side settings to review (adaptive stream, dynacast, a lower layer for the
   streamer's screen). Bunny CDN and HLS stay out of Phase 1; LiveKit Egress → HLS → Bunny is a later, optional phase.
6. **Cost:** at the targets, self-hosted LiveKit on Hetzner dedicated is in the **≈ €150–450/month** range
   (ESTIMATE, `COST_MODEL.md` option D) versus **≈ $16k/month** on LiveKit Cloud (ESTIMATE from SOURCED list prices,
   option E) and **≈ $450–1,300/month** for the proposed origin+edge network (options A–C), which would still need a
   WebRTC tier for the interactive modes.

---

## (a) Application architecture

| Part | Stack | Where |
|---|---|---|
| Mobile app | Flutter (GoRouter, Riverpod, gen-l10n), Android + iOS + web build | `apps/mobile` |
| API | NestJS + Prisma (PostgreSQL 16), Redis 7.4 (rate limits, locks, caches) | `apps/api` |
| Admin panel | React (Vite), static, served by Caddy; staff "watch a live" via `livekit-client` (subscribe only) | `apps/admin` |
| Browser studio «استوديو البث» (D247) | React, static; publishes camera / screen / mic over WebRTC to LiveKit | `apps/studio` |
| Website | static HTML | `infra/deploy/site` |
| Deploy bundle | docker compose (postgres, redis, migrate job, api, livekit, caddy), systemd update timer | `infra/deploy` |
| CI | one workflow, path-filtered jobs (api, admin, studio, mobile, android, ios, contracts, site, secrets, deploy-image, staging APK) | `.github/workflows/ci.yml` |

Contract-first rules: `docs/contracts/CONVENTIONS.md`, `docs/contracts/openapi.yaml`; decisions in
`docs/AI_WORKFORCE_BOARD.md` (D3 = "LiveKit as default live provider behind `LiveMediaProvider`"; D93 = "LiveKit
locally, LiveKit Cloud in production with the owner's keys (B1)"). B1 (provider credentials: Cloud vs self-host) is
still open in `docs/KNOWN_LIMITATIONS.md`.

## (b) The streaming stack that actually exists (verified in code)

### b.1 Media server
- `infra/deploy/docker-compose.yml`: service `livekit`, image `livekit/livekit-server:v1.9.1` (digest-pinned), config
  `/etc/kabso/livekit.yaml`, ports **7881/tcp** (ICE-TCP fallback) and **7882/udp** (single UDP mux) published;
  signalling `7880` only on the internal network, reached through Caddy at `wss://live.<domain>`.
- `infra/deploy/install.sh` (lines ~176–197) generates `livekit.yaml`:
  `port: 7880`, `rtc.tcp_port: 7881`, `rtc.udp_port: 7882`, `rtc.use_external_ip: true`, one key pair, webhook to
  `http://api:3000/internal/livekit/webhook`, `logging.level: info`.
  **Absent:** `redis` (→ single node, no clustering), `turn` (→ **no TURN/TURN-TLS**), `prometheus_port` (→ no
  metrics), `room.*` limits, `region`/node selector, Egress/Ingress. No STUN/TURN servers are configured on any client
  (`ConnectOptions.rtcConfiguration` left at default; CODE: `live_media_engine.dart`, `studio-live.ts`).
- `docs/DEPLOYMENT.md` §11.5 says it plainly: "Not verified yet: … WebRTC media through the server's firewall (a TURN
  server may be needed for some mobile networks)".
- Staging runs **everything on one VPS** (API, Postgres, Redis, LiveKit, Caddy) at `live.kabsolive.com`
  (`docs/DEPLOYMENT.md` §11 host table).

### b.2 Provider abstraction (board D3)
- Port: `apps/api/src/modules/live/media/live-media.provider.ts` — `LiveMediaProvider` with `issueToken`, `closeRoom`,
  `removeParticipant`, `listRooms`, `listIdentities`, `parseWebhook`, `listParticipants`, `setPermission`,
  `roomMetadata`/`setRoomMetadata`, `sendData`, `broadcastData`, `setParticipantAttributes`.
- Adapter: `apps/api/src/modules/live/media/livekit-media.provider.ts` (`LiveKitMediaProvider`, plus
  `UnconfiguredMediaProvider` while `LIVEKIT_*` is unset). `DataRetry` (`media/data-retry.ts`, D319) retries
  broadcasts through LiveKit's short "room not open" windows (~12 s).
- **Limit of the abstraction:** it abstracts the *server-side control plane*. The *client* side is LiveKit-specific
  (`LiveKitMediaEngine`, `LiveKitPkOpponentMedia` in Flutter; `livekit-client` in studio and admin). The port's
  semantics (rooms, participants, permissions, data messages, metadata) are SFU semantics; an HLS backend could not
  implement most of it.

### b.3 Tokens, room and stream IDs
- `POST /api/v1/live/rooms/{roomId}/media-token` (`live.controller.ts:310`) → `LiveMediaService`
  (`live-media.service.ts`); TTL `MEDIA_TOKEN_TTL_SECONDS = 600`, staff `STAFF_TOKEN_TTL_SECONDS = 120`.
- **Media room name = the live room's UUID.** Identities: user id, `guest:<uuid>` (accountless watchers),
  `team:<adminId>:<nonce>` (staff, D260), PK identities (`pkIdentity(match, base)`), second-camera identity
  (`secondCameraIdentity(hostUserId)`, D201).
- Grants (`issueToken`): host/seated guest = publisher with `canPublishSources` (camera, microphone; STREAMER also
  `screen_share`, `screen_share_audio`); viewers = `canPublish: false`, **`hidden: true`** (no viewer roster cost);
  `canPublishData: false` for everyone; second camera = `subscribe: false`.
- PK opponent token (`live-pk.service.ts:~2255`): subscribe-only, hidden, into the **other** room, TTL 600.
- Rate limits: `RATE_LIMIT_LIVE_MEDIA_TOKEN_USER 120/3600`, `…_GUEST_IP 60/3600` (`env.schema.ts:534`).

### b.4 Webhooks and sweeping
- `POST /internal/livekit/webhook` (`live.controller.ts:1052`), signed with the LiveKit key; Caddy answers `/internal/*`
  with 404 on public hosts. Mapped events: `participant_joined`, `participant_left`, `room_finished`.
- Sweeper (`live-media.service.ts:~952–1021`): every `LIVE_SWEEP_INTERVAL_SECONDS` (15 s) it calls `listRooms()` and
  `listIdentities(room)` for every open room. Host liveness also uses `POST …/heartbeat` (15 s interval, 45 s stale).

### b.5 Data messages (all server-sent)
Topics (CODE, `apps/api/src/modules/live`): `chat`, `gift`, `lucky`, `level`, `pk`, `streamer`, `watch`, `program`,
`kick`, `sticker`, `bullet`, `seat-emoji`, `boost`; direct `sendData` for seat invites/effects (`live-seats.service.ts`)
and PK (`live-pk.service.ts`). Room metadata carries `seatsVersion`, `score`, `hostCherries`, `roomCherries`,
`roomInfoVersion`, `streamerVersion` (`live_media_engine.dart` `_readMetadata`). Taps (`POST …/taps`,
`live-taps.service.ts`) update the score that is pushed through metadata (`live-metadata.service.ts`).
Global tickers (lucky win, gift, level) fan out to **every LIVE room** with one `RoomService.SendData` call per room,
concurrency 8, up to `LUCKY_TICKER_MAX_ROOMS = 5000` (`live-lucky-ticker.service.ts:~175`).

### b.6 Modes (Prisma `LiveRoomMode`, `apps/api/prisma/schema.prisma:606`)
| Mode | Media | Seats |
|---|---|---|
| SOLO | host camera + mic; optional guests (D174); optional second camera (D201/D243) | — |
| PK | two SOLO rooms; each client also opens a **second, hidden, subscribe-only** connection to the opponent room (`live_pk_media.dart`) | — |
| MULTI | video guests | `[4, 6, 9, 12]` tiles incl. host (`live.schemas.ts:77`) |
| AUDIO | mic only, active-speaker UI | `[5, 10, 15, 20]` |
| PODCAST (D212) | audio, host + up to 3 speakers, raise hand | 4 |
| STREAMER (D213) | phone screen 720p30 **2.5 Mbps, `simulcast: false`** + front-camera bubble + mic (`live_media_engine.dart:~1300`) | none, no PK |
| Studio (D247) | browser publishes camera (OBS Virtual Camera is listed first, `apps/studio/src/devices.ts`), screen, mic; `Room({adaptiveStream:false, dynacast:true})`, VP8 + RED (`studio-live.ts:100`) | — |

"OBS support" today means **OBS Virtual Camera into the browser studio over WebRTC**; there is no RTMP endpoint.

### b.7 Simulcast / adaptive stream / dynacast (CODE + package source `livekit_client-2.13.1/lib/src/options.dart`)
- Flutter `lk.Room()` is created with **default `RoomOptions`**: `adaptiveStream = false`, `dynacast = false`;
  `VideoPublishOptions.simulcast = true`; default codec `vp8` with a backup codec.
- Quality presets (`LiveVideoQuality`, D154g/D160): `normal` = LiveKit 720p default (layers 720/360/180; 720p cap
  1.7 Mbps @30), `smooth` = 480p @15 0.6 Mbps, `high` = 1080p (3 Mbps) with layers 1080/720/360, offered only when the
  camera captures 1080p and the uplink ≥ 4 Mbps for 10 s (`UplinkMeter`).
- Admin watch: `Room({adaptiveStream:true, dynacast:false})` (`apps/admin/src/live-media.ts:157`).
- Consequence: on phones the publisher always encodes all layers (no dynacast) and each viewer is offered the top
  layer of every visible track regardless of tile size (no adaptive stream); only the SFU's congestion control lowers
  it. For MULTI with 12 video tiles this is the most expensive case. The STREAMER screen has a **single 2.5 Mbps
  layer**, so a weak viewer cannot be served a lower one.

### b.8 Recording / Egress / HLS
- **None.** The only "recording" (`PUT /live/rooms/{id}/recording`, `live-tools.service.ts:609`, D201) is a ≤ 60 s clip
  recorded **on the host's phone** with a room indicator. No LiveKit Egress, no Ingress, no HLS, no RTMP, no VOD.

## (c) Where publishing and playback live

| Role | File |
|---|---|
| Host publish (camera/mic, quality, uplink meter, beauty/DeepAR pipeline) | `apps/mobile/lib/features/live/data/live_media_engine.dart` (`LiveKitMediaEngine.publish`, `_connect`, `_applyEncodings`) |
| Host screen (STREAMER) | same file `publishScreen()`; `apps/mobile/lib/features/live/data/streamer/live_screen_share.dart`, `live_streamer_platform.dart` |
| Host UI | `apps/mobile/lib/features/live/go_live_screen.dart`, `presentation/go_live/*` (audio room, podcast room, quality sheet, seat tiles) |
| Viewer playback | `apps/mobile/lib/features/live/live_room_screen.dart` (joins via `LiveMediaEngine.join`; renders `lk.VideoTrackRenderer`), `presentation/hub/live_room_swipe.dart` |
| PK opponent | `apps/mobile/lib/features/live/data/live_pk_media.dart` |
| Camera FX | `apps/mobile/packages/kabso_camera_fx`, `data/beauty/*` |
| Browser studio publish | `apps/studio/src/studio-live.ts`, `Stage.tsx`, `devices.ts`, `ObsHelp.tsx` |
| Staff watch | `apps/admin/src/live-media.ts` |
| API token / control | `apps/api/src/modules/live/live-media.service.ts`, `media/*`, `live.controller.ts` |

## (d) Auth, realtime channel, room management
- Auth: API bearer tokens (app, studio), `__Host-` session cookie (admin). Media tokens are short-lived LiveKit JWTs
  minted by the API after the API's own checks (blocked/kicked users, guests allowed, host permission D93/D295).
- **There is no WebSocket server in the API** (no `@WebSocketGateway`, no socket.io). The LiveKit signalling
  connection is the app's only realtime downlink; everything else is REST (+ FCM push, D152).
- Room lifecycle: `POST /live/rooms` → LIVE in Postgres; host joins LiveKit; heartbeats; `POST …/end` or sweeper/
  webhook ends it and `closeRoom` deletes the media room. Seats: `live-seats.service.ts` + `live-seats.store.ts`
  (Redis), enforced with `setPermission`. Kicks: `removeParticipant`.

## (e) Infrastructure
- Compose: `infra/deploy/docker-compose.yml` (prod-style single server), `/docker-compose.yml` (local dev: Postgres,
  Redis, optional MinIO).
- Caddy: `infra/deploy/Caddyfile` — `<domain>` site, `api.`, `admin.` (CSP allows `wss://live.<domain>`; extra origins
  via `KABSO_ADMIN_MEDIA_ORIGINS`), `studio.` (`KABSO_STUDIO_MEDIA_ORIGINS`), `live.` (LiveKit signalling +
  `/app/` APK mirror).
- Env: generated on the server by `install.sh` into `/etc/kabso/*.env` (never in git); `LIVEKIT_URL`,
  `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`; production requires `wss://` (`env.schema.ts:1728`).
- Firewall (`install.sh`): 22, 80, 443/tcp+udp, 7881/tcp, 7882/udp.
- Update timer: `infra/deploy/systemd/kabso-update.timer` every 5 min → `update.sh` (ff-merge branch, pull CI image,
  migrate, restart what changed, build admin/studio, mirror APK).
- APK mirror: `infra/deploy/mirror-apk.sh` → `https://live.<domain>/app/` (D330).
- CI: LiveKit-real e2e specs (`apps/api/test/*livekit-real*.e2e-spec.ts`) are **skipped unless `LIVEKIT_TEST_URL`**
  is set; CI does not set it, so real-SFU behaviour is not exercised in CI. Studio e2e with a local LiveKit is local
  only (`ci.yml:255` comment).

## (f) Features that depend on sub-second latency

| Feature | Why it needs < 1 s | Files |
|---|---|---|
| PK battles (score bar, dares, rematch, boost FX, mute opponent) | both hosts and both audiences must see each other and the score at the same moment; viewers watch the opponent through a second WebRTC connection | `live-pk.service.ts`, `live-pk.ts`, `pk-dares/`, `live_pk_media.dart`, `widgets/kabso_pk_bar.dart`, `widgets/live_pk_dare.dart`, `widgets/live_pk_pages.dart` |
| Multi-guest video seats (MULTI 4–12) | guests converse with the host — two-way media | `live-seats.service.ts`, `seat_controls.dart`, `live_seat_tiles.dart`, `widgets/guest_seats.dart` |
| Audio rooms (5–20 speakers), active speaker rings | conversation; LiveKit `ActiveSpeakersChangedEvent` | `live_audio_room.dart`, `live_cp_seats.dart` |
| Podcast speakers + raise hand | conversation | `live_podcast_room.dart`, `live-podcast.spec.ts` |
| Co-host / SOLO guests (D174) | conversation | `test/features/live/solo_guests_d174_test.dart`, seats service |
| Gift reactions, lucky combo, gift effects | the host thanks the sender live; a 6–15 s gap breaks the loop | `live-gifts.service.ts`, `widgets/live_gift_effects_layer.dart`, `widgets/live_lucky_combo_button.dart` |
| Taps / hearts and score | metadata pushed with the video; must match what viewers see | `live-taps.service.ts`, `live-metadata.service.ts` |
| Chat, bullets, seat emoji, stickers | same — text arrives over data channel at WebRTC latency; with HLS video it would arrive *before* the picture | `live-chat.service.ts`, `live-bullets.service.ts`, `live-seat-emoji.service.ts`, `live-stickers.service.ts` |
| Streamer camera bubble + screen | two tracks composed on the viewer; host reacts to chat while playing | `live_media_engine.dart` (`publishScreen`), `presentation/streamer/streamer_widgets.dart` |
| Second camera main-feed switch (D201/D243) | participant attribute flips the feed instantly | `live-tools.service.ts` (`ATTR_MAIN_FEED`) |
| Kicks, mutes, seat permission changes | server-side permission must take effect at once | `livekit-media.provider.ts` `setPermission`, `removeParticipant` |
| Watch together (YouTube, D-watch) | playback position sync via `watch` topic (≈ 1 s tolerance) | `live-watch.service.ts`, `data/youtube_player.dart` |

## (g) Compatibility verdict: SRS/RTMP → FFmpeg → HLS → Nginx edges

**Verdict: INCOMPATIBLE as a replacement; PARTIALLY USEFUL as an add-on (viewer-only distribution and recordings),
best built from LiveKit Egress rather than a separate RTMP ingest.**

What breaks if media moved to RTMP/HLS:

| Area | Effect |
|---|---|
| Publishing | Phones publish WebRTC (`livekit_client`); there is no RTMP/SRT encoder in the app. Adding one = a new native encoder per platform (and DeepAR/beauty pipeline re-plumbing). |
| Playback | No HLS player in the app; every renderer is `lk.VideoTrackRenderer`. |
| Interactive modes | PK, MULTI, AUDIO, PODCAST, SOLO guests, second camera are two-way: HLS cannot carry them at all; they would still need the SFU. |
| Latency | HLS 2 s segments ≈ 6–10 s glass-to-glass typical (3 segments buffered + encode/packaging); 4 s segments ≈ 12–20 s; LL-HLS ≈ 2–4 s with tuned players and partial-segment support at every edge (ESTIMATE, industry-typical). All versus WebRTC's ≈ 0.2–0.5 s. |
| Realtime state | Chat/gifts/score/seats ride the LiveKit data channel and metadata. An HLS-only viewer would need a new realtime downlink (WebSocket service) **and** delay compensation so a gift banner doesn't arrive 8 s before the host's reaction. |
| Moderation | Kicks/mutes are SFU permissions; on HLS a kicked viewer keeps the playlist URL unless signed, expiring URLs are added. |
| Ops | A second media stack (SRS, FFmpeg workers, Nginx caches, WireGuard mesh, HAProxy) alongside LiveKit, which cannot be removed. |

What it could serve:

1. **Large SOLO/STREAMER rooms** (thousands of passive viewers) — via **LiveKit Egress** (room composite or track
   egress → HLS segments) → origin storage → **Bunny CDN**. Viewers who only watch could stay connected to LiveKit
   with `autoSubscribe: false` to keep receiving data messages (cheap), and play HLS. Self-hosted Egress needs Redis
   shared with the LiveKit server (SOURCED: docs.livekit.io/transport/self-hosting/egress/; the search index also
   reported a minimum server version for `StartEgress` that is higher than the pinned v1.9.1 — confirm before Phase 2).
2. **Recordings / replays / moderation evidence** — Egress to MP4/HLS on R2 (D45 already chose Cloudflare R2).

Cost to change (ESTIMATE, engineering):
- Add-on path (Egress → HLS → CDN for large rooms only): new API flag + threshold, Egress service + Redis, an HLS player
  in the viewer screen, data-only LiveKit join, delay-aware gift/chat rendering, signed playlist URLs, contract update.
  Several weeks of work and a decision record; **not needed at the stated targets** (4 viewers/room).
- Replacement path: a rewrite of every live mode's client media, a new realtime service, and still an SFU for
  interactive modes — not recommended.

## (h) Capacity math for the stated targets

Inputs (owner): 250 simultaneous broadcasters × 2.5 Mbps in; 1,000 concurrent viewers × 2 Mbps out; 5 h/day average
viewing; 720p.

**Bandwidth (instantaneous)**
- Ingress = 250 × 2.5 Mbps = **625 Mbps**.
- Egress = 1,000 × 2 Mbps = **2.0 Gbps** (+ ~10–20 % for audio, RTCP, retransmissions, TURN overhead → plan
  **2.3–2.4 Gbps**; ESTIMATE).
- Per viewer-hour: 2 Mbps × 3,600 s / 8 = **0.9 GB**.

**Monthly egress (30 days) — two interpretations**

| Interpretation | Formula | Result |
|---|---|---|
| (1) Concurrency-based, worst case: 1,000 viewers connected 24 h/day | 2 Gbps × 86,400 s × 30 / 8 | **648 TB/month** |
| (1b) Concurrency-based: 1,000 concurrent during a 5 h daily peak, ~0 otherwise | 2 Gbps × 5 × 3,600 s × 30 / 8 | **135 TB/month** |
| (2) Viewer-hours-based: 1,000 viewers × 5 h/day = 5,000 viewer-hours/day | 5,000 × 0.9 GB × 30 | **135 TB/month** |

(1b) and (2) coincide. If "1,000" is peak concurrency and the daily audience is larger, use (2) with the real
viewer-hours: **TB/month = viewer-hours/day × 0.027**. Ingress if 250 broadcasters were live 24 h:
625 Mbps × 2,592,000 s / 8 = 202.5 TB/month (ingress is not metered by Hetzner dedicated; SOURCED, see COST_MODEL).

**Multipliers specific to Kabso (ESTIMATE)**
- **PK:** each viewer subscribes to its own host *and* the opponent → ~2× per PK viewer.
- **MULTI (up to 12 tiles):** without adaptive stream each tile may be sent at a high layer; with adaptive stream the
  small tiles drop to 180p/360p (≈ 0.16–0.45 Mbps each per the SDK presets). This is the single biggest lever.
- **Audio rooms/podcast:** ~32–64 kbps per speaker per listener — negligible.

**Why HLS edge caching barely helps here**
- 1,000 viewers / 250 rooms = **4 viewers per room** average (the real distribution is skewed: a few rooms with
  dozens, most with 0–3).
- HLS: each live stream must be packaged at the origin regardless of audience. An edge fetches each segment once per
  stream and serves it N times; with N ≈ 4 the origin→edge traffic is ~25 % of the edge→viewer traffic per edge — the
  "cache" saves little, and with 2–4 edges every edge pulls most streams. For ABR (e.g. 720/480/360) the origin
  **transcodes 250 streams** = 250 × 2–3 x264 encodes (CPU-bound; roughly 1–2 cores per 720p30 ladder rung with fast
  presets → hundreds of cores; ESTIMATE) — far above one EPYC 9355P (32c/64t). Single-rendition remux is cheap but
  gives **no ABR**, so weak mobile viewers in Egypt/KSA buffer.
- SFU with simulcast: the **phone** encodes 3 layers (it already does); LiveKit only **forwards** RTP and picks a
  layer per subscriber from congestion feedback. CPU per Gbps forwarded is low (network-bound before CPU-bound on a
  modern 8-core; ESTIMATE — load-test before committing). No transcoding, sub-second latency, ABR-like adaptation.

**SFU sizing on the owner's hardware (ESTIMATE)**
- Each Hetzner dedicated server on the default 1 Gbit port has unmetered traffic (SOURCED). Target ≤ 70 % port
  utilisation → **~700 Mbps per node** → 2.4 Gbps needs **4 nodes on 1 Gbit**, or **1–2 nodes with the 10G uplink**
  (20 TB included, €1/TB beyond; SOURCED).
- LiveKit self-hosted multi-node: Redis turns on distributed mode; `regionaware` node selector with `sysload_limit`;
  **each room must fit on one node** (SOURCED: docs.livekit.io/transport/self-hosting/distributed/). With 4
  viewers/room that is never the constraint; a PK spans two rooms (two nodes is fine, the opponent connection is just
  another subscriber).
- Region-aware routing matters only once there are nodes in more than one region (see COST_MODEL §4 geography).

**2 s vs 4 s HLS segments (only relevant to the add-on path)**
- 2 s: lower latency (≈ 6–10 s), 2× more requests and playlist reloads, more keyframes (encoder must use GOP = 2 s →
  ~5–10 % more bits at equal quality), smaller CDN objects; better for "live-ish" rooms.
- 4 s: ≈ 12–20 s latency, fewer requests, better compression, steadier on bad mobile links; better for replays-of-live.
- For Kabso's gift-driven rooms neither is acceptable for the host↔viewer loop; 2 s (or LL-HLS) only for passive mass
  viewing.

## (i) Gaps and risks (current stack)

| # | Gap / risk | Severity | Evidence |
|---|---|---|---|
| R1 | **No TURN/TURN-TLS.** Clients on networks that block UDP and non-443 TCP (some corporate/hotel Wi-Fi, some carriers) cannot reach 7881/7882. | High | `install.sh` livekit.yaml; `DEPLOYMENT.md` §11.5 |
| R2 | **Single LiveKit node on the shared staging VPS** (with Postgres, Redis, API). Media load competes with the database; one host = one failure domain; VPS ports are usually ≤ 1 Gbit and VPS traffic is metered/fair-use (Contabo-class: 32 TB, SOURCED). | High | compose file |
| R3 | No Redis in `livekit.yaml` → cannot add nodes without a config change and a restart. | Medium | `install.sh` |
| R4 | No media metrics (`prometheus_port` unset), no alerting on packet loss / node load. | Medium | `install.sh` |
| R5 | Mobile `adaptiveStream`/`dynacast` off (SDK defaults). Extra egress and publisher CPU/battery, worst in MULTI and PK. | Medium (cost) | `live_media_engine.dart:696` (`lk.Room.new`), package `options.dart:298-299` |
| R6 | STREAMER screen: one 2.5 Mbps layer (`simulcast: false`) → no fallback for weak viewers. | Medium (QoE) | `live_media_engine.dart:~1300-1327` |
| R7 | Sweeper: `listRooms` + `listIdentities` per room every 15 s; global tickers: one `SendData` per LIVE room per event (concurrency 8). At 250 rooms ≈ 250+ RoomService calls per sweep and per ticker event — fine for one node, but measure; a ticker storm adds latency to chat. | Low–Medium | `live-media.service.ts:952`, `live-lucky-ticker.service.ts:175` |
| R8 | Real-LiveKit e2e tests not run in CI. | Medium | `kl063-livekit-real.e2e-spec.ts` gate |
| R9 | No recording/Egress: no evidence trail for moderation disputes, no replays. | Product | — |
| R10 | LiveKit v1.9.1 pinned; Egress/newer APIs may require an upgrade. | Low | compose file |
| R11 | Distance: Hetzner dedicated is only in Germany/Finland; Gulf users see ≈ 80–120 ms RTT (SOURCED medians). Fine for WebRTC; a Gulf/Egypt node would help but needs a provider decision. | Low–Medium | COST_MODEL §4 |
| R12 | No load test exists for 250 publishers / 1,000 subscribers. Capacity figures here are estimates until `lk load-test` (or equivalent) is run in a later phase. | High (planning) | — |

## (j) Feature status

Legend: **Impl** implemented in code · **Tested** unit/widget/e2e tests exist · **Prod-ready** verified on a real
server and device at target load · **Ext infra** requires infrastructure that does not exist yet · **Blocked**.

| Feature | Impl | Tested | Prod-ready | Ext infra | Notes |
|---|---|---|---|---|---|
| SOLO video live (publish/watch) | Yes | Yes (unit, e2e w/ fake provider; real-LiveKit spec opt-in) | No (not load-tested; no TURN) | TURN, dedicated media node | |
| Quality presets / 1080p / uplink meter | Yes | Yes (`quality_d160_test.dart`) | No | — | |
| PK battles (cross-room) | Yes | Yes (`d195-pk*.e2e`, opt-in real) | No | — | 2× egress per PK viewer |
| MULTI video seats 4–12 | Yes | Yes (`kl064-live-seats`) | No | — | R5 |
| AUDIO rooms 5–20 seats | Yes | Yes | No (device notes in KNOWN_LIMITATIONS) | — | |
| PODCAST | Yes | Yes (`d212-podcast`) | No | — | |
| STREAMER (screen + bubble) | Yes (Android host) | Yes (`live-streamer.spec.ts`) | No | — | R6 |
| Browser studio / OBS Virtual Camera | Yes | Yes (unit; e2e local only) | No (PP-44 open) | DNS `studio.` + cert | |
| Second camera | Yes | Yes (`second_camera_d243/d251`) | No | — | |
| Data messages (chat, gifts, tickers, seats, PK…) | Yes | Yes | No | — | R7 |
| Staff watch (admin) | Yes | Yes (`live-moderation.spec.ts`) | No (PP-45) | — | |
| Webhooks / sweeper | Yes | Yes (`live-sweeper.spec.ts`) | No | — | |
| TURN / TURN-TLS | No | — | No | Yes | R1 |
| Multi-node LiveKit (Redis) | No | — | No | Yes | R3 |
| Media metrics (Prometheus/Grafana) | No | — | No | Yes | R4 |
| Recording / replays (Egress) | No | — | No | Yes | R9 |
| HLS / CDN distribution | No | — | No | Yes | not needed at targets |
| RTMP/SRT ingest (SRS) | No | — | No | Yes | not compatible with app as built |
| LiveKit production provider choice (B1) | — | — | — | — | **Blocked** on owner decision (Cloud vs self-host) |

---

## Recommendation

**Keep the SFU. Do not build the SRS/RTMP → HLS → Nginx-edge network for Phase 1.**

Kabso's product is interactive by design (PK, seats, audio rooms, gifts answered live). The stated load — 250 rooms
averaging 4 viewers — is the profile an SFU is built for and the worst profile for HLS edges. The codebase already has
a clean control-plane abstraction (D3), simulcast publishing and server-side data delivery; what is missing is
**infrastructure hardening**, not a different media architecture.

**Proposed Phase 1 (planning; each item needs the owner's approval and its own task):**

1. **Decide B1 = self-hosted LiveKit** (LiveKit Cloud is ≈ 30–100× the cost at the targets; COST_MODEL option E).
2. **Dedicated media nodes:** run LiveKit on the owner's **Hetzner AX41 + AX42** (1 Gbit unmetered each), with Redis
   for distributed mode; keep the API/Postgres on a separate host. Add **1–2 more AX nodes** or the **10G uplink**
   when measured egress passes ~1.4 Gbps sustained. Same datacenter region first (Falkenstein/Nuremberg); no WireGuard
   mesh is needed for SFU nodes beyond Redis/API traffic (a private vSwitch or WireGuard for Redis only).
3. **TURN:** enable LiveKit's embedded TURN with TLS on 443 (own hostname, e.g. `turn.<domain>`) and UDP TURN.
4. **Observability:** LiveKit `prometheus_port`, node exporter, Prometheus + Grafana (on the API host or a small VPS),
   alerts on packet loss, node CPU, port utilisation, room count.
5. **App-side settings to evaluate (code change, separate approved task):** `adaptiveStream: true` and
   `dynacast: true` on the Flutter `Room`; a lower simulcast layer (or 2 layers) for the STREAMER screen. These lower
   egress more than any hardware change.
6. **Load test** (later step, not Phase 0): synthetic publishers/subscribers against one node to measure real
   Gbps/CPU per node before buying anything.
7. **Later (Phase 2, optional):** LiveKit Egress → MP4/HLS on R2 for replays/moderation; HLS + Bunny CDN only for
   rooms above a viewer threshold (hundreds), with viewers kept on a data-only LiveKit connection. Bunny Volume network
   has no Middle-East PoPs (SOURCED), so Middle-East traffic would be billed at the Standard ME rate.
8. **Geography (Phase 2+):** if RTT to the Gulf matters after measuring, add one LiveKit node closer to the audience
   and turn on the `regionaware` selector. Provider to be chosen after measuring real RTT from Amman, Cairo, Riyadh,
   Dubai.

Phase 0 stops here.

## Open questions for the owner

1. Is "1,000 viewers" **peak concurrency** or **daily viewers**? Is "5 h/day" per viewer or total viewing time per day?
   (135 TB vs 648 TB/month depends on it.)
2. How is the audience split by country, and are many viewers on mobile data versus Wi-Fi?
3. Expected largest room size (top 1 %)? HLS only makes sense above a few hundred viewers in one room.
4. Is replay/recording a product requirement (and its retention, legal hold)?
5. B1: confirm self-hosted LiveKit for production (vs LiveKit Cloud).
6. Which of the existing servers can be dedicated to media, and are the AX41/AX42 in the same Hetzner location?
   Current port speed and any 10G uplink already ordered?
7. Is a data-residency or latency requirement for KSA/UAE expected (e.g. a regulator or a carrier partner)?
8. Approval to schedule the app-side `adaptiveStream`/`dynacast` change and a load test as Phase 1 tasks.
9. Allow `hetzner.com`, `docs.hetzner.com`, `bunny.net`, `livekit.io` in this session's network so the SOURCED prices
   can be re-checked and marked VERIFIED.
