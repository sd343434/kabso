/**
 * D355 «واتساب» in the panel: rendered to HTML in Node (no DOM library) — the inbox list (unread, assignee, closed), the
 * chat (bubbles, media states, voice, ticks, the reaction, the 24-hour window: closed → «إرسال قالب» only), the customer
 * panel (account card or the link hint, notes, history), the settings (no secret, the webhook address, the test), the
 * nav items per role and the badge. Both languages.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D355, EN_D355 } from '../src/i18n-d355';
import { visibleNav } from '../src/nav';
import {
  historyLine,
  WaChatView,
  WaComposer,
  WaConversationList,
  WaCustomerPanel,
  waBadgeText,
  WaSettingsView,
} from '../src/pages/WhatsApp';
import type { Capability, WaAssignment, WaConversation, WaMessage, WaStatus } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: 'OWNER' | 'SUPPORT' | 'FINANCE' | 'MODERATION') =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const wrap = (lang: Lang, caps: Capability[], node: ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const staffRef = { userId: 's1', displayName: 'Mona', staffId: 'Kabso07' };
const CONV: WaConversation = {
  id: 'c1',
  phone: '+966512345678',
  name: 'سارة',
  status: 'OPEN',
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 3,
  lastMessageAt: '2026-11-10T10:00:00.000Z',
  lastPreview: '📷 الإيصال',
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: '2026-11-11T10:00:00.000Z' },
  linkedAccount: null,
  closedAt: null,
  createdAt: '2026-11-10T09:00:00.000Z',
};
const msg = (over: Partial<WaMessage>): WaMessage => ({
  id: 'm',
  direction: 'INBOUND',
  type: 'TEXT',
  text: null,
  media: null,
  location: null,
  reaction: null,
  template: null,
  status: 'RECEIVED',
  error: null,
  sentBy: null,
  at: '2026-11-10T10:00:00.000Z',
  statusAt: null,
  ...over,
});
const MESSAGES: WaMessage[] = [
  msg({ id: 'm5', direction: 'OUTBOUND', text: 'تم الشحن', status: 'READ', sentBy: staffRef, reaction: '👍' }),
  msg({ id: 'm4', direction: 'OUTBOUND', text: 'لحظة', status: 'FAILED', error: { code: 131026, title: 'Message undeliverable' } }),
  msg({ id: 'm3', type: 'AUDIO', media: { state: 'STORED', mime: 'audio/ogg', size: 300, filename: null, voice: true } }),
  msg({ id: 'm2', type: 'DOCUMENT', media: { state: 'TYPE_REFUSED', mime: 'application/x-msdownload', size: 100, filename: 'a.exe', voice: false } }),
  msg({ id: 'm1', type: 'IMAGE', text: 'الإيصال', media: { state: 'STORED', mime: 'image/jpeg', size: 500, filename: null, voice: false } }),
];

describe('D355 «واتساب» — the panel', () => {
  it('every key has an English text', () => {
    for (const k of Object.keys(AR_D355)) expect(EN_D355[k as keyof typeof EN_D355], k).toBeTruthy();
  });

  it('the nav shows the inbox to OWNER / MODERATION / SUPPORT, settings and quick replies to OWNER / MODERATION only', () => {
    const items = (role: 'OWNER' | 'SUPPORT' | 'FINANCE' | 'MODERATION') =>
      visibleNav((c) => capsOf(role).includes(c)).flatMap((g) => g.items.map((i) => i.to));
    for (const role of ['OWNER', 'MODERATION'] as const) {
      expect(items(role)).toEqual(expect.arrayContaining(['/whatsapp', '/whatsapp/settings', '/whatsapp/quick-replies']));
    }
    expect(items('SUPPORT')).toContain('/whatsapp');
    expect(items('SUPPORT')).not.toContain('/whatsapp/settings');
    expect(items('FINANCE')).not.toContain('/whatsapp');
    expect(waBadgeText(0)).toBeNull();
    expect(waBadgeText(7)).toBe('7');
    expect(waBadgeText(150)).toBe('99+');
  });

  it('the list: unread count, unassigned / mine / with someone / closed, the phone isolated LTR', () => {
    const html = wrap('ar', capsOf('SUPPORT'), (
      <WaConversationList
        items={[
          CONV,
          { ...CONV, id: 'c2', name: null, unreadCount: 0, assignedTo: staffRef, assignedToMe: true },
          { ...CONV, id: 'c3', assignedTo: staffRef },
          { ...CONV, id: 'c4', status: 'CLOSED' },
        ]}
        selected="c1"
        onOpen={() => undefined}
      />
    ));
    expect(html).toContain('سارة');
    expect(html).toContain('aria-label="3 غير مقروءة"');
    expect(html).toContain('غير مسندة');
    expect(html).toContain('معي');
    expect(html).toContain('مع Mona');
    expect(html).toContain('مغلقة');
    expect(html).toContain('<bdi dir="ltr" class="wa-phone">+966512345678</bdi>');
    expect(html).toContain('aria-current="true"');
    expect(wrap('ar', [], <WaConversationList items={[]} selected={null} onOpen={() => undefined} />)).toContain('لا توجد محادثات');
  });

  it('the chat: bubbles, media states, the voice note, ticks, the failure and the reaction; claim for an unassigned one', () => {
    const html = wrap('ar', capsOf('SUPPORT'), (
      <WaChatView c={CONV} messages={MESSAGES} onAction={() => undefined} composer={null} />
    ));
    expect(html).toContain('استلام المحادثة');
    expect(html).toContain('/api/v1/admin/whatsapp/messages/m1/media');
    expect(html).toContain('<audio controls=""');
    expect(html).toContain('رسالة صوتية');
    expect(html).toContain('نوع الملف غير مسموح');
    expect(html).toContain('class="wa-ticks read"');
    expect(html).toContain('class="wa-ticks failed"');
    expect(html).toContain('Message undeliverable');
    expect(html).toContain('أرسلها Mona');
    expect(html).toContain('👍');
    expect(html).toContain('نافذة الرد مفتوحة');
    // Oldest first on screen.
    expect(html.indexOf('data-wa-msg="m1"')).toBeLessThan(html.indexOf('data-wa-msg="m5"'));
    const other = wrap('en', capsOf('SUPPORT'), (
      <WaChatView c={{ ...CONV, assignedTo: staffRef }} messages={[]} onAction={() => undefined} composer={null} />
    ));
    expect(other).not.toContain('Claim');
    expect(other).not.toContain('>Close<');
    const managed = wrap('en', capsOf('MODERATION'), (
      <WaChatView c={{ ...CONV, assignedTo: staffRef }} messages={[]} onAction={() => undefined} composer={null} />
    ));
    expect(managed).toContain('Transfer');
    expect(managed).toContain('Release');
  });

  it('the 24-hour window: open → the text composer; closed → «إرسال قالب» only; another agent’s → no composer', () => {
    const open = wrap('ar', capsOf('SUPPORT'), <WaComposer c={CONV} onSent={() => undefined} />);
    expect(open).toContain('<textarea');
    expect(open).toContain('ردود سريعة');
    const closedConv = { ...CONV, window: { open: false, closesAt: '2026-11-09T10:00:00.000Z' } };
    const closed = wrap('ar', capsOf('SUPPORT'), <WaComposer c={closedConv} onSent={() => undefined} />);
    expect(closed).not.toContain('<textarea');
    expect(closed).toContain('إرسال قالب');
    const banner = wrap('ar', capsOf('SUPPORT'), (
      <WaChatView c={closedConv} messages={[]} onAction={() => undefined} composer={null} />
    ));
    expect(banner).toContain('مرّت 24 ساعة على آخر رسالة من العميل');
    const taken = wrap('en', capsOf('SUPPORT'), (
      <WaComposer c={{ ...CONV, assignedTo: staffRef }} onSent={() => undefined} />
    ));
    expect(taken).not.toContain('<textarea');
    expect(taken).toContain('Another team member has this conversation.');
    expect(wrap('en', capsOf('SUPPORT'), <WaComposer c={{ ...CONV, status: 'CLOSED' }} onSent={() => undefined} />)).toBe('');
  });

  it('the customer panel: the link hint (no automatic phone match), the account card, notes and history', () => {
    const history: WaAssignment[] = [
      { id: 'h2', action: 'TRANSFER', from: staffRef, to: { userId: 's2', displayName: 'Ali', staffId: null }, by: staffRef, at: CONV.lastMessageAt },
      { id: 'h1', action: 'REOPEN', from: null, to: null, by: null, at: CONV.lastMessageAt },
    ];
    const none = wrap('ar', capsOf('SUPPORT'), (
      <WaCustomerPanel c={CONV} notes={[]} history={history} onLink={() => undefined} onUnlink={() => undefined} onNote={() => undefined} />
    ));
    expect(none).toContain('لا يوجد في Kabso رقم هاتف موثّق');
    expect(none).toContain('لا توجد ملاحظات');
    expect(none).toContain('حوّلها Mona إلى Ali');
    expect(none).toContain('أُعيد فتحها');
    const linked = wrap('en', capsOf('SUPPORT'), (
      <WaCustomerPanel
        c={{
          ...CONV,
          linkedAccount: { userId: 'u1', username: 'sara_9', displayName: 'Sara', avatarUrl: null, status: 'ACTIVE', countryCode: 'SA', createdAt: '2026-01-01T00:00:00.000Z' },
        }}
        notes={[{ id: 'n1', body: 'Waiting for finance', author: staffRef, at: CONV.lastMessageAt }]}
        history={[]}
        onLink={() => undefined}
        onUnlink={() => undefined}
        onNote={() => undefined}
      />
    ));
    expect(linked).toContain('@sara_9');
    expect(linked).toContain('Unlink');
    expect(linked).toContain('Waiting for finance');
    expect(historyLine((k, v) => translate('en', k, v), history[0]!)).toBe('Mona transferred it to Ali');
  });

  it('the settings: status, the webhook address to paste in Meta, missing names, the test result — never a secret', () => {
    const s: WaStatus = {
      enabled: false,
      phoneNumberId: null,
      businessAccountId: null,
      displayName: null,
      graphApiVersion: 'v23.0',
      webhookUrl: 'https://api.kabsolive.com/api/v1/webhooks/whatsapp',
      subscribedFields: ['messages'],
      retentionDays: 180,
      mediaMaxBytes: 16 * 1048576,
      lastInboundAt: null,
      conversations: 0,
      missing: ['WHATSAPP_PHONE_NUMBER_ID', 'WHATSAPP_ACCESS_TOKEN_FILE'],
    };
    const off = wrap('ar', capsOf('OWNER'), <WaSettingsView s={s} test={null} onTest={() => undefined} />);
    expect(off).toContain('غير مفعّل');
    expect(off).toContain('https://api.kabsolive.com/api/v1/webhooks/whatsapp');
    expect(off).toContain('WHATSAPP_ACCESS_TOKEN_FILE');
    expect(off).toContain('180 يوماً');
    expect(off).toMatch(/<button class="btn primary" disabled="">اختبار الاتصال<\/button>/);
    const ok = wrap('en', capsOf('OWNER'), (
      <WaSettingsView
        s={{ ...s, enabled: true, phoneNumberId: '1098765432100', missing: [] }}
        test={{ ok: true, displayPhoneNumber: '+966 50 000 0000', verifiedName: 'Kabso Live', qualityRating: 'GREEN', templates: 2, error: null }}
        onTest={() => undefined}
      />
    ));
    expect(ok).toContain('Connected — Kabso Live (GREEN), approved templates: 2');
    const fail = wrap('en', capsOf('OWNER'), (
      <WaSettingsView
        s={{ ...s, enabled: true, missing: [] }}
        test={{ ok: false, displayPhoneNumber: null, verifiedName: null, qualityRating: null, templates: null, error: { status: 401, code: 190, title: 'x' } }}
        onTest={() => undefined}
      />
    ));
    expect(fail).toContain('HTTP 401 / 190');
  });
});
