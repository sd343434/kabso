/**
 * D281 «الأهداف الذكية» (OWNER only): the knobs form (editable for the OWNER, read-only otherwise, only the changed knobs
 * sent, the order easy < medium < hard enforced before saving), the catalogue's size, a host's day with «لماذا هذا الهدف»,
 * the nav entry for the OWNER only, and every key in Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D281, EN_D281 } from '../src/i18n-d281';
import { NAV } from '../src/nav';
import {
  CatalogueStats,
  HostTargetDayView,
  HostTargetKnobsForm,
  bpsPercent,
  knobChanges,
  knobsValid,
} from '../src/pages/HostTargets';
import type { AdminHostTargetDay, AdminHostTargetSettings, AdminTargetCatalogue, Capability } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: 'OWNER' | 'SUPPORT' | 'FINANCE' | 'MODERATION') =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (node: React.ReactNode, lang: Lang, caps: Capability[]) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const SAVED: AdminHostTargetSettings = {
  easyPercentile: 50,
  mediumPercentile: 75,
  hardPercentile: 90,
  easyRewardBps: 150,
  mediumRewardBps: 250,
  hardRewardBps: 400,
  noRepeatDays: 7,
  taskNoRepeatDays: 3,
  historyDays: 30,
  completionShift: 10,
  engineFrom: '2027-01-14',
  updatedAt: '2027-01-13T07:00:00.000Z',
  updatedById: null,
};
const draftOf = (s: AdminHostTargetSettings) => {
  const { engineFrom: _e, updatedAt: _u, updatedById: _b, ...d } = s;
  return d;
};

describe('D281 the knobs', () => {
  it('OWNER edits: every knob, the shares as percents, the engine day; only changes are sent', () => {
    const html = render(
      <HostTargetKnobsForm saved={SAVED} draft={draftOf(SAVED)} onChange={() => undefined} onSave={() => undefined} />,
      'ar',
      capsOf('OWNER'),
    );
    for (const k of ['easyPercentile', 'hardRewardBps', 'noRepeatDays', 'taskNoRepeatDays', 'completionShift']) {
      expect(html).toContain(`data-knob="${k}"`);
    }
    expect(html).toContain('1.5٪');
    expect(html).toContain('2.5٪');
    expect(html).toContain('4٪');
    expect(html).toContain('2027-01-14');
    expect(html).toContain('data-host-target-knobs-save');
    expect(html).not.toContain('readOnly');
    expect(knobChanges(SAVED, { ...draftOf(SAVED), hardRewardBps: 500 })).toEqual({ hardRewardBps: 500 });
    expect(knobChanges(SAVED, draftOf(SAVED))).toEqual({});
    expect(bpsPercent(400, 'en')).toBe('4%');
  });

  it('the order holds before saving; others see nothing editable', () => {
    expect(knobsValid(draftOf(SAVED))).toBe(true);
    expect(knobsValid({ ...draftOf(SAVED), easyPercentile: 80 })).toBe(false);
    expect(knobsValid({ ...draftOf(SAVED), easyRewardBps: 600 })).toBe(false);
    const html = render(
      <HostTargetKnobsForm saved={SAVED} draft={draftOf(SAVED)} onChange={() => undefined} onSave={() => undefined} />,
      'en',
      capsOf('SUPPORT'),
    );
    expect(html).not.toContain('data-host-target-knobs-save');
    expect(html).toContain('readOnly');
    // The capabilities: OWNER only.
    expect(CAPABILITY_ROLES['host_targets.view']).toEqual(['OWNER']);
    expect(CAPABILITY_ROLES['host_targets.edit']).toEqual(['OWNER']);
    const items = NAV.flatMap((g) => g.items).filter((i) => i.to === '/programs/host-targets');
    expect(items.map((i) => i.cap)).toEqual(['host_targets.view']);
  });
});

describe('D281 the catalogue and a host’s day', () => {
  it('the catalogue counts targets by kind and tasks by template', () => {
    const data: AdminTargetCatalogue = {
      targets: { version: 'ab12cd34', total: 235_200, windows: 147, gifts: 19, categories: 5, byKind: { GIFT_COUNT: 111_720 } },
      tasks: { total: 115_983, templates: 23, byTemplate: { P_WATCH_LIVES: 5_880 } },
    };
    const ar = render(<CatalogueStats data={data} />, 'ar', capsOf('OWNER'));
    expect(ar).toContain('عدد هدية');
    expect(ar).toContain('ab12cd34');
    const en = render(<CatalogueStats data={data} />, 'en', capsOf('OWNER'));
    expect(en).toContain('235,200');
    expect(en).toContain('115,983');
    expect(en).toContain('P_WATCH_LIVES');
  });

  it('«لماذا هذا الهدف»: the reason of each level in the panel language; none for a day not read', () => {
    const day: AdminHostTargetDay = {
      host: { id: 'u1', username: 'host1', displayName: 'Host' },
      day: '2027-01-14',
      targets: [
        {
          level: 'EASY',
          code: 'T.GIFT_COUNT.warrior.100.0-1440',
          kind: 'GIFT_COUNT',
          subject: 'warrior',
          titleAr: 'استقبل 100 هدية من المحارب',
          titleEn: 'Receive 100 × Warrior',
          amount: 100,
          progress: 140,
          window: null,
          expectedCoins: 100_000,
          rewardBps: 150,
          rewardCherries: 7_295,
          paidCherries: 7_295,
          paidAt: '2027-01-14T20:00:00.000Z',
          profitUsd: 0.535,
          catalogueVersion: 'v',
          reason: { newHost: false, why: 'Warrior received: the 50th percentile …', whyAr: 'استلام المحارب: المئين 50 …' },
        },
        {
          level: 'HARD',
          code: 'T.GIFT_CHERRIES.*.3000000.0-1440',
          kind: 'GIFT_CHERRIES',
          subject: null,
          titleAr: 'هدف الهدايا: 3,000,000 كرزة',
          titleEn: 'Gifts target: 3,000,000 cherries',
          amount: 3_000_000,
          progress: 120_000,
          window: null,
          expectedCoins: 461_538,
          rewardBps: 400,
          rewardCherries: 89_790,
          paidCherries: null,
          paidAt: null,
          profitUsd: null,
          catalogueVersion: 'v',
          reason: { newHost: true, why: 'New host', whyAr: 'مضيف جديد' },
        },
      ],
    };
    const ar = render(<HostTargetDayView data={day} />, 'ar', capsOf('OWNER'));
    expect(ar).toContain('استقبل 100 هدية من المحارب');
    expect(ar).toContain('استلام المحارب: المئين 50');
    expect(ar).toContain('سهل');
    expect(ar).toContain('صعب');
    // Progress capped at the amount; the share as a percent; unpaid as a dash.
    expect(ar).toContain('100 / 100');
    expect(ar).toContain('4٪');
    expect(ar).toContain('—');
    const en = render(<HostTargetDayView data={day} />, 'en', capsOf('OWNER'));
    expect(en).toContain('Receive 100 × Warrior');
    expect(en).toContain('89,790');
    expect(en).toContain('New host');
    expect(render(<HostTargetDayView data={{ ...day, targets: [] }} />, 'en', capsOf('OWNER'))).toContain(
      'No targets for that day',
    );
  });

  it('every key in Arabic and English', () => {
    expect(Object.keys(EN_D281).sort()).toEqual(Object.keys(AR_D281).sort());
    for (const k of Object.keys(AR_D281) as (keyof typeof AR_D281)[]) {
      expect(AR_D281[k].length, k).toBeGreaterThan(0);
      expect(EN_D281[k].length, k).toBeGreaterThan(0);
    }
  });
});
