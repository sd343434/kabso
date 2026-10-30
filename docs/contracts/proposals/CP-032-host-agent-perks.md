# CP-032 — Host-agent perks «وكيل مضيفين»

**Status: OWNER REQUEST (2026-10-30, via the coordinator) with four default rules PENDING OWNER CONFIRMATION —
built in D189 (contract v1.58-social, CONVENTIONS §10.52).** Extends D179 (host agencies, CP-027) with D185's perks
and special-username layer (CP-028, §10.48.1). The owner's wording stays in the coordinator's spec (scratch).

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Who | A host agent «وكيل مضيفين» (the owner of a host agency) gets the same kind of perks as a recharge agent. |
| Special username | `host` + a sequential number, at least two digits: `host01` … `host99`, `host100`, `host123`; allocated atomically, never reused, reserved for the person like `coinNNNN`, not changeable by the agent; through the D185 layer with a new source `HOST_AGENT`. |
| Reserved pattern | `host` + digits is the system's; existing accounts that already have one keep it; activation skips taken numbers. |
| Art | Owner-supplied, AI-generated Kabso art (may enter git): badge, blue entrance bar, avatar frame without a name plate (`apps/mobile/assets/host_agent/PROVENANCE.md`). |
| Badge | Profile and person card, and inline next to the name in live rooms — placed exactly as the recharge-agent badge. |
| Entrance | Same size and behaviour as D185's resized bar (65 % width, ≤ 64 lp, leading side, above the chat); «دخل وكيل المضيفين {username}» / "Host agent {username} joined". |
| Frame | Profile and avatar; no name written; the photo circle measured from the alpha channel. |

## 2. Default rules (proposals, built so each can change)

| | Rule built | Where to change it |
|-|------------|--------------------|
| a | **Activation = the agency's creation** (`economy-admin agency-create`), same transaction. New `economy-admin agency-suspend` / `agency-reinstate`. Older agencies get their code from the agency sweeper. | `createAgencyIn` / `allocateHostCodeIn` (`economy/host-agents.ts`) |
| b | **Perks last while the agency exists and is not suspended — any rank, LAPSED too.** The team's suspension (or an account suspension) removes them all at once: base username back, frame, badge and entrance gone; the code stays reserved. Suspension touches only the perks (hosts, commissions, rank unchanged). | `hostAgentPerksActive` (API), the `suspended_at IS NULL` subquery of the room host summary |
| c | **Both roles:** both badges. One special username: the code **activated first** stays; the other is allocated, held for the person and shown in the agency dashboard. When the shown role is suspended the other live code becomes the username. | `AGENT_USERNAME_RULE` / `pickAgentUsername` (`users/agent-usernames.ts`) |
| d | **Frame precedence** on the profile and the person card: recharge-agent frame > host-agent frame > a bag / CP frame (the live ring still wins while live). The recharge agent's entrance bar wins for a person who is both. | `agentFrameKindFor` (app, `recharge_perks.dart`); the entrance layer |

## 3. Notes

- D185's own paths (recharge activation, suspension, reinstatement) now go through the same agent-username rule, so
  a recharge agent who is already a host agent keeps `hostNN` if it was activated first (D185 alone behaved as
  before).
- D186's worn bag frame (another branch) is not on this branch's profile yet; on merge it goes below both agent
  frames (rule d).
- The host-agent art is square (badge 240 px, frame 512 px) and the bar 1050 × 389 px; photo circle cx 0.4995,
  cy 0.4815, r 0.2645.

## 4. Questions for the owner

1. Rule a: is "activation" the agency's creation, or should it wait for a rank (e.g. AGENT)?
2. Rule b: should LAPSED (or a NEW agency that never qualified) keep the perks? Should an agency suspension also stop
   commissions and joining (today it only removes the perks)?
3. Rule c: with both roles, which username should show — the first activated (built), always the recharge code, or
   always the host code? Should the person be able to choose?
4. Rule d: frame precedence — recharge > host > bag frame (built)? And for a person who is both, which entrance bar?
5. Should older agencies (created before this change) get codes automatically (built, oldest first) or only when the
   team re-activates them?
