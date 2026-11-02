/**
 * The studio's sign-in session (D247, CONVENTIONS §6 and §10.88). The user API's token pair: the access token lives
 * in memory only; the refresh token is kept in this tab's `sessionStorage` (it survives a reload during a live, never
 * reaches another tab or a later browser session, and is removed at sign-out). The refresh is **single-flight**
 * (CONVENTIONS §6: two refreshes with one secret revoke the session), and a tab duplicated by the browser — which
 * copies `sessionStorage` — gives the copy up instead of racing the original (BroadcastChannel claim).
 */

export interface TokenPair {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

/** `sessionStorage`, or nothing when the browser refuses it (a private window, blocked site data). */
export function tabStorage(): KeyValueStore | null {
  try {
    const s = globalThis.sessionStorage;
    const probe = '__kabso_probe';
    s.setItem(probe, '1');
    s.removeItem(probe);
    return s;
  } catch {
    return null;
  }
}

export const REFRESH_KEY = 'kabso.studio.refresh';
const TAB_KEY = 'kabso.studio.tab';

/** The refresh call; resolves to the new pair or rejects (`status` 401/403 = the session is over). */
export type RefreshCall = (refreshToken: string) => Promise<TokenPair>;

export class SessionExpiredError extends Error {
  constructor() {
    super('session expired');
  }
}

export class Session {
  private access: string | null = null;
  private accessExpiresAt = 0;
  private inflight: Promise<string> | null = null;
  private listeners = new Set<() => void>();

  constructor(
    private readonly store: KeyValueStore | null,
    private readonly refreshCall: RefreshCall,
    private readonly now: () => number = () => Date.now(),
  ) {}

  /** A refresh token is held (a reload can resume without the password). */
  get hasSession(): boolean {
    return this.access !== null || this.readRefresh() !== null;
  }

  /** Called with the pair from login / register; replaces whatever was held. */
  signedIn(tokens: TokenPair): void {
    this.apply(tokens);
  }

  /** Forgets the tokens (sign-out, a refused refresh). Listeners hear it. */
  clear(): void {
    this.access = null;
    this.accessExpiresAt = 0;
    try {
      this.store?.removeItem(REFRESH_KEY);
    } catch {
      /* nothing kept */
    }
    for (const l of this.listeners) l();
  }

  /** Runs `fn` when the session ends (a refused refresh). */
  onCleared(fn: () => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  /**
   * A valid access token: the one in memory while it has more than 30 s left, else one refresh. Concurrent callers
   * share the same refresh (single-flight). Throws {@link SessionExpiredError} when there is no session or the
   * server refused it (the session is cleared).
   */
  async accessToken(): Promise<string> {
    if (this.access && this.accessExpiresAt - this.now() > 30_000) return this.access;
    return this.refresh();
  }

  /** Forces one refresh (a 401 on a token that looked valid), shared by every concurrent caller. */
  refresh(): Promise<string> {
    if (this.inflight) return this.inflight;
    const refreshToken = this.readRefresh();
    if (!refreshToken) return Promise.reject(new SessionExpiredError());
    this.inflight = this.refreshCall(refreshToken)
      .then((pair) => {
        this.apply(pair);
        return pair.accessToken;
      })
      .catch((err: unknown) => {
        const status = (err as { status?: number }).status;
        if (status === 401 || status === 403) {
          this.clear();
          throw new SessionExpiredError();
        }
        throw err;
      })
      .finally(() => {
        this.inflight = null;
      });
    return this.inflight;
  }

  /** The refresh token, for `POST /auth/logout`'s caller to revoke (the access token is what it sends). */
  private readRefresh(): string | null {
    try {
      return this.store?.getItem(REFRESH_KEY) ?? null;
    } catch {
      return null;
    }
  }

  private apply(pair: TokenPair): void {
    this.access = pair.accessToken;
    const at = Date.parse(pair.accessTokenExpiresAt);
    this.accessExpiresAt = Number.isFinite(at) ? at : this.now() + 60_000;
    try {
      this.store?.setItem(REFRESH_KEY, pair.refreshToken);
    } catch {
      /* the session lasts as long as the tab's memory */
    }
  }
}

/**
 * A duplicated tab copies `sessionStorage`, so two tabs would hold one refresh token and the second refresh would
 * revoke the session for both. Each tab keeps a random id; at start it asks on a BroadcastChannel whether another tab
 * already holds the same id (it is a copy) and, if so, takes a new id and drops the copied refresh token. Resolves to
 * true when this tab was a copy (it then needs a new sign-in).
 */
export async function claimTab(
  store: KeyValueStore | null,
  channel: Pick<BroadcastChannel, 'postMessage' | 'close'> & {
    onmessage: ((ev: MessageEvent) => void) | null;
  } | null,
  newId: () => string = () => crypto.randomUUID(),
  waitMs = 150,
): Promise<boolean> {
  if (!store || !channel) return false;
  let id: string | null;
  try {
    id = store.getItem(TAB_KEY);
  } catch {
    return false;
  }
  let copied = false;
  const mine = id ?? newId();
  let current = mine;
  let answered = false;
  channel.onmessage = (ev: MessageEvent) => {
    const data = ev.data as { type?: string; id?: string } | null;
    if (data?.type === 'who' && data.id === current) channel.postMessage({ type: 'mine', id: current });
    if (data?.type === 'mine' && data.id === mine && !answered) copied = true;
  };
  if (id) {
    channel.postMessage({ type: 'who', id: mine });
    await new Promise((r) => setTimeout(r, waitMs));
  }
  answered = true;
  if (copied) {
    current = newId();
    try {
      store.removeItem(REFRESH_KEY);
    } catch {
      /* ignore */
    }
  }
  try {
    store.setItem(TAB_KEY, current);
  } catch {
    /* ignore */
  }
  return copied;
}
