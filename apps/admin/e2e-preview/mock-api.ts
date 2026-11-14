/**
 * D356: the panel's API for the preview tests and captures, answered in the browser (Playwright `page.route`): an OWNER
 * session, one running gift event with two boards, its options (with `designChoices`) and its stored design. Saves are
 * recorded; `refuse` makes the next save a 400 with the given `design*` issues (the server's shape).
 */
import { crc32, deflateSync } from 'node:zlib';
import type { Page, Route } from '@playwright/test';

export const EVENT_ID = '01a1b6a1-0000-7000-8000-000000000356';

export const STORED_DESIGN = {
  v: 1,
  layout: 'HERO_PODIUM',
  leaderboard: 'THRONE',
  countdown: 'FLIP',
  preset: 'LUXURY_GOLD',
  rulesButton: { style: 'GOLD_PILL', edge: 'END' },
  sections: ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'].map((id) => ({ id, visible: true })),
  leaderboardBackgroundMediaId: null,
  leaderboardBackgroundUrl: null,
  rewards: {
    tiers: [
      { board: 'SENDERS', from: 1, to: 1, labelAr: 'البطل', labelEn: 'Champion', featured: [0] },
      { board: 'SENDERS', from: 2, to: 2, labelAr: null, labelEn: null, featured: [] },
      { board: 'SENDERS', from: 3, to: 3, labelAr: null, labelEn: null, featured: [] },
      { board: 'SENDERS', from: 4, to: 10, labelAr: null, labelEn: null, featured: [] },
    ],
  },
  motion: { entrance: 'FADE', durationMs: 450, shimmer: true, pulseFirst: true, overlaySpeed: 1, overlayOpacity: 1 },
};

const line = (rankFrom: number, rankTo: number, items: Record<string, unknown>[]) => ({ rankFrom, rankTo, items });

export const FORM = {
  titleAr: 'ملك الهدايا',
  titleEn: 'Gift King',
  rulesAr: 'شارك بإرسال هدايا الفعالية في أي بث.',
  rulesEn: 'Send the event gifts in any live.',
  startsAt: '2026-11-08T17:00:00.000Z',
  endsAt: '2026-11-15T17:00:00.000Z',
  timeZone: 'Asia/Riyadh',
  audience: 'EVERYONE',
  featured: true,
  bannerUrl: null,
  status: 'PUBLISHED',
  permanent: false,
  recurrence: 'NONE',
  scoring: 'MULTIPLIER',
  countedGifts: 'EVENT_GIFTS',
  bannerMediaId: null,
  announceFullscreen: true,
  milestones: [{ board: 'SENDERS', points: 100000, prizes: [{ type: 'COINS', amount: 1000 }] }],
  backgroundKey: null,
  backgroundPosterKey: null,
  titleKey: null,
  overlayKey: null,
  gifts: [
    { giftCode: 'rose', pointsPerCoin: 1, pointsPerGift: 0 },
    { giftCode: 'crown', pointsPerCoin: 1, pointsPerGift: 0 },
  ],
  boards: [
    {
      kind: 'SENDERS',
      minPoints: 1000,
      shown: 20,
      prizes: [
        line(1, 1, [
          { type: 'COINS', amount: 100000 },
          { type: 'BAG_ITEM', itemCode: 'frame_gold', days: null },
        ]),
        line(2, 2, [{ type: 'COINS', amount: 50000 }]),
        line(3, 3, [{ type: 'COINS', amount: 20000 }]),
        line(4, 10, [{ type: 'COINS', amount: 5000 }]),
      ],
    },
    { kind: 'RECEIVERS', minPoints: 0, shown: 20, prizes: [line(1, 3, [{ type: 'CHERRIES', amount: 80000 }])] },
  ],
  design: STORED_DESIGN,
};

export const OPTIONS = {
  timeZone: 'Asia/Riyadh',
  boardKinds: ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'],
  specs: [
    {
      kind: 'board_background',
      width: 1080,
      height: 1440,
      formats: ['PNG', 'JPEG', 'WebP'],
      maxStillBytes: 2097152,
      maxAnimatedBytes: null,
      maxDurationMs: null,
      transparent: false,
      safeZone: null,
    },
  ],
  badges: [],
  gifts: [
    { code: 'rose', nameAr: 'وردة', nameEn: 'Rose', priceCoins: 100, enabled: true, imageUrl: null },
    { code: 'crown', nameAr: 'تاج', nameEn: 'Crown', priceCoins: 5000, enabled: true, imageUrl: null },
  ],
  bagItems: [{ code: 'frame_gold', category: 'AVATAR_FRAME', nameAr: 'إطار البطل', nameEn: 'Champion frame' }],
  vipTiers: [],
  giftCategories: [],
  designChoices: {
    v: 1,
    layouts: ['HERO_PODIUM', 'STAGE', 'DECK'],
    leaderboards: ['THRONE', 'PODIUM', 'CARDS_ROW', 'SPOTLIGHT', 'SHIELD_CREST'],
    countdowns: ['CLASSIC', 'FLIP', 'RING', 'COINS', 'NEON', 'RIBBON'],
    presets: ['CLASSIC', 'LUXURY_GOLD', 'GLASS', 'DARK_MINIMAL', 'NEON', 'KABSO_RED'],
    rulesButtons: ['EDGE_RIBBON', 'ROUND_ICON', 'GOLD_PILL', 'GLASS_CHIP', 'SIDE_TAB', 'APP_BAR_LINK'],
    edges: ['START', 'END'],
    sections: ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'],
    entrances: ['FADE', 'SLIDE', 'SCALE', 'NONE'],
    limits: { tiers: 40, featured: 3, labelLength: 24, entranceMaxMs: 1500, entranceMinMs: 0, overlaySpeedMin: 0.25, overlaySpeedMax: 2 },
  },
};

export interface MockApi {
  saves: Record<string, unknown>[];
  refuse: { field: string; issue: string }[] | null;
}

export async function mockApi(page: Page): Promise<MockApi> {
  const state: MockApi = { saves: [], refuse: null };
  const json = (route: Route, body: unknown, status = 200) =>
    route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
  await page.route('**/api/v1/**', async (route) => {
    const url = new URL(route.request().url());
    const path = url.pathname.replace('/api/v1', '');
    const method = route.request().method();
    if (path === '/admin/auth/session') {
      return json(route, {
        admin: { id: 'a1', email: 'owner@example.test', username: 'owner', displayName: 'Owner' },
        roles: ['OWNER'],
        capabilities: ['catalog.view', 'events.manage'],
        csrfToken: 'csrf',
        expiresAt: '2099-01-01T00:00:00Z',
        idleSeconds: 3600,
      });
    }
    if (path === '/admin/events') {
      return json(route, {
        data: [
          {
            id: EVENT_ID,
            titleAr: FORM.titleAr,
            titleEn: FORM.titleEn,
            metric: 'EVENT_GIFTS',
            startsAt: FORM.startsAt,
            endsAt: FORM.endsAt,
            permanent: false,
            state: 'RUNNING',
            payoutHold: false,
            status: 'PUBLISHED',
            recurrence: 'NONE',
          },
        ],
      });
    }
    if (path === '/admin/event-options') return json(route, OPTIONS);
    if (path === '/admin/event-uploads' && method === 'POST') {
      const kind = url.searchParams.get('kind');
      return json(route, {
        kind,
        mediaId: '01a1b6a1-0000-7000-8000-0000000000bb',
        key: null,
        url: '/__test-media/board.png',
        width: 1080,
        height: 1440,
        animated: false,
        durationMs: null,
      });
    }
    if (path === `/admin/gift-events/${EVENT_ID}` && method === 'GET') {
      return json(route, {
        id: EVENT_ID,
        state: 'RUNNING',
        payoutHold: false,
        structureLocked: true,
        creatorsAsHosts: true,
        artUrls: { background: null, backgroundPoster: null, title: null, overlay: null, leaderboardBackground: null },
        form: FORM,
        results: [],
      });
    }
    if (path === `/admin/gift-events/${EVENT_ID}` && method === 'PUT') {
      state.saves.push(route.request().postDataJSON() as Record<string, unknown>);
      if (state.refuse) {
        const details = state.refuse;
        state.refuse = null;
        return json(route, { error: { code: 'VALIDATION_FAILED', message: 'Validation failed', details } }, 400);
      }
      return json(route, { id: EVENT_ID });
    }
    return json(route, { error: { code: 'NOT_FOUND', message: 'not in the mock' } }, 404);
  });
  // The «uploaded» picture, served to the panel and the preview alike.
  await page.route('**/__test-media/board.png', (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: BRIGHT_PNG }),
  );
  return state;
}

/** A PNG (RGB, no filter) of [w] × [h] from [pixel]. */
export function png(w: number, h: number, pixel: (x: number, y: number) => [number, number, number]): Buffer {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    for (let x = 0; x < w; x++) raw.set(pixel(x, y), y * (w * 3 + 1) + 1 + x * 3);
  }
  const chunk = (type: string, data: Buffer) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** A light leaderboard background (pale gold to white): the contrast warning's case. */
export const BRIGHT_PNG = png(108, 144, (x, y) => [255, 236 + Math.round((19 * y) / 144), 190 + Math.round((60 * x) / 108)]);
