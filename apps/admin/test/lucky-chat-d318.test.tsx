/**
 * D318 «مكاسب الحظ في التكست»: the lucky chat threshold in «شريطا الهدايا والألعاب» — a choice among the lucky
 * multipliers (shown only with an API that sends them), sent in the PUT body; anything else refused.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { globalStripsBody, GlobalStripsView } from '../src/pages/SiteSettings';

const MULTIPLIERS = [5, 10, 25, 50, 100, 250, 500, 1000];

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, lucky?: string) =>
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
        {...(lucky !== undefined
          ? { luckyChat: { value: lucky, multipliers: MULTIPLIERS, onChange: () => undefined } }
          : {})}
      />
    </AppContext.Provider>,
  );

describe('D318 lucky chat threshold', () => {
  it('Arabic and English: the field, every multiplier as a choice, the hint; the button on', () => {
    for (const lang of ['ar', 'en'] as const) {
      const html = render(lang, '250');
      expect(html).toContain(translate(lang, 'gsLuckyChat'));
      expect(html).toContain(translate(lang, 'gsLuckyChatHint').replaceAll("'", '&#x27;'));
      for (const m of MULTIPLIERS) expect(html).toContain(`<option value="${m}"`);
      expect(html).toMatch(/<option value="250" selected=""/);
      expect(html).not.toMatch(/<button[^>]*disabled/);
    }
  });

  it('an older API (no multipliers): no field, the D305 form as it was', () => {
    const html = render('en');
    expect(html).not.toContain(translate('en', 'gsLuckyChat'));
  });

  it('the PUT body carries it only when chosen among the multipliers', () => {
    expect(globalStripsBody('500000', '1000000', '', { value: '500', multipliers: MULTIPLIERS })).toEqual({
      giftMinCoins: 500_000,
      gameMinTickets: 1_000_000,
      luckyChatMinMultiplier: 500,
    });
    expect(globalStripsBody('500000', '1000000', '')).toEqual({ giftMinCoins: 500_000, gameMinTickets: 1_000_000 });
    for (const bad of ['300', '0', '', '2.5', 'x']) {
      expect(globalStripsBody('500000', '1000000', '', { value: bad, multipliers: MULTIPLIERS }), bad).toBeNull();
    }
    const html = render('en', '300');
    expect(html).toContain(translate('en', 'gsLuckyChatInvalid'));
    expect(html).toMatch(/<button[^>]*disabled/);
  });
});
