import { Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveStaffAlertsService } from '../live/live-staff-alerts.service.js';

/** The panel roles the shared queue reaches (D288; OWNER only as the fallback, like D273). */
export const SHARED_REPORT_ROLES = ['MODERATION', 'SUPPORT'] as const;

/** One unread STAFF_REPORT_NEW row per staff member (it moves to the newest report). */
export const STAFF_REPORT_NEW_GROUP = 'STAFF_REPORT_NEW';

/**
 * v1.93-social (D296, §10.109): the reports in `reportIds` are closed — their `STAFF_REPORT_NEW` rows are read for every
 * staff member, exactly as after a manual «تم حله» (D288). Inside the caller's transaction; returns the rows marked.
 */
export async function markReportAlertsReadIn(
  tx: Prisma.TransactionClient,
  reportIds: readonly string[],
  at: Date = new Date(),
): Promise<number> {
  if (reportIds.length === 0) return 0;
  const done = await tx.notification.updateMany({
    where: { type: 'STAFF_REPORT_NEW', reportId: { in: [...reportIds] }, readAt: null },
    data: { readAt: at },
  });
  return done.count;
}

export interface SharedReportAlertResult {
  route: 'staff' | 'owners';
  recipients: string[];
  /** Already told by the D273 live alert for this report (not told twice). */
  liveRecipients: string[];
}

/**
 * v1.78-live (D288, CONVENTIONS §10.101; owner: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله»): a new
 * report reaches every moderator and support member — an in-app `STAFF_REPORT_NEW` row per staff member, which the push
 * dispatcher sends on the app's staff channel («بلاغ جديد بانتظار الحل», never the reporter, the reason or the target).
 *
 * Who: every ACTIVE ADMIN account holding MODERATION or SUPPORT now, **on shift or not** (the shift decides only that
 * the push skips the general gap, as for D273); nobody → every OWNER. Never the reporter or the reported user. A
 * report on a live first runs the D273 alert (the live's responsible staff member gets `LIVE_STAFF_REPORT`); those
 * recipients are not told twice. One unread row per recipient: a newer report moves it up (and points it at the newest
 * report), so a busy queue never floods the inbox. Audited `moderation.report.alert` {reportId, recipients, route}.
 * Best effort: never fails the report.
 */
@Injectable()
export class ReportStaffAlertsService {
  private readonly logger = new Logger(ReportStaffAlertsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly liveAlerts: LiveStaffAlertsService,
  ) {}

  async onNewReport(reportId: string, reporterId: string): Promise<SharedReportAlertResult | null> {
    let liveRecipients: string[] = [];
    try {
      liveRecipients = (await this.liveAlerts.onReport(reportId, reporterId))?.recipients ?? [];
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not alert the staff about a live report');
    }
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
      select: { id: true, status: true, targetUserId: true },
    });
    if (!report || report.status !== 'OPEN') return null;
    const never = new Set([reporterId, ...(report.targetUserId ? [report.targetUserId] : [])]);
    let route: SharedReportAlertResult['route'] = 'staff';
    let staff = (
      await this.prisma.user.findMany({
        where: {
          role: 'ADMIN',
          status: 'ACTIVE',
          adminPermissions: { some: { permission: { in: [...SHARED_REPORT_ROLES] } } },
        },
        select: { id: true },
      })
    )
      .map((u) => u.id)
      .filter((id) => !never.has(id));
    if (staff.length === 0) {
      route = 'owners';
      staff = (
        await this.prisma.user.findMany({
          where: { role: 'ADMIN', status: 'ACTIVE', adminPermissions: { some: { permission: 'OWNER' } } },
          select: { id: true },
        })
      )
        .map((u) => u.id)
        .filter((id) => !never.has(id));
    }
    const told = new Set(liveRecipients);
    const recipients = staff.filter((id) => !told.has(id));
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      for (const recipientId of recipients) {
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:notif'), hashtext(${`${recipientId}:${STAFF_REPORT_NEW_GROUP}`}))`;
        const open = await tx.notification.findFirst({
          where: { recipientId, groupKey: STAFF_REPORT_NEW_GROUP, readAt: null },
          select: { id: true },
        });
        if (open) {
          await tx.notification.update({ where: { id: open.id }, data: { reportId, updatedAt: now } });
        } else {
          await tx.notification.create({
            data: {
              recipientId,
              type: 'STAFF_REPORT_NEW',
              reportId,
              groupKey: STAFF_REPORT_NEW_GROUP,
              createdAt: now,
              updatedAt: now,
            },
          });
        }
      }
      await this.audit.recordIn(tx, {
        action: AuditAction.MODERATION_REPORT_ALERT,
        actorUserId: null,
        targetType: 'report',
        targetId: reportId,
        metadata: { reportId, recipients, route, liveRecipients },
      });
    });
    return { route, recipients, liveRecipients };
  }

  /** {@link onNewReport} without failing the caller. */
  afterNewReport(reportId: string, reporterId: string): Promise<void> {
    return this.onNewReport(reportId, reporterId).then(
      () => undefined,
      (err: unknown) => {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not alert the staff about a new report');
      },
    );
  }
}
