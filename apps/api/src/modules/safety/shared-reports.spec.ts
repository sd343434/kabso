import { describe, expect, it } from 'vitest';
import { CAPABILITIES } from '../admin-panel/admin-permissions.js';
import { notificationPushData } from '../notifications/notification-push.dispatcher.js';
import { ANDROID_CHANNEL_ID } from '../push/push-sender.js';
import { notificationBody, STAFF_REPORT_PUSH_TITLE } from '../push/push-texts.js';
import { resolveReportSchema, sharedReportsQuerySchema } from './safety.schemas.js';

/** v1.78-live (D288, §10.101): the pure parts of the shared report queue. */
describe('D288 shared reports', () => {
  it('the push names nothing about the report, on its own channel and title', () => {
    const base = {
      type: 'STAFF_REPORT_NEW',
      actorName: null,
      actorCount: 0,
      targetType: 'REPORT',
      targetId: 'r1',
      targetText: 'never shown',
    };
    expect(notificationBody(base, 'ar')).toBe('بلاغ جديد بانتظار الحل');
    expect(notificationBody(base, 'en')).toBe('A new report is waiting to be resolved');
    expect(STAFF_REPORT_PUSH_TITLE).toEqual({ ar: 'بلاغات فريق كابسو', en: 'Kabso Team reports' });
    expect(ANDROID_CHANNEL_ID.staff).toBe('kabso_staff');
    const data = notificationPushData({
      id: 'n1',
      type: 'STAFF_REPORT_NEW',
      actors: [],
      actorCount: 0,
      target: {
        type: 'REPORT',
        id: 'r1',
        postId: null,
        thumbUrl: null,
        text: null,
        reportTargetType: 'POST',
      },
      createdAt: '2026-11-06T10:00:00.000Z',
      read: false,
    });
    expect(data).toEqual({
      kind: 'notification',
      channel: 'staff',
      notificationId: 'n1',
      type: 'STAFF_REPORT_NEW',
      targetType: 'REPORT',
      targetId: 'r1',
    });
  });

  it('the capabilities: SUPPORT reads and resolves; reopen is OWNER and MODERATION', () => {
    expect(CAPABILITIES['reports.view']).toEqual(['OWNER', 'MODERATION', 'SUPPORT']);
    expect(CAPABILITIES['reports.resolve']).toEqual(['OWNER', 'MODERATION', 'SUPPORT']);
    expect(CAPABILITIES['reports.act']).toEqual(['OWNER', 'MODERATION']);
    expect(CAPABILITIES['reports.reopen']).toEqual(['OWNER', 'MODERATION']);
  });

  it('the queue: OPEN by default, RESOLVED accepted; the note is optional and 1–500', () => {
    expect(sharedReportsQuerySchema.parse({})).toMatchObject({ status: 'OPEN', limit: 20 });
    expect(sharedReportsQuerySchema.parse({ status: 'RESOLVED' }).status).toBe('RESOLVED');
    expect(sharedReportsQuerySchema.safeParse({ status: 'DONE' }).success).toBe(false);
    expect(resolveReportSchema.parse({})).toEqual({});
    expect(resolveReportSchema.parse({ note: ' ok ' })).toEqual({ note: 'ok' });
    expect(resolveReportSchema.safeParse({ note: '' }).success).toBe(false);
    expect(resolveReportSchema.safeParse({ note: 'x'.repeat(501) }).success).toBe(false);
    expect(resolveReportSchema.safeParse({ extra: 1 }).success).toBe(false);
  });
});
