/**
 * D204 «نزاعات الشحن» and «أسعار الصرف»: the disputed order's page rendered to HTML in Node — the facts (USD and the
 * local amount, the frozen coins), the whole chat with «الإدارة» lines and the system steps, the private pictures
 * served only through the panel's audited endpoint, and the decision buttons only for the money roles.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { DisputeOrderView, PriceText } from '../src/pages/Disputes';
import type { AdminOrder } from '../src/types';

const state = (lang: Lang, caps: string[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (cap) => caps.includes(cap),
  toast: () => undefined,
});

const ORDER: AdminOrder = {
  id: '0190f3a0-0000-7000-8000-0000000000aa',
  status: 'DISPUTED',
  coins: 1_000_000,
  heldCoins: 1_000_000,
  country: 'EG',
  price: { usdMinor: 1250, usd: '12.50', local: { currency: 'EGP', minor: 63125, digits: 2, amount: '631.25', rate: '50.5' } },
  paymentType: 'MOBILE_WALLET',
  createdAt: '2026-10-31T09:00:00.000Z',
  detailsAt: '2026-10-31T09:02:00.000Z',
  noticeAcknowledgedAt: '2026-10-31T09:03:00.000Z',
  paidAt: '2026-10-31T09:10:00.000Z',
  disputedAt: '2026-10-31T09:26:00.000Z',
  disputedBy: 'BUYER',
  closedAt: null,
  closeReason: null,
  buyer: { id: '0190f3a0-0000-7000-8000-000000000001', username: 'sara', displayName: 'سارة', email: 's@example.test' },
  agent: { id: '0190f3a0-0000-7000-8000-000000000002', username: 'coin0007', displayName: 'محمد', code: 'coin0007', stockCoins: 29_000_000 },
  messages: [
    { id: 'm1', kind: 'SYSTEM', role: 'SYSTEM', author: null, text: null, method: null, event: 'CREATED', hasImage: false, createdAt: '2026-10-31T09:00:00.000Z', adminUserId: null },
    { id: 'm2', kind: 'PAYMENT_DETAILS', role: 'AGENT', author: { id: 'a', username: 'coin0007', displayName: 'محمد' }, text: 'Vodafone Cash 0100 000 0000', method: 'MOBILE_WALLET', event: null, hasImage: false, createdAt: '2026-10-31T09:02:00.000Z', adminUserId: null },
    { id: 'm3', kind: 'TRANSFER_PROOF', role: 'BUYER', author: { id: 'b', username: 'sara', displayName: 'سارة' }, text: null, method: null, event: null, hasImage: true, createdAt: '2026-10-31T09:10:00.000Z', adminUserId: null },
    { id: 'm4', kind: 'SYSTEM', role: 'SYSTEM', author: null, text: null, method: null, event: 'DISPUTED_BY_BUYER', hasImage: false, createdAt: '2026-10-31T09:26:00.000Z', adminUserId: null },
    { id: 'm5', kind: 'TEXT', role: 'ADMIN', author: null, text: 'نراجع الإثباتات', method: null, event: null, hasImage: false, createdAt: '2026-10-31T09:30:00.000Z', adminUserId: '0190f3a0-0000-7000-8000-000000000009' },
  ],
};

const render = (caps: string[], lang: Lang = 'ar', data: AdminOrder = ORDER) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, caps)}>
      <DisputeOrderView data={data} onChange={() => undefined} />
    </AppContext.Provider>,
  );

describe('DisputeOrderView', () => {
  it('Arabic: facts, USD and local price, frozen coins, the chat with «الإدارة» and the system steps', () => {
    const html = render(['recharge.disputes', 'recharge.disputes.resolve']);
    expect(html).toContain('طلب شحن');
    expect(html).toContain('$12.50 · 631.25 EGP');
    expect(html).toContain('مجمّد');
    expect(html).toContain('coin0007');
    expect(html).toContain('الإدارة');
    expect(html).toContain('نراجع الإثباتات');
    expect(html).toContain('فتح المشتري نزاعاً');
    expect(html).toContain('معلومات الدفع (محفظة إلكترونية)');
    expect(html).toContain('لقطة شاشة الحوالة');
    // The picture only through the audited panel endpoint, never a storage URL.
    expect(html).toContain(`/api/v1/admin/recharge/orders/${ORDER.id}/messages/m3/image`);
    expect(html).not.toContain('private/recharge-orders');
    expect(html).toContain('إضافة العملات للمشتري');
    expect(html).toContain('إعادة العملات للوكيل');
  });

  it('only the money roles get the decision; English labels', () => {
    const support = render(['recharge.disputes']);
    expect(support).not.toContain('إضافة العملات للمشتري');
    expect(support).toContain('القرار لأدوار المالية والمالك فقط.');
    const en = render(['recharge.disputes', 'recharge.disputes.resolve'], 'en');
    expect(en).toContain('Credit the buyer');
    expect(en).toContain('Team');
    expect(en).toContain('The buyer opened a dispute');
    const decided = render(['recharge.disputes', 'recharge.disputes.resolve'], 'ar', {
      ...ORDER,
      status: 'COMPLETED_BY_ADMIN',
      heldCoins: 0,
      closeReason: 'وصلت الحوالة',
    });
    expect(decided).not.toContain('إضافة العملات للمشتري');
    expect(decided).toContain('وصلت الحوالة');
  });

  it('shows USD only without a rate', () => {
    const html = renderToStaticMarkup(<PriceText price={{ usdMinor: 1250, usd: '12.50', local: null }} />);
    expect(html).toContain('$12.50');
    expect(html).not.toContain('·');
  });
});
