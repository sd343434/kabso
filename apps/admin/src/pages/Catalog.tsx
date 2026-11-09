import { useRef, useState } from 'react';
import { api } from '../api';
import {
  applyDetection,
  badgeProblems,
  badgesPart,
  badgeState,
  seasonalWithoutEnd,
  type AdminItemBadge,
  type BadgeState,
  type ItemBadgeCode,
} from '../badges';
import { Dialog, ErrorAlert, FormDialog, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { Icon } from '../ui/icons';
import { BadgeChip, BadgePicker, SeasonalNoEndHint, SeasonalNoEndNote } from './BadgePicker';
import { BannerForm, placementLabelKey } from './BannerForm';
import { FileSlot, NO_FILE, previewUrl, type Alpha, type FileValue } from './GiftFiles';

/**
 * v1.91-live (D323, owner: «تاج الافتتاح» at 3 000 000 coins): a gift's price is 0 … 100 000 000 coins (0: a free
 * quip), as the server (`gifts_price_range`) — was 1 000 000.
 */
export const GIFT_PRICE_MAX = 100_000_000;

/** The «السعر بالعملات» input's attributes (the browser's own check uses `max`). */
export const giftPriceInputProps = { type: 'number', min: 0, max: GIFT_PRICE_MAX, step: 1, className: 'num' } as const;

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
  /** Deprecated v1.79-live (D289): the single value, kept in step by the server. */
  badge: string;
  /** v1.79-live (D289): every stored badge, its end and whether it still shows. */
  badges: AdminItemBadge[];
  lucky: boolean;
  tagCode: string | null;
  tagNameAr: string | null;
  tagNameEn: string | null;
  soundKey: string | null;
  soundMs: number | null;
  quipText: string | null;
  /** v1.100-social (D312): «صاحب الهدية» of a CUSTOM gift and their status now; null otherwise. */
  owner?: GiftOwnerDto | null;
  enabled: boolean;
  sends: number;
  coinsSpent: number;
  /** v1.103-social (D338, §10.131): set while archived («المحذوفة», always off). */
  archivedAt: string | null;
  /** v1.103-social (D338): something points at it, so «حذف» archives it (else deletes it for real). */
  inUse: boolean;
  /** v1.103-social (D338): people holding pieces of it now. */
  holders: number;
  /** v1.103-social (D338): the pieces in bags now (an archived gift's are sent until they run out). */
  pieces: number;
}

/**
 * v1.103-social (D338): what «حذف» will do — `delete` (nothing ever used it: gone for good) or `archive` (kept for
 * history, hidden everywhere). The server decides again on the same rule.
 */
export function giftDeleteCase(gift: Pick<GiftDto, 'inUse'>): 'delete' | 'archive' {
  return gift.inUse ? 'archive' : 'delete';
}

/** « (sent N times)» — empty when only other records name it (pieces in bags have their own sentence). */
function archiveDetails(gift: GiftDto, t: ReturnType<typeof useApp>['t'], lang: 'ar' | 'en'): string {
  const parts = gift.sends > 0 ? [t('giftDeleteSends', { n: formatNumber(gift.sends, lang) })] : [];
  return parts.length === 0 ? '' : ` (${parts.join(lang === 'ar' ? '، ' : ', ')})`;
}

/** The confirm dialog's sentence for [gift] (D338). */
export function GiftDeleteIntro({ gift }: { gift: GiftDto }) {
  const { t, lang } = useApp();
  const which = giftDeleteCase(gift);
  return (
    <p className={`alert ${which === 'delete' ? 'error' : 'warn'}`} data-gift-delete-case={which}>
      {which === 'delete'
        ? t('giftDeleteForever')
        : gift.pieces > 0
          ? t('giftDeletePieces', { pieces: formatNumber(gift.pieces, lang), holders: formatNumber(gift.holders, lang) })
          : t('giftDeleteArchive', { details: archiveDetails(gift, t, lang) })}
    </p>
  );
}

/** D338: the gifts a list shows — the normal list without the archived ones, the «المحذوفة» filter only those. */
export function giftsShown(
  gifts: readonly GiftDto[],
  { cat, noEndOnly, archivedOnly }: { cat: string; noEndOnly: boolean; archivedOnly: boolean },
): GiftDto[] {
  return gifts.filter(
    (g) =>
      (g.archivedAt !== null) === archivedOnly &&
      (!cat || g.category === cat) &&
      (!noEndOnly || seasonalWithoutEnd(g.badges)),
  );
}

/** v1.100-social (D312, §10.118): the owner of a custom gift as the panel lists it. */
export interface GiftOwnerDto {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: 'ACTIVE' | 'SUSPENDED' | 'PENDING_DELETION' | 'DELETED';
}

/** v1.71-social (D207): a category as the gift list answers it (the form's choice and the tabs). */
export interface GiftCategoryChoice {
  code: string;
  kind: 'NORMAL' | 'LUCKY' | 'QUIPS' | 'CUSTOM';
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

/** v1.79-live (D289): what the form's files show, for the pre-selection. */
export function detectFromFiles(files: GiftFilesState): { hasEffect: boolean; hasAudio: boolean; fullscreen?: boolean } {
  const info = files.animation.info;
  return {
    hasEffect: !!files.animation.key,
    hasAudio: !!files.sound.key || !!info?.hasAudio,
    ...(info?.fullscreen !== undefined ? { fullscreen: info.fullscreen } : {}),
  };
}

/** The badges a detection turned on (for the «اختير تلقائياً» note). */
export function autoOn(state: BadgeState): ItemBadgeCode[] {
  return (Object.keys(state) as ItemBadgeCode[]).filter((c) => state[c].auto && state[c].on);
}

/** v1.100-social (D312): whether `category` is the special CUSTOM «مُخصَّص» one (the form then asks for the owner). */
export function isCustomCategory(category: string, categories: readonly GiftCategoryChoice[]): boolean {
  return categories.find((c) => c.code === category)?.kind === 'CUSTOM';
}

/** A typed Kabso ID as the server reads it: trimmed, without a leading @, lower-case ('' when empty). */
export function ownerHandle(text: string): string {
  return text.trim().replace(/^@/, '').toLowerCase();
}

/**
 * v1.100-social (D312): the owner part of the body — on create the handle of a CUSTOM gift; on an edit only a changed
 * handle (moving a gift out of «مُخصَّص» drops the owner on the server, so nothing is sent then).
 */
export function ownerPart(
  ownerText: string,
  custom: boolean,
  before: GiftDto | null,
): { owner?: string } {
  const handle = ownerHandle(ownerText);
  if (!custom || handle === '') return {};
  if (before === null) return { owner: handle };
  return before.owner?.username === handle ? {} : { owner: handle };
}

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

export function GiftForm({
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
  const [badges, setBadges] = useState<BadgeState>(() => badgeState(gift?.badges ?? []));
  const now = new Date();
  /** A new file: what it shows is pre-selected (marked «تلقائي»); the owner can change it. */
  const onFiles = (patch: Partial<GiftFilesState>, fresh: boolean) => {
    setFiles((f) => ({ ...f, ...patch }));
    if (fresh) setBadges((b) => applyDetection(b, detectFromFiles({ ...files, ...patch })));
  };
  const [form, setForm] = useState<Record<string, string>>(() =>
    gift
      ? Object.fromEntries(Object.entries(gift).map(([k, v]) => [k, v === null || v === undefined ? '' : String(v)]))
      : { category: 'POPULAR', sortOrder: '0' },
  );
  const [ownerText, setOwnerText] = useState(gift?.owner?.username ?? '');
  const custom = isCustomCategory(form.category ?? '', categories);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const set = (k: string) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }));
  const body = {
    ...giftBody(form, gift),
    ...filesBody(files, gift),
    ...badgesPart(badges, gift),
    ...ownerPart(ownerText, custom, gift),
  };
  // D312: a CUSTOM gift always has its owner (a gift moved into «مُخصَّص» needs one too).
  const ownerOk = !custom || ownerHandle(ownerText) !== '';
  const badgesOk = badgeProblems(badges, now).length === 0;
  const code = gift?.code ?? (/^[a-z0-9][a-z0-9_]{0,39}$/.test((form.code ?? '').trim()) ? (form.code ?? '').trim() : '');
  const ok =
    badgesOk &&
    ownerOk &&
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
        {custom && (
          <div className="field span-2" data-gift-owner-field>
            <label htmlFor="gf-owner">{t('giftOwner')}</label>
            <input
              id="gf-owner"
              type="text"
              className="ltr mono"
              maxLength={31}
              placeholder="@username"
              value={ownerText}
              onChange={(e) => setOwnerText(e.target.value)}
              aria-invalid={!ownerOk}
            />
            <span className="hint">{ownerOk ? t('giftOwnerHint') : t('giftOwnerRequired')}</span>
          </div>
        )}
        {input('nameAr', 'giftNameAr', { maxLength: 60, dir: 'rtl' })}
        {input('nameEn', 'giftNameEn', { maxLength: 60, dir: 'ltr' })}
        {input('priceCoins', 'giftPrice', { ...giftPriceInputProps })}
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
            onChange={(animation) => onFiles({ animation }, !!animation.info)}
          />
          {form.category !== 'QUIPS' && (
            <FileSlot
              kind="sound"
              code={code}
              label={t('giftSoundFile')}
              hint={t('giftSoundHint')}
              value={files.sound}
              onChange={(sound) => onFiles({ sound }, !!sound.info)}
            />
          )}
        </fieldset>
        <BadgePicker value={badges} onChange={setBadges} now={now} detected={autoOn(badges)} />
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

/** v1.100-social (D312): «صاحب الهدية» on a custom gift's card (a warning when the account is not ACTIVE). */
export function GiftOwnerChip({ owner }: { owner: GiftOwnerDto }) {
  const { t } = useApp();
  return (
    <div className="small gift-owner" data-gift-owner={owner.username}>
      {/* The string isolates «@name» (FSI … PDI) so it reads left-to-right inside Arabic text. */}
      <span className="badge info">{t('giftOwnerBy', { username: owner.username })}</span>
      {owner.status !== 'ACTIVE' && <span className="badge warn">{t('giftOwnerInactive')}</span>}
    </div>
  );
}

/** «الهدايا» (D197): the catalogue as cards — price in coins and USD, category (LUCKY), badge, use — with CRUD. */
export function Gifts() {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<GiftListDto>('/admin/gifts'), []);
  const [cat, setCat] = useState<string>('');
  const [edit, setEdit] = useState<GiftDto | 'new' | null>(null);
  const [toggle, setToggle] = useState<GiftDto | null>(null);
  // D338: «حذف» (delete or archive), «استعادة», and the «المحذوفة» filter.
  const [del, setDel] = useState<GiftDto | null>(null);
  const [back, setBack] = useState<GiftDto | null>(null);
  const [archivedOnly, setArchivedOnly] = useState(false);
  const lastDelete = useRef<'DELETED' | 'ARCHIVED'>('ARCHIVED');
  // D289 (owner Q2): the gifts whose «موسمي» has no end yet, and the filter to show only them.
  const [noEndOnly, setNoEndOnly] = useState(false);
  const live = data?.data.filter((g) => g.archivedAt === null) ?? [];
  const archivedCount = (data?.data.length ?? 0) - live.length;
  const noEnd = live.filter((g) => seasonalWithoutEnd(g.badges)).length;
  const shown = giftsShown(data?.data ?? [], { cat, noEndOnly: noEndOnly && !archivedOnly, archivedOnly });
  const done = (message: string) => {
    toast(message);
    reload();
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('giftsTitle')}</h1>
          <p className="muted small">{data ? t('giftsSubtitle', { n: formatNumber(live.length, lang), usd: String(data.coinRetailUsdPerMillion) }) : ''}</p>
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
      <div className="row" style={{ justifyContent: 'flex-end' }}>
        <button
          type="button"
          aria-pressed={archivedOnly}
          className={`btn small ${archivedOnly ? 'primary' : ''}`}
          onClick={() => setArchivedOnly((a) => !a)}
          data-gift-archived-filter={archivedOnly ? 'on' : 'off'}
        >
          <Icon name="filter" size={14} />
          {t('giftArchivedFilter', { n: formatNumber(archivedCount, lang) })}
        </button>
      </div>
      <ErrorAlert error={error} />
      {archivedOnly ? (
        <p className="muted small" data-gift-archived-note>
          {t('giftArchivedNote')}
        </p>
      ) : (
        <SeasonalNoEndNote count={noEnd} only={noEndOnly} onOnly={setNoEndOnly} />
      )}
      {loading && !data && <div className="gift-grid">{Array.from({ length: 8 }, (_, i) => <div key={i} className="gift-card skeleton-card" />)}</div>}
      {data && shown.length === 0 && (
        <div className="card state empty-state">
          <Icon name="gift" size={32} />
          <p>{t('giftsNone')}</p>
        </div>
      )}
      <div className="gift-grid">
        {shown.map((g) => (
          <div key={g.code} className={`gift-card${g.enabled ? '' : ' off'}`} data-gift-card={g.code}>
            <div className="gift-art">
              {/* D207: from the panel's own origin (the CDN may not be reachable from here). */}
              {g.imageObjectKey || g.imageUrl ? (
                <img src={previewUrl(g.imageObjectKey) ?? g.imageUrl ?? ''} alt="" loading="lazy" />
              ) : (
                <Icon name="gift" size={36} />
              )}
              {/* D289: the running badges as icons (all of them, the panel's card is wide); the lucky mark unchanged. */}
              {g.badges.some((b) => b.active) && (
                <span className="corner badge-stack" data-gift-badges={g.code}>
                  {g.badges
                    .filter((b) => b.active)
                    .map((b) => (
                      <BadgeChip key={b.code} code={b.code} iconOnly />
                    ))}
                </span>
              )}
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
            {g.owner && <GiftOwnerChip owner={g.owner} />}
            <div className="muted small">{t('giftUse', { n: formatNumber(g.sends, lang) })}</div>
            {g.archivedAt && (
              <div className="small" data-gift-archived={g.code}>
                <span className="badge warn">{t('giftArchived')}</span>{' '}
                <span className="muted">{t('giftArchivedSince', { date: formatDate(g.archivedAt, lang) })}</span>
                <div className="muted" data-gift-pieces={g.pieces}>
                  {g.pieces > 0
                    ? t('giftPiecesLeft', { pieces: formatNumber(g.pieces, lang), holders: formatNumber(g.holders, lang) })
                    : t('giftPiecesDone')}
                </div>
              </div>
            )}
            {!g.archivedAt && seasonalWithoutEnd(g.badges) && <SeasonalNoEndHint />}
            {can('catalog.manage') &&
              (g.archivedAt ? (
                <div className="row gift-actions">
                  <button className="btn small primary" onClick={() => setBack(g)} data-gift-restore={g.code}>
                    {t('giftRestore')}
                  </button>
                </div>
              ) : (
                <div className="row gift-actions">
                  <button className="btn small" onClick={() => setEdit(g)}>
                    {t('edit')}
                  </button>
                  <button className={`btn small ${g.enabled ? '' : 'primary'}`} onClick={() => setToggle(g)}>
                    {g.enabled ? t('disable') : t('enable')}
                  </button>
                  <button className="btn small danger" onClick={() => setDel(g)} data-gift-delete={g.code}>
                    {t('giftDelete')}
                  </button>
                </div>
              ))}
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
      {del && (
        <FormDialog
          title={`${t('giftDelete')} · ${lang === 'ar' ? del.nameAr : del.nameEn}`}
          intro={<GiftDeleteIntro gift={del} />}
          fields={[reasonField(t)]}
          confirmLabel={giftDeleteCase(del) === 'delete' ? t('giftDeleteConfirm') : t('giftArchiveConfirm')}
          danger
          submit={async (v) => {
            const r = await api.del<{ result: 'DELETED' | 'ARCHIVED' }>(`/admin/gifts/${del.code}`, { reason: v.reason });
            lastDelete.current = r.result;
          }}
          onClose={() => setDel(null)}
          onDone={() => {
            setDel(null);
            done(lastDelete.current === 'DELETED' ? t('giftDeletedToast') : t('giftArchivedToast'));
          }}
        />
      )}
      {back && (
        <FormDialog
          title={`${t('giftRestore')} · ${lang === 'ar' ? back.nameAr : back.nameEn}`}
          intro={<p className="muted small">{t('giftRestoreNote')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('giftRestore')}
          submit={(v) => api.post(`/admin/gifts/${back.code}/restore`, { reason: v.reason })}
          onClose={() => setBack(null)}
          onDone={() => {
            setBack(null);
            done(t('done'));
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

/** Local `datetime-local` text → an ISO time with the browser's offset. */
export function localToIso(value: string): string {
  return new Date(value).toISOString();
}

/** «البانرات» (D197): banners on / off / removed; v1.101-social (D325): the events are in «الفعاليات». */
export function Promo() {
  const { t, lang, can, toast } = useApp();
  const banners = useAsync(() => api.get<{ data: BannerDto[] }>('/admin/banners'), []);
  const [act, setAct] = useState<{ path: string; label: string; danger?: boolean; reload: () => void } | null>(null);
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
      {/* v1.101-social (D325): the events moved to «الفعاليات» — one events system with the step-by-step editor. */}
      <section className="card" style={{ marginTop: 16 }}>
        <div className="card-head">
          <h2>{t('eventsTitle')}</h2>
          <a className="btn small" href="/events">
            {t('navEvents')}
          </a>
        </div>
        <p className="muted small">{t('evSubtitle')}</p>
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
    </>
  );
}
