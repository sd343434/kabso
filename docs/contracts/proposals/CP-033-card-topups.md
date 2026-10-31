# CP-033 — Card top-ups on the Kabso website «الشحن بالبطاقة»

**Status: OWNER-APPROVED BRIEF (2026-10-31, via the coordinator) — built in D190 (contract v1.59-social, CONVENTIONS
§10.53, DEPLOYMENT §5.29).** Off until the owner sets the Stripe secrets on the server. Builds on D187's recharge-badge
hook (`recordRechargeIn(…, WEBSITE_TOPUP)`) and D179's gift reversal (`economy-admin reverse-gift`).

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Where | Card top-ups **only on the Kabso website**, never inside the app. The app may show «الشحن من الموقع» only behind a config flag, **off by default** (`TOPUP_APP_LINK_ENABLED`). |
| Seller | Kigofi LLC, 30 N Gould St #7354, Sheridan, WY 82801, USA. Statement descriptor «KABSO LIVE». |
| Payment | Stripe Checkout (hosted), 3-D Secure always requested (`request_three_d_secure=any`), Radar default rules, receipt email. Chargeback Protection may be enabled by the owner; nothing depends on it. |
| Bank transfers | Stripe `customer_balance` / bank transfer where available — behind `STRIPE_BANK_TRANSFER_ENABLED` (off). |
| Limits | **No per-purchase limit, no hold period** on host cherries. |
| Price | Retail 1 000 000 coins = **$12.50**; packages 100k, 500k, 1M, 5M, 10M, 50M (configurable); the server's price; USD. |
| Terms | «العملات رقمية وغير قابلة للاسترداد» accepted (time, IP, UA) **before** the session is created. |
| Credit | Only from the signed webhook — `checkout.session.completed` with `payment_status=paid` or the bank transfer's async success — exactly once; the D187 hook counts it. |
| Refund / fraud / dispute | `charge.refunded`, `radar.early_fraud_warning.created`, `charge.dispute.created` / `closed`: the purchased coins are taken back (the balance may go **negative**); the buyer is frozen from card purchases and from gifting while negative; host cherries are **not** clawed back automatically — an admin case lists the FIFO-attributed gifts for the team (D179 reversal). Early-fraud warning → automatic refund, then the same reversal. Dispute won → coins restored, freeze lifted. Idempotent per Stripe event id; audited. |
| Evidence | On `charge.dispute.created`, evidence submitted automatically: access activity log (gifts, sign-ins, IP, device for those coins), customer email, ToS acceptance, receipt, `uncategorized_text`. No other users' personal data. |

## 2. Rules built where the brief left room (CTO defaults)

| | Rule built | Where to change it |
|-|------------|--------------------|
| a | The website is three small server-rendered pages served by the API (`/topup`, `/topup/success`, `/topup/cancel`) on `api.<domain>`; the main site redirects `/topup…` there. Sign-in with the existing `POST /auth/login`; the token stays in the tab's `sessionStorage`. | `topup-web.ts`, `infra/deploy/Caddyfile` |
| b | Partial refunds take back their share rounded up; an open or lost dispute holds its share; a won dispute / `warning_closed` / `prevented` gives it back. | `targetReversal` (`topup-rules.ts`) |
| c | FIFO: the coins held before the purchase are spent first, then the purchase's; reversals are not spending; a debt before the purchase is paid by it first. | `fifoAttribution` |
| d | The freeze is lifted automatically only by a won dispute that leaves none of the buyer's purchases reversed or fraud-warned; a refund's freeze stays until the team runs `payments-admin unfreeze`. | `liftFreezeIfClearIn` (`topup-core.ts`) |
| e | Gifting is blocked (403 `TOPUP_ACCOUNT_FROZEN`) while the coin balance is below 0 — live and conversation gifts with coins **or** from the bag, and bag transfers. With a balance ≥ 0 a frozen buyer may still gift coins they hold (only card purchases stay frozen). | `inCoinDebtIn` (`wallet-ledger.ts`) |
| f | The evidence is submitted at once (`STRIPE_DISPUTE_AUTO_SUBMIT=true`); `false` stages it for review in the dashboard. | env |
| g | Checkouts: 20 / hour per user; a session expires after 30 minutes. | `RATE_LIMIT_TOPUP_CHECKOUT_USER`, `topup.service.ts` |

## 3. Questions for the owner

1. Rule e: should a frozen buyer whose balance is back at or above 0 (e.g. after buying from an agent) be able to
   gift again (built), or stay blocked until the team unfreezes?
2. Rule d: should a refund the **team** made (`payments-admin refund`, e.g. a goodwill refund) also freeze the buyer
   (built: every refund freezes)?
3. Bank transfers: which region's transfer type (`us_bank_transfer` built) — and should they be offered at all at
   launch?
4. Should the website link in the app ever be switched on (store policy), and for which stores / countries?
