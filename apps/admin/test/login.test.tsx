/**
 * D249 the sign-in page's split card, rendered to HTML in Node (no DOM library): every step (password, the TOTP code,
 * the enrolment, the recovery codes) sits in the same shell — the form first (the reading-start side), then the Kabi
 * panel with the slogan; labelled fields, the password eye, the language / theme tools at the bottom, and no control
 * the admin API does not have (no «remember me», «forgot password» or third-party sign-in).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D249, EN_D249 } from '../src/i18n-d249';
import { Login, type LoginStep } from '../src/pages/Login';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

function render(lang: Lang, initialStep?: LoginStep): string {
  return renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <Login onSignedIn={() => undefined} tools={<button data-testid="tool">tool</button>} initialStep={initialStep} />
    </AppContext.Provider>,
  );
}

/** The parts every step shares. */
function expectShell(html: string, lang: Lang): void {
  const t = (k: keyof typeof AR_D249) => (lang === 'ar' ? AR_D249[k] : EN_D249[k]);
  expect(html).toContain('class="auth"');
  expect(html).toContain('data-testid="auth-card"');
  expect(html).toContain(translate(lang, 'appName'));
  // The owner's logo (not the old «K» placeholder) above the panel's name.
  expect(html).toMatch(/<img class="auth-logo" src="[^"]*kabso_logo[^"]*\.webp" alt=""/);
  expect(html).not.toContain('brand-mark');
  expect(html.indexOf('class="auth-logo"')).toBeLessThan(html.indexOf(translate(lang, 'appName')));
  expect(html).toMatch(/<img class="art-kabi" src="[^"]*kabi_win[^"]*\.png" alt=""/);
  expect(html).toContain(t('loginSlogan1'));
  expect(html).toContain(t('loginSlogan2'));
  // The form comes first in the DOM (the right in Arabic RTL), the art panel after it; the tools sit in the form.
  expect(html.indexOf('class="auth-form"')).toBeLessThan(html.indexOf('class="auth-art"'));
  expect(html.indexOf('data-testid="tool"')).toBeLessThan(html.indexOf('class="auth-art"'));
  expect(html.indexOf('class="auth-tools"')).toBeGreaterThan(html.indexOf('class="auth-inner"'));
}

describe('D249 sign-in split card', () => {
  it('password step (ar): welcome title, the subtitle, labelled fields, the eye, the red «دخول», no fake controls', () => {
    const html = render('ar');
    expectShell(html, 'ar');
    expect(html).toContain('<h1>مرحباً بعودتك</h1>');
    expect(html).toContain('للفريق فقط. كل دخول وكل إجراء مسجَّل.');
    expect(html).toContain('<label for="email">البريد الإلكتروني</label>');
    expect(html).toContain('<label for="password">كلمة المرور</label>');
    expect(html).toMatch(/<input id="password" type="password"[^>]*autoComplete="current-password"/i);
    expect(html).toMatch(/<button type="button" class="pw-toggle" aria-controls="password" aria-pressed="false" aria-label="إظهار"/);
    expect(html).toMatch(/<button class="btn primary auth-submit" disabled="">دخول<\/button>/);
    for (const fake of ['تذكرني', 'نسيت', 'Google', 'remember', 'forgot']) expect(html.toLowerCase()).not.toContain(fake.toLowerCase());
    expect(html).not.toContain('id="code"');
  });

  it('password step (en): English copy in the same shell', () => {
    const html = render('en');
    expectShell(html, 'en');
    expect(html).toContain('<h1>Welcome back</h1>');
    expect(html).toContain('Stream. Engage.');
    expect(html).toContain('Grow.');
    expect(html).toContain('aria-label="Show"');
  });

  it('TOTP step: the same shell with the 6-digit code field, «تحقق» and the recovery switch', () => {
    const html = render('ar', { kind: 'verify', recovery: false });
    expectShell(html, 'ar');
    expect(html).toContain(`<h1>${translate('ar', 'verifyTitle')}</h1>`);
    expect(html).toContain(translate('ar', 'verifySubtitle'));
    expect(html).toContain(`<label for="code">${translate('ar', 'totpCode')}</label>`);
    expect(html).toMatch(/<input id="code" type="text" class="code-input" inputMode="numeric" autoComplete="one-time-code" maxLength="6"/i);
    expect(html).toContain(translate('ar', 'verify'));
    expect(html).toContain(translate('ar', 'useRecovery'));
    expect(html).not.toContain('id="password"');
    expect(html).not.toContain('مرحباً بعودتك');
  });

  it('TOTP step with a recovery code: the shell and the recovery field', () => {
    const html = render('en', { kind: 'verify', recovery: true });
    expectShell(html, 'en');
    expect(html).toContain(`<label for="code">${translate('en', 'recoveryCode')}</label>`);
    expect(html).toContain(translate('en', 'useTotp'));
  });

  it('enrolment and recovery codes: the same shell', () => {
    const enrol = render('ar', { kind: 'enrol', secret: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567', uri: 'otpauth://totp/Kabso:a?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567' });
    expectShell(enrol, 'ar');
    expect(enrol).toContain(`<h1>${translate('ar', 'enrolTitle')}</h1>`);
    expect(enrol).toContain('data-testid="totp-secret"');
    const session = { csrfToken: 'x' } as never;
    const codes = render('ar', { kind: 'codes', codes: ['AAAA-BBBB', 'CCCC-DDDD'], session });
    expectShell(codes, 'ar');
    expect(codes).toContain(`<h1>${translate('ar', 'recoveryTitle')}</h1>`);
    expect(codes).toContain('AAAA-BBBB');
  });

  it('Arabic and English keys match and differ', () => {
    expect(Object.keys(EN_D249).sort()).toEqual(Object.keys(AR_D249).sort());
    for (const k of Object.keys(AR_D249) as (keyof typeof AR_D249)[]) expect(EN_D249[k]).not.toBe(AR_D249[k]);
  });
});
