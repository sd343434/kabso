# CP-030 — Daily recharge badges «شارات الشحن اليومي»

**Status: OWNER DECISIONS (2026-10-30, chat, Arabic, relayed by the coordinator) — built in D187 (contract
v1.56-social, CONVENTIONS §10.50).** Follows CP-028 (recharge agents). CP-029 and v1.55-social are D186's. The
owner's wording stays in the coordinator's spec (scratch, not in git).

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Art | Five badges (owner-supplied, AI-generated Kabso art): bronze pouch, silver-blue chest, gold-red chest, purple vessel, royal red vault. |
| Tiers | 1M–10M, 10.01M–20M, 20.01M–40M, 40.01M–70M, 70.01M+ coins recharged. |
| Period | **Daily**: the tier comes from the total recharged in one day. |
| Duration | The badge shows for **24 hours**. |
| What counts | Purchases from a recharge agent (D185 sale to the buyer) and website top-ups when they exist. **Not** gifts, rewards, admin credits. |
| Who | Not for recharge agents. |
| Where | Next to the name in lives, on the profile and the person card, like the level badge. |

## 2. Choices made (coordinator / CTO defaults, changeable)

1. **The day** is the calendar day in `RECHARGE_BADGE_TIME_ZONE`, default `Asia/Riyadh` (UTC+3).
2. **The 24 hours** run from the moment the tier was reached; a higher tier the same day replaces the badge and
   restarts them.
3. **Earlier-day badge still showing:** a higher one from yesterday stays until it ends even if a lower tier is
   reached today (today's lower tier is then not shown separately); an equal or higher tier replaces it.
   *(Owner question 1.)*
4. **Recharge agents** never get it, as buyers or sellers, whatever their agent status (approved, active,
   suspended). Employees of an agent are not agents: their own purchases from another agent count.
   *(Owner question 2.)*
5. **Tiers, zone and hours are settings** (`RECHARGE_BADGE_TIERS`, `RECHARGE_BADGE_TIME_ZONE`,
   `RECHARGE_BADGE_HOURS`), not code.
6. **Website top-ups:** only the hook (`recordRechargeIn` with source `WEBSITE_TOPUP`); no website flow is built.
7. **Me hub card:** the badge also shows beside the name on the Me hub card (where the level badge shows).

## 3. Owner questions

1. A lower tier reached today while yesterday's higher badge still shows: keep the higher one (now), or switch
   to today's?
2. Should an agent's employees be excluded like agents?
3. Should reaching a tier send a notification or show an animation? (Nothing now.)
