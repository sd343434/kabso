/**
 * D381 (contract v1.134-social, CONVENTIONS §10.171.3) PRIORITY_SUPPORT in the WhatsApp staff inbox: a conversation
 * linked to an account holding the perk (inherited too) is marked `priority` and listed first; unlinking, or a new
 * message after the VIP ended, clears it. End to end against PostgreSQL + Redis and a fake Graph API.
 */
import { randomBytes } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeWhatsAppGraph, signatureOf, webhookBody } from './helpers/fake-whatsapp.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, settle, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const PNID = '1098765432101';
const WABA = '2098765432101';
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const DAY = 86_400_000;
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const unix = (d = new Date()) => String(Math.floor(d.getTime() / 1000));

describe('D381 PRIORITY_SUPPORT in the WhatsApp inbox', { timeout: 300_000 }, () => {
  const accessToken = randomBytes(24).toString('base64url');
  const appSecret = randomBytes(16).toString('hex');
  const verifyToken = randomBytes(16).toString('base64url');
  const graph = new FakeWhatsAppGraph(accessToken, PNID, WABA);
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let holder: Person;
  let seq = 0;

  const hook = (phone: string, body: string) => {
    seq += 1;
    const raw = webhookBody(PNID, {
      contacts: [{ profile: { name: `c${String(seq)}` }, wa_id: phone }],
      messages: [
        { from: phone, id: `wamid.D381${String(seq)}`, timestamp: unix(), type: 'text', text: { body } },
      ],
    });
    return ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .set('X-Hub-Signature-256', signatureOf(raw, appSecret))
      .send(raw);
  };
  const conversations = async () => {
    const res = await ctx.http.get('/api/v1/staff/whatsapp/conversations?filter=all').set(auth(owner));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getStaffWhatsAppConversations');
    return res.body.data as { id: string; phone: string; priority: boolean }[];
  };

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa-d381-'));
    const file = (n: string, v: string) => {
      const path = join(dir, n);
      writeFileSync(path, v, { mode: 0o600 });
      return path;
    };
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      WHATSAPP_PHONE_NUMBER_ID: PNID,
      WHATSAPP_BUSINESS_ACCOUNT_ID: WABA,
      WHATSAPP_ACCESS_TOKEN_FILE: file('token', accessToken),
      WHATSAPP_APP_SECRET_FILE: file('secret', appSecret),
      WHATSAPP_VERIFY_TOKEN_FILE: file('verify', verifyToken),
      WHATSAPP_GRAPH_BASE_URL: graph.base,
      WHATSAPP_SWEEP_INTERVAL_SECONDS: '0',
      WHATSAPP_PUSH_GAP_SECONDS: '0',
      API_PUBLIC_URL: 'https://api.kabso.example',
    });
    owner = await p.makeAdmin(['OWNER']);
    holder = await p.signup();
    vi.useRealTimers();
    const v1 = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      reason: 'owner D381',
      perks: [{ code: 'BADGE' }, { code: 'PRIORITY_SUPPORT' }],
    });
    expect(v1.status, JSON.stringify(v1.body)).toBe(200);
    // A VIP_2 member: PRIORITY_SUPPORT inherited from VIP_1.
    const v2 = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_2',
      nameAr: 'في آي بي 2',
      nameEn: 'VIP 2',
      color: '#3366CC',
      priceCoins: 2_000_000,
      durationDays: 30,
      enabled: true,
      perks: [{ code: 'BADGE' }],
      reason: 'owner D381',
    });
    expect(v2.status, JSON.stringify(v2.body)).toBe(201);
    await withMigrationClient((db) =>
      db.vipMembership.create({
        data: {
          userId: holder.id,
          tierId: v2.body.id as string,
          startedAt: new Date(Date.now() - DAY),
          expiresAt: new Date(Date.now() + 30 * DAY),
        },
      }),
    );
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it("a holder's linked conversation is listed first; unlinking or an ended VIP clears it", async () => {
    expect((await hook('966500000001', 'hello from the holder')).status).toBe(200);
    expect((await hook('966500000002', 'a later message from someone else')).status).toBe(200);
    await settle(ctx);
    let list = await conversations();
    // Newest first, nobody has priority yet.
    expect(list.map((c) => [c.phone, c.priority])).toEqual([
      ['+966500000002', false],
      ['+966500000001', false],
    ]);
    const first = list[1]!.id;
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: holder.id } });
    const linked = await ctx.http
      .post(`/api/v1/staff/whatsapp/conversations/${first}/link`)
      .set(auth(owner))
      .send({ username: profile.username });
    expect(linked.status, JSON.stringify(linked.body)).toBe(200);
    expectContract(linked, 'linkStaffWhatsAppConversation');
    expect(linked.body.priority).toBe(true);
    list = await conversations();
    expect(list.map((c) => [c.phone, c.priority])).toEqual([
      ['+966500000001', true],
      ['+966500000002', false],
    ]);
    // Page by page (limit 1) the order holds.
    const page1 = await ctx.http
      .get('/api/v1/staff/whatsapp/conversations?filter=all&limit=1')
      .set(auth(owner));
    expect(page1.body.data[0].id).toBe(first);
    const page2 = await ctx.http
      .get(
        `/api/v1/staff/whatsapp/conversations?filter=all&limit=1&cursor=${encodeURIComponent(page1.body.page.nextCursor as string)}`,
      )
      .set(auth(owner));
    expect(page2.status, JSON.stringify(page2.body)).toBe(200);
    expect(page2.body.data.map((c: { phone: string }) => c.phone)).toEqual(['+966500000002']);

    // The VIP ends: the holder's next message clears the mark.
    await withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: holder.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 1000) },
      }),
    );
    expect((await hook('966500000001', 'still waiting')).status).toBe(200);
    await settle(ctx);
    expect((await conversations()).find((c) => c.id === first)!.priority).toBe(false);

    // Linked again while not holding: no priority; unlinking keeps it off.
    const unlinked = await ctx.http
      .delete(`/api/v1/staff/whatsapp/conversations/${first}/link`)
      .set(auth(owner));
    expect(unlinked.status, JSON.stringify(unlinked.body)).toBe(200);
    expect(unlinked.body.priority).toBe(false);
  });
});
