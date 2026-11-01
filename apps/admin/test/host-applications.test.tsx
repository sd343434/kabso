/**
 * D209 «طلبات المضيفين»: an application's page rendered to HTML in Node (no DOM library) — the private fields and the
 * account summary, no picture fetched until asked, the pictures and the decision only for the roles that may, and a
 * purged application without its private fields.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { HostApplicationView } from '../src/pages/HostApplications';
import type { Capability, HostApplicationDetail } from '../src/types';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});

function fixture(over: Partial<HostApplicationDetail> = {}): HostApplicationDetail {
  return {
    id: '0190f3a0-0000-7000-8000-0000000000a1',
    status: 'PENDING',
    createdAt: '2026-10-31T09:00:00.000Z',
    decidedAt: null,
    decidedBy: null,
    rejectReason: null,
    cancelReason: null,
    purgedAt: null,
    reapplyAt: null,
    displayName: 'سارة المضيفة',
    country: 'SA',
    dateOfBirth: '2000-05-01',
    age: 26,
    contact: { type: 'WHATSAPP', value: '+966511111111' },
    bio: 'أبث الطبخ\nوالدردشة',
    links: ['https://www.tiktok.com/@sara'],
    rulesAcceptedAt: '2026-10-31T09:00:00.000Z',
    photos: { photo: true, selfie: true },
    account: {
      id: '0190f3a0-0000-7000-8000-0000000000b1',
      username: 'sara',
      displayName: 'سارة',
      avatarUrl: null,
      email: 'sara@example.test',
      status: 'ACTIVE',
      createdAt: '2026-09-01T09:00:00.000Z',
      accountAgeDays: 60,
      profileCountry: 'SA',
      openReports: 2,
      totalReports: 3,
      bans: 1,
      warnings: 0,
      host: null,
      agency: null,
    },
    history: [{ id: '0190f3a0-0000-7000-8000-0000000000a0', status: 'REJECTED', createdAt: '2026-09-15T09:00:00.000Z', decidedAt: '2026-09-16T09:00:00.000Z', rejectReason: 'صورة غير واضحة' }],
    ...over,
  };
}

const render = (data: HostApplicationDetail, caps: Capability[], lang: Lang = 'ar') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, caps)}>
      <HostApplicationView data={data} busy={false} onApprove={() => undefined} onReject={() => undefined} />
    </AppContext.Provider>,
  );

const SUPPORT: Capability[] = ['hosts.applications', 'hosts.applications.photos', 'hosts.applications.decide'];

describe('D209 host application page', () => {
  it('shows the fields and the account summary; the pictures wait for a click', () => {
    const html = render(fixture(), SUPPORT);
    for (const text of ['سارة المضيفة', '+966511111111', '2000-05-01', '26 سنة', 'https://www.tiktok.com/@sara', 'مفتوحة: 2', 'الكل: 3', 'sara@example.test', 'صورة غير واضحة', 'واتساب']) {
      expect(html, text).toContain(text);
    }
    expect(html).not.toContain('<img');
    expect(html).toContain('data-private-photo="photo"');
    expect(html).toContain('data-host-approve');
    expect(html).toContain('data-host-reject');
  });

  it('MODERATION may look but not open the pictures or decide', () => {
    const html = render(fixture(), ['hosts.applications']);
    expect(html).toContain('+966511111111');
    expect(html).toContain(translate('ar', 'hostAppPhotoNotAllowed'));
    expect(html).not.toContain('data-host-approve');
  });

  it('a decided or purged application has no buttons; purged hides the private fields', () => {
    const decided = render(fixture({ status: 'REJECTED', rejectReason: 'لا هوية', reapplyAt: '2026-11-30T09:00:00.000Z', decidedAt: '2026-10-31T10:00:00.000Z', decidedBy: { id: 'x', username: 'boss', displayName: 'Boss' } }), SUPPORT, 'en');
    expect(decided).not.toContain('data-host-approve');
    expect(decided).toContain('لا هوية');
    expect(decided).toContain('@boss');
    expect(decided).toContain('May apply again');
    const purged = render(fixture({ status: 'CANCELLED', cancelReason: 'ACCOUNT', purgedAt: '2026-11-01T09:00:00.000Z', dateOfBirth: null, age: null, contact: { type: 'PHONE', value: null }, bio: null, links: [], photos: { photo: false, selfie: false } }), SUPPORT);
    expect(purged).not.toContain('+966511111111');
    expect(purged).toContain(translate('ar', 'hostAppCancelACCOUNT'));
    expect(purged).toContain(translate('ar', 'photoMissing'));
  });
});
