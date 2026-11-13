import { createContext, useContext } from 'react';
import { translate, type Key, type Lang } from './i18n';

export interface I18n {
  lang: Lang;
  t: (key: Key, vars?: Record<string, string | number>) => string;
}

export const I18nContext = createContext<I18n>({ lang: 'ar', t: (k, v) => translate('ar', k, v) });

export function useT(): I18n {
  return useContext(I18nContext);
}
