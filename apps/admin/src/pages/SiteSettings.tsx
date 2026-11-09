import { useEffect, useState } from 'react';
import { api } from '../api';
import { ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import type {
  CameraFxEngine,
  CameraFxSettings,
  GlobalStripsSettings,
  LevelTickerSettings,
  SiteSettings as Settings,
} from '../types';

export function SiteSettings() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<Settings>('/admin/site-settings'), []);
  const [form, setForm] = useState({ instagram: '', tiktok: '', whatsapp: '', topupEnabled: false, reason: '' });
  const [saveError, setSaveError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (data)
      setForm({
        instagram: data.socials.instagram ?? '',
        tiktok: data.socials.tiktok ?? '',
        whatsapp: data.socials.whatsapp ?? '',
        topupEnabled: data.topupEnabled,
        reason: '',
      });
  }, [data]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('siteTitle')}</h1>
          <p className="muted small">{t('siteSubtitle')}</p>
        </div>
      </div>
      <form
        className="card"
        style={{ maxWidth: 640 }}
        onSubmit={(e) => {
          e.preventDefault();
          setBusy(true);
          setSaveError(null);
          api
            .put<Settings>('/admin/site-settings', {
              socials: { instagram: form.instagram.trim() || null, tiktok: form.tiktok.trim() || null, whatsapp: form.whatsapp.trim() || null },
              topupEnabled: form.topupEnabled,
              ...(form.reason.trim() ? { reason: form.reason.trim() } : {}),
            })
            .then(
              (saved) => {
                setBusy(false);
                setForm({
                  instagram: saved.socials.instagram ?? '',
                  tiktok: saved.socials.tiktok ?? '',
                  whatsapp: saved.socials.whatsapp ?? '',
                  topupEnabled: saved.topupEnabled,
                  reason: '',
                });
                toast(t('saved'));
              },
              (err: unknown) => {
                setBusy(false);
                setSaveError(err);
              },
            );
        }}
      >
        <ErrorAlert error={saveError} />
        <div className="field">
          <label htmlFor="s-ig">{t('instagram')}</label>
          <input id="s-ig" type="text" className="ltr" placeholder="https://www.instagram.com/…" value={form.instagram} onChange={set('instagram')} />
        </div>
        <div className="field">
          <label htmlFor="s-tt">{t('tiktok')}</label>
          <input id="s-tt" type="text" className="ltr" placeholder="https://www.tiktok.com/@…" value={form.tiktok} onChange={set('tiktok')} />
        </div>
        <div className="field">
          <label htmlFor="s-wa">{t('whatsapp')}</label>
          <input id="s-wa" type="text" className="ltr" placeholder="+966…" value={form.whatsapp} onChange={set('whatsapp')} />
        </div>
        <label className="check field">
          <input type="checkbox" checked={form.topupEnabled} onChange={(e) => setForm((f) => ({ ...f, topupEnabled: e.target.checked }))} />
          {t('topupEnabled')}
        </label>
        <div className="field">
          <label htmlFor="s-reason">{t('reason')}</label>
          <textarea id="s-reason" maxLength={500} value={form.reason} onChange={set('reason')} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        <button className="btn primary" disabled={busy}>
          {t('save')}
        </button>
      </form>
      <CameraFxCard />
      <LevelTickerCard />
      <GlobalStripsCard />
    </>
  );
}

/** D228: the PUT body of «محرك مؤثرات الكاميرا» (a reason only when typed). */
export function cameraFxBody(engine: CameraFxEngine, reason: string): { cameraFxEngine: CameraFxEngine; reason?: string } {
  return { cameraFxEngine: engine, ...(reason.trim() ? { reason: reason.trim() } : {}) };
}

/** D228: the form of «محرك مؤثرات الكاميرا» (the app's camera effects engine), pure for the tests. */
export function CameraFxView(props: {
  engine: CameraFxEngine;
  reason: string;
  busy: boolean;
  onEngine: (engine: CameraFxEngine) => void;
  onReason: (reason: string) => void;
  onSave: () => void;
}) {
  const { t } = useApp();
  const option = (value: CameraFxEngine, label: string) => (
    <label className="check field">
      <input type="radio" name="camera-fx" value={value} checked={props.engine === value} onChange={() => props.onEngine(value)} />
      {label}
    </label>
  );
  return (
    <form
      className="card"
      style={{ maxWidth: 640, marginTop: 16 }}
      onSubmit={(e) => {
        e.preventDefault();
        props.onSave();
      }}
    >
      <h2>{t('fxTitle')}</h2>
      <p className="muted small">{t('fxIntro')}</p>
      {option('DEEPAR', t('fxDeepar'))}
      {option('FREE', t('fxFree'))}
      {props.engine === 'FREE' ? <p className="hint">{t('fxFreeNote')}</p> : null}
      <div className="field">
        <label htmlFor="fx-reason">{t('reason')}</label>
        <textarea id="fx-reason" maxLength={500} value={props.reason} onChange={(e) => props.onReason(e.target.value)} />
      </div>
      <button className="btn primary" disabled={props.busy}>
        {t('fxSave')}
      </button>
    </form>
  );
}

function CameraFxCard() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<CameraFxSettings>('/admin/camera-fx'), []);
  const [engine, setEngine] = useState<CameraFxEngine>('DEEPAR');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<unknown>(null);
  useEffect(() => {
    if (data) setEngine(data.cameraFxEngine);
  }, [data]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <>
      <ErrorAlert error={saveError} />
      <CameraFxView
        engine={engine}
        reason={reason}
        busy={busy}
        onEngine={setEngine}
        onReason={setReason}
        onSave={() => {
          setBusy(true);
          setSaveError(null);
          api.put<CameraFxSettings>('/admin/camera-fx', cameraFxBody(engine, reason)).then(
            (saved) => {
              setBusy(false);
              setEngine(saved.cameraFxEngine);
              setReason('');
              toast(t('saved'));
            },
            (err: unknown) => {
              setBusy(false);
              setSaveError(err);
            },
          );
        }}
      />
    </>
  );
}

/**
 * D254: the PUT body of «شريط ترقية المستويات» — the typed level as an integer 1–100 (null when it is not one, the
 * form refuses it before sending) and a reason only when typed.
 */
export function levelTickerBody(minLevel: string, reason: string): { minLevel: number; reason?: string } | null {
  const text = minLevel.trim();
  if (!/^[0-9]{1,3}$/.test(text)) return null;
  const level = Number(text);
  if (level < 1 || level > 100) return null;
  return { minLevel: level, ...(reason.trim() ? { reason: reason.trim() } : {}) };
}

/** D254: the form of «شريط ترقية المستويات» (the level-up banner's threshold), pure for the tests. */
export function LevelTickerView(props: {
  minLevel: string;
  reason: string;
  busy: boolean;
  onMinLevel: (minLevel: string) => void;
  onReason: (reason: string) => void;
  onSave: () => void;
}) {
  const { t } = useApp();
  const invalid = levelTickerBody(props.minLevel, '') === null;
  return (
    <form
      className="card"
      style={{ maxWidth: 640, marginTop: 16 }}
      onSubmit={(e) => {
        e.preventDefault();
        if (!invalid) props.onSave();
      }}
    >
      <h2>{t('lvTitle')}</h2>
      <p className="muted small">{t('lvIntro')}</p>
      <div className="field">
        <label htmlFor="lv-min">{t('lvMinLevel')}</label>
        <input
          id="lv-min"
          type="number"
          className="ltr"
          min={1}
          max={100}
          step={1}
          inputMode="numeric"
          value={props.minLevel}
          aria-invalid={invalid}
          onChange={(e) => props.onMinLevel(e.target.value)}
        />
        <span className="hint">{invalid ? t('lvInvalid') : t('lvHint')}</span>
      </div>
      <div className="field">
        <label htmlFor="lv-reason">{t('reason')}</label>
        <textarea id="lv-reason" maxLength={500} value={props.reason} onChange={(e) => props.onReason(e.target.value)} />
      </div>
      <button className="btn primary" disabled={props.busy || invalid}>
        {t('lvSave')}
      </button>
    </form>
  );
}

function LevelTickerCard() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<LevelTickerSettings>('/admin/level-ticker'), []);
  const [minLevel, setMinLevel] = useState('30');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<unknown>(null);
  useEffect(() => {
    if (data) setMinLevel(String(data.minLevel));
  }, [data]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <>
      <ErrorAlert error={saveError} />
      <LevelTickerView
        minLevel={minLevel}
        reason={reason}
        busy={busy}
        onMinLevel={setMinLevel}
        onReason={setReason}
        onSave={() => {
          const body = levelTickerBody(minLevel, reason);
          if (!body) return;
          setBusy(true);
          setSaveError(null);
          api.put<LevelTickerSettings>('/admin/level-ticker', body).then(
            (saved) => {
              setBusy(false);
              setMinLevel(String(saved.minLevel));
              setReason('');
              toast(t('saved'));
            },
            (err: unknown) => {
              setBusy(false);
              setSaveError(err);
            },
          );
        }}
      />
    </>
  );
}

/** D305: a whole positive number up to [max] typed in a field, or null. */
function wholeUpTo(text: string, max: number): number | null {
  const t = text.trim();
  if (!/^[0-9]{1,13}$/.test(t)) return null;
  const n = Number(t);
  return n >= 1 && n <= max ? n : null;
}

/**
 * D305: the PUT body of «شريطا الهدايا والألعاب» — both thresholds as whole numbers (one gift's price 1–10⁹ coins,
 * a prize 1–10¹² tickets; null when either is not one, the form refuses it) and a reason only when typed.
 */
export function globalStripsBody(
  giftMinCoins: string,
  gameMinTickets: string,
  reason: string,
  /** D318: the lucky chat threshold (omitted: not sent, an older API's form) and the multipliers it may be. */
  luckyChat?: { value: string; multipliers: readonly number[] },
): { giftMinCoins: number; gameMinTickets: number; luckyChatMinMultiplier?: number; reason?: string } | null {
  const gift = wholeUpTo(giftMinCoins, 1_000_000_000);
  const game = wholeUpTo(gameMinTickets, 1_000_000_000_000);
  if (gift === null || game === null) return null;
  let lucky: number | undefined;
  if (luckyChat) {
    const n = wholeUpTo(luckyChat.value, 10_000);
    if (n === null || !luckyChat.multipliers.includes(n)) return null;
    lucky = n;
  }
  return {
    giftMinCoins: gift,
    gameMinTickets: game,
    ...(lucky !== undefined ? { luckyChatMinMultiplier: lucky } : {}),
    ...(reason.trim() ? { reason: reason.trim() } : {}),
  };
}

/** D305: the form of «شريطا الهدايا والألعاب» (the global strips' thresholds), pure for the tests. */
export function GlobalStripsView(props: {
  giftMinCoins: string;
  gameMinTickets: string;
  reason: string;
  busy: boolean;
  onGiftMinCoins: (value: string) => void;
  onGameMinTickets: (value: string) => void;
  onReason: (reason: string) => void;
  onSave: () => void;
  /** D318: the lucky chat threshold and the multipliers to choose from (absent: an older API, no field). */
  luckyChat?: { value: string; multipliers: readonly number[]; onChange: (value: string) => void };
}) {
  const { t } = useApp();
  const invalid = globalStripsBody(props.giftMinCoins, props.gameMinTickets, '') === null;
  const lucky = props.luckyChat;
  const luckyInvalid =
    lucky !== undefined && globalStripsBody('1', '1', '', { value: lucky.value, multipliers: lucky.multipliers }) === null;
  return (
    <form
      className="card"
      style={{ maxWidth: 640, marginTop: 16 }}
      onSubmit={(e) => {
        e.preventDefault();
        if (!invalid && !luckyInvalid) props.onSave();
      }}
    >
      <h2>{t('gsTitle')}</h2>
      <p className="muted small">{t('gsIntro')}</p>
      <div className="field">
        <label htmlFor="gs-gift">{t('gsGiftMinCoins')}</label>
        <input
          id="gs-gift"
          type="number"
          className="ltr"
          min={1}
          step={1}
          inputMode="numeric"
          value={props.giftMinCoins}
          aria-invalid={invalid}
          onChange={(e) => props.onGiftMinCoins(e.target.value)}
        />
      </div>
      <div className="field">
        <label htmlFor="gs-game">{t('gsGameMinTickets')}</label>
        <input
          id="gs-game"
          type="number"
          className="ltr"
          min={1}
          step={1}
          inputMode="numeric"
          value={props.gameMinTickets}
          aria-invalid={invalid}
          onChange={(e) => props.onGameMinTickets(e.target.value)}
        />
        <span className="hint">{invalid ? t('gsInvalid') : t('gsHint')}</span>
      </div>
      {lucky && (
        <div className="field">
          <label htmlFor="gs-lucky-chat">{t('gsLuckyChat')}</label>
          <select
            id="gs-lucky-chat"
            className="ltr"
            value={lucky.value}
            aria-invalid={luckyInvalid}
            onChange={(e) => lucky.onChange(e.target.value)}
          >
            {lucky.multipliers.map((m) => (
              <option key={m} value={String(m)}>
                ×{m}
              </option>
            ))}
          </select>
          <span className="hint">{luckyInvalid ? t('gsLuckyChatInvalid') : t('gsLuckyChatHint')}</span>
        </div>
      )}
      <div className="field">
        <label htmlFor="gs-reason">{t('reason')}</label>
        <textarea id="gs-reason" maxLength={500} value={props.reason} onChange={(e) => props.onReason(e.target.value)} />
      </div>
      <button className="btn primary" disabled={props.busy || invalid || luckyInvalid}>
        {t('gsSave')}
      </button>
    </form>
  );
}

function GlobalStripsCard() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<GlobalStripsSettings>('/admin/global-strips'), []);
  const [gift, setGift] = useState('500000');
  const [game, setGame] = useState('1000000');
  const [luckyChat, setLuckyChat] = useState('250');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<unknown>(null);
  useEffect(() => {
    if (data) {
      setGift(String(data.giftMinCoins));
      setGame(String(data.gameMinTickets));
      if (data.luckyChatMinMultiplier !== undefined) setLuckyChat(String(data.luckyChatMinMultiplier));
    }
  }, [data]);
  // D318: the lucky chat field only with an API that sends the multipliers.
  const multipliers = data?.luckyMultipliers;
  const lucky = multipliers?.length ? { value: luckyChat, multipliers } : undefined;
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <>
      <ErrorAlert error={saveError} />
      <GlobalStripsView
        giftMinCoins={gift}
        gameMinTickets={game}
        reason={reason}
        busy={busy}
        onGiftMinCoins={setGift}
        onGameMinTickets={setGame}
        onReason={setReason}
        {...(lucky ? { luckyChat: { ...lucky, onChange: setLuckyChat } } : {})}
        onSave={() => {
          const body = globalStripsBody(gift, game, reason, lucky);
          if (!body) return;
          setBusy(true);
          setSaveError(null);
          api.put<GlobalStripsSettings>('/admin/global-strips', body).then(
            (saved) => {
              setBusy(false);
              setGift(String(saved.giftMinCoins));
              setGame(String(saved.gameMinTickets));
              if (saved.luckyChatMinMultiplier !== undefined) setLuckyChat(String(saved.luckyChatMinMultiplier));
              setReason('');
              toast(t('saved'));
            },
            (err: unknown) => {
              setBusy(false);
              setSaveError(err);
            },
          );
        }}
      />
    </>
  );
}
