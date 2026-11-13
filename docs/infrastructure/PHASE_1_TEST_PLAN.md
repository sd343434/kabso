# Phase 1 test plan — single LiveKit media node (D350)

Status: **PLAN. No test in this document has been run on a server or device.** The only things run so far are the
local checks in LIVEKIT_SINGLE_NODE_DEPLOYMENT.md §9. Every threshold here is a **TARGET**, not a result; results go
into [`SINGLE_NODE_CAPACITY_RESULTS.md`](./SINGLE_NODE_CAPACITY_RESULTS.md).

Order: T1–T4 on the node **before** staging is switched (test rooms with `lk` / test tokens), T5–T6 **after** the switch
(LIVEKIT_SINGLE_NODE_DEPLOYMENT §6), T7 (load) last, outside the owner's test hours.

## T1 — Connectivity matrix (devices and browsers)

Join a test room (before the switch: tokens from `lk token create --join --room t1 --identity <name>` run on the
operator's machine with the node's key; after the switch: a real live through the app). Use LiveKit's public
connection tester only with a short-lived token, never with the key.

| Client | Network A: normal Wi-Fi | B: mobile data (4G/5G, Jordan/Egypt/KSA carriers available) | C: UDP blocked (firewall drops all UDP except DNS) | D: only 443/tcp allowed (TURN-TLS only) | E: VPN on |
|---|---|---|---|---|---|
| Android phone (Flutter app, publish + watch) | | | | | |
| iPhone (Flutter app, publish + watch) | | | | | |
| Flutter second-camera tool | | | | | |
| Studio «استوديو البث» in Chrome (screen + camera publish) | | | | | |
| Studio in Safari / Firefox | | | | | |
| Admin panel staff watch (subscribe only) | | | | | |

For every cell record: joined (y/n), time to first frame (s), **candidate pair type** (host-udp / tcp / relay-udp /
relay-tls — Chrome `chrome://webrtc-internals`, Flutter debug log, or LiveKit's participant log line), video ok after
2 min, reconnect after toggling Wi-Fi ↔ mobile.

How to make C and D on a laptop (Linux, as root; undo afterwards):
```bash
# C: drop all outgoing UDP except DNS
iptables -I OUTPUT -p udp ! --dport 53 -j DROP
# D: additionally allow only TCP 443 (and DNS) to the node
iptables -I OUTPUT -p tcp -d <NODE_IP> ! --dport 443 -j REJECT
# undo
iptables -D OUTPUT -p udp ! --dport 53 -j DROP; iptables -D OUTPUT -p tcp -d <NODE_IP> ! --dport 443 -j REJECT
```
On a phone: a laptop hotspot with those rules, or a corporate/guest Wi-Fi that is known to block UDP.

**TARGETS:** A and B: 100 % join for every client; C: join via ICE/TCP 7881 or TURN; D: join via **relay-tls** (TURN/TLS
443) for every client; E: join. Time to first frame ≤ 3 s on A/B, ≤ 6 s on C/D (TARGET).

## T2 — TURN-only check (no device needed)

From an outside machine: `python3 -I infra/media/test/probe.py stun-tls turn1.<domain> 443 turn1.<domain>` (valid
certificate, mapped address = the machine's public IP) and `probe.py stun-udp <NODE_IP> 443`. Then a browser with
`iceTransportPolicy: 'relay'` (LiveKit JS `rtcConfig: { iceTransportPolicy: 'relay' }` in a scratch page, not in the
product) must publish and subscribe. **TARGET:** both relay paths carry video for 5 min.

## T3 — Room lifecycle and webhook (before the switch)

1. Run `test/webhook-sink.py` on the operator's machine (public IP, port opened temporarily) with the node's key in
   its environment; set `LIVEKIT_WEBHOOK_URL=https://<sink>/…` (or an SSH reverse tunnel) and `update-media.sh
   --service config`.
2. `lk load-test --room t3 --video-publishers 1 --subscribers 2 --duration 1m` from the operator's machine.
3. **Expect** (all VALID): `room_started`, `participant_joined` ×3, `track_published`, then `track_unpublished`,
   `participant_left` ×3, `room_finished` (after `departure_timeout` 20 s). Record the delay from leave to webhook.
4. Kill the sink for 2 min during a room, restart it: LiveKit retries, but "no guarantees around delivery" — note what
   arrived (the API's sweeper covers gaps).

## T4 — Drain and restart on the node

Room with 1 publisher + 5 subscribers running; `update-media.sh --drain-timeout 600 --yes`. **Expect:** the room keeps
playing until it ends (no freeze); a NEW room cannot be created during the drain; the node is back and healthy after.
Also `reboot` of the node with no rooms: everything comes back by itself (restart policy, health timer).

## T5 — Through the API (after the switch)

| # | Action | Expected |
|---|---|---|
| 5.1 | Host goes live (video) on Android | media token `url` = `wss://media1.<domain>`; webhook `participant_joined` reaches `POST /livekit/webhook` (API log 200) |
| 5.2 | Viewer joins | viewer count +1 (`live_room_viewers`), viewer is **hidden** (not in the participant list of other clients) |
| 5.3 | Viewer leaves | count −1 within ~1 s of LiveKit's webhook |
| 5.4 | Host ends the live | `room_finished` → rows removed; no ghost viewers |
| 5.5 | Unsigned POST to `https://api.<domain>/livekit/webhook` from the internet | 401 `AUTH_UNAUTHENTICATED`; `/internal/livekit/webhook` from the internet still 404 |
| 5.6 | PK battle between two hosts | each audience sees both hosts (cross-room watch token) |
| 5.7 | AUDIO room with seats: seat, mute, unseat | publish permission follows at once (RoomService via `LIVEKIT_URL`/`LIVEKIT_API_URL`) |
| 5.8 | MULTI with guests | guests publish; viewers watch all |
| 5.9 | Studio screen share; admin staff watch | works through the new CSP origins |
| 5.10 | Rollback drill | restore `kabso.env.before-d350`, recreate api/caddy: new lives use `live.` again |

## T6 — Hidden viewer and permission checks

- A viewer token cannot publish (try with a modified client: publishing is refused by LiveKit) and cannot send data
  (`canPublishData: false`).
- Hidden viewers do not appear in `participants` of the host's client; a staff observer is invisible; a team watcher
  is visible only where designed (D250/D260).
- A kicked viewer is disconnected and its new token is refused (API).
- Token of room A used for room B: refused.

## T7 — Single-node load test (`lk load-test`)

### 7.1 Rules

- **Generators never run on the node under test** (`load-test.sh` refuses an address of its own machine). The node
  runs only LiveKit, Caddy and node_exporter during the test.
- Each generator: `ulimit -n 65535` (LiveKit benchmark docs), the pinned `lk` v2.19.3, its own `--prefix g1|g2|…`.
- One stage = several `lk load-test` processes (one room each) per generator, started together by `load-test.sh`.
- Hold each stage **10 min**; ramp `--num-per-second 5`; stop the ramp at the first broken threshold (§7.5) and record
  the last good stage as the ceiling.
- The app's real profile differs from lk's: lk subscribers are **visible** participants (Kabso viewers are hidden), lk
  does not simulate data messages, and lk publishes 720p simulcast with keyframes ≈ every 3 s. VP8 is forced
  (`--codec vp8`) because the apps publish VP8.

### 7.2 Room shapes (Kabso modes → lk)

| Shape | lk options | Stands for |
|---|---|---|
| SOLO | `--video-publishers 1 --subscribers N` | video live |
| PK | `--video-publishers 2 --subscribers N` | one audience of a PK battle (lk cannot watch two rooms per viewer) |
| MULTI | `--video-publishers 9 --layout 3x3 --subscribers N` | host + 8 seated video guests |
| AUDIO | `--audio-publishers 9 --subscribers N` | audio room, 9 seats |

### 7.3 Generators: how many, how big

ESTIMATE from LiveKit's numbers and the local smoke (a subscriber of one 720p simulcast publisher received ≈ 1.2–1.3
Mbit/s): to push the node's **egress to ~900 Mbit/s** the generators must **receive ~900 Mbit/s** and send the
publishers' uplink (~2.5 Mbit/s per video publisher). Keep each generator at ≤ 60–70 % of its own port so the generator
is not the bottleneck → **at least 2, better 3 machines with a guaranteed 1 Gbit/s port**, 4–8 vCPU each (lk does not
decode video; CPU use was not measured here). Options (**owner-approved 2026-11-10: a budget of ~€32 for the load
generators, approved, not spent yet** — PRE_PRODUCTION_CHECKLIST PP-84; prices from Phase 0 §7, eu-central,
excl. VAT): 3 × Hetzner Cloud CCX33 (€0.2227/h; **throughput per instance not published — measure with iperf3 first**;
generator outbound traffic counts against the 20 TB included), or hourly dedicated servers if offered. Two days of
three CCX33 ≈ 3 × €0.2227 × 48 h ≈ **€32**. Incoming traffic to the node is not counted by Hetzner (Phase 0 §2).

Before the stages: `iperf3 -s` on the node (temporary, port 5201 opened for the generator IPs only) and
`iperf3 -c <node> -R -t 30` from each generator → record real Mbit/s per generator; remove the rule afterwards.

### 7.4 Stages (fill SINGLE_NODE_CAPACITY_RESULTS.md)

| Stage | Mix (rooms × shape × subscribers) | Total subscribers | Purpose |
|---|---|---|---|
| L0 | 1 × SOLO × 10 | 10 | baseline, tool check |
| L1 | 25 × SOLO × 4 | 100 | the app's typical room (~4 viewers, Phase 0 audit) |
| L2 | 50 × SOLO × 4 | 200 | |
| L3 | 100 × SOLO × 4 | 400 | |
| L4 | 150 × SOLO × 4 | 600 | ≈ the estimated port limit |
| L5 | 200 × SOLO × 4 | 800 | past the estimate: expect the NIC to saturate |
| M1 | 1 × SOLO × 300 | 300 | one big room |
| M2 | 10 × PK × 10 | 100 | |
| M3 | 10 × MULTI × 10 | 100 | publisher-heavy (90 video ingress) |
| M4 | 20 × AUDIO × 20 | 400 | audio rooms |
| X1 | 60 % SOLO, 15 % PK, 15 % MULTI, 10 % AUDIO at the L3/L4 level | 400–600 | realistic mix (mix ratios are an ESTIMATE; owner to confirm) |

Split each stage's rooms evenly over the generators (e.g. `--rooms 50` on g1 and g2 for L3).

### 7.5 What to record and the acceptance TARGETS

| Metric | Where | TARGET (not a result) |
|---|---|---|
| Join success | lk summaries (`Total` line, Error column) per room | ≥ 99.5 % of testers connected and subscribed |
| Subscriber packet loss | lk `Total Pkt. Loss`; `livekit_packet_loss_percent` | ≤ 1 % average, ≤ 3 % worst room |
| Node CPU | node_exporter `node_cpu_seconds_total` (all cores); load per CPU (`node_load1` / 20) | ≤ 70 % sustained; load/CPU ≤ 0.7 (the Phase 2 `sysload_limit`) |
| NIC egress / ingress | `node_network_transmit_bytes_total` / `receive` on the uplink | record the plateau; capacity planning uses ≤ 80 % of 1 Gbit/s |
| Packets per second | `node_network_transmit_packets_total` | record |
| UDP buffer errors | `node_netstat_Udp_RcvbufErrors`, `SndbufErrors` (or `netstat -su`) | **0** growth (else raise sysctl buffers) |
| Join latency | `livekit_session_join_latency_ms` | p95 ≤ 1 s (TARGET) |
| Forward latency | `livekit_forward_latency` | record p90 |
| RTT / jitter | `livekit_rtt_ms`, `livekit_jitter_us` | record |
| Rooms / participants | `livekit_room_total`, `livekit_participant_total` | match the stage |
| Memory | `node_memory_MemAvailable_bytes` | ≥ 50 % free |
| Webhook queue | `livekit_webhook_queue_length` | stays near 0 (sink or API keeps up) |

Read metrics on the node with `curl -s 127.0.0.1:6789/metrics` and `curl -s 127.0.0.1:9100/metrics` (SSH), or a
temporary Prometheus on a generator scraping through an SSH tunnel. Capture `docker stats` and `top -H` once per stage.

### 7.6 Outputs of T7

- The ceiling per shape and for the mix (last stage within all TARGETS).
- Production values: `LIMIT_BYTES_PER_SEC` (≈ 80 % of the measured plateau, in+out) and the capacity guard's
  `LIVE_CAPACITY_MAX_ROOMS` / `LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT` (D351, DEPLOYMENT §11.10), `sysload_limit` for Phase 2.
- Whether sysctl values need changing (UDP buffer errors).
