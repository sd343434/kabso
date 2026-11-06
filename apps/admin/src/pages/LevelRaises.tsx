import { useEffect, useState } from 'react';
import { api, ApiError, uploadLevelRaiseVideo } from '../api';
import { Dialog, ErrorAlert, FormDialog, Loading, UserCell, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Lang } from '../i18n';
import { navigate } from '../router';

/**
 * D290 (owner, CONVENTIONS §10.103): «طلب رفع ليفيل».
 *  - «طلبات رفع الليفيل» (`levels.raise.request`: MODERATION, SUPPORT see and make their own; the OWNER sees all);
 *  - a request's review (`levels.raise.decide`: OWNER) — the video, the fields, the recharge, the current support and
 *    charm levels, the proposal with every step of its reasoning, approve at the proposal or lower, reject;
 *  - «بيانات التطبيقات» and «إعدادات الاقتراح» (OWNER): the source-app data with confidence labels and the weights.
 */

export type Confidence = 'CONFIRMED' | 'ESTIMATE';
export type Status = 'PENDING' | 'APPROVED' | 'REJECTED';
interface Person {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}
interface AppOption {
  code: string;
  nameAr: string;
  nameEn: string;
  confidence: Confidence;
  isOther: boolean;
}
export interface LevelRaise {
  id: string;
  status: Status;
  via: 'app' | 'panel';
  supporter: Person;
  requestedBy: Person;
  sourceApp: AppOption | null;
  sourceAppName: string;
  sourceAccountId: string;
  sourceLevel: number;
  note: string | null;
  video: {
    id: string;
    durationMs: number | null;
    width: number;
    height: number;
    byteSize: number;
    posterUrl: string | null;
    /** D290: the video is deleted after the decision (its evidence stays). */
    deletedAt: string | null;
  };
  /** «سبق رفض طلب بنفس الحساب»: the latest REJECTED request for the same source account. */
  previousRejection: {
    id: string;
    createdAt: string;
    decidedAt: string | null;
    rejectReason: string | null;
    requestedBy: Person;
  } | null;
  createdAt: string;
  decidedAt: string | null;
  decidedBy: Person | null;
  rejectReason: string | null;
  proposedLevel: number | null;
  approvedLevel: number | null;
  levelBefore: number | null;
  levelAfter: number | null;
}
export interface Evidence {
  totalRechargeCoins: number;
  firstDaysRechargeCoins: number;
  firstDays: number;
  accountCreatedAt: string;
  firstDaysEndAt: string;
  supportLevel: number;
  charmLevel: number;
  minRechargeCoins: number;
  eligible: boolean;
}
export interface XpPoint {
  level: number;
  xp: number;
  confidence: Confidence;
}
export interface Proposal {
  proposedLevel: number;
  limitedBy: 'SOURCE' | 'RECHARGE' | 'MAX_LEVEL' | 'CURRENT_LEVEL';
  eligible: boolean;
  maxLevel: number;
  app: {
    code: string | null;
    name: string;
    mode: 'MONEY' | 'FACTOR';
    confidence: Confidence;
  };
  sourceLevel: number;
  source:
    | {
        mode: 'MONEY';
        level: number;
        xp: number;
        xpMethod: 'TABLE' | 'INTERPOLATED' | 'BELOW_TABLE' | 'ABOVE_TABLE_CLAMPED';
        xpFrom: XpPoint[];
        sourceCoins: number;
        usd: number;
        usdPerMillion: number;
        coinsPerXp: number;
        kabsoCoins: number;
        kabsoPoints: number;
        kabsoUsdPerMillion: number;
      }
    | { mode: 'FACTOR'; level: number; factor: number }
    | { mode: 'NONE'; level: number };
  firstDaysCap: number;
  totalCap: number;
  rechargeCap: number;
  supportBonus: number;
  charmBonus: number;
  beforeClamp: number;
  evidence: Evidence;
}
interface Detail {
  request: LevelRaise;
  proposal: Proposal | null;
  evidence: Evidence;
}
export interface SourceApp {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  mode: 'MONEY' | 'FACTOR';
  usdPerMillion: number | null;
  coinsPerXp: number | null;
  xpTable: XpPoint[];
  factor: number | null;
  confidence: Confidence;
  sourceNote: string;
  sourceUrl: string | null;
  sourceDate: string | null;
  enabled: boolean;
  isOther: boolean;
  sort: number;
  aliases: string[];
  updatedAt: string;
}
export const SETTING_KEYS = [
  'minRechargeCoins',
  'firstDays',
  'anchorCoins',
  'firstDaysBaseLevel',
  'totalBaseLevel',
  'levelsPerDoubling',
  'supportBonusPer10Levels',
  'supportBonusMax',
  'charmBonusPer10Levels',
  'charmBonusMax',
  'belowTableExponent',
] as const;
type SettingKey = (typeof SETTING_KEYS)[number];
type Settings = Record<SettingKey, number> & {
  maxLevel: number;
  kabsoUsdPerMillion: number;
};
interface SettingsView {
  settings: Settings;
  defaults: Settings;
  updatedAt: string;
}

type T = ReturnType<typeof useApp>['t'];
const n = (v: number, lang: Lang) => formatNumber(v, lang);
/** Dollars with two decimals («5,548.50»). */
const usd2 = (v: number, lang: Lang) =>
  new Intl.NumberFormat(lang === 'ar' ? 'ar-u-nu-latn' : 'en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(v);

/** `GET …/source-apps/suggest`: «هل تقصد: …؟». */
export interface Suggestion {
  kind: 'APP' | 'NAME';
  app: AppOption | null;
  name: string | null;
  count: number | null;
}

/** The text of a suggestion: the listed app in the panel's language, or the earlier typed name (pure: tested). */
export function suggestionLabel(sg: Suggestion, lang: Lang): string {
  if (sg.kind === 'APP' && sg.app) return lang === 'ar' ? sg.app.nameAr : sg.app.nameEn;
  return sg.name ?? '';
}

/**
 * 409 LEVEL_RAISE_DUPLICATE in words: the existing request's status, date and staff member (pure: tested); null for
 * any other error.
 */
export function duplicateText(err: unknown, t: T, lang: Lang): string | null {
  if (!(err instanceof ApiError) || err.code !== 'LEVEL_RAISE_DUPLICATE') return null;
  const of = (f: string) => err.details.find((d) => d.field === f)?.issue ?? '';
  const status = of('status') === 'APPROVED' ? 'APPROVED' : 'PENDING';
  return t('lrDuplicate', {
    status: t(`lrStatus${status}`),
    date: formatDate(of('createdAt') || null, lang),
    name: of('requestedBy') || '—',
  });
}

/** Every step of the proposal as one localized line, in order (pure: tested). */
export function reasoningLines(p: Proposal, t: T, lang: Lang): string[] {
  const lines: string[] = [];
  lines.push(
    t('lrStepApp', {
      app: p.app.name,
      conf: t(`lrConf${p.app.confidence}`),
      level: n(p.sourceLevel, lang),
    }),
  );
  const s = p.source;
  if (s.mode === 'MONEY') {
    lines.push(
      t(`lrStepXp${s.xpMethod}`, {
        xp: n(s.xp, lang),
        a: s.xpFrom[0] ? n(s.xpFrom[0].level, lang) : '—',
        b: s.xpFrom[1] ? n(s.xpFrom[1].level, lang) : '—',
      }),
    );
    lines.push(
      t('lrStepCoins', {
        xp: n(s.xp, lang),
        per: n(s.coinsPerXp, lang),
        coins: n(s.sourceCoins, lang),
      }),
    );
    lines.push(
      t('lrStepUsd', {
        coins: n(s.sourceCoins, lang),
        price: n(s.usdPerMillion, lang),
        usd: usd2(s.usd, lang),
      }),
    );
    lines.push(
      t('lrStepKabso', {
        usd: usd2(s.usd, lang),
        kprice: n(s.kabsoUsdPerMillion, lang),
        kcoins: n(s.kabsoCoins, lang),
        points: n(s.kabsoPoints, lang),
      }),
    );
    lines.push(t('lrStepEquivalent', { level: n(s.level, lang) }));
  } else if (s.mode === 'FACTOR') {
    lines.push(
      t('lrStepFactor', {
        level: n(p.sourceLevel, lang),
        factor: n(s.factor, lang),
        result: n(s.level, lang),
      }),
    );
  } else {
    lines.push(t('lrStepNone'));
  }
  const e = p.evidence;
  lines.push(
    t('lrStepFirstDays', {
      days: e.firstDays,
      coins: n(e.firstDaysRechargeCoins, lang),
      cap: p.firstDaysCap,
    }),
  );
  lines.push(t('lrStepTotal', { coins: n(e.totalRechargeCoins, lang), cap: p.totalCap }));
  lines.push(t('lrStepCap', { cap: p.rechargeCap }));
  lines.push(
    t('lrStepBonus', {
      s: e.supportLevel,
      sb: p.supportBonus,
      c: e.charmLevel,
      cb: p.charmBonus,
    }),
  );
  lines.push(
    t('lrStepMin', {
      eq: s.level,
      bonus: p.supportBonus + p.charmBonus,
      cap: p.rechargeCap,
      value: p.beforeClamp,
    }),
  );
  lines.push(
    t('lrStepClamp', {
      current: e.supportLevel,
      max: p.maxLevel,
      proposed: p.proposedLevel,
    }),
  );
  lines.push(t(`lrLimited${p.limitedBy}`));
  return lines;
}

/** The levels the OWNER may approve: from the current level to the proposal (never higher; pure: tested). */
export function approvalBounds(p: Proposal): { min: number; max: number } {
  const min = p.evidence.supportLevel;
  return { min, max: Math.max(min, p.proposedLevel) };
}

/** An entered level kept inside the bounds (the field only lowers; pure: tested). */
export function clampApproval(value: number, b: { min: number; max: number }): number {
  if (!Number.isFinite(value)) return b.max;
  return Math.min(Math.max(Math.trunc(value), b.min), b.max);
}

/** «32:27742536!» lines → table points (`!` = confirmed); null on a malformed line (pure: tested). */
export function parseXpTable(text: string): XpPoint[] | null {
  const out: XpPoint[] = [];
  for (const raw of text.split(/\n/)) {
    const line = raw.trim();
    if (line === '') continue;
    const m = /^(\d{1,3})\s*:\s*(\d{1,16})\s*(!?)$/.exec(line);
    if (!m) return null;
    out.push({
      level: Number(m[1]),
      xp: Number(m[2]),
      confidence: m[3] ? 'CONFIRMED' : 'ESTIMATE',
    });
  }
  return out.sort((a, b) => a.level - b.level);
}

export function formatXpTable(points: XpPoint[]): string {
  return points.map((p) => `${String(p.level)}:${String(p.xp)}${p.confidence === 'CONFIRMED' ? '!' : ''}`).join('\n');
}

export function ConfidenceBadge({ c }: { c: Confidence }) {
  const { t } = useApp();
  return (
    <span className={`badge ${c === 'CONFIRMED' ? 'ok' : 'warn'}`} data-confidence={c}>
      {t(`lrConf${c}`)}
    </span>
  );
}

function StatusChip({ s }: { s: Status }) {
  const { t } = useApp();
  return (
    <span className={`badge ${s === 'APPROVED' ? 'ok' : s === 'REJECTED' ? 'bad' : 'info'}`} data-status={s}>
      {t(`lrStatus${s}`)}
    </span>
  );
}

function appName(a: AppOption | null, fallback: string, lang: Lang): string {
  if (!a || a.isOther) return fallback;
  return lang === 'ar' ? a.nameAr : a.nameEn;
}

/** The requests table (pure rendering: tested). */
export function RequestTable({ rows, canDecide }: { rows: LevelRaise[]; canDecide: boolean }) {
  const { t, lang } = useApp();
  if (rows.length === 0)
    return (
      <p className="muted" data-empty>
        {t('lrNone')}
      </p>
    );
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            <th>{t('lrSupporter')}</th>
            <th>{t('lrSourceApp')}</th>
            <th>{t('lrSourceLevel')}</th>
            <th>{t('lrRequestedBy')}</th>
            <th>{t('lrStatus')}</th>
            <th>{t('lrApproved')}</th>
            <th>{t('lrCreated')}</th>
            {canDecide && <th />}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} data-request={r.id}>
              <td>
                <UserCell
                  username={r.supporter.username}
                  displayName={r.supporter.displayName}
                  avatarUrl={r.supporter.avatarUrl}
                />
              </td>
              <td>
                {appName(r.sourceApp, r.sourceAppName, lang)}{' '}
                {r.sourceApp ? <ConfidenceBadge c={r.sourceApp.confidence} /> : null}
                <div className="muted small">ID {r.sourceAccountId}</div>
                {r.previousRejection ? (
                  <span className="badge warn" data-previously-rejected>
                    {t('lrPreviouslyRejected')}
                  </span>
                ) : null}
              </td>
              <td className="num">{n(r.sourceLevel, lang)}</td>
              <td>
                <UserCell
                  username={r.requestedBy.username}
                  displayName={r.requestedBy.displayName}
                  avatarUrl={r.requestedBy.avatarUrl}
                />
                <div className="muted small">{t('lrVia', { via: t(`lrVia${r.via}`) })}</div>
              </td>
              <td>
                <StatusChip s={r.status} />
              </td>
              <td className="num">{r.approvedLevel ?? '—'}</td>
              <td className="date">{formatDate(r.createdAt, lang)}</td>
              {canDecide && (
                <td>
                  <button className="btn small" onClick={() => navigate(`/level-raises/${r.id}`)}>
                    {t('lrOpen')}
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

interface Check {
  found: boolean;
  supporter: Person | null;
  evidence: Evidence | null;
  openRequest: boolean;
  staffAccount: boolean;
}

function NewRequestDialog({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const { t, lang, toast } = useApp();
  const apps = useAsync(() => api.get<{ data: AppOption[] }>('/admin/level-raises/source-apps'), []);
  const [username, setUsername] = useState('');
  const [check, setCheck] = useState<Check | null>(null);
  const [app, setApp] = useState('');
  const [otherName, setOtherName] = useState('');
  const [accountId, setAccountId] = useState('');
  const [level, setLevel] = useState('');
  const [note, setNote] = useState('');
  const [video, setVideo] = useState<{ id: string; durationMs: number } | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const chosen = apps.data?.data.find((a) => a.code === app) ?? null;
  const levelNum = Number(level);
  // «هل تقصد: …؟» while typing an "other" app's name (debounced).
  useEffect(() => {
    const q = otherName.trim();
    if (!chosen?.isOther || q === '') {
      setSuggestions([]);
      return;
    }
    const timer = setTimeout(() => {
      api.get<{ data: Suggestion[] }>('/admin/level-raises/source-apps/suggest', { q }).then(
        (r) => setSuggestions(r.data),
        () => setSuggestions([]),
      );
    }, 300);
    return () => clearTimeout(timer);
  }, [otherName, chosen?.isOther]);
  const ready =
    check?.found === true &&
    !check.staffAccount &&
    !check.openRequest &&
    chosen !== null &&
    (!chosen.isOther || otherName.trim() !== '') &&
    accountId.trim() !== '' &&
    Number.isInteger(levelNum) &&
    levelNum >= 1 &&
    levelNum <= 999 &&
    video !== null;
  const runCheck = async () => {
    setError(null);
    try {
      setCheck(
        await api.get<Check>('/admin/level-raises/check', {
          username: username.trim(),
        }),
      );
    } catch (e) {
      setError(e);
    }
  };
  const pick = async (file: File | undefined) => {
    if (!file) return;
    setError(null);
    setVideo(null);
    setProgress(0);
    try {
      const up = await uploadLevelRaiseVideo(file, setProgress);
      setVideo({ id: up.videoId, durationMs: up.durationMs });
    } catch (e) {
      setError(e);
    } finally {
      setProgress(null);
    }
  };
  const send = async () => {
    setBusy(true);
    setError(null);
    try {
      await api.post('/admin/level-raises', {
        username: username.trim(),
        sourceApp: app,
        ...(chosen?.isOther ? { sourceAppName: otherName.trim() } : {}),
        sourceAccountId: accountId.trim(),
        sourceLevel: levelNum,
        videoId: video!.id,
        ...(note.trim() ? { note: note.trim() } : {}),
      });
      toast(t('lrSent'));
      onDone();
    } catch (e) {
      setError(e);
      setBusy(false);
    }
  };
  return (
    <Dialog title={t('lrNew')} onClose={onClose}>
      {duplicateText(error, t, lang) ? (
        <div className="alert error" role="alert" data-duplicate>
          {duplicateText(error, t, lang)}
        </div>
      ) : (
        <ErrorAlert error={error} />
      )}
      <div className="field">
        <label htmlFor="lr-user">{t('lrUsername')}</label>
        <div className="row">
          <input
            id="lr-user"
            type="text"
            value={username}
            maxLength={40}
            onChange={(e) => (setUsername(e.target.value), setCheck(null))}
          />
          <button type="button" className="btn" disabled={username.trim() === ''} onClick={() => void runCheck()}>
            {t('lrCheck')}
          </button>
        </div>
        {check && !check.found && <span className="hint bad">{t('lrNotFound')}</span>}
        {check?.staffAccount && <span className="hint bad">{t('lrStaffAccount')}</span>}
        {check?.openRequest && <span className="hint bad">{t('lrOpenExists')}</span>}
        {check?.evidence && <EvidenceList e={check.evidence} />}
      </div>
      <div className="field">
        <label htmlFor="lr-app">{t('lrSourceApp')}</label>
        <select id="lr-app" value={app} onChange={(e) => setApp(e.target.value)}>
          <option value="">—</option>
          {(apps.data?.data ?? []).map((a) => (
            <option key={a.code} value={a.code}>
              {lang === 'ar' ? a.nameAr : a.nameEn} · {t(`lrConf${a.confidence}`)}
            </option>
          ))}
        </select>
      </div>
      {chosen?.isOther && (
        <div className="field">
          <label htmlFor="lr-other">{t('lrSourceAppOther')}</label>
          <input
            id="lr-other"
            type="text"
            value={otherName}
            maxLength={60}
            onChange={(e) => setOtherName(e.target.value)}
          />
          <SuggestionList
            items={suggestions.filter((sg) => !(sg.kind === 'NAME' && sg.name === otherName.trim()))}
            onPick={(sg) => {
              if (sg.kind === 'APP' && sg.app) {
                setApp(sg.app.code);
                setOtherName('');
              } else if (sg.name) setOtherName(sg.name);
              setSuggestions([]);
            }}
          />
        </div>
      )}
      <div className="field">
        <label htmlFor="lr-acc">{t('lrSourceAccountId')}</label>
        <input
          id="lr-acc"
          type="text"
          value={accountId}
          maxLength={64}
          onChange={(e) => setAccountId(e.target.value)}
        />
      </div>
      <div className="field">
        <label htmlFor="lr-level">{t('lrSourceLevel')}</label>
        <input id="lr-level" type="number" min={1} max={999} value={level} onChange={(e) => setLevel(e.target.value)} />
      </div>
      <div className="field">
        <label htmlFor="lr-video">{t('lrVideo')}</label>
        <input
          id="lr-video"
          type="file"
          accept="video/mp4,video/quicktime"
          onChange={(e) => void pick(e.target.files?.[0])}
        />
        <span className="hint">
          {progress !== null
            ? t('lrVideoUploading', { pct: Math.round(progress * 100) })
            : video
              ? t('lrVideoReady', { s: Math.round(video.durationMs / 1000) })
              : t('lrVideoHint')}
        </span>
      </div>
      <div className="field">
        <label htmlFor="lr-note">{t('lrNote')}</label>
        <textarea id="lr-note" maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} />
      </div>
      <div className="actions">
        <button type="button" className="btn" onClick={onClose}>
          {t('cancel')}
        </button>
        <button type="button" className="btn primary" disabled={!ready || busy} onClick={() => void send()}>
          {t('lrSend')}
        </button>
      </div>
    </Dialog>
  );
}

/** «هل تقصد: …؟» — tapping one picks that app or that name (pure rendering: tested). */
export function SuggestionList({ items, onPick }: { items: Suggestion[]; onPick: (s: Suggestion) => void }) {
  const { t, lang } = useApp();
  if (items.length === 0) return null;
  return (
    <div className="row wrap" data-suggestions>
      {items.map((sg) => (
        <button
          key={`${sg.kind}:${sg.app?.code ?? sg.name ?? ''}`}
          type="button"
          className="btn small ghost"
          data-suggestion={sg.app?.code ?? sg.name ?? ''}
          onClick={() => onPick(sg)}
        >
          {t('lrDidYouMean', { name: suggestionLabel(sg, lang) })}
          {sg.app ? ` · ${t(`lrConf${sg.app.confidence}`)}` : ''}
        </button>
      ))}
    </div>
  );
}

/** The supporter's recharge and levels (pure rendering: tested). */
export function EvidenceList({ e }: { e: Evidence }) {
  const { t, lang } = useApp();
  return (
    <dl className="kv" data-evidence>
      <dt>{t('lrTotalRecharge')}</dt>
      <dd data-total>{n(e.totalRechargeCoins, lang)}</dd>
      <dt>{t('lrFirstDaysRecharge', { days: e.firstDays })}</dt>
      <dd data-first-days>{n(e.firstDaysRechargeCoins, lang)}</dd>
      <dt>{t('lrSupportLevel')}</dt>
      <dd data-support>{e.supportLevel}</dd>
      <dt>{t('lrCharmLevel')}</dt>
      <dd data-charm>{e.charmLevel}</dd>
      <dt />
      <dd>
        <span className={`badge ${e.eligible ? 'ok' : 'bad'}`} data-eligible={e.eligible}>
          {e.eligible
            ? t('lrEligible', { min: n(e.minRechargeCoins, lang) })
            : t('lrNotEligible', { min: n(e.minRechargeCoins, lang) })}
        </span>
      </dd>
    </dl>
  );
}

const STATUSES: (Status | null)[] = [null, 'PENDING', 'APPROVED', 'REJECTED'];

/** «طلبات رفع الليفيل». */
export function LevelRaises() {
  const { t, can } = useApp();
  const [status, setStatus] = useState<Status | null>('PENDING');
  const [creating, setCreating] = useState(false);
  const list = useAsync(
    () => api.get<{ data: LevelRaise[] }>('/admin/level-raises', status ? { status } : {}),
    [status],
  );
  return (
    <div className="page" data-page="level-raises">
      <h1>{t('navLevelRaises')}</h1>
      <p className="muted">{t('lrIntro')}</p>
      <div className="row">
        <div className="segmented wrap" role="group">
          {STATUSES.map((s) => (
            <button key={s ?? 'all'} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
              {s ? t(`lrStatus${s}`) : t('lrAll')}
            </button>
          ))}
        </div>
        {can('levels.raise.request') && (
          <button className="btn primary" onClick={() => setCreating(true)}>
            {t('lrNew')}
          </button>
        )}
      </div>
      <ErrorAlert error={list.error} />
      {list.loading || !list.data ? (
        <Loading />
      ) : (
        <RequestTable rows={list.data.data} canDecide={can('levels.raise.decide')} />
      )}
      {creating && (
        <NewRequestDialog
          onClose={() => setCreating(false)}
          onDone={() => {
            setCreating(false);
            list.reload();
          }}
        />
      )}
    </div>
  );
}

/** «حُذف الفيديو بعد القرار» with the evidence kept (pure rendering: tested). */
export function VideoDeleted({ r }: { r: LevelRaise }) {
  const { t, lang } = useApp();
  return (
    <div className="muted" data-video-deleted>
      <p className="strong">{t('lrVideoDeleted')}</p>
      <p className="small">
        {t('lrVideoEvidence', {
          id: r.video.id,
          s: Math.round((r.video.durationMs ?? 0) / 1000),
          mb: (r.video.byteSize / (1024 * 1024)).toFixed(1),
          date: formatDate(r.video.deletedAt, lang),
        })}
      </p>
    </div>
  );
}

/** «سبق رفض طلب بنفس الحساب»: the earlier rejection of the same source account (pure rendering: tested). */
export function PreviousRejection({ pr }: { pr: NonNullable<LevelRaise['previousRejection']> }) {
  const { t, lang } = useApp();
  return (
    <div className="card" data-previous-rejection={pr.id}>
      <h2>
        <span className="badge warn">{t('lrPreviouslyRejected')}</span>
      </h2>
      <p>
        {t('lrPreviousRejectionLine', {
          date: formatDate(pr.decidedAt ?? pr.createdAt, lang),
          name: pr.requestedBy.displayName,
          reason: pr.rejectReason ?? '—',
        })}
      </p>
    </div>
  );
}

/** The proposal card: the level, what decided it and every step (pure rendering: tested). */
export function ProposalCard({ p }: { p: Proposal }) {
  const { t, lang } = useApp();
  return (
    <div className="card" data-proposal={p.proposedLevel}>
      <h2>
        {t('lrProposal')}:{' '}
        <span className="strong" data-proposed>
          {p.proposedLevel}
        </span>{' '}
        <ConfidenceBadge c={p.app.confidence} />
      </h2>
      <h3 className="small">{t('lrReasoning')}</h3>
      <ol className="small" data-reasoning>
        {reasoningLines(p, t, lang).map((line, i) => (
          <li key={i}>{line}</li>
        ))}
      </ol>
    </div>
  );
}

/** Approve at the proposal or lower (the number field can only go down from the proposal; pure-ish: tested). */
export function ApproveForm({
  p,
  onApprove,
}: {
  p: Proposal;
  onApprove: (level: number, reason: string) => Promise<unknown>;
}) {
  const { t } = useApp();
  const bounds = approvalBounds(p);
  const [value, setValue] = useState(bounds.max);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  return (
    <div className="card" data-approve>
      <ErrorAlert error={error} />
      <div className="field">
        <label htmlFor="lr-approve">{t('lrApproveAt')}</label>
        <input
          id="lr-approve"
          type="number"
          min={bounds.min}
          max={bounds.max}
          value={value}
          onChange={(e) => setValue(clampApproval(Number(e.target.value), bounds))}
        />
        <span className="hint">{t('lrApproveHint', { min: bounds.min, max: bounds.max })}</span>
      </div>
      <div className="field">
        <label htmlFor="lr-approve-reason">{t('lrApproveReason')}</label>
        <input
          id="lr-approve-reason"
          type="text"
          maxLength={500}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />
      </div>
      <button
        className="btn primary"
        disabled={!p.eligible || busy}
        onClick={() => {
          setBusy(true);
          setError(null);
          onApprove(clampApproval(value, bounds), reason.trim()).catch((e: unknown) => {
            setError(e);
            setBusy(false);
          });
        }}
      >
        {t('lrApprove')}
      </button>
    </div>
  );
}

/** A request's review (OWNER). */
export function LevelRaiseDetail({ id }: { id: string }) {
  const { t, lang, toast } = useApp();
  const detail = useAsync(() => api.get<Detail>(`/admin/level-raises/${id}`), [id]);
  const [rejecting, setRejecting] = useState(false);
  if (detail.error) return <ErrorAlert error={detail.error} />;
  if (detail.loading || !detail.data) return <Loading />;
  const { request: r, proposal: p, evidence } = detail.data;
  return (
    <div className="page" data-page="level-raise" data-status={r.status}>
      <h1>
        {t('navLevelRaises')} · @{r.supporter.username} <StatusChip s={r.status} />
      </h1>
      <div className="grid">
        <div className="card">
          {r.video.deletedAt ? (
            <VideoDeleted r={r} />
          ) : (
            <video
              controls
              preload="metadata"
              src={`/api/v1/admin/level-raises/${r.id}/video`}
              style={{ width: '100%', maxHeight: 480 }}
              data-video
            />
          )}
        </div>
        <div className="card">
          <dl className="kv">
            <dt>{t('lrSupporter')}</dt>
            <dd>
              <UserCell
                username={r.supporter.username}
                displayName={r.supporter.displayName}
                avatarUrl={r.supporter.avatarUrl}
              />
            </dd>
            <dt>{t('lrSourceApp')}</dt>
            <dd>
              {appName(r.sourceApp, r.sourceAppName, lang)}{' '}
              {r.sourceApp ? <ConfidenceBadge c={r.sourceApp.confidence} /> : null}
            </dd>
            <dt>{t('lrSourceAccountId')}</dt>
            <dd data-account>{r.sourceAccountId}</dd>
            <dt>{t('lrSourceLevel')}</dt>
            <dd>{r.sourceLevel}</dd>
            <dt>{t('lrRequestedBy')}</dt>
            <dd>
              {r.requestedBy.displayName} (@{r.requestedBy.username}) · {t('lrVia', { via: t(`lrVia${r.via}`) })} ·{' '}
              {formatDate(r.createdAt, lang)}
            </dd>
            {r.note && (
              <>
                <dt>{t('lrNote')}</dt>
                <dd>{r.note}</dd>
              </>
            )}
          </dl>
          <h2 className="small">{t('lrEvidence')}</h2>
          <EvidenceList e={evidence} />
        </div>
      </div>
      {r.previousRejection && <PreviousRejection pr={r.previousRejection} />}
      {p && <ProposalCard p={p} />}
      {r.status === 'PENDING' && p ? (
        <>
          <ApproveForm
            p={p}
            onApprove={async (level, reason) => {
              await api.post(`/admin/level-raises/${r.id}/approve`, {
                level,
                ...(reason ? { reason } : {}),
              });
              toast(t('lrApprovedToast'));
              detail.reload();
            }}
          />
          <button className="btn danger" onClick={() => setRejecting(true)}>
            {t('lrReject')}
          </button>
        </>
      ) : (
        <div className="card" data-decision>
          <h2>{t('lrDecided')}</h2>
          <p>
            <StatusChip s={r.status} /> {r.decidedBy ? t('lrDecidedBy', { name: r.decidedBy.displayName }) : ''} ·{' '}
            {formatDate(r.decidedAt, lang)}
          </p>
          {r.status === 'APPROVED' && (
            <p data-before-after>
              {t('lrApproved')}: {r.approvedLevel} —{' '}
              {t('lrBeforeAfter', {
                before: r.levelBefore ?? 0,
                after: r.levelAfter ?? 0,
              })}
            </p>
          )}
          {r.rejectReason && <p data-reject-reason>{t('lrRejectReasonShown', { reason: r.rejectReason })}</p>}
        </div>
      )}
      {rejecting && (
        <FormDialog
          title={t('lrReject')}
          fields={[{ ...reasonField(t, t('lrRejectReason')) }]}
          confirmLabel={t('lrReject')}
          danger
          submit={(v) => api.post(`/admin/level-raises/${r.id}/reject`, { reason: v.reason })}
          onClose={() => setRejecting(false)}
          onDone={() => {
            setRejecting(false);
            toast(t('lrRejectedToast'));
            detail.reload();
          }}
        />
      )}
    </div>
  );
}

/** The source-app table with confidence labels (pure rendering: tested). */
export function AppsTable({ rows, onEdit }: { rows: SourceApp[]; onEdit?: (a: SourceApp) => void }) {
  const { t, lang } = useApp();
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            <th>{t('lrSourceApp')}</th>
            <th>{t('lrAppConfidence')}</th>
            <th>{t('lrAppMode')}</th>
            <th>{t('lrAppPrice')}</th>
            <th>{t('lrAppCoinsPerXp')}</th>
            <th>{t('lrAppTable')}</th>
            <th>{t('lrAppFactor')}</th>
            {onEdit && <th />}
          </tr>
        </thead>
        <tbody>
          {rows.map((a) => (
            <tr key={a.id} data-app={a.code} className={a.enabled ? undefined : 'muted'}>
              <td>
                <span className="strong">{lang === 'ar' ? a.nameAr : a.nameEn}</span>
                <div className="muted small">
                  {a.code}
                  {a.isOther ? ` · ${t('lrAppOther')}` : ''}
                </div>
                {a.aliases.length > 0 ? (
                  <div className="small" data-aliases>
                    {t('lrAppAliases')}: {a.aliases.join('، ')}
                  </div>
                ) : null}
                <div className="small" style={{ maxWidth: 420, whiteSpace: 'normal' }} data-source>
                  {a.sourceNote}
                  {a.sourceUrl ? (
                    <div>
                      <a href={a.sourceUrl} target="_blank" rel="noreferrer noopener">
                        {a.sourceUrl}
                      </a>
                    </div>
                  ) : null}
                  {a.sourceDate ? <div className="muted">{a.sourceDate}</div> : null}
                </div>
              </td>
              <td>
                <ConfidenceBadge c={a.confidence} />
              </td>
              <td>{t(`lrMode${a.mode}`)}</td>
              <td className="num">{a.usdPerMillion === null ? '—' : `$${n(a.usdPerMillion, lang)}`}</td>
              <td className="num">{a.coinsPerXp === null ? '—' : n(a.coinsPerXp, lang)}</td>
              <td className="small">
                {a.xpTable.length === 0
                  ? '—'
                  : a.xpTable.map((p) => (
                      <div key={p.level}>
                        Lv.{p.level}: {n(p.xp, lang)} XP <ConfidenceBadge c={p.confidence} />
                      </div>
                    ))}
              </td>
              <td className="num">{a.factor === null ? '—' : `× ${n(a.factor, lang)}`}</td>

              {onEdit && (
                <td>
                  <button className="btn small" data-edit={a.code} onClick={() => onEdit(a)}>
                    {t('lrAppEdit')}
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function AppDialog({ app, onClose, onDone }: { app: SourceApp | null; onClose: () => void; onDone: () => void }) {
  const { t, toast } = useApp();
  const [f, setF] = useState({
    code: app?.code ?? '',
    nameAr: app?.nameAr ?? '',
    nameEn: app?.nameEn ?? '',
    mode: app?.mode ?? ('FACTOR' as 'MONEY' | 'FACTOR'),
    usdPerMillion: app?.usdPerMillion?.toString() ?? '',
    coinsPerXp: app?.coinsPerXp?.toString() ?? '',
    table: formatXpTable(app?.xpTable ?? []),
    factor: app?.factor?.toString() ?? '0.5',
    confidence: app?.confidence ?? ('ESTIMATE' as Confidence),
    sourceNote: app?.sourceNote ?? '',
    sourceUrl: app?.sourceUrl ?? '',
    sourceDate: app?.sourceDate ?? '',
    aliases: (app?.aliases ?? []).join('\n'),
    enabled: app?.enabled ?? true,
    reason: '',
  });
  const [error, setError] = useState<unknown>(null);
  const set = (k: keyof typeof f, v: string | boolean) => setF((x) => ({ ...x, [k]: v }));
  const table = parseXpTable(f.table);
  const save = async () => {
    setError(null);
    const num = (v: string) => (v.trim() === '' ? null : Number(v));
    const body = {
      nameAr: f.nameAr.trim(),
      nameEn: f.nameEn.trim(),
      mode: f.mode,
      usdPerMillion: num(f.usdPerMillion),
      coinsPerXp: num(f.coinsPerXp),
      xpTable: table ?? [],
      factor: num(f.factor),
      confidence: f.confidence,
      sourceNote: f.sourceNote.trim(),
      sourceUrl: f.sourceUrl.trim() || null,
      sourceDate: f.sourceDate.trim() || null,
      aliases: f.aliases
        .split(/[\n،,]/)
        .map((x) => x.trim())
        .filter((x) => x !== ''),
      enabled: f.enabled,
      reason: f.reason.trim(),
    };
    try {
      if (app) await api.put(`/admin/level-raise/apps/${app.id}`, body);
      else
        await api.post('/admin/level-raise/apps', {
          ...body,
          code: f.code.trim().toUpperCase(),
        });
      toast(t('lrAppSaved'));
      onDone();
    } catch (e) {
      setError(e);
    }
  };
  const text = (k: keyof typeof f, label: string, extra: Record<string, unknown> = {}) => (
    <div className="field">
      <label htmlFor={`lra-${k}`}>{label}</label>
      <input id={`lra-${k}`} type="text" value={String(f[k])} onChange={(e) => set(k, e.target.value)} {...extra} />
    </div>
  );
  return (
    <Dialog title={app ? t('lrAppEdit') : t('lrAppAdd')} onClose={onClose}>
      <ErrorAlert error={error} />
      {!app && text('code', t('lrAppCode'), { maxLength: 32 })}
      {text('nameAr', t('lrAppNameAr'), { maxLength: 60 })}
      {text('nameEn', t('lrAppNameEn'), { maxLength: 60 })}
      <div className="field">
        <label htmlFor="lra-mode">{t('lrAppMode')}</label>
        <select id="lra-mode" value={f.mode} onChange={(e) => set('mode', e.target.value)}>
          <option value="MONEY">{t('lrModeMONEY')}</option>
          <option value="FACTOR">{t('lrModeFACTOR')}</option>
        </select>
      </div>
      {text('usdPerMillion', t('lrAppPrice'), { inputMode: 'decimal' })}
      {text('coinsPerXp', t('lrAppCoinsPerXp'), { inputMode: 'decimal' })}
      <div className="field">
        <label htmlFor="lra-table">{t('lrAppTable')}</label>
        <textarea id="lra-table" value={f.table} onChange={(e) => set('table', e.target.value)} />
        <span className={`hint ${table === null ? 'bad' : ''}`}>{t('lrAppTableHint')}</span>
      </div>
      {text('factor', t('lrAppFactor'), { inputMode: 'decimal' })}
      <div className="field">
        <label htmlFor="lra-conf">{t('lrAppConfidence')}</label>
        <select id="lra-conf" value={f.confidence} onChange={(e) => set('confidence', e.target.value)}>
          <option value="ESTIMATE">{t('lrConfESTIMATE')}</option>
          <option value="CONFIRMED">{t('lrConfCONFIRMED')}</option>
        </select>
      </div>
      <div className="field">
        <label htmlFor="lra-note">{t('lrAppSource')}</label>
        <textarea
          id="lra-note"
          maxLength={1000}
          value={f.sourceNote}
          onChange={(e) => set('sourceNote', e.target.value)}
        />
      </div>
      {text('sourceUrl', t('lrAppSourceUrl'), { maxLength: 500 })}
      {text('sourceDate', t('lrAppSourceDate'), { type: 'date' })}
      <div className="field">
        <label htmlFor="lra-aliases">{t('lrAppAliases')}</label>
        <textarea id="lra-aliases" value={f.aliases} onChange={(e) => set('aliases', e.target.value)} />
        <span className="hint">{t('lrAppAliasesHint')}</span>
      </div>
      <label className="row">
        <input type="checkbox" checked={f.enabled} onChange={(e) => set('enabled', e.target.checked)} />{' '}
        {t('lrAppEnabled')}
      </label>
      <div className="field">
        <label htmlFor="lra-reason">{t('reason')}</label>
        <textarea id="lra-reason" maxLength={500} value={f.reason} onChange={(e) => set('reason', e.target.value)} />
      </div>
      <div className="actions">
        <button type="button" className="btn" onClick={onClose}>
          {t('cancel')}
        </button>
        <button
          type="button"
          className="btn primary"
          disabled={table === null || f.reason.trim() === ''}
          onClick={() => void save()}
        >
          {t('lrSave')}
        </button>
      </div>
    </Dialog>
  );
}

/** «بيانات التطبيقات» (OWNER). */
export function LevelRaiseApps() {
  const { t } = useApp();
  const list = useAsync(() => api.get<{ data: SourceApp[] }>('/admin/level-raise/apps'), []);
  const [editing, setEditing] = useState<SourceApp | 'new' | null>(null);
  return (
    <div className="page" data-page="level-raise-apps">
      <h1>{t('navLevelRaiseApps')}</h1>
      <p className="muted">{t('lrAppsIntro')}</p>
      <button className="btn primary" onClick={() => setEditing('new')}>
        {t('lrAppAdd')}
      </button>
      <ErrorAlert error={list.error} />
      {list.loading || !list.data ? <Loading /> : <AppsTable rows={list.data.data} onEdit={setEditing} />}
      {editing && (
        <AppDialog
          app={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onDone={() => {
            setEditing(null);
            list.reload();
          }}
        />
      )}
    </div>
  );
}

/** The settings that changed, as the API's body (pure: tested). */
export function settingChanges(
  saved: Settings,
  draft: Record<SettingKey, string>,
): Partial<Record<SettingKey, number>> | null {
  const out: Partial<Record<SettingKey, number>> = {};
  for (const k of SETTING_KEYS) {
    const v = Number(draft[k]);
    if (draft[k].trim() === '' || !Number.isFinite(v)) return null;
    if (v !== saved[k]) out[k] = v;
  }
  return out;
}

/** «إعدادات الاقتراح» (OWNER). */
export function LevelRaiseSettingsPage() {
  const { t, lang } = useApp();
  const view = useAsync(() => api.get<SettingsView>('/admin/level-raise/settings'), []);
  if (view.error) return <ErrorAlert error={view.error} />;
  if (view.loading || !view.data) return <Loading />;
  return <SettingsForm key={view.data.updatedAt} view={view.data} lang={lang} t={t} onSaved={view.reload} />;
}

function SettingsForm({ view, lang, t, onSaved }: { view: SettingsView; lang: Lang; t: T; onSaved: () => void }) {
  const { toast } = useApp();
  const [draft, setDraft] = useState<Record<SettingKey, string>>(
    Object.fromEntries(SETTING_KEYS.map((k) => [k, String(view.settings[k])])) as Record<SettingKey, string>,
  );
  const [confirm, setConfirm] = useState(false);
  const changes = settingChanges(view.settings, draft);
  return (
    <div className="page" data-page="level-raise-settings">
      <h1>{t('navLevelRaiseSettings')}</h1>
      <p className="muted">{t('lrSettingsIntro')}</p>
      <div className="card">
        {SETTING_KEYS.map((k) => (
          <div className="field" key={k}>
            <label htmlFor={`lrs-${k}`}>{t(`lrSet${k}`)}</label>
            <input
              id={`lrs-${k}`}
              type="number"
              step="any"
              value={draft[k]}
              onChange={(e) => setDraft((d) => ({ ...d, [k]: e.target.value }))}
            />
            <span className="hint">{t('lrDefault', { v: n(view.defaults[k], lang) })}</span>
          </div>
        ))}
        <p className="muted small">{t('lrMaxFixed', { p: n(view.settings.kabsoUsdPerMillion, lang) })}</p>
        <button
          className="btn primary"
          disabled={changes === null || Object.keys(changes).length === 0}
          onClick={() => setConfirm(true)}
        >
          {t('lrSave')}
        </button>
      </div>
      {confirm && changes && (
        <FormDialog
          title={t('navLevelRaiseSettings')}
          fields={[reasonField(t)]}
          confirmLabel={t('lrSave')}
          submit={(v) =>
            api.put('/admin/level-raise/settings', {
              ...changes,
              reason: v.reason,
            })
          }
          onClose={() => setConfirm(false)}
          onDone={() => {
            setConfirm(false);
            toast(t('lrSaved'));
            onSaved();
          }}
        />
      )}
    </div>
  );
}
