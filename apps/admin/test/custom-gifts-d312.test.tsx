/**
 * D312 «مُخصَّص» (custom gifts) in «الهدايا»: the form asks for the owner «صاحب الهدية» (Kabso ID) only for the CUSTOM
 * category and sends it as the server reads it; an edit sends only a changed owner; the card shows the owner and warns
 * when the account is not active.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import {
  GiftOwnerChip,
  isCustomCategory,
  ownerHandle,
  ownerPart,
  type GiftCategoryChoice,
  type GiftDto,
  type GiftOwnerDto,
} from '../src/pages/Catalog';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const categories: GiftCategoryChoice[] = [
  { code: 'POPULAR', kind: 'NORMAL', nameAr: 'شائعة', nameEn: 'Popular', enabled: true },
  { code: 'LUCKY', kind: 'LUCKY', nameAr: 'الحظ', nameEn: 'Lucky', enabled: true },
  { code: 'CUSTOM', kind: 'CUSTOM', nameAr: 'مُخصَّص', nameEn: 'Custom', enabled: true },
];

const owner: GiftOwnerDto = {
  id: '0192f1d0-0000-7000-8000-000000000001',
  username: 'designer',
  displayName: 'Designer',
  avatarUrl: null,
  status: 'ACTIVE',
};
const custom = { code: 'star', category: 'CUSTOM', owner } as unknown as GiftDto;

describe('D312 custom gifts in the panel', () => {
  it('only the CUSTOM kind asks for an owner', () => {
    expect(isCustomCategory('CUSTOM', categories)).toBe(true);
    expect(isCustomCategory('POPULAR', categories)).toBe(false);
    expect(isCustomCategory('LUCKY', categories)).toBe(false);
    expect(isCustomCategory('UNKNOWN', categories)).toBe(false);
  });

  it('sends the Kabso ID as the server reads it (no @, lower-case), on create and only when changed on an edit', () => {
    expect(ownerHandle('  @DeSigner ')).toBe('designer');
    expect(ownerPart('@DeSigner', true, null)).toEqual({ owner: 'designer' });
    expect(ownerPart('designer', false, null)).toEqual({});
    expect(ownerPart('   ', true, null)).toEqual({});
    expect(ownerPart('@designer', true, custom)).toEqual({});
    expect(ownerPart('other', true, custom)).toEqual({ owner: 'other' });
  });

  it('shows the owner on the card (ar / en) and warns when the account is not active', () => {
    const ar = renderToStaticMarkup(
      <AppContext.Provider value={state('ar')}>
        <GiftOwnerChip owner={owner} />
      </AppContext.Provider>,
    );
    const plain = (html: string) => html.replace(/[\u2066-\u2069]/g, '');
    expect(plain(ar)).toContain('صاحب الهدية: @designer');
    // The handle is isolated so it reads left-to-right inside Arabic.
    expect(ar).toContain('\u2068@designer\u2069');
    expect(ar).not.toContain(translate('ar', 'giftOwnerInactive'));
    const en = renderToStaticMarkup(
      <AppContext.Provider value={state('en')}>
        <GiftOwnerChip owner={{ ...owner, status: 'SUSPENDED' }} />
      </AppContext.Provider>,
    );
    expect(plain(en)).toContain('Owner: @designer');
    expect(en).toContain(translate('en', 'giftOwnerInactive'));
  });

  it('names the CUSTOM kind in both languages', () => {
    expect(translate('ar', 'giftCatKindCUSTOM')).toBe('مُخصَّص');
    expect(translate('en', 'giftCatKindCUSTOM')).toBe('Custom');
  });
});
