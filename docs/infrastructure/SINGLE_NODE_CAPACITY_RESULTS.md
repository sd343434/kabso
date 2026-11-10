# Single-node capacity results — Phase 1 (D350)

**TEMPLATE — EMPTY. No test has been run; no number in this file is a measurement until a row is filled with its date,
generator set and raw log path.** Method and TARGETS: [`PHASE_1_TEST_PLAN.md`](./PHASE_1_TEST_PLAN.md) T7.

## 1. Setup (fill before the first stage)

| Item | Value |
|---|---|
| Node | EX44, FSN1, IP: |
| LiveKit / Caddy / node_exporter image digests (from `docker compose ps`) | |
| `livekit.yaml` hash (`sha256sum /etc/kabso-media/livekit.yaml`) | |
| Kernel, sysctl file version | |
| Generators (type, location, vCPU, port) | g1: · g2: · g3: |
| iperf3 node → generator (Mbit/s, `-R`, 30 s) | g1: · g2: · g3: |
| `lk` version | |
| Date / operator | |

## 2. Stages

| Stage | Date (UTC) | Rooms × shape × subs | Testers connected / planned | Avg loss % | Worst-room loss % | CPU % (avg / peak) | Load/CPU | Egress Mbit/s | Ingress Mbit/s | kpps out | UDP buf errors Δ | Join p95 ms | Mem free % | Within TARGETS? | Raw logs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| L0 | | 1 × SOLO × 10 | | | | | | | | | | | | | |
| L1 | | 25 × SOLO × 4 | | | | | | | | | | | | | |
| L2 | | 50 × SOLO × 4 | | | | | | | | | | | | | |
| L3 | | 100 × SOLO × 4 | | | | | | | | | | | | | |
| L4 | | 150 × SOLO × 4 | | | | | | | | | | | | | |
| L5 | | 200 × SOLO × 4 | | | | | | | | | | | | | |
| M1 | | 1 × SOLO × 300 | | | | | | | | | | | | | |
| M2 | | 10 × PK × 10 | | | | | | | | | | | | | |
| M3 | | 10 × MULTI × 10 | | | | | | | | | | | | | |
| M4 | | 20 × AUDIO × 20 | | | | | | | | | | | | | |
| X1 | | mix | | | | | | | | | | | | | |

## 3. Connectivity matrix (T1) — results

| Client | A Wi-Fi | B mobile | C no UDP | D 443 only | E VPN | Candidate types seen | Notes |
|---|---|---|---|---|---|---|---|
| Android | | | | | | | |
| iPhone | | | | | | | |
| Studio Chrome | | | | | | | |
| Studio Safari / Firefox | | | | | | | |
| Admin watch | | | | | | | |

## 4. Conclusions (fill after the stages)

| Output | Value | From stage |
|---|---|---|
| Ceiling, SOLO rooms of 4 viewers | | |
| Ceiling, realistic mix | | |
| Egress plateau (Mbit/s) | | |
| `LIMIT_BYTES_PER_SEC` for production | | |
| Capacity guard (D351): `LIVE_CAPACITY_MAX_ROOMS` per node (≈ 80 % of the mix ceiling) and the audio weight `LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT` | | |
| `sysload_limit` for Phase 2 | | |
| sysctl changes needed | | |
| Nodes needed for the production target (Phase 0 demand) | | |
