import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { nameInUse } from '../premium-usernames/premium-username-ops.js';
import { syncAgentUsernameIn } from '../users/agent-usernames.js';
import { reserveSpecialIn, SpecialUsernameError } from '../users/special-usernames.js';

/**
 * Host agents «وكيل مضيفين» (v1.58-social, D189, CONVENTIONS §10.52, CP-032): an agency's owner gets perks like a
 * recharge agent (D185) — the code `hostNN` as their special username, a frame, a badge and an entrance. The
 * perks are derived from the agency (no bag items): they last while the agency exists and its host agent is not
 * suspended, whatever the rank (LAPSED keeps them), and the team's suspension removes them all at once. Shared by
 * the API (the sweeper's backfill), the `economy-admin` CLI and the tests (no Nest dependencies).
 */

type Tx = Prisma.TransactionClient;

/** A refused admin action (the CLI prints the message and exits 1; nothing changed). */
export class HostAgentError extends Error {}

/** `host01`: `host` and the activation number, at least two digits (owner). */
export function hostAgentCode(number: number): string {
  if (!Number.isInteger(number) || number < 1) throw new RangeError('A code number is a positive integer');
  return `host${String(number).padStart(2, '0')}`;
}

/**
 * Whether an agency's owner has the host-agent perks now (owner proposal D189 b, pending confirmation): the
 * agency exists and the team has not suspended it — the rank does not matter. The account must also be ACTIVE
 * (checked where the perks are read).
 */
export function hostAgentPerksActive(agency: { hostCode: string | null; suspendedAt: Date | null }): boolean {
  return agency.hostCode !== null && agency.suspendedAt === null;
}

/** A refused special-username step as the CLI's error (the whole transaction rolls back). */
async function specialIn<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof SpecialUsernameError) throw new HostAgentError(`Username: ${err.message}`);
    throw err;
  }
}

/**
 * Gives the agency's owner the next host code from the counter row (updated in this transaction: in order,
 * never twice; concurrent activations queue on the row). A number whose name an older account already uses
 * (names made before `host` + digits was reserved) or that is otherwise held is skipped — the only gap the
 * counter can have. Then the code becomes the username through the agent-username rule (D189 c). Nothing when
 * the agency already has a code. Returns the code.
 */
export async function allocateHostCodeIn(
  tx: Tx,
  agencyId: string,
  now: Date,
  specialGraceDays: number,
  opts: { strict?: boolean } = {},
): Promise<string> {
  const [agency] = await tx.$queryRaw<{ owner: string; code: string | null }[]>`
    SELECT owner_user_id::text AS owner, host_code AS code FROM agencies WHERE id = ${agencyId}::uuid FOR UPDATE`;
  if (!agency) throw new HostAgentError('No such agency.');
  if (agency.code !== null) return agency.code;
  let n: number;
  for (let tries = 0; ; tries++) {
    const [counter] = await tx.$queryRaw<{ n: number }[]>`
      INSERT INTO host_agent_counter (id, last_number) VALUES (1, 1)
      ON CONFLICT (id) DO UPDATE SET last_number = host_agent_counter.last_number + 1
      RETURNING last_number AS n`;
    if (!counter) throw new Error('host_agent_counter row missing');
    n = counter.n;
    if (!(await nameInUse(tx, hostAgentCode(n), agency.owner, now))) break;
    if (tries >= 200) throw new HostAgentError('No free host code found.');
  }
  const code = hostAgentCode(n);
  await tx.agency.update({
    where: { id: agencyId },
    data: { hostCode: code, hostCodeNumber: n, hostCodeAt: now },
  });
  // Held for the person from now on (also while suspended or while another code is shown), then shown per the
  // agent-username rule.
  await specialIn(() => reserveSpecialIn(tx, agency.owner, code, 'HOST_AGENT', now));
  await specialIn(() =>
    syncAgentUsernameIn(tx, agency.owner, now, specialGraceDays, { strict: opts.strict }),
  );
  await tx.auditLog.create({
    data: {
      action: AuditAction.HOST_AGENT_ACTIVATE,
      targetType: 'agency',
      targetId: agencyId,
      metadata: { owner: agency.owner, code, via: opts.strict === false ? 'sweeper' : 'cli' },
    },
  });
  return code;
}

/**
 * `economy-admin agency-create`: the agency and, in the same transaction, its owner's activation as a host
 * agent (D189 a: activation = the agency's creation). The caller checked the owner and the parent.
 */
export async function createAgencyIn(
  tx: Tx,
  input: { ownerUserId: string; inviteCode: string; parentAgencyId: string | null; evaluateFrom: Date },
  now: Date,
  specialGraceDays: number,
): Promise<{ agencyId: string; hostCode: string }> {
  const agencyId = uuidv7();
  await tx.agency.create({
    data: {
      id: agencyId,
      ownerUserId: input.ownerUserId,
      inviteCode: input.inviteCode,
      parentAgencyId: input.parentAgencyId,
      evaluateFrom: input.evaluateFrom,
      createdAt: now,
    },
  });
  const hostCode = await allocateHostCodeIn(tx, agencyId, now, specialGraceDays);
  return { agencyId, hostCode };
}

/**
 * `economy-admin agency-suspend`: the host agent loses every perk at once — the username goes back to the base
 * one (or to their recharge code), the frame, badge and entrance go (they are derived). The code stays theirs.
 * Hosts, commissions and the rank are not touched.
 */
export async function suspendHostAgentIn(
  tx: Tx,
  agencyId: string,
  reason: string,
  now: Date,
  specialGraceDays: number,
): Promise<void> {
  const rows = await tx.$queryRaw<{ owner: string }[]>`
    UPDATE agencies SET suspended_at = ${now}, suspend_reason = ${reason}, updated_at = ${now}
     WHERE id = ${agencyId}::uuid AND suspended_at IS NULL RETURNING owner_user_id::text AS owner`;
  const owner = rows[0]?.owner;
  if (!owner) throw new HostAgentError('No such agency, or already suspended.');
  await specialIn(() => syncAgentUsernameIn(tx, owner, now, specialGraceDays, { note: reason }));
  await tx.auditLog.create({
    data: {
      action: AuditAction.HOST_AGENT_SUSPEND,
      targetType: 'agency',
      targetId: agencyId,
      metadata: { owner, reason, via: 'cli' },
    },
  });
}

/** `economy-admin agency-reinstate`: the perks come back (the code is the username again per the rule). */
export async function reinstateHostAgentIn(
  tx: Tx,
  agencyId: string,
  now: Date,
  specialGraceDays: number,
): Promise<void> {
  const rows = await tx.$queryRaw<{ owner: string; code: string | null }[]>`
    UPDATE agencies SET suspended_at = NULL, suspend_reason = NULL, updated_at = ${now}
     WHERE id = ${agencyId}::uuid AND suspended_at IS NOT NULL
     RETURNING owner_user_id::text AS owner, host_code AS code`;
  const row = rows[0];
  if (!row) throw new HostAgentError('No such agency, or not suspended.');
  if (row.code === null) await allocateHostCodeIn(tx, agencyId, now, specialGraceDays);
  else await specialIn(() => syncAgentUsernameIn(tx, row.owner, now, specialGraceDays));
  await tx.auditLog.create({
    data: {
      action: AuditAction.HOST_AGENT_REINSTATE,
      targetType: 'agency',
      targetId: agencyId,
      metadata: { owner: row.owner, via: 'cli' },
    },
  });
}

/**
 * The agency sweeper's step: agencies created before D189 (no code) get theirs, oldest first, one transaction
 * each; a refused username grant (a rented premium username) keeps the code reserved. Returns how many.
 */
export async function assignMissingHostCodes(
  prisma: PrismaClient,
  now: Date,
  specialGraceDays: number,
): Promise<number> {
  const due = await prisma.agency.findMany({
    where: { hostCode: null },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { id: true },
    take: 100,
  });
  let n = 0;
  for (const a of due) {
    await prisma.$transaction((tx) => allocateHostCodeIn(tx, a.id, now, specialGraceDays, { strict: false }));
    n++;
  }
  return n;
}
