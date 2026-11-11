import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { BAG_CATEGORIES } from '../bag/bag.catalogue.js';
import { looksLikeMp4 } from './store-art.js';
import {
  isStoreBagCode,
  lowestPrice,
  newStoreBagCode,
  sortedPrices,
  STORE_DAY_MS,
  STORE_KINDS,
  storeArtDto,
  storeExpiryAfter,
  storeRequestHash,
  storeWearOf,
  wearHasEntrance,
  ENTRY_DISPLAYS,
  STORE_ART_SELECT,
} from './store-rules.js';
import { buyStoreItemBody, createStoreItemBody, updateStoreItemBody } from './store.schemas.js';

const migration = readFileSync(
  new URL('../../../prisma/migrations/20270310090100_store/migration.sql', import.meta.url),
  'utf8',
);

describe('D270 store rules', () => {
  it('kinds: every store kind is a stored bag category, and the CHECK lists exactly them', () => {
    for (const k of STORE_KINDS) expect(BAG_CATEGORIES).toContain(k);
    expect(migration).toContain(`kind::text IN (${STORE_KINDS.map((k) => `'${k}'`).join(', ')})`);
  });

  it('bag codes: store_<12 hex>, never a catalogue or VIP code', () => {
    const code = newStoreBagCode();
    expect(code).toMatch(/^store_[0-9a-f]{12}$/);
    expect(isStoreBagCode(code)).toBe(true);
    expect(isStoreBagCode('bunny_royal')).toBe(false);
    expect(isStoreBagCode('vip:AVATAR_FRAME')).toBe(false);
  });

  it('prices: coins first then cherries, shorter first; the lowest per currency', () => {
    const prices = [
      { currency: 'CHERRIES' as const, days: 7, amount: 900n },
      { currency: 'COINS' as const, days: 30, amount: 300n },
      { currency: 'COINS' as const, days: 7, amount: 100n },
    ];
    expect(sortedPrices(prices).map((p) => `${p.currency}:${p.days}`)).toEqual([
      'COINS:7',
      'COINS:30',
      'CHERRIES:7',
    ]);
    expect(lowestPrice(prices, 'COINS')).toBe(100n);
    expect(lowestPrice(prices, 'CHERRIES')).toBe(900n);
    expect(lowestPrice(prices.slice(1), 'CHERRIES')).toBeNull();
  });

  it('extension: days added to an end in the future, else from now; never past 3 650 days', () => {
    const now = new Date('2026-11-04T00:00:00Z');
    const owned = new Date(now.getTime() + 3 * STORE_DAY_MS);
    expect(storeExpiryAfter(owned, 7, now)!.getTime()).toBe(now.getTime() + 10 * STORE_DAY_MS);
    expect(storeExpiryAfter(null, 14, now)!.getTime()).toBe(now.getTime() + 14 * STORE_DAY_MS);
    const past = new Date(now.getTime() - STORE_DAY_MS);
    expect(storeExpiryAfter(past, 30, now)!.getTime()).toBe(now.getTime() + 30 * STORE_DAY_MS);
    expect(storeExpiryAfter(new Date(now.getTime() + 3640 * STORE_DAY_MS), 30, now)).toBeNull();
  });

  it('the Idempotency-Key fingerprint follows every field (the recipient case-insensitively)', () => {
    const base = { itemId: 'A', currency: 'COINS' as const, days: 7, price: 10, recipient: null };
    expect(storeRequestHash(base)).toBe(storeRequestHash({ ...base, itemId: 'a' }));
    expect(storeRequestHash(base)).not.toBe(storeRequestHash({ ...base, days: 14 }));
    expect(storeRequestHash(base)).not.toBe(storeRequestHash({ ...base, currency: 'CHERRIES' }));
    expect(storeRequestHash({ ...base, recipient: 'Sara' })).toBe(
      storeRequestHash({ ...base, recipient: 'sara' }),
    );
    expect(storeRequestHash(base)).not.toBe(storeRequestHash({ ...base, recipient: 'sara' }));
  });

  it('art: the alpha only for MP4, the format only with an animation', () => {
    const row = {
      still: 'https://m/s.png',
      animation: 'https://m/a.mp4',
      animationFormat: 'MP4' as const,
      animationAlpha: null,
      artWidth: 10,
      artHeight: 20,
    };
    expect(storeArtDto(row)).toEqual({
      still: 'https://m/s.png',
      animation: 'https://m/a.mp4',
      format: 'MP4',
      alpha: 'NONE',
      width: 10,
      height: 20,
    });
    expect(storeArtDto({ ...row, animation: null })).toMatchObject({ format: null });
    expect(storeArtDto({ ...row, animationFormat: 'SVGA', animationAlpha: 'SIDE_BY_SIDE' }).alpha).toBeNull();
  });

  it('wear: only store items, not expired, by kind; an entrance is a banner or a car', () => {
    const now = new Date('2026-11-04T00:00:00Z');
    const art = {
      still: null,
      animation: null,
      animationFormat: null,
      animationAlpha: null,
      artWidth: null,
      artHeight: null,
    };
    const wear = storeWearOf(
      [
        {
          category: 'CHAT_BUBBLE',
          itemCode: 'store_aaaaaaaaaaaa',
          expiresAt: null,
          item: { storeItem: art },
        },
        { category: 'AVATAR_FRAME', itemCode: 'host_frame_blue', expiresAt: null, item: { storeItem: null } },
        {
          category: 'ENTRY_EFFECT',
          itemCode: 'store_bbbbbbbbbbbb',
          expiresAt: new Date(now.getTime() - 1),
          item: { storeItem: art },
        },
      ],
      now,
    );
    expect(Object.keys(wear!)).toEqual(['chatBubble']);
    expect(wear!.chatBubble!.code).toBe('store_aaaaaaaaaaaa');
    expect(wearHasEntrance(wear)).toBe(false);
    expect(storeWearOf([], now)).toBeNull();
    expect(
      wearHasEntrance(
        storeWearOf(
          [
            {
              category: 'ENTRY_BANNER',
              itemCode: 'store_cccccccccccc',
              expiresAt: null,
              item: { storeItem: art },
            },
          ],
          now,
        ),
      ),
    ).toBe(true);
  });

  it('MP4 is told by its bytes (ftyp), an SVGA is not', () => {
    expect(looksLikeMp4(Buffer.from('\u0000\u0000\u0000\u0018ftypisom\u0000\u0000', 'latin1'))).toBe(true);
    expect(looksLikeMp4(Buffer.from([0x78, 0x9c, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))).toBe(false);
  });

  it('bodies: 7 / 14 / 30 days only, a currency and duration once, the kind fixed on update', () => {
    const id = '01a27000-0000-7000-8000-000000000001';
    expect(buyStoreItemBody.safeParse({ itemId: id, currency: 'COINS', days: 7, price: 1 }).success).toBe(
      true,
    );
    expect(buyStoreItemBody.safeParse({ itemId: id, currency: 'COINS', days: 10, price: 1 }).success).toBe(
      false,
    );
    expect(buyStoreItemBody.safeParse({ itemId: id, currency: 'GEMS', days: 7, price: 1 }).success).toBe(
      false,
    );
    const item = { kind: 'ENTRY_EFFECT', nameAr: 'س', nameEn: 'Car', reason: 'r' };
    expect(createStoreItemBody.safeParse({ ...item, prices: [] }).success).toBe(true);
    expect(
      createStoreItemBody.safeParse({
        ...item,
        prices: [
          { currency: 'CHERRIES', days: 30, amount: 5 },
          { currency: 'CHERRIES', days: 30, amount: 6 },
        ],
      }).success,
    ).toBe(false);
    expect(createStoreItemBody.safeParse({ ...item, kind: 'MIC_WAVE', prices: [] }).success).toBe(false);
    expect(updateStoreItemBody.safeParse({ kind: 'AVATAR_FRAME', reason: 'r' }).success).toBe(false);
    expect(updateStoreItemBody.safeParse({ reason: 'r' }).success).toBe(false);
  });
});

describe('D373 an entry car display (v1.128-social, §10.165)', () => {
  const now = new Date('2026-11-11T00:00:00Z');
  const art = (entryDisplay?: 'FULL_SCREEN' | 'HALF_SCREEN') => ({
    still: null,
    animation: 'https://media.example.test/media/store/car.svga',
    animationFormat: 'SVGA' as const,
    animationAlpha: null,
    artWidth: 750,
    artHeight: 1334,
    ...(entryDisplay ? { entryDisplay } : {}),
  });
  const worn = (category: string, entryDisplay?: 'FULL_SCREEN' | 'HALF_SCREEN') =>
    storeWearOf(
      [{ category, itemCode: 'store_dddddddddddd', expiresAt: null, item: { storeItem: art(entryDisplay) } }],
      now,
    );

  it('the worn car carries its display; FULL_SCREEN when the select had none; no other kind has one', () => {
    expect(ENTRY_DISPLAYS).toEqual(['FULL_SCREEN', 'HALF_SCREEN']);
    expect(STORE_ART_SELECT).toHaveProperty('entryDisplay', true);
    expect(worn('ENTRY_EFFECT', 'HALF_SCREEN')!.entryEffect!.entryDisplay).toBe('HALF_SCREEN');
    expect(worn('ENTRY_EFFECT', 'FULL_SCREEN')!.entryEffect!.entryDisplay).toBe('FULL_SCREEN');
    expect(worn('ENTRY_EFFECT')!.entryEffect!.entryDisplay).toBe('FULL_SCREEN');
    for (const [kind, key] of [
      ['ENTRY_BANNER', 'entryBanner'],
      ['CHAT_BUBBLE', 'chatBubble'],
      ['AVATAR_FRAME', 'avatarFrame'],
      ['PROFILE_CARD', 'profileCard'],
    ] as const) {
      expect(worn(kind, 'HALF_SCREEN')![key], kind).not.toHaveProperty('entryDisplay');
    }
  });

  it('the panel bodies: an entry car takes FULL_SCREEN / HALF_SCREEN; another kind or value is refused', () => {
    const car = { kind: 'ENTRY_EFFECT', nameAr: 'س', nameEn: 'Car', prices: [], reason: 'r' };
    expect(createStoreItemBody.safeParse({ ...car, entryDisplay: 'HALF_SCREEN' }).success).toBe(true);
    expect(createStoreItemBody.safeParse({ ...car, entryDisplay: 'FULL_SCREEN' }).success).toBe(true);
    expect(createStoreItemBody.safeParse({ ...car, entryDisplay: 'HALF' }).success).toBe(false);
    const frame = createStoreItemBody.safeParse({
      ...car,
      kind: 'AVATAR_FRAME',
      entryDisplay: 'HALF_SCREEN',
    });
    expect(frame.success).toBe(false);
    expect(frame.error!.issues[0]!.path).toEqual(['entryDisplay']);
    expect(updateStoreItemBody.safeParse({ entryDisplay: 'HALF_SCREEN', reason: 'r' }).success).toBe(true);
    expect(updateStoreItemBody.safeParse({ entryDisplay: 'SIDE', reason: 'r' }).success).toBe(false);
  });

  it('the migration keeps every existing car FULL_SCREEN (a NOT NULL default on both tables)', () => {
    const sql = readFileSync(
      new URL('../../../prisma/migrations/20270502090000_entry_car_display/migration.sql', import.meta.url),
      'utf8',
    );
    expect(sql).toContain(`CREATE TYPE "entry_display" AS ENUM ('FULL_SCREEN', 'HALF_SCREEN');`);
    for (const table of ['store_items', 'vip_tier_perks']) {
      expect(sql).toContain(
        `ALTER TABLE "${table}" ADD COLUMN "entry_display" "entry_display" NOT NULL DEFAULT 'FULL_SCREEN';`,
      );
    }
  });
});
