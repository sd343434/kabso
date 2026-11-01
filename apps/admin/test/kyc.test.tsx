/**
 * D227 «التحقق من الهوية (Didit)»: the OWNER's section and the identity-check block of the application pages, rendered
 * to HTML in Node (no DOM library): the status in plain words, the secrets as last 4 only (empty password inputs), the
 * webhook address, the test's steps with their reasons, the PATCH / test bodies (only what changed; the secrets only
 * when typed), and the block's gate, reasons, duplicate warning and image button by capability, in Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { errorKey } from '../src/errors';
import { ApiError } from '../src/api';
import { translate, type Lang } from '../src/i18n';
import { NAV } from '../src/nav';
import { KycBlock, kycFormOf, kycPatch, KycSettingsView, kycTestBody, reasonText } from '../src/pages/Kyc';
import type { AdminKycCheck, AdminKycSummary, Capability, KycSettings } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, role = 'OWNER'): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (cap: Capability) => (CAPABILITY_ROLES[cap] ?? []).includes(role as never),
  toast: () => undefined,
});

const owner = { id: '0190f3a0-0000-7000-8000-000000000001', displayName: 'المالك' };
const WF = '66666666-7777-4888-9999-000000000000';

function settings(over: Partial<KycSettings> = {}): KycSettings {
  return {
    status: 'active',
    enabled: true,
    apiKey: { last4: 'Ap1k', setBy: owner, setAt: '2026-11-01T09:00:00.000Z' },
    webhookSecret: { last4: 'Wh5s', setBy: owner, setAt: '2026-11-01T09:00:00.000Z' },
    workflowId: WF,
    workflowIdHost: null,
    workflowIdAgency: null,
    workflowIdRecharge: null,
    maxSessionsPerDay: 3,
    missing: [],
    updatedAt: '2026-11-01T09:00:00.000Z',
    panelIgnored: null,
    lastTest: {
      ok: true,
      at: '2026-11-01T09:00:00.000Z',
      apiKeyLast4: 'Ap1k',
      apiKey: { ok: true, issue: null, ms: 40 },
      workflows: [{ field: 'workflowId', workflowId: WF, ok: true, label: 'Kabso KYC', features: 'OCR + LIVENESS + FACE_MATCH', issue: null }],
      by: owner,
    },
    webhookUrl: 'https://api.kabsolive.com/api/v1/kyc/didit/webhook',
    callbackUrl: 'kabsolive://kyc/done',
    consoleUrl: 'https://business.didit.me',
    connectionTestSkippable: false,
    ...over,
  };
}

const view = (data: KycSettings, lang: Lang = 'ar') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <KycSettingsView data={data} onChange={() => undefined} />
    </AppContext.Provider>,
  );

function check(over: Partial<AdminKycCheck> = {}): AdminKycCheck {
  return {
    id: '0190f3a0-0000-7000-8000-0000000000aa',
    purpose: 'HOST_APPLICATION',
    status: 'APPROVED',
    providerStatus: 'Approved',
    reasons: [],
    sessionId: '0190f3a0-0000-7000-8000-0000000000bb',
    sessionNumber: 43762,
    workflowId: WF,
    fullName: 'Noura Al Saud',
    dateOfBirth: '1995-04-02',
    age: 31,
    documentCountry: 'SAU',
    duplicateDocument: false,
    duplicates: [],
    createdAt: '2026-11-01T09:00:00.000Z',
    decidedAt: '2026-11-01T09:05:00.000Z',
    consoleUrl: 'https://business.didit.me',
    ...over,
  };
}

const block = (summary: AdminKycSummary, lang: Lang = 'ar', role = 'SUPPORT') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, role)}>
      <KycBlock summary={summary} />
    </AppContext.Provider>,
  );

describe('KycSettingsView', () => {
  it('Arabic: on, the secrets as last 4 with who, the webhook address, the workflow, the last test', () => {
    const html = view(settings());
    expect(html).toContain('التحقق من الهوية (Didit)');
    expect(html).toContain('مفعّل');
    expect(html).toContain('…\u2068Ap1k\u2069');
    expect(html).toContain('…\u2068Wh5s\u2069');
    expect(html).toContain('⁨المالك⁩');
    expect(html).toContain('https://api.kabsolive.com/api/v1/kyc/didit/webhook');
    expect(html).toContain(`value="${WF}"`);
    expect(html).toContain('value="3"');
    expect(html).toMatch(/role="switch"[^>]*checked=""|checked=""[^>]*role="switch"/);
    expect(html).toContain('ID Verification + Liveness (Passive) + Face Match');
    for (const id of ['kyc-api-key', 'kyc-secret']) {
      const input = html.match(new RegExp(`<input[^>]*id="${id}"[^>]*>`))?.[0] ?? '';
      expect(input, id).toContain('type="password"');
      expect(input, id).toContain('value=""');
      expect(input, id).toMatch(/autocomplete="off"/i);
    }
  });

  it('not configured: what is missing, the switch disabled; a failed test explains why; English', () => {
    const empty = settings({ status: 'not_configured', enabled: false, apiKey: null, webhookSecret: null, workflowId: null, missing: ['apiKey', 'webhookSecret', 'workflowId'], lastTest: null });
    const ar = view(empty);
    expect(ar).toContain('غير مُعدّ');
    expect(ar).toContain('مفتاح API، سر الـ Webhook (Webhook Secret Key)، معرّف سير العمل الافتراضي (Workflow ID)');
    expect(ar).toMatch(/<input[^>]*role="switch"[^>]*disabled=""/);
    expect(ar).not.toContain('حذف إعدادات Didit');
    const failed = view(
      settings({
        lastTest: { ok: false, at: '2026-11-01T09:00:00.000Z', apiKeyLast4: 'Ap1k', apiKey: { ok: false, issue: 'bad_api_key', ms: 30 }, workflows: [{ field: 'workflowId', workflowId: WF, ok: false, label: null, features: null, issue: 'bad_api_key' }], by: owner },
      }),
    );
    expect(failed).toContain('رفض Didit المفتاح (خاطئ أو ملغى).');
    const en = view(empty, 'en');
    expect(en).toContain('Not configured');
    expect(en).toContain('Identity verification (Didit)');
  });

  it('builds only what changed; the secrets only when typed; the test body from what is typed', () => {
    const data = settings();
    const form = kycFormOf(data);
    expect(form.apiKey).toBe('');
    expect(kycPatch(form, data)).toEqual({});
    expect(kycPatch({ ...form, apiKey: ' new-key-value-000001 ', workflowIdAgency: WF.toUpperCase(), maxSessionsPerDay: 5 }, data)).toEqual({
      apiKey: 'new-key-value-000001',
      workflowIdAgency: WF,
      maxSessionsPerDay: 5,
    });
    expect(kycPatch({ ...form, workflowId: '' }, data)).toEqual({ workflowId: null });
    expect(kycTestBody({ ...form, apiKey: 'typed-key-000000001' })).toEqual({ apiKey: 'typed-key-000000001', workflowId: WF });
  });

  it('the section is OWNER only in the menu; the refusals are worded', () => {
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === '/kyc-settings');
    expect(item?.cap).toBe('kyc.settings');
    expect(CAPABILITY_ROLES['kyc.settings']).toEqual(['OWNER']);
    expect(CAPABILITY_ROLES['kyc.view']).toEqual(['OWNER', 'SUPPORT']);
    const refusal = (issue: string) => new ApiError(409, 'ADMIN_ACTION_REFUSED', 'x', null, [{ field: 'kyc', issue }]);
    expect(errorKey(refusal('kyc_required')).key).toBe('kycErrRequired');
    expect(errorKey(refusal('kyc_test_failed')).key).toBe('kycErrTestFailed');
  });
});

describe('KycBlock (the application pages)', () => {
  const required = (over: Partial<AdminKycSummary>): AdminKycSummary => ({ enabled: true, required: true, satisfied: false, workflowId: WF, approved: null, latest: null, ...over });

  it('approved: the gate passes, the minimum shown, the images button and Didit’s console for kyc.view', () => {
    const html = block(required({ satisfied: true, approved: check(), latest: check() }));
    expect(html).toContain('هوية مؤكدة');
    expect(html).toContain('Noura Al Saud');
    expect(html).toContain('1995-04-02');
    expect(html).toContain('SAU');
    expect(html).toContain('#43762');
    expect(html).toContain('عرض الصور');
    expect(html).toContain('https://business.didit.me');
    expect(html).not.toContain('<img');
  });

  it('declined with reasons and a duplicate document; MODERATION sees no image button', () => {
    const c = check({
      status: 'DECLINED',
      reasons: ['LIVENESS_FACE_ATTACK', 'SOMETHING_NEW'],
      duplicateDocument: true,
      duplicates: [{ id: '0190f3a0-0000-7000-8000-0000000000cc', username: 'other', displayName: 'Other' }],
    });
    const html = block(required({ latest: c }), 'ar', 'MODERATION');
    expect(html).toContain('لا يوجد تحقق مقبول');
    expect(html).toContain('مرفوض');
    expect(html).toContain('محاولة تحايل على فحص الحيوية');
    expect(html).toContain('SOMETHING_NEW');
    expect(html).toContain('@other');
    expect(html).not.toContain('عرض الصور');
    const en = block(required({ latest: c }), 'en');
    expect(en).toContain('No approved check');
    expect(en).toContain('An attempt to trick the liveness check');
  });

  it('Didit off and nothing started; absent summary renders nothing', () => {
    const html = block({ enabled: false, required: false, satisfied: false, workflowId: null, approved: null, latest: null });
    expect(html).toContain('Didit متوقف');
    expect(html).toContain('لم يبدأ الشخص أي تحقق بعد.');
    expect(renderToStaticMarkup(<AppContext.Provider value={state('ar')}><KycBlock summary={undefined} /></AppContext.Provider>)).toBe('');
    expect(reasonText((k) => translate('en', k), 'UNDER_MIN_AGE')).toBe('Under 18 according to the document');
  });
});
