import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { signatureOf } from '../../src/modules/whatsapp/whatsapp-core.js';

/**
 * D355: a fake of Meta's Graph API for the WhatsApp Cloud API (no network) — the shapes the server uses
 * (graph-client.ts): send messages and read receipts, media upload / lookup / download, the approved templates and
 * the phone number's details. Every request must carry the configured bearer token.
 */
export interface FakeTemplate {
  name: string;
  language: string;
  status: string;
  category: string;
  components: { type: string; text?: string }[];
}

export class FakeWhatsAppGraph {
  private server: Server | undefined;
  base = '';
  readonly sent: Record<string, unknown>[] = [];
  readonly reads: string[] = [];
  readonly uploads: { size: number; type: string | null }[] = [];
  readonly media = new Map<string, { bytes: Buffer; mime: string }>();
  templates: FakeTemplate[] = [
    {
      name: 'kabso_followup',
      language: 'ar',
      status: 'APPROVED',
      category: 'UTILITY',
      components: [{ type: 'BODY', text: 'مرحباً {{1}}، هل ما زلت تحتاج المساعدة في طلبك {{2}}؟' }],
    },
    {
      name: 'kabso_hello',
      language: 'en_US',
      status: 'APPROVED',
      category: 'UTILITY',
      components: [{ type: 'BODY', text: 'Hello from Kabso' }],
    },
    { name: 'kabso_draft', language: 'ar', status: 'PENDING', category: 'MARKETING', components: [] },
  ];
  /** The next send answers this Graph error. */
  failNext: { status: number; code: number; title: string } | null = null;
  badAuth = 0;
  private seq = 0;

  constructor(
    readonly token: string,
    readonly phoneNumberId: string,
    readonly wabaId: string,
  ) {}

  async start(): Promise<void> {
    this.server = createServer((req, res) => void this.handle(req, res));
    await new Promise<void>((resolve) => this.server!.listen(0, '127.0.0.1', resolve));
    const addr = this.server.address();
    if (addr && typeof addr === 'object') this.base = `http://127.0.0.1:${addr.port}`;
  }

  async stop(): Promise<void> {
    await new Promise<void>((resolve) => this.server?.close(() => resolve()) ?? resolve());
  }

  /** A media file Meta holds for an inbound message. */
  addMedia(id: string, bytes: Buffer, mime: string): void {
    this.media.set(id, { bytes, mime });
  }

  private async body(req: IncomingMessage): Promise<Buffer> {
    const chunks: Buffer[] = [];
    for await (const c of req) chunks.push(c as Buffer);
    return Buffer.concat(chunks);
  }

  private async handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const json = (status: number, body: unknown) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(body));
    };
    if (req.headers.authorization !== `Bearer ${this.token}`) {
      this.badAuth += 1;
      return json(401, { error: { code: 190, message: 'Invalid OAuth access token' } });
    }
    const url = new URL(req.url ?? '/', 'http://x');
    const parts = url.pathname.split('/').filter(Boolean);
    if (parts[0] === 'media-bytes' && parts[1]) {
      const m = this.media.get(parts[1]);
      if (!m) return json(404, {});
      res.writeHead(200, { 'Content-Type': m.mime, 'Content-Length': String(m.bytes.length) });
      return void res.end(m.bytes);
    }
    const [version, node, edge] = parts;
    if (!version?.startsWith('v')) return json(404, {});
    if (req.method === 'POST' && node === this.phoneNumberId && edge === 'messages') {
      const body = JSON.parse((await this.body(req)).toString('utf8')) as Record<string, unknown>;
      if (body.status === 'read') {
        this.reads.push(String(body.message_id));
        return json(200, { success: true });
      }
      if (this.failNext) {
        const f = this.failNext;
        this.failNext = null;
        return json(f.status, { error: { code: f.code, message: f.title, type: 'OAuthException' } });
      }
      this.sent.push(body);
      this.seq += 1;
      return json(200, {
        messaging_product: 'whatsapp',
        contacts: [{ input: body.to, wa_id: body.to }],
        messages: [{ id: `wamid.OUT${this.seq}` }],
      });
    }
    if (req.method === 'POST' && node === this.phoneNumberId && edge === 'media') {
      const raw = await this.body(req);
      const type = /name="type"\r\n\r\n([^\r]+)/.exec(raw.toString('latin1'))?.[1] ?? null;
      this.uploads.push({ size: raw.length, type });
      this.seq += 1;
      return json(200, { id: `up-${this.seq}` });
    }
    if (req.method === 'GET' && node === this.wabaId && edge === 'message_templates') {
      return json(200, { data: this.templates, paging: {} });
    }
    if (req.method === 'GET' && node === this.phoneNumberId && !edge) {
      return json(200, {
        display_phone_number: '+966 50 000 0000',
        verified_name: 'Kabso Live',
        quality_rating: 'GREEN',
        id: this.phoneNumberId,
      });
    }
    if (req.method === 'GET' && node && !edge && this.media.has(node)) {
      const m = this.media.get(node)!;
      return json(200, {
        url: `${this.base}/media-bytes/${node}`,
        mime_type: m.mime,
        file_size: m.bytes.length,
        id: node,
        messaging_product: 'whatsapp',
      });
    }
    return json(404, { error: { code: 100, message: 'Unsupported request' } });
  }
}

/** A signed webhook POST body for `messages` / `statuses` (the way Meta sends it). */
export function webhookBody(
  phoneNumberId: string,
  value: { messages?: unknown[]; statuses?: unknown[]; contacts?: unknown[] },
): string {
  return JSON.stringify({
    object: 'whatsapp_business_account',
    entry: [
      {
        id: 'WABA',
        changes: [
          {
            field: 'messages',
            value: {
              messaging_product: 'whatsapp',
              metadata: { display_phone_number: '966500000000', phone_number_id: phoneNumberId },
              ...value,
            },
          },
        ],
      },
    ],
  });
}

export { signatureOf };
