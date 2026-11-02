import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import type { AddressInfo } from 'node:net';

/** One request the stub received (the key only as «present», never stored). */
export interface FxHit {
  readonly kind: 'free' | 'currencyapi' | 'exchangerate-api' | 'other';
  readonly path: string;
  readonly apikeyHeader: string | null;
}

/** What the stub answers next (per feed). */
export interface FxAnswer {
  status?: number;
  body?: unknown;
  /** Delay before answering (ms), to hold a fetch open. */
  delayMs?: number;
}

/**
 * D245: a local stand-in for the exchange-rate providers — no real network and no real key in tests. It speaks the
 * three shapes the API reads: the free ExchangeRate-API «open access» feed (`GET /v6/latest/USD`), currencyapi.com
 * (`GET /v3/latest?base_currency=USD`, header `apikey`) and the paid ExchangeRate-API (`GET /v6/{key}/latest/USD`).
 * A paid request is accepted only with {@link validKey}.
 */
export class FakeFx {
  private server: Server | null = null;
  readonly hits: FxHit[] = [];
  free: FxAnswer = {};
  paid: FxAnswer = {};
  /** The provider's last-updated time the answers carry (unix seconds). */
  updatedUnix = Math.floor(Date.now() / 1000);
  rates: Record<string, unknown> = { USD: 1, EGP: 48.6, EUR: 0.92, SAR: 3.75, JPY: 152.3, KWD: 0.3071 };

  constructor(readonly validKey: string) {}

  get base(): string {
    const a = this.server?.address() as AddressInfo | null;
    if (!a) throw new Error('FakeFx is not started');
    return `http://127.0.0.1:${String(a.port)}`;
  }

  async start(): Promise<void> {
    this.server = createServer((req, res) => void this.handle(req, res));
    await new Promise<void>((resolve) => this.server!.listen(0, '127.0.0.1', resolve));
  }

  async stop(): Promise<void> {
    await new Promise<void>((resolve) => this.server?.close(() => resolve()) ?? resolve());
  }

  count(kind: FxHit['kind']): number {
    return this.hits.filter((h) => h.kind === kind).length;
  }

  private async handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const url = new URL(req.url ?? '/', 'http://x');
    const apikey = typeof req.headers.apikey === 'string' ? req.headers.apikey : null;
    const send = async (a: FxAnswer, fallback: unknown) => {
      if (a.delayMs) await new Promise((r) => setTimeout(r, a.delayMs));
      res.writeHead(a.status ?? 200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(a.body ?? fallback));
    };
    if (url.pathname === '/v6/latest/USD') {
      this.hits.push({ kind: 'free', path: url.pathname, apikeyHeader: apikey });
      return send(this.free, {
        result: 'success',
        provider: 'https://www.exchangerate-api.com',
        documentation: 'https://www.exchangerate-api.com/docs/free',
        terms_of_use: 'https://www.exchangerate-api.com/terms',
        time_last_update_unix: this.updatedUnix,
        time_next_update_unix: this.updatedUnix + 86_400,
        base_code: 'USD',
        rates: this.rates,
      });
    }
    if (url.pathname === '/v3/latest' && url.searchParams.get('base_currency') === 'USD') {
      this.hits.push({ kind: 'currencyapi', path: url.pathname, apikeyHeader: apikey ? '[present]' : null });
      if (apikey !== this.validKey) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ message: 'Invalid authentication credentials' }));
        return;
      }
      const data: Record<string, unknown> = {};
      for (const [code, value] of Object.entries(this.rates)) data[code] = { code, value };
      return send(this.paid, {
        meta: { last_updated_at: new Date(this.updatedUnix * 1000).toISOString() },
        data,
      });
    }
    const m = /^\/v6\/([^/]+)\/latest\/USD$/.exec(url.pathname);
    if (m) {
      this.hits.push({ kind: 'exchangerate-api', path: '/v6/{key}/latest/USD', apikeyHeader: null });
      if (decodeURIComponent(m[1]!) !== this.validKey) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ result: 'error', 'error-type': 'invalid-key' }));
        return;
      }
      return send(this.paid, {
        result: 'success',
        time_last_update_unix: this.updatedUnix,
        base_code: 'USD',
        conversion_rates: this.rates,
      });
    }
    this.hits.push({ kind: 'other', path: url.pathname, apikeyHeader: null });
    res.writeHead(404);
    res.end();
  }
}
