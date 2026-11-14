/**
 * D213 «البث الآن»: the streamer gets its mode chip (between «بث متعدد» and PK, like the app's order) and a card tag
 * «ستريمر»; the other modes carry no tag (the live badge only).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { LIVE_MODES, LiveModeTabs, LiveModeTag } from '../src/pages/Lives';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const inLang = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

describe('D213 streamer in «البث الآن»', () => {
  it('the chips list STREAMER after MULTI, PK last', () => {
    expect(LIVE_MODES).toEqual(['', 'SOLO', 'AUDIO', 'PODCAST', 'MULTI', 'STREAMER', 'PK']);
  });

  it('Arabic: the «ستريمر» chip, pressed when chosen', () => {
    const html = inLang('ar', <LiveModeTabs mode="STREAMER" onMode={() => undefined} />);
    expect(html).toContain('ستريمر');
    expect(html).toMatch(/aria-pressed="true"[^>]*>ستريمر</);
    expect(html).toMatch(/aria-pressed="false"[^>]*>بث متعدد</);
  });

  it('English chip label', () => {
    expect(inLang('en', <LiveModeTabs mode="" onMode={() => undefined} />)).toContain('>Streamer<');
  });

  it('the card tag: streamers only', () => {
    expect(inLang('ar', <LiveModeTag mode="STREAMER" />)).toBe('<span class="live-mode-tag">ستريمر</span>');
    expect(inLang('en', <LiveModeTag mode="STREAMER" />)).toContain('Streamer');
    for (const mode of ['SOLO', 'PK', 'MULTI', 'AUDIO', 'PODCAST']) {
      expect(inLang('ar', <LiveModeTag mode={mode} />)).toBe('');
    }
  });

  it('the key has both languages', () => {
    expect(translate('ar', 'liveModeSTREAMER')).not.toBe(translate('en', 'liveModeSTREAMER'));
  });
});
