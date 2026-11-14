# Kabso Live — Media Cost Model (Phase 0)

> **Superseded in part (2026-11-09):** the owner owns **no** Hetzner server (AX41/AX42 were options only), and the
> Hetzner prices here were search-index readings. See `PHASE_0_INFRASTRUCTURE_READINESS.md`,
> `HETZNER_SERVER_COMPARISON.md` (VERIFIED prices) and `PRODUCTION_COST_MODEL.md`.

Companion to [`MEDIA_ARCHITECTURE_AUDIT.md`](./MEDIA_ARCHITECTURE_AUDIT.md). Planning only: nothing was ordered,
no account was created, and the ≈ $750–800/month budget is a target, not an authorisation.

## 0. How to read the figures (important)

On 2026-11-09 this session **could not fetch any provider page**: `www.hetzner.com`, `docs.hetzner.com`, `bunny.net`
and `livekit.io` all failed DNS resolution inside the sandbox (network allowlist). Prices were therefore collected
through **web search**, which returns the search index's reading of a page, not the page itself.

| Label | Meaning |
|---|---|
| **VERIFIED** | Read on the official page, with URL and date. **No figure in this document reaches this level.** |
| **SOURCED-OFFICIAL** | Found via search on 2026-11-09, attributed by the index to the provider's own page/press release (URL given). Re-check on the live page. |
| **SOURCED-SECONDARY** | Found via search on 2026-11-09 from a third-party listing/review/aggregator (URL given). Lower confidence. |
| **ESTIMATE** | Arithmetic or engineering judgement; reasoning shown. |

To upgrade figures to VERIFIED, allow those four hosts in the session network and re-run the checks (open question
9 in the audit). Prices exclude VAT unless stated. Currency: as published; where a USD comparison is needed,
€1 ≈ $1.12 (ESTIMATE, derived from Hetzner's own €43 / $48 pair for the 10G uplink below).

## 1. Demand assumptions (from the audit §h)

| Item | Value | Basis |
|---|---|---|
| Ingress | 625 Mbps | 250 × 2.5 Mbps |
| Egress (peak) | 2.0 Gbps; plan 2.3–2.4 Gbps with overhead | 1,000 × 2 Mbps (+10–20 %, ESTIMATE) |
| Egress per viewer-hour | 0.9 GB | 2 Mbps × 3600 / 8 |
| Monthly egress, base case | **135 TB** | 5,000 viewer-hours/day × 0.9 GB × 30 (= 1,000 concurrent for 5 h/day) |
| Monthly egress, worst case | **648 TB** | 1,000 concurrent 24 h/day |
| Participant-minutes/month (for LiveKit Cloud) | ≈ 11.25 M | viewers 5,000 h/day × 60 × 30 = 9.0 M; broadcasters 250 × 5 h/day × 60 × 30 = 2.25 M (ESTIMATE: broadcaster hours not given by owner) |

## 2. Unit prices found

### 2.1 Hetzner (Germany: Falkenstein, Nuremberg; Finland: Helsinki)

| Item | Figure | Label | Source |
|---|---|---|---|
| AX42 at launch (Apr 2024) | €46.00/mo or €0.0737/h up to the monthly cap; setup €39; prices excl. VAT | SOURCED-OFFICIAL | https://www.hetzner.com/press-release/new-ax42 |
| AX42 after 1 Apr 2026 increase | €47.30 → **€57.30/mo** (DE) | SOURCED-SECONDARY | https://agentdeals.dev/hetzner-pricing-2026 ; https://baremetalbench.pages.dev/reviews/hetzner |
| AX41-NVMe after 1 Apr 2026 | €41.10 → **€42.30/mo** | SOURCED-SECONDARY | https://agentdeals.dev/hetzner-pricing-2026 |
| AX102 after 1 Apr 2026 | €107.30 → **€122.30/mo** | SOURCED-SECONDARY | same |
| Setup fee, new orders | AX42 **€49**, AX102 **€129** (reported as checked against Hetzner's price API 2 Oct 2026) | SOURCED-SECONDARY | https://github.com/robhunter/agentdeals/issues/2273 |
| **Conflicting** "AX42-1" rows on Hetzner's price-adjustment page | €97.30 + €49 setup in one table; €187.30 + €94 setup (FSN/HEL) in another — context of these tables unclear (possibly a newer/limited-tier product line) | SOURCED-OFFICIAL (fragmentary) | https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/ |
| 1 Gbit dedicated uplink traffic | **Unlimited**; only outbound counted (incoming/internal not counted per a secondary source); no published fair-use cap found | SOURCED-OFFICIAL / SECONDARY | https://docs.hetzner.com/robot/general/traffic/ ; https://inxy.hosting/blog-posts/hetzner-vs-ovh |
| 10 Gbit uplink | **€43/mo ($48)**, NIC included, one per server (Aug 2026 add-on list) | SOURCED-OFFICIAL | https://docs.hetzner.com/robot/dedicated-server/network/10g-uplink/ ; https://docs.hetzner.com/robot/general/pricing/price-list-for-additional-products |
| 10 Gbit traffic quota | **20 TB/month included, then €1/TB**, billed in 100 MB steps, no throttling | SOURCED-OFFICIAL (via index) | https://docs.hetzner.com/robot/general/traffic/ |
| Hetzner Cloud CCX33 (8 dedicated vCPU, 32 GB, 240 GB) | €48.49/mo (2025 listing); 30 TB? or 20 TB EU included (sources disagree); ≈ €1/TB overage; cloud prices raised 15 Jun 2026 for new orders — current price **not found** | SOURCED-SECONDARY | https://www.whtop.com/plans/hetzner.com/128292 ; https://www.bitdoze.com/hetzner-cloud-review/ ; https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/ |
| AX42 hardware | 8-core Ryzen 7 PRO 8700GE, 64 GB DDR5 ECC, 2 × 512 GB NVMe | ESTIMATE (from memory of the launch release; confirm) | https://www.hetzner.com/news/new-ax42 |

### 2.2 EPYC 9355P servers actually on sale (origin for options A–C)

| Provider | Config / price | Label | Source |
|---|---|---|---|
| DediPeak | 9355P 32c, 128 GB DDR5, 2 × 1.92 TB NVMe, 10 Gbps — **$199/mo** | SOURCED-SECONDARY (provider site via index) | https://dedipeak.com/ |
| LowCostDedi | similar, 10 Gbps unmetered, monthly, no contract, no setup — **$199/mo** | SOURCED-SECONDARY | https://lowcostdedi.com/dedicated-servers |
| Worldstream (NL) | Dell R6715, 9355P, 2 × 960 GB NVMe — **€329/mo** | SOURCED-SECONDARY | https://www.worldstream.com/en/about-worldstream/amd-epyc-servers/ |
| Evolushost (Amsterdam) | 128 GB DDR5 — **€461.99/mo + €693.99 setup** | SOURCED-SECONDARY | https://www.serverhunter.com/offer/evolushost-amd-epyc-9355p-dedicated-server-by-evolushost/ |
| Cherry Servers | EPYC 9355 (non-P) — **$700.83/mo** ($1.20/h) | SOURCED-SECONDARY | https://www.cherryservers.com/pricing/dedicated-servers/amd-epyc-9355 |
| Qloudhost | 32c, 128 GB ECC, 2 × 960 GB NVMe, 10 Gbps — **$799.99/mo** | SOURCED-SECONDARY | https://qloudhost.com/blog/best-server-for-sportsbook/ |

The $199 offers come from small resellers; "10 Gbps unmetered" at that price usually means a shared/oversubscribed
port — ask for a committed-rate figure before relying on it (ESTIMATE). Hetzner does **not** list a 9355P server in
the results found.

### 2.3 OVHcloud
Advance range: public bandwidth 1–5 Gbps by model, 25 Gbps private; some configs "3 Gbps unmetered, guaranteed"; one
Canadian listing Advance-1 2026 **$201.59 incl. VAT/mo**; fair-use rule does not apply to the guaranteed-bandwidth
option; 5 Gbps upgrade price **not found**. SOURCED-OFFICIAL (index): https://us.ovhcloud.com/bare-metal/advance/ ,
https://www.ovhcloud.com/en/bare-metal/regions-availability/ . Rise bandwidth terms: **not found**.

### 2.4 Contabo-class VPS (owner's two VPS)
"32 TB traffic, unlimited incoming", port 200 Mbit/s–1 Gbit/s by tier (SOURCED-OFFICIAL via index:
https://contabo.com/vps ). A secondary source reports throttling to 100 Mbit/s after 10 days averaging > 100 Mbit/s
(unconfirmed: https://bestusavps.com/guides/contabo-cloud-vps-4/ ). **Conclusion (ESTIMATE): unsuitable as media
nodes at 2 Gbps**; fine for API/Postgres/monitoring.

### 2.5 Bunny CDN
| Network | Price | Label | Source |
|---|---|---|---|
| Standard — Europe & North America | $0.010/GB | SOURCED-OFFICIAL | https://bunny.net/pricing/ |
| Standard — Asia & Oceania | $0.030/GB | SOURCED-OFFICIAL | same |
| Standard — South America | $0.045/GB | SOURCED-OFFICIAL | same |
| Standard — **Middle East & Africa** | **$0.060/GB** | SOURCED-OFFICIAL | same |
| **Volume network** (≈ 10 PoPs) | $0.005/GB 0–500 TB; $0.004 500 TB–1 PB; $0.002 1–2 PB; > 2 PB quote | SOURCED-OFFICIAL | same |
| Volume network PoPs | Frankfurt, Paris, Chicago, Dallas, LA, Miami, Hong Kong, Singapore, Tokyo… — **no Middle-East Volume PoP found**; Dubai PoP is in the ME/Africa tier | SOURCED-OFFICIAL | https://bunny.net/cdn ; https://bunny.net/blog/the-bunnies-expand-to-dubai/ |
| Monthly minimum | $1 | SOURCED-SECONDARY | https://www.bitdoze.com/bunny-net-review/ |

### 2.6 LiveKit Cloud
| Plan | Price / included | Overage | Label | Source |
|---|---|---|---|---|
| Build | $0 | — | SOURCED-OFFICIAL | https://livekit.com/pricing |
| Ship | $50/mo, 150,000 WebRTC min | $0.0005/min | SOURCED-OFFICIAL | same |
| Scale | $500/mo, 1.5 M WebRTC min | $0.0004/min | SOURCED-OFFICIAL | same |
| Bandwidth | Ship 250 GB then $0.12/GB; Scale 3 TB then $0.10/GB | — | **SOURCED-SECONDARY** (current official page excerpt did not show bandwidth) | https://micdrop.dev/blog/livekit-pricing ; https://www.forasoft.com/blog/article/livekit-vs-agora-cost-analysis |
| Enterprise | volume pricing | — | SOURCED-OFFICIAL | https://livekit.com/pricing |

## 3. Options

Base case 135 TB/month egress; worst case 648 TB in brackets. Monthly figures exclude VAT and IPv4 add-ons.

### A — Proposed: Origin EPYC 9355P + 2 Edges (SRS → FFmpeg → HLS → Nginx over WireGuard, HAProxy)
| Line | Monthly | Setup | Label |
|---|---|---|---|
| Origin 9355P | $199 – $800 (≈ €330 Worldstream mid-point) | $0 – €694 | SOURCED-SECONDARY |
| 2 × edge (8 vCPU/16–24 GB, 1 Gbps) on Hetzner Cloud CCX33-class | 2 × €50–100 (post-June-2026 price unknown) | 0 | ESTIMATE |
| Edge traffic overage | (135 TB − 2 × 20–30 TB) × €1/TB ≈ €75–95 [≈ €590–610] | — | ESTIMATE from SOURCED €1/TB |
| **Still required:** a LiveKit tier for PK/seats/audio/podcast | see D (≥ 1 AX node, €42–57) | | ESTIMATE |
| **Total** | **≈ $450 – $1,150** [≈ $950 – $1,700] | | ESTIMATE |

Capacity issue (ESTIMATE): 2 edges × 1 Gbps = 2.0 Gbps at 100 % — **below** the 2.3–2.4 Gbps plan; ABR transcoding of
250 streams does not fit one 32-core origin (audit §h). Single-rendition remux fits but gives no ABR.

### B — Origin + 4 Edges
Origin as A + 4 × €50–100 + overage (135 − 4 × 20–30 TB, ≈ €15–55) [≈ €530–570] + LiveKit tier.
**≈ $650 – $1,400** [≈ $1,150 – $2,000]. ESTIMATE. Bandwidth-adequate (4 Gbps); ABR CPU issue unchanged.

### C — Origin + 4 smaller Edges
Edges as Hetzner **AX41-NVMe dedicated at €42.30** (unmetered 1 Gbit, no overage) → 4 × €42.30 = €169 + setup
(AX41 setup not found; ESTIMATE ≤ €49 each). Origin $199–800 + LiveKit tier.
**≈ $450 – $1,050**, no traffic overage even in the worst case. ESTIMATE from SOURCED-SECONDARY prices.
(Cheaper and safer than cloud edges because Hetzner dedicated 1 Gbit traffic is unmetered.)

### D — Recommended: self-hosted LiveKit SFU on Hetzner AX (owner's AX41 + AX42, + 1–2 AX42)
| Line | Monthly | Setup | Label |
|---|---|---|---|
| AX41 + AX42 (owner already has them) | €42.30 + €57.30 = €99.60 (already being paid → €0 incremental) | 0 | SOURCED-SECONDARY |
| +2 × AX42 (to reach 4 × 1 Gbit ≈ 2.8 Gbps at 70 %) | 2 × €57.30 = €114.60 (or 2 × €97.30 = €194.60 if the higher AX42-1 row applies) | 2 × €49 | SOURCED-SECONDARY / -OFFICIAL (conflict) |
| *or* 10G uplink on 1–2 nodes instead | €43 each + (egress − 20 TB) × €1/TB ≈ €115 [≈ €630] | — | SOURCED-OFFICIAL |
| Redis + Prometheus/Grafana | on the API host or a small VPS (≈ €5–15) | — | ESTIMATE |
| TURN | LiveKit embedded TURN on the same nodes | €0 | ESTIMATE |
| **Total (4 × 1 Gbit nodes)** | **≈ €215 – €310/mo all-in (≈ €115–195 incremental)**, no overage even at 648 TB | ≈ €98 | ESTIMATE |
| **Total (2 nodes + 10G on each)** | ≈ €100 + €86 + €95–115 ≈ **€280–300/mo** [≈ €800 worst case] | — | ESTIMATE |

CPU (ESTIMATE): forwarding ~0.7 Gbps per 8-core node is network-bound; confirm with a load test before ordering.
Each room lives on one node (SOURCED: https://docs.livekit.io/transport/self-hosting/distributed/), irrelevant at
4 viewers/room.

### E — LiveKit Cloud
| Line | Base case | Worst case | Label |
|---|---|---|---|
| Scale plan | $500 | $500 | SOURCED-OFFICIAL |
| Minutes overage: (11.25 M − 1.5 M) × $0.0004 | $3,900 | ≈ $21,000 (24 h viewers: 43.2 M + broadcasters) | ESTIMATE |
| Bandwidth: (135 TB − 3 TB) × $0.10/GB | **$13,200** | ≈ $64,500 | ESTIMATE from SOURCED-SECONDARY rate |
| **Total** | **≈ $17,600/mo** | ≈ $86,000/mo | ESTIMATE (Enterprise discounts not known) |

### Bunny CDN fallback / overflow (only if HLS exists — the current app cannot play HLS)
| Volume | Standard ME&A ($0.06) | Standard Asia ($0.03) | Standard EU ($0.01) | Volume network ($0.005, no ME PoPs) |
|---|---|---|---|---|
| 10 % overflow = 13.5 TB | $810 | $405 | $135 | $68 |
| 25 % = 33.75 TB | $2,025 | $1,013 | $338 | $169 |
| 100 % = 135 TB | $8,100 | $4,050 | $1,350 | $675 |
| Worst 648 TB | $38,880 | $19,440 | $6,480 | $3,240 (tier 1) |
ESTIMATE from SOURCED-OFFICIAL unit prices (1 TB = 1,000 GB). Which tier Middle-East viewers are billed at depends on
the PoP that serves them; with the Volume network they are served from European/Asian PoPs (latency).

### Summary

| Option | Monthly (base 135 TB) | Monthly (worst 648 TB) | Interactive modes? | Fits ≈ $750–800? |
|---|---|---|---|---|
| A Origin + 2 edges | ≈ $450–1,150 + LiveKit tier | ≈ $950–1,700 | No (needs LiveKit too) | Partly; under-provisioned |
| B Origin + 4 edges | ≈ $650–1,400 | ≈ $1,150–2,000 | No | Upper half over budget |
| C Origin + 4 AX41 edges | ≈ $450–1,050 | same (unmetered) | No | Yes at low end |
| **D LiveKit self-hosted on AX** | **≈ €215–310 (≈ $240–350)** | ≈ €215–310 (1 Gbit nodes) | **Yes (as built)** | **Yes, with headroom** |
| E LiveKit Cloud | ≈ $17,600 | ≈ $86,000 | Yes | No |
| Bunny overflow | +$68–810 per 10 % | — | No (HLS only) | Optional later |

All totals ESTIMATE; unit prices SOURCED (not VERIFIED).

## 4. Geography and latency

Hetzner dedicated servers are offered in Falkenstein and Nuremberg (Germany) and Helsinki (Finland)
(SOURCED-OFFICIAL via the price-adjustment page's location columns). No Hetzner dedicated location in the Middle East
was found.

| Path | RTT | Label | Source |
|---|---|---|---|
| Riyadh → Frankfurt | 81 ms (single probe, 31 Jul 2026); 94 ms median (11–25 Oct 2026) | SOURCED-SECONDARY (citing WonderNetwork) | https://wondernetwork.com/pings/Riyadh/Frankfurt ; https://space-node.net/blog/minecraft-server-hosting-middle-east-2026 |
| Dubai → Frankfurt | 115 ms median (Oct 2026); 110–130 ms vendor range | SOURCED-SECONDARY | https://wondernetwork.com/pings/Dubai/Frankfurt ; https://olivevps.com/blog/posts/dubai-vps-hosting |
| Cairo → Amsterdam | 66 ms median | SOURCED-SECONDARY | https://wondernetwork.com/pings/Cairo/Frankfurt (page not fetched) |
| Cairo → Frankfurt | not found; ≈ 60–75 ms | ESTIMATE (Amsterdam figure ± a few ms) | — |
| Amman → Frankfurt | not found; ≈ 60–90 ms | ESTIMATE (Jordan transit typically via Europe or the Gulf) | — |
| Frankfurt → Falkenstein / Nuremberg | + 3–8 ms | ESTIMATE (≈ 200–300 km in Germany) | — |
| Frankfurt → Helsinki | + 20–30 ms | ESTIMATE | — |

Implication (ESTIMATE): 80–130 ms RTT is acceptable for WebRTC conversation (< 150 ms one-way target is met); prefer
Falkenstein/Nuremberg over Helsinki. A Gulf node can be considered later after measuring real users (audit,
recommendation 8).

## 5. Contract terms, renewal, taxes

- **Hetzner dedicated:** monthly billing; AX42 launched with hourly billing up to the monthly cap (SOURCED-OFFICIAL,
  press release); setup fee per new server (above); 2026 saw three price changes (1 Apr monthly +3 % to +21 %; setup
  fees changed 2 Feb and 29 Apr; cloud +15 Jun) and changes applied to **existing** products too
  (SOURCED-SECONDARY: https://hostingjournalist.com/news/hetzner-to-significantly-raise-cloud-and-server-prices-in-2026 ,
  https://webhosting.today/2026/05/29/hetzner-has-now-raised-prices-three-times-in-2026-this-one-is-different/ ) —
  **budget a renewal risk of +10–25 %/year** (ESTIMATE). Cancellation notice period: not confirmed in this session.
- **Small EPYC resellers ($199):** "monthly, no contract, no setup" claimed (SOURCED-SECONDARY); check SLA, DDoS
  policy and committed port rate.
- **LiveKit Cloud / Bunny:** monthly, usage-based (SOURCED).
- **Taxes (ESTIMATE — confirm with an accountant):** Hetzner/Bunny/LiveKit list prices excl. VAT. For a business
  customer outside the EU, EU VAT is normally not charged on B2B services (place of supply = customer); Jordan's
  general sales tax on imported services (16 %) may be due by the customer under reverse charge. Hetzner also charges
  for IPv4 addresses separately (amount not confirmed this session).

## 6. Not found / to confirm before any order

1. Current AX42 price for **new orders** (€57.30 vs €97.30 vs €187.30 rows) and AX41 availability for new orders.
2. Hetzner's written fair-use stance for the unmetered 1 Gbit port at sustained ~700 Mbps.
3. Current Hetzner Cloud CCX prices after 15 Jun 2026 and their included traffic.
4. LiveKit Cloud bandwidth price on the live page, and Enterprise volume pricing.
5. Bunny Volume network PoP list (any Middle-East PoP?).
6. RTT from Amman and Cairo to Falkenstein/Nuremberg (a looking-glass test from the owner's users).
7. Committed (not shared) bandwidth on the $199 EPYC offers.
