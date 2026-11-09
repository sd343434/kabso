import { afterAll, describe, expect, it } from 'vitest';
import { TestPki } from '../../../test/helpers/fake-stores.js';
import { loadStoreClients, StoreCredentialError } from './store-clients.js';

/** D345 (§10.144.1): the credential files are read at boot; a bad file stops the boot; nothing configured = off. */
describe('loadStoreClients', () => {
  const pki = new TestPki();
  afterAll(() => pki.cleanup());
  const base = { acceptSandbox: true, voidedPollHours: 24, sweepIntervalSeconds: 0, consentVersion: 'v' };

  it('is off when nothing is configured', () => {
    expect(loadStoreClients({ ...base, google: null, apple: null })).toEqual({ google: null, apple: null });
  });

  it('builds both stores from valid files', () => {
    const sa = pki.file(
      'sa.json',
      JSON.stringify({ client_email: 'kabso@example.iam.gserviceaccount.com', private_key: pki.key('rsa') }),
    );
    const p8 = pki.file('key.p8', pki.key('ec'));
    const root = pki.file('root.pem', pki.chain('boot').rootPem);
    const clients = loadStoreClients({
      ...base,
      google: { packageName: 'com.kabso.live', serviceAccountFile: sa, rtdnToken: null },
      apple: {
        bundleId: 'com.kabso.live',
        issuerId: '57246542-96fe-1a63-e053-0824d011072a',
        keyId: 'ABCDEFGHIJ',
        privateKeyFile: p8,
        rootCertFiles: [root],
        appAppleId: null,
      },
    });
    expect(clients.google).not.toBeNull();
    expect(clients.apple?.roots).toHaveLength(1);
  });

  it('refuses unreadable or wrong-kind credentials without printing them', () => {
    const google = (file: string) => () =>
      loadStoreClients({
        ...base,
        apple: null,
        google: { packageName: 'com.kabso.live', serviceAccountFile: file, rtdnToken: null },
      });
    expect(google('/nonexistent/sa.json')).toThrow(StoreCredentialError);
    expect(google(pki.file('bad.json', '{"client_email":"x"}'))).toThrow(/client_email/);
    const ecKey = pki.key('ec');
    const wrong = pki.file('ec.json', JSON.stringify({ client_email: 'x@y', private_key: ecKey }));
    expect(google(wrong)).toThrow(/not RSA/);
    try {
      google(wrong)();
    } catch (err) {
      expect(String(err)).not.toContain('PRIVATE KEY');
    }
    const apple = (keyFile: string, roots: string[]) => () =>
      loadStoreClients({
        ...base,
        google: null,
        apple: {
          bundleId: 'com.kabso.live',
          issuerId: '57246542-96fe-1a63-e053-0824d011072a',
          keyId: 'ABCDEFGHIJ',
          privateKeyFile: keyFile,
          rootCertFiles: roots,
          appAppleId: null,
        },
      });
    expect(apple(pki.file('rsa.p8', pki.key('rsa')), [])).toThrow(/not an EC key/);
    expect(apple(pki.file('ok.p8', pki.key('ec')), [pki.file('junk.cer', 'junk')])).toThrow(
      /unreadable certificate/,
    );
  });
});
