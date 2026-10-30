# CP-027 — The Kabso economy, phase 1: cherries, host agencies, commissions and withdrawals

**Status: OWNER DECISIONS (2026-10-30, chat, Arabic) — phase 1 built in D179 (contract v1.52-social,
CONVENTIONS §10.43).** Phase 2 (recharge agents, the agent's cherry → coin conversion, coin selling and
website payments) is recorded in §6 and is **not built**. The owner's wording is kept in the coordinator's
spec (scratch, not in git); this file records the decisions, the defaults we chose where the owner was silent,
and the open questions.

## 1. Currencies

| Unit | Rule (owner) | Where |
|------|--------------|-------|
| Coin (gold) | Bought by viewers (B5: no payment method yet; admins grant). Retail on our website 1 000 000 coins = $12.50. | `wallets`, `wallet_ledger` (§10.19) |
| Cherry (host currency, D134) | **1 coin = 10 cherries.** Credited to the gift recipient per gift: coins × the recipient share × 10, rounded down. | `cherry_wallets`, `cherry_ledger` (§10.43) |
| In-room cherry score | 100 points per counted coin (§10.10): a popularity score, **not money**. | `live_rooms.score`, boards |

Recipient shares (stored per send in `live_gifts.host_share_bps`, unchanged): normal gifts 65 %, lucky 10 %,
quips 50 %, gifts in a direct conversation 50 % (lucky there 10 %).

## 2. Host agencies «وكالة المضيفين»

- An agency earns a commission on its hosts' cherries, **paid by the company on top of the host's share**,
  **credited instantly per gift**: 15 %; 16 % for the month after a calendar month in which its hosts earned
  ≥ 1 500 000 000 cherries. A parent agency (agency admin) earns 3 % of each sub-agency's hosts' cherries, on top.
- A host joins with the agent's invite code and accepts; may leave within 14 days of activation; after that a
  complaint to the admin.
- Ranks: **host agent** with ≥ 5 active hosts (active = ≥ 7 live days and ≥ 10 live hours in the last 30 days),
  or — exception — its hosts earned ≥ 200 000 000 cherries in the month; **agency admin** with ≥ 3 agencies each
  with ≥ 5 active hosts. Re-evaluated at each month start; a rank is kept until the month's end; when no longer
  qualified, no commission on hosts who join after that, existing hosts stay linked.
- Minimum withdrawal for agents $10, like hosts.

Cost example per 1 000 000 coins gifted (retail $12.50): host 6.5M cherries = $7.15; agency 0.975M = $1.07;
parent 0.195M = $0.21 → payouts $8.43 (67 %), the company keeps ≈ $4.07.

## 3. Withdrawals

1 000 000 cherries = **$1.10** (the owner's latest value; an earlier "100M = $75" is superseded — **confirm**).
Minimum $10 (≈ 9.09M cherries). No payment provider yet: requests are held and paid by hand.

## 4. Choices made for phase 1 (CTO defaults, changeable)

1. **History:** the gifts received before v1.52 are **backfilled once** into the cherry ledger by the migration
   (same arithmetic, at the send's time), so one source shows a continuous history; D164's coin-valued earnings
   reads stay, deprecated.
2. **Agencies are created by the team** (`economy-admin agency-create`), not self-service: an agency earns money,
   so the team decides who is an agent (the recharge-agent KYC of phase 2 can be reused later).
3. **Grace for a new agency:** rank `NEW` (earns commission) until the month start two months after its
   creation month; then the monthly rules apply.
4. **Promotion at any time, demotion only at a month start** (the owner's "kept until the end of the month").
5. **200M exception:** the current or the last calendar month (at a month start that is the month just ended).
6. **Agency admin:** each of the 3 sub-agencies qualifies **by the same test as an agent** (5 active hosts or the
   200M exception), and the admin must itself qualify as an agent.
7. **Lapsed agencies:** a host who joined while the agency was lapsed earns it no commission until it qualifies
   again; hosts from before keep earning it.
8. **Reversal** (admin): mirrors the host's cherries and both commissions; balances may go negative (a debt that
   blocks withdrawals). Coins are not refunded (no coin refund exists).
9. **One pending withdrawal at a time;** the request holds ceil(amount × rate) cherries; the team pays within
   7 days (config) and records a note; rejection refunds.
10. **Bag gifts** credit cherries like coin gifts (as the D164 earnings did).

## 5. Open questions for the owner

1. Confirm 1 000 000 cherries = $1.10 (and that "100M = $75" is dropped).
2. Agency admin: is each sub-agency's test "5 active hosts" only, or also the 200M exception (our default: both)?
3. Should gifts sent **from the bag** (free items) credit withdrawable cherries? (Default: yes, like D164.)
4. New agencies' grace (default: until the second month start) — or no commission until the first evaluation?
5. Who may become an agent: the team only (default), or self-service with a review?
6. Payout time shown to requesters (default 7 days) and the accepted payout methods per country.
7. Does a lapsed agency regain commission on hosts who joined while it was lapsed once it qualifies again
   (default: yes)?

## 6. Phase 2 (recorded, not built)

- **Recharge agents «وكيل الشحن»:** fixed username `coin` + activation number from `0001` (never changeable);
  an application with the full four-part name, a WhatsApp number, a photo, face confirmation (proposal: a selfie
  reviewed by the admin first, a liveness provider later), selling locations and payment methods per country;
  admin approval; employees with working hours and per-employee sales; the contact number / payment method
  available at a given time. Application data private (admin only) with retention rules.
- **Buy prices for agents:** 10M coins = $120 ($12/M); 100M–299.99M: $11.95/M; 300M+: $11.90/M.
- **Agent buys host cherries:** the host sells cherries to a recharge agent for cash outside the app ($1.10 / 1M);
  the app converts 1 000 000 cherries → 93 220 coins to the agent (the company keeps 6 780 coins per 1M);
  two-sided confirmation, a per-agent daily cap, audited.
- **Coin selling prices and website payments** (B5), app-store purchase policy, automatic payouts, an admin UI.
- Level points stay 10 coins = 1 point; 1 coin = 5 game cards (no game yet).
