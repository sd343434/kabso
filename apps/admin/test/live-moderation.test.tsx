/**
 * D250 «مراقبة البث»: the card previews (capped at 6 by the pool), the reported tab and the sidebar's red dot, the
 * action dialogs (a reason always; the scope and duration of a ban; the authenticator code of a device ban), what each
 * dialog sends, the actions per capability, the reports panel and the watch view's tile order. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D250, EN_D250 } from '../src/i18n-d250';
import { PREVIEW_MAX, PreviewPool, type WatchTrack } from '../src/live-media';
import { NAV } from '../src/nav';
import { liveActions, moderateRequest, ModerateDialog, type ModForm } from '../src/pages/LiveModeration';
import { LiveCard, ReportedTab, type LiveRow } from '../src/pages/Lives';
import { orderTiles, ReportsPanel, type LiveReport } from '../src/pages/LiveWatch';
import { navDots } from '../src/ui/Shell';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, can: (c: Capability) => boolean = () => true): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can,
  toast: () => undefined,
});
const roleCan = (role: PanelRole) => (c: Capability) => (CAPABILITY_ROLES[c] ?? []).includes(role);
const html = (lang: Lang, node: React.ReactNode, can?: (c: Capability) => boolean) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, can)}>{node}</AppContext.Provider>);

const live: LiveRow = {
  id: '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
  title: 'سهرة',
  mode: 'SOLO',
  viewers: 42,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: { id: 'h1', username: 'coin0001', displayName: 'jgjg', avatarUrl: null },
  pk: null,
  openReports: 0,
};

describe('D250 strings', () => {
  it('has every string in both languages', () => {
    expect(Object.keys(EN_D250).sort()).toEqual(Object.keys(AR_D250).sort());
    for (const k of Object.keys(AR_D250) as (keyof typeof AR_D250)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D250[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D250[k]);
    }
  });
});

describe('D250 previews are capped', () => {
  it('six cards on screen play; the seventh waits; play takes the oldest slot; leaving frees one', () => {
    const pool = new PreviewPool();
    expect(pool.max).toBe(PREVIEW_MAX);
    expect(PREVIEW_MAX).toBe(6);
    for (let i = 1; i <= 6; i += 1) expect(pool.request(`r${i}`)).toBe(true);
    expect(pool.request('r7')).toBe(false);
    expect(pool.playing()).toHaveLength(6);
    expect(pool.request('r7', true)).toBe(true);
    expect(pool.has('r1')).toBe(false);
    expect(pool.playing()).toHaveLength(6);
    pool.release('r2');
    expect(pool.request('r8')).toBe(true);
    expect(pool.playing()).toHaveLength(6);
    // A card already playing keeps its slot.
    expect(pool.request('r8')).toBe(true);
    expect(pool.playing()).toHaveLength(6);
  });

  it('a card with a slot shows the muted preview video; without one the cover and a play button', () => {
    const pool = new PreviewPool();
    pool.request(live.id);
    const playing = html('ar', <LiveCard live={live} pool={pool} onOpen={() => undefined} />);
    expect(playing).toMatch(/<video[^>]*class="live-preview-video"[^>]*>/);
    expect(playing).toContain('muted=""');
    expect(playing).toContain('data-preview="loading"');
    expect(playing).not.toContain('play-btn');
    const idle = html('ar', <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} />);
    expect(idle).not.toContain('<video');
    expect(idle).toContain('play-btn');
    expect(idle).toContain('aria-label="تشغيل المعاينة"');
    expect(html('en', <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} />)).toContain(
      'aria-label="Play preview"',
    );
  });

  it('without lives.watch (FINANCE): no preview and no play button — the cover only', () => {
    const pool = new PreviewPool();
    pool.request(live.id);
    const out = html('ar', <LiveCard live={live} pool={pool} onOpen={() => undefined} />, roleCan('FINANCE'));
    expect(out).not.toContain('<video');
    expect(out).not.toContain('play-btn');
  });

  it('D250b: SUPPORT watches (the preview plays) and sees the reports badge, but no action anywhere', () => {
    const pool = new PreviewPool();
    pool.request(live.id);
    const support = roleCan('SUPPORT');
    expect(support('lives.watch')).toBe(true);
    expect(support('lives.reports')).toBe(true);
    expect(support('lives.moderate')).toBe(false);
    expect(support('devices.ban')).toBe(false);
    const out = html(
      'ar',
      <LiveCard live={{ ...live, openReports: 2 }} pool={pool} onOpen={() => undefined} onAction={() => undefined} />,
      support,
    );
    expect(out).toMatch(/<video[^>]*class="live-preview-video"/);
    expect(out).toContain('data-open-reports="2"');
    expect(out).not.toContain('data-action=');
    // The watch view's and the card menu's actions come from liveActions: none for SUPPORT, on air or not.
    expect(liveActions(support as never, true, 2)).toEqual([]);
    expect(liveActions(support as never, false, 2)).toEqual([]);
  });
});

describe('D250 reported lives and red dots', () => {
  it('a reported card: the red badge with its count and the outline', () => {
    const out = html('ar', <LiveCard live={{ ...live, openReports: 3 }} pool={new PreviewPool()} onOpen={() => undefined} />);
    expect(out).toContain('data-reported="true"');
    expect(out).toContain('data-open-reports="3"');
    expect(out).toContain('red-dot');
    expect(out).toContain('3 بلاغ');
    expect(html('ar', <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} />)).not.toContain('red-dot');
  });

  it('the «لايفات مبلّغ عنها» chip: a red dot and the count only while reported lives are on air', () => {
    const on = html('ar', <ReportedTab rooms={2} pressed={false} onClick={() => undefined} />);
    expect(on).toContain('لايفات مبلّغ عنها');
    expect(on).toContain('red-dot');
    expect(on).toContain('count-pill');
    expect(on).toContain('>2<');
    const off = html('en', <ReportedTab rooms={0} pressed onClick={() => undefined} />);
    expect(off).toContain('Reported lives');
    expect(off).not.toContain('red-dot');
    expect(off).toContain('aria-pressed="true"');
  });

  it('the sidebar: «البث الآن» gets a dot while reported lives are on air; «الأجهزة المحظورة» is for devices.ban', () => {
    expect(navDots({ rooms: 2 })['/lives']).toBe(2);
    expect(navDots(null)['/lives']).toBe(0);
    const items = NAV.flatMap((g) => g.items);
    expect(items.find((i) => i.to === '/device-bans')?.cap).toBe('devices.ban');
    expect(items.find((i) => i.to === '/lives')?.match).toContain('liveWatch');
  });
});

describe('D250 action dialogs', () => {
  const form = (patch: Partial<ModForm>): ModForm => ({
    action: 'END',
    scope: 'NO_LIVE',
    duration: '24h',
    until: '',
    reason: 'سبب',
    totpCode: '',
    ...patch,
  });
  const id = live.id;

  it('sends exactly what the contract asks; nothing without a reason or the code', () => {
    expect(moderateRequest(id, form({ action: 'END' }))).toEqual({
      path: `/admin/lives/${id}/moderate`,
      body: { action: 'END', reason: 'سبب' },
    });
    expect(moderateRequest(id, form({ action: 'END', reason: '   ' }))).toBeNull();
    expect(moderateRequest(id, form({ action: 'BAN', scope: 'NO_LIVE', duration: '1h' }))!.body).toEqual({
      action: 'NO_LIVE',
      reason: 'سبب',
      hours: 1,
    });
    for (const [d, h] of [
      ['24h', 24],
      ['3d', 72],
      ['7d', 168],
      ['30d', 720],
    ] as const) {
      expect(moderateRequest(id, form({ action: 'BAN', scope: 'SUSPEND', duration: d }))!.body).toMatchObject({
        action: 'SUSPEND',
        hours: h,
      });
    }
    const until = new Date(Date.now() + 5 * 86_400_000);
    const local = new Date(until.getTime() - until.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);
    expect(moderateRequest(id, form({ action: 'BAN', duration: 'custom', until: local }))!.body.until).toMatch(/Z$/);
    expect(moderateRequest(id, form({ action: 'BAN', duration: 'custom', until: '' }))).toBeNull();
    expect(moderateRequest(id, form({ action: 'BAN', duration: 'custom', until: '2020-01-01T10:00' }))).toBeNull();
    expect(moderateRequest(id, form({ action: 'BAN', duration: 'permanent' }))).toBeNull();
    expect(moderateRequest(id, form({ action: 'DEVICE_BAN', duration: 'permanent' }))).toBeNull();
    expect(moderateRequest(id, form({ action: 'DEVICE_BAN', duration: 'permanent', totpCode: '123456' }))!.body).toEqual({
      action: 'DEVICE_BAN',
      reason: 'سبب',
      permanent: true,
      totpCode: '123456',
    });
    expect(moderateRequest(id, form({ action: 'DEVICE_BAN', duration: '7d', totpCode: '123456' }))!.body).toMatchObject({
      hours: 168,
    });
    expect(moderateRequest(id, form({ action: 'DISMISS' }))).toEqual({
      path: `/admin/lives/${id}/reports/dismiss`,
      body: { reason: 'سبب' },
    });
  });

  it('every dialog has the required reason box; a ban its scope and durations; a device ban the code and the limits', () => {
    const end = html('ar', <ModerateDialog roomId={id} host="@coin0001" action="END" onClose={() => undefined} onDone={() => undefined} />);
    expect(end).toContain('إغلاق البث — \u2066@coin0001\u2069');
    expect(end).toMatch(/<textarea[^>]*id="mod-reason"[^>]*required=""/);
    expect(end).toContain('السبب (يصل للمضيف)');
    expect(end).not.toContain('mod-code');
    // The confirm button stays off until a reason is typed.
    expect(end).toMatch(/<button type="submit" class="btn danger" disabled="">/);

    const ban = html('ar', <ModerateDialog roomId={id} host="@coin0001" action="BAN" onClose={() => undefined} onDone={() => undefined} />);
    expect(ban).toContain('منع من البث');
    expect(ban).toContain('تعليق الحساب');
    for (const d of ['1h', '24h', '3d', '7d', '30d', 'custom']) expect(ban).toContain(`data-duration="${d}"`);
    expect(ban).not.toContain('data-duration="permanent"');
    expect(ban).toMatch(/aria-pressed="true" data-duration="24h"/);

    const device = html(
      'en',
      <ModerateDialog roomId={id} host="@coin0001" action="DEVICE_BAN" onClose={() => undefined} onDone={() => undefined} />,
    );
    expect(device).toContain('Ban device — \u2066@coin0001\u2069');
    expect(device).toContain('id="mod-code"');
    expect(device).toContain('data-honest-limits');
    expect(device).toContain('factory reset');
    expect(device).toContain('data-duration="permanent"');

    const filled = html(
      'ar',
      <ModerateDialog
        roomId={id}
        host="@coin0001"
        action="DISMISS"
        initial={{ reason: 'لا مخالفة' }}
        onClose={() => undefined}
        onDone={() => undefined}
      />,
    );
    expect(filled).toContain('تمت المراجعة — لا مخالفة');
    expect(filled).toContain('ملاحظة المراجعة');
    expect(filled).toMatch(/<button type="submit" class="btn primary">/);
  });

  it('the actions follow the capabilities (OWNER, MODERATION: all; SUPPORT — watches only, D250b — and FINANCE: none)', () => {
    for (const role of ['OWNER', 'MODERATION'] as const) {
      expect(liveActions(roleCan(role) as never, true, 2)).toEqual(['END', 'BAN', 'DEVICE_BAN', 'DISMISS']);
      expect(liveActions(roleCan(role) as never, true, 0)).toEqual(['END', 'BAN', 'DEVICE_BAN']);
      expect(liveActions(roleCan(role) as never, false, 1)).toEqual(['DISMISS']);
    }
    for (const role of ['SUPPORT', 'FINANCE'] as const) expect(liveActions(roleCan(role) as never, true, 2)).toEqual([]);
    expect(CAPABILITY_ROLES['lives.watch']).toEqual(['OWNER', 'MODERATION', 'SUPPORT']);
    expect(CAPABILITY_ROLES['lives.moderate']).toEqual(['OWNER', 'MODERATION']);
  });
});

describe('D250 watch view parts', () => {
  it('the reports panel: the open count with a red dot, the reporter, the note and the chat before', () => {
    const reports: LiveReport[] = [
      {
        id: 'r1',
        targetType: 'LIVE_ROOM',
        reason: 'HARASSMENT',
        note: 'يشتم المشاهدين',
        status: 'OPEN',
        createdAt: new Date().toISOString(),
        resolvedAt: null,
        resolutionNote: null,
        reporter: { id: 'u2', username: 'viewer7', displayName: 'V', avatarUrl: null },
        chatBefore: [
          {
            id: 'c1',
            kind: 'TEXT',
            text: 'كلام سيء',
            createdAt: new Date().toISOString(),
            deleted: false,
            authorRole: 'HOST',
            author: { id: 'h1', username: 'coin0001', displayName: 'jgjg', avatarUrl: null },
          },
        ],
      },
      {
        id: 'r2',
        targetType: 'USER',
        reason: 'NUDITY',
        note: null,
        status: 'DISMISSED',
        createdAt: new Date().toISOString(),
        resolvedAt: new Date().toISOString(),
        resolutionNote: 'لا مخالفة',
        reporter: null,
        chatBefore: [],
      },
    ];
    const out = html('ar', <ReportsPanel reports={reports} open={1} />);
    expect(out).toContain('data-open-reports="1"');
    expect(out).toContain('red-dot');
    expect(out).toContain('@viewer7');
    expect(out).toContain('«يشتم المشاهدين»');
    expect(out).toContain('كلام سيء');
    expect(out).toContain('تحرش أو إساءة');
    expect(out).toContain('بلاغ على المضيف أثناء البث');
    expect(out).toContain('↳ لا مخالفة');
    expect(html('en', <ReportsPanel reports={[]} open={0} />)).toContain('No reports on this live.');
  });

  it('tiles: the host first, a screen share before the same person’s camera, audio never a tile', () => {
    const tr = (participant: string, kind: 'video' | 'audio', source: string, key: string) =>
      ({ key, room: 'main', participant, name: participant, kind, source, track: {} }) as unknown as WatchTrack;
    const list = orderTiles(
      [
        tr('guest', 'video', 'camera', 'a'),
        tr('h1', 'audio', 'microphone', 'b'),
        tr('h1', 'video', 'camera', 'c'),
        tr('h1', 'video', 'screen_share', 'd'),
      ],
      'h1',
    );
    expect(list.map((x) => x.key)).toEqual(['d', 'c', 'a']);
  });
});
