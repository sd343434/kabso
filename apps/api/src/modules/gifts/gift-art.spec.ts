import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import type { ObjectStorage } from '../media/object-storage.js';
import {
  GIFT_ANIMATION_MAX_BYTES,
  GIFT_ANIMATION_OBJECT_KEY_PATTERN,
  GIFT_ART_CACHE_CONTROL,
  GIFT_IMAGE_MAX_BYTES,
  GIFT_IMAGE_OBJECT_KEY_PATTERN,
  GiftArtError,
  giftAnimationFile,
  giftArtUrl,
  giftImageFile,
  uploadGiftArt,
} from './gift-art.js';
import { giftArtDto } from './gifts.service.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20261119090000_gift_art/migration.sql', import.meta.url),
  'utf8',
);

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 200, g: 40, b: 90, alpha: 0.5 } } })
    .png()
    .toBuffer();

/** A minimal SVGA 2.x movie: zlib(protobuf MovieEntity { version: "2.0.0" }). */
const svga = (extra = Buffer.alloc(0)) =>
  deflateSync(Buffer.concat([Buffer.from([0x0a, 0x05]), Buffer.from('2.0.0'), extra]));

describe('gift art (v1.26.2-live, D126)', () => {
  it('accepts a square PNG and WebP, keyed by content under media/gifts/<code>/', async () => {
    const body = await png(300, 300);
    const file = await giftImageFile('angel_warrior', body);
    const digest = createHash('sha256').update(body).digest('hex').slice(0, 32);
    expect(file).toMatchObject({
      key: `media/gifts/angel_warrior/${digest}.png`,
      contentType: 'image/png',
      size: body.length,
    });
    expect(file.key).toMatch(GIFT_IMAGE_OBJECT_KEY_PATTERN);
    const webp = await sharp(body).webp().toBuffer();
    const w = await giftImageFile('angel_warrior', webp);
    expect(w.contentType).toBe('image/webp');
    expect(w.key).toMatch(/\.webp$/);
    // The same bytes give the same key (immutable, re-uploading is harmless).
    expect((await giftImageFile('angel_warrior', body)).key).toBe(file.key);
  });

  it('refuses images that are not PNG/WebP, too big, too small or not square-ish', async () => {
    const jpeg = await sharp(await png(300, 300))
      .jpeg()
      .toBuffer();
    await expect(giftImageFile('g', jpeg)).rejects.toThrow('PNG or WebP');
    await expect(giftImageFile('g', Buffer.alloc(0))).rejects.toThrow(GiftArtError);
    await expect(giftImageFile('g', Buffer.alloc(GIFT_IMAGE_MAX_BYTES + 1, 1))).rejects.toThrow('1 MB');
    await expect(giftImageFile('g', await png(300, 200))).rejects.toThrow('about square');
    await expect(giftImageFile('g', await png(40, 40))).rejects.toThrow('64–2048');
    const broken = Buffer.concat([(await png(300, 300)).subarray(0, 40)]);
    await expect(giftImageFile('g', broken)).rejects.toThrow(GiftArtError);
    // A file named .png that is something else is judged by its bytes.
    await expect(giftImageFile('g', Buffer.from('GIF89a........'))).rejects.toThrow('PNG or WebP');
  });

  it('accepts SVGA 2.x (zlib + protobuf) and refuses 1.x zips, other files and > 25 MB', () => {
    const body = svga();
    const file = giftAnimationFile('angel_warrior', body);
    expect(file.contentType).toBe('application/octet-stream');
    expect(file.size).toBe(body.length);
    expect(file.key).toMatch(GIFT_ANIMATION_OBJECT_KEY_PATTERN);
    expect(() => giftAnimationFile('g', Buffer.from('PK\u0003\u0004rest-of-a-zip'))).toThrow('SVGA 1.x');
    expect(() => giftAnimationFile('g', Buffer.from('not an svga at all'))).toThrow('zlib header');
    expect(() => giftAnimationFile('g', deflateSync(Buffer.from('hello')))).toThrow('not an SVGA movie');
    const truncated = body.subarray(0, body.length - 4);
    expect(() =>
      giftAnimationFile('g', Buffer.concat([truncated.subarray(0, 2), Buffer.from([1, 2, 3])])),
    ).toThrow(GiftArtError);
    expect(() => giftAnimationFile('g', Buffer.alloc(GIFT_ANIMATION_MAX_BYTES + 1, 0x78))).toThrow('25 MB');
    expect(() => giftAnimationFile('g', Buffer.alloc(0))).toThrow('empty');
  });

  it('uploads with the content type and an immutable one-year cache', async () => {
    const puts: unknown[][] = [];
    const storage = {
      put: (...a: unknown[]) => (puts.push(a), Promise.resolve()),
    } as unknown as ObjectStorage;
    const file = giftAnimationFile('angel_warrior', svga());
    await uploadGiftArt(storage, file);
    expect(puts).toEqual([[file.key, file.body, 'application/octet-stream', GIFT_ART_CACHE_CONTROL]]);
    expect(GIFT_ART_CACHE_CONTROL).toBe('public, max-age=31536000, immutable');
  });

  it('builds public URLs only with a base URL; bytes only with an animation', () => {
    const key = `media/gifts/rose/${'a'.repeat(32)}.svga`;
    expect(giftArtUrl('https://cdn.example/', key)).toBe(`https://cdn.example/${key}`);
    expect(giftArtUrl(undefined, key)).toBeNull();
    expect(giftArtUrl('https://cdn.example', null)).toBeNull();
    expect(
      giftArtDto(
        { imageObjectKey: null, animationObjectKey: key, animationBytes: 42 },
        'https://cdn.example',
      ),
    ).toEqual({ imageUrl: null, animationUrl: `https://cdn.example/${key}`, animationBytes: 42 });
    expect(
      giftArtDto({ imageObjectKey: null, animationObjectKey: key, animationBytes: 42 }, undefined),
    ).toEqual({
      imageUrl: null,
      animationUrl: null,
      animationBytes: null,
    });
  });

  it('the migration adds nullable columns with the key formats and the size rule', () => {
    expect(migration).toMatch(/ADD COLUMN "image_object_key" VARCHAR\(200\)/);
    expect(migration).toMatch(/ADD COLUMN "animation_bytes" INTEGER/);
    expect(migration).not.toMatch(/ADD COLUMN [^,;]*(NOT NULL|DEFAULT)/);
    expect(migration).toContain('gifts_animation_bytes_set');
    expect(migration).toContain('26214400');
    expect(GIFT_ANIMATION_MAX_BYTES).toBe(26214400);
  });
});
