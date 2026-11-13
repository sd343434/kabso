# Phase 0 — Infrastructure Readiness & Verification (self-hosted LiveKit on Hetzner AX)

Status: **Phase 0 only.** The owner approved the direction "self-hosted LiveKit on Hetzner Dedicated AX" (target
250 concurrent publishers / 1,000 peak concurrent viewers, 720p). Nothing was bought, ordered, deployed, configured
or committed. This document builds on [`MEDIA_ARCHITECTURE_AUDIT.md`](./MEDIA_ARCHITECTURE_AUDIT.md) and supersedes
[`COST_MODEL.md`](./COST_MODEL.md) where they differ. Companions:
[`HETZNER_SERVER_COMPARISON.md`](./HETZNER_SERVER_COMPARISON.md) and [`PRODUCTION_COST_MODEL.md`](./PRODUCTION_COST_MODEL.md).

**Labels:** **CODE** = read in this repository (`file:line`). **VERIFIED** = read on the official page named,
accessed 2026-11-09. Pages were downloaded with curl through the session proxy. WebFetch could not resolve
`*.hetzner.com` or `*.livekit.io`, but curl could. **ESTIMATE** = reasoning, shown each time.

**Correction to earlier material:** the owner **owns no Hetzner server**. AX41, AX42 and the two large VPS were
options he was considering. The only existing server is the staging VPS (§4).

---

## 1. Repository facts (origin/staging)

| Item | Fact | Evidence |
|---|---|---|
| Tree audited | `origin/staging` = **`809063bdf412e53b79fad3593f77d30ac85c65d2`** (`git fetch` on 2026-11-09 found no newer commit). Worktree branch `claude/kl-348-media-audit`, clean apart from `docs/infrastructure/` | `git rev-parse` |
| LiveKit server | `livekit/livekit-server:v1.9.1@sha256:c039a1bf…` (digest-pinned, resolved 2026-10-25) | `infra/deploy/docker-compose.yml:75-76` |
| Latest LiveKit server | **v1.13.11**, published 2026-10-25. The repo is **four minor versions behind** | VERIFIED: Docker Hub `livekit/livekit-server` tags API (official image registry) |
| LiveKit CLI (load tester) | v2.19.3 (2026-11-03) | VERIFIED: Docker Hub `livekit/livekit-cli` |
| Flutter client | `livekit_client: 2.13.1` | `apps/mobile/pubspec.yaml:51` |
| JS clients | `livekit-client 2.22.4` (studio, admin) | `apps/studio/package.json:20`, `apps/admin/package.json:20` |
| Server SDK | `livekit-server-sdk 2.19.1` and `@livekit/rtc-node 1.1.0` | `apps/api/package.json:71,84` |
| Generated `livekit.yaml` | `port: 7880`, `rtc.tcp_port: 7881`, `rtc.udp_port: 7882`, `use_external_ip: true`, one key pair, webhook to `http://api:3000/internal/livekit/webhook`. **No** `redis`, `turn`, `prometheus_port`, `node_selector`, `region` | `infra/deploy/install.sh:176-192` |
| Firewall | ufw: 22, 80/tcp, 443/tcp+udp, 7881/tcp, 7882/udp. No 3478/udp (TURN) | `infra/deploy/install.sh:61-68` |
| Network topology | one compose project, one bridge network `internal`. LiveKit publishes only 7881/tcp and 7882/udp. Signalling 7880 is internal and reached through Caddy `live.{$KABSO_DOMAIN}` → `reverse_proxy livekit:7880`. Caddy `depends_on: [api, livekit]` | `docker-compose.yml:81-85,107-112`, `Caddyfile:141,190-191` |

### 1.1 How clients get the LiveKit URL (server-driven: moving media needs no app update)

- The API reads one env var, `LIVEKIT_URL` (`ws`/`wss`; `wss://` required in production) →
  `apps/api/src/config/env.schema.ts:976-980,1728-1729`. `install.sh:167` writes `LIVEKIT_URL='wss://live.${DOMAIN}'`.
- The provider is built from that config (`apps/api/src/modules/live/live.module.ts:131-138`), and every
  media-token response returns it: `url: this.media.url` (`apps/api/src/modules/live/live-media.service.ts:274`,
  also `:333`, `:370`; DTO `LiveMediaAccessDto.url` at `:52`).
- Every client connects to the URL **it was given**: Flutter `room.connect(access.url, access.token)`
  (`apps/mobile/lib/features/live/data/live_media_engine.dart:1069`, PK `live_pk_media.dart:81`), studio
  `apps/studio/src/studio-live.ts:143`, admin `apps/admin/src/live-media.ts:172,236`.
- **Consequence:** pointing `LIVEKIT_URL` at a new media tier, or keeping `live.kabsolive.com` and changing what is
  behind it, needs **no app release**. The only coupled settings are the admin and studio CSP `connect-src`
  (`Caddyfile:77,110`). They allow `wss://live.{$KABSO_DOMAIN}` plus `KABSO_ADMIN_MEDIA_ORIGINS` /
  `KABSO_STUDIO_MEDIA_ORIGINS`, so a new hostname is an env change only.
- **Caveat:** the same URL is used for the server's RoomService calls
  (`livekit-media.provider.ts:81`, `url.replace(/^ws/, 'http')`). There is no separate internal or control URL.
  With media on other hosts, API→LiveKit control calls go over the public `https://live.…` front. This works because
  LiveKit's API is homogeneous: "any client could connect to any backend instance" (VERIFIED, firewall docs). A
  private `LIVEKIT_API_URL` would be a small, optional code change.

### 1.2 Webhook

- `POST /internal/livekit/webhook`, `@Public()`, `@SkipRateLimit()`. The raw body is checked by `WebhookReceiver`
  with the key and secret (`live.controller.ts:1048-1067`, `livekit-media.provider.ts:82,229-244`). Mapped events:
  `participant_joined`, `participant_left`, `room_finished`. Everything else is ignored.
- LiveKit signs webhooks with a JWT in `Authorization` that carries a sha256 of the payload. It retries, keeps events
  in order, but gives "**no guarantees around delivery**" (VERIFIED, webhooks-events docs). The repo already makes up
  for that with the 15 s sweeper (`live-media.service.ts:1003-1040`).
- **Gap for separate hosts:** the webhook URL is the docker-internal `http://api:3000` (`install.sh:189`), and the
  public `api.` site answers `/internal/*` with **404** (`Caddyfile:57-61`). Media nodes on other machines need a
  private path: the vSwitch IP of the app server, firewalled to the media nodes' private IPs.

### 1.3 Token semantics

- One room per token. Room name = the live room's UUID. TTL **600 s** (`MEDIA_TOKEN_TTL_SECONDS`,
  `live-media.service.ts:75`), staff 120 s (`:82`).
- Grants: `roomJoin`, `canSubscribe` (default true), `canPublish` only with sources, **`canPublishData: false`**,
  `hidden: true` for viewers (`livekit-media.provider.ts:~99-112`). PK opponent tokens are subscribe-only into the
  other room.
- ESTIMATE: tokens are not tied to a node. Any node in a Redis-backed cluster accepts them, so moving or adding
  nodes changes nothing on the token side.

### 1.4 Deployment and rollback today

- `kabso-update.timer` runs every 5 min (`OnUnitActiveSec=5min`, `RandomizedDelaySec=30s`). It starts
  `kabso-update.service` → `update.sh` (oneshot, 20 min timeout) (`infra/deploy/systemd/*`).
- `update.sh`: fast-forwards `/opt/kabso` to `origin/$KABSO_BRANCH`, pulls `$KABSO_API_IMAGE`, then
  `up -d --wait postgres redis` → `run --rm migrate` (`prisma migrate deploy`) → `up -d --remove-orphans`. It
  recreates Caddy when the Caddyfile changed and waits for `/health/ready` (`infra/deploy/update.sh:45-99`).
- Image pinning: Postgres, Redis, LiveKit and Caddy are pinned **by digest**. The API image is the **mutable tag**
  `ghcr.io/sd343434/kabso-api:staging` (`install.sh:25`). CI also pushes `:sha-<commit>`.
- **Rollback:** set `KABSO_API_IMAGE=…:sha-<good commit>` in `/etc/kabso/kabso.env` and run `update.sh --force`.
  Migrations are expand/contract and are never rolled back (`docs/DEPLOYMENT.md:1488-1490`, §5).
- **Media-node risks (ESTIMATE):** (a) `up -d` restarts LiveKit whenever its compose definition changes, which
  drops every room on that node. (b) LiveKit drains on SIGTERM: active rooms keep running, new rooms are refused
  (VERIFIED, distributed docs). But Docker's default stop timeout (10 s) kills the process long before a live room
  ends. Media nodes need `stop_grace_period` and a manual, node-by-node upgrade, not the 5-minute auto-update.

### 1.5 Can API / Postgres / Redis run apart from media?

| Question | Answer | Evidence |
|---|---|---|
| Does the API need LiveKit on the same host? | **No.** It only needs `LIVEKIT_URL` and the key and secret | `env.schema.ts:976-982,1641-1650` |
| Does LiveKit need the API's Redis? | **No.** Today LiveKit has no Redis at all. Multi-node needs a Redis for LiveKit (VERIFIED: "Redis is required as shared data store and message bus"). ESTIMATE: run it as a **separate Redis instance** from the app's Redis (`redis:7.4`, AOF on, `docker-compose.yml:27-36`) so app eviction or blocking cannot affect routing | compose, distributed docs |
| Required Redis version | **Not stated** on the LiveKit pages read. The repo's pinned Redis 7.4 is assumed to be fine (ESTIMATE, confirm in `config-sample.yaml` when GitHub is reachable) | — |
| What couples them today | the single compose project (`caddy depends_on livekit`), the Caddy `live.` block → `livekit:7880`, the internal webhook URL, and `install.sh` writing every env file on one host | §1, §1.2 |
| Caddy reverse proxy for signalling | Already in place (`Caddyfile:141-192`). It can take several `reverse_proxy` upstreams (the media nodes' private 7880) with health checks (ESTIMATE). LiveKit nodes forward signalling to the room's node themselves (VERIFIED: "That instance then acts as a signaling bridge") | Caddyfile, distributed docs |
| Docker networking for media | LiveKit recommends **host networking** (VERIFIED, deployment docs). The repo uses bridge + published ports | `docker-compose.yml:81-85` |

### 1.6 Node-failure behaviour in the app (CODE + ESTIMATE)

- Flutter treats LiveKit's `Reconnecting`, `Resuming` and `Reconnected` as a blip (D243). `RoomDisconnectedEvent`
  sets `_closed = true` as final (`live_media_engine.dart:1141-1151`).
- **Finding:** `sessionClosed` is read **only** by the second-camera screen
  (`tools/second_camera/second_camera_screen.dart:218`). No code was found in the viewer or host path that fetches a
  fresh media token and rejoins after a final disconnect. ESTIMATE: if a media node dies and LiveKit's own full
  reconnect does not recover, a viewer may sit on a frozen stage until they leave and re-enter. **This must be
  checked in the failover test** and may need an app change.
- The sweeper does **not** end LIVE rooms that are missing from LiveKit. Host liveness is the REST heartbeat (15 s,
  45 s stale), so a node failure alone does not end lives (`live-media.service.ts:1003-1040`; audit §b.4).
- ESTIMATE: room metadata (`seatsVersion`, `score`, …) lives only in the LiveKit room. A room re-created on another
  node starts empty until the API's next metadata write. To be verified.
- There is no client telemetry today (no time-to-first-frame, reconnect counts or join failures reported).

---

## 2. LiveKit facts (official docs, VERIFIED 2026-11-09)

| Topic | Fact | Source |
|---|---|---|
| Current stable | v1.13.11 (2026-10-25) | Docker Hub tags (official image) |
| Distributed mode | "When Redis is configured, LiveKit automatically switches to a distributed setup … each node periodically reports their stats to Redis". The receiving node "is able to choose an available node … to host the room" | https://docs.livekit.io/transport/self-hosting/distributed/ |
| Room placement | "a room must fit on a single node" | same; also the benchmark page |
| Node selector | `node_selector: kind: regionaware`, `sysload_limit: 0.5`, `regions: [{name, lat, lon}]`. Choice: node below `sysload_limit`, region closest to the signalling instance, then random | distributed |
| Draining | on SIGTERM/SIGINT/SIGQUIT with participants connected: keeps active rooms, accepts new participants into active rooms, rejects new rooms, shuts down when empty | distributed |
| Node crash | **not described** in the docs read. ESTIMATE: rooms on the dead node are lost; clients go through LiveKit's reconnect (below), and a rejoin creates the room again on a healthy node | — |
| Client reconnect | Network change → resume (signal reconnect + ICE restart). If that fails → "full reconnection": `ParticipantDisconnected` → `Reconnecting` → full reconnect → `Reconnected` → tracks republished, "identical to having everyone leave the room, then coming back". A participant who leaves without `disconnect()` disappears after 15 s | https://docs.livekit.io/intro/basics/connect.md |
| Ports | 7880 API/WS (behind a TLS LB, not exposed); 50000–60000/udp ICE (2 ports per participant) **or** 7882/udp mux; 7881/tcp ICE-TCP ("when the client could not connect via UDP (e.g. VPN, corporate firewalls)"); 5349 TURN/TLS ("If not using LB, this port needs to be set to 443"); 3478/udp TURN/UDP (also STUN) | https://docs.livekit.io/transport/self-hosting/ports-firewall/ |
| TURN | Embedded. Only clients that already hold a signal connection may use it. TURN/TLS: `turn.enabled`, `tls_port`, `domain`, `cert_file`, `key_file`; LiveKit terminates TLS. "**a separate TURN domain and SSL cert will be needed**". TURN/UDP may use `udp_port: 443` | https://docs.livekit.io/transport/self-hosting/deployment/ |
| TLS certificates | trusted CA required; "self-signed certs do not work" | deployment |
| External IP | `use_external_ip: true` "for most cloud environments where the host has a public IP address, but is not exposed to the process"; discovered by STUN | deployment |
| Metrics | `prometheus_port: 6789` exposes `:6789/metrics` | deployment |
| Hardware | "scalability … is bound by CPU and bandwidth. We recommend running production setups on **10Gbps ethernet or faster**"; compute-optimised instances; **host networking** in Docker | deployment |
| Benchmarks (c2-standard-16) | Audio: 10 pubs / 3,000 subs → 23 MBps out, 80 % CPU. Large meeting: 150/150 → 50 MBps in / 93 MBps out, 85 %. Livestreaming: 1 pub / 3,000 subs → 531 MBps out (≈ 4.2 Gbit/s), 92 % | https://docs.livekit.io/transport/self-hosting/benchmark/ |
| Load tester | `lk perf load-test` (alias `lk load-test`): one room per run; `--video-publishers`, `--audio-publishers`, `--subscribers`, `--duration`, `--video-resolution high/medium/low`, `--video-codec h264/vp8`, `--num-per-second` ≤ 10, `--layout speaker/3x3/4x4/5x5`, `--no-simulcast`, `--simulate-speakers`. Publishes looping 720p with simulcast, keyframes ~3 s, silent audio at the target bitrate. Subscribers can simulate adaptive stream. "Run … on a machine with plenty of CPU and bandwidth … `ulimit -n 65535` … from several machines" | https://docs.livekit.io/reference/developer-tools/livekit-cli/perf.md, benchmark |
| Load-generator bandwidth | Not quantified by LiveKit. ESTIMATE: generators must **receive** the whole subscriber downlink (≈ 2.0–2.4 Gbit/s at target) and **send** the publisher uplink (≈ 0.6 Gbit/s), so 3–4 machines with 1 Gbit/s each, plus CPU for 1,250 simulated participants | — |

---

## 3. Readiness gaps (what blocks a production media tier)

| # | Gap | Fix (Phase 1, separate approved tasks) | Type |
|---|---|---|---|
| G1 | Single-host compose: LiveKit, API, DB and Caddy are coupled | split into an **app bundle** and a **media-node bundle** (LiveKit, host network, own update path) | infra code |
| G2 | `livekit.yaml` lacks `redis`, `turn`, `prometheus_port`, `node_selector` | generator for per-node config: Redis on the vSwitch, `sysload` selector (one region), TURN `turnN.` domain + cert, metrics on the private IP only | infra code |
| G3 | Webhook URL is docker-internal; public `/internal/*` is 404 | private listener on the app server's vSwitch IP, firewalled to the media nodes | infra code |
| G4 | No TURN (UDP 3478/443, TLS 443) | embedded TURN on every media node. 443 on each node is free if signalling stays on the app server (R1) | infra + DNS |
| G5 | LiveKit 1.9.1 pinned, latest 1.13.11 | upgrade, tested against `livekit_client 2.13.1`, `livekit-client 2.22.4`, `livekit-server-sdk 2.19.1` | infra + tests |
| G6 | Media nodes must not auto-restart every 5 min | manual or rolling node upgrade, `stop_grace_period`, drain | infra code |
| G7 | Flutter `adaptiveStream`/`dynacast` off; STREAMER screen has a single 2.5 Mbit/s layer | app change + release, **before or alongside** capacity tests | app code |
| G8 | No rejoin after a final disconnect (§1.6) | verify in the failover test; app change if confirmed | app code |
| G9 | No client telemetry (time-to-first-frame, reconnects, join failures) | app + API change, **and a privacy decision** (what, consent, retention) | app + policy |
| G10 | No media metrics or alerts | Prometheus `6789`, node exporter, Grafana, alerts on port use, CPU, packet loss, rooms per node | infra |
| G11 | Real-LiveKit e2e tests are not in CI (opt-in `LIVEKIT_TEST_URL`) | run them against the staging media node | CI |
| G12 | One LiveKit Redis = single point of failure for routing new rooms (ESTIMATE) | accept for Phase 1 with an alert; Sentinel or a replica later | infra |
| G13 | No load test exists | §5 test plan | tests |
| G14 | Staging VPS too small for media (§4) | staging media node (CPX22) or one production node with separate keys | infra |

---

## 4. Inventory (owner, 2026-11-09)

| Server | Facts | Label |
|---|---|---|
| **Staging VPS** `live.kabsolive.com`, hostname `srv2094930` | Hostinger **KVM 1**, Ubuntu 26.04.1. Runs API, PostgreSQL, Redis, LiveKit and Caddy (compose). Verified on the server 2026-10-25 for API health; **WebRTC through its firewall never verified** | owner; `docs/DEPLOYMENT.md:1436-1438,1492-1509` |
| KVM 1 specs | ≈ 1 vCPU, 4 GB RAM, 50 GB NVMe, ≈ 4 TB/month traffic. hostinger.com could not be reached from this session (proxy 403) | **ESTIMATE, needs confirmation** |
| Assessment | **Far too small for any meaningful LiveKit test.** One vCPU is shared with PostgreSQL, the API, Argon2 hashing and Caddy. 4 TB/month is ≈ 4,400 viewer-hours at 2 Mbit/s. Keep it as a light staging box, or retire it once production exists | ESTIMATE |
| Hetzner AX41/AX42, 12-vCPU/48 GB and 18-vCPU/96 GB VPS | **Not owned.** These were options he was considering | owner correction |
| **Owner's choice (2026-11-09, D350)** | Media: **EX44** ($74/month, $0 setup; AX41 unavailable). App/DB at production: **EX63** ($174/month + $84 setup). USD, VAT 0 % on his account, prices seen on his account 2026-11-09. Phase 1 = **1 × EX44** (being ordered once the account is verified); production = **5 × EX44 + 1 × EX63** | OWNER |

**Owner decision, 2026-11-09 (after Phase 0; D350):** direction "self-hosted LiveKit on Hetzner dedicated" approved.
AX41 is **not available** to order. Media nodes: **EX44** (Intel i5-13500, 14 cores / 20 threads, 64 GB DDR4,
2 × 512 GB NVMe, 1 Gbit/s guaranteed, unlimited traffic, FSN1) at **$74/month, $0 setup**. App/DB at production:
**EX63** at **$174/month + $84 setup**. Prices as seen **on the owner's Hetzner account on 2026-11-09, in USD, VAT 0 %
on his account** (OWNER; not read by us on hetzner.com). Phase 1: **one EX44** as a single-node test
(`LIVEKIT_SINGLE_NODE_DEPLOYMENT.md`). Production plan: **5 × EX44 media + 1 × EX63 app/DB**.

---

## 5. Amended phase plan (recommendation; each step needs the owner's approval)

The owner's plan, with the coordinator's amendments: TURN in Phase 1, Flutter optimisation early, separate load
generators, N+1 math, TURN-TLS/IPv4 cost, node-failure behaviour, and telemetry with a privacy decision.

**Phase 0 (this document): done.** No external action taken.

**Phase 1A: decisions and orders.**
Owner answers §7. Then order R1 (`PRODUCTION_COST_MODEL.md` §3): 1 × AX42 (app/DB) + 4 × AX41 (media), FSN1,
vSwitch, and DNS records `turn1…4.` (DNS only when approved). Optionally a CPX22 staging media node.

**Phase 1B: infrastructure code (one PR, reviewed).** G1–G6, G10, G12:
- app/media bundle split;
- `livekit.yaml` generator: Redis, sysload selector, TURN/TLS 443 + TURN/UDP 3478, `prometheus_port` on the private
  IP, host networking, `use_external_ip`;
- private webhook path;
- Caddy `live.` with multiple upstreams;
- per-node firewall: 80/tcp (cert), 443/tcp (TURN/TLS), 3478/udp, 7881/tcp, 7882/udp, private-only 7880/6789;
- media-node upgrade runbook (drain);
- LiveKit upgrade to 1.13.x behind tests.

**Phase 1C: app changes, in parallel with 1B, before the capacity tests that decide N.** G7–G9:
`adaptiveStream`/`dynacast` on, a lower STREAMER layer, a rejoin-after-final-disconnect check, and client
telemetry (time-to-first-frame, reconnects) **only after the privacy decision**. These need an app release to reach
users. The server side needs none.

**Phase 1D: capacity and resilience tests (§6).**

**Phase 1E: size the cluster from data.**
If the measured peak is ≤ 2.1 Gbit/s, stay at 4 nodes. If it is between 2.1 and 2.8, add a 5th AX41 (+€59). If it
is above that, add nodes or a 10G uplink (`PRODUCTION_COST_MODEL.md` §4). With no minimum term and immediate
cancellation (VERIFIED), extra nodes can be dropped.

**Phase 1F: cut-over.**
Point production `LIVEKIT_URL` / `live.` at the cluster. No app update is needed (§1.1). Keep the old single node
until rollback is no longer needed.

**Phase 2 (later):** Egress/recording, a Gulf node with the `regionaware` selector, Redis HA.

## 6. Test plan for Phase 1D (no test was run in Phase 0)

| Test | Setup | Pass criterion (proposal) |
|---|---|---|
| T1 Single-node ceiling | 1 AX41 target; 3 AX41 + app server as generators (internal traffic is free, VERIFIED) | measured Gbit/s and CPU at < 2 % packet loss; confirms the network-bound assumption |
| T2 Target profile | 4 targets; +3–4 hourly AX41 generators (€27 for 72 h); 250 `lk load-test` runs × (1 publisher + 4 subscribers, `--layout speaker`), plus a PK and MULTI mix | 1,000 subscribers stable for 1 h, per-node port < 80 % |
| T3 N+1 | T2 with one node stopped by SIGKILL | rooms re-created, clients back within an agreed time (e.g. < 10 s), remaining nodes < 90 % |
| T4 Drain | SIGTERM on one node | no new rooms there, existing rooms continue |
| T5 TURN | UDP blocked on the client, then UDP + non-443 blocked | joins succeed over TURN/UDP, then TURN/TLS 443 |
| T6 Real devices | Android/iOS on 4G from target countries | time-to-first-frame and reconnect behaviour (needs G9, or manual timing) |
| T7 Redis loss | stop the LiveKit Redis | existing rooms keep running; observe what happens to new rooms (expected to fail, ESTIMATE); alert fires |

---

## 7. Questions for the owner (inputs needed; nothing is guessed)

1. **Staging VPS:** confirm Hostinger KVM 1 plan details (vCPU, RAM, disk, monthly traffic, price, renewal date).
   Keep it as API staging, or retire it?
2. **Hetzner account:** who opens it, in which country, as a business with a VAT ID or not? This sets the VAT on
   every price (all figures exclude VAT). Is the $750–800 budget before or after VAT?
3. **Location:** FSN1 (recommended, closest to Frankfurt transit) or HEL1? NBG1 is not offered for AX on the
   current pages.
4. **Hardware choice:** AX41 media nodes (€59, Zen 2, no ECC, €0 setup) or AX42 (€99, Zen 4, ECC, €49 setup)?
   At order time, check in the configurator which AX42 type is the €79 "starting from" one, and whether the primary
   IPv4 is charged.
5. **Audience:** is 1,000 the **peak concurrent** count? How many hours a day? Country split, and Wi-Fi vs mobile
   data? This sets 135 TB vs 648 TB and the N decision.
6. **N+1 policy:** 4 nodes (N+1 holds at 80 % load) or 5 nodes (N+1 at 70 %)?
7. **Load generators:** approve about €30–70 one-time (hourly AX41 or Cloud) for T2.
8. **TURN hostnames:** approve `turn1…turn4.kabsolive.com` (DNS changes happen only in Phase 1).
9. **Telemetry and privacy:** may the app report time-to-first-frame, reconnects and join failures? Pseudonymous or
   not, consent, retention, and the privacy-policy wording.
10. **App release:** the `adaptiveStream`/`dynacast` change and any rejoin fix reach users only through a new
    build. Which release slot?
11. **Production vs staging:** production will be a new environment on new servers. Confirm the branch, domain
    (`kabsolive.com` stays?) and the update policy (no 5-minute auto-update for media nodes).
12. **Redis single point of failure:** acceptable for Phase 1 with alerting?
13. **Hetzner fair use:** should we ask Hetzner support in writing about sustained ~80 % use of the 1 Gbit port?
    No written fair-use clause was found on the pages read.
14. **Decision record:** record B1 = self-hosted LiveKit (replacing D93's "LiveKit Cloud in production") in the
    board.

---

## 8. Status per item

Legend: **Impl** implemented in code · **Tested** automated tests exist · **Prod-ready** verified on real servers at
target load · **Ext infra** needs infrastructure that does not exist yet · **Blocked** waiting on a decision or input.

| Item | Impl | Tested | Prod-ready | Ext infra | Blocked |
|---|---|---|---|---|---|
| Server-driven `LIVEKIT_URL` (no app update to move media) | Yes | Yes (config spec) | No | — | — |
| Token issuance (TTL 600 s, hidden viewers, no client data) | Yes | Yes | No | — | — |
| Signed webhook + sweeper fallback | Yes | Yes | No | private path for remote nodes | — |
| Single-node LiveKit 1.9.1 on staging | Yes | opt-in real e2e only | No (KVM 1 too small, WebRTC not verified) | — | — |
| Deploy/update timer + image-tag rollback | Yes | verified on staging 2026-10-25 | No (not for media nodes) | — | — |
| App/media split (two bundles) | No | — | No | Yes | owner approval |
| Multi-node LiveKit (Redis, selector) | No | — | No | Yes | servers |
| Embedded TURN (UDP + TLS 443) | No | — | No | Yes (servers, DNS, certs) | servers, DNS approval |
| Media metrics and alerts | No | — | No | Yes | servers |
| LiveKit upgrade to 1.13.x | No | — | No | — | Phase 1 task |
| Flutter `adaptiveStream`/`dynacast`, STREAMER layers | No | — | No | — | owner approval + release slot |
| Rejoin after node failure (app) | Unverified (§1.6) | No | No | — | failover test |
| Client telemetry (TTFF) | No | — | No | — | **privacy decision** |
| Load test 250 / 1,000 | No | — | No | Yes (generators) | servers |
| Hetzner prices and terms | — | VERIFIED on pages 2026-11-09 | — | — | account and VAT questions |
| Purchase of R1 | — | — | — | Yes | **owner decision** |
