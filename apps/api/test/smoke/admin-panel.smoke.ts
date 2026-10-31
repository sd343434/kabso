/**
 * D191: serves the API for the admin panel's Playwright smoke (apps/admin/e2e/smoke.spec.ts) — the real app on
 * PostgreSQL + Redis (the *_test database is reset), with the in-memory object storage. Seeds a not-yet-enrolled
 * OWNER (its email and password go to SMOKE_FILE), a pending recharge-agent application with its two private
 * pictures, a pending cherry withdrawal and two open reports, then listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE
 * is removed (or an hour passes).
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { createAgencyByAdmin } from '../../src/modules/economy/agency-admin.js';
import { seedDefaultTaskPoolIn, seedDefaultTasksIn } from '../../src/modules/programs/programs-seed.js';
import { OBJECT_STORAGE } from '../../src/modules/media/object-storage.js';
import { privateKeyOf } from '../../src/modules/recharge/recharge-core.js';
import { MemoryObjectStorage } from '../helpers/memory-storage.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

it('serves the admin panel smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const storage = new MemoryObjectStorage();
  const ctx = await createTestApp(
    {
      ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
      RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:5180/media-not-served',
      RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
    },
    [{ token: OBJECT_STORAGE, value: storage }],
  );
  const signup = async (displayName: string) => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const id = res.body.user.id as string;
    await ctx.prisma.userProfile.update({ where: { userId: id }, data: { displayName } });
    return {
      id,
      email: payload.email,
      password: payload.password,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };

  const owner = await signup('مالك كابسو');
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, owner.email, 'OWNER')));

  // A pending application with two private pictures (drawn here: no real person).
  const applicant = await signup('سارة محمد');
  const appId = randomUUID();
  const picture = (bg: string) =>
    sharp({ create: { width: 480, height: 320, channels: 3, background: bg } })
      .composite([
        {
          input: Buffer.from(
            `<svg width="480" height="320"><rect x="40" y="40" width="140" height="180" rx="12" fill="#ffffff" opacity="0.8"/><rect x="210" y="70" width="220" height="22" fill="#ffffff" opacity="0.7"/><rect x="210" y="120" width="180" height="22" fill="#ffffff" opacity="0.7"/><rect x="210" y="170" width="200" height="22" fill="#ffffff" opacity="0.7"/></svg>`,
          ),
        },
      ])
      .webp()
      .toBuffer();
  storage.putRaw(privateKeyOf(appId, 'photo'), await picture('#3b5b8a'), 'image/webp');
  storage.putRaw(privateKeyOf(appId, 'selfie'), await picture('#6a4b8a'), 'image/webp');
  await ctx.prisma.rechargeAgentApplication.create({
    data: {
      id: appId,
      userId: applicant.id,
      fullName: 'سارة محمد علي',
      phone: '+201001112223',
      photoKey: privateKeyOf(appId, 'photo'),
      selfieKey: privateKeyOf(appId, 'selfie'),
      locations: [{ country: 'EG', cities: ['Cairo', 'Giza'] }],
      paymentMethods: [{ country: 'EG', type: 'VODAFONE_CASH' }],
    },
  });

  // A pending withdrawal (gift cherries, then the real request).
  const host = await signup('مضيف تجريبي');
  await ctx.prisma.$transaction(async (tx) => {
    const w = await tx.cherryWallet.upsert({
      where: { userId: host.id },
      create: { userId: host.id, cherries: 25_000_000n },
      update: {},
    });
    await tx.cherryLedgerEntry.create({
      data: {
        userId: host.id,
        delta: 25_000_000n,
        balanceAfter: w.cherries,
        reason: 'GIFT_RECEIVED',
        referenceId: randomUUID(),
      },
    });
  });
  const wd = await ctx.http
    .post('/api/v1/wallet/me/cherries/withdrawals')
    .set('Authorization', `Bearer ${host.token}`)
    .set('Idempotency-Key', randomUUID())
    .send({ amountMinor: 2000, payoutDetails: 'Vodafone Cash 0100 111 2223' });
  expect(wd.status).toBe(201);

  // Two open reports.
  const reporter = await signup('مستخدم مبلّغ');
  const rude = await signup('حساب مخالف');
  await ctx.prisma.userProfile.update({
    where: { userId: rude.id },
    data: { bio: 'رسائل مزعجة متكررة في التعليقات' },
  });
  for (const [target, reason, note] of [
    [rude.username, 'SPAM', 'يرسل روابط مزعجة'],
    [host.username, 'HARASSMENT', 'إساءة في البث'],
  ] as const) {
    const r = await ctx.http
      .post('/api/v1/reports')
      .set('Authorization', `Bearer ${reporter.token}`)
      .send({ targetType: 'USER', targetId: target, reason, note });
    expect(r.status).toBe(201);
  }

  // ---- D197 (panel v2): 30 days of synthetic activity for the dashboard, agencies, lives, gifts, money, team.
  // Every name is invented; no real person, photo or third-party art.
  let extra: Record<string, string> = {};
  if (process.env.SMOKE_V2 === '1') {
    const DAY = 86_400_000;
    const now = Date.now();
    const rnd = (() => {
      let x = 197;
      return () => (x = (x * 1103515245 + 12345) % 2 ** 31) / 2 ** 31;
    })();
    const names = [
      'ليان',
      'يوسف',
      'نور',
      'سلمان',
      'مها',
      'كريم',
      'جود',
      'فارس',
      'ريم',
      'هادي',
      'دانة',
      'عمر',
      'لمى',
      'زياد',
      'تالا',
      'سيف',
    ];
    const people: string[] = [];
    for (let i = 0; i < 64; i++) {
      const at = new Date(now - Math.floor(rnd() * 30) * DAY - Math.floor(rnd() * 20) * 3_600_000);
      const u = await ctx.prisma.user.create({
        data: {
          email: `seed${i}@example.test`,
          passwordHash: 'x',
          createdAt: at,
          lastActiveAt: new Date(now - Math.floor(rnd() * 5) * DAY),
          profile: {
            create: {
              username: `kabso_fan${String(i).padStart(2, '0')}`,
              displayName: `${names[i % names.length]} ${i + 1}`,
              countryCode: ['SA', 'EG', 'AE', 'KW', 'JO'][i % 5]!,
            },
          },
        },
      });
      people.push(u.id);
    }
    // A recharge agent with daily sales and top-ups.
    const agent = people[0]!;
    const appId = randomUUID();
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id: appId,
        userId: agent,
        status: 'APPROVED',
        decidedAt: new Date(now - 40 * DAY),
        purgedAt: new Date(now - 39 * DAY),
      },
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: agent,
        applicationId: appId,
        status: 'ACTIVE',
        code: 'coin0001',
        codeNumber: 1,
        stockCoins: 42_000_000n,
        countries: ['SA'],
        locations: [],
        paymentTypes: [],
        activatedAt: new Date(now - 38 * DAY),
      },
    });
    await ctx.prisma.gift.createMany({
      data: [
        ['rose', 'وردة', 'Rose', 10, 'POPULAR'],
        ['heart', 'قلب', 'Heart', 99, 'POPULAR'],
        ['crown', 'تاج', 'Crown', 2999, 'EVENT'],
        ['rocket', 'صاروخ', 'Rocket', 9999, 'FUN'],
        ['lucky_cat', 'قط الحظ', 'Lucky cat', 50, 'LUCKY'],
        ['castle', 'قلعة', 'Castle', 49999, 'EVENT'],
      ].map(([code, nameAr, nameEn, price, category], i) => ({
        code: code as string,
        nameAr: nameAr as string,
        nameEn: nameEn as string,
        priceCoins: price as number,
        category: category as 'POPULAR',
        assetKey: `gifts/${code as string}`,
        sortOrder: i,
        badge: i === 2 ? ('NEW' as const) : ('NONE' as const),
      })),
    });
    for (let d = 29; d >= 0; d--) {
      const day = (h: number) => new Date(now - d * DAY - h * 3_600_000);
      const growth = 1 + (29 - d) / 20;
      for (let k = 0; k < 2 + Math.floor(rnd() * 3); k++) {
        await ctx.prisma.rechargeSale.create({
          data: {
            agentUserId: agent,
            sellerUserId: agent,
            buyerUserId: people[1 + Math.floor(rnd() * 60)]!,
            clientId: randomUUID(),
            coins: BigInt(Math.round((200_000 + rnd() * 900_000) * growth)),
            createdAt: day(rnd() * 10),
          },
        });
      }
      if (d % 6 === 0) {
        const coins = 30_000_000n;
        await ctx.prisma.rechargeTopup.create({
          data: {
            agentUserId: agent,
            coins,
            tier: 'T1',
            pricePerMillionMinor: 1200,
            expectedMinor: 36_000n,
            paidMinor: 36_000n,
            currency: 'USD',
            first: d === 24,
            createdAt: day(3),
          },
        });
      }
      for (let k = 0; k < Math.floor(rnd() * 3); k++) {
        const buyer = people[1 + Math.floor(rnd() * 60)]!;
        const terms = randomUUID();
        await ctx.prisma.topupTermsAcceptance.create({
          data: {
            id: terms,
            userId: buyer,
            termsVersion: 'smoke',
            termsText: 'العملات رقمية وغير قابلة للاسترداد',
            locale: 'ar',
            acceptedAt: day(2),
          },
        });
        const pkg = [1_000_000, 5_000_000, 10_000_000][Math.floor(rnd() * 3)]!;
        await ctx.prisma.topupOrder.create({
          data: {
            id: randomUUID(),
            userId: buyer,
            termsAcceptanceId: terms,
            packageId: String(pkg),
            coins: BigInt(pkg),
            amountMinor: Math.round(pkg * 0.00125),
            currency: 'USD',
            paymentMethodTypes: ['card'],
            paymentMethodType: 'card',
            status: 'PAID',
            stripePaymentIntentId: `pi_smoke_${randomUUID().slice(0, 8)}`,
            creditedAt: day(1),
            createdAt: day(1.1),
          },
        });
      }
      const gifts = ['rose', 'heart', 'crown', 'rocket', 'castle'];
      for (let k = 0; k < 4 + Math.floor(rnd() * 6 * growth); k++) {
        const code = gifts[Math.floor(rnd() * gifts.length)]!;
        const price = { rose: 10, heart: 99, crown: 2999, rocket: 9999, castle: 49999 }[code]!;
        const q = 1 + Math.floor(rnd() * 5);
        await ctx.prisma.liveGift.create({
          data: {
            senderId: people[Math.floor(rnd() * 60)]!,
            clientId: randomUUID(),
            giftCode: code,
            quantity: q,
            source: 'COINS',
            unitPrice: price,
            totalCoins: BigInt(price * q),
            coinsCharged: BigInt(price * q),
            recipientsKey: people[63]!,
            comboId: randomUUID(),
            comboCount: 1,
            comboQuantity: BigInt(q),
            hostShareBps: 5000,
            createdAt: day(rnd() * 12),
          },
        });
      }
      if (d % 9 === 0) {
        await ctx.prisma.cherryWithdrawal.create({
          data: {
            userId: people[62]!,
            clientId: randomUUID(),
            cherries: 9_090_909n,
            amountMinor: 1000n,
            currency: 'USD',
            rateCherries: 1_000_000n,
            rateMinor: 110,
            payoutDetails: 'Bank transfer (synthetic)',
            status: 'PAID',
            createdAt: day(30),
            decidedAt: day(2),
            decisionNote: 'ref: SMOKE',
          },
        });
      }
    }
    // Lives on air.
    const titles = [
      'سهرة طرب',
      'تحدي المواهب',
      'دردشة الصباح',
      'قصص وحكايات',
      'مسابقة الأسئلة',
      'ليلة الشعر',
    ];
    for (let i = 0; i < titles.length; i++) {
      await ctx.prisma.liveHost.create({
        data: { userId: people[40 + i]!, source: i % 2 ? 'AGENCY' : 'ADMIN' },
      });
      await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: people[40 + i]!,
          title: titles[i]!,
          viewerCount: Math.floor(30 + rnd() * 900),
          startedAt: new Date(now - (10 + i * 23) * 60_000),
          lastHeartbeatAt: new Date(now),
        },
      });
    }
    // Agencies through the CLI's rule, with hosts and month totals.
    const agencyIds: string[] = [];
    for (const i of [50, 51, 52]) {
      const created = await createAgencyByAdmin(
        ctx.prisma,
        { ownerUserId: people[i]!, parentInviteCode: null, reason: 'smoke seed' },
        { timeZone: 'Asia/Riyadh', specialGraceDays: 30 },
      );
      agencyIds.push(created.agencyId);
      for (let h = 0; h < 4; h++) {
        await ctx.prisma.agencyHost.create({
          data: {
            agencyId: created.agencyId,
            hostUserId: people[10 + (i - 50) * 5 + h]!,
            commissionEligible: true,
          },
        });
      }
      for (let m = 0; m < 4; m++) {
        const date = new Date(now);
        await ctx.prisma.agencyMonth.create({
          data: {
            agencyId: created.agencyId,
            month: new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() - m, 1)),
            hostCherries: BigInt(Math.round(5_000_000 + rnd() * 40_000_000)),
            commission: BigInt(Math.round(400_000 + rnd() * 3_000_000)),
          },
        });
      }
    }
    const link = await ctx.prisma.agencyHost.findFirstOrThrow({ where: { agencyId: agencyIds[0]! } });
    await ctx.prisma.agencyComplaint.create({
      data: {
        agencyHostId: link.id,
        hostUserId: link.hostUserId,
        agencyId: agencyIds[0]!,
        text: 'لم تصلني عمولة الأسبوع الماضي، أطلب مراجعة الحساب.',
      },
    });
    await ctx.prisma.bagItem.createMany({
      data: [
        {
          code: 'frame_gold',
          category: 'AVATAR_FRAME',
          nameAr: 'إطار ذهبي',
          nameEn: 'Gold frame',
          assetKey: 'frames/gold',
          sortOrder: 1,
        },
        {
          code: 'frame_ruby',
          category: 'AVATAR_FRAME',
          nameAr: 'إطار ياقوتي',
          nameEn: 'Ruby frame',
          assetKey: 'frames/ruby',
          sortOrder: 2,
        },
        {
          code: 'host_frame_blue',
          category: 'AVATAR_FRAME',
          nameAr: 'إطار المضيف',
          nameEn: 'Host frame',
          assetKey: 'frames/host_blue',
          sortOrder: 3,
        },
        {
          code: 'card_night',
          category: 'PROFILE_CARD',
          nameAr: 'بطاقة الليل',
          nameEn: 'Night card',
          assetKey: 'cards/night',
          sortOrder: 1,
        },
      ],
    });
    await ctx.prisma.event.create({
      data: {
        titleAr: 'تحدي الهدايا الأسبوعي',
        titleEn: 'Weekly gift challenge',
        rulesAr: '',
        rulesEn: '',
        startsAt: new Date(now - 2 * DAY),
        endsAt: new Date(now + 5 * DAY),
        metric: 'GIFT_COINS_RECEIVED',
        featured: true,
        prizes: [{ rankFrom: 1, rankTo: 1, coins: 5000 }],
      },
    });
    await ctx.prisma.$transaction(async (tx) => {
      await seedDefaultTasksIn(tx);
      await seedDefaultTaskPoolIn(tx);
    });
    for (const [i, locale] of ['ar', 'ar', 'en', 'ar', 'en'].entries()) {
      await ctx.prisma.waitlistSignup.create({ data: { email: `launch${i}@example.test`, locale } });
    }
    // Two more team members (granted with the CLI rule) for the team page.
    for (const [i, role] of [
      [60, 'SUPPORT'],
      [61, 'FINANCE'],
    ] as const) {
      const email = `seed${i}@example.test`;
      await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, email, role)));
    }
    extra = { teamRecruit: 'seed59@example.test', liveTitle: titles[0]! };
  }

  writeFileSync(
    file,
    JSON.stringify({
      email: owner.email,
      password: owner.password,
      applicant: applicant.username,
      applicationId: appId,
      ...extra,
    }),
    { mode: 0o600 },
  );
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  let beat = 0;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
    // D197: the seeded hosts keep their lives alive (their apps would send heartbeats).
    if (process.env.SMOKE_V2 === '1' && ++beat % 20 === 0) {
      await ctx.prisma.liveRoom.updateMany({
        where: { status: 'LIVE' },
        data: { lastHeartbeatAt: new Date() },
      });
    }
  }
  await ctx.close();
});
