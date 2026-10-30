/**
 * D171 (owner 2026-10-29; amendment «يمكن أن تجزّئ المدة»): the bag v2 — only owned items, expiry,
 * wear / take off, sending an item whole or some days of it, stacking, notification, ledger and
 * admin grants with a duration (openapi v1.48-social DRAFT, CONVENTIONS §10.43, §4, §7, §11.10), end
 * to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 *
 * Times are moved by writing `expires_at` directly (the API reads the system clock); every
 * comparison allows a few seconds of test run time.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
import { BagService } from '../src/modules/bag/bag.service.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

interface OwnedItem {
  code: string;
  category: string;
  name: string;
  source: string;
  equipped: boolean;
  expiresAt: string | null;
  giftedBy: { id: string; username: string } | null;
  transferable: boolean;
}

const DAY = 24 * 3600_000;
/** Slack for the time a test takes between writing and reading an expiry. */
const SLACK = 30_000;

function bagAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'bag:admin', ...args], {
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

describe('D171 contract coverage', () => {
  it('openapi v1.48-social declares sendMyBagItem', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('sendMyBagItem POST /api/v1/me/bag/transfers');
  });
});

describe('D171 the bag v2', { timeout: 180_000 }, () => {
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const bag = async (u: TestUser): Promise<OwnedItem[]> => {
    const res = await ctx.http.get('/api/v1/me/bag').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as OwnedItem[];
  };
  const owned = async (u: TestUser, code: string) => (await bag(u)).find((i) => i.code === code);
  const give = async (u: TestUser, code: string, days: number | null) => {
    await ctx.prisma.userBagItem.create({
      data: {
        userId: u.id,
        itemCode: code,
        category: 'PROFILE_CARD',
        source: 'ADMIN',
        expiresAt: days === null ? null : new Date(Date.now() + days * DAY),
      },
    });
  };
  const setExpiry = (u: TestUser, code: string, at: Date | null) =>
    ctx.prisma.userBagItem.update({
      where: { userId_itemCode: { userId: u.id, itemCode: code } },
      data: { expiresAt: at },
    });
  const equip = (u: TestUser, code: string | null) =>
    ctx.http.put('/api/v1/me/bag/equipped').set(auth(u)).send({ category: 'PROFILE_CARD', code });
  const send = (u: TestUser, body: Record<string, unknown>) =>
    ctx.http.post('/api/v1/me/bag/transfers').set(auth(u)).set('Accept-Language', 'en').send(body);
  const profileCard = async (reader: TestUser, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
    expect(res.status).toBe(200);
    return res.body.profileCard as { code: string } | null;
  };
  const expiresIn = (item: OwnedItem | undefined) =>
    item?.expiresAt === null || item?.expiresAt === undefined
      ? null
      : new Date(item.expiresAt).getTime() - Date.now();

  beforeAll(async () => {
    ctx = await createTestApp();
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
  });
  afterAll(async () => ctx?.close());

  it('lists only owned items, with expiresAt, source, giftedBy and transferable', async () => {
    const u = await signup();
    await give(u, 'golden_stags', 7);
    const items = await bag(u);
    // Never the catalogue items the user does not own (kabi_royal, emerald_wings).
    expect(items.map((i) => i.code)).toEqual(['bunny_royal', 'golden_stags']);
    expect(items[0]).toMatchObject({
      source: 'FREE_SIGNUP',
      expiresAt: null,
      giftedBy: null,
      transferable: false,
    });
    expect(items[1]).toMatchObject({ source: 'ADMIN', giftedBy: null, transferable: true });
    expect(expiresIn(items[1])).toBeGreaterThan(7 * DAY - SLACK);
    expect(expiresIn(items[1])).toBeLessThanOrEqual(7 * DAY);
  });

  it('an expired item is gone: not listed, cannot be worn, leaves the profile, and the sweeper deletes it', async () => {
    const u = await signup();
    const reader = await signup();
    await give(u, 'emerald_wings', 3);
    expect((await equip(u, 'emerald_wings')).status).toBe(200);
    expect(await profileCard(reader, u)).toEqual({ code: 'emerald_wings', assetKey: 'header_emerald_wings' });
    await setExpiry(u, 'emerald_wings', new Date(Date.now() - 1000));
    expect((await bag(u)).map((i) => i.code)).toEqual(['bunny_royal']);
    // Expiry takes it off: the profile shows nothing (bunny_royal is not put back on).
    expect(await profileCard(reader, u)).toBeNull();
    const wear = await equip(u, 'emerald_wings');
    expect(wear.status).toBe(409);
    expect(wear.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    // The expired row was cleared by that equip; wearing another item works.
    expect((await equip(u, 'bunny_royal')).status).toBe(200);
    expect(await profileCard(reader, u)).toEqual({ code: 'bunny_royal', assetKey: 'header_bunny_royal' });

    // The sweeper deletes expired rows (a worn one too) and leaves the rest.
    const v = await signup();
    await give(v, 'kabi_royal', 2);
    await give(v, 'golden_stags', 2);
    await ctx.prisma.userBagItem.update({
      where: { userId_itemCode: { userId: v.id, itemCode: 'bunny_royal' } },
      data: { equipped: false },
    });
    await ctx.prisma.userBagItem.update({
      where: { userId_itemCode: { userId: v.id, itemCode: 'kabi_royal' } },
      data: { equipped: true, expiresAt: new Date(Date.now() - 1000) },
    });
    const swept = await ctx.app.get(BagService).sweep();
    expect(swept).toBeGreaterThanOrEqual(1);
    const rows = await ctx.prisma.userBagItem.findMany({
      where: { userId: v.id },
      orderBy: { itemCode: 'asc' },
    });
    expect(rows.map((r) => r.itemCode)).toEqual(['bunny_royal', 'golden_stags']);
  });

  it('wear / take off: one per category, the new one replaces the old', async () => {
    const u = await signup();
    await give(u, 'kabi_royal', 5);
    await give(u, 'golden_stags', null);
    expect((await equip(u, 'kabi_royal')).body.equipped.code).toBe('kabi_royal');
    expect((await bag(u)).filter((i) => i.equipped).map((i) => i.code)).toEqual(['kabi_royal']);
    expect((await equip(u, 'golden_stags')).body.equipped.code).toBe('golden_stags');
    expect((await bag(u)).filter((i) => i.equipped).map((i) => i.code)).toEqual(['golden_stags']);
    const off = await equip(u, null);
    expect(off.body).toEqual({ category: 'PROFILE_CARD', equipped: null });
    expect((await bag(u)).filter((i) => i.equipped)).toEqual([]);
  });

  it('sends the whole item: it moves with its remaining time, taken off, «gift from», notified, ledgered', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'emerald_wings', 6);
    expect((await equip(a, 'emerald_wings')).status).toBe(200);
    const before = expiresIn(await owned(a, 'emerald_wings'))!;
    const res = await send(a, { code: 'emerald_wings', username: b.username });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendMyBagItem');
    expect(res.body).toMatchObject({
      code: 'emerald_wings',
      category: 'PROFILE_CARD',
      name: 'Emerald Wings',
      recipient: { id: b.id, username: b.username },
      whole: true,
      remaining: null,
    });
    expect(res.body.durationSeconds * 1000).toBeGreaterThan(before - SLACK);
    expect(res.body.durationSeconds * 1000).toBeLessThanOrEqual(before);
    // Gone from the sender (and so no longer worn).
    expect(await owned(a, 'emerald_wings')).toBeUndefined();
    expect(await profileCard(b, a)).toBeNull();
    // The recipient owns it, not worn, with the same remaining time, «gift from @a».
    const got = await owned(b, 'emerald_wings');
    expect(got).toMatchObject({
      source: 'GIFT',
      equipped: false,
      giftedBy: { id: a.id, username: a.username },
    });
    expect(Math.abs(expiresIn(got)! - before)).toBeLessThan(SLACK);
    expect((await bag(b)).filter((i) => i.equipped).map((i) => i.code)).toEqual(['bunny_royal']);
    // The notification.
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(b));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    const n = (inbox.body.data as { type: string; actors: { id: string }[]; target: unknown }[]).find(
      (x) => x.type === 'BAG_ITEM_RECEIVED',
    );
    expect(n?.actors.map((x) => x.id)).toEqual([a.id]);
    expect(n?.target).toEqual({
      type: 'BAG_ITEM',
      id: 'emerald_wings',
      postId: null,
      thumbUrl: null,
      text: null,
      bagCategory: 'PROFILE_CARD',
    });
    // The ledger.
    const ledger = await ctx.prisma.bagTransfer.findMany({ where: { senderId: a.id } });
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({
      recipientId: b.id,
      itemCode: 'emerald_wings',
      whole: true,
      senderExpiresAt: null,
    });
    expect(Number(ledger[0]!.durationMs)).toBeGreaterThan(before - SLACK);
    // The recipient can wear it and send it on.
    expect((await equip(b, 'emerald_wings')).status).toBe(200);
  });

  it('a permanent item sent whole stays permanent; part of a permanent item is refused', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'kabi_royal', null);
    const part = await send(a, { code: 'kabi_royal', username: b.username, days: 3 });
    expect(part.status).toBe(409);
    expectContract(part, 'sendMyBagItem');
    expect(part.body.error.code).toBe('BAG_SEND_PERMANENT_WHOLE_ONLY');
    expect((await owned(a, 'kabi_royal'))?.expiresAt).toBeNull();
    const whole = await send(a, { code: 'kabi_royal', username: b.username, days: null });
    expect(whole.status).toBe(201);
    expect(whole.body).toMatchObject({ whole: true, durationSeconds: null, remaining: null });
    expect(await owned(b, 'kabi_royal')).toMatchObject({ expiresAt: null, source: 'GIFT' });
    expect(await owned(a, 'kabi_royal')).toBeUndefined();
    const ledger = await ctx.prisma.bagTransfer.findFirst({ where: { senderId: a.id } });
    expect(ledger).toMatchObject({ whole: true, durationMs: null, recipientExpiresAt: null });
    // Sending again to someone who owns it permanently: refused, nothing changes.
    const c = await signup();
    await give(c, 'kabi_royal', 4);
    const again = await send(c, { code: 'kabi_royal', username: b.username });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('BAG_RECIPIENT_HAS_PERMANENT');
    expect(await owned(c, 'kabi_royal')).toBeDefined();
  });

  it('sends some days: the sender keeps the rest (still worn), the recipient gets exactly those days', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'golden_stags', 10);
    expect((await equip(a, 'golden_stags')).status).toBe(200);
    const before = expiresIn(await owned(a, 'golden_stags'))!;
    const res = await send(a, { code: 'golden_stags', username: b.username, days: 3 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendMyBagItem');
    expect(res.body).toMatchObject({ whole: false, durationSeconds: 3 * 24 * 3600 });
    expect(res.body.remaining).toMatchObject({ code: 'golden_stags', equipped: true });
    const mine = await owned(a, 'golden_stags');
    expect(mine?.equipped).toBe(true);
    expect(Math.abs(expiresIn(mine)! - (before - 3 * DAY))).toBeLessThan(SLACK);
    expect(res.body.remaining.expiresAt).toBe(mine?.expiresAt);
    const theirs = await owned(b, 'golden_stags');
    expect(theirs).toMatchObject({ source: 'GIFT', equipped: false, giftedBy: { id: a.id } });
    expect(Math.abs(expiresIn(theirs)! - 3 * DAY)).toBeLessThan(SLACK);
    const ledger = await ctx.prisma.bagTransfer.findFirst({ where: { senderId: a.id } });
    expect(ledger).toMatchObject({ whole: false, durationMs: BigInt(3 * DAY) });
    expect(ledger?.senderExpiresAt?.toISOString()).toBe(mine?.expiresAt);
    expect(ledger?.recipientExpiresAt?.toISOString()).toBe(theirs?.expiresAt);
  });

  it('refuses more days than remain (and exactly all of them); nothing changes', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'golden_stags', 3);
    const exp = (await owned(a, 'golden_stags'))?.expiresAt;
    for (const days of [3, 4, 3650]) {
      const res = await send(a, { code: 'golden_stags', username: b.username, days });
      expect(res.status, String(days)).toBe(409);
      expectContract(res, 'sendMyBagItem');
      expect(res.body.error.code).toBe('BAG_SEND_EXCEEDS_REMAINING');
    }
    expect((await owned(a, 'golden_stags'))?.expiresAt).toBe(exp);
    expect(await owned(b, 'golden_stags')).toBeUndefined();
    expect(await ctx.prisma.bagTransfer.count({ where: { senderId: a.id } })).toBe(0);
    // 2 of the 3 days are fine.
    expect((await send(a, { code: 'golden_stags', username: b.username, days: 2 })).status).toBe(201);
  });

  it('stacks on the recipient’s copy: time is added, what they wear is unchanged; whole permanent makes it permanent', async () => {
    const a = await signup();
    const b = await signup();
    await give(b, 'emerald_wings', 5);
    expect((await equip(b, 'emerald_wings')).status).toBe(200);
    await give(a, 'emerald_wings', 9);
    const theirsBefore = expiresIn(await owned(b, 'emerald_wings'))!;
    expect((await send(a, { code: 'emerald_wings', username: b.username, days: 2 })).status).toBe(201);
    const theirs = await owned(b, 'emerald_wings');
    expect(Math.abs(expiresIn(theirs)! - (theirsBefore + 2 * DAY))).toBeLessThan(SLACK);
    expect(theirs).toMatchObject({ equipped: true, source: 'GIFT', giftedBy: { id: a.id } });
    expect((await bag(b)).filter((i) => i.code === 'emerald_wings')).toHaveLength(1);
    // Whole (timed) on top: the sender's remaining time is added.
    const aLeft = expiresIn(await owned(a, 'emerald_wings'))!;
    expect((await send(a, { code: 'emerald_wings', username: b.username })).status).toBe(201);
    expect(
      Math.abs(expiresIn(await owned(b, 'emerald_wings'))! - (theirsBefore + 2 * DAY + aLeft)),
    ).toBeLessThan(SLACK);
    // A whole permanent item on a timed copy: permanent.
    const c = await signup();
    await give(c, 'emerald_wings', null);
    expect((await send(c, { code: 'emerald_wings', username: b.username })).status).toBe(201);
    expect((await owned(b, 'emerald_wings'))?.expiresAt).toBeNull();
    // An expired copy on the recipient's side is replaced, counting from now.
    const d = await signup();
    await give(d, 'kabi_royal', 1);
    await setExpiry(d, 'kabi_royal', new Date(Date.now() - DAY));
    await give(a, 'kabi_royal', 8);
    expect((await send(a, { code: 'kabi_royal', username: d.username, days: 1 })).status).toBe(201);
    expect(Math.abs(expiresIn(await owned(d, 'kabi_royal'))! - DAY)).toBeLessThan(SLACK);
  });

  it('refuses: oneself, unknown user, a block either way, not owned / expired / unknown, free items, bad bodies', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'golden_stags', 5);
    const self = await send(a, { code: 'golden_stags', username: a.username });
    expect(self.status).toBe(400);
    expectContract(self, 'sendMyBagItem');
    expect(self.body.error.details).toEqual([{ field: 'username', issue: 'invalid_value' }]);
    const nobody = await send(a, { code: 'golden_stags', username: 'nobody_here_9' });
    expect(nobody.status).toBe(404);
    expectContract(nobody, 'sendMyBagItem');

    // b blocked a; then a blocked b: both refused as 404, nothing moves.
    await ctx.http.put(`/api/v1/users/${a.username}/block`).set(auth(b)).expect(200);
    expect((await send(a, { code: 'golden_stags', username: b.username })).status).toBe(404);
    await ctx.http.delete(`/api/v1/users/${a.username}/block`).set(auth(b)).expect(200);
    await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(a)).expect(200);
    expect((await send(a, { code: 'golden_stags', username: b.username })).status).toBe(404);
    await ctx.http.delete(`/api/v1/users/${b.username}/block`).set(auth(a)).expect(200);
    expect(await owned(a, 'golden_stags')).toBeDefined();
    expect(await owned(b, 'golden_stags')).toBeUndefined();

    // A non-owner can neither wear nor send.
    for (const code of ['kabi_royal', 'no_such_item']) {
      const res = await send(b, { code, username: a.username });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
      expect((await equip(b, code)).status).toBe(409);
    }
    // Expired: not owned.
    await give(b, 'kabi_royal', 2);
    await setExpiry(b, 'kabi_royal', new Date(Date.now() - 1000));
    const expired = await send(b, { code: 'kabi_royal', username: a.username });
    expect(expired.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    // The free item is not transferable.
    const free = await send(a, { code: 'bunny_royal', username: b.username });
    expect(free.status).toBe(409);
    expect(free.body.error.code).toBe('BAG_ITEM_NOT_TRANSFERABLE');

    const cases: [unknown, { field: string; issue: string }][] = [
      [{ username: b.username }, { field: 'code', issue: 'required' }],
      [{ code: 'golden_stags' }, { field: 'username', issue: 'required' }],
      [
        { code: 'golden_stags', username: b.username, days: 0 },
        { field: 'days', issue: 'too_small' },
      ],
      [
        { code: 'golden_stags', username: b.username, days: 3651 },
        { field: 'days', issue: 'too_big' },
      ],
      [
        { code: 'golden_stags', username: b.username, days: 1.5 },
        { field: 'days', issue: 'invalid_type' },
      ],
      [
        { code: 'golden_stags', username: b.username, extra: 1 },
        { field: 'extra', issue: 'unknown_field' },
      ],
    ];
    for (const [body, detail] of cases) {
      const res = await send(a, body as Record<string, unknown>);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expectContract(res, 'sendMyBagItem');
      expect(res.body.error.details, JSON.stringify(body)).toContainEqual(detail);
    }
    expect((await ctx.http.post('/api/v1/me/bag/transfers').send({ code: 'x', username: 'y' })).status).toBe(
      401,
    );
    expect(await ctx.prisma.bagTransfer.count({ where: { senderId: a.id } })).toBe(0);
  });

  it('concurrent sends never give away more than the sender has', async () => {
    const a = await signup();
    const r = await Promise.all([signup(), signup(), signup(), signup()]);
    await give(a, 'emerald_wings', 5);
    // 4 × 2 days of 5: at most two succeed (2 + 2 < 5; a third would need 6).
    const parts = await Promise.all(
      r.map((u) => send(a, { code: 'emerald_wings', username: u.username, days: 2 })),
    );
    const ok = parts.filter((p) => p.status === 201).length;
    expect(ok).toBe(2);
    for (const p of parts) {
      if (p.status !== 201) expect(p.body.error.code).toBe('BAG_SEND_EXCEEDS_REMAINING');
    }
    const left = expiresIn(await owned(a, 'emerald_wings'))!;
    expect(Math.abs(left - DAY)).toBeLessThan(SLACK);

    // Whole sends of one item at once: exactly one wins.
    const b = await signup();
    await give(b, 'kabi_royal', 4);
    const wholes = await Promise.all(r.map((u) => send(b, { code: 'kabi_royal', username: u.username })));
    expect(wholes.filter((p) => p.status === 201)).toHaveLength(1);
    for (const p of wholes) {
      if (p.status !== 201) expect(p.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    }
    const holders = await ctx.prisma.userBagItem.count({
      where: { itemCode: 'kabi_royal', userId: { in: r.map((u) => u.id) } },
    });
    expect(holders).toBe(1);

    // Two users sending each other the same item at once: no deadlock, both land.
    const x = await signup();
    const y = await signup();
    await give(x, 'golden_stags', 6);
    await give(y, 'golden_stags', 6);
    const cross = await Promise.all([
      send(x, { code: 'golden_stags', username: y.username, days: 1 }),
      send(y, { code: 'golden_stags', username: x.username, days: 1 }),
    ]);
    expect(cross.map((c) => c.status)).toEqual([201, 201]);
  });

  it('a gift from someone now blocked or gone shows no giver', async () => {
    const a = await signup();
    const b = await signup();
    await give(a, 'golden_stags', 4);
    expect((await send(a, { code: 'golden_stags', username: b.username })).status).toBe(201);
    expect((await owned(b, 'golden_stags'))?.giftedBy?.id).toBe(a.id);
    await ctx.http.put(`/api/v1/users/${a.username}/block`).set(auth(b)).expect(200);
    expect(await owned(b, 'golden_stags')).toMatchObject({ source: 'GIFT', giftedBy: null });
    await ctx.http.delete(`/api/v1/users/${a.username}/block`).set(auth(b)).expect(200);
    await ctx.prisma.user.update({ where: { id: a.id }, data: { status: 'SUSPENDED' } });
    expect((await owned(b, 'golden_stags'))?.giftedBy).toBeNull();
  });

  it('bag-admin grants with a duration, adds days, makes permanent, audited', async () => {
    const u = await signup();
    const g = bagAdmin('grant', u.email, 'kabi_royal', '7');
    expect(g.status).toBe(0);
    expect(g.out).toMatch(new RegExp(`^${u.email.replace(/[.+]/g, '\\$&')}: \\+kabi_royal until .+Z\\.\\n$`));
    expect(Math.abs(expiresIn(await owned(u, 'kabi_royal'))! - 7 * DAY)).toBeLessThan(SLACK);
    const more = bagAdmin('grant', u.email, 'kabi_royal', '30');
    expect(more.status).toBe(0);
    expect(more.out).toContain('(time added)');
    expect(Math.abs(expiresIn(await owned(u, 'kabi_royal'))! - 37 * DAY)).toBeLessThan(SLACK);
    expect(bagAdmin('grant', u.email, 'kabi_royal', 'forever').status).toBe(0);
    expect((await owned(u, 'kabi_royal'))?.expiresAt).toBeNull();
    expect(bagAdmin('grant', u.email, 'kabi_royal', '7').out).toBe(
      `${u.email} already owns kabi_royal; nothing changed.\n`,
    );
    for (const bad of ['0', '3651', 'x', '-1']) {
      expect(bagAdmin('grant', u.email, 'golden_stags', bad).status, bad).toBe(1);
    }
    expect(await owned(u, 'golden_stags')).toBeUndefined();
    const listed = bagAdmin('list', u.email);
    expect(listed.out).toMatch(/PROFILE_CARD kabi_royal \(ADMIN, [^,]+\)\n/);
    const audits = await ctx.prisma.auditLog.findMany({
      where: { targetId: u.id, action: 'bag.grant' },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((a) => a.metadata)).toEqual([
      { item: 'kabi_royal', category: 'PROFILE_CARD', via: 'cli', days: 7, extended: false },
      { item: 'kabi_royal', category: 'PROFILE_CARD', via: 'cli', days: 30, extended: true },
      { item: 'kabi_royal', category: 'PROFILE_CARD', via: 'cli', days: null, extended: true },
    ]);
  });
});

describe('D171 send rate limit', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_BAG_SEND_USER: '2/3600' });
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
  });
  afterAll(async () => ctx?.close());

  it('the third send in the hour → 429', async () => {
    const reg = async () => {
      const { res } = await registerVerified(ctx);
      return {
        id: res.body.user.id as string,
        username: res.body.user.username as string,
        token: res.body.tokens.accessToken as string,
      };
    };
    const a = await reg();
    const b = await reg();
    await ctx.prisma.userBagItem.create({
      data: {
        userId: a.id,
        itemCode: 'golden_stags',
        category: 'PROFILE_CARD',
        source: 'ADMIN',
        expiresAt: new Date(Date.now() + 30 * DAY),
      },
    });
    const go = () =>
      ctx.http
        .post('/api/v1/me/bag/transfers')
        .set({ Authorization: `Bearer ${a.token}` })
        .send({ code: 'golden_stags', username: b.username, days: 1 });
    expect((await go()).status).toBe(201);
    expect((await go()).status).toBe(201);
    const third = await go();
    expect(third.status).toBe(429);
    expectContract(third, 'sendMyBagItem');
  });
});
