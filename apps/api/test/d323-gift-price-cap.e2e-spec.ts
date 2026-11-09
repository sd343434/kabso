/**
 * D323 (owner 2026-11-08: «تاج الافتتاح» at 3 000 000 coins was refused by the panel with "Value must be less than or
 * equal to 1000000"; then «السقف 100,000,000»; contract v1.91-live, CONVENTIONS §10.23): a gift costs 1 … 100 000 000
 * coins — the panel API, the CLI rules and the DB CHECK `gifts_price_range` agree — and the largest send of such a gift
 * (100 000 000 × 1 314, the top default quantity, × 25 recipients = 3 285 000 000 000 coins) is charged and credited
 * exactly everywhere it counts: the wallet and its ledger, the send rows, the cherries and the agency commission, the
 * live score / popularity / Contribution points (× 100), the hourly and monthly boards, the family, the medal and
 * «الأغنى» totals, the levels — and the reports that multiply a recipient's coins by the send's charge (host targets,
 * recruits) no longer overflow BIGINT.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { FAMILY_CREATE_COST_COINS } from '../src/modules/families/families.constants.js';
import {
  addGiftIn,
  GIFT_MAX_PRICE,
  giftFieldProblems,
  type GiftFields,
} from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { HostTargetsService } from '../src/modules/programs/host-targets.service.js';
import { recruitProfitIn } from '../src/modules/recruits/recruit-core.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

class RealClock extends Clock {
  now(): Date {
    return new Date();
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 200, g: 160, b: 40, alpha: 1 } } })
    .png()
    .toBuffer();

const PRICE = 100_000_000;
const QUANTITY = 1314;
const RECIPIENTS = 25;
const PER_RECIPIENT = PRICE * QUANTITY; // 131 400 000 000
const TOTAL = PER_RECIPIENT * RECIPIENTS; // 3 285 000 000 000
const POINTS = TOTAL * 100; // 328 500 000 000 000 (< 2^53)

describe('D323 gift price cap 100 000 000 and the largest send', { timeout: 600_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let admin: Admin;

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
  const upload = async (code: string) => {
    const res = await ctx.http
      .post(`/api/v1/admin/gift-uploads?kind=image&code=${code}`)
      .set('Cookie', admin.cookie)
      .set('X-CSRF-Token', admin.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(await png(256, 256));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.key as string;
  };
  const enter = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const publishLevels = async (code: 'ATTRACTIVENESS' | 'SUPPORT') => {
    const category = await ctx.prisma.levelCategory.create({
      data: { code, nameAr: 'فئة', nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: { create: [{ levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: 0n }] },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
    return category.id;
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: Date.now() });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        ADMIN_DASHBOARD_TIME_ZONE: 'UTC',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: new RealClock() },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
    admin = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  describe('the cap: 1 … 100 000 000 in the panel API, the CLI rules and the database', () => {
    const create = async (code: string, priceCoins: number) =>
      p.send(admin, 'post', '/admin/gifts', {
        code,
        category: 'POPULAR',
        nameAr: 'تاج الافتتاح',
        nameEn: 'Opening Crown',
        priceCoins,
        imageObjectKey: await upload(code),
        reason: 'D323 opening crown',
      });

    it('creates a 3 000 000-coin gift «تاج الافتتاح» and a 100 000 000-coin gift', async () => {
      const crown = await create('d323_crown', 3_000_000);
      expect(crown.status, JSON.stringify(crown.body)).toBe(201);
      expectContract(crown, 'createAdminGift');
      const top = await create('d323_top', 100_000_000);
      expect(top.status, JSON.stringify(top.body)).toBe(201);
      expectContract(top, 'createAdminGift');
      const rows = await ctx.prisma.gift.findMany({
        where: { code: { in: ['d323_crown', 'd323_top'] } },
        select: { code: true, priceCoins: true },
        orderBy: { code: 'asc' },
      });
      expect(rows).toEqual([
        { code: 'd323_crown', priceCoins: 3_000_000 },
        { code: 'd323_top', priceCoins: 100_000_000 },
      ]);
      // The catalogue the apps read shows the price as is.
      const viewer = await signup();
      const catalogue = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(viewer));
      expect(catalogue.status).toBe(200);
      const listed = (catalogue.body.data as { code: string; priceCoins: number }[]).filter((g) =>
        g.code.startsWith('d323_'),
      );
      expect(listed.map((g) => [g.code, g.priceCoins]).sort()).toEqual([
        ['d323_crown', 3_000_000],
        ['d323_top', 100_000_000],
      ]);
    });

    it('refuses 100 000 001 on create and on edit (400), nothing stored', async () => {
      const over = await create('d323_over', 100_000_001);
      expect(over.status).toBe(400);
      expect(over.body.error.code).toBe('VALIDATION_FAILED');
      expect(over.body.error.details).toEqual(
        expect.arrayContaining([expect.objectContaining({ field: 'priceCoins' })]),
      );
      expect(await ctx.prisma.gift.count({ where: { code: 'd323_over' } })).toBe(0);
      const edit = await p.send(admin, 'patch', '/admin/gifts/d323_crown', {
        priceCoins: 100_000_001,
        reason: 'too much',
      });
      expect(edit.status).toBe(400);
      expect((await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd323_crown' } })).priceCoins).toBe(
        3_000_000,
      );
      // An edit up to the cap is accepted.
      const up = await p.send(admin, 'patch', '/admin/gifts/d323_crown', {
        priceCoins: 100_000_000,
        reason: 'max',
      });
      expect(up.status, JSON.stringify(up.body)).toBe(200);
      expect((await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd323_crown' } })).priceCoins).toBe(
        100_000_000,
      );
      const back = await p.send(admin, 'patch', '/admin/gifts/d323_crown', {
        priceCoins: 3_000_000,
        reason: 'back',
      });
      expect(back.status).toBe(200);
    });

    it('the CLI rules (addGiftIn) and the DB CHECK gifts_price_range stop at 100 000 000', async () => {
      const fields: GiftFields = {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: GIFT_MAX_PRICE + 1,
        assetKey: 'gift_d323',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      };
      // `gift-admin add|update` checks the fields first (giftFieldProblems), with the same bound as the API.
      expect(giftFieldProblems({ priceCoins: GIFT_MAX_PRICE })).toEqual([]);
      expect(giftFieldProblems(fields)).toEqual([
        'price must be a whole number of coins from 1 to 100000000 (0: a free QUIPS gift)',
      ]);
      // Past them, the database refuses it.
      await expect(ctx.prisma.$transaction((tx) => addGiftIn(tx, 'd323_cli_over', fields))).rejects.toThrow(
        /gifts_price_range/,
      );
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, 'd323_cli_max', { ...fields, priceCoins: GIFT_MAX_PRICE }),
      );
      // The database itself (even past the API): 100 000 001 breaks the CHECK, 100 000 000 passes.
      await withMigrationClient(async (db) => {
        await expect(
          db.$executeRawUnsafe(`UPDATE gifts SET price_coins = 100000001 WHERE code = 'd323_cli_max'`),
        ).rejects.toThrow(/gifts_price_range/);
        await expect(
          db.$executeRawUnsafe(
            `INSERT INTO gifts (code, category, name_ar, name_en, price_coins, asset_key)
             VALUES ('d323_sql_over', 'POPULAR', 'x', 'x', 100000001, 'gift_x')`,
          ),
        ).rejects.toThrow(/gifts_price_range/);
        expect(
          await db.$executeRawUnsafe(`UPDATE gifts SET price_coins = 100000000 WHERE code = 'd323_cli_max'`),
        ).toBe(1);
        // The other branches are unchanged: 0 only for a free quip, never below 0.
        await expect(
          db.$executeRawUnsafe(`UPDATE gifts SET price_coins = 0 WHERE code = 'd323_cli_max'`),
        ).rejects.toThrow(/gifts_price_range/);
      });
    });
  });

  describe('the largest send: 100 000 000 × 1 314 × 25 recipients', () => {
    it('charges and credits 3 285 000 000 000 coins exactly everywhere (no 32-bit or BIGINT overflow)', async () => {
      const attractiveness = await publishLevels('ATTRACTIVENESS');
      const support = await publishLevels('SUPPORT');
      // The host belongs to an agency (cherries → commission), the sender to a family.
      const host = await signup();
      await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
      const agencyOwner = await signup();
      const agency = await ctx.prisma.agency.create({
        data: {
          ownerUserId: agencyOwner.id,
          inviteCode: 'D323AGCX',
          evaluateFrom: new Date('2020-01-01T00:00:00Z'),
        },
      });
      await ctx.prisma.agencyHost.create({
        data: { agencyId: agency.id, hostUserId: host.id, commissionEligible: true, activatedAt: new Date() },
      });
      const live = await ctx.http
        .post('/api/v1/live/rooms')
        .set(auth(host))
        .send({ title: 'Max', mode: 'AUDIO', seatCount: 20 });
      expect(live.status, JSON.stringify(live.body)).toBe(201);
      const roomId = live.body.id as string;
      // 24 seated guests (a room started with 25 tiles before D123 keeps seats 1 … 24): 25 recipients with the host.
      await ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { seatCount: 25 } });
      const guests: TestUser[] = [];
      for (let i = 1; i <= 24; i++) {
        const g = await signup();
        await enter(roomId, g);
        await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: i, userId: g.id } });
        guests.push(g);
      }
      const sender = await signup();
      await enter(roomId, sender);
      const extra = 7;
      await ctx.prisma.$transaction((tx) =>
        creditIn(
          tx,
          sender.id,
          BigInt(TOTAL + FAMILY_CREATE_COST_COINS + extra),
          'ADMIN_GRANT',
          randomUUID(),
        ),
      );
      const fam = await ctx.http
        .post('/api/v1/families')
        .set(auth(sender))
        .send({ name: `D323${randomUUID().slice(0, 6)}`, clientId: randomUUID() });
      expect(fam.status, JSON.stringify(fam.body)).toBe(201);
      const familyId = fam.body.family.id as string;
      const familyBefore = (await ctx.prisma.family.findUniqueOrThrow({ where: { id: familyId } })).points;

      const recipients = [host, ...guests];
      const res = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/gifts`)
        .set(auth(sender))
        .send({
          giftCode: 'd323_top',
          quantity: QUANTITY,
          recipients: recipients.map((u) => u.username),
          source: 'COINS',
          clientId: randomUUID(),
        });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveGift');
      expect(res.body.gift).toMatchObject({ unitPrice: PRICE, quantity: QUANTITY, totalCoins: TOTAL });
      expect(res.body.coins).toBe(extra);
      const giftId = res.body.gift.id as string;

      // The wallet and its ledger.
      expect((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: sender.id } })).coins).toBe(
        BigInt(extra),
      );
      const debit = await ctx.prisma.walletLedgerEntry.findFirstOrThrow({
        where: { userId: sender.id, reason: 'LIVE_GIFT', referenceId: giftId },
      });
      expect(debit.delta).toBe(BigInt(-TOTAL));
      expect(debit.balanceAfter).toBe(BigInt(extra));
      // The send and its recipients.
      const row = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: giftId } });
      expect([row.unitPrice, row.quantity, row.totalCoins, row.coinsCharged]).toEqual([
        PRICE,
        QUANTITY,
        BigInt(TOTAL),
        BigInt(TOTAL),
      ]);
      const recipientRows = await ctx.prisma.liveGiftRecipient.findMany({ where: { giftId } });
      expect(recipientRows).toHaveLength(RECIPIENTS);
      expect(new Set(recipientRows.map((r) => r.coins))).toEqual(new Set([BigInt(PER_RECIPIENT)]));
      // Cherries: floor(coins × share × 10) each; the agency's commission on the host's; the room's cherries.
      const share = BigInt(row.hostShareBps);
      const cherriesEach = (BigInt(PER_RECIPIENT) * share * 10n) / 10_000n;
      expect(cherriesEach).toBe(854_100_000_000n); // 65 %
      for (const u of recipients) {
        expect((await ctx.prisma.cherryWallet.findUniqueOrThrow({ where: { userId: u.id } })).cherries).toBe(
          cherriesEach,
        );
      }
      const earning = await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { giftId } });
      expect(earning.hostCherries).toBe(cherriesEach);
      expect(earning.commission).toBe((cherriesEach * BigInt(earning.rateBps)) / 10_000n);
      const ownerCherries = (await ctx.prisma.cherryWallet.findUnique({ where: { userId: agencyOwner.id } }))
        ?.cherries;
      expect(ownerCherries ?? 0n).toBe(earning.commission);
      const room = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } });
      expect(room.score).toBe(BigInt(POINTS));
      expect(room.cherries).toBe(cherriesEach * BigInt(RECIPIENTS));
      const score = await ctx.prisma.liveRoomScore.findUniqueOrThrow({ where: { roomId } });
      expect(score.supportPoints).toBe(BigInt(POINTS));
      expect(score.hostCherries).toBe(cherriesEach);
      // Popularity (hourly, monthly) and the sender's Contribution.
      const hourly = await ctx.prisma.liveHostPointsHourly.findMany({ where: { hostUserId: host.id } });
      expect(hourly.map((h) => h.points)).toEqual([BigInt(POINTS)]);
      const monthly = await ctx.prisma.liveHostPointsMonthly.findMany({ where: { hostUserId: host.id } });
      expect(monthly.map((h) => h.points)).toEqual([BigInt(POINTS)]);
      const tapper = await ctx.prisma.liveRoomTapper.findUniqueOrThrow({
        where: { roomId_userId: { roomId, userId: sender.id } },
      });
      expect([tapper.supportCoins, tapper.points]).toEqual([BigInt(TOTAL), BigInt(POINTS)]);
      // The family, the medal total and «الأغنى».
      expect((await ctx.prisma.family.findUniqueOrThrow({ where: { id: familyId } })).points).toBe(
        familyBefore + BigInt(TOTAL),
      );
      const famEntry = await ctx.prisma.familyPointsEntry.findFirstOrThrow({
        where: { walletLedgerId: debit.id },
      });
      expect(famEntry.points).toBe(BigInt(TOTAL));
      const medal = await withMigrationClient(
        (db) =>
          db.$queryRaw<{ value: bigint }[]>`
          SELECT value FROM medal_metric_totals WHERE user_id = ${sender.id}::uuid AND metric = 'GIFTS_SENT_COINS'`,
      );
      expect(medal.map((m) => m.value)).toEqual([BigInt(TOTAL)]);
      const rich = await withMigrationClient(
        (db) =>
          db.$queryRaw<{ h: bigint; m: bigint }[]>`
          SELECT (SELECT sum(coins) FROM gift_coins_sent_hourly WHERE user_id = ${sender.id}::uuid)::bigint AS h,
                 (SELECT sum(coins) FROM gift_coins_sent_monthly WHERE user_id = ${sender.id}::uuid)::bigint AS m`,
      );
      expect(rich).toEqual([{ h: BigInt(TOTAL), m: BigInt(TOTAL) }]);
      // Levels: the host's charm counts its 131 400 000 000 coins (× 1), the sender's support all 25.
      const level = async (userId: string, categoryId: string) =>
        (
          await ctx.prisma.userLevelState.findUniqueOrThrow({
            where: { userId_categoryId: { userId, categoryId } },
          })
        ).lifetimeEarnedPoints;
      expect(await level(host.id, attractiveness)).toBe(BigInt(PER_RECIPIENT));
      expect(await level(guests[23]!.id, attractiveness)).toBe(BigInt(PER_RECIPIENT));
      expect(await level(sender.id, support)).toBe(BigInt(TOTAL));

      // The public numbers read back as exact integers.
      const popularity = await ctx.http.get('/api/v1/live/rankings?board=POPULARITY&period=MONTH');
      expect(popularity.status, JSON.stringify(popularity.body)).toBe(200);
      expectContract(popularity, 'listLiveRankings');
      expect(
        (popularity.body.data as { host: { id: string }; points: number }[]).find(
          (e) => e.host.id === host.id,
        )?.points,
      ).toBe(POINTS);
      const richBoard = await ctx.http.get('/api/v1/live/rankings?board=RICH&period=DAY');
      expect(richBoard.status, JSON.stringify(richBoard.body)).toBe(200);
      expect(
        (richBoard.body.data as { host: { id: string }; points: number }[]).find(
          (e) => e.host.id === sender.id,
        )?.points,
      ).toBe(TOTAL);
      const stats = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stats`).set(auth(host));
      expect(stats.status, JSON.stringify(stats.body)).toBe(200);

      // A recipient's coins × the send's charge passes BIGINT: the old expression fails, the reports now use numeric.
      await expect(
        withMigrationClient(
          (db) =>
            db.$queryRaw`
            SELECT (gr.coins * g.coins_charged) / g.total_coins AS charged
              FROM live_gift_recipients gr JOIN live_gifts g ON g.id = gr.gift_id
             WHERE g.id = ${giftId}::uuid`,
        ),
      ).rejects.toThrow(/bigint out of range/);
      const targets = ctx.app.get(HostTargetsService);
      const from = new Date(Date.now() - 3_600_000);
      const to = new Date(Date.now() + 3_600_000);
      const sends = await (
        targets as unknown as {
          sendsIn(
            db: unknown,
            host: string,
            from: Date,
            to: Date,
          ): Promise<{ coins: bigint; charged: bigint }[]>;
        }
      ).sendsIn(ctx.prisma, host.id, from, to);
      expect(sends.map((s) => [s.coins, s.charged])).toEqual([
        [BigInt(PER_RECIPIENT), BigInt(PER_RECIPIENT)],
      ]);
      const profit = await recruitProfitIn(
        ctx.prisma,
        { type: 'HOST', recruitUserId: host.id, agencyId: null },
        from,
        to,
        targets.economy(),
        'USD',
      );
      expect(profit.count).toBe(1);
      expect(typeof profit.units).toBe('bigint');
    });
  });
});
