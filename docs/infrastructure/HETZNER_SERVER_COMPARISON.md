# Hetzner server comparison — Kabso Live media tier (Phase 0)

Planning only. Nothing was ordered, no account was opened. Companion to
[`PHASE_0_INFRASTRUCTURE_READINESS.md`](./PHASE_0_INFRASTRUCTURE_READINESS.md) and
[`PRODUCTION_COST_MODEL.md`](./PRODUCTION_COST_MODEL.md).

**Labels**

- **VERIFIED**: read on the official page named, accessed **2026-11-09**. The pages were downloaded with `curl` through
  the session proxy and their text was read. The WebFetch tool could not resolve the hosts, but curl could.
- **ESTIMATE**: reasoning, given each time.
- Every price is **excl. VAT**, as Hetzner publishes it.

> This file replaces the Hetzner figures in `COST_MODEL.md` §2.1. Those were search-index readings, and the live pages
> differ a lot: AX42 is **€99**, not €57.30, and AX41 is **€59**, not €42.30.

## 0. Owner decision (2026-11-09, D350)

**Owner decision, 2026-11-09 (after Phase 0; D350):** direction "self-hosted LiveKit on Hetzner dedicated" approved.
AX41 is **not available** to order. Media nodes: **EX44** (Intel i5-13500, 14 cores / 20 threads, 64 GB DDR4,
2 × 512 GB NVMe, 1 Gbit/s guaranteed, unlimited traffic, FSN1) at **$74/month, $0 setup**. App/DB at production:
**EX63** at **$174/month + $84 setup**. Prices as seen **on the owner's Hetzner account on 2026-11-09, in USD, VAT 0 %
on his account** (OWNER; not read by us on hetzner.com). Phase 1: **one EX44** as a single-node test
(`LIVEKIT_SINGLE_NODE_DEPLOYMENT.md`). Production plan: **5 × EX44 media + 1 × EX63 app/DB**.

EX44 and EX63 were not part of the pages read in Phase 0; their figures above are the owner's, not VERIFIED here. The AX
tables below stay as the Phase 0 record.

## 1. Dedicated AX line (1 Gbit port, unlimited traffic)

Sources: https://www.hetzner.com/dedicated-rootserver/matrix-ax/ (matrix) and the product pages
`/dedicated-rootserver/ax41/`, `/ax42/`, `/ax102/`, `/ax162/`. All VERIFIED on 2026-11-09.

| Model | CPU | RAM | Disk | Monthly (product page) | Matrix "starting from" | Hourly | Setup | Locations | Port |
|---|---|---|---|---|---|---|---|---|---|
| **AX41** | AMD Ryzen 5 3600, 6 cores, Zen 2, SMT | 64 GB DDR4 (no ECC listed) | 2 × 512 GB NVMe | **€59.00** | €59.00 | €0.0945 | **€0.00** | FSN1, HEL1 | 1 Gbit/s, "Bandwidth guaranteed 1 GBit/s" |
| **AX42** | AMD Ryzen 7 PRO 8700GE, 8 cores, Zen 4, SMT | 64 GB DDR5 ECC | 2 × 512 GB NVMe | **€99.00** | €79.00 (one of "2 Types") | €0.1586 | **€49.00** | HEL1, FSN1 | 1 Gbit/s, guaranteed |
| AX102 | AMD Ryzen 9 7950X3D, 16 cores, Zen 4, 3D V-Cache | 128 GB DDR5 ECC | 2 × 1.92 TB Gen4 NVMe DC (up to 2 × 7.68 TB) | **€259.00** | €159.00 | €0.4150 | **€129.00** | FSN1, HEL1 | 1 Gbit/s, guaranteed |
| AX162 | AMD EPYC 9454P, 48 cores, Zen 4 | 128 GB DDR5 ECC reg. (up to 512 GB) | 2 × 1.92 TB NVMe DC (up to 2 × 15.36 TB) | **€614.00** | €319.00 | €0.9840 | **€304.00** | FSN1, HEL1 | 1 Gbit/s, guaranteed |
| AX52 | — | — | — | **not offered**: `/dedicated-rootserver/ax52/` redirects to the dedicated overview, and the AX matrix lists only AX41/42/102/162 | | | | | |

Notes:

1. **"Starting from" vs product-page price (unresolved).** The matrix shows a lower "starting from" price for AX42,
   AX102 and AX162, in a hidden `limit-price` element with product key `ROBOT_1720+ROBOT_1266` for AX42. The product
   page, and the hourly rate × ~624 h, both give the higher price. **This model uses the product-page price.** The order
   configurator would show which type or location is cheaper, but it is rendered by JavaScript and could not be read
   here. Question for the owner: check it at order time.
2. **NBG1 is not listed** for any AX model. Every product page shows **FSN1 and HEL1** only.
3. **IPv4:** the AX42 page lists "1 Dedicated IPv4 address — optional", and the matrix lists "Primary IPv4 — optional
   IPv4 address 1". **No price for the primary IPv4 is shown on the pages read.** ESTIMATE: it is either included or
   charged like an additional IP. Confirm in the configurator.
4. **Power (VERIFIED, matrix):** idle 26 / 34 / 61 W and max 83 / 166 / 349 W for AX42 / AX102 / AX162. AX41 has no
   value listed.
5. **Terms (VERIFIED, matrix and AX42 page):** "Minimum contract period: none", "Cancellation period: immediately".
   Payment by bank transfer, credit card, PayPal, or SEPA direct debit (EUR only, for SEPA accounts). An optional
   GDPR Art. 28 DPA is offered.

## 2. Traffic policy (VERIFIED)

| Text | Source |
|---|---|
| "Traffic usage is unlimited and free of charge. Please note that our unlimited traffic policy does not apply to servers that have the 10G uplink addon." | matrix-ax, ax42 |
| "In this special case, we will charge the usage over 20TB with € 1.00, excl. VAT / TB (The basis for calculation is for outgoing traffic only. Incoming and internal traffic is not calculated.) There is no bandwidth limitation." | ax42 page footnote |
| "All root servers have a dedicated 1 GBit uplink by default and with it unlimited traffic. Inclusive monthly traffic for servers with 10Gbit uplink is 20TB. There is no bandwidth limitation. We will charge € 1 ($1.20)/TB for overusage." | https://docs.hetzner.com/robot/general/traffic/ (last change 2024-05-21) |
| Overage is billed "in blocks of 100 MB". Traffic warnings can be set hourly, daily or monthly in Robot. "We calculate monthly traffic only using outgoing traffic." | same |

**Fair use:** no written fair-use clause or cap for the unlimited 1 Gbit traffic was found on the pages read (matrix,
product pages, traffic doc). The Terms and System Policies pages were **not** read. ESTIMATE: sustained 700–800 Mbps
on a guaranteed 1 Gbit port is the use the product is sold for. Still, ask Hetzner support in writing before relying
on 24/7 saturation (see the questions in the readiness document).

## 3. 10G uplink (VERIFIED)

| Item | Figure | Source |
|---|---|---|
| Price | **10 Gbit Uplink €43.00 / $48.00 per month** | https://docs.hetzner.com/robot/dedicated-server/dedicated-server-hardware/price-server-addons/ (last change 2026-10-07; the docs URL `…/pricing/price-list-for-additional-products/` redirects here) |
| Setup on a new order | none listed. Ordered in the configurator when the model supports it. "-LTD" and auction servers need a support ticket. | https://docs.hetzner.com/robot/dedicated-server/network/10g-uplink/ (last change 2026-09-23) |
| Moving an existing server | €32.77 ($37.00). €99.00 ($110.00) when the chassis must be rebuilt. €70.59 for Dell. **The old IP addresses are lost.** | same |
| Included traffic | 20 TB outgoing/month, then **€1.00 ($1.20) per TB**. No bandwidth limitation. Incoming and internal traffic unlimited. | same |
| Restriction | "**The Robot firewall is not available for servers with 10G Uplink.**" Only one uplink per server. | same |

## 4. IP addresses (VERIFIED, matrix-ax and ax42)

| Item | Monthly | Hourly | Setup |
|---|---|---|---|
| Additional single IPv4 (primary IPv4 required) | **€1.70** | €0.0027 | **€4.90** |
| Failover IP | €4.20 | €0.0067 | €4.90 |
| Additional /29 (6 usable) | €13.60 | €0.0218 | €34.90 |
| IPv6 /64 | included | — | — |

Allocation follows RIPE guidelines, and "we require a valid technical reason" (https://docs.hetzner.com/robot/dedicated-server/ip/ip-addresses/).
A TURN/TLS listener on 443 of a separate IP is a normal technical reason (ESTIMATE).

## 5. Other dedicated add-ons (VERIFIED, matrix-ax)

| Item | Price |
|---|---|
| Storage Box 1 TB / 5 TB / 10 TB | €3.20 / €10.90 / €20.80 per month |
| Remote Hands | €21.00 per ¼ h |
| vSwitch (VLAN between dedicated servers, also across locations) | listed as a feature; **no price shown** on the pages read (ESTIMATE: no charge, confirm) |
| Stateless Robot firewall | included (not with 10G uplink) |
| DDoS protection | listed as included |
| Network availability | "min. 99.9 %" |

## 6. Server Auction (VERIFIED, https://www.hetzner.com/sb/)

- "All without setup fees". Traffic "Unlimited", 1 Gbit/s port. The navigation teaser says "from € 47.70 per month".
- Servers are refurbished and each offer is single-unit. A 10G uplink needs a support ticket.
- ESTIMATE: usable for a spare media node or a load generator. It is not ideal for a homogeneous media cluster,
  because the hardware differs between units.

## 7. Hetzner Cloud (for temporary load generators or a staging media node), VERIFIED

Sources: https://www.hetzner.com/cloud/general-purpose/ (CCX, dedicated vCPU) and
https://www.hetzner.com/cloud/regular-performance/ (CPX, shared vCPU). eu-central prices.

| Plan | vCPU | RAM | Disk | Monthly cap | Hourly |
|---|---|---|---|---|---|
| CCX13 | 2 dedicated | 8 GB | 80 GB | €43.49 | €0.0697 |
| CCX23 | 4 dedicated | 16 GB | 160 GB | €86.49 | €0.1386 |
| CCX33 | 8 dedicated | 32 GB | 240 GB | €138.99 | €0.2227 |
| CCX43 | 16 dedicated | 64 GB | 360 GB | €276.49 | €0.4431 |
| CCX53 | 32 dedicated | 128 GB | 600 GB | €533.99 | €0.8558 |
| CPX22 | 2 shared | 4 GB | 80 GB | €19.99 | €0.0320 |
| CPX32 | 4 shared | 8 GB | 160 GB | €35.99 | €0.0577 |
| CPX42 | 8 shared | 16 GB | 320 GB | €69.99 | €0.1122 |
| CPX52 | 12 shared | 24 GB | 480 GB | €100.99 | €0.1618 |
| CPX62 | 16 shared | 32 GB | 640 GB | €130.49 | €0.2091 |

- Traffic: "Cloud servers located in the EU include at least 20 TB of included traffic. For each additional TB at
  EU-Central locations we charge € 1.00 …". The page says "per hour", which reads as a typo for per TB. US: 1 TB
  included. Singapore: 0.5 TB included and €7.40/TB.
- Locations shown: CCX in NBG1 and HEL1, CPX in FSN1, NBG1 and HEL1.
- "Your server's bill will never exceed its monthly price cap". Billing is hourly.
- The pages show "This product is currently unavailable. Please check back later." in the markup of each plan. It
  could not be told whether this is a hidden template or a real stock state. Check at order time.
- **Network throughput per cloud instance is not published** on these pages. A load generator needs about 1 Gbit/s
  per machine, so this is the main reason to prefer hourly **AX41** generators (guaranteed 1 Gbit/s, unlimited traffic,
  €0 setup) over cloud instances (ESTIMATE).
- The prices are far above the 2025 search-index figures used in `COST_MODEL.md` (CCX33 €138.99, not €48.49).

## 8. Fit for Kabso's media nodes (ESTIMATE)

Why it is the port that limits each node, not the CPU:

- LiveKit's published benchmark (VERIFIED, https://docs.livekit.io/transport/self-hosting/benchmark/) ran on a GCP
  c2-standard-16 (16 vCPU, 8 physical cores). "Livestreaming" with 1 publisher and 3,000 subscribers sent
  **531 MBps out (≈ 4.2 Gbit/s)** at 560,962 packets/s and 92 % CPU. "Large meeting" with 150 publishers and 150
  subscribers sent 93 MBps out at 762,749 packets/s and 85 % CPU.
- CPU cost follows packets per second. At 700 Mbit/s egress per node with mostly ~1,100-byte video packets, a node
  sends ≈ 80–110 k packets/s, roughly 1/6 of the benchmark's packet rate. So an 8-core Zen 4 AX42, or even a 6-core
  Zen 2 AX41, should be **network-bound on a 1 Gbit port** (ESTIMATE, to be measured with `lk load-test`).
- On a 10G uplink the CPU becomes the limit. ESTIMATE: about 2–4 Gbit/s for AX42 and about 4–6 Gbit/s for AX102, by
  scaling the benchmark's packet rate. That is not proven for Kabso's many-small-rooms profile.

| Candidate | €/month per Gbit of usable egress (70 % of port) | Pros | Cons |
|---|---|---|---|
| **AX41** (1 Gbit) | €59 / 0.7 ≈ **€84** | cheapest, **no setup fee**, hourly billing makes it usable as a load generator too | Zen 2 (2019), DDR4 without ECC, single type, could leave the range |
| AX42 (1 Gbit) | €99 / 0.7 ≈ €141 | newer Zen 4, ECC, low power | €49 setup, 68 % dearer per Gbit |
| AX42 + 10G | (€99 + €43) / ~2 Gbit/s ≈ €71 + €1/TB over 20 TB | fewer machines | CPU-bound below 10G, no Robot firewall, traffic metered (≈ €95/month at 135 TB for two nodes, more at worst case), a failed node removes a large share of capacity |
| AX102 + 10G | (€259 + €43) / ~4 Gbit/s ≈ €76 + €1/TB | one node could carry the whole target | €129 setup, losing one node loses 100 % of capacity, so N+1 doubles the cost |

**Conclusion (ESTIMATE):** for 2.3–2.4 Gbit/s with N+1, **several 1 Gbit nodes** are cheaper and more resilient
than a few 10G nodes. AX41 is the cheapest per Gbit; AX42 costs more for newer hardware and ECC. The app and database
server should be **AX42** (ECC RAM for PostgreSQL).

## 9. Inputs that need the owner's account or a decision (not guessed)

- Which of the AX42 "2 Types" is the €79 one, and whether the primary IPv4 is charged (configurator).
- Whether FSN1 or HEL1 has stock for 5–6 identical units on the order date.
- VAT treatment: depends on the account's country and VAT ID. Hetzner prices exclude VAT.
- Any new-customer order limits or identity checks on a fresh Hetzner account (not described on the pages read).
- Written confirmation from Hetzner support that sustained ~80 % use of the 1 Gbit port is fine (no fair-use text
  was found).
