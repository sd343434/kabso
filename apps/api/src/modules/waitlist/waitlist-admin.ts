import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * The waitlist's reads for the team (v1.61-social, D192, §10.55), shared by `waitlist-admin list|export` and the
 * admin panel (v1.65-social, D197, CONVENTIONS §10.60.6). The e-mails are personal data: every read writes an
 * audit row `waitlist.view` {op, count} (never the addresses).
 */
export async function auditWaitlistViewIn(
  db: Pick<Prisma.TransactionClient, 'auditLog'>,
  op: 'list' | 'export',
  count: number,
  by: AdminVia = CLI_VIA,
): Promise<void> {
  await db.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.WAITLIST_VIEW,
      targetType: 'waitlist',
      metadata: { op, count, via: by.via },
    },
  });
}

/** The number of sign-ups per language. */
export async function waitlistCounts(
  db: Pick<Prisma.TransactionClient, 'waitlistSignup'>,
): Promise<{ total: number; byLocale: { locale: string; count: number }[] }> {
  const counts = await db.waitlistSignup.groupBy({ by: ['locale'], _count: { _all: true } });
  const byLocale = counts
    .map((c) => ({ locale: c.locale, count: c._count._all }))
    .sort((a, b) => a.locale.localeCompare(b.locale));
  return { total: byLocale.reduce((n, c) => n + c.count, 0), byLocale };
}
