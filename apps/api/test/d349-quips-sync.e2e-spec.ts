/**
 * D349 (owner 2026-11-09, CONVENTIONS §10.147): «إفيهات» by dialect — the free sounds stay «مجانية», the 27
 * Kabi lines of D154 become «مصري» at 100 000 coins, and 14 «خليجي» and 4 «أردني» lines are added at 100 000.
 * `gift-admin quips-sync` brings a catalogue seeded by D154 (old prices and tags, a send already made) in line,
 * idempotently, and sets texts from a file; history keeps the price it was sent at. Runs `gift-admin` as on the
 * server (a child process with the migration role) against PostgreSQL + Redis.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join as joinPath } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { QUIP_PACK, QUIP_PRICES } from '../src/modules/gifts/quips.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

/** Runs `pnpm gift:admin …` as on the server (migration role, a child process). */
function giftAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'gift:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

/** D154's tags and prices, as a catalogue seeded before D349 holds them. */
const D154_GROUPS = {
  ghazal: { ar: 'غزل', en: 'Flirty', price: 99, sort: 100 },
  funny: { ar: 'ضحك', en: 'Funny', price: 199, sort: 200 },
  tease: { ar: 'تريقة', en: 'Teasing', price: 299, sort: 300 },
} as const;

describe('D349 quips by dialect: quips-sync', { timeout: 180_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let dir: string;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const scene = async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const live = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Quips', mode: 'AUDIO', seatCount: 10 });
    expect(live.status, JSON.stringify(live.body)).toBe(201);
    const roomId = live.body.id as string;
    const viewer = await signup();
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: viewer.id },
    });
    await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw)
      .expect(200);
    await ctx.prisma.$transaction((tx) =>
      creditIn(tx, viewer.id, BigInt(1_000_000), 'ADMIN_GRANT', randomUUID()),
    );
    return { h, viewer, roomId };
  };
  const send = (roomId: string, u: TestUser, code: string, to: TestUser) =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(u))
      .send({
        giftCode: code,
        quantity: 1,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
  const catalogue = async (u: TestUser, lang = 'ar') => {
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u)).set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'getGiftCatalogue');
    return (
      res.body.data as {
        code: string;
        category: string;
        priceCoins: number;
        tag: { code: string; name: string } | null;
        quip: { soundKey: string; durationMs: number; text: string | null } | null;
      }[]
    ).filter((g) => g.category === 'QUIPS');
  };
  const textsFile = (name: string, json: unknown): string => {
    const file = joinPath(dir, name);
    writeFileSync(file, typeof json === 'string' ? json : JSON.stringify(json));
    return file;
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    dir = mkdtempSync(joinPath(tmpdir(), 'd349-'));
    // The staging catalogue before D349: D154's 35 quips at the old prices and tags.
    await ctx.prisma.$transaction(async (tx) => {
      for (const { code, ...q } of QUIP_PACK) {
        const [folder, name] = q.soundKey!.split('/') as [string, string];
        if (folder === 'room') {
          await addGiftIn(tx, code, q);
        } else if (folder === 'kabi') {
          const kind = name.split('_')[0] as keyof typeof D154_GROUPS;
          const g = D154_GROUPS[kind];
          await addGiftIn(tx, code, {
            ...q,
            priceCoins: g.price,
            tagCode: kind,
            tagNameAr: g.ar,
            tagNameEn: g.en,
            sortOrder: g.sort + Number(name.split('_')[1]),
          });
        }
      }
    });
  });
  afterAll(async () => {
    rmSync(dir, { recursive: true, force: true });
    await ctx?.close();
  });

  it('moves the D154 lines to «مصري» at 100 000, adds «خليجي» and «أردني»; history keeps its price; idempotent', async () => {
    const { h, viewer, roomId } = await scene();
    // A send at the old price, before the sync.
    const before = await send(roomId, viewer, 'quip_ghazal_01', h);
    expect(before.status, JSON.stringify(before.body)).toBe(201);
    expect(before.body.gift).toMatchObject({ unitPrice: 99, totalCoins: 99 });

    const synced = giftAdmin('quips-sync');
    expect(synced.status, synced.out).toBe(0);
    expect(synced.out).toMatch(
      /^quips: 18 added \(quip_gulf_01, .*quip_jordan_04\), 27 updated \(quip_ghazal_01, .*quip_tease_09\), 8 unchanged\.$/m,
    );

    const quips = await catalogue(viewer);
    expect(quips).toHaveLength(53);
    // The chips, in the panel's order.
    expect([...new Set(quips.map((g) => g.tag?.name))]).toEqual(['مجانية', 'مصري', 'خليجي', 'أردني']);
    const en = await catalogue(viewer, 'en');
    expect([...new Set(en.map((g) => g.tag?.name))]).toEqual(['Free', 'Egyptian', 'Gulf', 'Jordanian']);
    for (const g of quips) {
      expect(g.priceCoins).toBe(g.tag!.code === 'free' ? 0 : QUIP_PRICES.egypt);
    }
    // Names, sound and words of a D154 line are kept; a new line comes with the owner's words.
    expect(quips.find((g) => g.code === 'quip_tease_02')).toMatchObject({
      priceCoins: 100_000,
      tag: { code: 'egypt', name: 'مصري' },
      quip: { soundKey: 'kabi/tease_02', durationMs: 5721, text: 'إنت لو التركيز فلوس، كنت استلفت مننا.' },
    });
    expect(quips.find((g) => g.code === 'quip_gulf_07')).toMatchObject({
      priceCoins: 100_000,
      tag: { code: 'gulf', name: 'خليجي' },
      quip: { soundKey: 'gulf/gulf_07', durationMs: 3997, text: 'تكفى لا تطلع، توّنا بدينا نستانس! 🥹' },
    });
    // Audited per gift.
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'gift.update', targetId: { startsWith: 'quip_' } },
      }),
    ).toBe(27);
    expect(
      await ctx.prisma.auditLog.count({
        where: { action: 'gift.add', targetId: { startsWith: 'quip_gulf_' } },
      }),
    ).toBe(14);

    // History keeps the price it was sent at; the next send pays the new price, at the quips' 50 % share.
    const old = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: before.body.gift.id as string } });
    expect(old.unitPrice).toBe(99);
    const now = await send(roomId, viewer, 'quip_jordan_02', h);
    expect(now.status, JSON.stringify(now.body)).toBe(201);
    expect(now.body.gift).toMatchObject({ unitPrice: 100_000, totalCoins: 100_000 });
    expect(now.body.quip).toMatchObject({
      soundKey: 'jordan/jordan_02',
      text: 'يا زلمة قلبي مش واتساب، بس إنت كل ما تطلّ عليّ... بعملك اتصال!',
      free: false,
    });
    const row = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: now.body.gift.id as string } });
    expect(row.hostShareBps).toBe(5000);

    // A second run changes nothing; quips-seed finds them all.
    const again = giftAdmin('quips-sync');
    expect(again.status, again.out).toBe(0);
    expect(again.out).toContain('quips: 0 added, 0 updated, 53 unchanged.');
    expect(giftAdmin('quips-seed').out).toContain('0 added, 53 already there');
  });

  it("--texts sets the named quips' words once; a bad file changes nothing", async () => {
    // Placeholder words for the test only (a later correction by the owner goes the same way).
    const file = textsFile('texts.json', {
      quip_gulf_01: '  test line one  ',
      quip_jordan_04: 'test line four',
    });
    const set = giftAdmin('quips-sync', '--texts', file);
    expect(set.status, set.out).toBe(0);
    expect(set.out).toContain('quips: 0 added, 2 updated (quip_gulf_01, quip_jordan_04), 51 unchanged.');
    const u = await signup();
    const quips = await catalogue(u);
    expect(quips.find((g) => g.code === 'quip_gulf_01')?.quip?.text).toBe('test line one');
    expect(quips.find((g) => g.code === 'quip_jordan_04')?.quip?.text).toBe('test line four');
    expect(giftAdmin('quips-sync', '--texts', file).out).toContain('0 added, 0 updated, 53 unchanged.');
    // A plain sync leaves the texts alone.
    expect(giftAdmin('quips-sync').out).toContain('0 updated');
    expect((await catalogue(u)).find((g) => g.code === 'quip_gulf_01')?.quip?.text).toBe('test line one');

    // An unknown code, an empty text or broken JSON: exit 1, nothing written.
    const audits = await ctx.prisma.auditLog.count();
    for (const bad of [
      textsFile('unknown.json', { quip_gulf_01: 'x', quip_nope: 'y' }),
      textsFile('empty.json', { quip_gulf_02: '  ' }),
      textsFile('broken.json', '{"quip_gulf_02": '),
    ]) {
      const res = giftAdmin('quips-sync', '--texts', bad);
      expect(res.status, res.out).toBe(1);
    }
    expect(giftAdmin('quips-sync', '--nope').status).toBe(1);
    expect(await ctx.prisma.auditLog.count()).toBe(audits);
    // null removes a text.
    const clear = giftAdmin('quips-sync', '--texts', textsFile('clear.json', { quip_jordan_04: null }));
    expect(clear.out).toContain('1 updated (quip_jordan_04)');
    expect((await catalogue(u)).find((g) => g.code === 'quip_jordan_04')?.quip?.text).toBeNull();
  });
});
