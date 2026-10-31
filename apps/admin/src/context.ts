import { createContext, useContext } from 'react';
import type { Key, Lang } from './i18n';
import type { AdminSessionInfo, Capability } from './types';

export interface AppState {
  lang: Lang;
  t: (key: Key, vars?: Record<string, string | number>) => string;
  session: AdminSessionInfo | null;
  can: (cap: Capability) => boolean;
  toast: (text: string) => void;
}

export const AppContext = createContext<AppState | null>(null);

export function useApp(): AppState {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('AppContext missing');
  return ctx;
}

/** localStorage only for per-viewer conveniences (language, theme), always guarded. */
export function readPref(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function writePref(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // private mode / blocked storage: the choice lasts for this page only
  }
}
