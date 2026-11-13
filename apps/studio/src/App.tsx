import { useEffect, useMemo, useState } from 'react';
import { Api } from './api';
import { I18nContext, type I18n } from './context';
import { initialLang, translate, type Lang } from './i18n';
import { claimTab, tabStorage } from './session';
import { SignIn } from './SignIn';
import { Studio } from './Studio';
import type { Me } from './types';

type Theme = 'light' | 'dark';

function savedPref(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}
function savePref(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* a per-viewer convenience */
  }
}

function initialTheme(): Theme {
  const saved = savedPref('kabso.studio.theme');
  if (saved === 'light' || saved === 'dark') return saved;
  return globalThis.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

/** «استوديو البث» (D247): the shell — language, theme, the sign-in and the studio. */
export function App() {
  const api = useMemo(() => new Api(), []);
  const [lang, setLang] = useState<Lang>(() => initialLang(savedPref('kabso.studio.lang'), navigator.languages ?? []));
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const [me, setMe] = useState<Me | null>(null);
  const [booting, setBooting] = useState(true);

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    document.title = translate(lang, 'appName');
    api.lang = lang;
  }, [lang, api]);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  // A reload during a live resumes with this tab's refresh token (a duplicated tab gives its copy up).
  useEffect(() => {
    let cancelled = false;
    const channel = typeof BroadcastChannel === 'function' ? new BroadcastChannel('kabso-studio') : null;
    void (async () => {
      await claimTab(tabStorage(), channel);
      if (api.session.hasSession) {
        try {
          const user = await api.get<Me>('/me');
          if (!cancelled) setMe(user);
        } catch {
          api.session.clear();
        }
      }
      if (!cancelled) setBooting(false);
    })();
    const off = api.session.onCleared(() => setMe(null));
    return () => {
      cancelled = true;
      off();
    };
  }, [api]);

  const i18n: I18n = useMemo(() => ({ lang, t: (k, v) => translate(lang, k, v) }), [lang]);
  const t = i18n.t;

  const signOut = async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      /* the session ends here anyway */
    }
    api.session.clear();
    setMe(null);
  };

  return (
    <I18nContext.Provider value={i18n}>
      <header className="top">
        <a className="brand" href="/" aria-label={t('appName')}>
          <span className="brand-mark" aria-hidden="true">
            K
          </span>
          <span className="brand-text">
            <strong>{t('appName')}</strong>
            <small>{t('appTag')}</small>
          </span>
        </a>
        <span className="grow" />
        <a className="link small hide-narrow" href="https://kabsolive.com/studio" target="_blank" rel="noopener noreferrer">
          {t('siteGuide')}
        </a>
        <button
          className="btn ghost small"
          onClick={() => {
            const next = theme === 'dark' ? 'light' : 'dark';
            setTheme(next);
            savePref('kabso.studio.theme', next);
          }}
          aria-label={t('themeLabel')}
          data-testid="theme-toggle"
        >
          {theme === 'dark' ? `☀ ${t('themeLight')}` : `☾ ${t('themeDark')}`}
        </button>
        <button
          className="btn ghost small"
          onClick={() => {
            const next = lang === 'ar' ? 'en' : 'ar';
            setLang(next);
            savePref('kabso.studio.lang', next);
          }}
          aria-label={t('langToggleLabel')}
          lang={lang === 'ar' ? 'en' : 'ar'}
          data-testid="lang-toggle"
        >
          {t('langToggle')}
        </button>
        {me && (
          <>
            <span className="user">
              {me.avatarUrl ? <img src={me.avatarUrl} alt="" width={28} height={28} /> : <span className="avatar-ph">{me.displayName.slice(0, 1)}</span>}
              <bdi>{me.displayName}</bdi>
            </span>
            <button className="btn ghost small" onClick={() => void signOut()} data-testid="sign-out">
              {t('signOut')}
            </button>
          </>
        )}
      </header>
      {booting ? (
        <main className="center">
          <div className="spinner" aria-label="…" />
        </main>
      ) : me ? (
        <Studio api={api} me={me} />
      ) : (
        <SignIn api={api} onSignedIn={setMe} />
      )}
    </I18nContext.Provider>
  );
}
