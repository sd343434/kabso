/**
 * D228 «محرك مؤثرات الكاميرا»: the OWNER's switch of the app's camera effects engine on «إعدادات الموقع» — both
 * engines offered with what each does, the current one checked, the free engine's honest beta note, and the PUT body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { cameraFxBody, CameraFxView } from '../src/pages/SiteSettings';
import type { CameraFxEngine } from '../src/types';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, engine: CameraFxEngine) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <CameraFxView engine={engine} reason="" busy={false} onEngine={() => undefined} onReason={() => undefined} onSave={() => undefined} />
    </AppContext.Provider>,
  );

describe('D228 camera effects engine', () => {
  it('Arabic: both engines, DeepAR checked by default, no beta note', () => {
    const html = render('ar', 'DEEPAR');
    expect(html).toContain('محرك مؤثرات الكاميرا');
    expect(html).toContain(translate('ar', 'fxDeepar'));
    expect(html).toContain(translate('ar', 'fxFree'));
    expect(html).toMatch(/checked="" value="DEEPAR"/);
    expect(html).not.toMatch(/checked="" value="FREE"/);
    expect(html).not.toContain(translate('ar', 'fxFreeNote'));
  });

  it('English, FREE: checked and the honest beta note shown', () => {
    const html = render('en', 'FREE');
    expect(html).toMatch(/checked="" value="FREE"/);
    expect(html).toContain('not been tested on a real phone');
  });

  it('the body: the engine, a reason only when typed', () => {
    expect(cameraFxBody('FREE', '  ')).toEqual({ cameraFxEngine: 'FREE' });
    expect(cameraFxBody('DEEPAR', ' back ')).toEqual({ cameraFxEngine: 'DEEPAR', reason: 'back' });
  });

  it('every key has both languages', () => {
    for (const key of ['fxTitle', 'fxIntro', 'fxDeepar', 'fxFree', 'fxFreeNote', 'fxSave'] as const) {
      expect(translate('ar', key)).not.toBe(translate('en', key));
    }
  });
});
