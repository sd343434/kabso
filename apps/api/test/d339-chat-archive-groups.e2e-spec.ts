/**
 * D339 (owner 2026-11-09: «الدردشات، طلبات المراسلة، المؤرشفة، رسائل جماعية»): archived chats and group messages, end to
 * end against PostgreSQL + Redis with the API as the DML-only runtime role (openapi v1.104-social DRAFT, CONVENTIONS
 * §10.132, §10.133), a fake clock, in-memory object storage and a fake push sender. Covers: archiving per user (the
 * inbox, «المؤرشفة», the badge, a message from the peer brings it back, one's own does not, requests refused); groups —
 * who may be added (mutual follows, blocks, «من يستطيع مراسلتك», oneself), the member cap, idempotent create, the
 * photo, admins (add, remove, roles, rename; the creator protected), leaving (admin hand-over, the last member ends the
 * group), messages (kinds, read pointers and `readCount`, unread counts, mute, archive and its return, blocks hide,
 * new members see only new messages, delete rules, the 24-hour sweeper), pushes, `listDmChats` (both kinds by
 * recency, search, cursor) and reports (`DM_GROUP` snapshot, REMOVE_TARGET removes the group).
 */
import { randomUUID } from 'node:crypto';
import type { Redis } from 'ioredis';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DmSweeper } from '../src/modules/messages/dm-sweeper.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { REDIS } from '../src/redis/redis.module.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += seconds * 1000;
  }
}

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
  to(token: string): PushMessage[] {
    return this.sent.filter((m) => m.tokens.includes(token));
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface GroupDetail {
  group: {
    id: string;
    name: string;
    photoUrl: string | null;
    memberCount: number;
    role: string;
    muted: boolean;
    archived: boolean;
    unreadCount: number;
    lastMessage: { id: string; text: string | null; readCount: number } | null;
  };
  members: { user: { username: string }; role: string; creator: boolean }[];
  maxMembers: number;
}

interface Chat {
  type: 'DIRECT' | 'GROUP';
  id: string;
  conversation: { id: string; archived: boolean; peer: { username: string } } | null;
  group: { id: string; name: string; unreadCount: number } | null;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

describe('D339 contract coverage', () => {
  it('openapi declares the archive and group operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'archiveDmConversation PUT /api/v1/dm/conversations/{conversationId}/archive',
      'unarchiveDmConversation DELETE /api/v1/dm/conversations/{conversationId}/archive',
      'listDmChats GET /api/v1/dm/chats',
      'listDmGroupCandidates GET /api/v1/dm/group-candidates',
      'createDmGroup POST /api/v1/dm/groups',
      'getDmGroup GET /api/v1/dm/groups/{groupId}',
      'updateDmGroup PATCH /api/v1/dm/groups/{groupId}',
      'addDmGroupMembers POST /api/v1/dm/groups/{groupId}/members',
      'removeDmGroupMember DELETE /api/v1/dm/groups/{groupId}/members/{username}',
      'setDmGroupMemberRole PUT /api/v1/dm/groups/{groupId}/members/{username}/role',
      'leaveDmGroup POST /api/v1/dm/groups/{groupId}/leave',
      'listDmGroupMessages GET /api/v1/dm/groups/{groupId}/messages',
      'sendDmGroupMessage POST /api/v1/dm/groups/{groupId}/messages',
      'markDmGroupRead POST /api/v1/dm/groups/{groupId}/read',
      'deleteDmGroupMessage DELETE /api/v1/dm/groups/{groupId}/messages/{messageId}',
      'muteDmGroup PUT /api/v1/dm/groups/{groupId}/mute',
      'unmuteDmGroup DELETE /api/v1/dm/groups/{groupId}/mute',
      'archiveDmGroup PUT /api/v1/dm/groups/{groupId}/archive',
      'unarchiveDmGroup DELETE /api/v1/dm/groups/{groupId}/archive',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D339 archived chats and group messages', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const storage = new MemoryObjectStorage();
  const push = new FakePushSender();
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
  const friends = async (a: TestUser, b: TestUser) => {
    await follow(a, b);
    await follow(b, a);
  };
  const block = async (by: TestUser, u: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/block`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  const dm = async (by: TestUser, to: TestUser, text = 'hello') => {
    const res = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(by))
      .send({ to: to.username, kind: 'TEXT', text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { message: { id: string; conversationId: string } };
  };
  const chats = async (u: TestUser, query = '') => {
    const res = await ctx.http.get(`/api/v1/dm/chats${query}`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listDmChats');
    return res.body as { data: Chat[]; page: { hasMore: boolean; nextCursor: string | null } };
  };
  const inbox = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/dm/conversations').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listDmConversations');
    return res.body.data as { id: string; archived: boolean }[];
  };
  const unread = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/dm/unread').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getDmUnread');
    return res.body as { messages: number; conversations: number; requests: number; groups: number };
  };
  const createGroup = (by: TestUser, members: (TestUser | string)[], extra: Record<string, unknown> = {}) =>
    ctx.http
      .post('/api/v1/dm/groups')
      .set(auth(by))
      .send({
        name: 'Study group',
        members: members.map((m) => (typeof m === 'string' ? m : m.username)),
        clientId: randomUUID(),
        ...extra,
      });
  const group = async (by: TestUser, members: TestUser[], extra: Record<string, unknown> = {}) => {
    const res = await createGroup(by, members, extra);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createDmGroup');
    return res.body as GroupDetail;
  };
  const detail = async (u: TestUser, groupId: string) => {
    const res = await ctx.http.get(`/api/v1/dm/groups/${groupId}`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getDmGroup');
    return res.body as GroupDetail;
  };
  const say = async (by: TestUser, groupId: string, text = 'hi all') => {
    const res = await ctx.http
      .post(`/api/v1/dm/groups/${groupId}/messages`)
      .set(auth(by))
      .send({ kind: 'TEXT', text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendDmGroupMessage');
    return res.body as { message: { id: string; readCount: number }; group: { unreadCount: number } };
  };
  const messages = async (u: TestUser, groupId: string) => {
    const res = await ctx.http.get(`/api/v1/dm/groups/${groupId}/messages`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listDmGroupMessages');
    return res.body as {
      data: {
        id: string;
        text: string | null;
        mine: boolean;
        readCount: number;
        sender: { username: string };
      }[];
      group: { unreadCount: number };
    };
  };
  const upload = async (u: TestUser, kind: string) => {
    const bytes = await sharp({
      create: { width: 400, height: 300, channels: 3, background: { r: 20, g: 130, b: 40 } },
    })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg')).toBe(true);
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    return done.body as { id: string; width: number; height: number };
  };
  const registerPush = async (u: TestUser) => {
    const token = `fcm_${randomUUID().replaceAll('-', '')}`;
    const res = await ctx.http
      .put('/api/v1/me/push-token')
      .set(auth(u))
      .send({ token, platform: 'ANDROID', appVersion: '0.1.0' });
    expect(res.status).toBe(204);
    return token;
  };
  const clearThrottles = async () => {
    const redis = ctx.app.get<Redis>(REDIS);
    const prefix = ctx.config.redis.keyPrefix;
    const keys = await redis.keys(`${prefix}push:*`);
    if (keys.length > 0) await redis.unlink(...keys.map((k) => k.slice(prefix.length)));
  };

  beforeAll(async () => {
    ctx = await createTestApp({ ...MEDIA_ON, PUSH_MESSAGES_GAP_SECONDS: '0', DM_GROUP_MAX_MEMBERS: '4' }, [
      { token: Clock, value: clock },
      { token: OBJECT_STORAGE, value: storage },
      { token: PUSH_SENDER, value: push },
    ]);
    await withMigrationClient(async (c) => {
      await c.searchBlockedWord.deleteMany({ where: { word: 'grpbadword' } });
      await c.searchBlockedWord.create({ data: { word: 'grpbadword' } });
    });
  });
  afterAll(async () => ctx?.close());

  // ---- Archive «المؤرشفة» (§10.132) -----------------------------------------------------------------------------

  describe('archived chats', () => {
    it('archives for the caller only; a message from the peer brings it back, the caller’s own does not', async () => {
      const [me, peer] = [await signup(), await signup()];
      await friends(me, peer);
      const { message } = await dm(peer, me, 'first');
      const id = message.conversationId;
      expect((await unread(me)).messages).toBe(1);

      const put = await ctx.http.put(`/api/v1/dm/conversations/${id}/archive`).set(auth(me));
      expect(put.status, JSON.stringify(put.body)).toBe(204);
      expectContract(put, 'archiveDmConversation');
      // Idempotent.
      expect((await ctx.http.put(`/api/v1/dm/conversations/${id}/archive`).set(auth(me))).status).toBe(204);

      // Gone from the chats and the inbox, in «المؤرشفة», not in the badge; the peer sees nothing.
      expect((await chats(me)).data.map((c) => c.id)).not.toContain(id);
      expect((await inbox(me)).map((c) => c.id)).not.toContain(id);
      const archived = await chats(me, '?box=ARCHIVED');
      expect(archived.data).toEqual([
        expect.objectContaining({
          type: 'DIRECT',
          id,
          conversation: expect.objectContaining({ archived: true }),
        }),
      ]);
      expect(await unread(me)).toEqual({ messages: 0, conversations: 0, requests: 0, groups: 0 });
      expect((await chats(peer)).data).toEqual([
        expect.objectContaining({ id, conversation: expect.objectContaining({ archived: false }) }),
      ]);

      // My own message keeps it archived …
      await dm(me, peer, 'from the archive');
      expect((await chats(me, '?box=ARCHIVED')).data.map((c) => c.id)).toEqual([id]);
      // … one from the peer brings it back.
      await dm(peer, me, 'are you there?');
      expect((await chats(me, '?box=ARCHIVED')).data).toEqual([]);
      expect((await inbox(me)).find((c) => c.id === id)?.archived).toBe(false);
      // Both of the peer's messages are unread again in the badge.
      expect((await unread(me)).messages).toBe(2);

      // Unarchive explicitly.
      await ctx.http.put(`/api/v1/dm/conversations/${id}/archive`).set(auth(me));
      const del = await ctx.http.delete(`/api/v1/dm/conversations/${id}/archive`).set(auth(me));
      expect(del.status).toBe(204);
      expectContract(del, 'unarchiveDmConversation');
      expect((await chats(me)).data.map((c) => c.id)).toContain(id);
    });

    it('refuses to archive a request waiting for the caller and someone else’s conversation', async () => {
      const [me, stranger, other] = [await signup(), await signup(), await signup()];
      const { message } = await dm(stranger, me, 'hi from a stranger');
      const res = await ctx.http
        .put(`/api/v1/dm/conversations/${message.conversationId}/archive`)
        .set(auth(me));
      expect(res.status).toBe(409);
      expectContract(res, 'archiveDmConversation');
      expect(res.body.error.code).toBe('DM_NOT_ARCHIVABLE');
      // The sender may archive the request they sent (it is in their chats).
      expect(
        (await ctx.http.put(`/api/v1/dm/conversations/${message.conversationId}/archive`).set(auth(stranger)))
          .status,
      ).toBe(204);
      // Not one's own conversation → 404.
      const notMine = await ctx.http
        .put(`/api/v1/dm/conversations/${message.conversationId}/archive`)
        .set(auth(other));
      expect(notMine.status).toBe(404);
      expect((await ctx.http.put('/api/v1/dm/conversations/nope/archive').set(auth(me))).status).toBe(404);
    });
  });

  // ---- Groups: who may be added, the cap, the lifecycle (§10.133) ----------------------------------------------------

  describe('group lifecycle', () => {
    it('adds only mutual follows who accept messages, never oneself, within the cap', async () => {
      const me = await signup();
      const [ok, oneWay, nobody, blocked, blocker] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      await friends(me, ok);
      await follow(me, oneWay); // they do not follow back
      await friends(me, nobody);
      const privacy = await ctx.http
        .patch('/api/v1/me/privacy')
        .set(auth(nobody))
        .send({ whoCanMessage: 'NOBODY' });
      expect(privacy.status, JSON.stringify(privacy.body)).toBe(200);
      await friends(me, blocked);
      await block(me, blocked);
      await friends(me, blocker);
      await block(blocker, me);

      const candidates = await ctx.http.get('/api/v1/dm/group-candidates').set(auth(me));
      expect(candidates.status).toBe(200);
      expectContract(candidates, 'listDmGroupCandidates');
      expect((candidates.body.data as { username: string }[]).map((u) => u.username)).toEqual([ok.username]);

      const refused = await createGroup(me, [ok, oneWay, nobody]);
      expect(refused.status).toBe(403);
      expectContract(refused, 'createDmGroup');
      expect(refused.body.error.code).toBe('DM_GROUP_MEMBER_NOT_ALLOWED');
      expect(refused.body.error.details).toEqual([
        { field: 'members.1', issue: 'not_allowed' },
        { field: 'members.2', issue: 'not_allowed' },
      ]);
      // A block either way is refused the same way (never told), and an unknown username too.
      expect((await createGroup(me, [ok, blocked])).body.error.details).toEqual([
        { field: 'members.1', issue: 'not_allowed' },
      ]);
      expect((await createGroup(me, [blocker])).status).toBe(403);
      expect((await createGroup(me, ['nobody_has_this_name'])).status).toBe(403);
      // Oneself → 400; duplicates → 400; nothing was created.
      const self = await createGroup(me, [ok, me]);
      expect(self.status).toBe(400);
      expect(self.body.error.details).toContainEqual(expect.objectContaining({ field: 'members.1' }));
      expect((await createGroup(me, [ok, ok])).status).toBe(400);
      expect((await createGroup(me, [])).status).toBe(400);
      expect((await createGroup(me, [ok], { name: '   ' })).status).toBe(400);
      expect(await ctx.prisma.dmGroup.count({ where: { createdById: me.id } })).toBe(0);

      // The cap (DM_GROUP_MAX_MEMBERS = 4 here, the creator included).
      const more = [await signup(), await signup(), await signup(), await signup()];
      for (const m of more) await friends(me, m);
      const full = await createGroup(me, more);
      expect(full.status).toBe(409);
      expect(full.body.error.code).toBe('DM_GROUP_FULL');
      const g = await group(me, more.slice(0, 3));
      expect(g.maxMembers).toBe(4);
      expect(g.group.memberCount).toBe(4);
      const add = await ctx.http
        .post(`/api/v1/dm/groups/${g.group.id}/members`)
        .set(auth(me))
        .send({ members: [more[3]!.username] });
      expect(add.status).toBe(409);
      expectContract(add, 'addDmGroupMembers');
      expect(add.body.error.code).toBe('DM_GROUP_FULL');
    });

    it('creates idempotently with a photo; admins rename, add, remove and set roles; the creator is protected', async () => {
      const [owner, a, b, c] = [
        await signup('Owner'),
        await signup('Alaa'),
        await signup('Bader'),
        await signup(),
      ];
      for (const u of [a, b, c]) await friends(owner, u);
      await friends(a, c);
      const photo = await upload(owner, 'DM_GROUP_PHOTO');
      // A centre-cropped square.
      expect(photo.width).toBe(photo.height);
      const clientId = randomUUID();
      const first = await createGroup(owner, [a, b], {
        clientId,
        photoMediaId: photo.id,
        name: '  أصدقاء  ',
      });
      expect(first.status, JSON.stringify(first.body)).toBe(201);
      const g = first.body as GroupDetail;
      expect(g.group).toEqual(
        expect.objectContaining({
          name: 'أصدقاء',
          role: 'ADMIN',
          memberCount: 3,
          archived: false,
          muted: false,
        }),
      );
      expect(g.group.photoUrl).toMatch(/^https:\/\/media\.example\.test\//);
      expect(g.members.map((m) => [m.user.username, m.role, m.creator])).toEqual([
        [owner.username, 'ADMIN', true],
        [a.username, 'MEMBER', false],
        [b.username, 'MEMBER', false],
      ]);
      const retry = await createGroup(owner, [a, b], { clientId, photoMediaId: photo.id, name: 'x' });
      expect(retry.status).toBe(200);
      expect((retry.body as GroupDetail).group.id).toBe(g.group.id);
      const id = g.group.id;

      // A member is not an admin.
      expect((await detail(a, id)).group.role).toBe('MEMBER');
      const notAdmin = await ctx.http.patch(`/api/v1/dm/groups/${id}`).set(auth(a)).send({ name: 'Mine' });
      expect(notAdmin.status).toBe(403);
      expectContract(notAdmin, 'updateDmGroup');
      expect(
        (
          await ctx.http
            .post(`/api/v1/dm/groups/${id}/members`)
            .set(auth(a))
            .send({ members: [c.username] })
        ).status,
      ).toBe(403);
      // An outsider gets 404 everywhere.
      expect((await ctx.http.get(`/api/v1/dm/groups/${id}`).set(auth(c))).status).toBe(404);

      // Rename and drop the photo (its files go).
      const renamed = await ctx.http
        .patch(`/api/v1/dm/groups/${id}`)
        .set(auth(owner))
        .send({ name: 'Weekend', photoMediaId: null });
      expect(renamed.status, JSON.stringify(renamed.body)).toBe(200);
      expectContract(renamed, 'updateDmGroup');
      expect((renamed.body as GroupDetail).group).toEqual(
        expect.objectContaining({ name: 'Weekend', photoUrl: null }),
      );
      await settle(ctx);
      expect(await ctx.prisma.mediaAsset.count({ where: { id: photo.id } })).toBe(0);
      expect((await ctx.http.patch(`/api/v1/dm/groups/${id}`).set(auth(owner)).send({})).status).toBe(400);

      // Make `a` an admin: `a` may add (their own mutual follows) and remove members — not the creator.
      const role = await ctx.http
        .put(`/api/v1/dm/groups/${id}/members/${a.username}/role`)
        .set(auth(owner))
        .send({ role: 'ADMIN' });
      expect(role.status).toBe(204);
      expectContract(role, 'setDmGroupMemberRole');
      const added = await ctx.http
        .post(`/api/v1/dm/groups/${id}/members`)
        .set(auth(a))
        .send({ members: [c.username] });
      expect(added.status, JSON.stringify(added.body)).toBe(200);
      expectContract(added, 'addDmGroupMembers');
      expect((added.body as GroupDetail).group.memberCount).toBe(4);
      expect(
        (
          await ctx.http
            .put(`/api/v1/dm/groups/${id}/members/${owner.username}/role`)
            .set(auth(a))
            .send({ role: 'MEMBER' })
        ).status,
      ).toBe(403);
      expect(
        (await ctx.http.delete(`/api/v1/dm/groups/${id}/members/${owner.username}`).set(auth(a))).status,
      ).toBe(403);
      expect(
        (await ctx.http.delete(`/api/v1/dm/groups/${id}/members/${a.username}`).set(auth(a))).status,
      ).toBe(400);
      const removed = await ctx.http.delete(`/api/v1/dm/groups/${id}/members/${b.username}`).set(auth(a));
      expect(removed.status).toBe(204);
      expectContract(removed, 'removeDmGroupMember');
      expect((await ctx.http.get(`/api/v1/dm/groups/${id}`).set(auth(b))).status).toBe(404);
      expect(
        (await ctx.http.delete(`/api/v1/dm/groups/${id}/members/${b.username}`).set(auth(a))).status,
      ).toBe(404);
    });

    it('hands the admin role on when the last admin leaves, and ends the group with its last member', async () => {
      const [owner, a, b] = [await signup(), await signup(), await signup()];
      await friends(owner, a);
      await friends(owner, b);
      const g = await group(owner, [a, b]);
      const id = g.group.id;
      await say(a, id, 'bye soon');
      const left = await ctx.http.post(`/api/v1/dm/groups/${id}/leave`).set(auth(owner));
      expect(left.status).toBe(204);
      expectContract(left, 'leaveDmGroup');
      // `a` joined first after the creator: they are the admin now.
      const after = await detail(a, id);
      expect(after.members.map((m) => [m.user.username, m.role, m.creator])).toEqual([
        [a.username, 'ADMIN', false],
        [b.username, 'MEMBER', false],
      ]);
      expect((await ctx.http.post(`/api/v1/dm/groups/${id}/leave`).set(auth(owner))).status).toBe(404);
      await ctx.http.post(`/api/v1/dm/groups/${id}/leave`).set(auth(a));
      await ctx.http.post(`/api/v1/dm/groups/${id}/leave`).set(auth(b));
      // Nobody left: the messages expire now and are swept.
      expect(await ctx.prisma.dmGroupMember.count({ where: { groupId: id } })).toBe(0);
      await ctx.app.get(DmSweeper).sweep();
      expect(await ctx.prisma.dmGroupMessage.count({ where: { groupId: id } })).toBe(0);
    });
  });

  // ---- Group messages ------------------------------------------------------------------------------------------

  describe('group messages', () => {
    it('reads, unread counts, readCount, mute, archive and its return, blocks and new members', async () => {
      const [owner, a, b, late] = [await signup(), await signup(), await signup(), await signup()];
      for (const u of [a, b, late]) await friends(owner, u);
      const id = (await group(owner, [a, b])).group.id;
      const sent = await say(owner, id, 'welcome');
      expect(sent.message.readCount).toBe(0);
      await say(a, id, 'thanks');

      // b has two unread; the badge counts groups apart.
      expect((await detail(b, id)).group.unreadCount).toBe(2);
      expect((await unread(b)).groups).toBe(2);
      const page = await messages(b, id);
      expect(page.data.map((m) => [m.text, m.sender.username, m.mine])).toEqual([
        ['thanks', a.username, false],
        ['welcome', owner.username, false],
      ]);
      const read = await ctx.http
        .post(`/api/v1/dm/groups/${id}/read`)
        .set(auth(b))
        .send({ lastMessageId: page.data[0]!.id });
      expect(read.status).toBe(204);
      expectContract(read, 'markDmGroupRead');
      expect((await unread(b)).groups).toBe(0);
      // The owner's message was read by a (who wrote after it) and b.
      const mine = (await messages(owner, id)).data.find((m) => m.text === 'welcome')!;
      expect(mine.readCount).toBe(2);
      expect(
        (
          await ctx.http
            .post(`/api/v1/dm/groups/${id}/read`)
            .set(auth(b))
            .send({ lastMessageId: randomUUID() })
        ).status,
      ).toBe(400);

      // Mute: not in the badge; archive: leaves the chats until someone else writes.
      expect((await ctx.http.put(`/api/v1/dm/groups/${id}/mute`).set(auth(b))).status).toBe(204);
      clock.advance(1);
      await say(owner, id, 'muted for b');
      expect((await unread(b)).groups).toBe(0);
      expect((await detail(b, id)).group).toEqual(expect.objectContaining({ muted: true, unreadCount: 1 }));
      expect((await ctx.http.delete(`/api/v1/dm/groups/${id}/mute`).set(auth(b))).status).toBe(204);
      expect((await unread(b)).groups).toBe(1);
      const arch = await ctx.http.put(`/api/v1/dm/groups/${id}/archive`).set(auth(b));
      expect(arch.status).toBe(204);
      expectContract(arch, 'archiveDmGroup');
      expect((await unread(b)).groups).toBe(0);
      expect((await chats(b)).data.map((c) => c.id)).not.toContain(id);
      expect((await chats(b, '?box=ARCHIVED')).data.map((c) => c.id)).toEqual([id]);
      await say(b, id, 'still archived');
      expect((await chats(b, '?box=ARCHIVED')).data.map((c) => c.id)).toEqual([id]);
      await say(a, id, 'back you come');
      expect((await chats(b, '?box=ARCHIVED')).data).toEqual([]);
      expect((await detail(b, id)).group.archived).toBe(false);

      // A block hides the two people's messages from each other (not from the others).
      await block(b, a);
      expect((await messages(b, id)).data.map((m) => m.text)).not.toContain('thanks');
      expect((await messages(a, id)).data.map((m) => m.text)).not.toContain('still archived');
      expect((await messages(owner, id)).data.map((m) => m.text)).toContain('thanks');
      expect((await detail(b, id)).members.map((m) => m.user.username)).not.toContain(a.username);

      // A new member reads from the time they joined (the fake clock moves on, as time does).
      clock.advance(1);
      await ctx.http
        .post(`/api/v1/dm/groups/${id}/members`)
        .set(auth(owner))
        .send({ members: [late.username] });
      expect((await messages(late, id)).data).toEqual([]);
      expect((await detail(late, id)).group.unreadCount).toBe(0);
      clock.advance(1);
      await say(owner, id, 'hello late');
      expect((await messages(late, id)).data.map((m) => m.text)).toEqual(['hello late']);
    });

    it('sends pictures; refuses bad emojis, gifts and reused assets; masks blocked words; idempotent', async () => {
      const [owner, a] = [await signup(), await signup()];
      await friends(owner, a);
      const id = (await group(owner, [a])).group.id;
      const pic = await upload(owner, 'DM_IMAGE');
      const img = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(owner))
        .send({ kind: 'IMAGE', mediaId: pic.id, clientId: randomUUID() });
      expect(img.status, JSON.stringify(img.body)).toBe(201);
      // The same asset cannot be sent twice.
      const again = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(owner))
        .send({ kind: 'IMAGE', mediaId: pic.id, clientId: randomUUID() });
      expect(again.status).toBe(400);
      const emoji = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(owner))
        .send({ kind: 'EMOJI', token: ':nope_1:', clientId: randomUUID() });
      expect(emoji.status).toBe(400);
      const gift = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(owner))
        .send({ kind: 'GIFT', clientId: randomUUID() });
      expect(gift.status).toBe(400);
      const clientId = randomUUID();
      const first = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(a))
        .send({ kind: 'TEXT', text: 'once', clientId });
      expect(first.status).toBe(201);
      const retry = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(a))
        .send({ kind: 'TEXT', text: 'once', clientId });
      expect(retry.status).toBe(200);
      expectContract(retry, 'sendDmGroupMessage');
      expect(retry.body.message.id).toBe(first.body.message.id);
      // Blocked words of the server's list are masked (seeded before the first send: the list is cached).
      const masked = await say(a, id, 'a grpbadword here');
      expect((await messages(owner, id)).data.find((m) => m.id === masked.message.id)?.text).toBe(
        'a ********** here',
      );
      // An outsider → 404.
      const outsider = await signup();
      const res = await ctx.http
        .post(`/api/v1/dm/groups/${id}/messages`)
        .set(auth(outsider))
        .send({ kind: 'TEXT', text: 'let me in', clientId: randomUUID() });
      expect(res.status).toBe(404);
    });

    it('deletes: one’s own within the hour, any message by an admin; and the 24-hour sweeper', async () => {
      const [owner, a, b] = [await signup(), await signup(), await signup()];
      await friends(owner, a);
      await friends(owner, b);
      const id = (await group(owner, [a, b])).group.id;
      const fromA = await say(a, id, 'from a');
      const fromB = await say(b, id, 'from b');
      const del = (u: TestUser, messageId: string, scope = 'everyone') =>
        ctx.http.delete(`/api/v1/dm/groups/${id}/messages/${messageId}?scope=${scope}`).set(auth(u));
      expect((await del(a, fromB.message.id)).status).toBe(403);
      expect((await del(a, fromA.message.id, 'me')).status).toBe(400);
      const own = await del(a, fromA.message.id);
      expect(own.status).toBe(204);
      expectContract(own, 'deleteDmGroupMessage');
      expect((await messages(owner, id)).data.map((m) => m.text)).toEqual(['from b']);
      clock.advance(3601);
      const late = await say(a, id, 'late');
      clock.advance(3601);
      const passed = await del(a, late.message.id);
      expect(passed.status).toBe(409);
      expect(passed.body.error.code).toBe('DM_DELETE_WINDOW_PASSED');
      expect((await del(owner, late.message.id)).status).toBe(204);
      // 24 hours later the rest is swept (with its file, rows gone).
      clock.advance(24 * 3600);
      await ctx.app.get(DmSweeper).sweep();
      expect(await ctx.prisma.dmGroupMessage.count({ where: { groupId: id } })).toBe(0);
      expect((await detail(owner, id)).group.lastMessage).toBeNull();
    });

    it('pushes new messages to the other members (not muted, not the sender) and tells people they were added', async () => {
      const [owner, a, b] = [await signup('Owner'), await signup('Alaa'), await signup('Bader')];
      await friends(owner, a);
      await friends(owner, b);
      const [tOwner, tA, tB] = [await registerPush(owner), await registerPush(a), await registerPush(b)];
      await clearThrottles();
      const id = (await group(owner, [a, b], { name: 'Trip' })).group.id;
      await settle(ctx);
      expect(push.to(tA).map((m) => [m.title, m.body])).toEqual([['Trip', 'Owner added you to the group']]);
      expect(push.to(tOwner)).toHaveLength(0);
      await ctx.http.put(`/api/v1/dm/groups/${id}/mute`).set(auth(b));
      await clearThrottles();
      await say(owner, id, 'leaving at 8');
      await settle(ctx);
      const got = push.to(tA).at(-1)!;
      expect([got.title, got.body, got.data.kind, got.data.groupId]).toEqual([
        'Trip',
        'Owner: leaving at 8',
        'dm_group',
        id,
      ]);
      expect(push.to(tB)).toHaveLength(1); // only the "added" one: muted since
      expect(push.to(tOwner)).toHaveLength(0);
    });
  });

  // ---- The merged list ---------------------------------------------------------------------------------------------

  describe('listDmChats', () => {
    it('lists conversations and groups by recency, searches both, pages with one cursor', async () => {
      const me = await signup();
      const [sara, omar, lina] = [await signup('Sara'), await signup('Omar'), await signup('Lina')];
      for (const u of [sara, omar, lina]) await friends(me, u);
      await dm(sara, me, 'one');
      clock.advance(1);
      const g = await group(me, [omar, lina], { name: 'Family' });
      clock.advance(1);
      await dm(omar, me, 'two');
      clock.advance(1);
      await say(lina, g.group.id, 'three');
      const all = await chats(me);
      expect(
        all.data.map((c) => [c.type, c.type === 'GROUP' ? c.group?.name : c.conversation?.peer.username]),
      ).toEqual([
        ['GROUP', 'Family'],
        ['DIRECT', omar.username],
        ['DIRECT', sara.username],
      ]);
      expect(all.data[0]!.group?.unreadCount).toBe(1);
      expect((await chats(me, '?q=fam')).data.map((c) => c.id)).toEqual([g.group.id]);
      expect((await chats(me, '?q=sar')).data.map((c) => c.type)).toEqual(['DIRECT']);
      const first = await chats(me, '?limit=2');
      expect(first.data).toHaveLength(2);
      const second = await chats(me, `?limit=2&cursor=${encodeURIComponent(first.page.nextCursor ?? '')}`);
      expect(second.data.map((c) => c.conversation?.peer.username)).toEqual([sara.username]);
      expect(second.page.nextCursor).toBeNull();
      const wrong = await ctx.http
        .get(`/api/v1/dm/chats?box=ARCHIVED&cursor=${encodeURIComponent(first.page.nextCursor ?? '')}`)
        .set(auth(me));
      expect(wrong.status).toBe(400);
      expectContract(wrong, 'listDmChats');
    });
  });

  // ---- Reports -----------------------------------------------------------------------------------------------------

  describe('reports', () => {
    it('a member reports the group (a snapshot); REMOVE_TARGET removes it for everyone', async () => {
      const [owner, a] = [await signup(), await signup()];
      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      await friends(owner, a);
      const id = (await group(owner, [a], { name: 'Spam room' })).group.id;
      await say(owner, id, 'buy followers here');
      const outsider = await ctx.http
        .post('/api/v1/reports')
        .set(auth(mod))
        .send({ targetType: 'DM_GROUP', targetId: id, reason: 'SPAM' });
      expect(outsider.status).toBe(404);
      const rep = await ctx.http
        .post('/api/v1/reports')
        .set(auth(a))
        .send({ targetType: 'DM_GROUP', targetId: id, reason: 'SPAM' });
      expect(rep.status, JSON.stringify(rep.body)).toBe(201);
      expectContract(rep, 'createReport');
      const again = await ctx.http
        .post('/api/v1/reports')
        .set(auth(a))
        .send({ targetType: 'DM_GROUP', targetId: id, reason: 'SPAM' });
      expect(again.status).toBe(200);
      const queue = await ctx.http.get('/api/v1/admin/reports?limit=50').set(auth(mod));
      expect(queue.status).toBe(200);
      expectContract(queue, 'listAdminReports');
      const ours = (queue.body.data as { id: string; dmGroupSnapshot?: Record<string, unknown> }[]).find(
        (r) => r.id === rep.body.id,
      );
      expect(ours?.dmGroupSnapshot).toEqual(
        expect.objectContaining({
          name: 'Spam room',
          memberCount: 2,
          members: [owner.username, a.username],
          purged: false,
          thread: expect.objectContaining({
            messages: [expect.objectContaining({ text: 'buy followers here', sender: owner.username })],
          }),
        }),
      );
      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(act.status, JSON.stringify(act.body)).toBe(200);
      expectContract(act, 'actOnReport');
      for (const u of [owner, a]) {
        expect((await ctx.http.get(`/api/v1/dm/groups/${id}`).set(auth(u))).status).toBe(404);
        expect((await chats(u)).data.map((c) => c.id)).not.toContain(id);
      }
      await ctx.app.get(DmSweeper).sweep();
      expect(await ctx.prisma.dmGroupMessage.count({ where: { groupId: id } })).toBe(0);
    });
  });
});

describe('D339 the new-group limit (owner: 2 a day)', { timeout: 120_000 }, () => {
  let ctx: TestContext;

  beforeAll(async () => {
    // The production default (src/config/env.schema.ts; app-config.spec asserts it) — the shared test config is
    // generous for every bucket.
    ctx = await createTestApp({ RATE_LIMIT_DM_GROUP_CREATE_USER: '2/86400' });
  });
  afterAll(async () => ctx?.close());

  it('refuses the 3rd group of the day with 429; refused attempts count; another user is not affected', async () => {
    const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
    const signup = async () => {
      const { res } = await registerVerified(ctx);
      expect(res.status).toBe(201);
      return {
        username: res.body.user.username as string,
        token: res.body.tokens.accessToken as string,
      };
    };
    const [me, a, other] = [await signup(), await signup(), await signup()];
    for (const [x, y] of [
      [me, a],
      [a, me],
      [other, a],
      [a, other],
    ] as const) {
      const res = await ctx.http.put(`/api/v1/users/${y.username}/follow`).set(auth(x));
      expect(res.status).toBeLessThan(300);
    }
    const create = (u: { token: string }, members: string[]) =>
      ctx.http
        .post('/api/v1/dm/groups')
        .set(auth(u))
        .send({ name: 'Limit', members, clientId: randomUUID() });

    // A refused attempt (oneself as a member, 400) uses one of the two.
    expect((await create(me, [me.username])).status).toBe(400);
    expect((await create(me, [a.username])).status).toBe(201);
    const third = await create(me, [a.username]);
    expect(third.status).toBe(429);
    expectContract(third, 'createDmGroup');
    expect(third.body.error.code).toBe('RATE_LIMITED');
    expect(await ctx.prisma.dmGroup.count({ where: { name: 'Limit', members: { some: {} } } })).toBe(1);

    // Two for someone else, then the third refused for them too.
    expect((await create(other, [a.username])).status).toBe(201);
    expect((await create(other, [a.username])).status).toBe(201);
    expect((await create(other, [a.username])).status).toBe(429);
  });
});
