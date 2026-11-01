import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, FormDialog, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import { Icon } from '../ui/icons';
import { FileSlot, NO_FILE, previewUrl, type FileValue } from './GiftFiles';

/** `AdminGiftCategory` (v1.71-social, D207). */
export interface GiftCategoryDto {
  code: string;
  kind: 'NORMAL' | 'LUCKY' | 'QUIPS';
  nameAr: string;
  nameEn: string;
  sortOrder: number;
  enabled: boolean;
  iconObjectKey: string | null;
  iconUrl: string | null;
  gifts: number;
  enabledGifts: number;
  special: boolean;
}

/** The category form → the request body: on create every field; on an edit only what changed. */
export function categoryBody(
  form: { code: string; nameAr: string; nameEn: string; sortOrder: string },
  icon: FileValue,
  before: GiftCategoryDto | null,
): Record<string, unknown> {
  const fields: Record<string, unknown> = {
    nameAr: form.nameAr.trim(),
    nameEn: form.nameEn.trim(),
    sortOrder: Number(form.sortOrder || '0'),
    iconObjectKey: icon.key,
  };
  if (before === null) {
    const out: Record<string, unknown> = { code: form.code.trim(), ...fields };
    if (out.iconObjectKey === null) delete out.iconObjectKey;
    return out;
  }
  return Object.fromEntries(
    Object.entries(fields).filter(([k, v]) => (before as unknown as Record<string, unknown>)[k] !== v),
  );
}

function CategoryForm({ cat, onClose, onDone }: { cat: GiftCategoryDto | null; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [form, setForm] = useState({
    code: cat?.code ?? '',
    nameAr: cat?.nameAr ?? '',
    nameEn: cat?.nameEn ?? '',
    sortOrder: String(cat?.sortOrder ?? 100),
  });
  const [icon, setIcon] = useState<FileValue>(cat ? { key: cat.iconObjectKey, url: previewUrl(cat.iconObjectKey) } : NO_FILE);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const body = categoryBody(form, icon, cat);
  const codeOk = /^[A-Z][A-Z0-9_]{0,39}$/.test(form.code.trim());
  const ok =
    reason.trim() !== '' &&
    form.nameAr.trim() !== '' &&
    form.nameEn.trim() !== '' &&
    (cat ? Object.keys(body).length > 0 : codeOk);
  const set = (k: keyof typeof form) => (e: { target: { value: string } }) =>
    setForm((f) => ({ ...f, [k]: k === 'code' ? e.target.value.toUpperCase() : e.target.value }));
  return (
    <Dialog title={cat ? t('giftCatEdit', { code: cat.code }) : t('giftCatAdd')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          const p = cat
            ? api.patch(`/admin/gift-categories/${cat.code}`, { ...body, reason: reason.trim() })
            : api.post('/admin/gift-categories', { ...body, reason: reason.trim() });
          p.then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        {!cat && (
          <div className="field">
            <label htmlFor="gc-code">{t('giftCatCode')}</label>
            <input id="gc-code" className="ltr mono" maxLength={40} value={form.code} onChange={set('code')} />
          </div>
        )}
        <div className="field">
          <label htmlFor="gc-sort">{t('giftCatSort')}</label>
          <input id="gc-sort" type="number" min={0} max={1000000} className="num" value={form.sortOrder} onChange={set('sortOrder')} />
        </div>
        <div className="field">
          <label htmlFor="gc-ar">{t('giftCatNameAr')}</label>
          <input id="gc-ar" dir="rtl" maxLength={30} value={form.nameAr} onChange={set('nameAr')} />
        </div>
        <div className="field">
          <label htmlFor="gc-en">{t('giftCatNameEn')}</label>
          <input id="gc-en" dir="ltr" maxLength={30} value={form.nameEn} onChange={set('nameEn')} />
        </div>
        <FileSlot
          kind="icon"
          code={cat?.code ?? (codeOk ? form.code.trim() : '')}
          label={t('giftCatIcon')}
          hint={t('giftCatIconHint')}
          value={icon}
          onChange={setIcon}
        />
        <div className="field span-2">
          <label htmlFor="gc-reason">{t('reason')}</label>
          <textarea id="gc-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t('giftArtHint')}</span>
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {cat ? t('save') : t('giftCatAdd')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** Delete: refused while gifts are in it, unless «نقل الهدايا إلى تصنيف آخر ثم الحذف» to another NORMAL category. */
function DeleteDialog({
  cat,
  all,
  onClose,
  onDone,
}: {
  cat: GiftCategoryDto;
  all: GiftCategoryDto[];
  onClose: () => void;
  onDone: () => void;
}) {
  const { t, lang } = useApp();
  const targets = all.filter((c) => c.kind === 'NORMAL' && c.code !== cat.code);
  const [moveTo, setMoveTo] = useState(targets[0]?.code ?? '');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const hasGifts = cat.gifts > 0;
  const ok = reason.trim() !== '' && (!hasGifts || moveTo !== '');
  return (
    <Dialog title={t('giftCatDelete', { code: cat.code })} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          api
            .post(`/admin/gift-categories/${cat.code}/remove`, { ...(hasGifts ? { moveTo } : {}), reason: reason.trim() })
            .then(onDone, (err: unknown) => {
              setError(err);
              setBusy(false);
            });
        }}
      >
        <p className={`span-2 ${hasGifts ? 'alert warn' : 'muted'}`}>
          {hasGifts ? t('giftCatDeleteHas', { n: formatNumber(cat.gifts, lang) }) : t('giftCatDeleteEmpty')}
        </p>
        {hasGifts && (
          <div className="field span-2">
            <label htmlFor="gc-move">
              {t('giftCatMoveThenDelete')} — {t('giftCatMoveTo')}
            </label>
            <select id="gc-move" value={moveTo} onChange={(e) => setMoveTo(e.target.value)}>
              {targets.map((c) => (
                <option key={c.code} value={c.code}>
                  {lang === 'ar' ? c.nameAr : c.nameEn} ({c.code})
                </option>
              ))}
            </select>
          </div>
        )}
        <div className="field span-2">
          <label htmlFor="gc-del-reason">{t('reason')}</label>
          <textarea id="gc-del-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn danger" disabled={!ok || busy}>
            {hasGifts ? t('giftCatMoveThenDelete') : t('remove')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** «تصنيفات الهدايا» (v1.71-social, D207, CONVENTIONS §10.66): the gift panel's tabs, managed (gifts.categories). */
export function GiftCategories() {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<{ data: GiftCategoryDto[] }>('/admin/gift-categories'), []);
  const [edit, setEdit] = useState<GiftCategoryDto | 'new' | null>(null);
  const [toggle, setToggle] = useState<GiftCategoryDto | null>(null);
  const [remove, setRemove] = useState<GiftCategoryDto | null>(null);
  const manage = can('gifts.categories');
  const done = () => {
    setEdit(null);
    setToggle(null);
    setRemove(null);
    toast(t('done'));
    reload();
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('giftCatsTitle')}</h1>
          <p className="muted small">{t('giftCatsSubtitle')}</p>
        </div>
        {manage && (
          <button className="btn primary" onClick={() => setEdit('new')}>
            <Icon name="plus" size={16} />
            {t('giftCatAdd')}
          </button>
        )}
      </div>
      <ErrorAlert error={error} />
      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th className="num">{t('giftCatSort')}</th>
                <th>{t('giftCatNameAr')}</th>
                <th>{t('giftCatNameEn')}</th>
                <th>{t('giftCatCode')}</th>
                <th>{t('giftCatGifts')}</th>
                <th>{t('state')}</th>
                {manage && <th />}
              </tr>
            </thead>
            <tbody>
              {data?.data.map((c) => (
                <tr key={c.code} className={c.enabled ? '' : 'muted'}>
                  <td className="num">{formatNumber(c.sortOrder, lang)}</td>
                  <td>
                    <span className="cat-name">
                      {c.iconObjectKey ? <img className="cat-icon" src={previewUrl(c.iconObjectKey) ?? ''} alt="" /> : <span className="cat-icon blank" />}
                      {c.nameAr}
                      {c.special && <span className="badge info">{t(`giftCatKind${c.kind}` as never)}</span>}
                    </span>
                  </td>
                  <td dir="ltr">{c.nameEn}</td>
                  <td className="mono small ltr">{c.code}</td>
                  <td>{t('giftCatGiftsN', { n: formatNumber(c.gifts, lang), on: formatNumber(c.enabledGifts, lang) })}</td>
                  <td>
                    <span className={`badge ${c.enabled ? 'ok' : ''}`}>{c.enabled ? t('enabled') : t('disabled')}</span>
                  </td>
                  {manage && (
                    <td>
                      <div className="row end">
                        <button className="btn small" onClick={() => setEdit(c)}>
                          {t('edit')}
                        </button>
                        {!c.special && (
                          <>
                            <button className={`btn small ${c.enabled ? '' : 'primary'}`} onClick={() => setToggle(c)}>
                              {c.enabled ? t('disable') : t('enable')}
                            </button>
                            <button className="btn small danger" onClick={() => setRemove(c)}>
                              {t('remove')}
                            </button>
                          </>
                        )}
                        {c.special && <span className="badge">{t('giftCatSpecial')}</span>}
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
          {loading && !data && <p className="muted state">{t('loading')}</p>}
          {data && data.data.length === 0 && <p className="muted state">{t('giftCatNone')}</p>}
        </div>
        <p className="muted small">{t('giftCatOffNote')}</p>
      </div>
      {edit && <CategoryForm cat={edit === 'new' ? null : edit} onClose={() => setEdit(null)} onDone={done} />}
      {toggle && (
        <FormDialog
          title={`${toggle.enabled ? t('disable') : t('enable')} · ${toggle.code}`}
          intro={toggle.enabled ? t('giftCatOffNote') : undefined}
          fields={[reasonField(t)]}
          confirmLabel={toggle.enabled ? t('disable') : t('enable')}
          danger={toggle.enabled}
          submit={(v) => api.post(`/admin/gift-categories/${toggle.code}/${toggle.enabled ? 'disable' : 'enable'}`, { reason: v.reason })}
          onClose={() => setToggle(null)}
          onDone={done}
        />
      )}
      {remove && data && <DeleteDialog cat={remove} all={data.data} onClose={() => setRemove(null)} onDone={done} />}
    </>
  );
}
