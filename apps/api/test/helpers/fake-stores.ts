/**
 * D345: an in-memory Google Play and App Store for the tests (no network, no real key). `TestPki` makes a throwaway
 * certificate chain shaped like Apple's (root → intermediate with the WWDR OID → leaf with the receipt-signing OID)
 * with the system's `openssl`, in a temporary directory deleted by `cleanup()`; `signJws` signs a payload like the App
 * Store does (ES256, `x5c`). Nothing here is a real Apple or Google credential.
 */
import { execFileSync } from 'node:child_process';
import { createPrivateKey, sign, X509Certificate, type KeyObject } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type {
  AppleConsumptionBody,
  AppStoreApi,
  GooglePlayApi,
  GoogleProductPurchase,
  GoogleVoidedPurchase,
  IapStoreClients,
} from '../../src/modules/store-iap/store-clients.js';
import { StoreApiError } from '../../src/modules/store-iap/store-clients.js';

const LEAF_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

function ssl(dir: string, args: string[]): void {
  execFileSync('openssl', args, { cwd: dir, stdio: 'ignore' });
}

export interface Chain {
  readonly leafKey: KeyObject;
  readonly x5c: string[];
  readonly root: X509Certificate;
  readonly rootPem: string;
}

/** A throwaway PKI shaped like Apple's (and, with `oids: false`, one missing Apple's markers). */
export class TestPki {
  readonly dir = mkdtempSync(join(tmpdir(), 'kabso-iap-pki-'));

  chain(name: string, oids = true): Chain {
    const d = this.dir;
    const p = (f: string) => `${name}-${f}`;
    ssl(d, ['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', p('root.key')]);
    ssl(d, [
      'req',
      '-x509',
      '-new',
      '-key',
      p('root.key'),
      '-subj',
      `/CN=${name} Root CA`,
      '-days',
      '3650',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
      '-addext',
      'keyUsage=critical,keyCertSign,cRLSign',
      '-out',
      p('root.pem'),
    ]);
    const level = (child: string, parent: string, ca: boolean, oid: string) => {
      ssl(d, ['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', p(`${child}.key`)]);
      ssl(d, [
        'req',
        '-new',
        '-key',
        p(`${child}.key`),
        '-subj',
        `/CN=${name} ${child}`,
        '-out',
        p(`${child}.csr`),
      ]);
      writeFileSync(
        join(d, p(`${child}.ext`)),
        [
          ca ? 'basicConstraints=critical,CA:TRUE' : 'basicConstraints=critical,CA:FALSE',
          ca ? 'keyUsage=critical,keyCertSign' : 'keyUsage=critical,digitalSignature',
          ...(oids ? [`${oid}=ASN1:NULL`] : []),
        ].join('\n'),
      );
      ssl(d, [
        'x509',
        '-req',
        '-in',
        p(`${child}.csr`),
        '-CA',
        p(`${parent}.pem`),
        '-CAkey',
        p(`${parent}.key`),
        '-CAcreateserial',
        '-days',
        '3650',
        '-extfile',
        p(`${child}.ext`),
        '-out',
        p(`${child}.pem`),
      ]);
    };
    level('intermediate', 'root', true, INTERMEDIATE_OID);
    level('leaf', 'intermediate', false, LEAF_OID);
    const der = (f: string) => new X509Certificate(readFileSync(join(d, p(f)))).raw.toString('base64');
    const rootPem = readFileSync(join(d, p('root.pem')), 'utf8');
    return {
      leafKey: createPrivateKey(readFileSync(join(d, p('leaf.key')))),
      x5c: [der('leaf.pem'), der('intermediate.pem'), der('root.pem')],
      root: new X509Certificate(rootPem),
      rootPem,
    };
  }

  /** Writes a file into the temporary directory and returns its path. */
  file(name: string, content: string | Buffer): string {
    const path = join(this.dir, name);
    writeFileSync(path, content);
    return path;
  }

  /** A fresh key in PEM (`ec` P-256 or `rsa` 2048), for the credential-file tests. */
  key(kind: 'ec' | 'rsa'): string {
    const f = `key-${kind}-${Math.random().toString(36).slice(2)}.pem`;
    if (kind === 'ec')
      ssl(this.dir, ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', f]);
    else ssl(this.dir, ['genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', f]);
    return readFileSync(join(this.dir, f), 'utf8');
  }

  cleanup(): void {
    rmSync(this.dir, { recursive: true, force: true });
  }
}

/** Signs `payload` like the App Store: ES256 over `header.payload`, the chain in `x5c`. */
export function signJws(
  chain: Chain,
  payload: Record<string, unknown>,
  header: Record<string, unknown> = {},
): string {
  const enc = (o: Record<string, unknown>) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const input = `${enc({ alg: 'ES256', x5c: chain.x5c, ...header })}.${enc(payload)}`;
  const sig = sign('sha256', Buffer.from(input), { key: chain.leafKey, dsaEncoding: 'ieee-p1363' });
  return `${input}.${sig.toString('base64url')}`;
}

/** Google Play's purchases, as the test sets them; consumes and voids recorded. */
export class FakeGooglePlay implements GooglePlayApi {
  readonly purchases = new Map<string, GoogleProductPurchase & { productId: string }>();
  readonly consumed: string[] = [];
  voided: GoogleVoidedPurchase[] = [];
  readonly voidedCalls: { startMs: number; endMs: number }[] = [];
  failConsume = 0;

  async getProductPurchase(productId: string, token: string): Promise<GoogleProductPurchase> {
    const p = this.purchases.get(token);
    if (!p || p.productId !== productId) throw new StoreApiError(404, 'not found');
    return p;
  }
  async consume(_productId: string, token: string): Promise<void> {
    if (this.failConsume > 0) {
      this.failConsume -= 1;
      throw new StoreApiError(503, 'down');
    }
    this.consumed.push(token);
  }
  async listVoided(startMs: number, endMs: number) {
    this.voidedCalls.push({ startMs, endMs });
    return {
      voided: this.voided.filter(
        (v) => Number(v.voidedTimeMillis) >= startMs && Number(v.voidedTimeMillis) <= endMs,
      ),
      nextPageToken: null,
    };
  }
}

/** The App Store Server API's consumption endpoint, recorded. */
export class FakeAppStore implements AppStoreApi {
  readonly sent: { transactionId: string; sandbox: boolean; body: AppleConsumptionBody }[] = [];
  fail = 0;
  async sendConsumption(transactionId: string, sandbox: boolean, body: AppleConsumptionBody): Promise<void> {
    if (this.fail > 0) {
      this.fail -= 1;
      throw new StoreApiError(500, 'down');
    }
    this.sent.push({ transactionId, sandbox, body });
  }
}

export function fakeClients(
  google: FakeGooglePlay,
  apple: FakeAppStore,
  root: X509Certificate,
): IapStoreClients {
  return { google, apple: { api: apple, roots: [root] } };
}
