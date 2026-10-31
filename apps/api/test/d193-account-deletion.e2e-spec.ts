/**
 * D193 (owner 2026-10-31: «زر حذف الحساب» inside the app, as Apple 5.1.1(v) and Google Play require, with 30 days to
 * change one's mind; contract v1.62-social, CONVENTIONS §10.56, CP-036): the person asks for deletion (password
 * re-checked, confirmation word typed, nothing to settle first), is signed out everywhere and hidden at once; signing
 * in within the grace period offers to cancel, which restores everything; after it the sweeper turns the account into
 * a tombstone — personal data and content gone, the financial and audit rows kept without personal data, the regular
 * username quarantined, system codes never reused. The `account-admin` CLI covers requests made without the app.
 * End to end against PostgreSQL + Redis.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AccountDeletionSweeper } from '../src/modules/auth/account-deletion.service.js';
import { createAgencyIn } from '../src/modules/economy/host-agents.js';
import { dateValue } from '../src/modules/economy/economy-math.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DmSweeper } from '../src/modules/messages/dm-sweeper.js';
import {
  DELETED_DISPLAY_NAME,
  purgeAccountIn,
  requestDeletionIn,
  TOMBSTONE_USERNAME,
  usernameHash,
} from '../src/modules/users/account-deletion.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}

const DAY_MS = 86_400_000;

/** An APPROVED recharge-agent application with its KYC fields (D185). */
const kycRow = (userId: string) => ({
  userId,
  status: 'APPROVED' as const,
  decidedAt: new Date(),
  fullName: 'Real Name',
  phone: '+962790000000',
  photoKey: `kyc/${userId}/photo.webp`,
  selfieKey: `kyc/${userId}/selfie.webp`,
  locations: [],
  paymentMethods: [],
});

/** Runs `pnpm account:admin …` as on the server (migration role, a child process). */
function accountAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'account:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: { ...process.env, S3_BUCKET: '' },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string; stdout: string };
    return { status: e.status, out: `${e.stdout}${e.stderr}` };
  }
}

describe('D193 contract coverage', () => {
  it('openapi v1.62-social declares the deletion routes, bodies and the login flag', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getAccountDeletionInfo GET /api/v1/me/account-deletion',
        'requestAccountDeletion POST /api/v1/me/account-deletion',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect((schemas.AccountDeletionBlocker as { enum: string[] }).enum).toEqual([
      'recharge_agent',
      'host_agency',
      'pending_withdrawal',
      'pending_cherry_sale',
      'negative_balance',
    ]);
    expect(Object.keys((schemas.LoginRequest as { properties: object }).properties)).toContain(
      'cancelDeletion',
    );
    expect(Object.keys((schemas.Earning as { properties: object }).properties)).toContain('senderDeleted');
  });
});

describe('D193 account deletion', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let sweeper: AccountDeletionSweeper;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email),
      password: String(payload.password),
      token: res.body.tokens.accessToken as string,
    };
  };
  const login = (u: TestUser, extra: Record<string, unknown> = {}) =>
    ctx.http.post('/api/v1/auth/login').send({ identifier: u.email, password: u.password, ...extra });
  const signIn = async (u: TestUser) => {
    const res = await login(u);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    u.token = res.body.tokens.accessToken as string;
    return res.body.tokens.refreshToken as string;
  };
  const askDeletion = (u: TestUser, body: Record<string, unknown> = {}) =>
    ctx.http
      .post('/api/v1/me/account-deletion')
      .set(auth(u))
      .send({ password: u.password, confirmation: 'حذف', ...body });
  const info = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/account-deletion').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getAccountDeletionInfo');
    return res.body as { graceDays: number; blockers: string[]; supportEmail: string };
  };
  const audits = (userId: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { targetId: userId, action }, orderBy: { createdAt: 'asc' } });
  const gift = (code: string, price: number) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${code}`,
        nameEn: `Gift ${code}`,
        priceCoins: price,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  const join = async (roomId: string, u: TestUser) => {
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

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: OBJECT_STORAGE, value: storage },
    ]);
    sweeper = ctx.app.get(AccountDeletionSweeper);
    await gift('del_rose', 10);
  });
  afterAll(async () => ctx?.close());

  it('re-authentication and the confirmation word are required; a wrong password is audited', async () => {
    const u = await signup();
    expect((await ctx.http.post('/api/v1/me/account-deletion').send({})).status).toBe(401);
    const shown = await info(u);
    expect(shown).toEqual({ graceDays: 30, blockers: [], supportEmail: 'info@kabsolive.com' });

    const noWord = await askDeletion(u, { confirmation: 'yes' });
    expect(noWord.status).toBe(400);
    expectContract(noWord, 'requestAccountDeletion');
    expect(noWord.body.error.details).toEqual([{ field: 'confirmation', issue: 'invalid_value' }]);
    expect((await askDeletion(u, { password: undefined })).status).toBe(400);
    expect((await askDeletion(u, { extra: 1 })).status).toBe(400);

    const wrong = await askDeletion(u, { password: 'not the password at all' });
    expect(wrong.status).toBe(403);
    expectContract(wrong, 'requestAccountDeletion');
    expect(wrong.body.error.code).toBe('REAUTH_FAILED');
    expect(await audits(u.id, 'account.deletion.reauth_failed')).toHaveLength(1);
    // Nothing changed: still active, still signed in.
    expect((await ctx.http.get('/api/v1/me').set(auth(u))).status).toBe(200);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    // The English word works too (any case, spaces around ignored).
    const ok = await askDeletion(u, { confirmation: '  delete ' });
    expect(ok.status, JSON.stringify(ok.body)).toBe(202);
  });

  it('blocks while something must be settled first, with a clear reason per blocker', async () => {
    const u = await signup();
    // A pending cherry withdrawal and a negative cherry balance (a reversal).
    await ctx.prisma.cherryWallet.create({ data: { userId: u.id, cherries: -5n } });
    await ctx.prisma.cherryWithdrawal.create({
      data: {
        userId: u.id,
        clientId: randomUUID(),
        cherries: 1000n,
        amountMinor: 1n,
        currency: 'USD',
        rateCherries: 1000n,
        rateMinor: 1,
        payoutDetails: 'IBAN SA00 0000 1234',
      },
    });
    // A host agency they own (D179/D189).
    await ctx.prisma.$transaction((tx) =>
      createAgencyIn(
        tx,
        {
          ownerUserId: u.id,
          inviteCode: 'DELAGY23',
          parentAgencyId: null,
          evaluateFrom: dateValue('2099-01-01'),
        },
        new Date(),
        30,
      ),
    );
    expect((await info(u)).blockers).toEqual(['host_agency', 'pending_withdrawal', 'negative_balance']);
    const res = await askDeletion(u);
    expect(res.status).toBe(409);
    expectContract(res, 'requestAccountDeletion');
    expect(res.body.error.code).toBe('ACCOUNT_DELETION_BLOCKED');
    expect(res.body.error.details).toEqual([
      { field: 'account', issue: 'host_agency' },
      { field: 'account', issue: 'pending_withdrawal' },
      { field: 'account', issue: 'negative_balance' },
    ]);
    const blocked = await audits(u.id, 'account.deletion.blocked');
    expect(blocked).toHaveLength(1);
    expect(blocked[0]!.metadata).toMatchObject({
      blockers: ['host_agency', 'pending_withdrawal', 'negative_balance'],
    });
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');

    // A recharge agent (D185) that is not suspended blocks too (generic over the agent's state).
    const agent = await signup();
    const app = await ctx.prisma.rechargeAgentApplication.create({ data: kycRow(agent.id) });
    await ctx.prisma.rechargeAgent.create({
      data: { userId: agent.id, applicationId: app.id, countries: [], locations: [], paymentTypes: [] },
    });
    expect((await info(agent)).blockers).toEqual(['recharge_agent']);
    expect((await askDeletion(agent)).status).toBe(409);
    // The CLI refuses the same way (exit 1, the blockers printed).
    const cli = accountAdmin('purge-now', agent.username, '--reason', 'test');
    expect(cli.status).toBe(1);
    expect(cli.out).toContain('recharge_agent');
  });

  it('the request hides the account at once, signs out everywhere and mails a notice; cancel restores it', async () => {
    const u = await signup();
    const fan = await signup();
    const secondRefresh = await signIn({ ...u }); // a second device
    expect((await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(fan))).status).toBeLessThan(
      300,
    );
    expect((await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(fan))).status).toBe(200);

    const before = ctx.mail.sent.length;
    const res = await askDeletion(u);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    expectContract(res, 'requestAccountDeletion');
    expect(res.body.status).toBe('PENDING');
    const purgeAfter = new Date(res.body.purgeAfter as string);
    expect(purgeAfter.getTime() - new Date(res.body.requestedAt as string).getTime()).toBe(30 * DAY_MS);
    await settle(ctx);
    const notice = ctx.mail.last(u.email, 'deletion_requested', before);
    expect(notice?.code).toBe(purgeAfter.toISOString().slice(0, 10));

    // Signed out everywhere: this token, the other device's refresh token, push tokens.
    expect((await ctx.http.get('/api/v1/me').set(auth(u))).status).toBe(401);
    expect((await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken: secondRefresh })).status).toBe(
      401,
    );
    const sessions = await ctx.prisma.session.findMany({ where: { userId: u.id } });
    expect(sessions.length).toBeGreaterThanOrEqual(2);
    expect(sessions.every((s) => s.revokedAt !== null && s.revokedReason === 'ACCOUNT_DELETION')).toBe(true);

    // Hidden like a deactivated account: profile, search, follow lists.
    expect((await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(fan))).status).toBe(404);
    const search = await ctx.http
      .get('/api/v1/search')
      .query({ q: u.username, type: 'users' })
      .set(auth(fan));
    expect(search.status).toBe(200);
    expect(JSON.stringify(search.body)).not.toContain(u.id);
    const following = await ctx.http.get(`/api/v1/users/${fan.username}/following`).set(auth(fan));
    expect(JSON.stringify(following.body)).not.toContain(u.id);

    // Signing in: the right password gets the pending answer (a wrong one learns nothing).
    expect((await login(u, { password: 'wrong password here!' })).status).toBe(401);
    const pending = await login(u);
    expect(pending.status).toBe(409);
    expectContract(pending, 'login');
    expect(pending.body.error).toMatchObject({
      code: 'ACCOUNT_DELETION_PENDING',
      details: [{ field: 'purgeAfter', issue: purgeAfter.toISOString() }],
    });
    // Idempotent at the core: asking again while pending returns the same request.
    const again = await ctx.prisma.$transaction((tx) =>
      requestDeletionIn(tx, u.id, new Date(), 30, { via: 'APP' }),
    );
    expect(again.outcome).toBe('already_pending');
    expect(await ctx.prisma.accountDeletionRequest.count({ where: { userId: u.id } })).toBe(1);

    // Cancel at sign-in: everything is back (the follow edge was never removed).
    const mails = ctx.mail.sent.length;
    const cancelled = await login(u, { cancelDeletion: true });
    expect(cancelled.status, JSON.stringify(cancelled.body)).toBe(200);
    expectContract(cancelled, 'login');
    u.token = cancelled.body.tokens.accessToken as string;
    await settle(ctx);
    expect(ctx.mail.last(u.email, 'deletion_cancelled', mails)).toBeDefined();
    expect((await ctx.http.get('/api/v1/me').set(auth(u))).status).toBe(200);
    expect((await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(fan))).status).toBe(200);
    const back = await ctx.http.get(`/api/v1/users/${fan.username}/following`).set(auth(fan));
    expect(JSON.stringify(back.body)).toContain(u.id);
    const row = await ctx.prisma.accountDeletionRequest.findFirstOrThrow({ where: { userId: u.id } });
    expect(row).toMatchObject({ status: 'CANCELLED', cancelledVia: 'APP' });
    expect(await audits(u.id, 'account.deletion.requested')).toHaveLength(1);
    expect(await audits(u.id, 'account.deletion.cancelled')).toHaveLength(1);
    // A cancelled account's sweep changes nothing (others' due requests may be purged).
    await sweeper.sweep(new Date(Date.now() + 40 * DAY_MS));
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    // `cancelDeletion` on an ordinary account is ignored.
    expect((await login(u, { cancelDeletion: true })).status).toBe(200);
  });

  it('after 30 days the sweeper purges: personal data gone, ledgers kept under the tombstone, username quarantined', async () => {
    const u = await signup();
    const fan = await signup();
    const host = await signup();
    // Content and graph.
    expect((await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(fan))).status).toBeLessThan(
      300,
    );
    expect((await ctx.http.put(`/api/v1/users/${host.username}/follow`).set(auth(u))).status).toBeLessThan(
      300,
    );
    const post = await ctx.prisma.post.create({
      data: { authorId: u.id, text: 'my post', publishedAt: new Date() },
    });
    const hostPost = await ctx.prisma.post.create({
      data: { authorId: host.id, text: 'host post', publishedAt: new Date(), likeCount: 1, commentCount: 1 },
    });
    await ctx.prisma.postLike.create({ data: { postId: hostPost.id, userId: u.id } });
    await ctx.prisma.comment.create({ data: { postId: hostPost.id, authorId: u.id, text: 'my comment' } });
    await ctx.prisma.userProfile.update({
      where: { userId: u.id },
      data: { bio: 'about me', countryCode: 'JO' },
    });
    // Money: a coin grant, a live gift to the host (the host's gift history), a cherry withdrawal already paid.
    await creditIn(ctx.prisma, u.id, 1000n, 'ADMIN_GRANT', randomUUID());
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Del' });
    expect(room.status).toBe(201);
    await join(room.body.id as string, u);
    const sent = await ctx.http
      .post(`/api/v1/live/rooms/${room.body.id as string}/gifts`)
      .set(auth(u))
      .send({
        giftCode: 'del_rose',
        quantity: 1,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    await ctx.prisma.cherryWithdrawal.create({
      data: {
        userId: u.id,
        clientId: randomUUID(),
        cherries: 1000n,
        amountMinor: 110n,
        currency: 'USD',
        rateCherries: 1000n,
        rateMinor: 110,
        payoutDetails: 'Wallet +962790001234',
        status: 'PAID',
        decidedAt: new Date(),
      },
    });
    const ledgerBefore = await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id } });
    expect(ledgerBefore).toBe(2); // the grant and the gift

    const res = await askDeletion(u);
    expect(res.status).toBe(202);
    const purgeAfter = new Date(res.body.purgeAfter as string);
    // Not before the grace period ends.
    expect((await sweeper.sweep(new Date(purgeAfter.getTime() - 60_000))).purged).toBe(0);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe(
      'PENDING_DELETION',
    );
    const swept = await sweeper.sweep(new Date(purgeAfter.getTime() + 60_000));
    expect(swept.purged).toBe(1);
    // Idempotent: a second sweep does nothing.
    expect((await sweeper.sweep(new Date(purgeAfter.getTime() + 120_000))).purged).toBe(0);

    // The tombstone: same id, no personal data.
    const tomb = await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id }, include: { profile: true } });
    expect(tomb.status).toBe('DELETED');
    expect(tomb.email).toBe(`deleted+${u.id}@deleted.invalid`);
    expect(tomb.passwordHash.startsWith('$argon2')).toBe(false);
    expect(tomb.deletedAt).not.toBeNull();
    expect(tomb.profile?.username).toMatch(TOMBSTONE_USERNAME);
    expect(tomb.profile).toMatchObject({
      displayName: DELETED_DISPLAY_NAME,
      bio: null,
      avatarUrl: null,
      countryCode: null,
      gender: null,
    });
    expect(JSON.stringify(tomb)).not.toContain(u.email);
    // Content and graph gone; the counters on others' content follow.
    expect(await ctx.prisma.post.count({ where: { id: post.id } })).toBe(0);
    expect(
      await ctx.prisma.follow.count({ where: { OR: [{ followerId: u.id }, { followeeId: u.id }] } }),
    ).toBe(0);
    expect(await ctx.prisma.session.count({ where: { userId: u.id } })).toBe(0);
    expect(await ctx.prisma.deviceToken.count({ where: { userId: u.id } })).toBe(0);
    const hp = await ctx.prisma.post.findUniqueOrThrow({ where: { id: hostPost.id } });
    expect(hp).toMatchObject({ likeCount: 0, commentCount: 0 });
    const comment = await ctx.prisma.comment.findFirstOrThrow({ where: { authorId: u.id } });
    expect(comment.deletedAt).not.toBeNull();
    expect(comment.text).toBe('');
    // The ledgers stay, under the same (tombstone) id; the withdrawal keeps only the end of its payout details.
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id } })).toBe(ledgerBefore);
    expect(await ctx.prisma.liveGift.count({ where: { senderId: u.id } })).toBe(1);
    const w = await ctx.prisma.cherryWithdrawal.findFirstOrThrow({ where: { userId: u.id } });
    expect(w.payoutDetails).toBe('…1234');
    // The host's gift history: the sender shows as a deleted user.
    const history = await ctx.http.get('/api/v1/wallet/me/earnings/history').set(auth(host));
    expect(history.status).toBe(200);
    expectContract(history, 'listMyEarnings');
    expect(history.body.data[0]).toMatchObject({ sender: null, senderDeleted: true });
    const cherries = await ctx.http.get('/api/v1/wallet/me/cherries/ledger').set(auth(host));
    expect(cherries.status).toBe(200);
    expectContract(cherries, 'listMyCherryLedger');
    const giftRow = (cherries.body.data as { gift: Record<string, unknown> | null }[]).find(
      (r) => r.gift !== null,
    );
    expect(giftRow?.gift).toMatchObject({ sender: null, senderDeleted: true });
    // The record and the audit.
    expect(
      await ctx.prisma.accountDeletionRequest.findFirstOrThrow({ where: { userId: u.id } }),
    ).toMatchObject({
      status: 'PURGED',
      purgedVia: 'SWEEPER',
    });
    const purged = await audits(u.id, 'account.deletion.purged');
    expect(purged).toHaveLength(1);
    expect(JSON.stringify(purged[0]!.metadata)).not.toContain(u.username);

    // The account cannot sign in by any name; the profile is gone for others.
    expect((await login(u)).status).toBe(401);
    expect(
      (await ctx.http.post('/api/v1/auth/login').send({ identifier: u.username, password: u.password }))
        .status,
    ).toBe(401);
    expect((await ctx.http.get(`/api/v1/users/${tomb.profile!.username}`).set(auth(fan))).status).toBe(404);

    // The regular username is quarantined (only its hash is kept), then free again.
    const quarantined = await ctx.prisma.deletedUsername.findUniqueOrThrow({
      where: { nameHash: usernameHash(u.username) },
    });
    expect(quarantined.until.getTime()).toBeGreaterThan(purgeAfter.getTime() + 89 * DAY_MS);
    const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username: u.username });
    expect(avail.body.available).toBe(false);
    const taken = await registerVerified(ctx, { username: u.username }).catch((e: Error) => e);
    expect(taken instanceof Error ? taken.message : '').toContain('409');
    const later = await sweeper.sweep(new Date(quarantined.until.getTime() + 60_000));
    expect(later.released).toBeGreaterThanOrEqual(1);
    const free = await ctx.http.get('/api/v1/users/username-availability').query({ username: u.username });
    expect(free.body.available).toBe(true);
  });

  it('system codes stay held for ever; purge is idempotent; the CLI requests, cancels and purges with an audit', async () => {
    // A suspended recharge agent with no stock may delete; their coinNNNN code is never released.
    const agent = await signup();
    const app = await ctx.prisma.rechargeAgentApplication.create({
      data: kycRow(agent.id),
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: agent.id,
        applicationId: app.id,
        status: 'SUSPENDED',
        suspendedAt: new Date(),
        suspendReason: 'test',
        countries: [],
        locations: [],
        paymentTypes: [],
      },
    });
    await ctx.prisma.specialUsername.create({
      data: {
        userId: agent.id,
        username: 'coin9193',
        baseUsername: agent.username,
        source: 'RECHARGE_AGENT',
        status: 'GRACE',
        endedAt: new Date(),
      },
    });
    const purge = () =>
      ctx.prisma.$transaction((tx) =>
        purgeAccountIn(tx, agent.id, new Date(), {
          quarantineDays: 90,
          specialGraceDays: 30,
          legalHoldDays: 90,
          via: 'ADMIN',
        }),
      );
    expect(await purge()).not.toBeNull();
    expect(await purge()).toBeNull(); // already a tombstone
    const code = await ctx.prisma.specialUsername.findFirstOrThrow({ where: { username: 'coin9193' } });
    expect(code).toMatchObject({ status: 'GRACE', graceUntil: null });
    expect(code.baseUsername).toMatch(TOMBSTONE_USERNAME);
    const kyc = await ctx.prisma.rechargeAgentApplication.findUniqueOrThrow({ where: { id: app.id } });
    expect(kyc).toMatchObject({ fullName: null, phone: null });
    expect(kyc.purgedAt).not.toBeNull();
    expect(
      (await ctx.http.get('/api/v1/users/username-availability').query({ username: 'coin9193' })).body
        .available,
    ).toBe(false);

    // The CLI: request (an emailed request), pending, cancel, then purge-now.
    const u = await signup();
    const req = accountAdmin('request', u.email, '--reason', 'emailed request #12');
    expect(req.status, req.out).toBe(0);
    expect((await ctx.http.get('/api/v1/me').set(auth(u))).status).toBe(401);
    const list = accountAdmin('pending');
    expect(list.status, list.out).toBe(0);
    expect(list.out).toContain(u.id);
    expect(accountAdmin('cancel', u.username).status).toBe(1); // a reason is required
    const cancel = accountAdmin('cancel', u.username, '--reason', 'changed their mind by email');
    expect(cancel.status, cancel.out).toBe(0);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('ACTIVE');
    const now = accountAdmin('purge-now', u.username, '--reason', 'legal request');
    expect(now.status, now.out).toBe(0);
    expect(now.out).toMatch(/tombstone @deleted\.[0-9a-f]{16}/);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('DELETED');
    const actions = (
      await ctx.prisma.auditLog.findMany({
        where: { targetId: u.id, action: { startsWith: 'account.deletion.' } },
      })
    ).map((a) => [a.action, (a.metadata as { via?: string; reason?: string }).reason]);
    expect(actions).toEqual(
      expect.arrayContaining([
        ['account.deletion.requested', 'emailed request #12'],
        ['account.deletion.cancelled', 'changed their mind by email'],
        ['account.deletion.purged', 'legal request'],
      ]),
    );
    expect(accountAdmin('purge-now', u.id, '--reason', 'again').out).toContain('already deleted');
  });
  it('owner retention: reported content held 90 days (hidden, audited views), the rest deleted; IPs dropped; ledgers 7 years', async () => {
    const u = await signup();
    const reporter = await signup();
    const other = await signup();
    const mod = await signup();
    await withMigrationClient(async (c) => {
      await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
      await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
    });
    // A picture post with an OPEN report (held), a post whose only report was DISMISSED and an unreported picture post
    // (both deleted), a comment on someone else's post with an ACTIONED report (held), a reported DM and profile link.
    const picture = async (tag: string) => {
      const asset = await ctx.prisma.mediaAsset.create({
        data: {
          ownerId: u.id,
          kind: 'POST_IMAGE',
          width: 1080,
          height: 1080,
          largeKey: `media/${tag}-${u.id}/large.webp`,
          thumbKey: `media/${tag}-${u.id}/thumb.webp`,
          byteSize: 1000,
          attachedAt: new Date(),
        },
      });
      storage.putRaw(asset.largeKey, Buffer.from('L'), 'image/webp');
      storage.putRaw(asset.thumbKey, Buffer.from('T'), 'image/webp');
      return asset;
    };
    const heldPic = await picture('held');
    const plainPic = await picture('plain');
    const heldPost = await ctx.prisma.post.create({
      data: {
        authorId: u.id,
        text: 'held post text',
        publishedAt: new Date(),
        media: { create: { mediaAssetId: heldPic.id, position: 0 } },
      },
    });
    const dismissedPost = await ctx.prisma.post.create({
      data: { authorId: u.id, text: 'dismissed post', publishedAt: new Date() },
    });
    const plainPost = await ctx.prisma.post.create({
      data: {
        authorId: u.id,
        text: 'plain post',
        publishedAt: new Date(),
        media: { create: { mediaAssetId: plainPic.id, position: 0 } },
      },
    });
    const otherPost = await ctx.prisma.post.create({
      data: { authorId: other.id, text: 'other post', publishedAt: new Date(), commentCount: 1 },
    });
    const badComment = await ctx.prisma.comment.create({
      data: { postId: otherPost.id, authorId: u.id, text: 'bad comment text' },
    });
    const postReport = await ctx.prisma.report.create({
      data: { reporterId: reporter.id, targetType: 'POST', targetPostId: heldPost.id, reason: 'HATE' },
    });
    const postReport2 = await ctx.prisma.report.create({
      data: { reporterId: other.id, targetType: 'POST', targetPostId: heldPost.id, reason: 'SPAM' },
    });
    const dismissedReport = await ctx.prisma.report.create({
      data: {
        reporterId: reporter.id,
        targetType: 'POST',
        targetPostId: dismissedPost.id,
        reason: 'SPAM',
        status: 'DISMISSED',
        resolvedAt: new Date(),
      },
    });
    const commentReport = await ctx.prisma.report.create({
      data: {
        reporterId: other.id,
        targetType: 'COMMENT',
        targetCommentId: badComment.id,
        reason: 'HARASSMENT',
        status: 'ACTIONED',
        resolvedAt: new Date(),
      },
    });
    const dmId = randomUUID();
    const dmFile = `reports/dm/${randomUUID()}.webp`;
    storage.putRaw(dmFile, Buffer.from('D'), 'image/webp');
    const dmReport = await ctx.prisma.report.create({
      data: {
        reporterId: reporter.id,
        targetType: 'DM_MESSAGE',
        targetDmMessageId: dmId,
        reason: 'NUDITY',
        // Resolved 40 days ago: the DM sweeper would clear an ordinary snapshot (30 days), not a held one.
        status: 'ACTIONED',
        resolvedAt: new Date(Date.now() - 40 * DAY_MS),
        dmSnapshot: {
          kind: 'IMAGE',
          text: 'dm text',
          token: null,
          senderId: u.id,
          senderUsername: u.username,
          conversationId: randomUUID(),
          sentAt: new Date().toISOString(),
          mediaKey: dmFile,
          giftCode: null,
          quantity: null,
          purged: false,
        },
      },
    });
    const linkReport = await ctx.prisma.report.create({
      data: {
        reporterId: reporter.id,
        targetType: 'PROFILE_LINK',
        targetProfileLinkId: randomUUID(),
        reason: 'SPAM',
        linkSnapshot: { userId: u.id, username: u.username, url: 'https://spam.example/x', label: 'x' },
      },
    });
    // Money and audit: a ledger row, a paid withdrawal, an 18+ statement; an audit row with an IP and a username.
    await creditIn(ctx.prisma, u.id, 500n, 'ADMIN_GRANT', randomUUID());
    await ctx.prisma.cherryWithdrawal.create({
      data: {
        userId: u.id,
        clientId: randomUUID(),
        cherries: 1000n,
        amountMinor: 110n,
        currency: 'USD',
        rateCherries: 1000n,
        rateMinor: 110,
        payoutDetails: 'IBAN JO00 0000 5678',
        decisionNote: 'paid to the account holder',
        status: 'PAID',
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.luckyGiftAgeConfirmation.create({ data: { userId: u.id } });
    await ctx.prisma.auditLog.create({
      data: {
        action: 'profile.username.change',
        actorUserId: u.id,
        targetType: 'user',
        targetId: u.id,
        metadata: { from: u.username, to: `${u.username}x`, email: u.email, kept: 1 },
        ip: '203.0.113.7',
      },
    });
    const ledgerRows = await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id } });
    const userAudit = () =>
      ctx.prisma.auditLog.findMany({
        where: { OR: [{ actorUserId: u.id }, { targetType: 'user', targetId: u.id }] },
      });

    const asked = await askDeletion(u);
    expect(asked.status).toBe(202);
    expect((await userAudit()).some((a) => a.ip !== null)).toBe(true); // the request carries the caller's IP
    const purgeAt = new Date(new Date(asked.body.purgeAfter as string).getTime() + 60_000);
    expect((await sweeper.sweep(purgeAt)).purged).toBeGreaterThanOrEqual(1);

    // -- Held: one hold per reported item, linked to the tombstone and its reports, never to the person.
    const holds = await ctx.prisma.legalHold.findMany({
      where: { userId: u.id },
      include: { reports: true },
    });
    expect(holds.map((h) => h.targetType).sort()).toEqual(['COMMENT', 'DM_MESSAGE', 'POST', 'PROFILE_LINK']);
    for (const h of holds) {
      expect(h.deleteAfter.getTime() - h.heldAt.getTime()).toBe(90 * DAY_MS);
      expect(h.heldAt.getTime()).toBe(purgeAt.getTime());
      const text = JSON.stringify(h);
      expect(text).not.toContain(u.username);
      expect(text).not.toContain(u.email);
    }
    const postHold = holds.find((h) => h.targetType === 'POST')!;
    expect(postHold.targetId).toBe(heldPost.id);
    expect(postHold.snapshot).toMatchObject({
      text: 'held post text',
      media: [{ largeKey: heldPic.largeKey }],
    });
    expect(postHold.objectKeys.sort()).toEqual([heldPic.largeKey, heldPic.thumbKey].sort());
    expect(postHold.reports.map((r) => r.id).sort()).toEqual([postReport.id, postReport2.id].sort());
    expect(postHold.reports.every((r) => r.targetPostId === null && r.status === 'OPEN')).toBe(true);
    const commentHold = holds.find((h) => h.targetType === 'COMMENT')!;
    expect(commentHold.snapshot).toMatchObject({ text: 'bad comment text', postId: otherPost.id });
    expect(commentHold.reports.map((r) => r.id)).toEqual([commentReport.id]);
    expect((await ctx.prisma.comment.findUniqueOrThrow({ where: { id: badComment.id } })).text).toBe('');
    const dmHold = holds.find((h) => h.targetType === 'DM_MESSAGE')!;
    expect(dmHold.snapshot).toMatchObject({ text: 'dm text', mediaKey: dmFile });
    expect(dmHold.objectKeys).toEqual([dmFile]);
    const dmRow = await ctx.prisma.report.findUniqueOrThrow({ where: { id: dmReport.id } });
    expect((dmRow.dmSnapshot as { senderUsername: unknown }).senderUsername).toBeNull();
    const linkRow = await ctx.prisma.report.findUniqueOrThrow({ where: { id: linkReport.id } });
    expect((linkRow.linkSnapshot as { username: string }).username).toMatch(TOMBSTONE_USERNAME);
    expect(holds.find((h) => h.targetType === 'PROFILE_LINK')!.snapshot).toEqual({
      url: 'https://spam.example/x',
      label: 'x',
    });

    // -- Deleted: the content rows (held ones too: the hold is a copy), the unreported and dismissed items with their
    // reports and files; the held files stay.
    expect(
      await ctx.prisma.post.count({ where: { id: { in: [heldPost.id, dismissedPost.id, plainPost.id] } } }),
    ).toBe(0);
    expect(await ctx.prisma.report.count({ where: { id: dismissedReport.id } })).toBe(0);
    expect(storage.objects.has(plainPic.largeKey)).toBe(false);
    expect(storage.objects.has(plainPic.thumbKey)).toBe(false);
    expect(storage.objects.has(heldPic.largeKey)).toBe(true);
    expect(storage.objects.has(dmFile)).toBe(true);

    // -- Hidden from every user: the post is gone for the reporter; no API returns the hold's content. The moderation
    // queue shows the report (its target id from the hold) and can still close it; every report of the hold closes.
    expect((await ctx.http.get(`/api/v1/posts/${heldPost.id}`).set(auth(reporter))).status).toBe(404);
    const modLogin = await login(mod);
    const modAuth = { Authorization: `Bearer ${modLogin.body.tokens.accessToken as string}` };
    const queue = await ctx.http.get('/api/v1/admin/reports').query({ limit: 50 }).set(modAuth);
    expect(queue.status).toBe(200);
    const queued = (queue.body.data as { id: string; targetId: string }[]).find(
      (r) => r.id === postReport.id,
    );
    expect(queued?.targetId).toBe(heldPost.id);
    expect(JSON.stringify(queue.body)).not.toContain('held post text');
    const acted = await ctx.http
      .post(`/api/v1/admin/reports/${postReport.id}/actions`)
      .set(modAuth)
      .send({ action: 'REMOVE_TARGET' });
    expect(acted.status, JSON.stringify(acted.body)).toBe(200);
    expectContract(acted, 'actOnReport');
    expect(await ctx.prisma.report.count({ where: { legalHoldId: postHold.id, status: 'ACTIONED' } })).toBe(
      2,
    );
    // Unrelated open reports were not closed by it.
    expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id: linkReport.id } })).status).toBe('OPEN');

    // -- The DM sweeper leaves a held snapshot (and its file) alone.
    await ctx.app.get(DmSweeper).sweep();
    const dmAfter = await ctx.prisma.report.findUniqueOrThrow({ where: { id: dmReport.id } });
    expect((dmAfter.dmSnapshot as { purged: boolean; text: string }).text).toBe('dm text');
    expect(storage.objects.has(dmFile)).toBe(true);

    // -- Audit: kept, without the IP addresses and without the person's identifiers.
    const scrubbed = await userAudit();
    expect(scrubbed.length).toBeGreaterThanOrEqual(3);
    expect(scrubbed.every((a) => a.ip === null)).toBe(true);
    const flat = JSON.stringify(scrubbed);
    expect(flat).not.toContain(u.username);
    expect(flat).not.toContain(u.email);
    expect(scrubbed.find((a) => a.action === 'profile.username.change')!.metadata).toEqual({ kept: 1 });
    expect(
      (
        await ctx.prisma.auditLog.findFirstOrThrow({
          where: { targetId: u.id, action: 'account.deletion.purged' },
        })
      ).metadata,
    ).toMatchObject({ held: 4 });

    // -- Admins read a hold only with the CLI, and each view is audited with its reason.
    expect(accountAdmin('holds').status).toBe(1); // a reason is required
    const listed = accountAdmin('holds', '--reason', 'weekly legal review');
    expect(listed.status, listed.out).toBe(0);
    expect(listed.out).toContain(postHold.id);
    expect(listed.out).not.toContain('held post text');
    const shown = accountAdmin('hold-show', postReport2.id, '--reason', 'police request #77');
    expect(shown.status, shown.out).toBe(0);
    expect(shown.out).toContain('held post text');
    expect(shown.out).toContain(postReport.id);
    expect(shown.out).toContain(heldPic.largeKey);
    expect(accountAdmin('hold-show', randomUUID(), '--reason', 'x').status).toBe(1);
    const views = await ctx.prisma.auditLog.findMany({
      where: { action: 'account.deletion.hold_viewed' },
      orderBy: { createdAt: 'asc' },
    });
    expect(views.map((v) => (v.metadata as { reason: string }).reason)).toEqual(
      expect.arrayContaining(['weekly legal review', 'police request #77']),
    );
    const itemView = views.find((v) => v.targetId === postHold.id)!;
    expect(itemView.metadata).toMatchObject({ via: 'cli', scope: 'item', heldType: 'POST' });
    expect((itemView.metadata as { reportIds: string[] }).reportIds.sort()).toEqual(
      [postReport.id, postReport2.id].sort(),
    );

    // -- 90 days: not a minute before; then the hold goes with its reports and files.
    const early = await sweeper.sweep(new Date(postHold.deleteAfter.getTime() - 60_000));
    expect(early.holdsExpired).toBe(0);
    expect(await ctx.prisma.legalHold.count({ where: { userId: u.id } })).toBe(4);
    const expired = await sweeper.sweep(new Date(postHold.deleteAfter.getTime() + 60_000));
    expect(expired.holdsExpired).toBeGreaterThanOrEqual(4);
    expect(await ctx.prisma.legalHold.count({ where: { userId: u.id } })).toBe(0);
    expect(
      await ctx.prisma.report.count({
        where: { id: { in: [postReport.id, postReport2.id, commentReport.id, dmReport.id, linkReport.id] } },
      }),
    ).toBe(0);
    expect(storage.objects.has(heldPic.largeKey)).toBe(false);
    expect(storage.objects.has(heldPic.thumbKey)).toBe(false);
    expect(storage.objects.has(dmFile)).toBe(false);
    const expiredAudit = await ctx.prisma.auditLog.findMany({
      where: { action: 'account.deletion.hold_expired', targetId: { in: holds.map((h) => h.id) } },
    });
    expect(expiredAudit).toHaveLength(4);
    expect(JSON.stringify(expiredAudit)).not.toContain(u.id);

    // -- 7 years (2557 days) after the purge: the ledgers stay anonymous, the rest of the trail goes.
    const purgedAt = (await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).deletedAt!;
    // (Tombstones purged earlier in this file, at the real time, may end here already; this one not yet.)
    await sweeper.sweep(new Date(purgedAt.getTime() + 2556 * DAY_MS));
    expect(await ctx.prisma.accountDeletionRequest.count({ where: { userId: u.id } })).toBe(1);
    expect((await userAudit()).length).toBeGreaterThanOrEqual(3);
    const after7 = await sweeper.sweep(new Date(purgedAt.getTime() + 2557 * DAY_MS + 60_000));
    expect(after7.retentionEnded).toBeGreaterThanOrEqual(1);
    expect(await userAudit()).toHaveLength(0);
    expect(await ctx.prisma.accountDeletionRequest.count({ where: { userId: u.id } })).toBe(0);
    expect(await ctx.prisma.luckyGiftAgeConfirmation.count({ where: { userId: u.id } })).toBe(0);
    const w = await ctx.prisma.cherryWithdrawal.findFirstOrThrow({ where: { userId: u.id } });
    expect(w).toMatchObject({ payoutDetails: '…', decisionNote: null, amountMinor: 110n, status: 'PAID' });
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: u.id } })).toBe(ledgerRows);
    expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: u.id } })).status).toBe('DELETED');
    const ended = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'account.deletion.retention_ended' },
      orderBy: { createdAt: 'desc' },
    });
    expect(ended).toMatchObject({ targetId: null, actorUserId: null });
    expect(ended.metadata).toMatchObject({ retentionDays: 2557 });
    // Idempotent: the next sweep finds nothing more for it.
    expect((await sweeper.sweep(new Date(purgedAt.getTime() + 2558 * DAY_MS))).retentionEnded).toBe(0);
  });
});
