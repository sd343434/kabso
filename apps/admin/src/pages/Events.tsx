import { useState } from 'react';
import { api, uploadGiftFile, uploadStoreArt } from '../api';
import { EventHubBannerField } from './EventHubBanner';
import { Dialog, ErrorAlert, FormDialog, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import {
  BOARD_KINDS,
  BOARD_SHOWN_DEFAULT,
  BOARD_SHOWN_MAX,
  BOARD_MONEY,
  COUNTED_GIFTS,
  EVENT_AUDIENCES,
  RECURRENCES,
  SCORINGS,
  defaultPrizeLines,
  emptyGiftEvent,
  formFromServer,
  giftEventBody,
  giftEventProblems,
  prizeTypesV2For,
  type BoardForm,
  type BoardKind,
  type EventOptions,
  type GiftEventFormState,
  type MilestoneForm,
  type PrizeItemForm,
  type PrizeLineForm,
} from '../gift-events';
import type { Key } from '../i18n';
import { Icon } from '../ui/icons';
import { GiftEventResults, type AdminGiftEvent } from './GiftEventForm';
import { EventArtFields, EventPagePreview, MedalDialog, PrizeItemEditor } from './GiftEventParts';
import { ContrastNotice, EventDesignFields, EventLivePreview, useMeasuredColour } from './EventDesigner';
import { designProblems, designServerProblems, previewEvent } from '../event-design';

/** `AdminEventList` row (v1.101-social, D325). */
export interface EventRow {
  id: string;
  titleAr: string;
  titleEn: string;
  metric: string;
  startsAt: string | null;
  endsAt: string | null;
  permanent: boolean;
  state: 'DRAFT' | 'UPCOMING' | 'RUNNING' | 'PAID' | 'HELD' | 'IN_REVIEW' | 'ENDED';
  payoutHold: boolean;
  status?: 'DRAFT' | 'PUBLISHED';
  recurrence?: 'NONE' | 'WEEKLY' | 'MONTHLY';
  period?: number;
}

/** The steps of the editor, in order. */
export const EVENT_STEPS = [
  'evStepBasics',
  'evStepTime',
  'evStepAudience',
  'evStepGifts',
  'evStepBoards',
  'evStepMilestones',
  'evStepDesign',
  'evStepReview',
] as const;
export type EventStep = (typeof EVENT_STEPS)[number];

/** The commands a row offers (the server checks each again). */
export function rowCommands(e: EventRow): string[] {
  const gift = e.metric === 'EVENT_GIFTS';
  const out: string[] = [];
  if (e.state === 'DRAFT') return ['publish', 'discard'];
  if (gift && e.state === 'UPCOMING') out.push('unpublish');
  if (e.state === 'RUNNING') out.push('end');
  if (!e.payoutHold && ['UPCOMING', 'RUNNING', 'IN_REVIEW', 'ENDED'].includes(e.state)) out.push('hold');
  if (e.payoutHold && e.state !== 'PAID') out.push('release');
  return out;
}

const COMMAND_LABEL: Record<string, Key> = {
  publish: 'evPublish',
  unpublish: 'evUnpublish',
  discard: 'evDiscard',
  end: 'eventEnd',
  hold: 'gevHold',
  release: 'eventRelease',
};

/**
 * «الفعاليات» (v1.101-social, D325, CONVENTIONS §10.127): one events system — every event (D166 and D303 ones finish
 * under their rules), the step-by-step editor for new ones, drafts and publishing, the results and the launch festival
 * template. `events.manage` (OWNER) for every change; the list for `catalog.view`.
 */
export function Events({ initial }: { initial?: EventRow[] } = {}) {
  const { t, lang, can, toast } = useApp();
  const events = useAsync(
    () => (initial ? Promise.resolve({ data: initial }) : api.get<{ data: EventRow[] }>('/admin/events')),
    [],
  );
  const [editing, setEditing] = useState<{ id?: string } | null>(null);
  const [results, setResults] = useState<string | null>(null);
  const [festival, setFestival] = useState(false);
  const [act, setAct] = useState<{ id: string; command: string } | null>(null);
  const manage = can('events.manage');
  const title = (e: EventRow) => (lang === 'ar' ? e.titleAr : e.titleEn);
  const list = events.data ?? (initial ? { data: initial } : null);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('evTitle')}</h1>
          <p className="muted small">{t('evSubtitle')}</p>
        </div>
        {manage && (
          <div className="row">
            <button className="btn primary" onClick={() => setEditing({})}>
              <Icon name="plus" size={16} />
              {t('evNew')}
            </button>
            <button className="btn" title={t('evFestivalHint')} onClick={() => setFestival(true)}>
              <Icon name="gift" size={16} />
              {t('evFestival')}
            </button>
          </div>
        )}
      </div>
      <section className="card">
        <ErrorAlert error={events.error} />
        {list && list.data.length === 0 && <p className="muted">{t('evNone')}</p>}
        {list && list.data.length > 0 && (
          <div className="table-wrap">
            <table className="events-v2">
              <thead>
                <tr>
                  <th>{t('evColTitle')}</th>
                  <th>{t('evColKind')}</th>
                  <th>{t('evColStatus')}</th>
                  <th>{t('evColWhen')}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {list.data.map((e) => (
                  <tr key={e.id} data-state={e.state}>
                    <td>{title(e)}</td>
                    <td className="small">
                      {e.metric === 'EVENT_GIFTS' ? (
                        <>
                          {t(`evRecurrence_${e.recurrence ?? 'NONE'}` as Key)}
                          {e.recurrence && e.recurrence !== 'NONE' && e.period !== undefined ? ` · #${String(e.period + 1)}` : ''}
                        </>
                      ) : (
                        <span className="muted">{t('evLegacy')}</span>
                      )}
                    </td>
                    <td>
                      <span className={`badge ${e.state === 'RUNNING' ? 'ok' : e.state === 'DRAFT' ? 'warn' : ''}`}>
                        {t(`evState_${e.state}` as Key)}
                      </span>
                    </td>
                    <td className="small date">
                      {e.startsAt
                        ? `${formatDate(e.startsAt, lang)} → ${e.endsAt ? formatDate(e.endsAt, lang) : '∞'}`
                        : t('evNoDates')}
                    </td>
                    <td>
                      <span className="row">
                        {manage && e.metric === 'EVENT_GIFTS' && ['DRAFT', 'UPCOMING', 'RUNNING'].includes(e.state) && (
                          <button className="btn small" onClick={() => setEditing({ id: e.id })}>
                            {e.state === 'DRAFT' ? t('evEditDraft') : t('gevEdit')}
                          </button>
                        )}
                        {e.metric === 'EVENT_GIFTS' && e.state !== 'DRAFT' && (
                          <button className="btn small" onClick={() => setResults(e.id)}>
                            {t('gevResults')}
                          </button>
                        )}
                        {manage &&
                          rowCommands(e).map((c) => (
                            <button
                              key={c}
                              className={`btn small${c === 'discard' || c === 'end' ? ' danger' : ''}`}
                              onClick={() => setAct({ id: e.id, command: c })}
                            >
                              {t(COMMAND_LABEL[c]!)}
                            </button>
                          ))}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      {act && (
        <FormDialog
          title={t(COMMAND_LABEL[act.command]!)}
          fields={[reasonField(t)]}
          confirmLabel={t(COMMAND_LABEL[act.command]!)}
          danger={act.command === 'discard' || act.command === 'end'}
          submit={(v) => api.post(`/admin/events/${act.id}/${act.command}`, { reason: v.reason })}
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            toast(t('done'));
            events.reload();
          }}
        />
      )}
      {festival && (
        <FormDialog
          title={t('evFestival')}
          intro={<p className="muted small">{t('evFestivalHint')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('evFestival')}
          submit={async (v) => {
            const made = await api.post<{ id: string }>('/admin/gift-events/launch-festival', { reason: v.reason });
            setEditing({ id: made.id });
          }}
          onClose={() => setFestival(false)}
          onDone={() => {
            setFestival(false);
            events.reload();
          }}
        />
      )}
      {results && <GiftEventResults eventId={results} onClose={() => setResults(null)} />}
      {editing && (
        <EventEditor
          eventId={editing.id}
          onClose={() => {
            setEditing(null);
            events.reload();
          }}
          onDone={() => {
            setEditing(null);
            toast(t('done'));
            events.reload();
          }}
        />
      )}
    </>
  );
}

/** A new event starts as a draft with no dates (owner: «prepare now, set the dates at launch»). */
export function newDraft(zone: string): GiftEventFormState {
  return { ...emptyGiftEvent(zone), status: 'DRAFT', gifts: [], boards: [] };
}

/** The step-by-step editor; `options` / `initial` may be given (tests, screenshots), otherwise loaded. */
export function EventEditor({
  eventId,
  onClose,
  onDone,
  options: givenOptions,
  initial,
  server: givenServer,
  step: givenStep,
}: {
  eventId?: string;
  onClose: () => void;
  onDone: () => void;
  options?: EventOptions;
  initial?: GiftEventFormState;
  server?: AdminGiftEvent | null;
  step?: EventStep;
}) {
  const { t } = useApp();
  const loadedOptions = useAsync(
    () =>
      givenOptions
        ? Promise.resolve(givenOptions)
        : api.get<EventOptions>(eventId ? `/admin/event-options?eventId=${eventId}` : '/admin/event-options'),
    [eventId],
  );
  const loaded = useAsync(
    () =>
      givenServer !== undefined || !eventId
        ? Promise.resolve(givenServer ?? null)
        : api.get<AdminGiftEvent>(`/admin/gift-events/${eventId}`),
    [eventId],
  );
  const options = givenOptions ?? loadedOptions.data;
  if (!options || (eventId && givenServer === undefined && !initial && !loaded.data)) {
    return (
      <Dialog title={eventId ? t('gevEdit') : t('evNew')} onClose={onClose}>
        <ErrorAlert error={loadedOptions.error ?? loaded.error} />
        <p className="muted">…</p>
      </Dialog>
    );
  }
  const server = givenServer ?? loaded.data ?? null;
  const start =
    initial ??
    (server
      ? formFromServer(server.form, options.timeZone, server.artUrls?.leaderboardBackground ?? null)
      : newDraft(options.timeZone));
  return (
    <Wizard
      eventId={eventId}
      options={options}
      start={start}
      server={server}
      firstStep={givenStep ?? 'evStepBasics'}
      onClose={onClose}
      onDone={onDone}
    />
  );
}

function Wizard({
  eventId: initialId,
  options: initialOptions,
  start,
  server,
  firstStep,
  onClose,
  onDone,
}: {
  eventId?: string;
  options: EventOptions;
  start: GiftEventFormState;
  server: AdminGiftEvent | null;
  firstStep: EventStep;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t, lang, toast } = useApp();
  const [f, setF] = useState<GiftEventFormState>(start);
  const [eventId, setEventId] = useState(initialId);
  const [options, setOptions] = useState(initialOptions);
  const [step, setStep] = useState<EventStep>(firstStep);
  const [artUrls, setArtUrls] = useState(server?.artUrls ?? {});
  const [bannerUrl, setBannerUrl] = useState<string | null>(
    (server as (AdminGiftEvent & { bannerImageUrl?: string | null }) | null)?.bannerImageUrl ?? null,
  );
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [dialog, setDialog] = useState<'gift' | 'item' | 'medal' | null>(null);
  // D356: the pictures the contrast warning measures (fresh uploads; else their URLs when readable).
  const [pageBgFile, setPageBgFile] = useState<Blob | null>(null);
  const [boardBgFile, setBoardBgFile] = useState<Blob | null>(null);
  const video = /\.(mp4|mov)$/.test(f.backgroundKey ?? '');
  const pageColour = useMeasuredColour(pageBgFile ?? (video ? artUrls.backgroundPoster : artUrls.background) ?? null);
  const boardColour = useMeasuredColour(boardBgFile ?? f.design?.backgroundUrl ?? null);
  // D356: the design's problems — the panel's own (the server's rules) and the server's last refusal.
  const designLocal = f.design ? designProblems(f.design, f.boards) : [];
  const designAll = [...designLocal, ...designServerProblems(error)];
  const wasPublished = server?.form.status === 'PUBLISHED' || (server !== null && server.form.status === undefined);
  const locked = server?.structureLocked ?? false;
  const index = EVENT_STEPS.indexOf(step);
  const set = <K extends keyof GiftEventFormState>(k: K, v: GiftEventFormState[K]) => setF((x) => ({ ...x, [k]: v }));
  const name = (o: { nameAr: string; nameEn: string }) => (lang === 'ar' ? o.nameAr : o.nameEn);
  const reloadOptions = (id: string) =>
    api.get<EventOptions>(`/admin/event-options?eventId=${id}`).then(setOptions, setError);

  /** Saves with `status` (a draft keeps what is there; publish runs every rule). Returns the event id. */
  const save = async (status: 'DRAFT' | 'PUBLISHED', reason = f.reason): Promise<string | null> => {
    setBusy(true);
    setError(null);
    try {
      const body = giftEventBody({ ...f, status, reason: reason.trim().length >= 3 ? reason : 'draft saved' });
      const res = eventId
        ? await api.put<{ id: string }>(`/admin/gift-events/${eventId}`, body)
        : await api.post<{ id: string }>('/admin/gift-events', body);
      setEventId(res.id);
      setF((x) => ({ ...x, status }));
      setBusy(false);
      return res.id;
    } catch (e) {
      setError(e);
      setBusy(false);
      // D356: a design refusal is shown at its field in the design step.
      if (designServerProblems(e).length > 0) setStep('evStepDesign');
      return null;
    }
  };
  /** Uploads inside the event need its id: the draft is saved first. */
  const withEvent = async (then: () => void) => {
    if (eventId) {
      then();
      return;
    }
    const id = await save('DRAFT');
    if (id) {
      toast(t('evDraftSaved'));
      void reloadOptions(id);
      then();
    }
  };
  const problems = giftEventProblems(f);
  const draftProblems = giftEventProblems({ ...f, status: 'DRAFT', reason: f.reason || 'draft' });

  const setBoard = (i: number, b: Partial<BoardForm>) =>
    setF((x) => ({ ...x, boards: x.boards.map((o, j) => (j === i ? { ...o, ...b } : o)) }));
  const setLine = (bi: number, li: number, l: Partial<PrizeLineForm>) =>
    setBoard(bi, { prizes: f.boards[bi]!.prizes.map((o, j) => (j === li ? { ...o, ...l } : o)) });
  const toggleBoard = (kind: BoardKind, on: boolean) =>
    setF((x) => ({
      ...x,
      boards: on
        ? [...x.boards, { kind, minPoints: '0', shown: String(BOARD_SHOWN_DEFAULT), prizes: defaultPrizeLines(kind) }].sort(
            (a, b) => BOARD_KINDS.indexOf(a.kind) - BOARD_KINDS.indexOf(b.kind),
          )
        : x.boards.filter((b) => b.kind !== kind),
    }));
  const moneyItem = (kind: BoardKind): PrizeItemForm => ({
    type: BOARD_MONEY[kind][0]!,
    value: '100',
    code: '',
    cherries: '100',
    coins: '100',
  });
  const setMilestone = (i: number, m: Partial<MilestoneForm>) =>
    set(
      'milestones',
      f.milestones.map((o, j) => (j === i ? { ...o, ...m } : o)),
    );

  const body = (() => {
    switch (step) {
      case 'evStepBasics':
        return (
          <div className="form-grid">
            <div className="field">
              <label htmlFor="ev-ar">{t('eventTitleAr')}</label>
              <input id="ev-ar" maxLength={120} value={f.titleAr} onChange={(e) => set('titleAr', e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="ev-en">{t('eventTitleEn')}</label>
              <input
                id="ev-en"
                dir="ltr"
                maxLength={120}
                value={f.titleEn}
                onChange={(e) => set('titleEn', e.target.value)}
              />
            </div>
            <div className="field">
              <label htmlFor="ev-rar">{t('eventRulesAr')}</label>
              <textarea id="ev-rar" maxLength={4000} value={f.rulesAr} onChange={(e) => set('rulesAr', e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="ev-ren">{t('eventRulesEn')}</label>
              <textarea
                id="ev-ren"
                dir="ltr"
                maxLength={4000}
                value={f.rulesEn}
                onChange={(e) => set('rulesEn', e.target.value)}
              />
            </div>
            <label className="check field">
              <input type="checkbox" checked={f.featured} onChange={(e) => set('featured', e.target.checked)} />
              {t('eventFeatured')}
            </label>
            <p className="muted small span-2">{t('evDraftNote')}</p>
          </div>
        );
      case 'evStepTime':
        return (
          <div className="form-grid">
            <div className="field">
              <label htmlFor="ev-start">{t('eventStarts')}</label>
              <input
                id="ev-start"
                type="datetime-local"
                disabled={locked}
                value={f.startsAt}
                onChange={(e) => set('startsAt', e.target.value)}
              />
            </div>
            <div className="field">
              <label htmlFor="ev-end">{t('eventEnds')}</label>
              <input
                id="ev-end"
                type="datetime-local"
                disabled={f.permanent}
                value={f.endsAt}
                onChange={(e) => set('endsAt', e.target.value)}
              />
            </div>
            <div className="field">
              <label htmlFor="ev-tz">{t('gevTimeZone')}</label>
              <input
                id="ev-tz"
                dir="ltr"
                className="mono"
                maxLength={64}
                disabled={locked}
                value={f.timeZone}
                onChange={(e) => set('timeZone', e.target.value)}
              />
              <span className="hint">{t('gevTimeZoneHint')}</span>
            </div>
            <label className="check field">
              <input
                type="checkbox"
                disabled={locked}
                checked={f.permanent}
                onChange={(e) => set('permanent', e.target.checked)}
              />
              {t('evPermanent')}
            </label>
            <fieldset className="span-2" disabled={locked}>
              <legend>{t('evRecurrence')}</legend>
              {RECURRENCES.map((r) => (
                <label key={r} className="check">
                  <input type="radio" name="ev-rec" checked={f.recurrence === r} onChange={() => set('recurrence', r)} />
                  {t(`evRecurrence_${r}`)}
                </label>
              ))}
              <span className="hint">{t('evRecurrenceHint')}</span>
            </fieldset>
          </div>
        );
      case 'evStepAudience':
        return (
          <div className="form-grid">
            <fieldset className="span-2" disabled={locked}>
              <legend>{t('eventAudience')}</legend>
              {EVENT_AUDIENCES.map((a) => (
                <label key={a} className="check">
                  <input type="radio" name="ev-aud" checked={f.audience === a} onChange={() => set('audience', a)} />
                  {t(`evAudience_${a}`)}
                </label>
              ))}
              <span className="hint">{t('evAudienceHint')}</span>
              {server?.creatorsAsHosts === false && f.audience === 'HOSTS' && (
                <span className="hint">{t('evAudienceOldHosts')}</span>
              )}
            </fieldset>
            <fieldset disabled={locked}>
              <legend>{t('evScoring')}</legend>
              {SCORINGS.map((s) => (
                <label key={s} className="check">
                  <input type="radio" name="ev-sc" checked={f.scoring === s} onChange={() => set('scoring', s)} />
                  {t(`evScoring_${s}`)}
                </label>
              ))}
            </fieldset>
            <fieldset disabled={locked}>
              <legend>{t('evCounted')}</legend>
              {COUNTED_GIFTS.map((c) => (
                <label key={c} className="check">
                  <input
                    type="radio"
                    name="ev-cg"
                    checked={f.countedGifts === c}
                    onChange={() => set('countedGifts', c)}
                  />
                  {t(`evCounted_${c}`)}
                </label>
              ))}
            </fieldset>
          </div>
        );
      case 'evStepGifts':
        return (
          <fieldset className="span-2" disabled={locked}>
            <legend>{t('gevGifts')}</legend>
            <p className="muted small">{t('evGiftNewHint')}</p>
            {f.gifts.map((g, i) => {
              const gift = options.gifts.find((o) => o.code === g.giftCode);
              const multiplier = f.scoring === 'COINS' ? 1 : Number(g.pointsPerCoin || 0);
              const each = gift ? Math.floor(gift.priceCoins * multiplier) + Number(g.pointsPerGift || 0) : null;
              return (
                <div key={i} className="row gev-gift" data-gift={g.giftCode}>
                  <select
                    aria-label={t('gevGift')}
                    value={g.giftCode}
                    onChange={(e) =>
                      set(
                        'gifts',
                        f.gifts.map((o, j) => (j === i ? { ...o, giftCode: e.target.value } : o)),
                      )
                    }
                  >
                    <option value="">—</option>
                    {options.gifts
                      .filter((o) => !o.eventId || o.eventId === eventId)
                      .map((o) => (
                        <option key={o.code} value={o.code}>
                          {name(o)} · {formatNumber(o.priceCoins, lang)}
                          {o.eventId ? ` · ${t('evExclusive')}` : ''}
                        </option>
                      ))}
                  </select>
                  {f.scoring === 'MULTIPLIER' && (
                    <label className="small">
                      {t('evMultiplier')} ×
                      <input
                        type="number"
                        min={0}
                        max={1000}
                        step={0.01}
                        value={g.pointsPerCoin}
                        onChange={(e) =>
                          set(
                            'gifts',
                            f.gifts.map((o, j) => (j === i ? { ...o, pointsPerCoin: e.target.value } : o)),
                          )
                        }
                      />
                    </label>
                  )}
                  {each !== null && <span className="muted small">{t('gevPointsEach', { n: formatNumber(each, lang) })}</span>}
                  {gift?.eventId && <span className="badge">{t('evExclusive')}</span>}
                  {gift?.fullscreen && <span className="badge">{t('evGiftFullscreen')}</span>}
                  <button
                    type="button"
                    className="btn small"
                    onClick={() =>
                      set(
                        'gifts',
                        f.gifts.filter((_, j) => j !== i),
                      )
                    }
                  >
                    {t('gevRemove')}
                  </button>
                </div>
              );
            })}
            <div className="row">
              {f.gifts.length < 12 && (
                <button
                  type="button"
                  className="btn small"
                  onClick={() => set('gifts', [...f.gifts, { giftCode: '', pointsPerCoin: '1', pointsPerGift: '0' }])}
                >
                  {t('gevAddGift')}
                </button>
              )}
              <button type="button" className="btn small primary" onClick={() => void withEvent(() => setDialog('gift'))}>
                <Icon name="plus" size={14} />
                {t('evGiftNew')}
              </button>
              {!eventId && <span className="hint">{t('evSaveFirst')}</span>}
            </div>
          </fieldset>
        );
      case 'evStepBoards':
        return (
          <>
            {locked && f.boards.length > 0 && (
              // v1.102-social (D334): «عدد المعروضين» is a display setting — editable while the event runs.
              <fieldset className="span-2" data-testid="ev-shown-running">
                <legend>{t('evShown')}</legend>
                {f.boards.map((b, bi) => (
                  <label key={b.kind} className="small">
                    {t(`gevBoard_${b.kind}`)}
                    <input
                      type="number"
                      min={1}
                      max={BOARD_SHOWN_MAX}
                      value={b.shown ?? String(BOARD_SHOWN_DEFAULT)}
                      onChange={(e) => setBoard(bi, { shown: e.target.value })}
                    />
                  </label>
                ))}
                <span className="hint">{t('evShownHint')}</span>
              </fieldset>
            )}
          <fieldset className="span-2" disabled={locked}>
            <legend>{t('gevBoards')}</legend>
            <p className="muted small">{t('evTop20')}</p>
            <div className="row">
              <button type="button" className="btn small primary" onClick={() => void withEvent(() => setDialog('item'))}>
                <Icon name="plus" size={14} />
                {t('evItemNew')}
              </button>
              <button type="button" className="btn small" onClick={() => setDialog('medal')}>
                {t('gevMedalNew')}
              </button>
            </div>
            {BOARD_KINDS.map((kind) => {
              const bi = f.boards.findIndex((b) => b.kind === kind);
              const b = bi >= 0 ? f.boards[bi] : undefined;
              return (
                <div key={kind} className="gev-board" data-board={kind}>
                  <label className="check">
                    <input type="checkbox" checked={b !== undefined} onChange={(e) => toggleBoard(kind, e.target.checked)} />
                    <strong>{t(`gevBoard_${kind}`)}</strong> <span className="muted small">{t(`gevBoardHint_${kind}`)}</span>
                  </label>
                  {b && (
                    <>
                      <label className="small">
                        {t('gevMinPoints')}
                        <input
                          type="number"
                          min={0}
                          value={b.minPoints}
                          onChange={(e) => setBoard(bi, { minPoints: e.target.value })}
                        />
                      </label>
                      <label className="small" title={t('evShownHint')}>
                        {t('evShown')}
                        <input
                          type="number"
                          min={1}
                          max={BOARD_SHOWN_MAX}
                          value={b.shown ?? String(BOARD_SHOWN_DEFAULT)}
                          onChange={(e) => setBoard(bi, { shown: e.target.value })}
                        />
                      </label>
                      {b.prizes.map((l, li) => (
                        <div key={li} className="gev-line">
                          <input
                            aria-label={t('gevRankFrom')}
                            type="number"
                            min={1}
                            max={100}
                            value={l.rankFrom}
                            onChange={(e) => setLine(bi, li, { rankFrom: e.target.value })}
                          />
                          <span>–</span>
                          <input
                            aria-label={t('gevRankTo')}
                            type="number"
                            min={1}
                            max={100}
                            value={l.rankTo}
                            onChange={(e) => setLine(bi, li, { rankTo: e.target.value })}
                          />
                          {l.items.map((it, ii) => (
                            <span key={ii} className="row">
                              <PrizeItemEditor
                                board={b.kind}
                                item={it}
                                options={options}
                                types={prizeTypesV2For(b.kind)}
                                eventId={eventId}
                                withDisplay
                                onChange={(next) => setLine(bi, li, { items: l.items.map((o, j) => (j === ii ? next : o)) })}
                              />
                              {l.items.length > 1 && (
                                <button
                                  type="button"
                                  className="btn small"
                                  onClick={() => setLine(bi, li, { items: l.items.filter((_, j) => j !== ii) })}
                                >
                                  ×
                                </button>
                              )}
                            </span>
                          ))}
                          {l.items.length < 6 && (
                            <button
                              type="button"
                              className="btn small"
                              onClick={() => setLine(bi, li, { items: [...l.items, moneyItem(b.kind)] })}
                            >
                              {t('gevAddItem')}
                            </button>
                          )}
                          <button
                            type="button"
                            className="btn small"
                            onClick={() => setBoard(bi, { prizes: b.prizes.filter((_, j) => j !== li) })}
                          >
                            {t('gevRemove')}
                          </button>
                        </div>
                      ))}
                      {b.prizes.length < 20 && (
                        <button
                          type="button"
                          className="btn small"
                          onClick={() => {
                            const last = Number(b.prizes.at(-1)?.rankTo ?? 0);
                            setBoard(bi, {
                              prizes: [
                                ...b.prizes,
                                { rankFrom: String(last + 1), rankTo: String(last + 1), items: [moneyItem(b.kind)] },
                              ],
                            });
                          }}
                        >
                          {t('gevAddLine')}
                        </button>
                      )}
                    </>
                  )}
                </div>
              );
            })}
          </fieldset>
          </>
        );
      case 'evStepMilestones':
        return (
          <fieldset className="span-2" disabled={locked}>
            <legend>{t('evStepMilestones')}</legend>
            <p className="muted small">{t('evMilestonesHint')}</p>
            {f.milestones.map((m, i) => (
              <div key={i} className="gev-line ev-milestone">
                <label className="small">
                  {t('evMilestoneBoard')}
                  <select value={m.board} onChange={(e) => setMilestone(i, { board: e.target.value as BoardKind })}>
                    {(f.boards.length > 0 ? f.boards.map((b) => b.kind) : BOARD_KINDS).map((k) => (
                      <option key={k} value={k}>
                        {t(`gevBoard_${k}`)}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="small">
                  {t('evMilestonePoints')}
                  <input type="number" min={1} value={m.points} onChange={(e) => setMilestone(i, { points: e.target.value })} />
                </label>
                {m.items.map((it, ii) => (
                  <PrizeItemEditor
                    key={ii}
                    board={m.board}
                    item={it}
                    options={options}
                    types={prizeTypesV2For(m.board)}
                    eventId={eventId}
                    onChange={(next) => setMilestone(i, { items: m.items.map((o, j) => (j === ii ? next : o)) })}
                  />
                ))}
                <button
                  type="button"
                  className="btn small"
                  onClick={() =>
                    set(
                      'milestones',
                      f.milestones.filter((_, j) => j !== i),
                    )
                  }
                >
                  {t('gevRemove')}
                </button>
              </div>
            ))}
            {f.milestones.length < 10 && (
              <button
                type="button"
                className="btn small"
                onClick={() => {
                  const board = f.boards[0]?.kind ?? 'SENDERS';
                  set('milestones', [...f.milestones, { board, points: '1000', items: [moneyItem(board)] }]);
                }}
              >
                {t('evMilestoneAdd')}
              </button>
            )}
          </fieldset>
        );
      case 'evStepDesign':
        return (
          <div className="dsg-layout">
            <div className="form-grid">
              {/* v1.119-social (D359): «بانر صفحة البث» — the event's only way onto the Live hub (its carousel). */}
              <EventHubBannerField
                f={f}
                spec={options.specs?.find((x) => x.kind === 'banner')}
                imageUrl={bannerUrl}
                onChange={(k, v) => setF((x) => ({ ...x, [k]: v }))}
                onUploaded={(mediaId, url) => {
                  set('bannerMediaId', mediaId);
                  setBannerUrl(url);
                }}
                onError={setError}
                onEditAudience={() => setStep('evStepAudience')}
              />
              {/* v1.105-social (D340): a display setting — editable while the event runs. */}
              <div className="field span-2">
                <label className="check">
                  <input
                    id="ev-announce"
                    type="checkbox"
                    checked={f.announceFullscreen}
                    onChange={(e) => set('announceFullscreen', e.target.checked)}
                  />
                  {t('evAnnounceFullscreen')}
                </label>
                <span className="hint">{t('evAnnounceFullscreenHint')}</span>
              </div>
              <EventArtFields
                f={f}
                options={options}
                urls={artUrls}
                disabled={false}
                preview={false}
                onKey={(slot, key, url, file) => {
                  setF((x) => ({ ...x, [`${slot}Key`]: key }));
                  setArtUrls((x) => ({ ...x, [slot]: url }));
                  if ((slot === 'background' && file && !/^video\//.test(file.type)) || slot === 'backgroundPoster') {
                    setPageBgFile(file ?? null);
                  }
                }}
              />
              {/* v1.115-social (D354 / D356): the page designer — a display setting, editable while the event runs. */}
              <EventDesignFields
                design={f.design ?? null}
                boards={f.boards}
                options={options}
                problems={designAll}
                onChange={(d) => set('design', d)}
                onBackgroundFile={setBoardBgFile}
              />
              {f.design && (
                <div className="span-2">
                  <ContrastNotice design={f.design} page={pageColour} board={boardColour} />
                </div>
              )}
            </div>
            <EventLivePreview
              eventFor={(l) => previewEvent(f, options, artUrls, l, eventId)}
              fallback={<EventPagePreview f={f} urls={artUrls} />}
            />
          </div>
        );
      case 'evStepReview':
        return (
          <div className="form-grid">
            <p className="muted small span-2">{t('evReviewHint')}</p>
            <dl className="span-2 ev-summary">
              <dt>{t('evStepBasics')}</dt>
              <dd>
                {f.titleAr || '—'} / <span dir="ltr">{f.titleEn || '—'}</span>
              </dd>
              <dt>{t('evStepTime')}</dt>
              <dd>
                {f.startsAt ? `${f.startsAt} → ${f.permanent ? '∞' : f.endsAt || '—'} (${f.timeZone})` : t('evNoDates')} ·{' '}
                {t(`evRecurrence_${f.recurrence}`)}
              </dd>
              <dt>{t('evStepAudience')}</dt>
              <dd>
                {t(`evAudience_${f.audience}`)} · {t(`evScoring_${f.scoring}`)} · {t(`evCounted_${f.countedGifts}`)}
              </dd>
              <dt>{t('evStepGifts')}</dt>
              <dd>
                {t('evSummaryGifts', { n: f.gifts.length })} · {t('evSummaryBoards', { n: f.boards.length })} ·{' '}
                {t('evSummaryMilestones', { n: f.milestones.length })}
              </dd>
            </dl>
            <div className="field span-2">
              <label htmlFor="ev-reason">{t('reason')}</label>
              <textarea id="ev-reason" maxLength={500} value={f.reason} onChange={(e) => set('reason', e.target.value)} />
              <span className="hint">{t('reasonHint')}</span>
            </div>
            {(problems.length > 0 || designLocal.length > 0) && (
              <ul className="span-2 muted small gev-problems">
                {problems.map((p) => (
                  <li key={p}>{t(p as Key)}</li>
                ))}
                {[...new Set(designLocal.map((p) => p.issue))].map((issue) => (
                  <li key={issue}>
                    {t('evStepDesign')}: {t(`dsgIssue_${issue}` as Key)}
                  </li>
                ))}
              </ul>
            )}
          </div>
        );
    }
  })();

  return (
    <Dialog title={eventId ? t('gevEdit') : t('evNew')} onClose={onClose}>
      <nav className="ev-steps" aria-label={t('evStepOf', { n: index + 1, total: EVENT_STEPS.length })}>
        {EVENT_STEPS.map((s, i) => (
          <button
            key={s}
            type="button"
            className={`ev-step${s === step ? ' on' : ''}${i < index ? ' done' : ''}`}
            aria-current={s === step ? 'step' : undefined}
            onClick={() => setStep(s)}
          >
            <span className="ev-step-n">{formatNumber(i + 1, lang)}</span>
            {t(s)}
          </button>
        ))}
      </nav>
      <p className="muted small">
        {t('evStepOf', { n: index + 1, total: EVENT_STEPS.length })}
        {' · '}
        <span className={`badge ${f.status === 'DRAFT' ? 'warn' : 'ok'}`}>
          {f.status === 'DRAFT' ? t('evState_DRAFT') : t('evPublish')}
        </span>
      </p>
      {locked && <p className="alert warn">{t('gevStructureLocked')}</p>}
      <ErrorAlert error={error} />
      <div className="ev-body" data-step={step}>
        {body}
      </div>
      <div className="actions ev-actions">
        <button type="button" className="btn" disabled={index === 0} onClick={() => setStep(EVENT_STEPS[index - 1]!)}>
          {t('evBack')}
        </button>
        {!wasPublished && (
          <button
            type="button"
            className="btn"
            disabled={busy || draftProblems.length > 0 || designLocal.length > 0}
            onClick={() => {
              void save('DRAFT').then((id) => {
                if (id) {
                  toast(t('evDraftSaved'));
                  void reloadOptions(id);
                }
              });
            }}
          >
            {t('evSaveDraft')}
          </button>
        )}
        {index < EVENT_STEPS.length - 1 ? (
          <button type="button" className="btn primary" onClick={() => setStep(EVENT_STEPS[index + 1]!)}>
            {t('evNext')}
          </button>
        ) : (
          <button
            type="button"
            className="btn primary"
            disabled={busy || giftEventProblems({ ...f, status: 'PUBLISHED' }).length > 0 || designLocal.length > 0}
            onClick={() => {
              void save('PUBLISHED').then((id) => id && onDone());
            }}
          >
            {wasPublished ? t('evSave') : t('evSaveAndPublish')}
          </button>
        )}
      </div>
      {dialog === 'gift' && eventId && (
        <EventGiftDialog
          eventId={eventId}
          options={options}
          onClose={() => setDialog(null)}
          onDone={(code) => {
            setDialog(null);
            void reloadOptions(eventId);
            set('gifts', [...f.gifts.filter((g) => g.giftCode !== ''), { giftCode: code, pointsPerCoin: '1', pointsPerGift: '0' }]);
          }}
        />
      )}
      {dialog === 'item' && eventId && (
        <EventItemDialog
          eventId={eventId}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            void reloadOptions(eventId);
          }}
        />
      )}
      {dialog === 'medal' && (
        <MedalDialog
          spec={options.specs?.find((x) => x.kind === 'badge')}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            void (eventId ? reloadOptions(eventId) : api.get<EventOptions>('/admin/event-options').then(setOptions));
          }}
        />
      )}
    </Dialog>
  );
}

/**
 * «رفع هدية حصرية»: an exclusive event gift with the D207 uploads (picture, SVGA / MP4 effect) and checks, the price and
 * the «شاشة كاملة» badge — `POST /admin/gifts` with `eventId`.
 */
export function EventGiftDialog({
  eventId,
  options,
  onClose,
  onDone,
}: {
  eventId: string;
  options: EventOptions;
  onClose: () => void;
  onDone: (code: string) => void;
}) {
  const { t, lang } = useApp();
  const [code, setCode] = useState('');
  const [nameAr, setNameAr] = useState('');
  const [nameEn, setNameEn] = useState('');
  const [price, setPrice] = useState('');
  const [category, setCategory] = useState(options.giftCategories?.find((c) => c.code === 'EVENT')?.code ?? options.giftCategories?.[0]?.code ?? 'EVENT');
  const [imageKey, setImageKey] = useState('');
  const [effectKey, setEffectKey] = useState('');
  const [fullscreen, setFullscreen] = useState(false);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const codeOk = /^[a-z0-9][a-z0-9_]{0,39}$/.test(code);
  const ok = codeOk && nameAr.trim() && nameEn.trim() && /^\d+$/.test(price) && Number(price) >= 1 && imageKey && reason.trim().length >= 3;
  const upload = (kind: 'image' | 'animation', file: File, done: (key: string) => void) => {
    setError(null);
    uploadGiftFile(kind, code, file).then((up) => done(up.key), setError);
  };
  return (
    <Dialog title={t('evGiftNew')} onClose={onClose}>
      <p className="muted small">{t('evGiftNewHint')}</p>
      <ErrorAlert error={error} />
      <div className="form-grid">
        <div className="field">
          <label htmlFor="eg-code">{t('evGiftCode')}</label>
          <input id="eg-code" dir="ltr" className="mono" value={code} onChange={(e) => setCode(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="eg-price">{t('evGiftPrice')}</label>
          <input id="eg-price" type="number" min={1} max={100000000} value={price} onChange={(e) => setPrice(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="eg-ar">{t('eventTitleAr')}</label>
          <input id="eg-ar" maxLength={60} value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="eg-en">{t('eventTitleEn')}</label>
          <input id="eg-en" dir="ltr" maxLength={60} value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="eg-cat">{t('evGiftCategory')}</label>
          <select id="eg-cat" value={category} onChange={(e) => setCategory(e.target.value)}>
            {(options.giftCategories ?? [{ code: 'EVENT', nameAr: 'EVENT', nameEn: 'EVENT' }]).map((c) => (
              <option key={c.code} value={c.code}>
                {lang === 'ar' ? c.nameAr : c.nameEn}
              </option>
            ))}
          </select>
        </div>
        <label className="check field">
          <input type="checkbox" checked={fullscreen} onChange={(e) => setFullscreen(e.target.checked)} />
          {t('evGiftFullscreen')}
        </label>
        <div className="field">
          <label htmlFor="eg-img">{t('evGiftImage')}</label>
          <input
            id="eg-img"
            type="file"
            accept="image/png,image/webp"
            disabled={!codeOk}
            onChange={(e) => e.target.files?.[0] && upload('image', e.target.files[0], setImageKey)}
          />
          {imageKey && <span className="badge ok">{t('gevUploaded')}</span>}
        </div>
        <div className="field">
          <label htmlFor="eg-fx">{t('evGiftEffect')}</label>
          <input
            id="eg-fx"
            type="file"
            accept=".svga,video/mp4"
            disabled={!codeOk}
            onChange={(e) => e.target.files?.[0] && upload('animation', e.target.files[0], setEffectKey)}
          />
          {effectKey && <span className="badge ok">{t('gevUploaded')}</span>}
        </div>
        <div className="field span-2">
          <label htmlFor="eg-reason">{t('reason')}</label>
          <textarea id="eg-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button
            type="button"
            className="btn primary"
            disabled={!ok}
            onClick={() => {
              api
                .post('/admin/gifts', {
                  code,
                  category,
                  nameAr: nameAr.trim(),
                  nameEn: nameEn.trim(),
                  priceCoins: Number(price),
                  imageObjectKey: imageKey,
                  ...(effectKey ? { animationObjectKey: effectKey } : {}),
                  ...(fullscreen ? { badges: [{ code: 'FULLSCREEN' }] } : {}),
                  eventId,
                  reason: reason.trim(),
                })
                .then(() => onDone(code), setError);
            }}
          >
            {t('evGiftNew')}
          </button>
        </div>
      </div>
    </Dialog>
  );
}

const ITEM_KINDS = ['AVATAR_FRAME', 'ENTRY_EFFECT', 'ENTRY_BANNER', 'CHAT_BUBBLE', 'PROFILE_CARD'] as const;

/**
 * «رفع جائزة حصرية»: an event-exclusive prize item with the D270 art uploads — `POST /admin/store/items` with `eventId`
 * and no prices (never sold, hidden from the store for good).
 */
export function EventItemDialog({ eventId, onClose, onDone }: { eventId: string; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [kind, setKind] = useState<(typeof ITEM_KINDS)[number]>('AVATAR_FRAME');
  const [nameAr, setNameAr] = useState('');
  const [nameEn, setNameEn] = useState('');
  const [still, setStill] = useState<string | null>(null);
  const [animation, setAnimation] = useState<{ url: string; format: 'SVGA' | 'MP4' | null; alpha: string | null } | null>(
    null,
  );
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const ok = nameAr.trim() && nameEn.trim() && (still || animation) && reason.trim().length >= 1;
  return (
    <Dialog title={t('evItemNew')} onClose={onClose}>
      <p className="muted small">{t('evItemNewHint')}</p>
      <ErrorAlert error={error} />
      <div className="form-grid">
        <div className="field">
          <label htmlFor="ei-kind">{t('evItemKind')}</label>
          <select id="ei-kind" value={kind} onChange={(e) => setKind(e.target.value as (typeof ITEM_KINDS)[number])}>
            {ITEM_KINDS.map((k) => (
              <option key={k} value={k}>
                {t(`evItemKind_${k}`)}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="ei-ar">{t('eventTitleAr')}</label>
          <input id="ei-ar" maxLength={40} value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="ei-en">{t('eventTitleEn')}</label>
          <input id="ei-en" dir="ltr" maxLength={40} value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="ei-still">{t('evItemStill')}</label>
          <input
            id="ei-still"
            type="file"
            accept="image/png,image/webp"
            onChange={(e) =>
              e.target.files?.[0] && uploadStoreArt('still', e.target.files[0]).then((up) => setStill(up.url), setError)
            }
          />
          {still && <img className="ev-item-thumb" src={still} alt="" />}
        </div>
        <div className="field">
          <label htmlFor="ei-anim">{t('evItemAnimation')}</label>
          <input
            id="ei-anim"
            type="file"
            accept=".svga,video/mp4"
            onChange={(e) =>
              e.target.files?.[0] &&
              uploadStoreArt('animation', e.target.files[0]).then(
                (up) => setAnimation({ url: up.url, format: up.format, alpha: up.detectedAlpha }),
                setError,
              )
            }
          />
          {animation && <span className="badge ok">{t('gevUploaded')}</span>}
        </div>
        <div className="field span-2">
          <label htmlFor="ei-reason">{t('reason')}</label>
          <textarea id="ei-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button
            type="button"
            className="btn primary"
            disabled={!ok}
            onClick={() => {
              api
                .post('/admin/store/items', {
                  kind,
                  nameAr: nameAr.trim(),
                  nameEn: nameEn.trim(),
                  still,
                  animation: animation?.url ?? null,
                  ...(animation?.format ? { animationFormat: animation.format } : {}),
                  ...(animation?.format === 'MP4' ? { animationAlpha: animation.alpha ?? 'NONE' } : {}),
                  prices: [],
                  eventId,
                  reason: reason.trim(),
                })
                .then(onDone, setError);
            }}
          >
            {t('evItemNew')}
          </button>
        </div>
      </div>
    </Dialog>
  );
}
