/**
 * D347 «شريط المردود في كل اللايفات» (owner «نعم موافق»): the global lucky banner's multipliers and gap in
 * «شريطا الهدايا والألعاب» — a tick per lucky multiplier and the gap in seconds (shown only with an API that sends
 * them), sent in the PUT body; validated like the server (≥ 1 multiplier among the lucky ones, a gap 1–600).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { globalStripsBody, GlobalStripsView, luckyGlobalProblem } from '../src/pages/SiteSettings';

const MULTIPLIERS = [5, 10, 25, 50, 100, 250, 500, 1000];

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, global?: { chosen: number[]; gap: string }) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <GlobalStripsView
        giftMinCoins="500000"
        gameMinTickets="1000000"
        reason=""
        busy={false}
        onGiftMinCoins={() => undefined}
        onGameMinTickets={() => undefined}
        onReason={() => undefined}
        onSave={() => undefined}
        luckyChat={{
          value: '250',
          multipliers: MULTIPLIERS,
          onChange: () => undefined,
        }}
        {...(global
          ? {
              luckyGlobal: {
                multipliers: MULTIPLIERS,
                ...global,
                onToggle: () => undefined,
                onGap: () => undefined,
              },
            }
          : {})}
      />
    </AppContext.Provider>,
  );

describe('D347 the global lucky banner settings', () => {
  it('Arabic and English: a tick per multiplier (the defaults ticked), the gap, the hints; the button on', () => {
    for (const lang of ['ar', 'en'] as const) {
      const html = render(lang, { chosen: [250, 500, 1000], gap: '10' });
      expect(html).toContain(translate(lang, 'gsLuckyGlobal'));
      expect(html).toContain(translate(lang, 'gsLuckyGlobalGap'));
      for (const m of MULTIPLIERS) expect(html).toContain(`id="gs-lucky-global-${m}"`);
      expect(html).toMatch(/id="gs-lucky-global-500" type="checkbox" checked=""/);
      expect(html).not.toMatch(/id="gs-lucky-global-100" type="checkbox" checked=""/);
      expect(html).toContain('value="10"');
      expect(html).not.toMatch(/<button[^>]*disabled/);
    }
  });

  it('an older API (no global fields): no ticks, no gap', () => {
    const html = render('en');
    expect(html).not.toContain(translate('en', 'gsLuckyGlobal'));
    expect(html).not.toContain('gs-lucky-gap');
  });

  it('the PUT body carries the set (sorted, distinct) and the gap; nothing ticked or a bad gap refuses', () => {
    expect(
      globalStripsBody('500000', '1000000', '', undefined, {
        multipliers: MULTIPLIERS,
        chosen: [1000, 100, 1000],
        gap: '30',
      }),
    ).toEqual({
      giftMinCoins: 500_000,
      gameMinTickets: 1_000_000,
      luckyGlobalMultipliers: [100, 1000],
      luckyGlobalGapSeconds: 30,
    });
    expect(luckyGlobalProblem({ multipliers: MULTIPLIERS, chosen: [], gap: '10' })).toBe('multipliers');
    expect(
      luckyGlobalProblem({
        multipliers: MULTIPLIERS,
        chosen: [300],
        gap: '10',
      }),
    ).toBe('multipliers');
    for (const gap of ['0', '601', '2.5', '', 'x']) {
      expect(luckyGlobalProblem({ multipliers: MULTIPLIERS, chosen: [250], gap }), gap).toBe('gap');
      expect(
        globalStripsBody('500000', '1000000', '', undefined, {
          multipliers: MULTIPLIERS,
          chosen: [250],
          gap,
        }),
      ).toBeNull();
    }
    const html = render('en', { chosen: [], gap: '10' });
    expect(html).toContain(translate('en', 'gsLuckyGlobalInvalid'));
    expect(html).toMatch(/<button[^>]*disabled/);
    expect(render('ar', { chosen: [250], gap: '0' })).toContain(translate('ar', 'gsLuckyGlobalGapInvalid'));
  });
});
