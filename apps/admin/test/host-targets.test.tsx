/**
 * D277 (owner): the host's «هدف الهدايا» and «هدف هدايا الحظ» are in cherries — the tasks page names each target's unit
 * («كرز» for cherries, «عملة» for a coin value, nothing for counts) next to every band's number.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { TasksTable, type TaskDto } from '../src/pages/Programs';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const task = (over: Partial<TaskDto>): TaskDto => ({
  code: 'P_HOST_GIFTS',
  period: 'DAILY',
  metric: 'HOST_GIFT_CHERRIES',
  audience: 'HOSTS',
  nameAr: 'هدف الهدايا (بالكرز)',
  nameEn: 'Gifts target (cherries)',
  enabled: true,
  pool: true,
  poolGroup: 'HOST',
  target: 6_500_000,
  targetUnit: 'CHERRIES',
  targetUsd: '$7.15',
  rewardCherries: 60_000,
  rewardUsd: '$0.066',
  bands: [650_000, 1_625_000, 3_250_000, 6_500_000].map((target) => ({
    target,
    targetUsd: '$0.72',
    rewardCherries: 10_000,
    rewardUsd: '$0.011',
  })),
  ...over,
});

const render = (lang: Lang, rows: TaskDto[]) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <TasksTable rows={rows} />
    </AppContext.Provider>,
  );

const count = (html: string, text: string) => html.split(text).length - 1;

describe('D277 host targets in cherries on the tasks page', () => {
  it('Arabic: «كرز» after each band target of the gifts and lucky targets', () => {
    const html = render('ar', [
      task({}),
      task({
        code: 'HOST_LUCKY_COINS',
        metric: 'HOST_LUCKY_CHERRIES',
        nameAr: 'هدف هدايا الحظ (بالكرز)',
        pool: false,
        poolGroup: null,
      }),
    ]);
    expect(html).toContain('هدف الهدايا (بالكرز)');
    expect(html).toContain('هدف هدايا الحظ (بالكرز)');
    expect(count(html, '> كرز</span>')).toBe(8);
    expect(html).not.toContain('عملة');
  });

  it('English: «coins» for a coin value, nothing for a count or an older API without the unit', () => {
    const html = render('en', [
      task({ code: 'SEND_GIFTS', metric: 'GIFT_COINS_SENT', targetUnit: 'COINS', bands: [] }),
      task({ code: 'FOLLOW_USERS', metric: 'FOLLOWS', targetUnit: null, targetUsd: null, bands: [] }),
      task({ code: 'OLD', metric: 'HOST_GIFT_COINS', targetUnit: undefined, bands: [] }),
    ]);
    expect(count(html, '> coins</span>')).toBe(1);
    expect(html).not.toContain('cherries</span>');
  });

  it('every key has both languages', () => {
    for (const key of ['tasksUnitCherries', 'tasksUnitCoins', 'tasksUnitNote'] as const) {
      expect(translate('ar', key)).not.toBe(translate('en', key));
    }
  });
});
