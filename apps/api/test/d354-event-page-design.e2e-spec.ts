/**
 * D354 (owner 2026-11-10 «اجعل كل الخيارات متاحة»; contract v1.115-social, CONVENTIONS §10.150): the event page
 * designer, phase 1 (server). A gift event carries an optional `design` (version 1): created, edited, validated (400
 * with `design_*` issues), kept when an edit leaves it out, cleared with null, published with the draft, edited while
 * the event runs (audited with the reason), returned in `EventDetail.design` (null = today's page) and in the panel's
 * form; the leaderboard background is a new event media kind (`board_background` → an `EVENT_BOARD_BG` asset). End to
 * end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const HOUR_MS = 3_600_000;

const CONFIG = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd354-admin-totp-test-key-0123456789-abcdefghijk',
  JWT_ACCESS_TTL_SECONDS: String(90 * 86_400),
  ADMIN_SESSION_IDLE_SECONDS: '86400',
  ADMIN_SESSION_MAX_SECONDS: '604800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '100000/900',
  EVENTS_SWEEP_INTERVAL_SECONDS: '0',
};

const SECTIONS = ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'];
const sections = (hidden: string[] = []) => SECTIONS.map((id) => ({ id, visible: !hidden.includes(id) }));

describe('D354 contract coverage', () => {
  it('openapi v1.115-social keeps the gift event operations the design travels through', () => {
    const ids = operations().map((o) => o.operationId);
    expect(ids).toEqual(
      expect.arrayContaining([
        'createAdminGiftEvent',
        'updateAdminGiftEvent',
        'getAdminGiftEvent',
        'uploadAdminEventMedia',
        'getAdminEventOptions',
        'getEvent',
      ]),
    );
  });
});

describe('D354 event page design', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let viewer: Person;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const iso = (ms: number) => new Date(ms).toISOString();
  const picture = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: { r: 120, g: 8, b: 20 } } })
      .png()
      .toBuffer();
  const upload = async (kind: string, body: Buffer) =>
    ctx.http
      .post(`/api/v1/admin/event-uploads?kind=${kind}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);
  const board = {
    kind: 'SENDERS',
    shown: 20,
    prizes: [
      {
        rankFrom: 1,
        rankTo: 1,
        items: [
          { type: 'COINS', amount: 50_000 },
          { type: 'VIP', tierCode: 'VIP_1', days: 7 },
        ],
      },
      { rankFrom: 2, rankTo: 2, items: [{ type: 'COINS', amount: 20_000 }] },
      { rankFrom: 3, rankTo: 3, items: [{ type: 'COINS', amount: 10_000 }] },
      { rankFrom: 4, rankTo: 10, items: [{ type: 'COINS', amount: 1_000 }] },
    ],
  };
  const tiers = [
    { board: 'SENDERS', from: 1, to: 1, featured: [1], labelAr: 'البطل', labelEn: 'Champion' },
    { board: 'SENDERS', from: 2, to: 2 },
    { board: 'SENDERS', from: 3, to: 3 },
    { board: 'SENDERS', from: 4, to: 10 },
  ];
  const fullDesign = (over: Record<string, unknown> = {}) => ({
    v: 1,
    layout: 'STAGE',
    leaderboard: 'SPOTLIGHT',
    countdown: 'FLIP',
    preset: 'LUXURY_GOLD',
    rulesButton: { style: 'EDGE_RIBBON', edge: 'START' },
    sections: sections(['RULES']),
    rewards: { tiers },
    motion: {
      entrance: 'SLIDE',
      durationMs: 300,
      shimmer: false,
      pulseFirst: true,
      overlaySpeed: 0.5,
      overlayOpacity: 0.6,
    },
    ...over,
  });
  const body = (over: Record<string, unknown> = {}) => ({
    status: 'PUBLISHED',
    titleAr: 'ليلة التصميم',
    titleEn: 'Design night',
    rulesAr: 'أرسل هدايا الفعالية.',
    rulesEn: 'Send the event gifts.',
    startsAt: iso(Date.now() + HOUR_MS),
    endsAt: iso(Date.now() + 48 * HOUR_MS),
    scoring: 'COINS',
    gifts: [{ giftCode: 'd354_rose' }],
    boards: [board],
    reason: 'D354 test',
    ...over,
  });
  const create = async (over: Record<string, unknown> = {}) => {
    const res = await p.send(owner, 'post', '/admin/gift-events', body(over));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createAdminGiftEvent');
    return res.body.id as string;
  };
  const put = (id: string, over: Record<string, unknown>) =>
    p.send(owner, 'put', `/admin/gift-events/${id}`, body(over));
  const detail = async (id: string, lang = 'ar') => {
    const res = await ctx.http.get(`/api/v1/events/${id}`).set(auth(viewer)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEvent');
    return res.body as { design: Record<string, unknown> | null };
  };
  type ErrorBody = {
    error?: { code?: string; message?: string; details?: { field: string; issue: string }[] };
  };
  const issuesOf = (res: { status: number; body: ErrorBody }) => {
    expect(res.status, JSON.stringify(res.body)).toBe(400);
    expect(res.body.error?.code).toBe('VALIDATION_FAILED');
    return (res.body.error?.details ?? []).map((d) => `${d.field}:${d.issue}`);
  };
  const auditWith = async (id: string, reason: string) => {
    const rows = await ctx.prisma.auditLog.findMany({ where: { action: 'event.update', targetId: id } });
    return rows.find((r) => (r.metadata as { reason?: string }).reason === reason)!;
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [{ token: OBJECT_STORAGE, value: storage }]);
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd354_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 100,
        assetKey: 'gift_d354_rose', // gitleaks:allow (an asset name)
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    owner = await p.makeAdmin(['OWNER']);
    viewer = await p.signup();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the migration: events.design (nullable JSONB, version 1) and the EVENT_BOARD_BG media kind', async () => {
    const [col] = await ctx.prisma.$queryRaw<
      { data_type: string; is_nullable: string; column_default: string | null }[]
    >`
      SELECT data_type, is_nullable, column_default FROM information_schema.columns
       WHERE table_name = 'events' AND column_name = 'design'`;
    expect(col).toEqual({ data_type: 'jsonb', is_nullable: 'YES', column_default: null });
    const checks = await ctx.prisma.$queryRaw<{ name: string; def: string }[]>`
      SELECT conname AS name, pg_get_constraintdef(oid) AS def FROM pg_constraint
       WHERE conname IN ('events_design_shape', 'media_assets_kind_known')`;
    expect(checks.map((c) => c.name).sort()).toEqual(['events_design_shape', 'media_assets_kind_known']);
    expect(checks.find((c) => c.name === 'media_assets_kind_known')!.def).toContain('EVENT_BOARD_BG');
    // An event without a design is today's page.
    const plain = await create({ titleEn: 'Plain' });
    expect((await detail(plain)).design).toBeNull();
    const form = await p.send(owner, 'get', `/admin/gift-events/${plain}`);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body.form.design).toBeNull();
    // The options list every choice for the panel.
    const options = await p.send(owner, 'get', '/admin/event-options');
    expectContract(options, 'getAdminEventOptions');
    expect(options.body.designChoices).toMatchObject({
      v: 1,
      layouts: ['HERO_PODIUM', 'STAGE', 'DECK'],
      leaderboards: ['THRONE', 'PODIUM', 'CARDS_ROW', 'SPOTLIGHT', 'SHIELD_CREST'],
      countdowns: ['CLASSIC', 'FLIP', 'RING', 'COINS', 'NEON', 'RIBBON'],
      presets: ['CLASSIC', 'LUXURY_GOLD', 'GLASS', 'DARK_MINIMAL', 'NEON', 'KABSO_RED'],
    });
    expect(options.body.specs.map((s: { kind: string }) => s.kind)).toContain('board_background');
  });

  it('create with a design: every default written out, in the app’s detail and the panel’s form', async () => {
    const minimal = await create({ titleEn: 'Minimal', design: { v: 1, layout: 'DECK' } });
    const d = (await detail(minimal)).design;
    expect(d).toEqual({
      v: 1,
      layout: 'DECK',
      leaderboard: 'THRONE',
      countdown: 'CLASSIC',
      preset: 'CLASSIC',
      rulesButton: null,
      sections: sections(),
      leaderboardBackgroundMediaId: null,
      leaderboardBackgroundUrl: null,
      rewards: null,
      motion: {
        entrance: 'FADE',
        durationMs: 450,
        shimmer: true,
        pulseFirst: true,
        overlaySpeed: 1,
        overlayOpacity: 1,
      },
    });
    const full = await create({ titleEn: 'Full', design: fullDesign() });
    const got = (await detail(full, 'en')).design!;
    expect(got).toMatchObject({ ...fullDesign(), rewards: { tiers: expect.any(Array) } });
    expect((got.rewards as { tiers: unknown[] }).tiers[0]).toEqual(tiers[0]);
    expect((got.rewards as { tiers: unknown[] }).tiers[1]).toEqual({ ...tiers[1], featured: [] });
    const form = await p.send(owner, 'get', `/admin/gift-events/${full}`);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body.form.design.layout).toBe('STAGE');
    expect(
      (await ctx.prisma.auditLog.findFirstOrThrow({ where: { action: 'event.create', targetId: full } }))
        .metadata,
    ).toMatchObject({
      design: {
        layout: 'STAGE',
        rulesButton: 'EDGE_RIBBON:START',
        tiers: ['SENDERS:1-1', 'SENDERS:2-2', 'SENDERS:3-3', 'SENDERS:4-10'],
      },
    });
  });

  it('invalid designs are 400 VALIDATION_FAILED with the issue, and nothing is saved', async () => {
    const before = await ctx.prisma.event.count();
    const cases: [Record<string, unknown>, string[]][] = [
      [{ design: fullDesign({ rulesButton: null }) }, ['design.rulesButton:design_rules_unreachable']],
      [
        { design: fullDesign({ sections: sections(['BOARDS']), rulesButton: { style: 'GOLD_PILL' } }) },
        ['design.sections:design_boards_required'],
      ],
      [
        { design: fullDesign({ rewards: { tiers: [tiers[1], tiers[0]] } }) },
        ['design.rewards.tiers.1:design_tier_overlap'],
      ],
      [
        { design: fullDesign({ rewards: { tiers: [{ board: 'SENDERS', from: 1, to: 3 }] } }) },
        ['design.rewards.tiers.0:design_tier_prize'],
      ],
      [
        {
          boards: [{ ...board, shown: 5 }],
          design: fullDesign({ rewards: { tiers: [{ board: 'SENDERS', from: 4, to: 10 }] } }),
        },
        ['design.rewards.tiers.0:design_tier_range'],
      ],
      [
        { design: fullDesign({ rewards: { tiers: [{ board: 'SENDERS', from: 2, to: 2, featured: [1] }] } }) },
        ['design.rewards.tiers.0:design_tier_featured'],
      ],
      [
        { design: fullDesign({ rewards: { tiers: [{ board: 'CP', from: 1, to: 1 }] } }) },
        ['design.rewards.tiers.0:design_tier_board'],
      ],
      [{ design: fullDesign({ layout: 'GRID' }) }, ['design.layout:invalid_value']],
      [{ design: fullDesign({ v: 2 }) }, ['design.v:invalid_value']],
      [{ design: fullDesign({ motion: { durationMs: 5000 } }) }, ['design.motion.durationMs:too_big']],
      [{ design: { ...fullDesign(), colour: '#fff' } }, ['design.colour:unknown_field']],
    ];
    for (const [over, want] of cases) {
      const res = await p.send(owner, 'post', '/admin/gift-events', body(over));
      expect(issuesOf(res), JSON.stringify(over)).toEqual(want);
    }
    expect(await ctx.prisma.event.count()).toBe(before);
  });

  it('the leaderboard background: its own media kind, its size, and only an uploaded one is accepted', async () => {
    const wrong = await upload('board_background', await picture(1500, 300));
    expect(wrong.status, JSON.stringify(wrong.body)).toBe(409);
    expect(wrong.body.error.details[0]).toEqual({ field: 'file', issue: 'event_media_size' });
    const ok = await upload('board_background', await picture(2160, 2880));
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expectContract(ok, 'uploadAdminEventMedia');
    expect(ok.body).toMatchObject({
      kind: 'board_background',
      key: null,
      width: 1080,
      height: 1440,
      animated: false,
    });
    const asset = await ctx.prisma.mediaAsset.findUniqueOrThrow({ where: { id: ok.body.mediaId } });
    expect(asset).toMatchObject({ kind: 'EVENT_BOARD_BG', width: 1080, height: 1440, attachedAt: null });
    expect(await storage.head(asset.largeKey)).toBeTruthy();

    // Not uploaded, or another kind (a home banner picture): 400 on the field.
    const banner = await upload('banner', await picture(1500, 300));
    for (const id of ['0197a9d6-0000-7000-8000-000000000000', banner.body.mediaId as string]) {
      const res = await p.send(
        owner,
        'post',
        '/admin/gift-events',
        body({ design: fullDesign({ leaderboardBackgroundMediaId: id }) }),
      );
      expect(issuesOf(res)).toEqual(['design.leaderboardBackgroundMediaId:invalid_value']);
    }
    const id = await create({
      titleEn: 'With background',
      design: fullDesign({ leaderboardBackgroundMediaId: ok.body.mediaId }),
    });
    const d = (await detail(id)).design!;
    expect(d.leaderboardBackgroundMediaId).toBe(ok.body.mediaId);
    expect(d.leaderboardBackgroundUrl).toBe(`https://media.example.test/${asset.largeKey}`);
    // Named by a design: attached, so the media sweeper keeps it.
    expect(
      (await ctx.prisma.mediaAsset.findUniqueOrThrow({ where: { id: asset.id } })).attachedAt,
    ).not.toBeNull();
    const form = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expect(form.body.artUrls.leaderboardBackground).toBe(d.leaderboardBackgroundUrl);
  });

  it('edits: absent keeps it, null clears it, a stale one is refused; a draft publishes with its design', async () => {
    const id = await create({ titleEn: 'Editable', design: fullDesign() });
    const kept = await put(id, { titleEn: 'Edited' });
    expect(kept.status, JSON.stringify(kept.body)).toBe(200);
    expectContract(kept, 'updateAdminGiftEvent');
    expect((await detail(id)).design!.layout).toBe('STAGE');
    // Before the start the prize table may change — the stored tiers must still fit, else 400 asking for the design.
    const stale = await put(id, {
      boards: [{ ...board, prizes: [{ rankFrom: 1, rankTo: 5, items: [{ type: 'COINS', amount: 1 }] }] }],
    });
    expect(issuesOf(stale)).toEqual([
      'design.rewards.tiers.0:design_tier_featured',
      'design.rewards.tiers.3:design_tier_prize',
    ]);
    expect(stale.body.error.message).toMatch(/Send the design again/);
    const cleared = await put(id, { design: null });
    expect(cleared.status, JSON.stringify(cleared.body)).toBe(200);
    expect((await detail(id)).design).toBeNull();
    expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id } })).design).toBeNull();

    // A draft keeps its design through «نشر».
    const draft = await p.send(owner, 'post', '/admin/gift-events', {
      ...body({
        status: 'DRAFT',
        startsAt: null,
        endsAt: null,
        design: { v: 1, layout: 'HERO_PODIUM', countdown: 'RING' },
      }),
    });
    expect(draft.status, JSON.stringify(draft.body)).toBe(201);
    const draftId = draft.body.id as string;
    const dated = await p.send(owner, 'put', `/admin/gift-events/${draftId}`, {
      ...body({ status: 'DRAFT', titleEn: 'Draft' }),
    });
    expect(dated.status, JSON.stringify(dated.body)).toBe(200);
    const published = await p.send(owner, 'post', `/admin/events/${draftId}/publish`, {
      reason: 'D354 publish',
    });
    expect(published.status, JSON.stringify(published.body)).toBe(200);
    const d = (await detail(draftId)).design!;
    expect(d).toMatchObject({ layout: 'HERO_PODIUM', countdown: 'RING' });
  });

  it('while running: the design may change (audited with the reason); the structure still may not', async () => {
    const id = await create({
      titleEn: 'Running',
      startsAt: iso(Date.now() - 60_000),
      endsAt: iso(Date.now() + 24 * HOUR_MS),
      design: fullDesign(),
    });
    const stored = await ctx.prisma.event.findUniqueOrThrow({ where: { id } });
    const dates = { startsAt: stored.startsAt!.toISOString(), endsAt: stored.endsAt!.toISOString() };
    const changed = await put(id, {
      ...dates,
      design: fullDesign({ layout: 'DECK', leaderboard: 'SHIELD_CREST', preset: 'NEON' }),
      reason: 'the owner wants the deck',
    });
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expect((await detail(id)).design).toMatchObject({
      layout: 'DECK',
      leaderboard: 'SHIELD_CREST',
      preset: 'NEON',
    });
    const audit = await auditWith(id, 'the owner wants the deck');
    expect(audit.metadata).toMatchObject({
      running: true,
      designChanged: true,
      reason: 'the owner wants the deck',
      design: { layout: 'DECK', leaderboard: 'SHIELD_CREST', preset: 'NEON' },
    });
    // The structure stays locked (D303): a prize change is still a 409, design or not.
    const structure = await put(id, { ...dates, boards: [{ ...board, minPoints: 5 }], design: fullDesign() });
    expect(structure.status, JSON.stringify(structure.body)).toBe(409);
    // The stored «عدد المعروضين» (20) bounds the tiers when the body leaves it out.
    const boardNoShown = { kind: board.kind, prizes: board.prizes };
    const beyond = await put(id, {
      ...dates,
      boards: [boardNoShown],
      design: fullDesign({ rewards: { tiers: [{ board: 'SENDERS', from: 4, to: 10 }] } }),
    });
    expect(beyond.status, JSON.stringify(beyond.body)).toBe(200);
    await ctx.prisma.eventBoard.updateMany({ where: { eventId: id }, data: { shown: 8 } });
    const tooFar = await put(id, {
      ...dates,
      boards: [boardNoShown],
      design: fullDesign({ rewards: { tiers: [{ board: 'SENDERS', from: 4, to: 10 }] } }),
    });
    expect(issuesOf(tooFar)).toEqual(['design.rewards.tiers.0:design_tier_range']);
    // An unchanged design is audited as unchanged.
    const same = await put(id, { ...dates, boards: [boardNoShown], design: fullDesign({ rewards: null }) });
    expect(same.status, JSON.stringify(same.body)).toBe(200);
    const again = await put(id, {
      ...dates,
      boards: [boardNoShown],
      design: fullDesign({ rewards: null }),
      reason: 'same again',
    });
    expect(again.status).toBe(200);
    const last = await auditWith(id, 'same again');
    expect(last.metadata).toMatchObject({ running: true, designChanged: false, reason: 'same again' });
  });
});
