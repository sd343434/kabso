/**
 * D364 (owner approved «نعم موافق»; CONVENTIONS §10.157): WhatsApp departments and the transfer in the panel — rendered
 * to HTML in Node: the transfer dialog (the department chips, «أول متاح في القسم» first and picked by default, the
 * department's agents with the on-shift dot and their open conversations, the note, «تحويل»), the department tag on the
 * inbox rows and in the chat head, the department queue's name, the inbox's department filter, the history lines with
 * the department and the note, and the staff card's departments with their dialog. Both languages.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D364, EN_D364 } from '../src/i18n-d364';
import {
  MemberCard,
  WaDepartmentsDialog,
  type Member,
  type TeamWaDepartments,
  type TeamWhatsApp,
} from '../src/pages/Team';
import {
  DepartmentFilter,
  historyLine,
  ownerText,
  WaChatView,
  WaConversationList,
  WaTransferView,
} from '../src/pages/WhatsApp';
import type { Capability, WaAgent, WaAssignment, WaConversation } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const OWNER_CAPS = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes('OWNER'));
const VIEW_CAPS: Capability[] = OWNER_CAPS.filter((c) => !c.startsWith('support.whatsapp')).concat('support.whatsapp.view');

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: 'self', email: 'o@kabso.test', username: 'o', displayName: 'O' },
    roles: ['OWNER'],
    capabilities: caps,
    csrfToken: 'csrf',
    expiresAt: '2026-11-11T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const wrap = (lang: Lang, caps: Capability[], node: ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);
const noop = () => undefined;
const t = (lang: Lang) => (key: Parameters<typeof translate>[1], vars?: Record<string, string | number>) =>
  translate(lang, key, vars);

const CONV: WaConversation = {
  id: 'c1',
  phone: '+966512345678',
  name: 'سارة',
  status: 'OPEN',
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 1,
  lastMessageAt: '2026-11-11T10:00:00.000Z',
  lastPreview: 'مرحبا',
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: '2026-11-12T10:00:00.000Z' },
  linkedAccount: null,
  closedAt: null,
  createdAt: '2026-11-11T09:00:00.000Z',
  department: 'PAYMENTS',
};

const AGENTS: WaAgent[] = [
  { userId: 's3', displayName: 'خالد', staffId: 'Kabso04', onShift: true, departments: ['PAYMENTS'], openCount: 1 },
  { userId: 's4', displayName: 'رنا', staffId: 'Kabso05', onShift: false, departments: ['PAYMENTS', 'TECHNICAL'], openCount: 3 },
];

const member = (
  wa: TeamWhatsApp,
  depts: TeamWaDepartments,
): Member & { whatsapp: TeamWhatsApp; whatsappDepartments: TeamWaDepartments } => ({
  id: '44444444-4444-4444-8444-444444444444',
  email: 'mona@kabso.test',
  username: 'mona',
  displayName: 'منى',
  avatarUrl: null,
  status: 'ACTIVE',
  roles: ['SUPPORT'],
  totpEnrolled: true,
  lockedUntil: null,
  lastSignInAt: '2026-11-10T09:00:00.000Z',
  onShift: false,
  shiftSince: null,
  regions: [],
  staffId: 'Kabso07',
  whatsapp: wa,
  whatsappDepartments: depts,
});
const REPLY: TeamWhatsApp = { level: 'REPLY', setLevel: null, defaultLevel: 'REPLY', locked: false };

describe('D364 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D364).sort()).toEqual(Object.keys(AR_D364).sort());
    for (const k of Object.keys(AR_D364) as (keyof typeof AR_D364)[]) {
      expect(EN_D364[k], k).toBeTruthy();
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D364[k]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D364[k]);
    }
    expect(AR_D364.waDeptPAYMENTS).toBe('الشحن والمدفوعات');
    expect(AR_D364.waDeptAGENCIES).toBe('الوكالات والمضيفون');
    expect(AR_D364.waDeptTECHNICAL).toBe('المشاكل التقنية');
    expect(AR_D364.waDeptREPORTS).toBe('البلاغات والحظر');
    expect(AR_D364.waDeptGENERAL).toBe('عام');
    expect(AR_D364.waTransferFirst).toBe('أول متاح في القسم');
  });
});

describe('D364 the transfer dialog', () => {
  it('department chips, «أول متاح» first and picked, the agents with shift and load, the note, «تحويل»', () => {
    const html = wrap('ar', OWNER_CAPS, (
      <WaTransferView
        choice={{ department: 'PAYMENTS', to: null, note: '' }}
        agents={AGENTS}
        loading={false}
        busy={false}
        onChange={noop}
        onConfirm={noop}
      />
    ));
    for (const d of ['PAYMENTS', 'AGENCIES', 'TECHNICAL', 'REPORTS', 'GENERAL']) expect(html).toContain(`data-wa-dept-chip="${d}"`);
    expect(html).toMatch(/aria-checked="true"[^>]*data-wa-dept-chip="PAYMENTS"/);
    expect(html).toMatch(/aria-checked="true"[^>]*data-wa-transfer-first/);
    // «أول متاح في القسم» before the agents.
    expect(html.indexOf('أول متاح في القسم')).toBeLessThan(html.indexOf('خالد'));
    expect(html.indexOf('خالد')).toBeLessThan(html.indexOf('رنا'));
    expect(html).toContain('Kabso04 · مناوب · 1 مفتوحة');
    expect(html).toContain('Kabso05 · خارج المناوبة · 3 مفتوحة');
    expect(html).toContain('wa-shift-dot on');
    expect(html).toContain('maxLength="500"');
    expect(html).toContain('لا تُرسل للعميل أبداً');
    expect(html).toContain('data-wa-transfer-confirm');
    // A person picked; an empty department.
    const picked = wrap('en', OWNER_CAPS, (
      <WaTransferView
        choice={{ department: 'TECHNICAL', to: 's4', note: 'abc' }}
        agents={[]}
        loading={false}
        busy={false}
        onChange={noop}
        onConfirm={noop}
      />
    ));
    expect(picked).toContain('No agents in this department yet.');
    expect(picked).toMatch(/aria-checked="false"[^>]*data-wa-transfer-first/);
    expect(picked).toContain('3/500');
  });
});

describe('D364 the inbox and the chat', () => {
  it('rows and the chat head carry the department; an unassigned one reads as the department queue', () => {
    const rows = wrap('ar', OWNER_CAPS, (
      <WaConversationList items={[CONV, { ...CONV, id: 'c2', department: undefined }]} selected={null} onOpen={noop} />
    ));
    expect(rows).toContain('data-wa-department="PAYMENTS"');
    expect(rows).toContain('قائمة الشحن والمدفوعات');
    // An older API (no department): GENERAL, «غير مسندة».
    expect(rows).toContain('data-wa-department="GENERAL"');
    expect(rows).toContain('غير مسندة');
    expect(ownerText(t('en'), { ...CONV, assignedTo: { userId: 'u', displayName: 'Ali', staffId: null } })).toBe('With Ali');
    const chat = wrap('en', OWNER_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={null} />);
    expect(chat).toContain('Top-ups &amp; payments queue');
    expect(chat).toContain('data-wa-department="PAYMENTS"');
    expect(chat).toContain('data-wa-transfer');
    // VIEW and a closed conversation: no transfer.
    expect(wrap('en', VIEW_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={null} />)).not.toContain(
      'data-wa-transfer',
    );
    expect(
      wrap('en', OWNER_CAPS, <WaChatView c={{ ...CONV, status: 'CLOSED' }} messages={[]} onAction={noop} composer={null} />),
    ).not.toContain('data-wa-transfer');
  });

  it('the department filter: all, then the five', () => {
    const html = wrap('ar', OWNER_CAPS, <DepartmentFilter value="REPORTS" onChange={noop} />);
    expect(html).toContain('<option value="">كل الأقسام</option>');
    expect(html).toContain('<option value="REPORTS" selected="">البلاغات والحظر</option>');
    expect(html.match(/<option /g)).toHaveLength(6);
  });

  it('history lines: to a person or a queue, with the department and the note', () => {
    const base: WaAssignment = {
      id: 'h1',
      action: 'TRANSFER',
      from: { userId: 'a', displayName: 'Ali', staffId: null },
      to: { userId: 'b', displayName: 'Badr', staffId: null },
      by: { userId: 'a', displayName: 'Ali', staffId: null },
      at: '2026-11-11T10:00:00.000Z',
      department: 'PAYMENTS',
      fromDepartment: 'GENERAL',
      note: { id: 'n', body: 'paid the agent' },
    };
    expect(historyLine(t('en'), base)).toBe('Ali transferred it to Badr — Top-ups & payments · Note: paid the agent');
    expect(historyLine(t('ar'), { ...base, to: null, note: null })).toBe('حوّلها Ali إلى قائمة الشحن والمدفوعات');
    // Before D364 (no department): D355's line.
    expect(historyLine(t('en'), { ...base, department: undefined, note: undefined })).toBe('Ali transferred it to Badr');
  });
});

describe('D364 the staff card', () => {
  it('shows the departments (GENERAL by default) with the change button for REPLY+', () => {
    const m = member(REPLY, { departments: ['GENERAL'], isDefault: true });
    const ar = wrap('ar', OWNER_CAPS, (
      <MemberCard m={m} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} onWhatsApp={noop} onWaDepartments={noop} />
    ));
    expect(ar).toContain('أقسام واتساب');
    expect(ar).toContain('data-wa-departments="GENERAL"');
    expect(ar).toContain('data-wa-departments-default="true"');
    expect(ar).toContain('تغيير الأقسام');
    // The level row comes first.
    expect(ar.indexOf('مستوى واتساب')).toBeLessThan(ar.indexOf('أقسام واتساب'));
    const set = wrap('en', OWNER_CAPS, (
      <MemberCard
        m={member(REPLY, { departments: ['PAYMENTS', 'TECHNICAL'], isDefault: false })}
        selfId="self"
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
        onWaDepartments={noop}
      />
    ));
    expect(set).toContain('Top-ups &amp; payments');
    expect(set).toContain('Technical issues');
    expect(set).toContain('data-wa-departments-default="false"');
    // VIEW: no change, the note why.
    const view = wrap('ar', OWNER_CAPS, (
      <MemberCard
        m={member({ ...REPLY, level: 'VIEW', setLevel: 'VIEW' }, { departments: ['GENERAL'], isDefault: true })}
        selfId="self"
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
        onWaDepartments={noop}
      />
    ));
    expect(view).not.toContain('data-edit-wa-departments');
    expect(view).toContain('الأقسام لمن مستواه');
  });

  it('the dialog: the five departments as checkboxes, the set ones checked, the reason and the code', () => {
    const m = member(REPLY, { departments: ['PAYMENTS'], isDefault: false });
    const html = wrap('ar', OWNER_CAPS, <WaDepartmentsDialog member={m} onClose={noop} onDone={noop} />);
    expect(html).toContain('أقسام واتساب — منى');
    for (const d of ['PAYMENTS', 'AGENCIES', 'TECHNICAL', 'REPORTS', 'GENERAL']) expect(html).toContain(`data-wa-department-option="${d}"`);
    expect(html.match(/type="checkbox"[^>]*checked=""/g)).toHaveLength(1);
    expect(html).toContain('يستقبل الموظف التحويلات');
  });
});
