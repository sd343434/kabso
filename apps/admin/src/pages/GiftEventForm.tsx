import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, useAsync } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import {
  BOARD_KINDS,
  BOARD_MONEY,
  PRIZE_TYPES,
  defaultPrizeLines,
  emptyGiftEvent,
  formFromServer,
  giftEventBody,
  giftEventProblems,
  type BoardForm,
  type BoardKind,
  type EventOptions,
  type GiftEventFormState,
  type PrizeLineForm,
} from '../gift-events';
import type { Key } from '../i18n';
import { EventArtFields, MedalDialog, PrizeItemEditor } from './GiftEventParts';

/** `AdminGiftEvent` (openapi): the editors' view of a gift event. */
export interface AdminGiftEvent {
  id: string;
  state: string;
  payoutHold: boolean;
  structureLocked: boolean;
  artUrls?: Partial<Record<'background' | 'backgroundPoster' | 'title' | 'overlay', string | null>>;
  form: Parameters<typeof formFromServer>[0];
  results: {
    board: string;
    rank: number;
    username: string | null;
    displayName: string | null;
    score: number;
    prize: Record<string, unknown>[];
    prizeStatus: 'NONE' | 'PENDING' | 'PAID' | 'FORFEITED';
    payouts: { userId: string; status: string }[];
  }[];
}

/** One prize item as a short line («عملات 10 000», «إطار ذهبي · 7 أيام»). */
export function prizeText(
  item: Record<string, unknown>,
  t: (k: Key, v?: Record<string, string | number>) => string,
  lang: 'ar' | 'en',
): string {
  const type = String(item.type);
  const label = (PRIZE_TYPES as readonly string[]).includes(type) ? t(`gevItem_${type}` as Key) : type;
  if (type === 'CP_MONEY')
    return `${label} ${formatNumber(Number(item.cherries ?? 0), lang)} / ${formatNumber(Number(item.coins ?? 0), lang)}`;
  if (item.days === null)
    return `${label} ${String(item.itemCode ?? item.tierCode ?? item.badgeCode ?? '')} · ${t('gevPermanent')}`;
  if (typeof item.amount === 'number') return `${label} ${formatNumber(item.amount, lang)}`;
  const code = String(item.itemCode ?? item.tierCode ?? '');
  return `${label} ${code} · ${formatNumber(Number(item.days ?? 0), lang)} ${t('gevDays')}`;
}

/**
 * «فعالية هدايا جديدة» / «تعديل فعالية الهدايا» (v1.97-social, D303, §10.114): titles, rules, the dates in a chosen time
 * zone, the audience, the event gifts with their points, the boards (each with its minimum and prize lines of bundles),
 * and the reason. `options` and `initial` may be given (tests); otherwise they are loaded.
 */
export function GiftEventForm({
  eventId,
  onClose,
  onDone,
  options: givenOptions,
  initial,
  locked: givenLocked,
}: {
  eventId?: string;
  onClose: () => void;
  onDone: () => void;
  options?: EventOptions;
  initial?: GiftEventFormState;
  locked?: boolean;
}) {
  const { t, lang } = useApp();
  const loadedOptions = useAsync(
    () => (givenOptions ? Promise.resolve(givenOptions) : api.get<EventOptions>('/admin/event-options')),
    [],
  );
  const loaded = useAsync(
    () => (eventId && !initial ? api.get<AdminGiftEvent>(`/admin/gift-events/${eventId}`) : Promise.resolve(null)),
    [eventId],
  );
  const options = givenOptions ?? loadedOptions.data;
  if (!options || (eventId && !initial && !loaded.data)) {
    return (
      <Dialog title={eventId ? t('gevEdit') : t('gevCreate')} onClose={onClose}>
        <ErrorAlert error={loadedOptions.error ?? loaded.error} />
        <p className="muted">…</p>
      </Dialog>
    );
  }
  const start =
    initial ?? (loaded.data ? formFromServer(loaded.data.form, options.timeZone) : emptyGiftEvent(options.timeZone));
  return (
    <Editor
      eventId={eventId}
      options={options}
      start={start}
      locked={givenLocked ?? loaded.data?.structureLocked ?? false}
      artUrls={loaded.data?.artUrls}
      onClose={onClose}
      onDone={onDone}
      lang={lang}
    />
  );
}

function Editor({
  eventId,
  options: initialOptions,
  artUrls: initialArtUrls,
  start,
  locked,
  onClose,
  onDone,
  lang,
}: {
  eventId?: string;
  options: EventOptions;
  artUrls?: Partial<Record<'background' | 'backgroundPoster' | 'title' | 'overlay', string | null>>;
  start: GiftEventFormState;
  locked: boolean;
  onClose: () => void;
  onDone: () => void;
  lang: 'ar' | 'en';
}) {
  const { t } = useApp();
  const [f, setF] = useState<GiftEventFormState>(start);
  const [options, setOptions] = useState<EventOptions>(initialOptions);
  const [artUrls, setArtUrls] = useState(initialArtUrls ?? {});
  const [medal, setMedal] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const problems = giftEventProblems(f);
  const set = <K extends keyof GiftEventFormState>(k: K, v: GiftEventFormState[K]) => setF((x) => ({ ...x, [k]: v }));
  const text = (
    k: 'titleAr' | 'titleEn' | 'rulesAr' | 'rulesEn' | 'startsAt' | 'endsAt' | 'timeZone' | 'bannerUrl' | 'reason',
  ) => ({
    value: f[k],
    onChange: (e: { target: { value: string } }) => set(k, e.target.value),
  });
  const setBoard = (i: number, b: Partial<BoardForm>) =>
    setF((x) => ({
      ...x,
      boards: x.boards.map((o, j) => (j === i ? { ...o, ...b } : o)),
    }));
  const setLine = (bi: number, li: number, l: Partial<PrizeLineForm>) =>
    setBoard(bi, {
      prizes: f.boards[bi]!.prizes.map((o, j) => (j === li ? { ...o, ...l } : o)),
    });
  const toggleBoard = (kind: BoardKind, on: boolean) =>
    setF((x) => ({
      ...x,
      boards: on
        ? [...x.boards, { kind, minPoints: '0', prizes: defaultPrizeLines(kind) }].sort(
            (a, b) => BOARD_KINDS.indexOf(a.kind) - BOARD_KINDS.indexOf(b.kind),
          )
        : x.boards.filter((b) => b.kind !== kind),
    }));
  const name = (o: { nameAr: string; nameEn: string }) => (lang === 'ar' ? o.nameAr : o.nameEn);
  return (
    <Dialog title={eventId ? t('gevEdit') : t('gevCreate')} onClose={onClose}>
      <p className="muted small">{t('gevIntro')}</p>
      {locked && <p className="alert warn">{t('gevStructureLocked')}</p>}
      <ErrorAlert error={error} />
      <form
        className="form-grid gift-event-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (problems.length > 0 || busy) return;
          setBusy(true);
          setError(null);
          const body = giftEventBody(f);
          (eventId ? api.put(`/admin/gift-events/${eventId}`, body) : api.post('/admin/gift-events', body)).then(
            onDone,
            (err: unknown) => {
              setError(err);
              setBusy(false);
            },
          );
        }}
      >
        <div className="field">
          <label htmlFor="gev-ar">{t('eventTitleAr')}</label>
          <input id="gev-ar" type="text" maxLength={120} {...text('titleAr')} />
        </div>
        <div className="field">
          <label htmlFor="gev-en">{t('eventTitleEn')}</label>
          <input id="gev-en" type="text" dir="ltr" maxLength={120} {...text('titleEn')} />
        </div>
        <div className="field">
          <label htmlFor="gev-start">{t('eventStarts')}</label>
          <input id="gev-start" type="datetime-local" disabled={locked} {...text('startsAt')} />
        </div>
        <div className="field">
          <label htmlFor="gev-end">{t('eventEnds')}</label>
          <input id="gev-end" type="datetime-local" {...text('endsAt')} />
        </div>
        <div className="field">
          <label htmlFor="gev-tz">{t('gevTimeZone')}</label>
          <input
            id="gev-tz"
            type="text"
            dir="ltr"
            className="mono"
            maxLength={64}
            disabled={locked}
            {...text('timeZone')}
          />
          <span className="hint">{t('gevTimeZoneHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="gev-aud">{t('eventAudience')}</label>
          <select
            id="gev-aud"
            value={f.audience}
            disabled={locked}
            onChange={(e) => set('audience', e.target.value as GiftEventFormState['audience'])}
          >
            <option value="EVERYONE">{t('audienceEVERYONE')}</option>
            <option value="HOSTS">{t('audienceHOSTS')}</option>
            <option value="CREATORS">{t('gevAudience_CREATORS')}</option>
          </select>
        </div>
        <label className="check field">
          <input type="checkbox" checked={f.featured} onChange={(e) => set('featured', e.target.checked)} />
          {t('eventFeatured')}
        </label>
        <div className="field">
          <label htmlFor="gev-banner">{t('gevBannerUrl')}</label>
          <input id="gev-banner" type="url" dir="ltr" maxLength={2048} placeholder="https://" {...text('bannerUrl')} />
        </div>
        <EventArtFields
          f={f}
          options={options}
          urls={artUrls}
          disabled={false}
          onKey={(slot, key, url) => {
            setF((x) => ({ ...x, [`${slot}Key`]: key }));
            setArtUrls((x) => ({ ...x, [slot]: url }));
          }}
        />
        <div className="field span-2">
          <button type="button" className="btn small" onClick={() => setMedal(true)}>
            {t('gevMedalNew')}
          </button>
        </div>
        <div className="field">
          <label htmlFor="gev-rar">{t('eventRulesAr')}</label>
          <textarea id="gev-rar" maxLength={4000} {...text('rulesAr')} />
        </div>
        <div className="field">
          <label htmlFor="gev-ren">{t('eventRulesEn')}</label>
          <textarea id="gev-ren" dir="ltr" maxLength={4000} {...text('rulesEn')} />
        </div>

        <fieldset className="span-2" disabled={locked}>
          <legend>{t('gevGifts')}</legend>
          {f.gifts.map((g, i) => {
            const gift = options.gifts.find((o) => o.code === g.giftCode);
            const each = gift ? gift.priceCoins * Number(g.pointsPerCoin || 0) + Number(g.pointsPerGift || 0) : null;
            return (
              <div key={i} className="row gev-gift">
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
                  {options.gifts.map((o) => (
                    <option key={o.code} value={o.code}>
                      {name(o)} · {formatNumber(o.priceCoins, lang)}
                    </option>
                  ))}
                </select>
                <label className="small">
                  {t('gevPointsPerCoin')}
                  <input
                    type="number"
                    min={0}
                    max={1000}
                    value={g.pointsPerCoin}
                    onChange={(e) =>
                      set(
                        'gifts',
                        f.gifts.map((o, j) => (j === i ? { ...o, pointsPerCoin: e.target.value } : o)),
                      )
                    }
                  />
                </label>
                <label className="small">
                  {t('gevPointsPerGift')}
                  <input
                    type="number"
                    min={0}
                    max={1000000}
                    value={g.pointsPerGift}
                    onChange={(e) =>
                      set(
                        'gifts',
                        f.gifts.map((o, j) => (j === i ? { ...o, pointsPerGift: e.target.value } : o)),
                      )
                    }
                  />
                </label>
                {each !== null && (
                  <span className="muted small">{t('gevPointsEach', { n: formatNumber(each, lang) })}</span>
                )}
                {f.gifts.length > 1 && (
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
                )}
              </div>
            );
          })}
          {f.gifts.length < 12 && (
            <button
              type="button"
              className="btn small"
              onClick={() => set('gifts', [...f.gifts, { giftCode: '', pointsPerCoin: '1', pointsPerGift: '0' }])}
            >
              {t('gevAddGift')}
            </button>
          )}
        </fieldset>

        <fieldset className="span-2" disabled={locked}>
          <legend>{t('gevBoards')}</legend>
          {BOARD_KINDS.map((kind) => {
            const bi = f.boards.findIndex((b) => b.kind === kind);
            const b = bi >= 0 ? f.boards[bi] : undefined;
            return (
              <div key={kind} className="gev-board" data-board={kind}>
                <label className="check">
                  <input
                    type="checkbox"
                    checked={b !== undefined}
                    onChange={(e) => toggleBoard(kind, e.target.checked)}
                  />
                  <strong>{t(`gevBoard_${kind}`)}</strong>{' '}
                  <span className="muted small">{t(`gevBoardHint_${kind}`)}</span>
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
                    <div className="small muted">{t('gevPrizeLines')}</div>
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
                              onChange={(next) =>
                                setLine(bi, li, {
                                  items: l.items.map((o, j) => (j === ii ? next : o)),
                                })
                              }
                            />
                            {l.items.length > 1 && (
                              <button
                                type="button"
                                className="btn small"
                                onClick={() =>
                                  setLine(bi, li, {
                                    items: l.items.filter((_, j) => j !== ii),
                                  })
                                }
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
                            onClick={() =>
                              setLine(bi, li, {
                                items: [
                                  ...l.items,
                                  {
                                    type: BOARD_MONEY[b.kind][0]!,
                                    value: '100',
                                    code: '',
                                    cherries: '100',
                                    coins: '100',
                                  },
                                ],
                              })
                            }
                          >
                            {t('gevAddItem')}
                          </button>
                        )}
                        <button
                          type="button"
                          className="btn small"
                          onClick={() =>
                            setBoard(bi, {
                              prizes: b.prizes.filter((_, j) => j !== li),
                            })
                          }
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
                              {
                                rankFrom: String(last + 1),
                                rankTo: String(last + 1),
                                items: [
                                  {
                                    type: BOARD_MONEY[b.kind][0]!,
                                    value: '100',
                                    code: '',
                                    cherries: '100',
                                    coins: '100',
                                  },
                                ],
                              },
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

        <div className="field span-2">
          <label htmlFor="gev-reason">{t('reason')}</label>
          <textarea id="gev-reason" maxLength={500} {...text('reason')} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        {problems.length > 0 && (
          <ul className="span-2 muted small gev-problems">
            {problems.map((p) => (
              <li key={p}>{t(p as Key)}</li>
            ))}
          </ul>
        )}
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={problems.length > 0 || busy}>
            {eventId ? t('gevSave') : t('gevCreate')}
          </button>
        </div>
      </form>
      {medal && (
        <MedalDialog
          spec={options.specs?.find((x) => x.kind === 'badge')}
          onClose={() => setMedal(false)}
          onDone={() => {
            setMedal(false);
            void api.get<EventOptions>('/admin/event-options').then(setOptions);
          }}
        />
      )}
    </Dialog>
  );
}

/** «النتائج»: each board's frozen ranks with the prize and its payout (PENDING / PAID / FORFEITED). */
export function GiftEventResults({
  eventId,
  onClose,
  data: given,
}: {
  eventId: string;
  onClose: () => void;
  data?: AdminGiftEvent;
}) {
  const { t, lang } = useApp();
  const loaded = useAsync(
    () => (given ? Promise.resolve(given) : api.get<AdminGiftEvent>(`/admin/gift-events/${eventId}`)),
    [eventId],
  );
  const data = given ?? loaded.data;
  return (
    <Dialog title={t('gevResults')} onClose={onClose}>
      <ErrorAlert error={loaded.error} />
      {data && data.results.length === 0 && <p className="muted">{t('gevNoResults')}</p>}
      {data && data.results.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('gevColBoard')}</th>
                <th className="num">{t('gevColRank')}</th>
                <th>{t('gevColWinner')}</th>
                <th className="num">{t('gevColScore')}</th>
                <th>{t('gevColPrize')}</th>
                <th>{t('gevColPayout')}</th>
              </tr>
            </thead>
            <tbody>
              {data.results.map((r) => (
                <tr key={`${r.board}-${r.rank}`}>
                  <td className="small">
                    {(BOARD_KINDS as readonly string[]).includes(r.board)
                      ? t(`gevBoard_${r.board as BoardKind}`)
                      : r.board}
                  </td>
                  <td className="num">{formatNumber(r.rank, lang)}</td>
                  <td>
                    {r.displayName ?? '—'} <span className="muted small ltr">@{r.username ?? '—'}</span>
                  </td>
                  <td className="num">{formatNumber(r.score, lang)}</td>
                  <td className="small">{r.prize.map((p) => prizeText(p, t, lang)).join('، ') || '—'}</td>
                  <td>
                    <span
                      className={`badge ${r.prizeStatus === 'PAID' ? 'ok' : r.prizeStatus === 'FORFEITED' ? 'bad' : ''}`}
                    >
                      {t(`gevPayout_${r.prizeStatus}`)}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Dialog>
  );
}
