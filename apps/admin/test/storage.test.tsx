/**
 * D222 «التخزين (R2 / S3)»: the section's component, rendered to HTML in Node (no DOM library): the status in plain
 * words, the keys as last 4 only (never a value; empty password inputs), the R2 endpoint derived from the account id,
 * the steps of a test with their reasons in Arabic, the switch, the server fallback, and the PATCH / test bodies it
 * builds (only what changed; the keys only when typed).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { NAV } from '../src/nav';
import { storageFormOf, storagePatch, StorageView, testBody, TestSteps } from '../src/pages/Storage';
import type { StorageSettings, StorageTestReport } from '../src/types';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const owner = { id: '0190f3a0-0000-7000-8000-000000000001', displayName: 'المالك' };
const ACCOUNT = '0123456789abcdef0123456789abcdef';

const target = {
  provider: 'R2' as const,
  accountId: ACCOUNT,
  endpoint: `https://${ACCOUNT}.r2.cloudflarestorage.com`,
  region: 'auto',
  forcePathStyle: false,
  publicBucket: 'kabso-media',
  publicBaseUrl: 'https://media.kabsolive.com',
  privateBucket: 'kabso-private',
};

function report(over: Partial<StorageTestReport> = {}): StorageTestReport {
  const ok = (bucket: 'public' | 'private', step: StorageTestReport['steps'][number]['step']) => ({ bucket, step, ok: true, ms: 12, issue: null, detail: null });
  return {
    ok: true,
    at: '2026-11-01T09:00:00.000Z',
    target,
    accessKeyIdLast4: 'Ak1d',
    steps: [
      ok('public', 'put'),
      ok('public', 'head'),
      ok('public', 'get'),
      ok('public', 'public_read'),
      ok('public', 'delete'),
      ok('private', 'put'),
      ok('private', 'head'),
      ok('private', 'get'),
      ok('private', 'not_public'),
      ok('private', 'delete'),
    ],
    ...over,
  };
}

function fixture(over: Partial<StorageSettings> = {}, panel: Partial<StorageSettings['panel']> = {}): StorageSettings {
  return {
    status: 'active',
    source: 'panel',
    uploadsEnabled: true,
    publicBaseUrl: 'https://media.kabsolive.com',
    enabled: true,
    panel: {
      ...target,
      accessKeyId: { last4: 'Ak1d', setBy: owner, setAt: '2026-11-01T09:00:00.000Z' },
      secretAccessKey: { last4: 'Sc4t', setBy: owner, setAt: '2026-11-01T09:00:00.000Z' },
      missing: [],
      updatedAt: '2026-11-01T09:00:00.000Z',
      ...panel,
    },
    env: { configured: false, uploadsEnabled: false, endpoint: null, region: 'auto', bucket: null, publicBaseUrl: null, accessKeyIdLast4: null },
    panelIgnored: null,
    lastTest: { ...report(), by: owner },
    publicPrefix: 'media/',
    healthcheckPrefix: '_healthcheck/',
    connectionTestSkippable: false,
    ...over,
  };
}

const render = (data: StorageSettings, lang: Lang = 'ar') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <StorageView data={data} onChange={() => undefined} />
    </AppContext.Provider>,
  );

describe('StorageView', () => {
  it('Arabic: on, the keys as last 4 with who, the buckets, the derived R2 endpoint, the last test', () => {
    const html = render(fixture());
    expect(html).toContain('التخزين (R2 / S3)');
    expect(html).toContain('مفعّل');
    expect(html).toContain('الرفع يعمل الآن بإعدادات هذه الصفحة.');
    expect(html).toContain('محفوظ: …Ak1d — \u2068المالك\u2069');
    expect(html).toContain('محفوظ: …Sc4t — \u2068المالك\u2069');
    expect(html).toContain('value="kabso-media"');
    expect(html).toContain('value="kabso-private"');
    expect(html).toContain('value="https://media.kabsolive.com"');
    expect(html).toContain(`https://${ACCOUNT}.r2.cloudflarestorage.com`);
    expect(html).toContain('نجح');
    expect(html).toMatch(/role="switch"[^>]*checked=""|checked=""[^>]*role="switch"/);
    expect(html).toContain('إزالة إعدادات اللوحة');
    expect(html).toContain('Object Read &amp; Write');
  });

  it('the key inputs are empty password fields without autocomplete', () => {
    const html = render(fixture());
    for (const id of ['st-akid', 'st-secret']) {
      const input = html.match(new RegExp(`<input[^>]*id="${id}"[^>]*>`))?.[0] ?? '';
      expect(input, id).toContain('type="password"');
      expect(input, id).toMatch(/autocomplete="off"/i);
      expect(input, id).toContain('value=""');
    }
  });

  it('not configured: 503 said plainly, the switch disabled with what is missing; English too', () => {
    const empty = fixture(
      { status: 'not_configured', source: 'none', uploadsEnabled: false, publicBaseUrl: null, enabled: false, lastTest: null },
      { accountId: null, endpoint: null, publicBucket: null, publicBaseUrl: null, privateBucket: null, accessKeyId: null, secretAccessKey: null, missing: ['accountId', 'accessKeyId', 'secretAccessKey', 'publicBucket', 'publicBaseUrl', 'privateBucket'] },
    );
    const ar = render(empty);
    expect(ar).toContain('غير مُعدّ');
    expect(ar).toContain('«التخزين غير مفعّل»');
    expect(ar).toContain('متوقف (503)');
    expect(ar).toContain('ينقص قبل التفعيل: معرّف الحساب، معرّف المفتاح، المفتاح السري، الحاوية العامة، الرابط العام، الحاوية الخاصة');
    expect(ar).toMatch(/<input[^>]*role="switch"[^>]*disabled=""/);
    expect(ar).toContain('غير محفوظ');
    expect(ar).toContain('لم يُجرَ اختبار بعد.');
    expect(ar).not.toContain('إزالة إعدادات اللوحة');
    const en = render(empty, 'en');
    expect(en).toContain('Not configured');
    expect(en).toContain('Missing before it can be turned on: account id, access key id, secret, public bucket, public URL, private bucket');
  });

  it('the server fallback and an unreadable panel are shown; generic S3 shows endpoint, region, path style', () => {
    const env = render(fixture({ status: 'env', source: 'env', enabled: false, env: { configured: true, uploadsEnabled: true, endpoint: 'https://s3.example.test', region: 'auto', bucket: 'kabso-media-staging', publicBaseUrl: 'https://cdn.example.test', accessKeyIdLast4: 'Env1' } }));
    expect(env).toContain('من إعدادات الخادم');
    expect(env).toContain('kabso-media-staging');
    expect(env).toContain('…Env1');
    expect(render(fixture({ panelIgnored: 'unreadable' }))).toContain('ADMIN_TOTP_KEY');
    const s3 = render(fixture({}, { provider: 'S3', accountId: null, endpoint: 'http://127.0.0.1:9000', region: 'us-east-1', forcePathStyle: true }));
    expect(s3).toContain('value="http://127.0.0.1:9000"');
    expect(s3).toContain('value="us-east-1"');
    expect(s3).toContain('path-style');
    expect(s3).not.toContain('id="st-account"');
  });

  it('a failed test names the step and the reason in Arabic', () => {
    const failed = report({
      ok: false,
      steps: [
        { bucket: 'public', step: 'put', ok: true, ms: 10, issue: null, detail: null },
        { bucket: 'public', step: 'public_read', ok: false, ms: 30, issue: 'not_public', detail: 'HTTP 404' },
        { bucket: 'private', step: 'not_public', ok: false, ms: 20, issue: 'publicly_readable', detail: 'pub-x.r2.dev' },
        { bucket: 'private', step: 'put', ok: false, ms: 5, issue: 'access_denied', detail: 'AccessDenied' },
      ],
    });
    const html = renderToStaticMarkup(
      <AppContext.Provider value={state('ar')}>
        <TestSteps report={failed} />
      </AppContext.Provider>,
    );
    expect(html).toContain('قراءته من الرابط العام');
    expect(html).toContain('الرابط العام لا يعرض الحاوية العامة');
    expect(html).toContain('خطر: الحاوية الخاصة مقروءة بدون مفتاح!');
    expect(html).toContain('المفتاح لا يملك صلاحية');
    expect(html).toContain('HTTP 404');
    // The status card repeats a failed last test.
    expect(render(fixture({ lastTest: { ...failed, by: owner } }))).toContain('فشل');
  });

  it('the section is in the settings group for storage.settings', () => {
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === '/storage');
    expect(item).toMatchObject({ cap: 'storage.settings', key: 'navStorage' });
  });
});

describe('the bodies', () => {
  it('PATCH: only what changed; keys only when typed; account id lower-cased; base URL without a trailing slash', () => {
    const data = fixture();
    const form = storageFormOf(data);
    expect(form.accessKeyId).toBe('');
    expect(storagePatch(form, data)).toEqual({});
    expect(storagePatch({ ...form, secretAccessKey: ' newsecret ', publicBaseUrl: 'https://cdn.kabsolive.com/' }, data)).toEqual({
      secretAccessKey: 'newsecret',
      publicBaseUrl: 'https://cdn.kabsolive.com',
    });
    expect(storagePatch({ ...form, accountId: ACCOUNT.toUpperCase() }, data)).toEqual({});
    expect(storagePatch({ ...form, privateBucket: '' }, data)).toEqual({ privateBucket: null });
    expect(storagePatch({ ...form, provider: 'S3', endpoint: 'http://127.0.0.1:9000', region: 'us-east-1', forcePathStyle: true }, data)).toEqual({
      provider: 'S3',
      endpoint: 'http://127.0.0.1:9000',
      region: 'us-east-1',
      forcePathStyle: true,
    });
  });

  it('test: everything typed (the saved keys are used when left empty)', () => {
    const form = storageFormOf(fixture());
    expect(testBody(form)).toEqual({
      provider: 'R2',
      accountId: ACCOUNT,
      publicBucket: 'kabso-media',
      publicBaseUrl: 'https://media.kabsolive.com',
      privateBucket: 'kabso-private',
    });
    expect(testBody({ ...form, accessKeyId: 'AKID12345678' })).toMatchObject({ accessKeyId: 'AKID12345678' });
  });
});
