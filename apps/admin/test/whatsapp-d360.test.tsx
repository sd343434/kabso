/**
 * D360 «مستوى واتساب لكل موظف» in the panel: rendered to HTML in Node — the member card's level row (the level, «افتراضي»
 * when none is set, the OWNER locked), the level dialog (the four levels + the roles' default, the reason and the
 * code), the nav and the badge for VIEW, and the VIEW-only chat: «مشاهدة فقط», no action buttons, no composer, no
 * link / unlink / note in the customer panel. Both languages.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D360, EN_D360 } from '../src/i18n-d360';
import { visibleNav } from '../src/nav';
import {
  MemberCard,
  WhatsAppLevelDialog,
  WhatsAppLevelRow,
  type Member,
  type TeamWhatsApp,
} from '../src/pages/Team';
import { WaChatView, WaComposer, WaCustomerPanel } from '../src/pages/WhatsApp';
import type { Capability, WaConversation } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const OWNER_CAPS = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes('OWNER'));
const NOT_WA = (c: Capability) => !c.startsWith('support.whatsapp');
/** A MODERATION staff member whose WhatsApp level is VIEW: their role's capabilities, WhatsApp read only. */
const VIEW_CAPS: Capability[] = [
  ...(Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes('MODERATION') && NOT_WA(c)),
  'support.whatsapp.view',
];
const REPLY_CAPS: Capability[] = [...VIEW_CAPS, 'support.whatsapp'];

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: 'self', email: 'o@kabso.test', username: 'o', displayName: 'O' },
    roles: ['OWNER'],
    capabilities: caps,
    csrfToken: 'csrf',
    expiresAt: '2026-11-10T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const wrap = (lang: Lang, caps: Capability[], node: ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const CONV: WaConversation = {
  id: 'c1',
  phone: '+966512345678',
  name: 'سارة',
  status: 'OPEN',
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 2,
  lastMessageAt: '2026-11-10T10:00:00.000Z',
  lastPreview: 'مرحبا',
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: '2026-11-11T10:00:00.000Z' },
  linkedAccount: null,
  closedAt: null,
  createdAt: '2026-11-10T09:00:00.000Z',
};

const member = (wa: TeamWhatsApp, over: Partial<Member> = {}): Member & { whatsapp: TeamWhatsApp } => ({
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
  ...over,
  whatsapp: wa,
});

describe('D360 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D360).sort()).toEqual(Object.keys(AR_D360).sort());
    for (const k of Object.keys(AR_D360) as (keyof typeof AR_D360)[]) {
      expect(EN_D360[k], k).toBeTruthy();
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D360[k]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D360[k]);
    }
    expect(AR_D360.waViewOnly).toBe('مشاهدة فقط');
  });
});

describe('D360 the team page: the WhatsApp level control', () => {
  it('a member with no level set shows the roles’ default and «افتراضي», with the change button', () => {
    const m = member({ level: 'REPLY', setLevel: null, defaultLevel: 'REPLY', locked: false });
    const ar = wrap('ar', OWNER_CAPS, (
      <MemberCard m={m} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} onWhatsApp={noop} />
    ));
    expect(ar).toContain('مستوى واتساب');
    expect(ar).toContain('data-wa-level="REPLY"');
    expect(ar).toContain('data-wa-level-set=""');
    expect(ar).toContain('افتراضي');
    expect(ar).toContain('تغيير المستوى');
    const en = wrap('en', OWNER_CAPS, <dl>{<WhatsAppLevelRow wa={m.whatsapp} onEdit={noop} />}</dl>);
    expect(en).toContain('Reply');
    expect(en).toContain('default');
    expect(en).toContain('Change level');
  });

  it('a level set (VIEW) shows «مشاهدة فقط» without «افتراضي»; an OWNER is locked to Manage with no button', () => {
    const v = wrap('ar', OWNER_CAPS, (
      <dl>
        <WhatsAppLevelRow wa={{ level: 'VIEW', setLevel: 'VIEW', defaultLevel: 'MANAGE', locked: false }} onEdit={noop} />
      </dl>
    ));
    expect(v).toContain('مشاهدة فقط');
    expect(v).toContain('data-wa-level-set="VIEW"');
    expect(v).not.toContain('افتراضي');
    const o = wrap('en', OWNER_CAPS, (
      <dl>
        <WhatsAppLevelRow wa={{ level: 'MANAGE', setLevel: null, defaultLevel: 'MANAGE', locked: true }} onEdit={noop} />
      </dl>
    ));
    expect(o).toContain('Owner: always Manage');
    expect(o).not.toContain('data-edit-wa-level');
    // An older API (no `whatsapp`): no row.
    const old = { ...member({ level: 'NONE', setLevel: null, defaultLevel: 'NONE', locked: false }) } as Member;
    delete (old as { whatsapp?: unknown }).whatsapp;
    expect(wrap('ar', OWNER_CAPS, <MemberCard m={old} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} />)).not.toContain(
      'مستوى واتساب',
    );
  });

  it('the dialog: the roles’ default first, the four levels with what each allows, the reason and the code', () => {
    const m = member({ level: 'MANAGE', setLevel: null, defaultLevel: 'MANAGE', locked: false }, { roles: ['MODERATION'] });
    const ar = wrap('ar', OWNER_CAPS, <WhatsAppLevelDialog member={m} onClose={noop} onDone={noop} />);
    expect(ar).toContain('مستوى واتساب — منى');
    for (const o of ['DEFAULT', 'NONE', 'VIEW', 'REPLY', 'MANAGE']) expect(ar).toContain(`data-wa-level-option="${o}"`);
    expect(ar).toContain('حسب الدور (إدارة)');
    expect(ar).toContain('لا رد ولا استلام');
    expect(ar).toContain('يعيد محادثاته المستلمة');
    expect(ar).toMatch(/type="radio"[^>]*checked=""/);
    const en = wrap('en', OWNER_CAPS, <WhatsAppLevelDialog member={m} onClose={noop} onDone={noop} />);
    expect(en).toContain('By role (Manage)');
    expect(en).toContain('View only');
  });
});

describe('D360 the VIEW-only chat', () => {
  it('the nav shows «واتساب» to VIEW (and its badge), not the quick replies or settings', () => {
    const items = (caps: Capability[]) => visibleNav((c) => caps.includes(c)).flatMap((g) => g.items.map((i) => i.to));
    expect(items(VIEW_CAPS)).toContain('/whatsapp');
    expect(items(VIEW_CAPS)).not.toContain('/whatsapp/quick-replies');
    expect(items(VIEW_CAPS)).not.toContain('/whatsapp/settings');
    expect(items(VIEW_CAPS.filter((c) => c !== 'support.whatsapp.view'))).not.toContain('/whatsapp');
  });

  it('VIEW: «مشاهدة فقط», no claim / transfer / close / reopen, no composer', () => {
    const composer = <WaComposer c={CONV} onSent={noop} />;
    const ar = wrap('ar', VIEW_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={composer} />);
    expect(ar).toContain('data-view-only="true"');
    expect(ar).toContain('مشاهدة فقط');
    expect(ar).toContain('لا يمكنك الرد');
    for (const action of ['استلام المحادثة', 'تحويل', 'إغلاق']) expect(ar).not.toContain(`>${action}<`);
    expect(wrap('ar', REPLY_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={null} />)).toContain('>استلام المحادثة<');
    expect(ar).not.toContain('<textarea');
    const closed = wrap('en', VIEW_CAPS, (
      <WaChatView c={{ ...CONV, status: 'CLOSED' }} messages={[]} onAction={noop} composer={null} />
    ));
    expect(closed).not.toContain('Reopen');
    expect(closed).toContain('View only');
    // REPLY: the same chat has its actions and its composer.
    const reply = wrap('ar', REPLY_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={composer} />);
    expect(reply).not.toContain('data-view-only');
    expect(reply).toContain('<textarea');
    expect(reply).not.toContain('data-wa-view-only');
  });

  it('VIEW: the customer panel reads the account, notes and history, with no link / unlink / note buttons', () => {
    const linked = {
      ...CONV,
      linkedAccount: { userId: 'u1', username: 'sara_9', displayName: 'Sara', avatarUrl: null, status: 'ACTIVE', countryCode: 'SA', createdAt: '2026-01-01T00:00:00.000Z' },
    };
    const notes = [{ id: 'n1', body: 'Waiting for finance', author: null, at: CONV.lastMessageAt }];
    const view = wrap('en', VIEW_CAPS, (
      <WaCustomerPanel c={linked} notes={notes} history={[]} onLink={noop} onUnlink={noop} onNote={noop} />
    ));
    expect(view).toContain('@sara_9');
    expect(view).toContain('Waiting for finance');
    expect(view).not.toContain('Unlink');
    expect(view).not.toContain('Add a note');
    const free = wrap('en', VIEW_CAPS, <WaCustomerPanel c={CONV} notes={[]} history={[]} onLink={noop} onUnlink={noop} onNote={noop} />);
    expect(free).not.toContain('>Link<');
    const reply = wrap('en', REPLY_CAPS, (
      <WaCustomerPanel c={linked} notes={notes} history={[]} onLink={noop} onUnlink={noop} onNote={noop} />
    ));
    expect(reply).toContain('Unlink');
  });
});
