/**
 * D388 (owner 2026-11-13; CONVENTIONS §10.177): «سؤال اللغة» in the panel — rendered to HTML in Node: the customer's
 * language tag on the inbox rows and in the chat head (nothing until they answer), the inbox's language filter, and the
 * staff card's languages with their dialog. Both languages.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D388, EN_D388 } from '../src/i18n-d388';
import {
  MemberCard,
  WaLanguagesDialog,
  type Member,
  type TeamWaDepartments,
  type TeamWaLanguages,
  type TeamWhatsApp,
} from '../src/pages/Team';
import { LanguageFilter, WaChatView, WaConversationList } from '../src/pages/WhatsApp';
import type { Capability, WaConversation } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const OWNER_CAPS = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes('OWNER'));

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

const DEPTS: TeamWaDepartments = { departments: ['GENERAL'], isDefault: true };
const member = (
  wa: TeamWhatsApp,
  langs: TeamWaLanguages,
): Member & { whatsapp: TeamWhatsApp; whatsappDepartments: TeamWaDepartments; whatsappLanguages: TeamWaLanguages } => ({
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
  whatsappDepartments: DEPTS,
  whatsappLanguages: langs,
});
const REPLY: TeamWhatsApp = { level: 'REPLY', setLevel: null, defaultLevel: 'REPLY', locked: false };


describe('D388 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D388).sort()).toEqual(Object.keys(AR_D388).sort());
    for (const k of Object.keys(AR_D388) as (keyof typeof AR_D388)[]) {
      expect(EN_D388[k], k).toBeTruthy();
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D388[k]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D388[k]);
    }
    expect(AR_D388.waLangAR).toBe('عربي');
    expect(EN_D388.waLangAR).toBe('Arabic');
  });
});

describe('D388 the inbox', () => {
  it('rows and the chat head carry the language; none until the customer answers', () => {
    const list = wrap('ar', OWNER_CAPS, (
      <WaConversationList
        items={[
          { ...CONV, language: 'AR' },
          { ...CONV, id: 'c2', language: 'EN' },
          { ...CONV, id: 'c3', language: null },
          { ...CONV, id: 'c4' },
        ]}
        selected={null}
        onOpen={noop}
      />
    ));
    expect(list.match(/data-wa-language="AR"/g)).toHaveLength(1);
    expect(list.match(/data-wa-language="EN"/g)).toHaveLength(1);
    expect(list.match(/data-wa-language=/g)).toHaveLength(2);
    expect(list).toContain('>عربي<');
    expect(list).toContain('>English<');
    const chat = wrap('en', OWNER_CAPS, (
      <WaChatView c={{ ...CONV, language: 'AR' }} messages={[]} onAction={noop} composer={null} />
    ));
    expect(chat).toContain('data-wa-language="AR"');
    expect(chat).toContain('>Arabic<');
    expect(wrap('en', OWNER_CAPS, <WaChatView c={CONV} messages={[]} onAction={noop} composer={null} />)).not.toContain(
      'data-wa-language=',
    );
  });

  it('the language filter: all, then Arabic and English', () => {
    const html = wrap('ar', OWNER_CAPS, <LanguageFilter value="EN" onChange={noop} />);
    expect(html).toContain('data-wa-language-filter');
    expect(html).toContain('اللغة');
    expect(html).toContain('كل اللغات');
    const opts = [...html.matchAll(/<option value="([A-Z]*)"/g)].map((m) => m[1]);
    expect(opts).toEqual(['', 'AR', 'EN']);
    expect(html).toMatch(/<option value="EN" selected="">English<\/option>/);
  });
});

describe('D388 the staff card', () => {
  it('shows the languages (both by default) with the change button for REPLY+', () => {
    const ar = wrap('ar', OWNER_CAPS, (
      <MemberCard
        m={member(REPLY, { languages: ['AR', 'EN'], isDefault: true })}
        selfId="self"
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
        onWhatsApp={noop}
        onWaLanguages={noop}
      />
    ));
    expect(ar).toContain('لغات واتساب');
    expect(ar).toContain('data-wa-languages="AR,EN"');
    expect(ar).toContain('data-wa-languages-default="true"');
    expect(ar).toContain('تغيير اللغات');
    // Under the departments.
    expect(ar.indexOf('أقسام واتساب')).toBeLessThan(ar.indexOf('لغات واتساب'));
    const en = wrap('en', OWNER_CAPS, (
      <MemberCard
        m={member(REPLY, { languages: ['EN'], isDefault: false })}
        selfId="self"
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
        onWaLanguages={noop}
      />
    ));
    expect(en).toContain('data-wa-languages="EN"');
    expect(en).toContain('data-wa-languages-default="false"');
    // VIEW: no change, the note why.
    const view = wrap('ar', OWNER_CAPS, (
      <MemberCard
        m={member({ ...REPLY, level: 'VIEW', setLevel: 'VIEW' }, { languages: ['AR', 'EN'], isDefault: true })}
        selfId="self"
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
        onWaLanguages={noop}
      />
    ));
    expect(view).not.toContain('data-edit-wa-languages');
    expect(view).toContain('اللغات لمن مستواه في واتساب');
  });

  it('the dialog: both languages as checkboxes, the picked ones checked, the reason and the code', () => {
    const html = wrap('ar', OWNER_CAPS, (
      <WaLanguagesDialog member={member(REPLY, { languages: ['EN'], isDefault: false })} onClose={noop} onDone={noop} />
    ));
    expect(html).toContain('لغات واتساب — منى');
    expect(html).toContain('data-wa-language-option="AR"');
    expect(html).toContain('data-wa-language-option="EN"');
    expect(html.match(/checked=""/g)).toHaveLength(1);
  });
});
