import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.122-social (D364, CONVENTIONS §10.157): the WhatsApp departments «الأقسام» — a fixed set. A staff member at REPLY
 * or above belongs to one or more (`wa_staff_departments`; no row: GENERAL); a conversation is in exactly one (GENERAL
 * until a transfer moves it). Plain functions over a Prisma client so the transfer, the agents list and the team page
 * share one rule.
 */
export const WA_DEPARTMENTS = ['PAYMENTS', 'AGENCIES', 'TECHNICAL', 'REPORTS', 'GENERAL'] as const;
export type WaDepartment = (typeof WA_DEPARTMENTS)[number];

/** The department of a person with no membership set (and of a conversation never transferred). */
export const DEFAULT_DEPARTMENT: WaDepartment = 'GENERAL';

export function isWaDepartment(v: unknown): v is WaDepartment {
  return typeof v === 'string' && (WA_DEPARTMENTS as readonly string[]).includes(v);
}

/** The catalogue order, without duplicates. */
export function sortDepartments(list: readonly WaDepartment[]): WaDepartment[] {
  const set = new Set(list);
  return WA_DEPARTMENTS.filter((d) => set.has(d));
}

type Db = Pick<Prisma.TransactionClient, 'waStaffDepartment'>;

/** The departments SET for each person (absent: none set). */
export async function setDepartmentsOf(
  db: Db,
  userIds: readonly string[],
): Promise<Map<string, WaDepartment[]>> {
  if (userIds.length === 0) return new Map();
  const rows = await db.waStaffDepartment.findMany({
    where: { userId: { in: [...userIds] } },
    select: { userId: true, department: true },
  });
  const out = new Map<string, WaDepartment[]>();
  for (const r of rows) out.set(r.userId, [...(out.get(r.userId) ?? []), r.department]);
  for (const [k, v] of out) out.set(k, sortDepartments(v));
  return out;
}

/** The departments that apply: the ones set, else GENERAL. */
export function effectiveDepartments(set: readonly WaDepartment[] | undefined): WaDepartment[] {
  return set && set.length > 0 ? sortDepartments(set) : [DEFAULT_DEPARTMENT];
}

/** `AdminTeamWhatsAppDepartments`: the departments that apply and whether they are the default (none set). */
export function teamDepartmentsOf(set: readonly WaDepartment[] | undefined) {
  return { departments: effectiveDepartments(set), isDefault: !set || set.length === 0 };
}

export interface RoutingCandidate {
  readonly userId: string;
  /** Open conversations assigned to them now. */
  readonly open: number;
  /** Their last CLAIM or TRANSFER received (null: never). */
  readonly lastAssignedAt: Date | null;
}

/**
 * «أول متاح في القسم» (§10.157.3): the candidate with the fewest open assigned conversations; a tie goes to the one
 * assigned least recently (never assigned first), then the lowest id (stable). Null when there is none.
 */
export function firstAvailable(candidates: readonly RoutingCandidate[]): RoutingCandidate | null {
  let best: RoutingCandidate | null = null;
  for (const c of candidates) {
    if (!best) {
      best = c;
      continue;
    }
    if (c.open !== best.open) {
      if (c.open < best.open) best = c;
      continue;
    }
    const a = c.lastAssignedAt?.getTime() ?? -Infinity;
    const b = best.lastAssignedAt?.getTime() ?? -Infinity;
    if (a !== b) {
      if (a < b) best = c;
      continue;
    }
    if (c.userId < best.userId) best = c;
  }
  return best;
}
