/**
 * D289b (owner: «عند اضافة عنصر الى متجر من لوحة الادمن لا يمكن حذفه، فاريد منك اضافة زر الحذف»): «حذف» in the panel's store —
 * the case the dialog announces (deleted for good when nobody bought or holds the item, hidden otherwise with the owners'
 * count), the delete button on each row and in the form, hidden rows with «إرجاع للمتجر» and no delete; both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { StoreDeleteIntro, StoreItemsTable, storeDeleteCase, type AdminStoreItem } from '../src/pages/Store';
import type { Capability } from '../src/types';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const render = (lang: Lang, node: React.ReactNode, caps: Capability[] = ['catalog.view', 'catalog.manage']) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const item = (extra: Partial<AdminStoreItem> = {}): AdminStoreItem => ({
  id: '01a27000-0000-7000-8000-000000000001',
  code: 'store_0123456789ab',
  kind: 'AVATAR_FRAME',
  nameAr: 'إطار الوردة',
  nameEn: 'Rose frame',
  still: null,
  animation: null,
  animationFormat: null,
  animationAlpha: null,
  artWidth: null,
  artHeight: null,
  prices: [{ currency: 'COINS', days: 7, amount: 50_000 }],
  sortOrder: 10,
  isNew: false,
  badges: [],
  enabled: true,
  hiddenAt: null,
  owners: 0,
  sold: 0,
  createdAt: '2027-03-01T00:00:00.000Z',
  updatedAt: '2027-03-01T00:00:00.000Z',
  ...extra,
});

describe('«حذف» a store item (D289b)', () => {
  it('announces which case applies: deleted for good, or hidden and kept by N owners', () => {
    expect(storeDeleteCase(item())).toBe('delete');
    expect(storeDeleteCase(item({ owners: 3, sold: 4 }))).toBe('hide');
    expect(storeDeleteCase(item({ owners: 0, sold: 2 }))).toBe('hide');
    expect(storeDeleteCase(item({ owners: 1, sold: 0 }))).toBe('hide');
    const forever = render('ar', <StoreDeleteIntro item={item()} />);
    expect(forever).toContain('data-store-delete-case="delete"');
    expect(forever).toContain('سيُحذف نهائياً');
    const hide = render('ar', <StoreDeleteIntro item={item({ owners: 3, sold: 4 })} />);
    expect(hide).toContain('data-store-delete-case="hide"');
    expect(hide).toContain('سيُخفى من المتجر؛ يبقى عند 3 مستخدمين يملكونه');
    expect(render('ar', <StoreDeleteIntro item={item({ owners: 0, sold: 2 })} />)).toContain('بيع 2 مرة ولا يملكه أحد الآن');
    expect(render('en', <StoreDeleteIntro item={item()} />)).toContain('It will be deleted for good');
    expect(render('en', <StoreDeleteIntro item={item({ owners: 3, sold: 4 })} />)).toContain('3 users who hold it keep it');
  });

  it('a delete button on each row; a hidden row shows «مخفي» and «إرجاع للمتجر» instead; read-only roles see none', () => {
    const rows = [item(), item({ id: 'h', code: 'store_ffffffffffff', enabled: false, hiddenAt: '2027-03-02T00:00:00.000Z', owners: 2, sold: 2 })];
    const ar = render('ar', <StoreItemsTable items={rows} onEdit={noop} onToggle={noop} onDelete={noop} onRestore={noop} />);
    expect(ar).toContain('data-store-delete="store_0123456789ab"');
    expect(ar).not.toContain('data-store-delete="store_ffffffffffff"');
    expect(ar).toContain('data-store-restore="store_ffffffffffff"');
    expect(ar).not.toContain('data-store-toggle="store_ffffffffffff"');
    expect(ar).toContain('data-store-hidden="store_ffffffffffff"');
    expect(ar).toContain('إرجاع للمتجر');
    expect(ar).toContain('>حذف<');
    const en = render('en', <StoreItemsTable items={rows} onEdit={noop} onToggle={noop} />);
    expect(en).toContain('Back to the store');
    expect(en).toContain('>Delete<');
    const support = render('ar', <StoreItemsTable items={rows} onEdit={noop} onToggle={noop} />, ['catalog.view']);
    expect(support).not.toContain('data-store-delete=');
    expect(support).not.toContain('data-store-restore=');
  });
});
