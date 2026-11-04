/**
 * D229 (v1.50-live, CONVENTIONS §10.80): the panel «أحكام PK» — capabilities (D274: OWNER only; SUPPORT,
 * MODERATION and FINANCE nothing), the library table (filters, search, CSV), add with the safety and duplicate checks, edit /
 * disable, import (JSON lines and CSV, dry run, idempotent by code, refused lines), the reported queue and its clear,
 * and the PK points settings — every write audited with the reason.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { panel, type Admin } from './helpers/admin-panel.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

describe('D229 the panel «أحكام PK»', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const P = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  const tag = Date.now()
    .toString(36)
    .replace(/[0-9]/g, (d) => 'qwertyuiop'[Number(d)]!);
  /** The same unique word in Arabic letters (the Arabic text may not hold Latin letters or long numbers). */
  const arTag = [...tag].map((c) => 'ابتثجحخدذرزسشصضطظعغفقكلمنه'[c.charCodeAt(0) % 26]).join('');

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: P.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
    });
    owner = await P.makeAdmin(['OWNER']);
    moderator = await P.makeAdmin(['MODERATION']);
    support = await P.makeAdmin(['SUPPORT']);
    finance = await P.makeAdmin(['FINANCE']);
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('capabilities (D274): OWNER only — SUPPORT, MODERATION and FINANCE can neither read nor write', async () => {
    const list = await P.send(owner, 'get', '/admin/pk-dares?pageSize=5');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listAdminPkDares');
    expect((await P.send(owner, 'get', '/admin/pk-dare-settings')).status).toBe(200);
    for (const who of [support, moderator, finance]) {
      expect((await P.send(who, 'get', '/admin/pk-dares')).status).toBe(403);
      expect((await P.send(who, 'get', '/admin/pk-dare-settings')).status).toBe(403);
      const denied = await P.send(who, 'post', '/admin/pk-dares', {
        textAr: 'تقليد بطريق أثناء عد النجوم بصوت هامس',
        textEn: 'Imitate a penguin counting the stars, in a whisper',
        category: 'IMITATION',
        level: 'EASY',
        reason: 'test',
      });
      expect(denied.status).toBe(403);
      expect(
        (await P.send(who, 'put', '/admin/pk-dare-settings', { winPoints: 4, reason: 'x' })).status,
      ).toBe(403);
    }
  });

  it('add: the safety rules and the duplicate check refuse (400), a good one is added and audited', async () => {
    const unsafe = await P.send(owner, 'post', '/admin/pk-dares', {
      textAr: 'القفز من النافذة',
      textEn: 'Jump out of the window',
      category: 'FUNNY',
      level: 'HARD',
      reason: 'test',
    });
    expect(unsafe.status).toBe(400);
    expect(JSON.stringify(unsafe.body)).toContain('danger');
    const text = {
      textAr: `تقليد ديناصور ${arTag} أثناء تعلم الطبخ بصوت هامس`,
      textEn: `Imitate a dinosaur ${tag} learning to cook, in a whisper`,
    };
    const made = await P.send(owner, 'post', '/admin/pk-dares', {
      ...text,
      category: 'IMITATION',
      level: 'EASY',
      reason: 'new',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'createAdminPkDare');
    expect(made.body).toMatchObject({ createdBy: 'ADMIN', active: true, reportCount: 0 });
    const dup = await P.send(owner, 'post', '/admin/pk-dares', {
      ...text,
      category: 'IMITATION',
      level: 'EASY',
      reason: 'again',
    });
    expect(dup.status).toBe(400);
    expect(JSON.stringify(dup.body)).toMatch(/duplicate/);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'pk_dare.create', targetId: made.body.id } }),
    ).toBe(1);

    // Edit, disable, search, filter.
    const off = await P.send(owner, 'patch', `/admin/pk-dares/${made.body.id as string}`, {
      active: false,
      reason: 'off',
    });
    expect(off.status).toBe(200);
    expectContract(off, 'updateAdminPkDare');
    expect(off.body).toMatchObject({ active: false, disabledReason: 'ADMIN' });
    const found = await P.send(owner, 'get', `/admin/pk-dares?q=${tag}&active=false`);
    expect(found.body.data.map((d: { id: string }) => d.id)).toEqual([made.body.id]);
    const csv = await P.send(owner, 'get', `/admin/pk-dares?q=${tag}&format=csv`);
    expect(csv.status).toBe(200);
    expect(csv.text).toContain(tag);
    const badEdit = await P.send(owner, 'patch', `/admin/pk-dares/${made.body.id as string}`, {
      textEn: 'Buy something with money',
      reason: 'x',
    });
    expect(badEdit.status).toBe(400);
  });

  it('import: JSON lines and CSV, dry run, idempotent by code, refused lines listed', async () => {
    const lines = [
      {
        code: `t-${tag}-1`,
        category: 'QUIZ',
        level: 'MEDIUM',
        textAr: `ذكر 7 ألوان ${arTag} خلال 30 ثانية بصوت هامس`,
        textEn: `Name 7 colours ${tag} in 30 seconds, in a whisper`,
      },
      {
        code: `t-${tag}-2`,
        category: 'FUNNY',
        level: 'EASY',
        textAr: 'أكل ملعقة ملح',
        textEn: 'Eat a spoon of salt',
      },
      { code: 'BAD CODE', category: 'FUNNY', level: 'EASY', textAr: 'تصفيق', textEn: 'Clap' },
    ];
    const content = lines.map((l) => JSON.stringify(l)).join('\n');
    const dry = await P.send(owner, 'post', '/admin/pk-dares/import', {
      format: 'json',
      content,
      dryRun: true,
      reason: 'try',
    });
    expect(dry.status, JSON.stringify(dry.body)).toBe(200);
    expectContract(dry, 'importAdminPkDares');
    expect(dry.body).toMatchObject({ received: 3, inserted: 0, existing: 0 });
    expect(dry.body.rejected.map((r: { line: number }) => r.line)).toEqual([2, 3]);
    expect(await ctx.prisma.pkDare.count({ where: { code: `t-${tag}-1` } })).toBe(0);
    const real = await P.send(owner, 'post', '/admin/pk-dares/import', {
      format: 'json',
      content,
      reason: 'add',
    });
    expect(real.body).toMatchObject({ inserted: 1 });
    const again = await P.send(owner, 'post', '/admin/pk-dares/import', {
      format: 'json',
      content,
      reason: 'again',
    });
    expect(again.body).toMatchObject({ inserted: 0, existing: 1 });
    const csvContent = `code,category,level,textAr,textEn\nt-${tag}-3,ACTING,HARD,"تمثيل دور قرصان ${arTag} في مطار مزدحم بصوت أوبرالي","Act as a pirate ${tag} in a busy airport, in an opera voice"\n`;
    const csv = await P.send(owner, 'post', '/admin/pk-dares/import', {
      format: 'csv',
      content: csvContent,
      reason: 'csv',
    });
    expect(csv.body).toMatchObject({ received: 1, inserted: 1, rejected: [] });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'pk_dare.import' } })).toBeGreaterThanOrEqual(
      3,
    );
    expect(
      (
        await P.send(support, 'post', '/admin/pk-dares/import', {
          format: 'csv',
          content: csvContent,
          reason: 'x',
        })
      ).status,
    ).toBe(403);
  });

  it('the reported queue and «إبقاء» (clear, enable again)', async () => {
    const d = await ctx.prisma.pkDare.findFirstOrThrow({ where: { code: `t-${tag}-1` } });
    await withMigrationClient((db) =>
      db.pkDare.update({
        where: { id: d.id },
        data: { reportCount: 6, active: false, disabledReason: 'REPORTS' },
      }),
    );
    const queue = await P.send(owner, 'get', '/admin/pk-dares?reported=true&sort=reportCount');
    expect(queue.body.data[0].id).toBe(d.id);
    const cleared = await P.send(owner, 'post', `/admin/pk-dares/${d.id}/reports/clear`, {
      enable: true,
      reason: 'fine',
    });
    expect(cleared.status, JSON.stringify(cleared.body)).toBe(200);
    expectContract(cleared, 'clearAdminPkDareReports');
    expect(cleared.body).toMatchObject({ reportCount: 0, active: true, disabledReason: null });
    const stats = await P.send(owner, 'get', '/admin/pk-dares/stats');
    expect(stats.status).toBe(200);
    expectContract(stats, 'getAdminPkDareStats');
  });

  it('settings: defaults +3 / +1 / 0 / −3, 30 s, 5 reports; changed with a reason and audited', async () => {
    const get = await P.send(owner, 'get', '/admin/pk-dare-settings');
    expectContract(get, 'getAdminPkDareSettings');
    expect(get.body).toMatchObject({
      winPoints: 3,
      drawPoints: 1,
      lossPoints: 0,
      refusePoints: -3,
      forfeitPoints: -3,
      decideSeconds: 30,
      reportsToDisable: 5,
    });
    const put = await P.send(owner, 'put', '/admin/pk-dare-settings', {
      refusePoints: -5,
      reason: 'owner',
    });
    expect(put.status).toBe(200);
    expectContract(put, 'updateAdminPkDareSettings');
    expect(put.body).toMatchObject({ refusePoints: -5, winPoints: 3 });
    expect(
      (await P.send(owner, 'put', '/admin/pk-dare-settings', { refusePoints: -500, reason: 'x' })).status,
    ).toBe(400);
    const row = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'pk_dare.settings.update' },
      orderBy: { createdAt: 'desc' },
    });
    expect(row.metadata).toMatchObject({
      before: { refusePoints: -3 },
      after: { refusePoints: -5 },
      reason: 'owner',
      via: 'panel',
    });
    await P.send(owner, 'put', '/admin/pk-dare-settings', { refusePoints: -3, reason: 'back' });
    // D276: «الانسحاب» −3 by default, changed like the others (audited before / after).
    const f = await P.send(owner, 'put', '/admin/pk-dare-settings', {
      forfeitPoints: -4,
      reason: 'owner D276',
    });
    expect(f.status, JSON.stringify(f.body)).toBe(200);
    expectContract(f, 'updateAdminPkDareSettings');
    expect(f.body).toMatchObject({ forfeitPoints: -4, refusePoints: -3, lossPoints: 0 });
    expect(
      (await P.send(owner, 'put', '/admin/pk-dare-settings', { forfeitPoints: 101, reason: 'x' })).status,
    ).toBe(400);
    // The panel's clock is frozen here: pick the row by its reason, not by time.
    const audited = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'pk_dare.settings.update', metadata: { path: ['reason'], equals: 'owner D276' } },
    });
    expect(audited.metadata).toMatchObject({ before: { forfeitPoints: -3 }, after: { forfeitPoints: -4 } });
    await P.send(owner, 'put', '/admin/pk-dare-settings', { forfeitPoints: -3, reason: 'back' });
  });
});
