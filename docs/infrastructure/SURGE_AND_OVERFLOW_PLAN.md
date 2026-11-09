# Surge and overflow plan — sudden load on the media tier (D350)

Status: **PLAN + scripts (dry-run by default). Nothing was created or run against Hetzner.** The capacity guard (§6) is
a **design only** in this branch (reason in §6.5). Labels: VERIFIED (official docs or LiveKit v1.13.11 source, named),
OWNER, ESTIMATE, TARGET.

## 1. What happens automatically

| Mechanism | What it does | Phase | Source |
|---|---|---|---|
| Node selector (`sysload`, `sysload_limit`) | a **new** room goes to a node whose load per CPU is below the limit, lowest first | 2 (needs Redis) | VERIFIED: distributed docs; `pkg/routing/selector/sysload.go`. ESTIMATE: when *every* node is above the limit, older releases fell back to all nodes — to be confirmed in the Phase 2 test |
| Existing rooms stay put | "a room must fit on a single node"; a room never moves to relieve a node | 1, 2 | VERIFIED: distributed docs |
| Node limits (`limit.bytes_per_sec`, `limit.num_tracks`) | once reached, the node refuses **new participants, also into existing rooms** (`ErrNodeLimitReached`) and is skipped for new rooms | 1, 2 | VERIFIED: `pkg/service/roomallocator.go` (`SelectRoomNode`), `selector/utils.go` (`LimitsReached`, in + out bytes) |
| Draining | SIGTERM: active rooms continue and accept viewers, new rooms refused, exit when empty | 1, 2 | VERIFIED: docs + local test (LIVEKIT_SINGLE_NODE_DEPLOYMENT §9) |
| Congestion control | per subscriber, LiveKit lowers the forwarded simulcast layer or pauses video before the link stalls (`congestion_control.enabled`, `allow_pause`, default on) | 1, 2 | VERIFIED: config-sample |
| Simulcast + adaptive stream + dynacast | viewers get a lower layer instead of a frozen picture; unused layers stop being sent | **only after the Flutter change** (Phase 0: `adaptiveStream`/`dynacast` are off in the app) | Phase 0 audit §b.7 |
| TCP / TURN fallback | an unstable UDP session moves to TCP or TURN/TLS (`allow_tcp_fallback`) | 1, 2 | VERIFIED: config-sample |

## 2. What does NOT happen automatically

- **No new dedicated server appears.** Ordering an EX44 takes from hours to about a day (OWNER/Hetzner, ESTIMATE),
  plus DNS and install (~30 min with `install.sh`).
- **No cloud node appears** unless someone runs `infra/media/cloud/hcloud-create.sh` (§5) — minutes, but manual.
- In **Phase 1 (one node, no Redis)** a second node cannot share load: the API hands out **one** `LIVEKIT_URL`. The
  only Phase 1 levers are quality (§1), the node limits and the capacity guard (§6).
- Rooms are not rebalanced; a full node stays full until rooms end.

## 3. Standing buffer: N+1

Production (OWNER): 5 × EX44. Phase 0 sizing (PRODUCTION_COST_MODEL §2): 4 nodes cover the 2.4 Gbit/s target at 80 %
of each port; **the 5th is the N+1 buffer** — one node can fail or drain while the target still fits (at 70 %). That
buffer is the first answer to a surge; cloud nodes are the second.

## 4. Alerts (Prometheus rules to add with the Phase 2 monitoring; thresholds are TARGETS)

| Alert | Expression (sketch) | For | Action |
|---|---|---|---|
| NIC busy | `rate(node_network_transmit_bytes_total{device="<uplink>"}[2m]) * 8 > 0.75 * 1e9` | 5 m | pre-scale (§5), check the capacity guard |
| CPU busy | `1 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) > 0.80` | 5 m | same |
| Load per CPU | `node_load1 / count(node_cpu_seconds_total{mode="idle"}) > 0.7` | 5 m | the node selector stops placing rooms here (Phase 2) |
| UDP drops | `increase(node_netstat_Udp_RcvbufErrors[5m]) > 0` | — | raise buffers (sysctl), check CPU |
| Probe failed | `kabso_media_probe_ok == 0` | 2 m | health.sh output in the journal |
| Certificate | `kabso_media_cert_days < 14` | — | check Caddy logs / DNS |
| Node limit hit | LiveKit log `node limit reached` / join failures in the app telemetry (to come) | — | §5 now |

## 5. Runbooks

### 5.1 Known event (a campaign, a famous host, a holiday)

1. 3–7 days before: estimate peak viewers × 2 Mbit/s; compare with nodes × 800 Mbit/s (80 %) minus one node (N+1).
2. If short: order dedicated nodes (Phase 2: they join through Redis by themselves) — the cheapest and the best ports.
3. 1 day before: if still short, plan cloud nodes (§5.2) for the event window only; test one the day before.
4. During: watch §4; do not update or drain any node.
5. After: drain and delete cloud nodes; keep dedicated nodes only if the new baseline needs them.

### 5.2 Emergency cloud node (Phase 2 only — Phase 1 has no cluster to join)

On the owner's or operator's machine (official `hcloud` CLI; `hcloud context create kabso` asks for the API token
there — it never goes into git or chat):

```bash
cp infra/media/.env.example media-s1.env && chmod 600 media-s1.env
# fill: MEDIA_DOMAIN=media-s1.<domain>, TURN_DOMAIN=turn-s1.<domain>, ACME_EMAIL, the CLUSTER key pair, NODE_IP=0.0.0.0
bash infra/media/cloud/hcloud-create.sh --name media-s1 --env media-s1.env --type ccx33 --location nbg1 \
     --ssh-key <key name in Hetzner Cloud> --network <private network>          # dry run: prints everything
# … add the two DNS records it prints, then the same command with --run
bash infra/media/cloud/hcloud-delete.sh --name media-s1 --run                   # after the surge (drains first)
```

What the scripts do: user-data from `cloud/cloud-init.yaml.tmpl` (**no secret**: user-data is stored by Hetzner and
readable from the server's metadata service) installs the public bundle and runs `install.sh`; the env file with the key
pair is copied **over SSH** (`scp`, mode 600); `install.sh` runs again, then `health.sh`. The node gets labels
`kabso-role=media-surge`; the delete script refuses any server without that label, drains LiveKit over SSH, then
`hcloud server delete`. From a **snapshot** (`--image <snapshot id>`) the first boot skips the package downloads
(ESTIMATE: saves a few minutes); a snapshot must not contain `/etc/kabso-media/media.env`.

In Phase 2 the node joins the cluster through the `redis:` block in its media.env-rendered config (to be added with the
Phase 2 template; the private network must reach the LiveKit Redis). Time to serve (ESTIMATE): 3–5 min create + boot,
3–5 min install, DNS + certificate 1–10 min depending on TTL → **about 10–20 minutes**.

### 5.3 Cost of cloud nodes (VERIFIED prices from Phase 0 HETZNER_SERVER_COMPARISON §7, eu-central, excl. VAT)

| Type | vCPU | RAM | €/hour | Monthly cap | 8 h event | 3 days |
|---|---|---|---|---|---|---|
| CCX33 | 8 dedicated | 32 GB | €0.2227 | €138.99 | €1.78 | €16.03 |
| CCX43 | 16 dedicated | 64 GB | €0.4431 | €276.49 | €3.54 | €31.90 |
| CPX52 | 12 shared | 24 GB | €0.1618 | €100.99 | €1.29 | €11.65 |
| CPX62 | 16 shared | 32 GB | €0.2091 | €130.49 | €1.67 | €15.06 |

- **Traffic:** at least **20 TB included** per EU cloud server, then **€1.00/TB** (outgoing). One node pushing
  700 Mbit/s for 8 h sends ≈ 2.5 TB (inside the 20 TB); for 24 h a day the 20 TB last ≈ 2.6 days, after which a full
  node costs ≈ €7.5/day in traffic (ESTIMATE from the unit price).
- **Bandwidth per instance is not published** — a cloud node's real throughput must be measured (iperf3, a short
  `lk load-test`) before an event relies on it. Shared-vCPU CPX types can be noisy; prefer CCX for media.
- CCX is listed in NBG1 and HEL1 (not FSN1); whether a cloud server can reach the dedicated nodes' vSwitch Redis
  (Hetzner Cloud network ↔ vSwitch coupling) must be checked when Phase 2 is built (ESTIMATE: possible within one
  network zone).
- **Short surges only:** an EX44 ($74/month, 1 Gbit guaranteed, unlimited traffic) is cheaper than a CCX33 running
  more than ~14 days a month (336 h × €0.2227 ≈ €75, ignoring the EUR/USD difference), and its port is guaranteed.

## 6. Capacity guard (DESIGN — not implemented in this branch)

### 6.1 Goal

When the media tier is full, **«ابدأ البث» is refused with a clear message** instead of letting a new live degrade
everyone (LiveKit's node limit would otherwise also refuse **new viewers of existing lives**, §1). **Viewers joining
existing rooms are never blocked by this guard.**

### 6.2 Rule

- Config (API): `LIVE_MAX_CONCURRENT_ROOMS` (0 = off, **default 0**) — the ceiling for LIVE rooms overall; optional
  `LIVE_MAX_ROOMS_PER_MEDIA_NODE` × `LIVE_MEDIA_NODE_COUNT` as the way to derive it (Phase 1: one node). Values from
  SINGLE_NODE_CAPACITY_RESULTS.md (e.g. 80 % of the measured ceiling of the realistic mix).
- Checked only where a **new live room is created**: `POST /live/rooms` (startLiveRoom), and the paths that create a
  new media room for a host (PK battle start creates no new room — not checked; second camera joins the host's room —
  not checked). Not checked: heartbeats, viewer tokens, guest/seat tokens, PK watch tokens, staff/team tokens.
- Count: `live_rooms` with status LIVE and a fresh heartbeat (the same "not stale" rule as listing). A soft limit: two
  hosts starting at the same instant may both pass (acceptable; a Redis `INCR` slot is the strict alternative).
- Admin bypass: none needed (admins do not go live as hosts); the owner can raise the value in the panel later
  (a setting like D-series panel settings) — out of scope.
- Per node in Phase 2: the API does not know which node a room lands on; per-node protection stays LiveKit's
  (`limit.*` + `sysload_limit`). The guard is the cluster-wide ceiling.

### 6.3 Contract (needs a contract-change proposal on the board, CONVENTIONS §4 + openapi)

| Code | HTTP | When | Client |
|---|---|---|---|
| `LIVE_CAPACITY_FULL` | 503, `Retry-After: 60` | `startLiveRoom` while the count ≥ the ceiling | shows «البث مزدحم الآن، حاول بعد قليل» / "Live is busy right now, please try again shortly" with a retry button; not an error toast |

Additive: unknown codes already fall back in the app (CONVENTIONS v1.3 note), so an older app shows the generic error.

### 6.4 Implementation outline (for the later approved task)

- API: `ErrorCode.LIVE_CAPACITY_FULL` (503) + message; env `LIVE_MAX_CONCURRENT_ROOMS` (intSetting 0–100000, default 0);
  the check in `startLiveRoom` right after the `LIVE_HOSTING_ENABLED` / permission checks, before the insert; openapi
  `503` response on `startLiveRoom` with the code; CONVENTIONS §4 row + §10 note.
- Mobile: `ErrorCode.liveCapacityFull('LIVE_CAPACITY_FULL')` in `app_failure.dart`, `failure_messages.dart` →
  `l10n.errorLiveCapacityFull`; ARB ar «البث مزدحم الآن، حاول بعد قليل» / en "Live is busy right now, please try
  again shortly." (+ description); the go-live screen keeps the setup and offers «حاول مجددًا».
- Tests: API unit (config), e2e (limit 1: second host 503 + `Retry-After`; a viewer of the first room still gets a
  token; ending the first room lets the second start; limit 0 = off), mobile unit for the mapping, golden/widget for the
  message in ar + en.

### 6.5 Why not in this branch

This branch was scoped as infrastructure with "no app changes"; the guard is a client-visible contract change (new
error code in CONVENTIONS §4 and openapi, the mobile mapping, ar/en strings, screen behaviour) that CONVENTIONS requires
to land as one coordinated API + mobile change set with a board proposal, and its ceiling can only be set from the
Phase 1 measurements, which do not exist yet. With the default "off" it would change nothing today. Recommended as the
next task once SINGLE_NODE_CAPACITY_RESULTS.md has numbers.
