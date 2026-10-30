import type { Prisma } from '../../generated/prisma/client.js';
import { lockUser } from '../premium-usernames/premium-username-ops.js';
import {
  activeSpecialOf,
  endSpecialIn,
  grantSpecialIn,
  reserveSpecialIn,
  SYSTEM_CODE_SOURCES,
} from './special-usernames.js';

/**
 * Which agent code is a person's username (v1.58-social, D189, CONVENTIONS §10.52; extends D185 §10.48.1). A person
 * can be a recharge agent (`coinNNNN`) and a host agent (`hostNN`) at once, but only one special username can be
 * active: every agent change (activation, suspension, reinstatement, an account suspension) calls
 * {@link syncAgentUsernameIn}, which shows the code {@link pickAgentUsername} chooses and keeps the other one
 * reserved for the person (shown in the agent dashboard). Shared by the API, the CLIs and the tests.
 */

type Tx = Prisma.TransactionClient;

export type AgentCodeSource = (typeof SYSTEM_CODE_SOURCES)[number];

export interface AgentCodeCandidate {
  source: AgentCodeSource;
  code: string;
  /** When this role was activated (the recharge agent's activation, the host code's allocation). */
  activatedAt: Date;
}

/**
 * The rule when both codes are live (owner proposal D189 c, pending confirmation): the one activated **first**
 * stays the username. The single place to change it (e.g. to "recharge agent first").
 */
export const AGENT_USERNAME_RULE: 'FIRST_ACTIVATED' | 'RECHARGE_FIRST' | 'HOST_FIRST' = 'FIRST_ACTIVATED';

/** The code to show of the live ones (null: none). Ties go to the recharge agent (D185 came first). */
export function pickAgentUsername(
  candidates: readonly AgentCodeCandidate[],
  rule: typeof AGENT_USERNAME_RULE = AGENT_USERNAME_RULE,
): AgentCodeCandidate | null {
  if (candidates.length === 0) return null;
  const order = (c: AgentCodeCandidate) => (c.source === 'RECHARGE_AGENT' ? 0 : 1);
  const sorted = [...candidates].sort((a, b) => {
    if (rule === 'RECHARGE_FIRST' || rule === 'HOST_FIRST') {
      const first = rule === 'RECHARGE_FIRST' ? 'RECHARGE_AGENT' : 'HOST_AGENT';
      if (a.source !== b.source) return a.source === first ? -1 : 1;
    }
    const t = a.activatedAt.getTime() - b.activatedAt.getTime();
    return t !== 0 ? t : order(a) - order(b);
  });
  return sorted[0]!;
}

/**
 * The person's live agent codes: an ACTIVE recharge agent with a code, and an agency owner with a host code whose
 * host agent is not suspended — both only while the account is ACTIVE (a suspended account loses them all).
 */
export async function agentCodeCandidatesIn(tx: Tx, userId: string): Promise<AgentCodeCandidate[]> {
  const user = await tx.user.findUnique({
    where: { id: userId },
    select: {
      status: true,
      rechargeAgent: { select: { status: true, code: true, activatedAt: true } },
      ownedAgency: { select: { hostCode: true, hostCodeAt: true, suspendedAt: true } },
    },
  });
  if (user?.status !== 'ACTIVE') return [];
  const out: AgentCodeCandidate[] = [];
  const r = user.rechargeAgent;
  if (r?.status === 'ACTIVE' && r.code !== null) {
    out.push({ source: 'RECHARGE_AGENT', code: r.code, activatedAt: r.activatedAt ?? new Date(0) });
  }
  const h = user.ownedAgency;
  if (h?.hostCode && h.hostCodeAt && h.suspendedAt === null) {
    out.push({ source: 'HOST_AGENT', code: h.hostCode, activatedAt: h.hostCodeAt });
  }
  return out;
}

export type AgentUsernameChange = 'granted' | 'ended' | 'unchanged';

/**
 * Makes the person's username follow their agent roles, in the caller's transaction: the chosen live code is
 * granted (permanent, locked; it replaces an earlier gift, as D185 did), the other live code is kept reserved,
 * and with no live code an agent code that is shown ends (the base username is shown again; the code stays the
 * person's — never released). Throws `SpecialUsernameError` when the grant is refused (a rented premium username).
 */
export async function syncAgentUsernameIn(
  tx: Tx,
  userId: string,
  now: Date,
  graceDays: number,
  opts: { note?: string | null; strict?: boolean } = {},
): Promise<AgentUsernameChange> {
  const note = opts.note ?? null;
  await lockUser(tx, userId);
  const candidates = await agentCodeCandidatesIn(tx, userId);
  const want = pickAgentUsername(candidates);
  const current = await activeSpecialOf(tx, userId);
  const agentShown = current !== null && (SYSTEM_CODE_SOURCES as readonly string[]).includes(current.source);
  let change: AgentUsernameChange = 'unchanged';
  if (want === null) {
    if (agentShown) {
      await endSpecialIn(tx, userId, 'SUSPENDED', now, graceDays, { via: 'system', note });
      change = 'ended';
    }
  } else if (current?.username !== want.code) {
    // Not strict (the sweeper's backfill): a refusal (a rented premium username) keeps the code reserved instead.
    if (
      opts.strict === false &&
      (await tx.premiumUsernameLease.count({ where: { userId, status: 'ACTIVE' } }))
    ) {
      await reserveSpecialIn(tx, userId, want.code, want.source, now);
      return 'unchanged';
    }
    await grantSpecialIn(
      tx,
      userId,
      want.code,
      {
        source: want.source,
        expiresAt: null,
        reason: want.source === 'HOST_AGENT' ? 'host agent activated' : 'recharge agent activated',
        via: 'system',
      },
      now,
      graceDays,
    );
    change = 'granted';
  }
  for (const other of candidates) {
    if (other.code !== want?.code) await reserveSpecialIn(tx, userId, other.code, other.source, now);
  }
  return change;
}
