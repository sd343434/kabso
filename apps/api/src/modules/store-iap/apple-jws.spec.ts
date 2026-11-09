import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { signJws, TestPki, type Chain } from '../../../test/helpers/fake-stores.js';
import { AppleJwsError, verifyAppleJws } from './apple-jws.js';

/** D345 (§10.144.3): the App Store's signed data is verified locally against the configured root. */
describe('verifyAppleJws', () => {
  const pki = new TestPki();
  let apple: Chain;
  let rogue: Chain;
  let unmarked: Chain;
  beforeAll(() => {
    apple = pki.chain('apple');
    rogue = pki.chain('rogue');
    unmarked = pki.chain('unmarked', false);
  });
  afterAll(() => pki.cleanup());

  const payload = { transactionId: '2000000123', bundleId: 'com.kabso.live', signedDate: Date.now() };
  const issue = (fn: () => unknown) => {
    try {
      fn();
    } catch (err) {
      expect(err).toBeInstanceOf(AppleJwsError);
      return (err as AppleJwsError).issue;
    }
    return 'accepted';
  };

  it('accepts a payload signed by a leaf that chains to the configured root', () => {
    expect(verifyAppleJws(signJws(apple, payload), [apple.root])).toMatchObject(payload);
  });

  it('refuses a chain to another root, a tampered payload, a missing marker OID and a wrong alg', () => {
    expect(issue(() => verifyAppleJws(signJws(rogue, payload), [apple.root]))).toBe('root');
    // A foreign leaf placed in front of Apple's intermediate and root: the chain does not verify.
    const spliced = signJws({ ...rogue, x5c: [rogue.x5c[0]!, apple.x5c[1]!, apple.x5c[2]!] }, payload);
    expect(issue(() => verifyAppleJws(spliced, [apple.root]))).toBe('chain');
    const [h, , s] = signJws(apple, payload).split('.');
    const forged = Buffer.from(JSON.stringify({ ...payload, transactionId: '9' })).toString('base64url');
    expect(issue(() => verifyAppleJws(`${h}.${forged}.${s}`, [apple.root]))).toBe('signature');
    expect(issue(() => verifyAppleJws(signJws(unmarked, payload), [unmarked.root]))).toBe('oid');
    expect(issue(() => verifyAppleJws(signJws(apple, payload, { alg: 'none' }), [apple.root]))).toBe('alg');
    expect(issue(() => verifyAppleJws(signJws(apple, payload, { x5c: [] }), [apple.root]))).toBe('x5c');
    expect(issue(() => verifyAppleJws('a.b', [apple.root]))).toBe('malformed');
    expect(issue(() => verifyAppleJws(signJws(apple, payload), []))).toBe('root');
  });

  it('checks the certificates at the signed date', () => {
    const old = { ...payload, signedDate: Date.UTC(2000, 0, 1) };
    expect(issue(() => verifyAppleJws(signJws(apple, old), [apple.root]))).toBe('expired');
  });
});
