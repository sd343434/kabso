import type { ReadableStream as WebReadableStream } from 'node:stream/web';
import type { AppConfig } from '../../config/app-config.js';
import {
  FxFetchError,
  parseCurrencyApi,
  parseExchangeRateApi,
  type FxFeed,
  type FxPaidProvider,
} from './fx.rules.js';

/** An answer larger than this is refused (about 160 currencies take ~4 KB). */
export const FX_MAX_BODY_BYTES = 1_000_000;

/**
 * v1.81-social (D245): the HTTP side of the exchange rates — one GET per fetch, a timeout, a size limit, no redirect
 * to another host and never the key in an error or a log line (the ExchangeRate-API key travels in the URL path, so
 * no URL is ever reported). Tests point the base URLs at a local stub server (no real network, no real key).
 */
export class FxFeedClient {
  constructor(private readonly config: AppConfig['fx']) {}

  /** The free no-key feed (USD base, updated once a day). */
  async free(): Promise<FxFeed> {
    return parseExchangeRateApi(await this.getJson(this.config.freeUrl, {}), 'OPEN_ER_API');
  }

  /** The OWNER's paid provider with its key. */
  async paid(provider: FxPaidProvider, apiKey: string): Promise<FxFeed> {
    if (provider === 'CURRENCYAPI') {
      const url = `${this.config.currencyApiBaseUrl}/v3/latest?base_currency=USD`;
      return parseCurrencyApi(await this.getJson(url, { apikey: apiKey }));
    }
    const url = `${this.config.exchangeRateApiBaseUrl}/v6/${encodeURIComponent(apiKey)}/latest/USD`;
    return parseExchangeRateApi(await this.getJson(url, {}), 'EXCHANGERATE_API');
  }

  private async getJson(url: string, headers: Record<string, string>): Promise<unknown> {
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'GET',
        redirect: 'error',
        headers: { Accept: 'application/json', 'User-Agent': 'kabso-api (exchange rates)', ...headers },
        signal: AbortSignal.timeout(this.config.fetchTimeoutMs),
      });
    } catch (err) {
      const name = err instanceof Error ? err.name : '';
      if (name === 'TimeoutError' || name === 'AbortError') {
        throw new FxFetchError('timeout', `no answer within ${this.config.fetchTimeoutMs} ms`);
      }
      throw new FxFetchError('unreachable', 'the provider could not be reached (DNS, TLS or network)');
    }
    let text: string;
    try {
      text = await readLimited(res);
    } catch (err) {
      if (err instanceof FxFetchError) throw err;
      throw new FxFetchError('timeout', 'the answer was cut off');
    }
    if (res.status === 401 || res.status === 403) throw new FxFetchError('bad_api_key', `HTTP ${res.status}`);
    if (res.status === 429) throw new FxFetchError('rate_limited', 'HTTP 429');
    let body: unknown;
    try {
      body = JSON.parse(text);
    } catch {
      throw new FxFetchError(res.ok ? 'bad_response' : 'http_error', `HTTP ${res.status}, not JSON`);
    }
    // ExchangeRate-API answers its own errors as JSON (sometimes with a 4xx): the parser reads them.
    if (!res.ok && !(typeof body === 'object' && body !== null && 'result' in body)) {
      throw new FxFetchError('http_error', `HTTP ${res.status}`);
    }
    return body;
  }
}

async function readLimited(res: Response): Promise<string> {
  const declared = Number(res.headers.get('content-length') ?? '0');
  if (declared > FX_MAX_BODY_BYTES) {
    await res.body?.cancel().catch(() => undefined);
    throw new FxFetchError('bad_response', 'answer too large');
  }
  const reader = (res.body as WebReadableStream<Uint8Array> | null)?.getReader();
  if (!reader) return '';
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const chunk = await reader.read();
    if (chunk.done) break;
    size += chunk.value.byteLength;
    if (size > FX_MAX_BODY_BYTES) {
      await reader.cancel().catch(() => undefined);
      throw new FxFetchError('bad_response', 'answer too large');
    }
    chunks.push(chunk.value);
  }
  return Buffer.concat(chunks).toString('utf8');
}
