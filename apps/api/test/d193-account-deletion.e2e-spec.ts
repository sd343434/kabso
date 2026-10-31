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
import {
  DELETED_DISPLAY_NAME,
  purgeAccountIn,
  requestDeletionIn,
  TOMBSTONE_USERNAME,
  usernameHash,
} from '../src/modules/users/account-deletion.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

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
        purgeAccountIn(tx, agent.id, new Date(), { quarantineDays: 90, specialGraceDays: 30, via: 'ADMIN' }),
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
});
