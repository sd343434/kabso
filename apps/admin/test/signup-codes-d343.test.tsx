/**
 * D343 «رمز الدعوة أو رمز المشرف» in the panel: the two new referral reasons «ليس شخصاً جديداً» on «الدعوات», and the
 * OWNER's «التسجيل برمز المشرف» table on «الاستقطاب» — credited or withheld with the reason — in both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D343, EN_D343 } from '../src/i18n-d343';
import { SignupRecruitsTable, type SignupRecruit } from '../src/pages/Recruits';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const person = (id: string, name: string, username: string) => ({
  id,
  displayName: name,
  username,
  avatarUrl: null,
});
const rows: SignupRecruit[] = [
  {
    user: person('u2', 'سامي', 'sami'),
    recruiter: person('s1', 'نور', 'nour.bd'),
    code: 'Kabso07',
    status: 'WITHHELD',
    withholdReason: 'DEVICE_HAD_ACCOUNT',
    createdAt: '2026-11-09T10:00:00.000Z',
  },
  {
    user: person('u1', 'ليلى', 'layla'),
    recruiter: person('s1', 'نور', 'nour.bd'),
    code: 'Kabso07',
    status: 'GRANTED',
    withholdReason: null,
    createdAt: '2026-11-08T10:00:00.000Z',
  },
];

describe('D343 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D343).sort()).toEqual(Object.keys(AR_D343).sort());
    for (const k of Object.keys(AR_D343) as (keyof typeof AR_D343)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D343[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D343[k]);
    }
  });

  it('names the new referral reasons and every withhold reason', () => {
    expect(translate('ar', 'refReasonDEVICE_HAD_ACCOUNT')).toBe('ليس جديداً: الجهاز عليه حساب سابق');
    expect(translate('en', 'refReasonEMAIL_HAD_ACCOUNT')).toBe('Not new: the email was registered before');
    for (const r of ['DEVICE_HAD_ACCOUNT', 'EMAIL_HAD_ACCOUNT', 'RECRUITER_INACTIVE'] as const)
      expect(translate('ar', `signupWithhold${r}`)).not.toBe(`signupWithhold${r}`);
  });
});

describe('D343 «التسجيل برمز المشرف»', () => {
  it('shows each sign-up counted or withheld with the reason (ar)', () => {
    const out = html('ar', <SignupRecruitsTable rows={rows} />);
    expect(out).toContain('data-signup-recruits');
    expect(out).toContain('data-status="WITHHELD"');
    expect(out).toContain('غير مُحتسب');
    expect(out).toContain('الجهاز عليه حساب سابق');
    expect(out).toContain('data-status="GRANTED"');
    expect(out).toContain('مُحتسب');
    expect(out).toContain('Kabso07');
    expect((out.match(/data-withhold-reason/g) ?? []).length).toBe(1);
  });

  it('English, and the empty state', () => {
    const out = html('en', <SignupRecruitsTable rows={rows} />);
    expect(out).toContain('Not counted');
    expect(out).toContain('The device had an account');
    expect(html('en', <SignupRecruitsTable rows={[]} />)).toContain('No sign-ups with a supervisor code yet.');
  });
});
