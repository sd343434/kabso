import { useState } from 'react';
import { api, uploadEventMedia, type EventMediaUpload } from '../api';
import { Dialog, ErrorAlert } from '../components';
import { useApp } from '../context';
import {
  prizeTypesFor,
  specText,
  type BoardKind,
  type EventMediaSpec,
  type EventOptions,
  type GiftEventFormState,
  type PrizeItemForm,
  type PrizeType,
} from '../gift-events';

/**
 * D303 follow-ups (owner): one prize item of a line — the type (the board's money only: supporters coins, hosts and
 * creators cherries, agencies either, CP the two-amount line), its amount / item / tier / medal and level, and the
 * days or «دائم» (items and medals; VIP is days only).
 */
export function PrizeItemEditor({
  board,
  item,
  options,
  onChange,
  types,
  eventId,
  withDisplay = false,
}: {
  board: BoardKind;
  item: PrizeItemForm;
  options: EventOptions;
  onChange: (next: PrizeItemForm) => void;
  /** v1.101-social (D325): the types offered (default D303's for the board). */
  types?: PrizeType[];
  /** v1.101-social (D325): the event whose own gifts are offered as pieces. */
  eventId?: string;
  /** v1.101-social (D325): an upload of the prize's display picture. */
  withDisplay?: boolean;
}) {
  const { t, lang } = useApp();
  const name = (o: { nameAr: string; nameEn: string }) => (lang === 'ar' ? o.nameAr : o.nameEn);
  const set = (patch: Partial<PrizeItemForm>) => onChange({ ...item, ...patch });
  const timed = item.type === 'BAG_ITEM' || item.type === 'BADGE' || item.type === 'VIP';
  const [displayError, setDisplayError] = useState<unknown>(null);
  const codes =
    item.type === 'BAG_ITEM'
      ? options.bagItems.filter((b) => !b.eventId || b.eventId === eventId)
      : item.type === 'VIP'
        ? options.vipTiers
        : item.type === 'BADGE'
          ? (options.badges ?? [])
          : item.type === 'GIFT_PIECES'
            ? options.gifts.filter((g) => eventId !== undefined && g.eventId === eventId)
            : null;
  const levels = item.type === 'BADGE' ? ((options.badges ?? []).find((b) => b.code === item.code)?.levels ?? []) : [];
  return (
    <span className="gev-item" data-type={item.type}>
      <select
        aria-label={t('gevItemType')}
        value={item.type}
        onChange={(e) =>
          onChange({
            type: e.target.value as PrizeType,
            value: item.value || '1',
            code: '',
          })
        }
      >
        {(types ?? prizeTypesFor(board)).map((p) => (
          <option key={p} value={p}>
            {t(`gevItem_${p}`)}
          </option>
        ))}
      </select>
      {codes && (
        <select aria-label={t('gevItemCode')} value={item.code} onChange={(e) => set({ code: e.target.value })}>
          <option value="">—</option>
          {codes.map((o) => (
            <option key={o.code} value={o.code}>
              {name(o)}
            </option>
          ))}
        </select>
      )}
      {item.type === 'BADGE' && (
        <select
          aria-label={t('gevMedalLevel')}
          value={item.level ?? '1'}
          onChange={(e) => set({ level: e.target.value })}
        >
          {(levels.length > 0 ? levels.map((l) => l.level) : [1]).map((l) => (
            <option key={l} value={String(l)}>
              {t('gevMedalLevelN', { n: l })}
            </option>
          ))}
        </select>
      )}
      {item.type === 'CP_MONEY' ? (
        <>
          <input
            aria-label={t('gevCpCherries')}
            title={t('gevCpCherries')}
            type="number"
            min={0}
            value={item.cherries ?? '0'}
            onChange={(e) => set({ cherries: e.target.value })}
          />
          <input
            aria-label={t('gevCpCoins')}
            title={t('gevCpCoins')}
            type="number"
            min={0}
            value={item.coins ?? '0'}
            onChange={(e) => set({ coins: e.target.value })}
          />
        </>
      ) : (
        <input
          aria-label={timed ? t('gevDays') : item.type === 'GIFT_PIECES' ? t('evPieces') : t('gevAmount')}
          title={item.type === 'GIFT_PIECES' ? t('evPieces') : undefined}
          type="number"
          min={1}
          max={timed ? 365 : item.type === 'GIFT_PIECES' ? 100000 : undefined}
          disabled={item.permanent === true}
          value={item.value}
          onChange={(e) => set({ value: e.target.value })}
        />
      )}
      {withDisplay && (
        <label className="small gev-display" title={t('evDisplay')}>
          {item.displayKey ? <span className="badge ok">{t('evDisplaySet')}</span> : t('evDisplay')}
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp"
            aria-label={t('evDisplay')}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              setDisplayError(null);
              uploadEventMedia('prize', file).then(
                (up) => set({ displayKey: up.key ?? '', displayUrl: up.url ?? '' }),
                setDisplayError,
              );
            }}
          />
          {item.displayUrl && <img className="gev-display-thumb" src={item.displayUrl} alt="" />}
          <ErrorAlert error={displayError} />
        </label>
      )}
      {(item.type === 'BAG_ITEM' || item.type === 'BADGE') && (
        <label className="check small">
          <input
            type="checkbox"
            checked={item.permanent === true}
            onChange={(e) => set({ permanent: e.target.checked })}
          />
          {t('gevPermanent')}
        </label>
      )}
    </span>
  );
}

type ArtSlot = 'background' | 'backgroundPoster' | 'title' | 'overlay';

/**
 * D303 follow-ups (owner: «ضع القياسات والصيغة»): the page art of the event — each field shows its published spec
 * (`EventOptions.specs`, the same object the server enforces) and uploads to `POST /admin/event-uploads`; a refusal
 * shows the server's message. Then a preview of the page with that art.
 */
export function EventArtFields({
  f,
  options,
  urls,
  disabled,
  onKey,
  preview = true,
}: {
  f: GiftEventFormState;
  options: EventOptions;
  urls: Partial<Record<ArtSlot, string | null>>;
  disabled: boolean;
  /** D356: with the uploaded file (the design step measures the background's light for its contrast warning). */
  onKey: (slot: ArtSlot, key: string, url: string | null, file?: File) => void;
  /** D356: the sketch preview below the fields (the editor's design step shows the real preview instead). */
  preview?: boolean;
}) {
  const { t } = useApp();
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const spec = (kind: string) => options.specs?.find((s) => s.kind === kind);
  const field = (slot: ArtSlot, label: string, kinds: string[], accept: string) => (
    <div className="field" key={slot}>
      <label htmlFor={`gev-art-${slot}`}>{label}</label>
      <input
        id={`gev-art-${slot}`}
        type="file"
        accept={accept}
        disabled={disabled || busy !== null}
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          const video = /^video\//.test(file.type);
          const kind = slot === 'background' && video ? 'background_video' : kinds[0]!;
          setBusy(slot);
          setError(null);
          uploadEventMedia(kind, file).then(
            (up: EventMediaUpload) => {
              onKey(slot, up.key ?? '', up.url, file);
              setBusy(null);
            },
            (err: unknown) => {
              setError(err);
              setBusy(null);
            },
          );
        }}
      />
      {kinds.map((k) => {
        const s = spec(k);
        return s ? (
          <span key={k} className="hint ltr spec" data-spec={k}>
            {specText(s)}
            {s.safeZone ? ` — ${s.safeZone}` : ''}
          </span>
        ) : null;
      })}
      {(f[`${slot}Key` as keyof GiftEventFormState] as string | undefined) && (
        <span className="badge ok">{t('gevUploaded')}</span>
      )}
    </div>
  );
  return (
    <fieldset className="span-2 gev-art">
      <legend>{t('gevArt')}</legend>
      <ErrorAlert error={error} />
      {field(
        'background',
        t('gevArtBackground'),
        ['background', 'background_video'],
        'image/png,image/jpeg,image/webp,image/gif,video/mp4,video/quicktime',
      )}
      {/\.(mp4|mov)$/.test(f.backgroundKey ?? '') &&
        field('backgroundPoster', t('gevArtPoster'), ['background'], 'image/png,image/jpeg,image/webp')}
      {field('title', t('gevArtTitle'), ['title'], 'image/png,image/webp')}
      {field('overlay', t('gevArtOverlay'), ['overlay'], '.svga,application/json,.json')}
      {preview && <EventPagePreview f={f} urls={urls} />}
    </fieldset>
  );
}

/** D303 follow-up: the page as the app draws it, with the uploaded art (a sketch: background, title, gold cards). */
export function EventPagePreview({
  f,
  urls,
}: {
  f: GiftEventFormState;
  urls: Partial<Record<ArtSlot, string | null>>;
}) {
  const { t, lang } = useApp();
  const video = /\.(mp4|mov)$/.test(f.backgroundKey ?? '');
  const still = video ? urls.backgroundPoster : urls.background;
  return (
    <div className="gev-preview" aria-label={t('gevPreview')} dir={lang === 'ar' ? 'rtl' : 'ltr'}>
      <div className="gev-preview-page" style={still ? { backgroundImage: `url(${still})` } : undefined}>
        {video && urls.background && (
          <video
            className="gev-preview-video"
            src={urls.background}
            poster={still ?? undefined}
            muted
            loop
            autoPlay
            playsInline
          />
        )}
        <div className="gev-preview-title">
          {urls.title ? <img src={urls.title} alt="" /> : <strong>{lang === 'ar' ? f.titleAr : f.titleEn}</strong>}
        </div>
        {[t('gevGifts'), t('eventRulesAr'), t('gevBoards')].map((h) => (
          <div key={h} className="gev-preview-card">
            <span>{h}</span>
          </div>
        ))}
        {f.overlayKey && <span className="badge gev-preview-overlay">{t('gevArtOverlayOn')}</span>}
      </div>
      <span className="muted small">{t('gevPreview')}</span>
    </div>
  );
}

/** D303 follow-up: «وسام جديد» — a reusable event medal with one art per level (the `badge` spec). */
export function MedalDialog({
  spec,
  onClose,
  onDone,
}: {
  spec?: EventMediaSpec;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const [code, setCode] = useState('');
  const [nameAr, setNameAr] = useState('');
  const [nameEn, setNameEn] = useState('');
  const [reason, setReason] = useState('');
  const [levels, setLevels] = useState<{ level: number; imageKey: string }[]>([]);
  const [error, setError] = useState<unknown>(null);
  const ok =
    /^[a-z0-9_]{2,40}$/.test(code) && nameAr.trim() && nameEn.trim() && levels.length > 0 && reason.trim().length >= 3;
  return (
    <Dialog title={t('gevMedalNew')} onClose={onClose}>
      <ErrorAlert error={error} />
      <div className="form-grid">
        <div className="field">
          <label htmlFor="md-code">{t('gevMedalCode')}</label>
          <input id="md-code" dir="ltr" className="mono" value={code} onChange={(e) => setCode(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="md-ar">{t('eventTitleAr')}</label>
          <input id="md-ar" maxLength={40} value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="md-en">{t('eventTitleEn')}</label>
          <input id="md-en" dir="ltr" maxLength={40} value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
        </div>
        {[1, 2, 3].map((level) => (
          <div className="field" key={level}>
            <label htmlFor={`md-l${String(level)}`}>{t('gevMedalLevelN', { n: level })}</label>
            <input
              id={`md-l${String(level)}`}
              type="file"
              accept="image/png,image/webp"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                setError(null);
                uploadEventMedia('badge', file).then(
                  (up) => setLevels((x) => [...x.filter((l) => l.level !== level), { level, imageKey: up.key ?? '' }]),
                  setError,
                );
              }}
            />
            {spec && <span className="hint ltr spec">{specText(spec)}</span>}
          </div>
        ))}
        <div className="field span-2">
          <label htmlFor="md-reason">{t('reason')}</label>
          <textarea id="md-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
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
                .post('/admin/event-badges', {
                  code,
                  nameAr: nameAr.trim(),
                  nameEn: nameEn.trim(),
                  levels,
                  reason: reason.trim(),
                })
                .then(onDone, setError);
            }}
          >
            {t('gevMedalNew')}
          </button>
        </div>
      </div>
    </Dialog>
  );
}
