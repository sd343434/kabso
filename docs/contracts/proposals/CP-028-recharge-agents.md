# CP-028 — The Kabso economy, phase 2: recharge agents «وكلاء الشحن»

**Status: OWNER DECISIONS (2026-10-30, chat, Arabic, relayed by the coordinator) — built in D185 (contract
v1.54-social, CONVENTIONS §10.48).** Follows CP-027 §6. The owner's wording stays in the coordinator's spec
(scratch, not in git); this file records the decisions, the defaults we chose where the owner was silent, and
the questions for the owner.

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Application «كن وكيل شحن» | Full four-part name, a phone number with WhatsApp, a photo of the agent, face confirmation, selling locations, payment methods per country. Admin approves. |
| Face confirmation | A selfie reviewed by a person first; no third-party liveness provider now. |
| Privacy | Application data private: admins only, through a CLI, every read audited, a retention rule. |
| Activation | Only by a **first top-up of at least 30 000 000 coins** (= $360 at $12 / M). |
| Buy price for agents | $12 / 1M coins; 100M–299.99M: $11.95 / M; 300M+: $11.90 / M. Paid outside the app, recorded by the admin. |
| Code | `coin` + activation number from `0001` (`coin0001`, `coin0002` …), never changeable. |
| Selling | The agent (or an employee during working hours) sells coins from the stock to any user; the buyer pays outside the app. |
| Employees | Added by the agent with working hours; sales statistics per employee. |
| Availability | The contact number (WhatsApp) and payment method available at a given time, shown to buyers. |
| Host cherries | A host sells withdrawable cherries to an agent for cash at $1.10 / 1M; 1 000 000 cherries → 93 220 coins to the agent's stock; two-sided confirmation; per-agent daily cap; audited. Locked task cherries (D184) can never be sold. |
| Perks | Avatar frame with the name plate, an entrance bar in every live room, a badge — the owner's Kabi art; no expiry; all lost at once on suspension or ban, with selling and the listing. |

## 2. Choices made (CTO defaults, changeable)

1. **Code vs username — decided by the owner (same day), replacing our default:** the code **becomes the agent's
   `@username`** through a general **special-username layer «يوزر مميز»** (CONVENTIONS §10.48.1): locked while
   active, shown to everyone else as the only username; the person's own (base) username is kept, visible only to
   them and to the team, still signs in, and old links and mentions still lead to them. Suspension gives the base
   back; the code stays theirs forever (never reused). Gifts by the team (`username-admin`) use the same layer,
   with an optional end and a 30-day grace period. `PURCHASE` is reserved (no store yet).
2. **Frame plate text — decided by the owner:** the agent's **display name** (fitted, ellipsized). The entrance bar
   keeps «دخل وكيل الشحن coin0001».
3. **Perks are derived from the status** (`ACTIVE` and an active account), not bag items: nothing to send, wear
   off, expire or revoke one by one; a suspension removes everything in the same transaction that changes the
   status. The bag (D171/D180) is not used because a bag item can be taken off and, when bought, sent.
4. **Entrance:** the agent's emblem keeps the owner's mascot (drawn in the art), timing = the CP entrance (3.2 s,
   2.2 s without motion); an agent's join bypasses the one-join-line-a-second limit (D96) so the bar always plays.
5. **Badge size:** like the level badges on the person card (18 lp high) and beside the name on the profile
   (22 lp) — the art is detailed; it is readable as an emblem, not as text.
6. **Cherry sale:** minimum 1 000 000 cherries, steps of 100 000 (9 322 coins per step, no rounding loss);
   request TTL 30 minutes; default daily cap 1 000 000 000 cherries per agent (≈ $1 100 to hosts, ≈ 93.2M coins),
   per-agent override by CLI. Either side may create; the other confirms after the cash changed hands.
7. **Top-up price check:** the CLI computes the tier price; a different USD amount needs `--note` (discounts,
   fees) and both are stored.
8. **Retention:** a rejected application's pictures and personal fields are deleted 90 days after the decision;
   a deleted account's at the next sweep; an approved agent's kept while the agent exists.
9. **Employees:** at most 20; an employee works for one agent; the agent cannot be an employee; a sale to the
   seller or to the agent themselves is refused (stock → own wallet).
10. **Directory:** ACTIVE agents with an active account in the country; the WhatsApp/payment method of the slot
    containing «now»; payment-method **types** only (the details from the application stay private); the
    «تواصل» button opens WhatsApp after D175's leaving sheet. No stock shown.
11. **Day boundary** for statistics and the cap: `LIVE_RANKINGS_TIME_ZONE` (like the economy's months).

## 3. Not built (honest)

- The buyer's in-app order flow of D150 (choose an agent → amount → screenshot → escrow → dispute): the owner's
  latest decision is a direct sale by the agent; payment proof and disputes stay outside the app.
- Automatic liveness, a payment gateway, an admin UI, agent-to-agent transfers, stock refunds.
- Store builds: selling digital currency for outside payment may conflict with app-store rules (D150's warning);
  the directory and «كن وكيل شحن» should stay off in store builds until legal review (**owner decision needed**).

## 4. Questions for the owner

1. ~~Username~~ — decided: the code becomes the username (§10.48.1). Open details: (a) during the 30-day grace a
   special username no longer signs in (only the shown and base names do) — OK? (b) a person who rents a premium
   username cannot be activated as an agent until it ends (nothing is charged) — OK, or should activation end the
   rental? (c) an old link or mention by the base username still opens the person's profile, so someone who
   already knows the base name learns the special one — acceptable? (d) `coin` names are never released, even
   after an agent leaves for good — OK?
2. ~~Plate text~~ — decided: the display name.
3. Daily cherry cap per agent (default 1 000 000 000 cherries / day), minimum 1M and step 100k — OK?
4. Request expiry 30 minutes — OK?
5. Should the directory show the agent's stock or «available now» only (default)?
6. Store builds (Play / App Store): hide the agent directory and application until legal review?
7. Retention: 90 days for rejected applications — OK? Keep an ex-agent's data how long after they stop?
