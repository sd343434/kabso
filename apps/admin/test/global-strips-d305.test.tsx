/**
 * D305 «شريطا الهدايا والألعاب»: the OWNER's thresholds of the global strips on «إعدادات الموقع» — the current values
 * shown, positive whole numbers only (the button off otherwise), and the PUT body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { globalStripsBody, GlobalStripsView } from '../src/pages/SiteSettings';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, gift: string, game: string) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <GlobalStripsView
        giftMinCoins={gift}
        gameMinTickets={game}
        reason=""
        busy={false}
        onGiftMinCoins={() => undefined}
        onGameMinTickets={() => undefined}
        onReason={() => undefined}
        onSave={() => undefined}
      />
    </AppContext.Provider>,
  );

describe('D305 global strips thresholds', () => {
  it('Arabic: the title, both values and the hint; the button on', () => {
    const html = render('ar', '500000', '1000000');
    expect(html).toContain('شريطا الهدايا والألعاب');
    expect(html).toContain('value="500000"');
    expect(html).toContain('value="1000000"');
    expect(html).toContain(translate('ar', 'gsHint'));
    expect(html).not.toContain(translate('ar', 'gsInvalid'));
    expect(html).not.toMatch(/<button[^>]*disabled/);
  });

  it('English: a value that is not a positive whole number is refused before sending (the button off)', () => {
    for (const [gift, game] of [
      ['0', '1000000'],
      ['500000', ''],
      ['50.5', '1'],
      ['abc', '1'],
      ['-3', '1'],
      ['1000000001', '1'],
    ]) {
      const html = render('en', gift!, game!);
      expect(html, `${gift} ${game}`).toContain('Enter a positive whole number in both fields.');
      expect(html, `${gift} ${game}`).toMatch(/<button[^>]*disabled/);
    }
  });

  it('the body: both whole numbers, a reason only when typed', () => {
    expect(globalStripsBody('500000', '1000000', '  ')).toEqual({ giftMinCoins: 500000, gameMinTickets: 1000000 });
    expect(globalStripsBody(' 20000 ', '300', ' launch ')).toEqual({
      giftMinCoins: 20000,
      gameMinTickets: 300,
      reason: 'launch',
    });
    expect(globalStripsBody('1', '1000000000000', '')).toEqual({ giftMinCoins: 1, gameMinTickets: 1_000_000_000_000 });
    for (const [a, b] of [
      ['0', '1'],
      ['1', '0'],
      ['1e5', '1'],
      ['', '1'],
      ['1', '1000000000001'],
    ]) {
      expect(globalStripsBody(a!, b!, ''), `${a} ${b}`).toBeNull();
    }
  });

  it('every key has both languages', () => {
    for (const key of ['gsTitle', 'gsIntro', 'gsGiftMinCoins', 'gsGameMinTickets', 'gsHint', 'gsInvalid', 'gsSave'] as const) {
      expect(translate('ar', key)).not.toBe(translate('en', key));
    }
  });
});
