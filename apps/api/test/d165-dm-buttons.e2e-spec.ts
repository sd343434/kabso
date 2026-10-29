/**
 * D165 (owner 2026-10-29: «الوكيل الثاني يعمل على زر الرسائل»): the Messages tab's buttons, end to
 * end against PostgreSQL + Redis (openapi v1.43.1-social DRAFT, CONVENTIONS §11.13): searching the
 * conversations (`listDmConversations?q=`, a case-insensitive prefix of the peer's username or
 * display name, the cursor bound to it) and the unread mark (`markDmUnread` / `clearDmUnread`,
 * `DmConversation.markedUnread`, the badge, cleared by `markDmRead`).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Row {
  id: string;
  markedUnread: boolean;
  unreadCount: number;
  peer: { username: string; displayName: string };
  lastMessage: { id: string } | null;
}

describe('D165 contract coverage', () => {
  it('openapi declares the unread mark operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('markDmUnread PUT /api/v1/dm/conversations/{conversationId}/unread');
    expect(ids).toContain('clearDmUnread DELETE /api/v1/dm/conversations/{conversationId}/unread');
  });
});

describe('D165 direct message buttons', { timeout: 240_000 }, () => {
  let ctx: TestContext;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (displayName = 'Test User'): Promise<TestUser> => {
    const { res } = await registerVerified(ctx, { displayName });
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const follow = async (by: TestUser, u: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  const text = async (by: TestUser, to: TestUser, t = 'hello') => {
    const res = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(by))
      .send({ to: to.username, kind: 'TEXT', text: t, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { message: { id: string; conversationId: string } };
  };
  const list = async (u: TestUser, query = '') => {
    const res = await ctx.http.get(`/api/v1/dm/conversations${query}`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listDmConversations');
    return res.body as { data: Row[]; page: { hasMore: boolean; nextCursor: string | null } };
  };
  const unread = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/dm/unread').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getDmUnread');
    return res.body as { messages: number; conversations: number; requests: number };
  };
  const friends = async (a: TestUser, b: TestUser) => {
    await follow(a, b);
    await follow(b, a);
  };

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('searches conversations by a prefix of the peer username or display name', async () => {
    const me = await signup();
    const sara = await signup('Sara Ahmad');
    const omar = await signup('عمر الحسن');
    const lina = await signup('Lina 100%');
    for (const u of [sara, omar, lina]) {
      await friends(me, u);
      await text(u, me);
    }
    const all = await list(me);
    expect(all.data).toHaveLength(3);
    for (const row of all.data) expect(row.markedUnread).toBe(false);

    // Display name, case-insensitive.
    expect((await list(me, '?q=sAR')).data.map((r) => r.peer.username)).toEqual([sara.username]);
    // Arabic display name.
    expect((await list(me, `?q=${encodeURIComponent('عمر')}`)).data.map((r) => r.peer.username)).toEqual([
      omar.username,
    ]);
    // Username prefix with a leading @ (all three usernames start with "user").
    expect((await list(me, `?q=${encodeURIComponent(`@${lina.username.toUpperCase()}`)}`)).data).toHaveLength(
      1,
    );
    // Only a prefix: the middle of a name does not match; LIKE wildcards are literal.
    expect((await list(me, '?q=ahmad')).data).toEqual([]);
    expect((await list(me, `?q=${encodeURIComponent('%')}`)).data).toEqual([]);
    expect((await list(me, `?q=${encodeURIComponent('_ina')}`)).data).toEqual([]);
    expect((await list(me, `?q=${encodeURIComponent('Lina 100%')}`)).data).toHaveLength(1);
    // The requests box is searched on its own.
    expect((await list(me, '?box=REQUESTS&q=sara')).data).toEqual([]);

    // Bounds: blank or longer than 30 → 400 q.
    for (const bad of ['%20%20', '@', 'x'.repeat(31)]) {
      const res = await ctx.http.get(`/api/v1/dm/conversations?q=${bad}`).set(auth(me));
      expect(res.status, bad).toBe(400);
      expectContract(res, 'listDmConversations');
      expect(res.body.error.details).toContainEqual(expect.objectContaining({ field: 'q' }));
    }

    // Paging keeps the search; a cursor from another search (or none) is refused.
    const first = await list(me, '?q=user&limit=2');
    expect(first.data).toHaveLength(2);
    expect(first.page.nextCursor).not.toBeNull();
    const cursor = encodeURIComponent(first.page.nextCursor ?? '');
    const second = await list(me, `?q=user&limit=2&cursor=${cursor}`);
    expect(second.data).toHaveLength(1);
    expect(new Set([...first.data, ...second.data].map((r) => r.id)).size).toBe(3);
    const other = await ctx.http.get(`/api/v1/dm/conversations?q=sara&cursor=${cursor}`).set(auth(me));
    expect(other.status).toBe(400);
    const none = await ctx.http.get(`/api/v1/dm/conversations?cursor=${cursor}`).set(auth(me));
    expect(none.status).toBe(400);
  });

  it('marks a conversation unread for the caller only and clears it on read', async () => {
    const me = await signup();
    const peer = await signup('Peer');
    await friends(me, peer);
    const sent = await text(peer, me, 'hi');
    const conversationId = sent.message.conversationId;
    expect(await unread(me)).toEqual({ messages: 1, conversations: 1, requests: 0 });

    const read = await ctx.http
      .post(`/api/v1/dm/conversations/${conversationId}/read`)
      .set(auth(me))
      .send({ lastMessageId: sent.message.id });
    expect(read.status).toBe(204);
    expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 0 });

    // Mark unread: 204, idempotent; counts as one; the peer sees nothing.
    for (let i = 0; i < 2; i += 1) {
      const res = await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/unread`).set(auth(me));
      expect(res.status).toBe(204);
    }
    let row = (await list(me)).data[0];
    expect(row?.markedUnread).toBe(true);
    expect(row?.unreadCount).toBe(0);
    expect(await unread(me)).toEqual({ messages: 1, conversations: 1, requests: 0 });
    expect((await list(peer)).data[0]?.markedUnread).toBe(false);
    expect(await unread(peer)).toEqual({ messages: 0, conversations: 0, requests: 0 });

    // A new message does not count twice.
    await text(peer, me, 'again');
    expect(await unread(me)).toEqual({ messages: 1, conversations: 1, requests: 0 });

    // Reading clears the mark.
    const last = (await list(me)).data[0]?.lastMessage?.id ?? '';
    const again = await ctx.http
      .post(`/api/v1/dm/conversations/${conversationId}/read`)
      .set(auth(me))
      .send({ lastMessageId: last });
    expect(again.status).toBe(204);
    row = (await list(me)).data[0];
    expect(row?.markedUnread).toBe(false);
    expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 0 });

    // DELETE clears it too (idempotent).
    await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/unread`).set(auth(me));
    for (let i = 0; i < 2; i += 1) {
      const res = await ctx.http.delete(`/api/v1/dm/conversations/${conversationId}/unread`).set(auth(me));
      expect(res.status).toBe(204);
    }
    expect((await list(me)).data[0]?.markedUnread).toBe(false);

    // A muted conversation is not in the badge, marked or not.
    await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/unread`).set(auth(me));
    await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/mute`).set(auth(me));
    expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 0 });
  });

  it('counts a marked request in requests; strangers and unknown ids get 404', async () => {
    const me = await signup();
    const stranger = await signup('Stranger');
    const sent = await text(stranger, me, 'hello?');
    const conversationId = sent.message.conversationId;
    await ctx.http
      .post(`/api/v1/dm/conversations/${conversationId}/read`)
      .set(auth(me))
      .send({ lastMessageId: sent.message.id });
    expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 0 });
    const res = await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/unread`).set(auth(me));
    expect(res.status).toBe(204);
    expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 1 });
    expect((await list(me, '?box=REQUESTS')).data[0]?.markedUnread).toBe(true);

    const outsider = await signup();
    for (const [path, user] of [
      [`/api/v1/dm/conversations/${conversationId}/unread`, outsider],
      [`/api/v1/dm/conversations/${randomUUID()}/unread`, me],
      ['/api/v1/dm/conversations/not-a-uuid/unread', me],
    ] as const) {
      const put = await ctx.http.put(path).set(auth(user));
      expect(put.status, path).toBe(404);
      expectContract(put, 'markDmUnread');
      const del = await ctx.http.delete(path).set(auth(user));
      expect(del.status, path).toBe(404);
      expectContract(del, 'clearDmUnread');
    }
    const anonymous = await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/unread`);
    expect(anonymous.status).toBe(401);
  });
});
