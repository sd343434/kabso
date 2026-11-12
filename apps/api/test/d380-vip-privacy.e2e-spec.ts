/**
 * D380 (owner 2026-11-11; contract v1.133-social, CONVENTIONS §10.170): the VIP privacy perks — HIDDEN_VISIT,
 * RANKING_ANONYMOUS, KICK_MUTE_SHIELD and ANONYMOUS_GIFT, each for a member whose effective perks hold it (inheritance
 * from a lower tier included) while the membership is active, with the holder's switch. End to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const VIP1 = '01a25200-0000-7000-8000-000000000001';
/** A higher tier with no perks of its own: it holds VIP 1's (D258 inheritance). */
const VIP2 = '01a38000-0000-7000-8000-000000000002';
const PERKS = ['HIDDEN_VISIT', 'RANKING_ANONYMOUS', 'KICK_MUTE_SHIELD', 'ANONYMOUS_GIFT'] as const;
const DAY = 86_400_000;

interface U {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D380 contract coverage', () => {
  it('openapi v1.133-social declares the gift report and the anonymous-gift refusal', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'reportLiveGift POST /api/v1/live/gifts/{giftId}/reports',
      'blockAnonymousGiftSender PUT /api/v1/live/gifts/{giftId}/anonymous-block',
      'unblockAnonymousGiftSender DELETE /api/v1/live/gifts/{giftId}/anonymous-block',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D380 VIP privacy perks', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let giftCode = '';

  const auth = (u: U) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<U> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  /** `u` holds [tier] until a month from now. */
  const member = async (u: U, tier: string = VIP1) => {
    const now = Date.now();
    await ctx.prisma.vipMembership.upsert({
      where: { userId: u.id },
      create: {
        userId: u.id,
        tierId: tier,
        startedAt: new Date(now - DAY),
        expiresAt: new Date(now + 30 * DAY),
      },
      update: { tierId: tier, expiresAt: new Date(now + 30 * DAY) },
    });
  };
  const expire = (u: U) =>
    ctx.prisma.vipMembership.update({
      where: { userId: u.id },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
  const privacy = async (u: U) => {
    const res = await ctx.http.get('/api/v1/me/privacy').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getPrivacy');
    return res.body as Record<string, unknown>;
  };
  const setPrivacy = (u: U, body: object) => ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send(body);
  const coins = (u: U, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const goLive = async (h: U): Promise<string> => {
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Privacy', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const join = async (roomId: string, u: U) => {
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
  const send = (roomId: string, from: U, to: U[], extra: object = {}): request.Test =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode,
        quantity: 1,
        recipients: to.map((r) => r.username),
        source: 'COINS',
        clientId: randomUUID(),
        ...extra,
      });
  const err = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_RANKINGS_TIME_ZONE: 'UTC' },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    // VIP 1 holds the four perks; VIP 2 (ranked above it) has none of its own and inherits them.
    await withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(`
        INSERT INTO vip_tiers (id, code, name_ar, name_en, sort_order, color, price_coins, duration_days, enabled)
          VALUES ('${VIP2}', 'VIP_2', 'في آي بي 2', 'VIP 2', 2, '#1E5AA8', 2000000, 30, true)
          ON CONFLICT (id) DO NOTHING`);
      for (const [i, code] of PERKS.entries()) {
        await db.$executeRawUnsafe(
          `INSERT INTO vip_tier_perks (id, tier_id, code, title_ar, title_en, sort_order, enabled)
             VALUES ('${randomUUID()}', '${VIP1}', '${code}', '${code}', '${code}', ${String(40 + i)}, true)
             ON CONFLICT DO NOTHING`,
        );
      }
    });
    giftCode = `d380_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, giftCode, {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10,
        assetKey: `gift_${giftCode}`,
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  });
  afterAll(async () => ctx?.close());

  it('the switches: only while held (inherited too), with their defaults; kept when the membership ends', async () => {
    const plain = await signup();
    expect(Object.keys(await privacy(plain))).not.toContain('hiddenVisit');
    const refused = await setPrivacy(plain, { hiddenVisit: false, hideCoinsSent: true });
    err(refused, 409, 'VIP_UNAVAILABLE');
    expect(refused.body.error.details).toEqual([{ field: 'hiddenVisit', issue: 'no_perk' }]);
    // Nothing changed (the plain field of the same request included).
    expect((await privacy(plain)).hideCoinsSent).toBe(false);

    const holder = await signup();
    await member(holder, VIP2);
    expect(await privacy(holder)).toMatchObject({
      hiddenVisit: true,
      rankingAnonymous: false,
      kickMuteShield: true,
    });
    const ok = await setPrivacy(holder, { rankingAnonymous: true, kickMuteShield: false });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'updatePrivacy');
    expect(ok.body).toMatchObject({ hiddenVisit: true, rankingAnonymous: true, kickMuteShield: false });
    await expire(holder);
    expect(Object.keys(await privacy(holder))).not.toContain('rankingAnonymous');
    await member(holder);
    expect(await privacy(holder)).toMatchObject({ rankingAnonymous: true, kickMuteShield: false });
  });

  it('HIDDEN_VISIT: a holder with the switch on leaves no visit; off, plain, or expired → recorded', async () => {
    const owner = await signup();
    const visits = (visitor: U) =>
      ctx.prisma.$queryRaw<{ visits: number }[]>`
        SELECT visits FROM profile_visits WHERE owner_id = ${owner.id}::uuid AND visitor_id = ${visitor.id}::uuid`;
    const open = async (visitor: U) => {
      const res = await ctx.http.get(`/api/v1/users/${owner.username}`).set(auth(visitor));
      expect(res.status).toBe(200);
    };
    const hidden = await signup();
    await member(hidden, VIP2); // inherited from VIP 1
    await open(hidden);
    expect(await visits(hidden)).toEqual([]);

    const plain = await signup();
    await open(plain);
    expect(await visits(plain)).toHaveLength(1);

    const off = await signup();
    await member(off);
    expect((await setPrivacy(off, { hiddenVisit: false })).status).toBe(200);
    await open(off);
    expect(await visits(off)).toHaveLength(1);

    await expire(hidden);
    await open(hidden);
    expect(await visits(hidden)).toHaveLength(1);
  });

  it('RANKING_ANONYMOUS: «مجهول» on the contributors and the rich board to others; the member and the host see the real person', async () => {
    const host = await signup();
    const roomId = await goLive(host);
    const hider = await signup();
    const fan = await signup();
    const reader = await signup();
    await member(hider);
    expect((await setPrivacy(hider, { rankingAnonymous: true })).status).toBe(200);
    for (const u of [hider, fan]) {
      await join(roomId, u);
      await coins(u, 10_000);
    }
    await join(roomId, reader);
    expect((await send(roomId, hider, [host], { quantity: 10 })).status).toBe(201);
    expect((await send(roomId, fan, [host])).status).toBe(201);

    const contributors = async (u: U) => {
      const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors`).set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'listLiveContributors');
      return res.body.data as { user: Record<string, unknown>; points: number }[];
    };
    const seen = await contributors(reader);
    expect(seen).toHaveLength(2);
    expect(seen[0]!.user).toMatchObject({
      username: 'kabso.anonymous',
      displayName: 'مجهول',
      avatarUrl: null,
      anonymous: true,
    });
    expect(seen[0]!.user.id).not.toBe(hider.id);
    expect(seen[0]!.user.vip).toBeUndefined();
    expect(seen[1]!.user).toMatchObject({ id: fan.id });
    expect(seen[1]!.user.anonymous).toBeUndefined();
    expect((await contributors(hider))[0]!.user).toMatchObject({ id: hider.id });
    expect((await contributors(host))[0]!.user).toMatchObject({ id: hider.id });
    // One person's standing: not told to others; the host still sees it.
    const standing = (u: U) =>
      ctx.http.get(`/api/v1/live/rooms/${roomId}/contributors/${hider.username}`).set(auth(u));
    const other = await standing(reader);
    expect(other.status).toBe(200);
    expectContract(other, 'getLiveContributor');
    expect(other.body).toMatchObject({ points: 0, rank: null });
    expect((await standing(host)).body).toMatchObject({ rank: 1 });

    // The rich board (coins sent): «مجهول» to the reader, real to the member.
    const rich = async (u: U) => {
      const res = await ctx.http
        .get('/api/v1/live/rankings')
        .query({ board: 'RICH', period: 'DAY' })
        .set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listLiveRankings');
      return res.body.data as { host: Record<string, unknown>; liveRoom: unknown }[];
    };
    const board = await rich(reader);
    expect(board.some((r) => r.host.id === hider.id)).toBe(false);
    expect(board.some((r) => r.host.anonymous === true)).toBe(true);
    expect(board.some((r) => r.host.id === fan.id)).toBe(true);
    expect((await rich(hider)).some((r) => r.host.id === hider.id)).toBe(true);

    // The membership ends: named again for everyone.
    await expire(hider);
    expect((await contributors(reader))[0]!.user).toMatchObject({ id: hider.id });
  });

  it('KICK_MUTE_SHIELD: a moderator is refused (403 VIP_PROTECTED, audited); the host can; plain members and the switch off are unchanged', async () => {
    const host = await signup();
    const roomId = await goLive(host);
    const mod = await signup();
    const shielded = await signup();
    const inherited = await signup();
    const plain = await signup();
    await member(shielded);
    await member(inherited, VIP2);
    for (const u of [mod, shielded, inherited, plain]) await join(roomId, u);
    expect(
      (await ctx.http.put(`/api/v1/live/rooms/${roomId}/moderators/${mod.username}`).set(auth(host))).status,
    ).toBe(200);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: shielded.id } });

    const chatMute = (by: U, target: U) =>
      ctx.http.put(`/api/v1/live/rooms/${roomId}/chat/mutes/${target.username}`).set(auth(by));
    const kick = (by: U, target: U) =>
      ctx.http.post(`/api/v1/live/rooms/${roomId}/kicks`).set(auth(by)).send({ username: target.username });
    const refused = async (res: request.Response, op: string) => {
      err(res, 403, 'VIP_PROTECTED');
      expectContract(res, op);
      expect(res.body.error.details).toEqual([{ field: 'username', issue: 'vip_shield' }]);
    };
    await refused(await chatMute(mod, shielded), 'muteLiveChatUser');
    await refused(await chatMute(mod, inherited), 'muteLiveChatUser');
    await refused(
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/seats/1/mute`).set(auth(mod)).send({ muted: true }),
      'muteLiveSeat',
    );
    await refused(
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/seats/1/remove`).set(auth(mod)),
      'removeFromLiveSeat',
    );
    await refused(await kick(mod, shielded), 'kickFromLive');
    expect(await ctx.prisma.liveRoomSeat.count({ where: { roomId, userId: shielded.id } })).toBe(1);
    const audits = await withMigrationClient((db) =>
      db.auditLog.findMany({
        where: { action: 'vip.shield.refused', targetId: { in: [shielded.id, inherited.id] } },
      }),
    );
    expect(audits.map((a) => (a.metadata as { action: string }).action).sort()).toEqual(
      ['CHAT_MUTE', 'CHAT_MUTE', 'KICK', 'SEAT_MUTE', 'SEAT_REMOVE'].sort(),
    );
    expect(audits.every((a) => a.actorUserId === mod.id)).toBe(true);

    // A plain member: the moderator mutes as before.
    expect((await chatMute(mod, plain)).status).toBe(204);
    // The holder's switch off: the moderator can.
    const off = await signup();
    await member(off);
    expect((await setPrivacy(off, { kickMuteShield: false })).status).toBe(200);
    await join(roomId, off);
    expect((await chatMute(mod, off)).status).toBe(204);
    // The membership ends: no shield.
    await expire(inherited);
    expect((await chatMute(mod, inherited)).status).toBe(204);
    // The host is never refused.
    expect(
      (await ctx.http.post(`/api/v1/live/rooms/${roomId}/seats/1/mute`).set(auth(host)).send({ muted: true }))
        .status,
    ).toBe(200);
    expect((await chatMute(host, shielded)).status).toBe(204);
    expect((await kick(host, shielded)).status).toBe(201);
  });

  it('ANONYMOUS_GIFT: holders only; «مجهول» to the room and the recipient, the real sender in the ledger; report and refuse by the send', async () => {
    const host = await signup();
    const roomId = await goLive(host);
    const sender = await signup();
    const plain = await signup();
    const other = await signup();
    await member(sender, VIP2);
    for (const u of [sender, plain, other]) {
      await join(roomId, u);
      await coins(u, 100_000);
    }

    const notHeld = await send(roomId, plain, [host], { anonymous: true });
    err(notHeld, 409, 'VIP_UNAVAILABLE');
    expect(notHeld.body.error.details).toEqual([{ field: 'anonymous', issue: 'no_perk' }]);
    expectContract(notHeld, 'sendLiveGift');

    const sent = await send(roomId, sender, [host], { anonymous: true });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    expectContract(sent, 'sendLiveGift');
    const giftId = sent.body.gift.id as string;
    // The sender's own response keeps their name.
    expect(sent.body.gift).toMatchObject({ anonymous: true, sender: { id: sender.id } });
    // The room's data message: «مجهول».
    await expect
      .poll(() => media.broadcastsOf(roomId, 'gift').find((g) => (g.gift as { id: string }).id === giftId))
      .toBeDefined();
    const shown = media.broadcastsOf(roomId, 'gift').find((g) => (g.gift as { id: string }).id === giftId)!
      .gift as { sender: Record<string, unknown>; anonymous: boolean };
    expect(shown.anonymous).toBe(true);
    expect(shown.sender).toMatchObject({ anonymous: true, displayName: 'مجهول' });
    expect(JSON.stringify(shown)).not.toContain(sender.id);
    expect(JSON.stringify(shown)).not.toContain(sender.username);
    // The ledger and the stored send keep the real sender.
    const row = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: giftId } });
    expect(row).toMatchObject({ senderId: sender.id, anonymous: true });
    // The recipient's earnings: «مجهول».
    const earnings = await ctx.http.get('/api/v1/wallet/me/earnings/history').set(auth(host));
    expect(earnings.status).toBe(200);
    expectContract(earnings, 'listMyEarnings');
    const entry = (earnings.body.data as { sender: Record<string, unknown> | null }[])[0]!;
    expect(entry.sender).toMatchObject({ anonymous: true });

    // The recipient reports the send: a USER report on the real sender; never named back.
    const report = (u: U, id = giftId) =>
      ctx.http.post(`/api/v1/live/gifts/${id}/reports`).set(auth(u)).send({ reason: 'HARASSMENT' });
    const filed = await report(host);
    expect(filed.status, JSON.stringify(filed.body)).toBe(201);
    expectContract(filed, 'reportLiveGift');
    expect(JSON.stringify(filed.body)).not.toContain(sender.id);
    const stored = await withMigrationClient((db) =>
      db.report.findFirstOrThrow({ where: { reporterId: host.id, contextLiveGiftId: giftId } }),
    );
    expect(stored).toMatchObject({ targetType: 'USER', targetUserId: sender.id, contextLiveRoomId: roomId });
    expect((await report(host)).status).toBe(200);
    // Not a recipient, or the sender: 404.
    expect((await report(other)).status).toBe(404);
    expect((await report(sender)).status).toBe(404);
    expect((await report(host, randomUUID())).status).toBe(404);

    // Refuse this sender's anonymous gifts: the next anonymous send is refused; a named one still arrives.
    const block = await ctx.http.put(`/api/v1/live/gifts/${giftId}/anonymous-block`).set(auth(host));
    expect(block.status).toBe(200);
    expectContract(block, 'blockAnonymousGiftSender');
    expect(block.body).toEqual({ blocked: true });
    const again = await send(roomId, sender, [host], { anonymous: true });
    err(again, 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');
    expect(again.body.error.details).toEqual([{ field: 'anonymous', issue: 'refused' }]);
    expect((await send(roomId, sender, [host])).status).toBe(201);
    const audited = await withMigrationClient((db) =>
      db.auditLog.count({
        where: { action: 'live.gift.anonymous_block', actorUserId: host.id, targetId: sender.id },
      }),
    );
    expect(audited).toBe(1);
    const unblock = await ctx.http.delete(`/api/v1/live/gifts/${giftId}/anonymous-block`).set(auth(host));
    expect(unblock.status).toBe(200);
    expectContract(unblock, 'unblockAnonymousGiftSender');
    expect((await send(roomId, sender, [host], { anonymous: true })).status).toBe(201);
    // A named send cannot be refused this way (404).
    const named = await send(roomId, plain, [host]);
    expect(
      (
        await ctx.http
          .put(`/api/v1/live/gifts/${named.body.gift.id as string}/anonymous-block`)
          .set(auth(host))
      ).status,
    ).toBe(404);

    // A block by a recipient (a seated guest) refuses an anonymous send like any send.
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 3, userId: other.id } });
    expect(
      (await ctx.http.put(`/api/v1/users/${sender.username}/block`).set(auth(other))).status,
    ).toBeLessThan(300);
    err(await send(roomId, sender, [other], { anonymous: true }), 409, 'LIVE_GIFT_RECIPIENT_UNAVAILABLE');

    // The membership ends: no more anonymous sends.
    await expire(sender);
    const other2 = await signup();
    await join(roomId, other2);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 2, userId: other2.id } });
    err(await send(roomId, sender, [other2], { anonymous: true }), 409, 'VIP_UNAVAILABLE');
  });

  it('ANONYMOUS_GIFT: at most 60 anonymous sends an hour', async () => {
    const host = await signup();
    const roomId = await goLive(host);
    const sender = await signup();
    await member(sender);
    await join(roomId, sender);
    await coins(sender, 100_000);
    for (let i = 0; i < 60; i += 1) {
      const res = await send(roomId, sender, [host], { anonymous: true });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
    }
    const over = await send(roomId, sender, [host], { anonymous: true });
    expect(over.status).toBe(429);
    // A named send is not limited by it.
    expect((await send(roomId, sender, [host])).status).toBe(201);
  });
});
