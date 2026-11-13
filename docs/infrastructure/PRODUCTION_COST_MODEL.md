# Production cost model — self-hosted LiveKit on Hetzner (Phase 0)

Planning only. **Nothing has been bought.** The owner owns **no** Hetzner server; the only existing server is the
staging VPS (Hostinger KVM 1, `live.kabsolive.com`). Every line below is a **new order**. The ≈ $750–800/month budget is
a target, not an authorisation. Unit prices: [`HETZNER_SERVER_COMPARISON.md`](./HETZNER_SERVER_COMPARISON.md)
(VERIFIED on 2026-11-09 unless marked). All prices are excl. VAT.

This file replaces `COST_MODEL.md` option D. That option assumed the owner already ran an AX41 and an AX42, which is
wrong, and it used search-index prices (AX42 €57.30, AX41 €42.30) that the live pages do not confirm (AX42 **€99**,
AX41 **€59**).

## 0. Owner decision (2026-11-09, D350) — supersedes the AX choice in §3–§4

**Owner decision, 2026-11-09 (after Phase 0; D350):** direction "self-hosted LiveKit on Hetzner dedicated" approved.
AX41 is **not available** to order. Media nodes: **EX44** (Intel i5-13500, 14 cores / 20 threads, 64 GB DDR4,
2 × 512 GB NVMe, 1 Gbit/s guaranteed, unlimited traffic, FSN1) at **$74/month, $0 setup**. App/DB at production:
**EX63** at **$174/month + $84 setup**. Prices as seen **on the owner's Hetzner account on 2026-11-09, in USD, VAT 0 %
on his account** (OWNER; not read by us on hetzner.com). Phase 1: **one EX44** as a single-node test
(`LIVEKIT_SINGLE_NODE_DEPLOYMENT.md`). Production plan: **5 × EX44 media + 1 × EX63 app/DB**.

| Production (owner's plan) | Units | Monthly | Setup | Label |
|---|---|---|---|---|
| Media nodes EX44 (N+1 per §2: 4 carry the target at 80 %, the 5th is the buffer) | 5 × $74 | **$370** | $0 | OWNER prices |
| App/DB EX63 | 1 × $174 | **$174** | $84 | OWNER prices |
| **Total servers** | | **$544/month** | **$84 once** | VAT 0 % on his account |
| Phase 1 (now) | 1 × EX44 | $74 | $0 | OWNER prices |

Backups (Storage Box), a vSwitch, extra IPs and load generators come on top as in §3/§6 (EUR prices from Phase 0, not
re-checked). The EX44's port is the same 1 Gbit/s guaranteed class as AX41's, so the node-count math in §2 is
unchanged (ESTIMATE until SINGLE_NODE_CAPACITY_RESULTS.md has numbers). §3–§4 below are kept as the Phase 0 record.

## 1. Demand (from MEDIA_ARCHITECTURE_AUDIT.md §h)

| Item | Value | Label |
|---|---|---|
| Ingress | 250 × 2.5 Mbit/s = **625 Mbit/s** (incoming traffic is not counted by Hetzner, VERIFIED) | ESTIMATE (owner's inputs) |
| Egress at peak | 1,000 × 2 Mbit/s = 2.0 Gbit/s; **plan 2.3–2.4 Gbit/s** with audio, RTCP, retransmits and TURN overhead | ESTIMATE |
| Monthly egress | **135 TB** (1,000 concurrent for 5 h/day) · worst case **648 TB** (24 h/day) | ESTIMATE |
| Reduction levers not yet applied | `adaptiveStream` and `dynacast` are off in the Flutter app; turning them on lowers egress in MULTI/PK | ESTIMATE, measure in Phase 1 |

## 2. Node-count math (ESTIMATE until load-tested)

Usable egress per 1 Gbit node: **700 Mbit/s at 70 %** of the port, or 800 Mbit/s at 80 %. The port is guaranteed at
1 Gbit/s (VERIFIED).

| Nodes × 1 Gbit | Capacity at 70 % | Capacity at 80 % | One node lost (70 % / 80 %) | Meets 2.4 Gbit/s? |
|---|---|---|---|---|
| 2 | 1.4 | 1.6 | 0.7 / 0.8 | **No**, even with every node up (2 × 1 Gbit = 2 Gbit/s at 100 % < 2.4) |
| 3 | 2.1 | 2.4 | 1.4 / 1.6 | Only at 80 %, no N+1 |
| **4** | 2.8 | 3.2 | 2.1 / **2.4** | Yes. **N+1 holds at 80 %** with one node down |
| **5** | 3.5 | 4.0 | **2.8** / 3.2 | Yes. **Strict N+1 at 70 %** |

A room must fit on one node (VERIFIED, LiveKit distributed docs). With ~4 viewers per room this never binds. The
largest single room is limited to about 700–800 Mbit/s, roughly 350–400 viewers at 2 Mbit/s.

## 3. Recommended initial topology (R1), recommendation only

| # | Role | Model | Location | Monthly | Setup | Label |
|---|---|---|---|---|---|---|
| 1 | **App/DB server**: API, PostgreSQL, app Redis, **separate LiveKit Redis instance**, Caddy (api/admin/studio/site + `live.` signalling front), Prometheus + Grafana | AX42 (Ryzen 7 PRO 8700GE, 64 GB **ECC**, 2 × 512 GB NVMe) | FSN1 | €99.00 | €49.00 | VERIFIED |
| 2–5 | **Media nodes** ×4: LiveKit + embedded TURN (UDP 3478 + TLS 443), host networking, private vSwitch to the app server | 4 × AX41 (Ryzen 5 3600, 64 GB, 1 Gbit guaranteed) | FSN1 | 4 × €59.00 = €236.00 | €0.00 | VERIFIED |
| — | Backups (pg dumps, configs) | Storage Box 1 TB | — | €3.20 | — | VERIFIED |
| — | Private network | vSwitch | — | €0 (no price shown) | — | ESTIMATE |
| — | **Contingency: 1 extra IPv4 per media node**, only if TURN/TLS must share a host with another 443 service (see §5) | 4 × additional IP | — | 4 × €1.70 = €6.80 | 4 × €4.90 = €19.60 | VERIFIED |
| — | Staging media test node (optional; the staging VPS is too small for LiveKit) | Cloud CPX22 (2 vCPU, 4 GB, 20 TB) | FSN1/NBG1 | €19.99 | — | VERIFIED |

| Total | Monthly € | Monthly $ (≈ €1 = $1.12, ESTIMATE) | One-time setup € |
|---|---|---|---|
| Core (app + 4 media + backups) | **€338.20** | ≈ $379 | €49.00 |
| + IPv4 contingency | €345.00 | ≈ $386 | €68.60 |
| + staging media node | **€364.99** | ≈ **$409** | €68.60 |
| Same, if 19 % German VAT is charged (depends on the account, see the questions) | €434.34 | ≈ $486 | €81.63 |
| **Strict N+1 variant**: a 5th AX41 | €423.99 | ≈ $475 | €68.60 |

**Against the budget:** R1 is about **$380–475/month** before VAT, so **$275–420/month below** the $750–800 target.
That headroom pays for a 6th node, a 10G uplink on one node, or Hetzner price rises. Hetzner raised prices several
times in 2026 (SOURCED-SECONDARY, `COST_MODEL.md` §5), and the live prices are 40–73 % above last year's search
figures. Budget **+10–25 % per year** as renewal risk (ESTIMATE). With no minimum term and immediate cancellation
(VERIFIED), nodes can be added or removed month by month.

**Why AX41 for media and AX42 for the app server (ESTIMATE):** SFU forwarding at ≤ 1 Gbit/s is network-bound
(HETZNER_SERVER_COMPARISON §8), so the cheaper Zen 2 node is enough and has **no setup fee**. PostgreSQL gets ECC
RAM and Zen 4. If the owner prefers identical modern hardware everywhere, use the **R2** variant below.

## 4. Alternatives (same app server, backups and staging node included)

| Variant | Media tier | Monthly € (135 TB) | Monthly € (648 TB worst case) | Setup € | N+1 | Notes |
|---|---|---|---|---|---|---|
| **R1** | 4 × AX41 1 Gbit | **€364.99** | €364.99 (unmetered) | €68.60 | yes at 80 % | recommended start |
| R1+ | 5 × AX41 1 Gbit | €423.99 | €423.99 | €68.60 | yes at 70 % | if tests show > 2.1 Gbit/s |
| R2 | 4 × AX42 1 Gbit | €524.99 | €524.99 | €264.60 | yes at 80 % | newer hardware, ECC; $588/month |
| R2+ | 5 × AX42 1 Gbit | €623.99 | €623.99 | €313.60 | yes at 70 % | $699/month, still under budget |
| R3 | 3 × AX42 + 10G uplink | 3 × €142 + €99 + €3.20 + €19.99 + (135 − 60) TB × €1 = **€623.19** | + (648 − 60) × €1 → **€1,136.19** | €196.00 | doubtful: CPU-bound per node, no Robot firewall | traffic metered, over budget at worst case |
| R4 | 2 × AX102 + 10G uplink | 2 × €302 + €99 + €3.20 + €19.99 + (135 − 40) TB × €1 = **€821.19** | + (648 − 40) × €1 → **€1,334.19** | €307.00 | one node = 50 % of capacity | over budget |

Overage arithmetic uses the VERIFIED figures of 20 TB included per 10G server and €1.00/TB beyond.

## 5. TURN/TLS and IPv4 (cost impact)

- LiveKit (VERIFIED, deployment docs): TURN/TLS "needs a separate TURN domain and SSL cert". "If not using a load
  balancer, `turn.tls_port` needs to be set to 443". LiveKit terminates TLS itself, from `cert_file`/`key_file`.
- LiveKit's own VM recipe (VERIFIED, `self-hosting/vm`) opens "443 - primary HTTPS and TURN/TLS" on **one** IP. Its
  generated Caddy config sits in front. ESTIMATE: it does this with a layer-4 SNI split, which the stock
  `caddy:2.10.2-alpine` image in this repo does not include.
- **In R1 no extra IPv4 is needed:** signalling `wss://live.kabsolive.com` stays on the **app server's** Caddy,
  proxied to the media nodes' 7880 over the vSwitch. Port 443 on each media node's own IP is then free for TURN/TLS
  (`turn1…turn4.kabsolive.com`). The amendment "TURN-TLS 443 needs a separate IPv4" applies only when TURN shares an
  IP with another 443 service. The contingency line covers that case for **€6.80/month + €19.60 once**.

## 6. Temporary load-generator cost (one-time)

`lk load-test` (VERIFIED, LiveKit CLI docs) simulates publishers and subscribers **in one room per run**. It publishes
720p simulcast with keyframes about every 3 s, and the docs say to run it "on a machine with plenty of CPU and
bandwidth" with `ulimit -n 65535`, "from several machines" for more load. The generators therefore have to
**receive ≈ 2.0–2.4 Gbit/s** (the subscribers' downlink) and **send ≈ 0.6 Gbit/s** (the publishers), so at least 3–4
machines with 1 Gbit/s each are needed (ESTIMATE).

| Step | Machines | Duration | Cost | Label |
|---|---|---|---|---|
| A. Single-node ceiling (1 target + 3 generators) | the 4 purchased AX41s + the app server | 1–2 days | **€0 extra** (internal traffic is not counted, VERIFIED) | ESTIMATE |
| B. Full cluster (4 targets, 250 rooms × 1 publisher + 4 subscribers, PK/MULTI mix) | +4 × **AX41 hourly** (€0.0945/h, €0 setup, guaranteed 1 Gbit, unlimited traffic) | 72 h | 4 × €0.0945 × 72 = **€27.22** | VERIFIED unit price |
| B (alternative) | +4 × Cloud CCX33 (€0.2227/h) | 72 h | **€64.14**; generator outbound ≈ 0.6 Gbit/s × ~20 h of test ≈ 5–6 TB, inside the 20 TB/instance | VERIFIED unit price; cloud NIC throughput **not published** |
| Worst case if hourly billing were not applied to a fresh dedicated order | 4 × AX41 one month | — | €236.00 | ESTIMATE |

**Budget for load testing: €30–70 one-time, worst case €236.**

## 7. Staging

The Hostinger KVM 1 (owner, 2026-11-09; specs ESTIMATE ≈ 1 vCPU, 4 GB RAM, 50 GB NVMe, ≈ 4 TB/month traffic;
hostinger.com could not be reached from this session) **cannot host a meaningful LiveKit test**. At 2 Mbit/s per
viewer, 4 TB is used up in ≈ 4,400 viewer-hours, and one vCPU is shared with PostgreSQL and the API. Keep it as a
light API staging box with `LIVEKIT_URL` pointing at the CPX22 staging media node, or retire it once production
exists. Its monthly price is not in this model (owner to supply).

## 8. What this model does not include

LiveKit Egress or recording, HLS or CDN, a Gulf-region node, Cloudflare R2 storage (D45), domain costs, Remote Hands
(€21 per ¼ h), and staff time.
