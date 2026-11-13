/**
 * D356 (CONVENTIONS §10.152): the editor's «التصميم» step — the event page designer (D354's `design`, §10.150) with
 * pickers with thumbnails, the sections list (drag to reorder, visibility under the server's rules), the leaderboard
 * background upload, the rewards tiers, the motion controls, the contrast warning — and the REAL live preview: the
 * app's own Flutter page (the preview bundle at /event-preview/) in a phone frame, fed by postMessage as the fields
 * change. If the bundle does not answer, the old sketch preview shows with a notice.
 */
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { uploadEventMedia } from '../api';
import { ErrorAlert } from '../components';
import { useApp } from '../context';
import {
  DESIGN_COUNTDOWNS,
  DESIGN_EDGES,
  DESIGN_ENTRANCES,
  DESIGN_LAYOUTS,
  DESIGN_LEADERBOARDS,
  DESIGN_LIMITS,
  DESIGN_PRESETS,
  DESIGN_RULES_BUTTONS,
  PREVIEW_DEVICES,
  PREVIEW_ERROR,
  PREVIEW_READY,
  PREVIEW_RENDERED,
  PREVIEW_STATES,
  boardPlaces,
  brightColour,
  contrastWarnings,
  coveringLine,
  defaultDesign,
  lineItems,
  moveSection,
  nextTier,
  offered,
  previewMessage,
  previewReply,
  previewUrl,
  problemsAt,
  sectionLock,
  setRulesButton,
  setSectionVisible,
  tiersFromLines,
  withTier,
  type DesignForm,
  type DesignProblem,
  type PreviewSettings,
  type TierForm,
} from '../event-design';
import { formatNumber } from '../format';
import type { BoardForm, EventOptions } from '../gift-events';
import type { Key } from '../i18n';
import { prizeText } from './GiftEventForm';

/** The option thumbnails: captures of the real page (apps/admin/e2e-preview/thumbnails.mjs). */
const THUMBS = import.meta.glob('../assets/event-design/*.webp', { eager: true, import: 'default' }) as Record<
  string,
  string
>;
export const thumbnail = (group: string, value: string): string | null =>
  THUMBS[`../assets/event-design/${group}-${value}.webp`] ?? null;

/** One row of choices, each a card with its thumbnail (radio semantics). */
function Picker<T extends string>({
  name,
  label,
  group,
  values,
  value,
  onChange,
  labelOf,
}: {
  name: string;
  label: string;
  group: string;
  values: readonly T[];
  value: T | null;
  onChange: (v: T) => void;
  labelOf: (v: T) => string;
}) {
  return (
    <fieldset className="dsg-picker" data-picker={name}>
      <legend>{label}</legend>
      <div className="dsg-options" role="radiogroup" aria-label={label}>
        {values.map((v) => {
          const src = thumbnail(group, v);
          return (
            <label key={v} className={`dsg-option${v === value ? ' on' : ''}`} data-value={v}>
              <input type="radio" name={name} value={v} checked={v === value} onChange={() => onChange(v)} />
              {src ? <img src={src} alt="" loading="lazy" /> : <span className="dsg-thumb-none" aria-hidden="true" />}
              <span>{labelOf(v)}</span>
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}

function Issues({ list }: { list: readonly DesignProblem[] }) {
  const { t } = useApp();
  if (list.length === 0) return null;
  return (
    <ul className="dsg-issues" role="alert">
      {[...new Set(list.map((p) => p.issue))].map((issue) => (
        <li key={issue}>{t(`dsgIssue_${issue}` as Key)}</li>
      ))}
    </ul>
  );
}

/** A colour measured from a picture (a fresh upload's file, else its URL when the host allows reading it). */
export function useMeasuredColour(source: Blob | string | null | undefined): [number, number, number] | null {
  const [rgb, setRgb] = useState<[number, number, number] | null>(null);
  useEffect(() => {
    setRgb(null);
    if (!source || typeof document === 'undefined') return;
    let live = true;
    const measure = (img: CanvasImageSource) => {
      const c = document.createElement('canvas');
      c.width = 24;
      c.height = 32;
      const g = c.getContext('2d', { willReadFrequently: true });
      if (!g) return;
      g.drawImage(img, 0, 0, c.width, c.height);
      try {
        const data = g.getImageData(0, 0, c.width, c.height).data;
        if (live) setRgb(brightColour(data));
      } catch {
        // A picture from a host without CORS cannot be read: not judged.
      }
    };
    if (typeof source !== 'string') {
      createImageBitmap(source).then(measure, () => undefined);
    } else {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => measure(img);
      img.src = source;
    }
    return () => {
      live = false;
    };
  }, [source]);
  return rgb;
}

/** The contrast warning «قد يصعب قراءة النص» (never blocks saving). */
export function ContrastNotice({
  design,
  page,
  board,
}: {
  design: DesignForm;
  page: [number, number, number] | null;
  board: [number, number, number] | null;
}) {
  const { t, lang } = useApp();
  const warnings = contrastWarnings(design.preset, design.leaderboard, page, design.backgroundMediaId ? board : null);
  if (warnings.length === 0) return null;
  return (
    <div className="alert warn dsg-contrast" role="status" data-testid="dsg-contrast">
      <strong>{t('dsgContrast')}</strong>
      <ul>
        {warnings.map((w) => (
          <li key={w.where} data-where={w.where}>
            {t(`dsgContrast_${w.where}`, { r: formatNumber(Math.round(w.ratio * 10) / 10, lang) })}
          </li>
        ))}
      </ul>
      <span className="hint">{t('dsgContrastHint')}</span>
    </div>
  );
}

/** The sections list: drag (or ↑ / ↓) to reorder, the visibility switch under the rules, the reason when locked. */
function SectionsList({ d, hasBoards, onChange }: { d: DesignForm; hasBoards: boolean; onChange: (d: DesignForm) => void }) {
  const { t } = useApp();
  const [drag, setDrag] = useState<number | null>(null);
  const rewards = d.sections.findIndex((s) => s.id === 'REWARDS');
  const boards = d.sections.findIndex((s) => s.id === 'BOARDS');
  const rewardsFirst = d.sections[rewards]?.visible && (!d.sections[boards]?.visible || rewards < boards);
  return (
    <fieldset className="dsg-sections" data-testid="dsg-sections">
      <legend>{t('dsgSections')}</legend>
      <span className="hint">{t('dsgSectionsHint')}</span>
      <ol>
        {d.sections.map((s, i) => {
          const lock = sectionLock(d, s.id, hasBoards);
          return (
            <li
              key={s.id}
              data-section={s.id}
              draggable
              className={`dsg-section${drag === i ? ' dragging' : ''}${s.visible ? '' : ' hidden-section'}`}
              onDragStart={(e) => {
                setDrag(i);
                e.dataTransfer.effectAllowed = 'move';
                e.dataTransfer.setData('text/plain', s.id);
              }}
              onDragOver={(e) => {
                if (drag === null) return;
                e.preventDefault();
                if (drag !== i) {
                  onChange(moveSection(d, drag, i));
                  setDrag(i);
                }
              }}
              onDragEnd={() => setDrag(null)}
              onDrop={(e) => {
                e.preventDefault();
                setDrag(null);
              }}
            >
              <span className="dsg-grip" aria-hidden="true">
                ⋮⋮
              </span>
              <strong>{t(`dsgSection_${s.id}`)}</strong>
              <label className="check small">
                <input
                  type="checkbox"
                  checked={s.visible}
                  disabled={lock !== null}
                  onChange={(e) => onChange(setSectionVisible(d, s.id, e.target.checked, hasBoards))}
                />
                {t('dsgVisible')}
              </label>
              <button
                type="button"
                className="btn small"
                aria-label={t('dsgMoveUp')}
                disabled={i === 0}
                onClick={() => onChange(moveSection(d, i, i - 1))}
              >
                ↑
              </button>
              <button
                type="button"
                className="btn small"
                aria-label={t('dsgMoveDown')}
                disabled={i === d.sections.length - 1}
                onClick={() => onChange(moveSection(d, i, i + 1))}
              >
                ↓
              </button>
              {lock && (
                <span className="hint dsg-lock" data-lock={lock}>
                  {t(lock === 'design_boards_required' ? 'dsgLockBoards' : 'dsgLockRules')}
                </span>
              )}
            </li>
          );
        })}
      </ol>
      {rewardsFirst && <span className="hint">{t('dsgRewardsFirst')}</span>}
    </fieldset>
  );
}

/** One board's rewards tiers. */
function TiersEditor({
  d,
  boards,
  problems,
  onChange,
}: {
  d: DesignForm;
  boards: readonly BoardForm[];
  problems: readonly DesignProblem[];
  onChange: (d: DesignForm) => void;
}) {
  const { t, lang } = useApp();
  const withPrizes = boards.filter((b) => b.prizes.length > 0);
  const setTier = (i: number, patch: Partial<TierForm>) =>
    onChange({ ...d, tiers: (d.tiers ?? []).map((x, j) => (j === i ? { ...x, ...patch } : x)) });
  return (
    <fieldset className="dsg-tiers" data-testid="dsg-tiers">
      <legend>{t('dsgTiers')}</legend>
      <span className="hint">{t('dsgTiersHint')}</span>
      {withPrizes.length === 0 ? (
        <p className="muted small">{t('dsgTiersNone')}</p>
      ) : (
        <>
          <div className="row">
            <label className="check small">
              <input type="radio" name="dsg-tiers" checked={d.tiers === null} onChange={() => onChange({ ...d, tiers: null })} />
              {t('dsgTiersDefault')}
            </label>
            <label className="check small">
              <input
                type="radio"
                name="dsg-tiers"
                checked={d.tiers !== null}
                onChange={() => onChange({ ...d, tiers: withPrizes.flatMap(tiersFromLines) })}
              />
              {t('dsgTiersCustom')}
            </label>
          </div>
          {d.tiers !== null &&
            withPrizes.map((b) => {
              const next = nextTier(d, b);
              return (
                <div key={b.kind} className="gev-board dsg-tier-board" data-board={b.kind}>
                  <strong>{t(`gevBoard_${b.kind}`)}</strong>{' '}
                  <span className="muted small">{t('dsgTierPlaces', { n: boardPlaces(b) })}</span>
                  {(d.tiers ?? []).map((tier, i) => {
                    if (tier.board !== b.kind) return null;
                    const line = coveringLine(b, Number(tier.from), Number(tier.to));
                    const items = lineItems(b, tier);
                    const mine = problemsAt(problems, i);
                    return (
                      <div key={i} className={`gev-line dsg-tier${mine.length > 0 ? ' invalid' : ''}`} data-tier={i}>
                        <label className="small">
                          {t('dsgTierFrom')}
                          <input
                            type="number"
                            min={1}
                            max={boardPlaces(b)}
                            value={tier.from}
                            aria-invalid={mine.length > 0}
                            onChange={(e) => setTier(i, { from: e.target.value, featured: [] })}
                          />
                        </label>
                        <label className="small">
                          {t('dsgTierTo')}
                          <input
                            type="number"
                            min={1}
                            max={boardPlaces(b)}
                            value={tier.to}
                            aria-invalid={mine.length > 0}
                            onChange={(e) => setTier(i, { to: e.target.value, featured: [] })}
                          />
                        </label>
                        <input
                          aria-label={t('dsgTierLabelAr')}
                          placeholder={t('dsgTierLabelAr')}
                          maxLength={DESIGN_LIMITS.labelLength}
                          value={tier.labelAr}
                          onChange={(e) => setTier(i, { labelAr: e.target.value })}
                        />
                        <input
                          aria-label={t('dsgTierLabelEn')}
                          placeholder={t('dsgTierLabelEn')}
                          dir="ltr"
                          maxLength={DESIGN_LIMITS.labelLength}
                          value={tier.labelEn}
                          onChange={(e) => setTier(i, { labelEn: e.target.value })}
                        />
                        <span className="small muted">
                          {line ? t('dsgTierLine', { from: line.rankFrom, to: line.rankTo }) : t('dsgTierNoLine')}
                        </span>
                        {items.length > 0 && (
                          <span className="dsg-featured" role="group" aria-label={t('dsgTierFeatured')}>
                            <span className="small">{t('dsgTierFeatured')}</span>
                            {items.map((it, k) => (
                              <label key={k} className="check small">
                                <input
                                  type="checkbox"
                                  checked={tier.featured.includes(k)}
                                  disabled={!tier.featured.includes(k) && tier.featured.length >= DESIGN_LIMITS.featured}
                                  onChange={(e) =>
                                    setTier(i, {
                                      featured: e.target.checked
                                        ? [...tier.featured, k].sort((x, y) => x - y)
                                        : tier.featured.filter((x) => x !== k),
                                    })
                                  }
                                />
                                {prizeText(it, t, lang)}
                              </label>
                            ))}
                          </span>
                        )}
                        <button
                          type="button"
                          className="btn small"
                          onClick={() => onChange({ ...d, tiers: (d.tiers ?? []).filter((_, j) => j !== i) })}
                        >
                          {t('dsgTierRemove')}
                        </button>
                        <Issues list={mine} />
                      </div>
                    );
                  })}
                  {next && (d.tiers ?? []).length < DESIGN_LIMITS.tiers && (
                    <button type="button" className="btn small" onClick={() => onChange(withTier(d, next))}>
                      {t('dsgTierAdd')}
                    </button>
                  )}
                </div>
              );
            })}
        </>
      )}
    </fieldset>
  );
}

/**
 * The step's design part. [design] null = today's page (the switch turns the designer on with the defaults).
 * [problems] are the panel's checks and the server's last refusal together, by field.
 */
export function EventDesignFields({
  design,
  boards,
  options,
  problems,
  onChange,
  onBackgroundFile,
}: {
  design: DesignForm | null;
  boards: readonly BoardForm[];
  options: EventOptions;
  problems: readonly DesignProblem[];
  onChange: (d: DesignForm | null) => void;
  onBackgroundFile?: (file: Blob | null) => void;
}) {
  const { t } = useApp();
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const c = options.designChoices;
  const spec = options.specs?.find((s) => s.kind === 'board_background');
  const hasBoards = boards.length > 0;
  return (
    <fieldset className="span-2 dsg" data-testid="dsg">
      <legend>{t('dsgTitle')}</legend>
      <p className="muted small">{t('dsgIntro')}</p>
      <div className="row">
        <label className="check">
          <input
            type="checkbox"
            id="dsg-use"
            checked={design !== null}
            onChange={(e) => onChange(e.target.checked ? defaultDesign() : null)}
          />
          {t('dsgUse')}
        </label>
        {design !== null && (
          <button
            type="button"
            className="btn small"
            data-testid="dsg-reset"
            onClick={() => onChange(defaultDesign(design))}
          >
            {t('dsgReset')}
          </button>
        )}
      </div>
      {design === null ? (
        <span className="hint">{t('dsgUseHint')}</span>
      ) : (
        <>
          <Picker
            name="layout"
            group="layout"
            label={t('dsgLayout')}
            values={offered(DESIGN_LAYOUTS, c?.layouts)}
            value={design.layout}
            onChange={(layout) => onChange({ ...design, layout })}
            labelOf={(v) => t(`dsgLayout_${v}`)}
          />
          <Picker
            name="leaderboard"
            group="leaderboard"
            label={t('dsgLeaderboard')}
            values={offered(DESIGN_LEADERBOARDS, c?.leaderboards)}
            value={design.leaderboard}
            onChange={(leaderboard) => onChange({ ...design, leaderboard })}
            labelOf={(v) => t(`dsgLeaderboard_${v}`)}
          />
          <Picker
            name="countdown"
            group="countdown"
            label={t('dsgCountdown')}
            values={offered(DESIGN_COUNTDOWNS, c?.countdowns)}
            value={design.countdown}
            onChange={(countdown) => onChange({ ...design, countdown })}
            labelOf={(v) => t(`dsgCountdown_${v}`)}
          />
          <Picker
            name="preset"
            group="preset"
            label={t('dsgPreset')}
            values={offered(DESIGN_PRESETS, c?.presets)}
            value={design.preset}
            onChange={(preset) => onChange({ ...design, preset })}
            labelOf={(v) => t(`dsgPreset_${v}`)}
          />
          <Picker
            name="rules"
            group="rules"
            label={t('dsgRules')}
            values={['NONE', ...offered(DESIGN_RULES_BUTTONS, c?.rulesButtons)] as const}
            value={design.rulesButton?.style ?? 'NONE'}
            onChange={(style) =>
              onChange(
                setRulesButton(
                  design,
                  style === 'NONE' ? null : { style, edge: design.rulesButton?.edge ?? 'END' },
                ),
              )
            }
            labelOf={(v) => t(`dsgRules_${v}`)}
          />
          {design.rulesButton && (
            <div className="field dsg-edge" data-testid="dsg-edge">
              <span className="small">{t('dsgEdge')}</span>
              {offered(DESIGN_EDGES, c?.edges).map((edge) => (
                <label key={edge} className="check small">
                  <input
                    type="radio"
                    name="dsg-edge"
                    checked={design.rulesButton?.edge === edge}
                    onChange={() => onChange({ ...design, rulesButton: { ...design.rulesButton!, edge } })}
                  />
                  {t(`dsgEdge_${edge}`)}
                </label>
              ))}
              {(design.rulesButton.style === 'GOLD_PILL' || design.rulesButton.style === 'APP_BAR_LINK') && (
                <span className="hint">{t('dsgEdgeFixed')}</span>
              )}
            </div>
          )}
          {!design.rulesButton && <span className="hint">{t('dsgRulesBack')}</span>}
          <Issues list={problemsAt(problems, 'rules')} />
          <SectionsList d={design} hasBoards={hasBoards} onChange={onChange} />
          <Issues list={problemsAt(problems, 'sections')} />

          <div className="field dsg-background">
            <label htmlFor="dsg-bg">{t('dsgBackground')}</label>
            <input
              id="dsg-bg"
              type="file"
              accept="image/png,image/jpeg,image/webp"
              disabled={busy}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                setBusy(true);
                setError(null);
                uploadEventMedia('board_background', file).then(
                  (up) => {
                    setBusy(false);
                    onBackgroundFile?.(file);
                    onChange({ ...design, backgroundMediaId: up.mediaId, backgroundUrl: up.url });
                  },
                  (err: unknown) => {
                    setBusy(false);
                    setError(err);
                  },
                );
              }}
            />
            {spec && (
              <span className="hint ltr spec" data-spec="board_background">
                {`${String(spec.width)} × ${String(spec.height)} px · ${spec.formats.join(', ')}`}
              </span>
            )}
            <span className="hint">{t('dsgBackgroundHint')}</span>
            <ErrorAlert error={error} />
            {design.backgroundMediaId && (
              <span className="row">
                {design.backgroundUrl && <img className="dsg-bg-thumb" src={design.backgroundUrl} alt="" />}
                <button
                  type="button"
                  className="btn small"
                  onClick={() => {
                    onBackgroundFile?.(null);
                    onChange({ ...design, backgroundMediaId: null, backgroundUrl: null });
                  }}
                >
                  {t('dsgBackgroundRemove')}
                </button>
              </span>
            )}
            <Issues list={problemsAt(problems, 'background')} />
          </div>

          <TiersEditor d={design} boards={boards} problems={problems} onChange={onChange} />

          <fieldset className="dsg-motion" data-testid="dsg-motion">
            <legend>{t('dsgMotion')}</legend>
            <label className="small">
              {t('dsgEntrance')}
              <select
                value={design.motion.entrance}
                onChange={(e) =>
                  onChange({ ...design, motion: { ...design.motion, entrance: e.target.value as DesignForm['motion']['entrance'] } })
                }
              >
                {offered(DESIGN_ENTRANCES, c?.entrances).map((v) => (
                  <option key={v} value={v}>
                    {t(`dsgEntrance_${v}`)}
                  </option>
                ))}
              </select>
            </label>
            <label className="small">
              {t('dsgDuration', { ms: design.motion.durationMs })}
              <input
                type="range"
                min={0}
                max={DESIGN_LIMITS.entranceMaxMs}
                step={50}
                value={design.motion.durationMs}
                onChange={(e) => onChange({ ...design, motion: { ...design.motion, durationMs: Number(e.target.value) } })}
              />
            </label>
            <label className="check small">
              <input
                type="checkbox"
                checked={design.motion.shimmer}
                onChange={(e) => onChange({ ...design, motion: { ...design.motion, shimmer: e.target.checked } })}
              />
              {t('dsgShimmer')}
            </label>
            <label className="check small">
              <input
                type="checkbox"
                checked={design.motion.pulseFirst}
                onChange={(e) => onChange({ ...design, motion: { ...design.motion, pulseFirst: e.target.checked } })}
              />
              {t('dsgPulse')}
            </label>
            <label className="small">
              {t('dsgOverlaySpeed', { x: design.motion.overlaySpeed })}
              <input
                type="range"
                min={0.25}
                max={2}
                step={0.05}
                value={design.motion.overlaySpeed}
                onChange={(e) =>
                  onChange({ ...design, motion: { ...design.motion, overlaySpeed: Math.round(Number(e.target.value) * 100) / 100 } })
                }
              />
            </label>
            <label className="small">
              {t('dsgOverlayOpacity', { p: Math.round(design.motion.overlayOpacity * 100) })}
              <input
                type="range"
                min={0}
                max={1}
                step={0.05}
                value={design.motion.overlayOpacity}
                onChange={(e) =>
                  onChange({
                    ...design,
                    motion: { ...design.motion, overlayOpacity: Math.round(Number(e.target.value) * 100) / 100 },
                  })
                }
              />
            </label>
            <span className="hint">{t('dsgReduceMotionNote')}</span>
          </fieldset>
        </>
      )}
    </fieldset>
  );
}

/** Debounce for the preview's updates while typing. */
const PREVIEW_DEBOUNCE_MS = 250;
/** No «ready» from the bundle in this time: the sketch preview with a notice. */
export const PREVIEW_TIMEOUT_MS = 20_000;

/**
 * The real preview: the preview bundle in an iframe inside a phone frame, given the draft [event] (`EventDetail` JSON
 * for the chosen language, from `previewEvent`) by postMessage — only to its own origin, and only its replies are
 * read. [fallback] (the old sketch) shows when it does not load.
 */
export function EventLivePreview({
  eventFor,
  fallback,
}: {
  eventFor: (lang: 'ar' | 'en') => Record<string, unknown>;
  fallback: ReactNode;
}) {
  const { t, lang } = useApp();
  const [s, setS] = useState<PreviewSettings>({
    language: lang,
    theme: 'dark',
    state: 'RUNNING',
    device: 'phone',
    reduceMotion: false,
  });
  const [status, setStatus] = useState<'loading' | 'ready' | 'failed'>('loading');
  const [designed, setDesigned] = useState<boolean | null>(null);
  const [scale, setScale] = useState(1);
  const frame = useRef<HTMLIFrameElement>(null);
  const src = useMemo(
    () =>
      typeof location === 'undefined'
        ? new URL('/event-preview/', 'http://localhost')
        : previewUrl(import.meta.env.VITE_EVENT_PREVIEW_URL as string | undefined, location.origin),
    [],
  );
  const device = PREVIEW_DEVICES.find((d) => d.id === s.device)!;
  const event = eventFor(s.language);
  const message = JSON.stringify(event);

  useEffect(() => {
    const onMessage = (e: MessageEvent) => {
      const reply = previewReply(e, { origin: src.origin, window: frame.current?.contentWindow ?? null });
      if (!reply) return;
      if (reply.type === PREVIEW_READY) setStatus('ready');
      else if (reply.type === PREVIEW_RENDERED) setDesigned(reply.designed);
      else if (reply.type === PREVIEW_ERROR) setDesigned(null);
    };
    window.addEventListener('message', onMessage);
    const timer = window.setTimeout(() => setStatus((x) => (x === 'loading' ? 'failed' : x)), PREVIEW_TIMEOUT_MS);
    return () => {
      window.removeEventListener('message', onMessage);
      window.clearTimeout(timer);
    };
  }, [src]);

  // The draft goes to the preview a moment after the last change.
  useEffect(() => {
    if (status !== 'ready') return;
    const timer = window.setTimeout(() => {
      frame.current?.contentWindow?.postMessage(previewMessage(JSON.parse(message) as Record<string, unknown>, s), src.origin);
    }, PREVIEW_DEBOUNCE_MS);
    return () => window.clearTimeout(timer);
  }, [status, message, s, src]);

  // The phone fits the window's height.
  useEffect(() => {
    const fit = () => setScale(Math.min(1, Math.max(0.45, (window.innerHeight - 330) / (device.height + 24))));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, [device.height]);

  const set = <K extends keyof PreviewSettings>(k: K, v: PreviewSettings[K]) => setS((x) => ({ ...x, [k]: v }));
  return (
    <section
      className="dsg-preview"
      aria-label={t('dsgPreview')}
      data-testid="dsg-preview"
      data-preview-status={status}
      data-preview-designed={designed === null ? '' : String(designed)}
    >
      <h3>{t('dsgPreview')}</h3>
      <p className="hint">{t('dsgPreviewHint')}</p>
      <div className="dsg-preview-controls">
        <label className="small">
          {t('dsgPreviewLanguage')}
          <select value={s.language} onChange={(e) => set('language', e.target.value as 'ar' | 'en')}>
            <option value="ar">العربية</option>
            <option value="en">English</option>
          </select>
        </label>
        <label className="small">
          {t('dsgPreviewTheme')}
          <select value={s.theme} onChange={(e) => set('theme', e.target.value as 'dark' | 'light')}>
            <option value="dark">{t('dsgPreviewTheme_dark')}</option>
            <option value="light">{t('dsgPreviewTheme_light')}</option>
          </select>
        </label>
        <label className="small">
          {t('dsgPreviewState')}
          <select value={s.state} onChange={(e) => set('state', e.target.value as PreviewSettings['state'])}>
            {PREVIEW_STATES.map((v) => (
              <option key={v} value={v}>
                {t(`dsgPreviewState_${v}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="small">
          {t('dsgPreviewDevice')}
          <select value={s.device} onChange={(e) => set('device', e.target.value as PreviewSettings['device'])}>
            {PREVIEW_DEVICES.map((d) => (
              <option key={d.id} value={d.id}>
                {t(`dsgPreviewDevice_${d.id}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="check small">
          <input type="checkbox" checked={s.reduceMotion} onChange={(e) => set('reduceMotion', e.target.checked)} />
          {t('dsgPreviewReduceMotion')}
        </label>
      </div>
      {status === 'failed' ? (
        <div className="dsg-preview-fallback">
          <p className="alert warn" role="status">
            {t('dsgPreviewFailed')}
          </p>
          {fallback}
        </div>
      ) : (
        <>
          {status === 'loading' && <p className="muted small">{t('dsgPreviewLoading')}</p>}
          {designed === false && <p className="muted small">{t('dsgPreviewToday')}</p>}
          <div
            className="dsg-phone-slot"
            style={{ width: (device.width + 24) * scale, height: (device.height + 24) * scale }}
          >
            <div className="dsg-phone" dir="ltr" style={{ transform: `scale(${String(scale)})` }}>
              <iframe
                ref={frame}
                src={src.href}
                title={t('dsgPreviewFrame')}
                width={device.width}
                height={device.height}
                referrerPolicy="no-referrer"
              />
            </div>
          </div>
        </>
      )}
    </section>
  );
}
