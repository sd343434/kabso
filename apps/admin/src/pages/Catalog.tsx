import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, FormDialog, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { Icon } from '../ui/icons';
import { BannerForm, placementLabelKey } from './BannerForm';
import { FileSlot, NO_FILE, previewUrl, type Alpha, type FileValue } from './GiftFiles';

export interface GiftDto {
  code: string;
  category: string;
  nameAr: string;
  nameEn: string;
  priceCoins: number;
  priceUsd: string;
  assetKey: string;
  animationKey: string | null;
  imageUrl: string | null;
  hostedAnimation: boolean;
  /** v1.71-social (D207): the uploaded files. */
  imageObjectKey: string | null;
  animationObjectKey: string | null;
  animationUrl: string | null;
  animationFormat: 'SVGA' | 'MP4' | null;
  animationAlpha: Alpha | null;
  animationBytes: number | null;
  audioObjectKey: string | null;
  audioUrl: string | null;
  audioMs: number | null;
  sortOrder: number;
  badge: string;
  lucky: boolean;
  tagCode: string | null;
  tagNameAr: string | null;
  tagNameEn: string | null;
  soundKey: string | null;
  soundMs: number | null;
  quipText: string | null;
  enabled: boolean;
  sends: number;
  coinsSpent: number;
}

/** v1.71-social (D207): a category as the gift list answers it (the form's choice and the tabs). */
export interface GiftCategoryChoice {
  code: string;
  kind: 'NORMAL' | 'LUCKY' | 'QUIPS';
  nameAr: string;
  nameEn: string;
  enabled: boolean;
}

export interface GiftListDto {
  coinRetailUsdPerMillion: number;
  categories: GiftCategoryChoice[];
  uploads: { storage: boolean; publicUrls: boolean };
  data: GiftDto[];
}

/** The form's files (D207). */
export interface GiftFilesState {
  image: FileValue;
  animation: FileValue;
  alpha: Alpha;
  sound: FileValue;
}

export function filesOf(gift: GiftDto | null): GiftFilesState {
  if (!gift) return { image: NO_FILE, animation: NO_FILE, alpha: 'NONE', sound: NO_FILE };
  return {
    image: { key: gift.imageObjectKey, url: previewUrl(gift.imageObjectKey) },
    animation: { key: gift.animationObjectKey, url: previewUrl(gift.animationObjectKey), format: gift.animationFormat ?? undefined },
    alpha: gift.animationAlpha ?? 'NONE',
    sound: { key: gift.audioObjectKey, url: previewUrl(gift.audioObjectKey), durationMs: gift.audioMs },
  };
}

/** The files' part of the body: on create what is set; on an edit only what changed (null: removed). */
export function filesBody(files: GiftFilesState, before: GiftDto | null): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  const was = filesOf(before);
  if (before === null) {
    if (files.image.key) out.imageObjectKey = files.image.key;
    if (files.animation.key) {
      out.animationObjectKey = files.animation.key;
      if (files.animation.key.endsWith('.mp4')) out.animationAlpha = files.alpha;
    }
    if (files.sound.key) out.audioObjectKey = files.sound.key;
    return out;
  }
  if (files.image.key !== was.image.key && files.image.key) out.imageObjectKey = files.image.key;
  const mp4 = files.animation.key?.endsWith('.mp4') ?? false;
  if (files.animation.key !== was.animation.key) {
    out.animationObjectKey = files.animation.key;
    if (mp4) out.animationAlpha = files.alpha;
  } else if (mp4 && files.alpha !== was.alpha) out.animationAlpha = files.alpha;
  if (files.sound.key !== was.sound.key) out.audioObjectKey = files.sound.key;
  return out;
}

const BADGES = ['NONE', 'NEW', 'EVENT'] as const;

/** The gift form's fields → the request body: only what changed on an edit, nulls for cleared optional fields. */
export function giftBody(form: Record<string, string>, before: GiftDto | null): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  const text = (k: string) => (form[k] ?? '').trim();
  const opt = (k: string) => (text(k) === '' ? null : text(k));
  const num = (k: string) => (text(k) === '' ? null : Number(text(k)));
  const fields: [string, unknown][] = [
    ['category', text('category')],
    ['nameAr', text('nameAr')],
    ['nameEn', text('nameEn')],
    ['priceCoins', Number(text('priceCoins'))],
    ['assetKey', text('assetKey') === '' && before === null ? null : text('assetKey')],
    ['animationKey', opt('animationKey')],
    ['sortOrder', Number(text('sortOrder') || '0')],
    ['badge', text('badge') || 'NONE'],
    ['tagCode', opt('tagCode')],
    ['tagNameAr', opt('tagNameAr')],
    ['tagNameEn', opt('tagNameEn')],
    ['soundKey', opt('soundKey')],
    ['soundMs', num('soundMs')],
    ['quipText', opt('quipText')],
  ];
  for (const [k, v] of fields) {
    if (before === null) {
      if (v !== null && v !== '') out[k] = v;
    } else if ((before as unknown as Record<string, unknown>)[k] !== v) out[k] = v;
  }
  return out;
}

function GiftForm({
  gift,
  categories,
  uploads,
  onClose,
  onDone,
}: {
  gift: GiftDto | null;
  categories: GiftCategoryChoice[];
  uploads: GiftListDto['uploads'] | undefined;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t, lang } = useApp();
  const [files, setFiles] = useState<GiftFilesState>(() => filesOf(gift));
  const [form, setForm] = useState<Record<string, string>>(() =>
    gift
      ? Object.fromEntries(Object.entries(gift).map(([k, v]) => [k, v === null || v === undefined ? '' : String(v)]))
      : { category: 'POPULAR', badge: 'NONE', sortOrder: '0' },
  );
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const set = (k: string) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }));
  const body = { ...giftBody(form, gift), ...filesBody(files, gift) };
  const code = gift?.code ?? (/^[a-z0-9][a-z0-9_]{0,39}$/.test((form.code ?? '').trim()) ? (form.code ?? '').trim() : '');
  const ok =
    reason.trim() !== '' &&
    (gift
      ? Object.keys(body).length > 0
      : !!code && !!form.nameAr && !!form.nameEn && !!files.image.key && form.priceCoins !== '');
  const input = (k: string, label: Parameters<typeof t>[0], props: Record<string, unknown> = {}) => (
    <div className="field">
      <label htmlFor={`gf-${k}`}>{t(label)}</label>
      <input id={`gf-${k}`} type="text" value={form[k] ?? ''} onChange={set(k)} {...props} />
    </div>
  );
  return (
    <Dialog title={gift ? t('giftEdit', { code: gift.code }) : t('giftCreate')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          const p = gift
            ? api.patch(`/admin/gifts/${gift.code}`, { ...body, reason: reason.trim() })
            : api.post('/admin/gifts', { code: (form.code ?? '').trim(), ...body, reason: reason.trim() });
          p.then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        {!gift && input('code', 'giftCode', { className: 'ltr mono', maxLength: 40, pattern: '[a-z0-9][a-z0-9_]*' })}
        <div className="field">
          <label htmlFor="gf-category">{t('colCategory')}</label>
          <select id="gf-category" value={form.category} onChange={set('category')}>
            {categories.map((c) => (
              <option key={c.code} value={c.code}>
                {lang === 'ar' ? c.nameAr : c.nameEn}
                {c.enabled ? '' : ` (${t('giftCategoryOff')})`}
              </option>
            ))}
          </select>
        </div>
        {input('nameAr', 'giftNameAr', { maxLength: 60, dir: 'rtl' })}
        {input('nameEn', 'giftNameEn', { maxLength: 60, dir: 'ltr' })}
        {input('priceCoins', 'giftPrice', { type: 'number', min: 0, max: 1000000, className: 'num' })}
        <div className="field">
          <label htmlFor="gf-badge">{t('giftBadge')}</label>
          <select id="gf-badge" value={form.badge} onChange={set('badge')}>
            {BADGES.map((b) => (
              <option key={b} value={b}>
                {t(`giftBadge${b}` as never)}
              </option>
            ))}
          </select>
        </div>
        {input('assetKey', 'giftAssetKey', { className: 'ltr mono', maxLength: 80 })}
        {input('animationKey', 'giftAnimationKey', { className: 'ltr mono', maxLength: 80 })}
        {input('sortOrder', 'giftSort', { type: 'number' })}
        {input('tagCode', 'giftTagCode', { className: 'ltr mono', maxLength: 40 })}
        {input('tagNameAr', 'giftTagNameAr', { maxLength: 30 })}
        {input('tagNameEn', 'giftTagNameEn', { maxLength: 30, dir: 'ltr' })}
        {form.category === 'QUIPS' && (
          <>
            {input('soundKey', 'giftSoundKey', { className: 'ltr mono', maxLength: 80 })}
            {input('soundMs', 'giftSoundMs', { type: 'number', min: 200, max: 15000 })}
            {input('quipText', 'giftQuipText', { maxLength: 200 })}
          </>
        )}
        <fieldset className="span-2 form-grid file-group">
          <legend>{t('giftFiles')}</legend>
          {uploads && !uploads.storage && <p className="alert warn span-2">{t('giftStorageOff')}</p>}
          {uploads && uploads.storage && !uploads.publicUrls && <p className="alert warn span-2">{t('giftPublicOff')}</p>}
          <FileSlot
            kind="image"
            code={code}
            label={t('giftImage')}
            hint={t('giftImageHint')}
            value={files.image}
            removable={!gift}
            onChange={(image) => setFiles((f) => ({ ...f, image }))}
          />
          <FileSlot
            kind="animation"
            code={code}
            label={t('giftDisplayFile')}
            hint={t('giftDisplayHint')}
            value={files.animation}
            alpha={files.alpha}
            onAlpha={(alpha) => setFiles((f) => ({ ...f, alpha }))}
            onChange={(animation) => setFiles((f) => ({ ...f, animation }))}
          />
          {form.category !== 'QUIPS' && (
            <FileSlot
              kind="sound"
              code={code}
              label={t('giftSoundFile')}
              hint={t('giftSoundHint')}
              value={files.sound}
              onChange={(sound) => setFiles((f) => ({ ...f, sound }))}
            />
          )}
        </fieldset>
        <div className="field span-2">
          <label htmlFor="gf-reason">{t('reason')}</label>
          <textarea id="gf-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t('giftArtHint')}</span>
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {gift ? t('save') : t('giftCreate')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** «الهدايا» (D197): the catalogue as cards — price in coins and USD, category (LUCKY), badge, use — with CRUD. */
export function Gifts() {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<GiftListDto>('/admin/gifts'), []);
  const [cat, setCat] = useState<string>('');
  const [edit, setEdit] = useState<GiftDto | 'new' | null>(null);
  const [toggle, setToggle] = useState<GiftDto | null>(null);
  const shown = data?.data.filter((g) => !cat || g.category === cat) ?? [];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('giftsTitle')}</h1>
          <p className="muted small">{data ? t('giftsSubtitle', { n: formatNumber(data.data.length, lang), usd: String(data.coinRetailUsdPerMillion) }) : ''}</p>
        </div>
        {can('catalog.manage') && (
          <button className="btn primary" onClick={() => setEdit('new')}>
            <Icon name="plus" size={16} />
            {t('giftCreate')}
          </button>
        )}
      </div>
      <div className="tabs">
        <button className="tab" aria-pressed={cat === ''} onClick={() => setCat('')}>
          {t('all')}
        </button>
        {(data?.categories ?? []).map((c) => (
          <button key={c.code} className="tab" aria-pressed={cat === c.code} onClick={() => setCat(c.code)}>
            {lang === 'ar' ? c.nameAr : c.nameEn}
            {c.enabled ? '' : ` · ${t('giftCategoryOff')}`}
          </button>
        ))}
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <div className="gift-grid">{Array.from({ length: 8 }, (_, i) => <div key={i} className="gift-card skeleton-card" />)}</div>}
      {data && shown.length === 0 && (
        <div className="card state empty-state">
          <Icon name="gift" size={32} />
          <p>{t('giftsNone')}</p>
        </div>
      )}
      <div className="gift-grid">
        {shown.map((g) => (
          <div key={g.code} className={`gift-card${g.enabled ? '' : ' off'}`}>
            <div className="gift-art">
              {/* D207: from the panel's own origin (the CDN may not be reachable from here). */}
              {g.imageObjectKey || g.imageUrl ? (
                <img src={previewUrl(g.imageObjectKey) ?? g.imageUrl ?? ''} alt="" loading="lazy" />
              ) : (
                <Icon name="gift" size={36} />
              )}
              {g.badge !== 'NONE' && <span className="badge warn corner">{t(`giftBadge${g.badge}` as never)}</span>}
              {g.lucky && <span className="badge info corner2">{t('giftCatLUCKY')}</span>}
              {g.animationFormat && <span className="badge corner3 ltr">{g.animationFormat}{g.animationAlpha === 'SIDE_BY_SIDE' ? ' α' : ''}</span>}
              {g.audioObjectKey && <span className="badge corner4 ltr">MP3</span>}
            </div>
            <div className="gift-name">{lang === 'ar' ? g.nameAr : g.nameEn}</div>
            <div className="mono small muted">{g.code}</div>
            <div className="gift-price">
              <Icon name="coins" size={14} />
              <strong className="num">{formatNumber(g.priceCoins, lang)}</strong>
              <span className="muted small ltr">${g.priceUsd}</span>
            </div>
            <div className="muted small">{t('giftUse', { n: formatNumber(g.sends, lang) })}</div>
            {can('catalog.manage') && (
              <div className="row gift-actions">
                <button className="btn small" onClick={() => setEdit(g)}>
                  {t('edit')}
                </button>
                <button className={`btn small ${g.enabled ? '' : 'primary'}`} onClick={() => setToggle(g)}>
                  {g.enabled ? t('disable') : t('enable')}
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
      {edit && (
        <GiftForm
          gift={edit === 'new' ? null : edit}
          categories={data?.categories ?? []}
          uploads={data?.uploads}
          onClose={() => setEdit(null)}
          onDone={() => {
            setEdit(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
      {toggle && (
        <FormDialog
          title={`${toggle.enabled ? t('disable') : t('enable')} · ${toggle.code}`}
          fields={[reasonField(t)]}
          confirmLabel={toggle.enabled ? t('disable') : t('enable')}
          danger={toggle.enabled}
          submit={(v) => api.post(`/admin/gifts/${toggle.code}/${toggle.enabled ? 'disable' : 'enable'}`, { reason: v.reason })}
          onClose={() => setToggle(null)}
          onDone={() => {
            setToggle(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}

/** «العناصر» (D197): frames and profile cards and how many hold each; giving one is on the user's page. */
export function Items() {
  const { t, lang } = useApp();
  const { data, error } = useAsync(
    () => api.get<{ data: { code: string; category: string; nameAr: string; nameEn: string; assetKey: string; free: boolean; automatic: boolean; holders: number }[] }>('/admin/bag-items'),
    [],
  );
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('itemsTitle')}</h1>
          <p className="muted small">{t('itemsSubtitle')}</p>
        </div>
      </div>
      <ErrorAlert error={error} />
      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('bagItem')}</th>
                <th>{t('colType')}</th>
                <th>{t('giftAssetKey')}</th>
                <th>{t('itemsKind')}</th>
                <th className="num">{t('itemsHolders')}</th>
              </tr>
            </thead>
            <tbody>
              {data?.data.map((i) => (
                <tr key={i.code}>
                  <td>
                    {lang === 'ar' ? i.nameAr : i.nameEn} <span className="mono small muted">{i.code}</span>
                  </td>
                  <td>{i.category === 'AVATAR_FRAME' ? t('catFrame') : t('catCard')}</td>
                  <td className="mono small ltr">{i.assetKey}</td>
                  <td>{i.automatic ? <span className="badge info">{t('itemsAutomatic')}</span> : i.free ? <span className="badge">{t('itemsFree')}</span> : t('itemsGrantable')}</td>
                  <td className="num">{formatNumber(i.holders, lang)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {data && data.data.length === 0 && <p className="muted state">{t('empty')}</p>}
        </div>
        <p className="muted small">{t('itemsBadgesNote')}</p>
      </div>
    </>
  );
}

interface BannerDto {
  id: string;
  placement: string;
  titleAr: string | null;
  titleEn: string | null;
  link: string;
  startsAt: string;
  endsAt: string | null;
  sortOrder: number;
  enabled: boolean;
  showing: boolean;
  imageUrl: string | null;
}

interface EventDto {
  id: string;
  titleAr: string;
  titleEn: string;
  metric: string;
  audience: string;
  startsAt: string;
  endsAt: string | null;
  permanent: boolean;
  featured: boolean;
  regions: string[];
  prizes: number;
  tone: string | null;
  state: string;
  payoutHold: boolean;
}

const METRICS = ['GIFT_COINS_RECEIVED', 'GIFT_COINS_SENT', 'LIVE_MINUTES', 'TAPS_RECEIVED', 'NEW_FOLLOWERS'] as const;

/** Local `datetime-local` text → an ISO time with the browser's offset. */
export function localToIso(value: string): string {
  return new Date(value).toISOString();
}

function EventForm({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [f, setF] = useState<Record<string, string>>({ metric: 'GIFT_COINS_RECEIVED', audience: 'EVERYONE' });
  const [permanent, setPermanent] = useState(false);
  const [featured, setFeatured] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const set = (k: string) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const ok = !!f.titleAr?.trim() && !!f.titleEn?.trim() && !!f.startsAt && (permanent || !!f.endsAt) && !!f.reason?.trim();
  return (
    <Dialog title={t('eventCreate')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          api
            .post('/admin/events', {
              titleAr: f.titleAr!.trim(),
              titleEn: f.titleEn!.trim(),
              ...(f.rulesAr?.trim() ? { rulesAr: f.rulesAr.trim() } : {}),
              ...(f.rulesEn?.trim() ? { rulesEn: f.rulesEn.trim() } : {}),
              startsAt: localToIso(f.startsAt!),
              ...(permanent ? { permanent: true } : { endsAt: localToIso(f.endsAt!) }),
              metric: f.metric,
              audience: f.audience,
              featured,
              ...(f.prizes?.trim() ? { prizes: f.prizes.trim() } : {}),
              reason: f.reason!.trim(),
            })
            .then(onDone, (err: unknown) => {
              setError(err);
              setBusy(false);
            });
        }}
      >
        <div className="field">
          <label htmlFor="ev-ar">{t('eventTitleAr')}</label>
          <input id="ev-ar" type="text" maxLength={120} value={f.titleAr ?? ''} onChange={set('titleAr')} />
        </div>
        <div className="field">
          <label htmlFor="ev-en">{t('eventTitleEn')}</label>
          <input id="ev-en" type="text" dir="ltr" maxLength={120} value={f.titleEn ?? ''} onChange={set('titleEn')} />
        </div>
        <div className="field">
          <label htmlFor="ev-start">{t('eventStarts')}</label>
          <input id="ev-start" type="datetime-local" value={f.startsAt ?? ''} onChange={set('startsAt')} />
        </div>
        <div className="field">
          <label htmlFor="ev-end">{t('eventEnds')}</label>
          <input id="ev-end" type="datetime-local" disabled={permanent} value={f.endsAt ?? ''} onChange={set('endsAt')} />
        </div>
        <label className="check field">
          <input type="checkbox" checked={permanent} onChange={(e) => setPermanent(e.target.checked)} />
          {t('eventPermanent')}
        </label>
        <label className="check field">
          <input type="checkbox" checked={featured} onChange={(e) => setFeatured(e.target.checked)} />
          {t('eventFeatured')}
        </label>
        <div className="field">
          <label htmlFor="ev-metric">{t('eventMetric')}</label>
          <select id="ev-metric" value={f.metric} onChange={set('metric')}>
            {METRICS.map((m) => (
              <option key={m} value={m}>
                {t(`metric${m}` as never)}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="ev-aud">{t('eventAudience')}</label>
          <select id="ev-aud" value={f.audience} onChange={set('audience')}>
            <option value="EVERYONE">{t('audienceEVERYONE')}</option>
            <option value="HOSTS">{t('audienceHOSTS')}</option>
          </select>
        </div>
        <div className="field span-2">
          <label htmlFor="ev-prizes">{t('eventPrizes')}</label>
          <input id="ev-prizes" type="text" className="ltr mono" placeholder="1:5000,2:3000,3-10:500" value={f.prizes ?? ''} onChange={set('prizes')} />
        </div>
        <div className="field">
          <label htmlFor="ev-rar">{t('eventRulesAr')}</label>
          <textarea id="ev-rar" maxLength={4000} value={f.rulesAr ?? ''} onChange={set('rulesAr')} />
        </div>
        <div className="field">
          <label htmlFor="ev-ren">{t('eventRulesEn')}</label>
          <textarea id="ev-ren" dir="ltr" maxLength={4000} value={f.rulesEn ?? ''} onChange={set('rulesEn')} />
        </div>
        <div className="field span-2">
          <label htmlFor="ev-reason">{t('reason')}</label>
          <textarea id="ev-reason" maxLength={500} value={f.reason ?? ''} onChange={set('reason')} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {t('eventCreate')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** «البانرات والفعاليات» (D197): banners on / off / removed; Event Center events created, ended, held, released. */
export function Promo() {
  const { t, lang, can, toast } = useApp();
  const banners = useAsync(() => api.get<{ data: BannerDto[] }>('/admin/banners'), []);
  const events = useAsync(() => api.get<{ data: EventDto[] }>('/admin/events'), []);
  const [act, setAct] = useState<{ path: string; label: string; danger?: boolean; reload: () => void } | null>(null);
  const [creating, setCreating] = useState(false);
  const [addingBanner, setAddingBanner] = useState(false);
  const manage = can('catalog.manage');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('promoTitle')}</h1>
          <p className="muted small">{t('promoSubtitle')}</p>
        </div>
      </div>
      <section className="card">
        <div className="card-head">
          <h2>{t('bannersTitle')}</h2>
          <span className="muted small">{t('bannersNote')}</span>
          {manage && (
            <button className="btn primary small" onClick={() => setAddingBanner(true)}>
              <Icon name="plus" size={16} />
              {t('bannerCreate')}
            </button>
          )}
        </div>
        <ErrorAlert error={banners.error} />
        {banners.data && banners.data.data.length === 0 && <p className="muted">{t('bannersNone')}</p>}
        <div className="banner-grid">
          {banners.data?.data.map((b) => (
            <div key={b.id} className={`banner-card${b.enabled ? '' : ' off'}`}>
              <div className="banner-art" data-placement={b.placement.toLowerCase()}>
                {b.imageUrl ? <img src={b.imageUrl} alt="" loading="lazy" /> : <Icon name="frame" size={28} />}
              </div>
              <div className="pad">
                <div className="row small">
                  <span className="badge">{placementLabelKey(b.placement) ? t(placementLabelKey(b.placement)!) : b.placement}</span>
                  {b.showing ? <span className="badge ok">{t('bannerShowing')}</span> : <span className="badge">{b.enabled ? t('bannerScheduled') : t('bannerOff')}</span>}
                </div>
                <div className="clip">{(lang === 'ar' ? b.titleAr : b.titleEn) ?? b.link}</div>
                <div className="muted small ltr clip">{b.link}</div>
                <div className="muted small date">
                  {formatDate(b.startsAt, lang)} → {b.endsAt ? formatDate(b.endsAt, lang) : '∞'}
                </div>
                {manage && (
                  <div className="row">
                    <button
                      className="btn small"
                      onClick={() =>
                        setAct({ path: `/admin/banners/${b.id}/${b.enabled ? 'disable' : 'enable'}`, label: b.enabled ? t('disable') : t('enable'), reload: banners.reload })
                      }
                    >
                      {b.enabled ? t('disable') : t('enable')}
                    </button>
                    <button className="btn small danger" onClick={() => setAct({ path: `/admin/banners/${b.id}/remove`, label: t('remove'), danger: true, reload: banners.reload })}>
                      {t('remove')}
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </section>
      <section className="card" style={{ marginTop: 16 }}>
        <div className="card-head">
          <h2>{t('eventsTitle')}</h2>
          {manage && (
            <button className="btn primary small" onClick={() => setCreating(true)}>
              <Icon name="plus" size={16} />
              {t('eventCreate')}
            </button>
          )}
        </div>
        <ErrorAlert error={events.error} />
        {events.data && events.data.data.length === 0 && <p className="muted">{t('eventsNone')}</p>}
        {events.data && events.data.data.length > 0 && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>{t('colTitle')}</th>
                  <th>{t('eventMetric')}</th>
                  <th>{t('colStatus')}</th>
                  <th>{t('eventStarts')}</th>
                  <th>{t('eventEnds')}</th>
                  <th className="num">{t('eventPrizesCount')}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {events.data.data.map((e) => (
                  <tr key={e.id}>
                    <td>
                      {lang === 'ar' ? e.titleAr : e.titleEn} {e.featured && <span className="badge warn">{t('eventFeatured')}</span>}
                    </td>
                    <td className="small">{t(`metric${e.metric}` as never)}</td>
                    <td>
                      <span className={`badge ${e.state === 'RUNNING' ? 'ok' : e.state === 'HELD' ? 'warn' : ''}`}>{t(`evState${e.state}` as never)}</span>
                    </td>
                    <td className="date small">{formatDate(e.startsAt, lang)}</td>
                    <td className="date small">{e.permanent ? '∞' : formatDate(e.endsAt, lang)}</td>
                    <td className="num">{formatNumber(e.prizes, lang)}</td>
                    <td>
                      {manage && (
                        <span className="row">
                          {e.state === 'RUNNING' && (
                            <button className="btn small danger" onClick={() => setAct({ path: `/admin/events/${e.id}/end`, label: t('eventEnd'), danger: true, reload: events.reload })}>
                              {t('eventEnd')}
                            </button>
                          )}
                          {e.state !== 'PAID' && !e.payoutHold && e.state !== 'RUNNING' && e.state !== 'UPCOMING' && (
                            <button className="btn small" onClick={() => setAct({ path: `/admin/events/${e.id}/hold`, label: t('eventHold'), reload: events.reload })}>
                              {t('eventHold')}
                            </button>
                          )}
                          {e.payoutHold && e.state !== 'PAID' && (
                            <button className="btn small" onClick={() => setAct({ path: `/admin/events/${e.id}/release`, label: t('eventRelease'), reload: events.reload })}>
                              {t('eventRelease')}
                            </button>
                          )}
                        </span>
                      )}
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
          title={act.label}
          fields={[reasonField(t)]}
          confirmLabel={act.label}
          danger={act.danger}
          submit={(v) => api.post(act.path, { reason: v.reason })}
          onClose={() => setAct(null)}
          onDone={() => {
            act.reload();
            setAct(null);
            toast(t('done'));
          }}
        />
      )}
      {addingBanner && (
        <BannerForm
          onClose={() => setAddingBanner(false)}
          onDone={() => {
            setAddingBanner(false);
            toast(t('bannerCreated'));
            banners.reload();
          }}
        />
      )}
      {creating && (
        <EventForm
          onClose={() => setCreating(false)}
          onDone={() => {
            setCreating(false);
            toast(t('done'));
            events.reload();
          }}
        />
      )}
    </>
  );
}
