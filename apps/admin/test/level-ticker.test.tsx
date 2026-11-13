/**
 * D254 «شريط ترقية المستويات»: the OWNER's threshold of the level-up banner shown in every live, on «إعدادات الموقع» —
 * the current level shown, a whole number 1–100 only (the button off otherwise), and the PUT body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { levelTickerBody, LevelTickerView } from '../src/pages/SiteSettings';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, minLevel: string) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <LevelTickerView
        minLevel={minLevel}
        reason=""
        busy={false}
        onMinLevel={() => undefined}
        onReason={() => undefined}
        onSave={() => undefined}
      />
    </AppContext.Provider>,
  );

describe('D254 level-up banner threshold', () => {
  it('Arabic: the title, the current level and the hint; the button on', () => {
    const html = render('ar', '30');
    expect(html).toContain('شريط ترقية المستويات');
    expect(html).toContain('value="30"');
    expect(html).toContain('min="1"');
    expect(html).toContain('max="100"');
    expect(html).toContain(translate('ar', 'lvHint'));
    expect(html).not.toContain(translate('ar', 'lvInvalid'));
    expect(html).not.toMatch(/<button[^>]*disabled/);
  });

  it('English: a level out of 1–100 is refused before sending (the button off)', () => {
    for (const bad of ['0', '101', '30.5', '', 'abc', '-3']) {
      const html = render('en', bad);
      expect(html, bad).toContain('Enter a whole number from 1 to 100.');
      expect(html, bad).toMatch(/<button[^>]*disabled/);
    }
  });

  it('the body: an integer 1–100, a reason only when typed', () => {
    expect(levelTickerBody('30', '  ')).toEqual({ minLevel: 30 });
    expect(levelTickerBody(' 45 ', ' fewer ')).toEqual({ minLevel: 45, reason: 'fewer' });
    expect(levelTickerBody('1', '')).toEqual({ minLevel: 1 });
    expect(levelTickerBody('100', '')).toEqual({ minLevel: 100 });
    for (const bad of ['0', '101', '30.5', '', 'x', '1e1', '-1']) expect(levelTickerBody(bad, ''), bad).toBeNull();
  });

  it('every key has both languages', () => {
    for (const key of ['lvTitle', 'lvIntro', 'lvMinLevel', 'lvHint', 'lvInvalid', 'lvSave'] as const) {
      expect(translate('ar', key)).not.toBe(translate('en', key));
    }
  });
});
