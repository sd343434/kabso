import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';

/**
 * Signed keyset cursors for the levels lists (CONVENTIONS §5), like the live cursors: the payload
 * holds a version, the list it belongs to (`scope`, which includes the caller or filter) and the
 * last row's `(createdAt, id)`. HKDF separates the key from the live cursors' key.
 */
const VERSION = 1;
const TAG_BYTES = 16;
const TAG_CHARS = 22;
const MAX_CURSOR_CHARS = 512;
const BASE64URL = /^[A-Za-z0-9_-]+$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const MAX_MS = Date.UTC(9999, 11, 31, 23, 59, 59, 999);

const payloadSchema = z.strictObject({
  v: z.number(),
  s: z.string().max(200),
  t: z.number().int().min(0).max(MAX_MS),
  i: z.string().regex(UUID),
});

export interface KeysetPosition {
  readonly createdAt: Date;
  readonly id: string;
}

export class LevelsCursorCodec {
  private readonly key: Buffer;

  constructor(keySource: string) {
    this.key = Buffer.from(hkdfSync('sha256', keySource, 'kabso', 'levels-cursor/v1', 32));
  }

  private tag(payload: string): Buffer {
    return createHmac('sha256', this.key)
      .update(`levels-cursor\u0000${payload}`)
      .digest()
      .subarray(0, TAG_BYTES);
  }

  encode(scope: string, position: KeysetPosition): string {
    const payload = Buffer.from(
      JSON.stringify({ v: VERSION, s: scope, t: position.createdAt.getTime(), i: position.id.toLowerCase() }),
      'utf8',
    ).toString('base64url');
    return `${payload}.${this.tag(payload).toString('base64url')}`;
  }

  /** The position in `cursor`, or null when it is malformed, forged or for another scope. */
  decode(cursor: string, scope: string): KeysetPosition | null {
    if (cursor.length > MAX_CURSOR_CHARS) return null;
    const [payload = '', tagText = '', ...rest] = cursor.split('.');
    if (
      rest.length > 0 ||
      !BASE64URL.test(payload) ||
      tagText.length !== TAG_CHARS ||
      !BASE64URL.test(tagText)
    ) {
      return null;
    }
    const expected = Buffer.from(this.tag(payload).toString('base64url'), 'ascii');
    if (!timingSafeEqual(Buffer.from(tagText, 'ascii'), expected)) return null;
    let decoded: unknown;
    try {
      decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    } catch {
      return null;
    }
    const parsed = payloadSchema.safeParse(decoded);
    if (!parsed.success || parsed.data.v !== VERSION || parsed.data.s !== scope) return null;
    return { createdAt: new Date(parsed.data.t), id: parsed.data.i };
  }
}
