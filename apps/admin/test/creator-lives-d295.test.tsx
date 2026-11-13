/**
 * D295 (owner 2026-11-06, CONVENTIONS §10.108) in the panel: the creators list shows the source and «فعّله وكيل: …» with
 * the revoke and (OWNER) ban actions; the ban confirmation shows the amount to be forfeited before confirming; the host
 * grant's refusal of a creator is worded; the capability is OWNER only; both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { ApiError } from '../src/api';
import { AppContext, type AppState } from '../src/context';
import { errorKey } from '../src/errors';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D295, EN_D295 } from '../src/i18n-d295';
import { AgencyBanFigures, banBody, banFigureRows, type AgencyBanPreview } from '../src/pages/AgencyBan';
import { CreatorActivatedBy, type CreatorApp } from '../src/pages/Recruits';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const state = (lang: Lang, role: PanelRole = 'OWNER'): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: {
      id: 'self',
      email: 'o@kabso.test',
      username: 'o',
      displayName: 'O',
    },
    roles: [role],
    capabilities: capsOf(role),
    csrfToken: 'csrf',
    expiresAt: '2026-11-06T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, role: PanelRole = 'OWNER') =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);

const preview: AgencyBanPreview = {
  agencyId: '11111111-1111-4111-8111-111111111111',
  status: 'OPEN',
  ban: null,
  commissionCherries: 1_177_500,
  balanceCherries: 268_410,
  lockedCherries: 0,
  heldCherries: 909_090,
  forfeitCherries: 268_410,
  creators: [
    {
      id: '22222222-2222-4222-8222-222222222222',
      username: 'creator_one',
      displayName: 'سارة',
      avatarUrl: null,
      applicationId: '33333333-3333-4333-8333-333333333333',
      activatedAt: '2026-11-06T09:00:00.000Z',
    },
  ],
};

const agencyApp: CreatorApp = {
  id: '44444444-4444-4444-8444-444444444444',
  status: 'APPROVED',
  country: 'EG',
  category: 'COMEDY',
  links: ['https://www.tiktok.com/@c'],
  bio: null,
  recruiter: null,
  createdAt: '2026-11-06T09:00:00.000Z',
  rejectReason: null,
  source: 'AGENCY',
  revokedAt: null,
  memberActive: true,
  activatedBy: {
    agencyId: preview.agencyId,
    agencyName: 'وكالة النجوم',
    inviteCode: 'ABCD1234',
    hostCode: 'host07',
    owner: {
      id: '55555555-5555-4555-8555-555555555555',
      username: 'agent7',
      displayName: 'أحمد',
    },
  },
  revokeReason: null,
  revokedBy: null,
  user: {
    id: '22222222-2222-4222-8222-222222222222',
    username: 'creator_one',
    displayName: 'سارة',
  },
};

describe('D295 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D295).sort()).toEqual(Object.keys(AR_D295).sort());
    for (const k of Object.keys(AR_D295) as (keyof typeof AR_D295)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D295[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D295[k]);
    }
    expect(AR_D295.agencyBan).toBe('حظر الوكالة — تفعيل صانع محتوى وهمي');
  });
});

describe('D295 capabilities', () => {
  it('the agency ban is OWNER only', () => {
    expect(CAPABILITY_ROLES['agencies.ban']).toEqual(['OWNER']);
    expect(capsOf('SUPPORT')).not.toContain('agencies.ban');
    expect(capsOf('OWNER')).toContain('agencies.ban');
  });
});

describe('D295 «فعّله وكيل: …»', () => {
  it('names the agent and links the agency, in both languages; nothing for an own application', () => {
    const ar = html('ar', <CreatorActivatedBy app={agencyApp} />);
    expect(ar).toContain('فعّله وكيل: أحمد (@agent7)');
    expect(ar).toContain('href="/agencies/11111111-1111-4111-8111-111111111111"');
    expect(ar).toContain('host07');
    const en = html('en', <CreatorActivatedBy app={agencyApp} />);
    expect(en).toContain('Activated by agent: أحمد (@agent7)');
    expect(
      html('ar', <CreatorActivatedBy app={{ ...agencyApp, activatedBy: null, source: 'APPLICATION' }} />),
    ).toBe('');
  });
});

describe('D295 the ban confirmation shows the amount first', () => {
  it('lists the commission, balance, locked, held and the amount to forfeit (last, emphasised)', () => {
    expect(banFigureRows(preview).map((r) => r.key)).toEqual([
      'agencyBanCommission',
      'agencyBanBalance',
      'agencyBanLocked',
      'agencyBanHeld',
      'agencyBanForfeit',
    ]);
    const ar = html('ar', <AgencyBanFigures preview={preview} />);
    expect(ar).toContain('سيُخصم من الوكيل');
    expect(ar).toMatch(/data-figure="agencyBanForfeit"><strong>[^<]*268/);
    expect(ar).toContain('لا يُسترجع ما سُحب');
    expect(ar).toContain('data-ban-creator="22222222-2222-4222-8222-222222222222"');
    const en = html('en', <AgencyBanFigures preview={{ ...preview, creators: [] }} />);
    expect(en).toContain('To be forfeited');
    expect(en).toContain('This agency activated no creator.');
    expect(en).toContain('Money already withdrawn is not taken back');
  });
});

describe('D295 the ban revokes only the creators ticked as fake (owner 2026-11-06)', () => {
  const second = { ...preview.creators[0]!, id: '66666666-6666-4666-8666-666666666666', username: 'genuine' };
  const two = { ...preview, creators: [preview.creators[0]!, second] };
  it('lists every creator the agency activated with a checkbox, none pre-selected', () => {
    const ar = html('ar', <AgencyBanFigures preview={two} />);
    expect(ar.match(/data-ban-tick=/g)).toHaveLength(2);
    expect(ar).not.toMatch(/checked=""/);
    expect(ar).toContain('data-ban-ticked="0"');
    expect(ar).toContain('ضع علامة على الوهميين فقط');
    expect(html('en', <AgencyBanFigures preview={two} />)).toContain('Tick only the fake ones');
  });
  it('shows the ticked one checked and counts it', () => {
    const out = html('en', <AgencyBanFigures preview={two} ticked={new Set([second.id])} />);
    expect(out).toContain('data-ban-ticked="1"');
    expect(out).toContain('Ticked as fake: 1');
    expect(out.match(/checked=""/g)).toHaveLength(1);
  });
  it('sends exactly the ticked creators — an empty list when none is ticked', () => {
    const v = { reason: 'تفعيل صانع محتوى وهمي', totpCode: '123456' };
    expect(banBody(v, new Set())).toEqual({ ...v, fakeCreatorUserIds: [] });
    expect(banBody(v, new Set([second.id]))).toEqual({ ...v, fakeCreatorUserIds: [second.id] });
  });
});

describe('D295 refusals', () => {
  it('words the host grant of a creator and the creator approval of a host', () => {
    const err = (issue: string) =>
      new ApiError(409, 'ADMIN_ACTION_REFUSED', 'x', null, [{ field: 'user', issue }]);
    expect(errorKey(err('CREATOR')).key).toBe('d295ErrCreator');
    expect(errorKey(err('HOST')).key).toBe('d295ErrHost');
  });
});
