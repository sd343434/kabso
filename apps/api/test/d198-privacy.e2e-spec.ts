/**
 * D198 (owner: Kabso Live is a GLOBAL app — privacy compliance; contract v1.66-social, CONVENTIONS §10.61, CP-040):
 * the personal-data export «تنزيل بياناتي» (password again, async ZIP with JSON + README, single-use 7-day link with
 * the bearer token, one per 24 h, audited, never secrets or other people's private data), versioned legal documents
 * (`legal-admin publish`), consent records (sign-up, the consent screen, the top-up terms, the lucky gifts' 18+
 * statement) and the 428 CONSENT_REQUIRED gate. End to end against PostgreSQL + Redis.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateRawSync } from 'node:zlib';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { ConsentsService } from '../src/modules/privacy/consents.service.js';
import { DataExportsService } from '../src/modules/privacy/data-exports.service.js';
import { truncateIp } from '../src/modules/privacy/legal.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  now(): Date {
    return new Date();
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const API_DIR = fileURLToPath(new URL('..', import.meta.url));

function cli(script: string, ...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', script, ...args], {
      cwd: API_DIR,
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

/** Reads a ZIP made by our writer (central directory; STORED or DEFLATE). */
function unzip(buf: Buffer): Map<string, Buffer> {
  const out = new Map<string, Buffer>();
  const end = buf.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  expect(end).toBeGreaterThan(0);
  const count = buf.readUInt16LE(end + 10);
  let p = buf.readUInt32LE(end + 16);
  for (let i = 0; i < count; i++) {
    expect(buf.readUInt32LE(p)).toBe(0x02014b50);
    const method = buf.readUInt16LE(p + 10);
    const csize = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extra = buf.readUInt16LE(p + 30);
    const comment = buf.readUInt16LE(p + 32);
    const offset = buf.readUInt32LE(p + 42);
    const name = buf.subarray(p + 46, p + 46 + nameLen).toString('utf8');
    const lname = buf.readUInt16LE(offset + 26);
    const lextra = buf.readUInt16LE(offset + 28);
    const data = buf.subarray(offset + 30 + lname + lextra, offset + 30 + lname + lextra + csize);
    out.set(name, method === 8 ? inflateRawSync(data) : Buffer.from(data));
    p += 46 + nameLen + extra + comment;
  }
  return out;
}

describe('D198 contract coverage', () => {
  it('openapi v1.66-social declares the privacy routes', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getLegalDocuments GET /api/v1/legal/documents',
        'getMyConsents GET /api/v1/me/consents',
        'acceptConsents POST /api/v1/me/consents',
        'listMyDataExports GET /api/v1/me/data-exports',
        'requestDataExport POST /api/v1/me/data-exports',
        'createDataExportLink POST /api/v1/me/data-exports/{exportId}/link',
        'downloadDataExport GET /api/v1/me/data-exports/{exportId}/file',
      ]),
    );
  });

  it('truncates IPs to /24 and /48', () => {
    expect(truncateIp('203.0.113.77')).toBe('203.0.113.0');
    expect(truncateIp('::ffff:198.51.100.9')).toBe('198.51.100.0');
    expect(truncateIp('2001:db8:abcd:12::1')).toBe('2001:db8:abcd::');
    expect(truncateIp('not an ip')).toBeNull();
  });
});

describe('D198 privacy', { timeout: 300_000 }, () => {
  const storage = new MemoryObjectStorage();
  const clock = new FakeClock();
  let ctx: TestContext;
  let exportsSvc: DataExportsService;
  let consents: ConsentsService;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (overrides: Record<string, unknown> = {}): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx, overrides);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email),
      password: String(payload.password),
      token: res.body.tokens.accessToken as string,
    };
  };
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({ where: { action, ...(targetId ? { targetId } : {}) } });
  const askExport = (u: TestUser, password = u.password) =>
    ctx.http.post('/api/v1/me/data-exports').set(auth(u)).send({ password });
  const publishFile = (() => {
    const dir = mkdtempSync(join(tmpdir(), 'd198-'));
    return (name: string, text: string) => {
      const file = join(dir, name);
      writeFileSync(file, text);
      return file;
    };
  })();

  beforeAll(async () => {
    ctx = await createTestApp({ MEDIA_PUBLIC_BASE_URL: 'https://media.kabso.example' }, [
      { token: Clock, value: clock },
      { token: OBJECT_STORAGE, value: storage },
    ]);
    exportsSvc = ctx.app.get(DataExportsService);
    consents = ctx.app.get(ConsentsService);
  });
  afterAll(async () => ctx?.close());

  it('exports the person’s data (expected sections) without secrets or other people’s private data', async () => {
    const alice = await signup({ legal: { ageConfirmed: true } });
    const bob = await signup();
    const carol = await signup();
    // Alice's content and relations.
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(alice))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'my first post' });
    expect(post.status, JSON.stringify(post.body)).toBe(201);
    expect((await ctx.http.put(`/api/v1/users/${bob.username}/follow`).set(auth(alice))).status).toBeLessThan(
      300,
    );
    expect((await ctx.http.put(`/api/v1/users/${alice.username}/follow`).set(auth(bob))).status).toBeLessThan(
      300,
    );
    expect((await ctx.http.put(`/api/v1/users/${carol.username}/block`).set(auth(alice))).status).toBe(200);
    const sent = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(alice))
      .send({ to: bob.username, clientId: randomUUID(), kind: 'TEXT', text: 'hi bob' });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    const reply = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(bob))
      .send({ to: alice.username, clientId: randomUUID(), kind: 'TEXT', text: 'hi alice' });
    expect(reply.status, JSON.stringify(reply.body)).toBe(201);
    // Bob also talks to Carol: never in Alice's export.
    await ctx.prisma.follow.create({ data: { followerId: carol.id, followeeId: bob.id } });
    // Alice's withdrawal and her (own) KYC application with pictures in private storage.
    await ctx.prisma.cherryWithdrawal.create({
      data: {
        userId: alice.id,
        clientId: randomUUID(),
        cherries: 1000n,
        amountMinor: 1n,
        currency: 'USD',
        rateCherries: 1000n,
        rateMinor: 1,
        payoutDetails: 'IBAN SA00 0000 9876',
        status: 'REJECTED',
        decidedAt: new Date(),
        decisionNote: 'internal note for the team',
      },
    });
    const app = await ctx.prisma.rechargeAgentApplication.create({
      data: {
        userId: alice.id,
        status: 'PENDING',
        fullName: 'Alice Real Name',
        phone: '+962790000001',
        photoKey: `private/recharge-agents/x/photo.webp`,
        selfieKey: `private/recharge-agents/x/selfie.webp`,
        locations: [],
        paymentMethods: [],
      },
    });
    storage.putRaw('private/recharge-agents/x/photo.webp', Buffer.from('PHOTO-BYTES'), 'image/webp');
    storage.putRaw('private/recharge-agents/x/selfie.webp', Buffer.from('SELFIE-BYTES'), 'image/webp');
    // An internal fraud signal on her levels must not leak.
    await ctx.prisma.auditLog.create({
      data: {
        action: 'admin.fraud.flag',
        targetType: 'user',
        targetId: alice.id,
        metadata: { risk: 'SECRET-RISK' },
      },
    });

    // 401 / 400 / wrong password (audited).
    expect((await ctx.http.post('/api/v1/me/data-exports').send({ password: 'x' })).status).toBe(401);
    const bad = await ctx.http.post('/api/v1/me/data-exports').set(auth(alice)).send({});
    expect(bad.status).toBe(400);
    const wrong = await askExport(alice, 'not the password at all');
    expect(wrong.status).toBe(403);
    expectContract(wrong, 'requestDataExport');
    expect(wrong.body.error.code).toBe('REAUTH_FAILED');
    expect(await audits('privacy.export.reauth_failed', alice.id)).toHaveLength(1);

    const asked = await askExport(alice);
    expect(asked.status, JSON.stringify(asked.body)).toBe(202);
    expectContract(asked, 'requestDataExport');
    expect(asked.body.status).toBe('PENDING');
    const exportId = asked.body.id as string;
    await settle(ctx); // the build runs after the response
    const listed = await ctx.http.get('/api/v1/me/data-exports').set(auth(alice));
    expect(listed.status).toBe(200);
    expectContract(listed, 'listMyDataExports');
    expect(listed.body.items[0]).toMatchObject({ id: exportId, status: 'READY' });
    expect(listed.body.nextAllowedAt).not.toBeNull();
    // A notification and a mail (no link in it).
    const notes = await ctx.prisma.notification.findMany({
      where: { recipientId: alice.id, type: 'DATA_EXPORT_READY' },
    });
    expect(notes).toHaveLength(1);
    const mail = ctx.mail.last(alice.email, 'data_export_ready');
    expect(mail?.link).toBe('');
    expect(await audits('privacy.export.requested', exportId)).toHaveLength(1);
    expect(await audits('privacy.export.ready', exportId)).toHaveLength(1);
    // Stored privately.
    const row = await ctx.prisma.dataExport.findUniqueOrThrow({ where: { id: exportId } });
    expect(row.objectKey).toBe(`private/data-exports/${alice.id}/${exportId}.zip`);
    expect(storage.objects.get(row.objectKey!)?.cacheControl).toBe('private, no-store');

    // Someone else cannot get a link or the file.
    expect((await ctx.http.post(`/api/v1/me/data-exports/${exportId}/link`).set(auth(bob))).status).toBe(410);
    const link = await ctx.http.post(`/api/v1/me/data-exports/${exportId}/link`).set(auth(alice));
    expect(link.status, JSON.stringify(link.body)).toBe(200);
    expectContract(link, 'createDataExportLink');
    const path = link.body.path as string;
    expect((await ctx.http.get(path)).status).toBe(401); // auth required
    expect((await ctx.http.get(path).set(auth(bob))).status).toBe(410);
    const wrongToken = path.replace(/token=.*/, `token=${'A'.repeat(43)}`);
    expect((await ctx.http.get(wrongToken).set(auth(alice))).status).toBe(410);

    const file = await ctx.http
      .get(path)
      .set(auth(alice))
      .buffer(true)
      .parse((res, cb) => {
        const chunks: Buffer[] = [];
        res.on('data', (c: Buffer) => chunks.push(c));
        res.on('end', () => cb(null, Buffer.concat(chunks)));
      });
    expect(file.status).toBe(200);
    expect(file.headers['content-type']).toBe('application/zip');
    expect(file.headers['cache-control']).toBe('no-store');
    const zip = file.body as Buffer;
    expect(await audits('privacy.export.downloaded', exportId)).toHaveLength(1);

    // Single use: the same link (or a new one) no longer works.
    const again = await ctx.http.get(path).set(auth(alice));
    expect(again.status).toBe(410);
    expect(again.body.error.code).toBe('DATA_EXPORT_LINK_INVALID');
    expect((await ctx.http.post(`/api/v1/me/data-exports/${exportId}/link`).set(auth(alice))).status).toBe(
      410,
    );

    // The content.
    const entries = unzip(zip);
    expect([...entries.keys()]).toEqual(
      expect.arrayContaining([
        'README.txt',
        'manifest.json',
        'data/profile.json',
        'data/settings.json',
        'data/posts.json',
        'data/stories.json',
        'data/comments.json',
        'data/messages.json',
        'data/follows.json',
        'data/blocks.json',
        'data/coins.json',
        'data/cherries.json',
        'data/levels.json',
        'data/gifts.json',
        'data/withdrawals.json',
        'data/topups.json',
        'data/recharge_agent.json',
        'data/consents.json',
        'data/devices.json',
        `files/recharge-agent/${app.id}/photo.webp`,
        `files/recharge-agent/${app.id}/selfie.webp`,
      ]),
    );
    const readme = entries.get('README.txt')!.toString('utf8');
    expect(readme).toContain('نسخة من بياناتك');
    expect(readme).toContain('a copy of your data');
    const json = <T>(name: string): T => JSON.parse(entries.get(`data/${name}.json`)!.toString('utf8')) as T;
    expect(json<{ email: string; username: string }>('profile')).toMatchObject({
      email: alice.email,
      username: alice.username,
    });
    expect(json<{ text: string }[]>('posts').map((p) => p.text)).toEqual(['my first post']);
    const msgs = json<{ direction: string; text: string; with: { username: string } }[]>('messages');
    expect(msgs.map((m) => [m.direction, m.text, m.with.username]).sort()).toEqual(
      [
        ['received', 'hi alice', bob.username],
        ['sent', 'hi bob', bob.username],
      ].sort(),
    );
    const follows = json<{ following: { username: string }[]; followers: { username: string }[] }>('follows');
    expect(follows.following.map((f) => f.username)).toEqual([bob.username]);
    expect(follows.followers.map((f) => f.username)).toEqual([bob.username]);
    expect(json<{ blocked: { username: string }[] }>('blocks').blocked.map((b) => b.username)).toEqual([
      carol.username,
    ]);
    expect(json<{ payoutDetails: string }[]>('withdrawals')[0]!.payoutDetails).toBe('…9876');
    expect(json<{ fullName: string }[]>('recharge_agent')[0]!.fullName).toBe('Alice Real Name');
    expect(entries.get(`files/recharge-agent/${app.id}/photo.webp`)!.toString()).toBe('PHOTO-BYTES');
    const consentsOut = json<{ acceptances: { document: string; method: string }[] }>('consents');
    expect(consentsOut.acceptances).toEqual([
      expect.objectContaining({ document: 'AGE_18', method: 'REGISTRATION' }),
    ]);
    expect(json<{ sessions: unknown[] }>('devices').sessions.length).toBeGreaterThan(0);
    const manifest = JSON.parse(entries.get('manifest.json')!.toString()) as {
      sections: Record<string, number>;
    };
    expect(manifest.sections.posts).toBe(1);

    // Never: secrets, hashes, tokens, admin notes, fraud signals, other people's private data.
    const all = [...entries.values()].map((b) => b.toString('utf8')).join('\n');
    const user = await ctx.prisma.user.findUniqueOrThrow({ where: { id: alice.id } });
    const sessions = await ctx.prisma.session.findMany({ where: { userId: alice.id } });
    expect(all).not.toContain(user.passwordHash);
    expect(all).not.toContain('$argon2');
    for (const s of sessions) expect(all).not.toContain(s.refreshTokenHash);
    expect(all).not.toContain('passwordHash');
    expect(all).not.toContain('refreshToken');
    expect(all).not.toContain('totp');
    expect(all).not.toContain('internal note for the team');
    expect(all).not.toContain('SECRET-RISK');
    expect(all).not.toContain('IBAN SA00');
    expect(all).not.toContain(bob.email);
    expect(all).not.toContain(carol.email);
    expect(all).not.toContain(bob.id);
    expect(all).not.toContain(carol.id);
  });

  it('allows one export per 24 hours (429 + Retry-After, audited), and the link expires after 7 days', async () => {
    const u = await signup();
    expect((await askExport(u)).status).toBe(202);
    const second = await askExport(u);
    expect(second.status).toBe(429);
    expectContract(second, 'requestDataExport');
    expect(second.body.error.code).toBe('DATA_EXPORT_LIMIT');
    expect(Number(second.headers['retry-after'])).toBeGreaterThan(23 * 3600);
    expect(await audits('privacy.export.limited', u.id)).toHaveLength(1);
    await settle(ctx);
    const [job] = (await ctx.http.get('/api/v1/me/data-exports').set(auth(u))).body.items as { id: string }[];
    const link = await ctx.http.post(`/api/v1/me/data-exports/${job!.id}/link`).set(auth(u));
    expect(link.status).toBe(200);

    // 7 days later: the link has expired; the sweeper marks it and deletes the file.
    const created = await ctx.prisma.dataExport.findUniqueOrThrow({ where: { id: job!.id } });
    expect(created.expiresAt!.getTime() - created.readyAt!.getTime()).toBe(7 * DAY);
    await ctx.prisma.dataExport.update({
      where: { id: job!.id },
      data: { expiresAt: new Date(Date.now() - HOUR), requestedAt: new Date(Date.now() - DAY - HOUR) },
    });
    const late = await ctx.http.get(link.body.path as string).set(auth(u));
    expect(late.status).toBe(410);
    const swept = await exportsSvc.sweep();
    expect(swept.expired).toBeGreaterThanOrEqual(1);
    const row = await ctx.prisma.dataExport.findUniqueOrThrow({ where: { id: job!.id } });
    expect(row.status).toBe('EXPIRED');
    expect(row.objectKey).toBeNull();
    expect(storage.objects.has(`private/data-exports/${u.id}/${job!.id}.zip`)).toBe(false);
    expect(await audits('privacy.export.expired', job!.id)).toHaveLength(1);
    // And after 24 hours a new export may be asked for.
    expect((await askExport(u)).status).toBe(202);
    await settle(ctx);
  });

  it('privacy-admin lists exports and queues one for a verified emailed request (audited)', async () => {
    const u = await signup();
    expect(cli('privacy:admin', 'export', u.email).status).toBe(1); // no reason
    const queued = cli('privacy:admin', 'export', u.email, '--reason', 'verified email request 2026-11-01');
    expect(queued.status, queued.out).toBe(0);
    const job = await ctx.prisma.dataExport.findFirstOrThrow({ where: { userId: u.id } });
    expect(job).toMatchObject({ status: 'PENDING', requestedVia: 'ADMIN' });
    expect(cli('privacy:admin', 'export', u.email, '--reason', 'again').status).toBe(1); // 24 h limit
    await exportsSvc.sweep(clock.now());
    expect((await ctx.prisma.dataExport.findUniqueOrThrow({ where: { id: job.id } })).status).toBe('READY');
    const list = cli('privacy:admin', 'exports', u.email);
    expect(list.status, list.out).toBe(0);
    expect(list.out).toContain(job.id);
    expect(await audits('privacy.export.admin_view', u.id)).toHaveLength(1);
    const dir = mkdtempSync(join(tmpdir(), 'd198-save-'));
    try {
      const other = await signup();
      const saved = cli('privacy:admin', 'export', other.email, '--reason', 'verified email', '--save', dir);
      expect(saved.status, saved.out).toBe(0);
      const file = /(\S+\.zip)/.exec(saved.out)?.[1];
      expect(unzip(readFileSync(file!)).has('data/profile.json')).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('records the 18+ statement and the versions accepted at sign-up', async () => {
    const terms = cli(
      'legal:admin',
      'publish',
      'terms',
      '--version',
      '2026-11-01',
      '--effective',
      new Date(clock.now().getTime() - HOUR).toISOString(),
      '--file',
      publishFile('terms.html', '<h1>terms v1</h1>'),
      '--summary-ar',
      'الإصدار الأول',
      '--summary-en',
      'First version',
    );
    expect(terms.status, terms.out).toBe(0);
    const privacy = cli(
      'legal:admin',
      'publish',
      'privacy',
      '--version',
      '2026-11-01',
      '--effective',
      new Date(clock.now().getTime() - HOUR).toISOString(),
      '--file',
      publishFile('privacy.html', '<h1>privacy v1</h1>'),
      '--summary-ar',
      'الإصدار الأول',
      '--summary-en',
      'First version',
    );
    expect(privacy.status, privacy.out).toBe(0);
    expect(await audits('legal.document.publish')).toHaveLength(2);
    consents.forget();
    const docs = await ctx.http.get('/api/v1/legal/documents');
    expect(docs.status).toBe(200);
    expectContract(docs, 'getLegalDocuments');
    expect(
      (docs.body.documents as { kind: string; version: string }[]).map((d) => `${d.kind}@${d.version}`),
    ).toEqual(['TERMS@2026-11-01', 'PRIVACY@2026-11-01']);
    // A bad register body.
    const bad = await ctx.http.post('/api/v1/auth/register').send({
      ...{
        email: 'x@example.com',
        password: 'correct horse battery staple',
        username: 'xbadlegal',
        displayName: 'X',
        gender: 'UNDISCLOSED',
      },
      legal: { ageConfirmed: false },
    });
    expect(bad.status).toBe(400);

    const u = await signup({
      legal: { ageConfirmed: true, termsVersion: '2026-11-01', privacyVersion: '2026-11-01' },
    });
    const rows = await ctx.prisma.userConsent.findMany({
      where: { userId: u.id },
      orderBy: { document: 'asc' },
    });
    expect(rows.map((r) => `${r.document}@${r.version}:${r.method}`).sort()).toEqual(
      ['AGE_18@18+:REGISTRATION', 'PRIVACY@2026-11-01:REGISTRATION', 'TERMS@2026-11-01:REGISTRATION'].sort(),
    );
    // Not blocked: everything accepted at sign-up.
    expect((await ctx.http.get('/api/v1/notifications').set(auth(u))).status).toBe(200);
    const status = await ctx.http.get('/api/v1/me/consents').set(auth(u));
    expect(status.status).toBe(200);
    expectContract(status, 'getMyConsents');
    expect(status.body.required).toEqual([]);
  });

  it('a new version gives 428 CONSENT_REQUIRED until it is accepted; accepting records it', async () => {
    const u = await signup({
      legal: { ageConfirmed: true, termsVersion: '2026-11-01', privacyVersion: '2026-11-01' },
    });
    const oldClient = await signup(); // sent no legal block
    expect((await ctx.http.get('/api/v1/notifications').set(auth(oldClient))).status).toBe(428);

    const v2 = cli(
      'legal:admin',
      'publish',
      'privacy',
      '--version',
      '2026-12-01',
      '--effective',
      new Date(clock.now().getTime() - 60_000).toISOString(),
      '--file',
      publishFile('privacy2.html', '<h1>privacy v2</h1>'),
      '--summary-ar',
      'أضفنا حقوق المستخدمين حسب المنطقة',
      '--summary-en',
      'We added the rights by region',
    );
    expect(v2.status, v2.out).toBe(0);
    expect(
      cli(
        'legal:admin',
        'publish',
        'privacy',
        '--version',
        '2026-12-01',
        '--effective',
        '2026-12-01',
        '--file',
        publishFile('p.html', 'x'),
        '--summary-ar',
        'x',
        '--summary-en',
        'x',
      ).status,
    ).toBe(1);
    consents.forget();

    const blocked = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(blocked.status).toBe(428);
    expect(blocked.body.error.code).toBe('CONSENT_REQUIRED');
    expect(blocked.body.error.details).toEqual([{ field: 'privacy', issue: '2026-12-01' }]);
    // Exempt: the consent screen, me, logout path, deletion info, data export.
    expect((await ctx.http.get('/api/v1/me').set(auth(u))).status).toBe(200);
    expect((await ctx.http.get('/api/v1/me/account-deletion').set(auth(u))).status).toBe(200);
    expect((await ctx.http.get('/api/v1/me/data-exports').set(auth(u))).status).toBe(200);
    expect((await ctx.http.get('/api/v1/auth/sessions').set(auth(u))).status).toBe(200);
    const st = await ctx.http.get('/api/v1/me/consents').set(auth(u));
    expect(st.status).toBe(200);
    expect(
      (st.body.required as { kind: string; version: string; summaryEn: string }[]).map((d) => [
        d.kind,
        d.version,
        d.summaryEn,
      ]),
    ).toEqual([['PRIVACY', '2026-12-01', 'We added the rights by region']]);

    // An old version → 409; the version in force → recorded and audited.
    const stale = await ctx.http
      .post('/api/v1/me/consents')
      .set(auth(u))
      .send({ accept: [{ kind: 'PRIVACY', version: '2026-11-01' }] });
    expect(stale.status).toBe(409);
    expectContract(stale, 'acceptConsents');
    expect(stale.body.error.code).toBe('CONSENT_VERSION_MISMATCH');
    expect((await ctx.http.post('/api/v1/me/consents').set(auth(u)).send({ accept: [] })).status).toBe(400);
    const ok = await ctx.http
      .post('/api/v1/me/consents')
      .set(auth(u))
      .set('User-Agent', 'KabsoTest/1.0')
      .set('X-Forwarded-For', '203.0.113.77')
      .send({ accept: [{ kind: 'PRIVACY', version: '2026-12-01' }] });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'acceptConsents');
    expect(ok.body.required).toEqual([]);
    const rec = await ctx.prisma.userConsent.findFirstOrThrow({
      where: { userId: u.id, document: 'PRIVACY', version: '2026-12-01' },
    });
    expect(rec.method).toBe('IN_APP');
    expect(rec.userAgent).toBe('KabsoTest/1.0');
    expect(rec.ipTruncated === null || /\.0$|::$/.test(rec.ipTruncated)).toBe(true);
    expect(await audits('privacy.consent.accept', u.id)).toHaveLength(1);
    // Idempotent.
    const twice = await ctx.http
      .post('/api/v1/me/consents')
      .set(auth(u))
      .send({ accept: [{ kind: 'PRIVACY', version: '2026-12-01' }] });
    expect(twice.status).toBe(200);
    expect(await ctx.prisma.userConsent.count({ where: { userId: u.id, version: '2026-12-01' } })).toBe(1);
    expect((await ctx.http.get('/api/v1/notifications').set(auth(u))).status).toBe(200);

    // The old client accepts both.
    const both = await ctx.http
      .post('/api/v1/me/consents')
      .set(auth(oldClient))
      .send({
        accept: [
          { kind: 'TERMS', version: '2026-11-01' },
          { kind: 'PRIVACY', version: '2026-12-01' },
        ],
      });
    expect(both.status).toBe(200);
    expect((await ctx.http.get('/api/v1/notifications').set(auth(oldClient))).status).toBe(200);

    // A version effective tomorrow is not enforced yet.
    expect(
      cli(
        'legal:admin',
        'publish',
        'terms',
        '--version',
        '2027-01-01',
        '--effective',
        new Date(clock.now().getTime() + DAY).toISOString(),
        '--file',
        publishFile('t2.html', 't2'),
        '--summary-ar',
        'ب',
        '--summary-en',
        'b',
      ).status,
    ).toBe(0);
    consents.forget();
    expect((await ctx.http.get('/api/v1/notifications').set(auth(u))).status).toBe(200);
    expect(cli('legal:admin', 'list').out).toContain('(not yet in force)');
  });

  it('the account deletion purge removes exports and clears the consents’ IP and user agent', async () => {
    const { requestDeletionIn, purgeAccountIn } = await import('../src/modules/users/account-deletion.js');
    const u = await signup({
      legal: { ageConfirmed: true, termsVersion: '2026-11-01', privacyVersion: '2026-12-01' },
    });
    await ctx.prisma.userConsent.updateMany({
      where: { userId: u.id },
      data: { ipTruncated: '203.0.113.0', userAgent: 'UA' },
    });
    expect((await askExport(u)).status).toBe(202);
    await settle(ctx);
    const job = await ctx.prisma.dataExport.findFirstOrThrow({ where: { userId: u.id } });
    expect(job.status).toBe('READY');
    await ctx.prisma.$transaction((tx) =>
      requestDeletionIn(tx, u.id, clock.now(), 30, { via: 'ADMIN', reason: 'test' }),
    );
    const result = await ctx.prisma.$transaction((tx) =>
      purgeAccountIn(tx, u.id, clock.now(), {
        via: 'ADMIN',
        reason: 'test',
        quarantineDays: 0,
        specialGraceDays: 30,
        legalHoldDays: 90,
      }),
    );
    expect(result!.objectKeys).toContain(job.objectKey);
    expect(await ctx.prisma.dataExport.count({ where: { userId: u.id } })).toBe(0);
    const left = await ctx.prisma.userConsent.findMany({ where: { userId: u.id } });
    expect(left.length).toBeGreaterThan(0);
    expect(left.every((c) => c.ipTruncated === null && c.userAgent === null)).toBe(true);
  });
});
