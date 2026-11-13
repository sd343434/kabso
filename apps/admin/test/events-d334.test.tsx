/**
 * D334 (events v2 follow-ups, CONVENTIONS §10.127.11) in the panel: «عدد المعروضين» per board (1–100, 20 by default; sent
 * only when set, kept on a round trip, editable while the event runs), the banner for every audience, «المضيفون» including
 * content creators (an older event marked), and the festival template's placeholder names, in Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import {
  BOARD_SHOWN_DEFAULT,
  BOARD_SHOWN_MAX,
  formFromServer,
  giftEventBody,
  giftEventProblems,
  type EventOptions,
  type GiftEventFormState,
} from '../src/gift-events';
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
  gifts: [
    {
      code: 'rose',
      nameAr: 'وردة',
      nameEn: 'Rose',
      priceCoins: 100,
      enabled: true,
    },
  ],
  bagItems: [],
  vipTiers: [],
  giftCategories: [],
};

function event(over: Partial<GiftEventFormState> = {}): GiftEventFormState {
  return {
    ...newDraft('UTC'),
    titleAr: 'فعالية',
    titleEn: 'Event',
    gifts: [{ giftCode: 'rose', pointsPerCoin: '1', pointsPerGift: '0' }],
    boards: [
      { kind: 'SENDERS', minPoints: '0', shown: '50', prizes: [] },
      { kind: 'RECEIVERS', minPoints: '0', prizes: [] },
    ],
    reason: 'd334 panel',
    ...over,
  };
}

const server = (f: GiftEventFormState, over: Partial<AdminGiftEvent> = {}): AdminGiftEvent =>
  ({
    id: 'e1',
    state: 'RUNNING',
    payoutHold: false,
    structureLocked: false,
    creatorsAsHosts: true,
    form: { ...giftEventBody(f), bannerUrl: null },
    results: [],
    ...over,
  }) as unknown as AdminGiftEvent;

const editor = (
  lang: Lang,
  step: Parameters<typeof EventEditor>[0]['step'],
  f: GiftEventFormState,
  s: AdminGiftEvent | null = null,
) =>
  html(
    lang,
    <EventEditor
      eventId="e1"
      options={OPTIONS}
      initial={f}
      server={s}
      step={step}
      onClose={() => undefined}
      onDone={() => undefined}
    />,
  );

describe('D334 «عدد المعروضين»', () => {
  it('is sent only when set (the server keeps or defaults it) and read back', () => {
    const body = giftEventBody(event());
    expect(body.boards.map((b) => (b as { shown?: number }).shown)).toEqual([50, undefined]);
    const back = formFromServer(
      {
        ...body,
        bannerUrl: null,
        boards: body.boards.map((b, i) => ({ ...b, shown: i === 0 ? 50 : 20 })),
      },
      'UTC',
    );
    expect(back.boards.map((b) => b.shown)).toEqual(['50', '20']);
    expect([BOARD_SHOWN_DEFAULT, BOARD_SHOWN_MAX]).toEqual([20, 100]);
  });

  it('is 1–100', () => {
    const bad = (shown: string) =>
      giftEventProblems(
        event({
          boards: [{ kind: 'SENDERS', minPoints: '0', shown, prizes: [] }],
        }),
      );
    expect(bad('0')).toContain('evBadShown');
    expect(bad('101')).toContain('evBadShown');
    expect(bad('2.5')).toContain('evBadShown');
    expect(bad('100')).not.toContain('evBadShown');
    expect(bad('1')).not.toContain('evBadShown');
    expect(bad('')).not.toContain('evBadShown'); // empty: the default
  });

  it('each board has the field (20 when unset), in Arabic and English', () => {
    const a = editor('ar', 'evStepBoards', event());
    expect(a).toContain('عدد المعروضين');
    expect(a).toContain('value="50"');
    expect(a).toContain('value="20"');
    expect(a).toContain('max="100"');
    expect(editor('en', 'evStepBoards', event())).toContain('Places shown');
  });

  it('stays editable once the event runs (the boards themselves are locked)', () => {
    const f = event();
    const a = editor('ar', 'evStepBoards', f, server(f, { structureLocked: true }));
    const running = a.slice(a.indexOf('data-testid="ev-shown-running"'));
    expect(a).toContain('data-testid="ev-shown-running"');
    // The running block is not inside a disabled fieldset; the locked boards block is.
    expect(running.slice(0, running.indexOf('</fieldset>'))).not.toContain('disabled');
    expect(a).toMatch(/<fieldset class="span-2" disabled="">/);
    expect(editor('ar', 'evStepBoards', f, server(f))).not.toContain('ev-shown-running');
  });
});

describe('D334 audience and banner', () => {
  it('«المضيفون» includes content creators; the banner is for every audience', () => {
    const a = editor('ar', 'evStepAudience', event({ audience: 'HOSTS' }));
    expect(a).toContain('المضيفون (يشمل صناع المحتوى)');
    expect(a).toContain('صناع المحتوى يُعدّون مضيفين، والمضيفون ليسوا صناع محتوى');
    expect(editor('en', 'evStepAudience', event())).toContain('Hosts (content creators included)');
    const d = editor('ar', 'evStepDesign', event({ audience: 'CP' }));
    expect(d).toContain('لجمهور الفعالية فقط (أي جمهور)');
    expect(d).not.toContain('فعاليات «الجميع»');
    expect(editor('en', 'evStepDesign', event({ audience: 'CREATORS' }))).toContain('any audience');
  });

  it('an older HOSTS event (D295) says its hosts leave creators out', () => {
    const f = event({ audience: 'HOSTS' });
    expect(editor('ar', 'evStepAudience', f, server(f, { creatorsAsHosts: false }))).toContain(
      'فعالية قديمة: «المضيفون» فيها بدون صناع المحتوى',
    );
    expect(editor('ar', 'evStepAudience', f, server(f))).not.toContain('فعالية قديمة');
  });

  it('the festival template is described with placeholder names and the full-screen gifts', () => {
    expect(translate('ar', 'evFestivalHint')).toContain('«هدية المهرجان 1…4»');
    expect(translate('ar', 'evFestivalHint')).toContain('«شاشة كاملة»');
    expect(translate('en', 'evFestivalHint')).toContain('“Festival gift 1…4”');
    expect(translate('ar', 'evFestivalHint')).not.toContain('شعلة');
  });
});
