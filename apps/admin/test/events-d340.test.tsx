/**
 * D340 (CONVENTIONS §10.134) in the panel: «إعلان بملء الشاشة عند البدء» in the design step — on by default for a new event,
 * sent with every save, read back from the server (an older server without the field reads as on), editable while the
 * event runs, in Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { emptyGiftEvent, formFromServer, giftEventBody, type EventOptions, type GiftEventFormState } from '../src/gift-events';
import { translate, type Lang } from '../src/i18n';
import { EventEditor, newDraft } from '../src/pages/Events';
import type { AdminGiftEvent } from '../src/pages/GiftEventForm';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const OPTIONS: EventOptions = {
  timeZone: 'UTC',
  boardKinds: ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'],
  gifts: [{ code: 'rose', nameAr: 'وردة', nameEn: 'Rose', priceCoins: 100, enabled: true }],
  bagItems: [],
  vipTiers: [],
  giftCategories: [],
};

const event = (over: Partial<GiftEventFormState> = {}): GiftEventFormState => ({
  ...newDraft('UTC'),
  titleAr: 'فعالية',
  titleEn: 'Event',
  gifts: [{ giftCode: 'rose', pointsPerCoin: '1', pointsPerGift: '0' }],
  boards: [{ kind: 'SENDERS', minPoints: '0', prizes: [] }],
  reason: 'd340 panel',
  ...over,
});

const server = (f: GiftEventFormState, over: Partial<AdminGiftEvent> = {}): AdminGiftEvent =>
  ({
    id: 'e1',
    state: 'RUNNING',
    payoutHold: false,
    structureLocked: true,
    creatorsAsHosts: true,
    form: { ...giftEventBody(f), bannerUrl: null },
    results: [],
    ...over,
  }) as unknown as AdminGiftEvent;

const design = (lang: Lang, f: GiftEventFormState, s: AdminGiftEvent | null = null) =>
  html(
    lang,
    <EventEditor
      eventId="e1"
      options={OPTIONS}
      initial={f}
      server={s}
      step="evStepDesign"
      onClose={() => undefined}
      onDone={() => undefined}
    />,
  );

/** The `<input id="ev-announce" …>` tag of the rendered step. */
const toggle = (markup: string) => {
  const at = markup.indexOf('id="ev-announce"');
  expect(at).toBeGreaterThan(-1);
  return markup.slice(markup.lastIndexOf('<input', at), markup.indexOf('/>', at) + 2);
};

describe('D340 «إعلان بملء الشاشة عند البدء»', () => {
  it('is on by default and always sent', () => {
    expect(emptyGiftEvent('UTC').announceFullscreen).toBe(true);
    expect(newDraft('UTC').announceFullscreen).toBe(true);
    expect(giftEventBody(event()).announceFullscreen).toBe(true);
    expect(giftEventBody(event({ announceFullscreen: false })).announceFullscreen).toBe(false);
  });

  it('round-trips with the server; an older server without the field reads as on', () => {
    const off = giftEventBody(event({ announceFullscreen: false }));
    expect(formFromServer({ ...off, bannerUrl: null }, 'UTC').announceFullscreen).toBe(false);
    const { announceFullscreen: _a, ...older } = off;
    expect(formFromServer({ ...older, bannerUrl: null }, 'UTC').announceFullscreen).toBe(true);
  });

  it('is in the design step, in Arabic and English, checked by default and unchecked when off', () => {
    const ar = design('ar', event());
    expect(ar).toContain('إعلان بملء الشاشة عند البدء');
    expect(ar).toContain('إعلان الفائزين «مبروك» يظهر دائماً');
    expect(toggle(ar)).toContain('checked=""');
    const en = design('en', event({ announceFullscreen: false }));
    expect(en).toContain('Full-screen announcement at the start');
    expect(toggle(en)).not.toContain('checked');
  });

  it('stays editable while the event runs', () => {
    const f = event({ status: 'PUBLISHED' });
    const markup = design('ar', f, server(f));
    expect(toggle(markup)).not.toContain('disabled');
    // Not inside a disabled fieldset.
    const before = markup.slice(0, markup.indexOf('id="ev-announce"'));
    const opened = (before.match(/<fieldset[^>]*disabled/g) ?? []).length;
    const closed = (before.match(/<\/fieldset>/g) ?? []).length;
    expect(opened).toBeLessThanOrEqual(closed);
  });
});
