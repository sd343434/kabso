import { readFileSync } from 'node:fs';
import { createPrivateKey, sign, type KeyObject, type X509Certificate } from 'node:crypto';
import type { AppConfig } from '../../config/app-config.js';
import { readCertificate } from './apple-jws.js';

/**
 * v1.110-social (D345, CONVENTIONS §10.144): the few store API calls, behind ports so tests replace them (no network in
 * tests: they override {@link IAP_STORE_CLIENTS}). The credentials are files whose paths are in the server environment;
 * they are read once at boot and a bad file stops the boot. Nothing here logs or returns a credential.
 */
export const IAP_STORE_CLIENTS = Symbol('IAP_STORE_CLIENTS');

/** A store answered with an HTTP error (`status`), or could not be reached (`status` 0). */
export class StoreApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/** Android Publisher v3 `ProductPurchase` (the fields used). */
export interface GoogleProductPurchase {
  readonly purchaseState?: number;
  readonly consumptionState?: number;
  readonly acknowledgementState?: number;
  readonly orderId?: string;
  readonly purchaseTimeMillis?: string;
  /** 0 = a test purchase (licence tester); absent = a real one. */
  readonly purchaseType?: number;
  readonly obfuscatedExternalAccountId?: string;
  readonly quantity?: number;
}

/** Android Publisher v3 `VoidedPurchase`. */
export interface GoogleVoidedPurchase {
  readonly purchaseToken: string;
  readonly orderId?: string;
  readonly voidedTimeMillis: string;
  readonly purchaseTimeMillis?: string;
  /** 0 user, 1 developer, 2 Google. */
  readonly voidedSource?: number;
  /** 0 other, 1 remorse, 2 not received, 3 defective, 4 accidental, 5 fraud, 6 friendly fraud, 7 chargeback. */
  readonly voidedReason?: number;
}

export interface GooglePlayApi {
  getProductPurchase(productId: string, token: string): Promise<GoogleProductPurchase>;
  consume(productId: string, token: string): Promise<void>;
  listVoided(
    startMs: number,
    endMs: number,
    pageToken: string | null,
  ): Promise<{ voided: GoogleVoidedPurchase[]; nextPageToken: string | null }>;
}

/** Apple's current `ConsumptionRequest` (App Store Server API ≥ 1.19). */
export interface AppleConsumptionBody {
  readonly customerConsented: true;
  readonly consumptionPercentage: number;
  readonly deliveryStatus: 'DELIVERED' | 'UNDELIVERED_OTHER';
  readonly refundPreference?: 'DECLINE';
  readonly sampleContentProvided: false;
}

export interface AppStoreApi {
  /** `PUT /inApps/v2/transactions/consumption/{transactionId}` on the environment's host; resolves on 202. */
  sendConsumption(transactionId: string, sandbox: boolean, body: AppleConsumptionBody): Promise<void>;
}

export interface IapStoreClients {
  readonly google: GooglePlayApi | null;
  readonly apple: { readonly api: AppStoreApi; readonly roots: readonly X509Certificate[] } | null;
}

const TIMEOUT_MS = 10_000;

async function call(url: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(url, { ...init, signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch {
    throw new StoreApiError(0, 'store unreachable');
  }
}

function jwt(
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
  key: KeyObject,
  alg: 'RS256' | 'ES256',
) {
  const enc = (o: Record<string, unknown>) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const input = `${enc(header)}.${enc(claims)}`;
  const signature =
    alg === 'RS256'
      ? sign('sha256', Buffer.from(input), key)
      : sign('sha256', Buffer.from(input), { key, dsaEncoding: 'ieee-p1363' });
  return `${input}.${signature.toString('base64url')}`;
}

/** The real Google Play client: a service account's OAuth token (cached until 5 minutes before it expires). */
class HttpGooglePlayApi implements GooglePlayApi {
  private token: { value: string; until: number } | null = null;
  private readonly base: string;

  constructor(
    packageName: string,
    private readonly clientEmail: string,
    private readonly key: KeyObject,
    private readonly tokenUri: string,
  ) {
    this.base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}`;
  }

  private async bearer(): Promise<string> {
    if (this.token && this.token.until > Date.now()) return this.token.value;
    const now = Math.floor(Date.now() / 1000);
    const assertion = jwt(
      { alg: 'RS256', typ: 'JWT' },
      {
        iss: this.clientEmail,
        scope: 'https://www.googleapis.com/auth/androidpublisher',
        aud: this.tokenUri,
        iat: now,
        exp: now + 3600,
      },
      this.key,
      'RS256',
    );
    const res = await call(this.tokenUri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    if (!res.ok) throw new StoreApiError(res.status, 'google token refused');
    const body = (await res.json()) as { access_token?: string; expires_in?: number };
    if (!body.access_token) throw new StoreApiError(502, 'google token missing');
    this.token = { value: body.access_token, until: Date.now() + ((body.expires_in ?? 3600) - 300) * 1000 };
    return body.access_token;
  }

  private async request(path: string, method: 'GET' | 'POST'): Promise<Response> {
    const res = await call(`${this.base}${path}`, {
      method,
      headers: { Authorization: `Bearer ${await this.bearer()}` },
    });
    if (!res.ok) throw new StoreApiError(res.status, `google ${method} failed`);
    return res;
  }

  async getProductPurchase(productId: string, token: string): Promise<GoogleProductPurchase> {
    const res = await this.request(
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`,
      'GET',
    );
    return (await res.json()) as GoogleProductPurchase;
  }

  async consume(productId: string, token: string): Promise<void> {
    await this.request(
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:consume`,
      'POST',
    );
  }

  async listVoided(startMs: number, endMs: number, pageToken: string | null) {
    const q = new URLSearchParams({
      startTime: String(startMs),
      endTime: String(endMs),
      type: '0',
      maxResults: '1000',
      ...(pageToken ? { token: pageToken } : {}),
    });
    const res = await this.request(`/purchases/voidedpurchases?${q.toString()}`, 'GET');
    const body = (await res.json()) as {
      voidedPurchases?: GoogleVoidedPurchase[];
      tokenPagination?: { nextPageToken?: string };
    };
    return { voided: body.voidedPurchases ?? [], nextPageToken: body.tokenPagination?.nextPageToken ?? null };
  }
}

/** The real App Store Server API client (ES256 JWT per call, ≤ 20 minutes). */
class HttpAppStoreApi implements AppStoreApi {
  constructor(
    private readonly issuerId: string,
    private readonly keyId: string,
    private readonly key: KeyObject,
    private readonly bundleId: string,
  ) {}

  async sendConsumption(transactionId: string, sandbox: boolean, body: AppleConsumptionBody): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    const token = jwt(
      { alg: 'ES256', kid: this.keyId, typ: 'JWT' },
      { iss: this.issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1', bid: this.bundleId },
      this.key,
      'ES256',
    );
    const host = sandbox ? 'https://api.storekit-sandbox.apple.com' : 'https://api.storekit.apple.com';
    const res = await call(
      `${host}/inApps/v2/transactions/consumption/${encodeURIComponent(transactionId)}`,
      {
        method: 'PUT',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      },
    );
    if (res.status !== 202 && res.status !== 200)
      throw new StoreApiError(res.status, 'apple consumption refused');
  }
}

/** Why a credential file was refused at boot (never its content). */
export class StoreCredentialError extends Error {}

/** Reads the configured credential files and builds the clients (a store that is not configured is null). */
export function loadStoreClients(config: AppConfig['storeIap']): IapStoreClients {
  let google: GooglePlayApi | null = null;
  if (config.google) {
    let parsed: { client_email?: unknown; private_key?: unknown; token_uri?: unknown };
    try {
      parsed = JSON.parse(readFileSync(config.google.serviceAccountFile, 'utf8')) as typeof parsed;
    } catch {
      throw new StoreCredentialError('STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE is not a readable JSON file');
    }
    if (typeof parsed.client_email !== 'string' || typeof parsed.private_key !== 'string') {
      throw new StoreCredentialError(
        'STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE has no client_email / private_key',
      );
    }
    let key: KeyObject;
    try {
      key = createPrivateKey(parsed.private_key);
    } catch {
      throw new StoreCredentialError('STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE has an unreadable private_key');
    }
    if (key.asymmetricKeyType !== 'rsa')
      throw new StoreCredentialError('the Google service-account key is not RSA');
    const tokenUri =
      typeof parsed.token_uri === 'string' ? parsed.token_uri : 'https://oauth2.googleapis.com/token';
    if (!tokenUri.startsWith('https://'))
      throw new StoreCredentialError('the service account token_uri is not https');
    google = new HttpGooglePlayApi(config.google.packageName, parsed.client_email, key, tokenUri);
  }
  let apple: IapStoreClients['apple'] = null;
  if (config.apple) {
    let key: KeyObject;
    try {
      key = createPrivateKey(readFileSync(config.apple.privateKeyFile, 'utf8'));
    } catch {
      throw new StoreCredentialError('STORE_IAP_APPLE_PRIVATE_KEY_FILE is not a readable .p8 key');
    }
    if (key.asymmetricKeyType !== 'ec')
      throw new StoreCredentialError('the App Store Connect key is not an EC key');
    const roots = config.apple.rootCertFiles.map((path) => {
      try {
        return readCertificate(readFileSync(path));
      } catch {
        throw new StoreCredentialError('STORE_IAP_APPLE_ROOT_CERT_FILES lists an unreadable certificate');
      }
    });
    apple = {
      api: new HttpAppStoreApi(config.apple.issuerId, config.apple.keyId, key, config.apple.bundleId),
      roots,
    };
  }
  return { google, apple };
}
