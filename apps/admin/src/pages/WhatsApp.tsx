import { useCallback, useEffect, useRef, useState } from 'react';
import { api, ApiError, uploadWhatsAppMedia } from '../api';
import { Avatar, Dialog, ErrorAlert, FormDialog, Loading, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Key } from '../i18n';
import { navigate, useLocation } from '../router';
import type {
  WaAgent,
  WaAssignment,
  WaConversation,
  WaMessage,
  WaNote,
  WaQuickReply,
  WaStaffRef,
  WaStatus,
  WaSummary,
  WaTemplate,
  WaTestResult,
  WaDepartment,
} from '../types';
import { WA_DEPARTMENTS } from '../types';
import './whatsapp.css';

/**
 * D355 (v1.116-social, CONVENTIONS §10.151): «واتساب» in the panel — the same inbox as the staff's app, as a desktop
 * layout: the conversation list (unassigned / mine / all / closed, search), the chat (bubbles, media, voice, ticks, the
 * 24-hour window — closed → «إرسال قالب» only) and the customer panel (the linked Kabso account, internal notes, the
 * assignment history). Plus «إعدادات واتساب» (status, the webhook address, «اختبار الاتصال») and the quick replies. The
 * pure views are exported for the tests; nothing here is a fixture — every list comes from `/admin/whatsapp/*`.
 */

const BASE = '/admin/whatsapp';
type Filter = 'unassigned' | 'mine' | 'all' | 'closed';
const FILTERS: { f: Filter; key: Key }[] = [
  { f: 'unassigned', key: 'waFilterUnassigned' },
  { f: 'mine', key: 'waFilterMine' },
  { f: 'all', key: 'waFilterAll' },
  { f: 'closed', key: 'waFilterClosed' },
];
type T = ReturnType<typeof useApp>['t'];
type Page<X> = { data: X[]; page: { nextCursor: string | null; hasMore: boolean } };

/** «WhatsApp changed» — the nav badge and the list reload at once. */
export const WA_CHANGED = 'kabso:wa-changed';
const changed = () => window.dispatchEvent(new Event(WA_CHANGED));

/** The nav badge's number (hidden at 0, «99+» above 99). */
export function waBadgeText(n: number): string | null {
  if (!Number.isFinite(n) || n <= 0) return null;
  return n > 99 ? '99+' : String(Math.floor(n));
}

/** The badge: polled every 30 s and on every change; null when WhatsApp is off or the role has no access. */
export function useWhatsAppBadge(enabled: boolean, path: string): number | null {
  const [n, setN] = useState<number | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    const load = () =>
      api.get<WaSummary>(`${BASE}/summary`).then(
        (s) => live && setN(s.enabled ? s.badge : null),
        () => undefined,
      );
    void load();
    const h = window.setInterval(load, 30_000);
    window.addEventListener(WA_CHANGED, load);
    return () => {
      live = false;
      window.clearInterval(h);
      window.removeEventListener(WA_CHANGED, load);
    };
  }, [enabled, path]);
  return enabled ? n : null;
}

/** D366 (§10.159): a department's name. */
export function departmentName(t: T, d: WaDepartment | null | undefined): string {
  return t(`waDept${d ?? 'GENERAL'}` as Key);
}

/** D366: the department tag (inbox rows, the chat head). */
export function DepartmentTag({ d }: { d: WaDepartment | undefined }) {
  const { t } = useApp();
  const name = departmentName(t, d);
  return (
    <span className="tag dept" data-wa-department={d ?? 'GENERAL'} title={`${t('waDeptFilter')}: ${name}`}>
      {name}
    </span>
  );
}

/** D366: who has it — a person, me, the unassigned queue (named by its department unless GENERAL), or closed. */
export function ownerText(t: T, c: WaConversation): string {
  if (c.status === 'CLOSED') return t('waClosed');
  if (c.assignedTo) return c.assignedToMe ? t('waAssignedToMe') : t('waAssignedTo', { name: staffName(t, c.assignedTo) });
  return c.department && c.department !== 'GENERAL'
    ? t('waQueueOf', { department: departmentName(t, c.department) })
    : t('waUnassigned');
}

export function staffName(t: T, s: WaStaffRef | null): string {
  if (!s) return t('waSomeone');
  return s.displayName ?? s.staffId ?? t('waSomeone');
}

/** The error of a send / an action in words (the server's codes of §10.151.4). */
export function waErrorText(t: T, e: unknown): string | null {
  if (!(e instanceof ApiError)) return null;
  switch (e.code) {
    case 'WHATSAPP_WINDOW_CLOSED':
      return t('waErrWindow');
    case 'WHATSAPP_CONVERSATION_ASSIGNED':
      return t('waErrAssigned');
    case 'WHATSAPP_CONVERSATION_CLOSED':
      return t('waErrClosed');
    case 'WHATSAPP_SEND_FAILED':
      return t('waErrSend', { issue: e.details[0]?.issue ?? String(e.status) });
    default:
      return null;
  }
}

function WaError({ error }: { error: unknown }) {
  const { t } = useApp();
  const own = waErrorText(t, error);
  if (!error) return null;
  return own ? (
    <div className="alert error" role="alert">
      {own}
    </div>
  ) : (
    <ErrorAlert error={error} />
  );
}

/** A phone number always reads left to right inside Arabic. */
function Phone({ value }: { value: string }) {
  return (
    <bdi dir="ltr" className="wa-phone">
      {value}
    </bdi>
  );
}

// ---- the list ------------------------------------------------------------------------------------------------------

export function WaConversationList({
  items,
  selected,
  onOpen,
}: {
  items: WaConversation[];
  selected: string | null;
  onOpen: (id: string) => void;
}) {
  const { t, lang } = useApp();
  if (items.length === 0) return <p className="muted wa-empty">{t('waEmptyList')}</p>;
  return (
    <ul className="wa-list" role="list">
      {items.map((c) => (
        <li key={c.id}>
          <button
            type="button"
            className={`wa-row${c.id === selected ? ' active' : ''}${c.unreadCount > 0 ? ' unread' : ''}`}
            aria-current={c.id === selected ? 'true' : undefined}
            onClick={() => onOpen(c.id)}
            data-wa-row={c.id}
          >
            <span className="wa-row-top">
              <span className="wa-row-name">{c.name ?? <Phone value={c.phone} />}</span>
              <span className="wa-row-time muted small">{formatDate(c.lastMessageAt, lang)}</span>
            </span>
            <span className="wa-row-bottom">
              <span className="wa-row-preview muted">{c.lastPreview ?? ''}</span>
              {c.unreadCount > 0 && (
                <span className="wa-unread" aria-label={t('waUnread', { count: c.unreadCount })}>
                  {formatNumber(c.unreadCount, lang)}
                </span>
              )}
            </span>
            <span className="wa-row-tags small">
              {c.status === 'CLOSED' ? (
                <span className="tag">{t('waClosed')}</span>
              ) : c.assignedTo ? (
                <span className={`tag${c.assignedToMe ? ' mine' : ''}`}>
                  {c.assignedToMe ? t('waAssignedToMe') : t('waAssignedTo', { name: staffName(t, c.assignedTo) })}
                </span>
              ) : (
                <span className="tag open">{ownerText(t, c)}</span>
              )}
              <DepartmentTag d={c.department} />
            </span>
          </button>
        </li>
      ))}
    </ul>
  );
}

// ---- the chat ------------------------------------------------------------------------------------------------------

const STATUS_KEY: Partial<Record<WaMessage['status'], Key>> = {
  SENT: 'waStatusSent',
  DELIVERED: 'waStatusDelivered',
  READ: 'waStatusRead',
  FAILED: 'waStatusFailed',
};

/** ✓ sent, ✓✓ delivered, blue ✓✓ read, ! failed. */
export function Ticks({ status }: { status: WaMessage['status'] }) {
  const { t } = useApp();
  const key = STATUS_KEY[status];
  if (!key) return null;
  const glyph = status === 'SENT' ? '✓' : status === 'FAILED' ? '!' : '✓✓';
  return (
    <span className={`wa-ticks ${status.toLowerCase()}`} title={t(key)} aria-label={t(key)}>
      {glyph}
    </span>
  );
}

function MediaPart({ m }: { m: WaMessage }) {
  const { t } = useApp();
  if (!m.media) return null;
  const src = `/api/v1${BASE}/messages/${encodeURIComponent(m.id)}/media`;
  if (m.media.state === 'TOO_LARGE') return <p className="wa-media-note">{t('waMediaTooLarge')}</p>;
  if (m.media.state === 'TYPE_REFUSED') return <p className="wa-media-note">{t('waMediaRefused')}</p>;
  if (m.media.state === 'FAILED') return <p className="wa-media-note">{t('waMediaFailed')}</p>;
  if (m.type === 'IMAGE' || m.type === 'STICKER') {
    return (
      <a href={src} target="_blank" rel="noreferrer">
        <img className="wa-image" src={src} alt="" loading="lazy" />
      </a>
    );
  }
  if (m.type === 'AUDIO') {
    return (
      <span className="wa-audio">
        <span className="small muted">{m.media.voice ? t('waVoice') : (m.media.filename ?? '')}</span>
        <audio controls preload="none" src={src} />
      </span>
    );
  }
  if (m.type === 'VIDEO') return <video className="wa-video" controls preload="none" src={src} />;
  return (
    <a className="wa-doc" href={src} target="_blank" rel="noreferrer">
      📄 <bdi>{m.media.filename ?? t('waMediaStored')}</bdi>
    </a>
  );
}

export function WaBubble({ m }: { m: WaMessage }) {
  const { t, lang } = useApp();
  const out = m.direction === 'OUTBOUND';
  return (
    <div className={`wa-bubble ${out ? 'out' : 'in'}`} data-wa-msg={m.id}>
      {m.template && <p className="wa-template-tag small">{t('waTemplateSent', { name: m.template.name })}</p>}
      <MediaPart m={m} />
      {m.location && (
        <p>
          📍 {m.location.name ?? t('waLocation')}{' '}
          <a
            href={`https://www.openstreetmap.org/?mlat=${m.location.latitude}&mlon=${m.location.longitude}#map=16/${m.location.latitude}/${m.location.longitude}`}
            target="_blank"
            rel="noreferrer"
          >
            {t('waOpenMap')}
          </a>
        </p>
      )}
      {m.type === 'UNSUPPORTED' && <p className="muted">{t('waUnsupported')}</p>}
      {m.text && <p className="wa-text" dir="auto">{m.text}</p>}
      {m.error && <p className="wa-error small">{m.error.title ?? m.error.code}</p>}
      <span className="wa-meta small">
        {out && m.sentBy && <span>{t('waSentBy', { name: staffName(t, m.sentBy) })} · </span>}
        <span>{formatDate(m.at, lang)}</span>
        {out && <Ticks status={m.status} />}
      </span>
      {m.reaction && <span className="wa-reaction">{m.reaction}</span>}
    </div>
  );
}

/** The 24-hour window banner (§10.151.4). */
export function WindowBanner({ c }: { c: WaConversation }) {
  const { t, lang } = useApp();
  if (c.status === 'CLOSED') return null;
  if (c.window.open && c.window.closesAt) {
    return <p className="wa-window open small">{t('waWindowOpen', { time: formatDate(c.window.closesAt, lang) })}</p>;
  }
  return (
    <p className="wa-window closed" role="status">
      {t(c.window.closesAt ? 'waWindowClosed' : 'waWindowNever')}
    </p>
  );
}

/** The chat column without its data loading (the tests render it). */
export function WaChatView({
  c,
  messages,
  onAction,
  composer,
}: {
  c: WaConversation;
  messages: WaMessage[];
  onAction: (a: 'claim' | 'release' | 'close' | 'reopen' | 'transfer') => void;
  composer: React.ReactNode;
}) {
  const { t, can } = useApp();
  const manage = can('support.whatsapp.manage');
  // v1.120-social (D360): the WhatsApp level VIEW reads only — no action, no composer, «مشاهدة فقط».
  const reply = can('support.whatsapp');
  const mineOrFree = c.assignedTo === null || c.assignedToMe;
  return (
    <section className="wa-chat" aria-label={c.name ?? c.phone} data-view-only={reply ? undefined : 'true'}>
      <header className="wa-chat-head">
        <div>
          <h2>
            {c.name ?? <Phone value={c.phone} />}{' '}
            {!reply && (
              <span className="badge warn" data-wa-view-only title={t('waViewOnlyHint')}>
                {t('waViewOnly')}
              </span>
            )}
          </h2>
          <p className="muted small">
            <Phone value={c.phone} /> · {ownerText(t, c)} <DepartmentTag d={c.department} />
          </p>
        </div>
        {reply && (
        <div className="wa-actions">
          {c.status === 'OPEN' && c.assignedTo === null && (
            <button className="btn primary small" onClick={() => onAction('claim')}>
              {t('waClaim')}
            </button>
          )}
          {c.status === 'OPEN' && c.assignedTo !== null && (c.assignedToMe || manage) && (
            <button className="btn small" onClick={() => onAction('release')}>
              {t('waRelease')}
            </button>
          )}
          {c.status === 'OPEN' && (mineOrFree || manage) && (
            <button className="btn small" data-wa-transfer title={t('waTransfer')} onClick={() => onAction('transfer')}>
              ⇄ {t('waTransfer')}
            </button>
          )}
          {c.status === 'OPEN' && (mineOrFree || manage) && (
            <button className="btn small" onClick={() => onAction('close')}>
              {t('waClose')}
            </button>
          )}
          {c.status === 'CLOSED' && (
            <button className="btn small" onClick={() => onAction('reopen')}>
              {t('waReopen')}
            </button>
          )}
        </div>
        )}
      </header>
      <WindowBanner c={c} />
      <div className="wa-messages" aria-live="polite">
        {[...messages].reverse().map((m) => (
          <WaBubble key={m.id} m={m} />
        ))}
      </div>
      {reply ? (
        composer
      ) : (
        <p className="wa-view-only muted small" role="note">
          {t('waViewOnlyHint')}
        </p>
      )}
    </section>
  );
}

export function WaComposer({ c, onSent }: { c: WaConversation; onSent: () => void }) {
  const { t } = useApp();
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [templateOpen, setTemplateOpen] = useState(false);
  const [quickOpen, setQuickOpen] = useState(false);
  const file = useRef<HTMLInputElement>(null);
  const blockedByOther = c.assignedTo !== null && !c.assignedToMe;
  if (c.status === 'CLOSED') return null;
  const send = async () => {
    const body = text.trim();
    if (!body || busy) return;
    setBusy(true);
    setError(null);
    try {
      await api.post(`${BASE}/conversations/${c.id}/messages`, { type: 'TEXT', text: body });
      setText('');
      onSent();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  };
  const attach = async (f: File | undefined) => {
    if (!f || busy) return;
    setBusy(true);
    setError(null);
    try {
      await uploadWhatsAppMedia(c.id, f, text);
      setText('');
      onSent();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
      if (file.current) file.current.value = '';
    }
  };
  return (
    <div className="wa-composer">
      <WaError error={error} />
      {blockedByOther ? (
        <p className="muted small">{t('waErrAssigned')}</p>
      ) : c.window.open ? (
        <>
          <textarea
            className="input"
            rows={3}
            maxLength={4096}
            dir="auto"
            placeholder={t('waComposer')}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) void send();
            }}
          />
          <div className="wa-composer-bar">
            <button className="btn small" onClick={() => setQuickOpen(true)}>
              {t('waQuickReplies')}
            </button>
            <button className="btn small" onClick={() => file.current?.click()} disabled={busy}>
              {t('waAttach')}
            </button>
            <input
              ref={file}
              type="file"
              hidden
              accept="image/jpeg,image/png,audio/*,video/mp4,video/3gpp,application/pdf,text/plain,.doc,.docx,.xls,.xlsx,.ppt,.pptx"
              onChange={(e) => void attach(e.target.files?.[0])}
            />
            <button className="btn small ghost" onClick={() => setTemplateOpen(true)}>
              {t('waSendTemplate')}
            </button>
            <button className="btn primary" onClick={() => void send()} disabled={busy || !text.trim()}>
              {busy ? t('waSending') : t('waSend')}
            </button>
          </div>
        </>
      ) : (
        <button className="btn primary wa-template-only" onClick={() => setTemplateOpen(true)}>
          {t('waSendTemplate')}
        </button>
      )}
      {templateOpen && (
        <TemplateDialog
          c={c}
          onClose={() => setTemplateOpen(false)}
          onSent={() => {
            setTemplateOpen(false);
            onSent();
          }}
        />
      )}
      {quickOpen && (
        <QuickPick
          onClose={() => setQuickOpen(false)}
          onPick={(body) => {
            setText((cur) => (cur ? `${cur}\n${body}` : body));
            setQuickOpen(false);
          }}
        />
      )}
    </div>
  );
}

function QuickPick({ onClose, onPick }: { onClose: () => void; onPick: (body: string) => void }) {
  const { t } = useApp();
  const { data, error, loading } = useAsync(() => api.get<{ data: WaQuickReply[] }>(`${BASE}/quick-replies`), []);
  return (
    <Dialog title={t('waQuickReplies')} onClose={onClose}>
      <ErrorAlert error={error} />
      {loading && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('waNoQuickReplies')}</p>}
      <ul className="wa-quick-list">
        {data?.data.map((q) => (
          <li key={q.id}>
            <button className="btn ghost wa-quick" onClick={() => onPick(q.body)}>
              <b>{q.title}</b>
              <span className="muted small">{q.body}</span>
            </button>
          </li>
        ))}
      </ul>
    </Dialog>
  );
}

function TemplateDialog({ c, onClose, onSent }: { c: WaConversation; onClose: () => void; onSent: () => void }) {
  const { t } = useApp();
  const { data, error, loading } = useAsync(() => api.get<{ data: WaTemplate[] }>(`${BASE}/templates`), []);
  const [pick, setPick] = useState(0);
  const [params, setParams] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [sendError, setSendError] = useState<unknown>(null);
  const tpl = data?.data[pick];
  const ready = tpl && params.slice(0, tpl.parameterCount).filter((p) => p.trim()).length === tpl.parameterCount;
  const go = async () => {
    if (!tpl || !ready) return;
    setBusy(true);
    setSendError(null);
    try {
      await api.post(`${BASE}/conversations/${c.id}/messages`, {
        type: 'TEMPLATE',
        template: { name: tpl.name, language: tpl.language, parameters: params.slice(0, tpl.parameterCount).map((p) => p.trim()) },
      });
      onSent();
    } catch (e) {
      setSendError(e);
      setBusy(false);
    }
  };
  return (
    <Dialog title={t('waSendTemplate')} onClose={onClose}>
      <ErrorAlert error={error} />
      <WaError error={sendError} />
      {loading && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('waNoTemplates')}</p>}
      {data && data.data.length > 0 && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void go();
          }}
        >
          <label className="field">
            <span>{t('waTemplate')}</span>
            <select
              className="input"
              value={pick}
              onChange={(e) => {
                setPick(Number(e.target.value));
                setParams([]);
              }}
            >
              {data.data.map((x, i) => (
                <option key={`${x.name}:${x.language}`} value={i}>
                  {x.name} ({x.language})
                </option>
              ))}
            </select>
          </label>
          {tpl?.body && (
            <p className="wa-template-preview" dir="auto">
              {tpl.body}
            </p>
          )}
          {tpl &&
            Array.from({ length: tpl.parameterCount }, (_, i) => (
              <label className="field" key={i}>
                <span>{t('waTemplateParam', { n: i + 1 })}</span>
                <input
                  className="input"
                  dir="auto"
                  maxLength={1024}
                  value={params[i] ?? ''}
                  onChange={(e) => {
                    const next = [...params];
                    next[i] = e.target.value;
                    setParams(next);
                  }}
                />
              </label>
            ))}
          <div className="actions">
            <button type="button" className="btn" onClick={onClose}>
              {t('cancel')}
            </button>
            <button type="submit" className="btn primary" disabled={!ready || busy}>
              {busy ? t('waSending') : t('waSend')}
            </button>
          </div>
        </form>
      )}
    </Dialog>
  );
}

// ---- the customer panel --------------------------------------------------------------------------------------------

export function historyLine(t: T, a: WaAssignment): string {
  const by = staffName(t, a.by);
  const to = staffName(t, a.to);
  if (a.action === 'REOPEN') return a.by ? t('waActREOPENBy', { by }) : t('waActREOPEN');
  // D366: a transfer with its department — to a person or to the department's queue — and its note.
  if (a.action === 'TRANSFER' && a.department) {
    const department = departmentName(t, a.department);
    const line = a.to ? t('waActTRANSFERDept', { by, to, department }) : t('waActTRANSFERQueue', { by, department });
    return a.note ? `${line} · ${t('waHistoryNote', { note: a.note.body })}` : line;
  }
  return t(`waAct${a.action}` as Key, { by, to });
}

export function WaCustomerPanel({
  c,
  notes,
  history,
  onLink,
  onUnlink,
  onNote,
}: {
  c: WaConversation;
  notes: WaNote[];
  history: WaAssignment[];
  onLink: () => void;
  onUnlink: () => void;
  onNote: () => void;
}) {
  const { t, lang, can } = useApp();
  // D360: VIEW reads the panel; linking, unlinking and notes need REPLY.
  const reply = can('support.whatsapp');
  const a = c.linkedAccount;
  return (
    <aside className="wa-side">
      <section className="card">
        <h3>{t('waCustomer')}</h3>
        <p>
          {t('waPhone')}: <Phone value={c.phone} />
        </p>
        <h4>{t('waAccount')}</h4>
        {a ? (
          <div className="wa-account" data-wa-account={a.userId}>
            <Avatar url={a.avatarUrl} name={a.displayName} />
            <div>
              <a
                href={`/users/${a.userId}`}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(`/users/${a.userId}`);
                }}
              >
                {a.displayName}
              </a>
              <p className="muted small">
                <bdi dir="ltr">@{a.username}</bdi> · {a.status} · {t('waJoined', { date: formatDate(a.createdAt, lang) })}
              </p>
            </div>
            {reply && (
              <button className="btn small ghost" onClick={onUnlink}>
                {t('waUnlink')}
              </button>
            )}
          </div>
        ) : (
          <>
            <p className="muted small">{t('waNoAccount')}</p>
            {reply && (
              <button className="btn small" onClick={onLink}>
                {t('waLink')}
              </button>
            )}
          </>
        )}
      </section>
      <section className="card">
        <h3>{t('waNotes')}</h3>
        <p className="muted small">{t('waNotesHint')}</p>
        {notes.length === 0 && <p className="muted small">{t('waNoNotes')}</p>}
        <ul className="wa-notes">
          {notes.map((n) => (
            <li key={n.id}>
              <p dir="auto">{n.body}</p>
              <span className="muted small">
                {staffName(t, n.author)} · {formatDate(n.at, lang)}
              </span>
            </li>
          ))}
        </ul>
        {reply && (
          <button className="btn small" onClick={onNote}>
            {t('waAddNote')}
          </button>
        )}
      </section>
      <section className="card">
        <h3>{t('waHistory')}</h3>
        <ul className="wa-history small">
          {history.map((h) => (
            <li key={h.id}>
              {historyLine(t, h)} <span className="muted">· {formatDate(h.at, lang)}</span>
            </li>
          ))}
        </ul>
      </section>
    </aside>
  );
}

// ---- the page ------------------------------------------------------------------------------------------------------

export function WhatsAppInbox() {
  const { t, toast } = useApp();
  const { search } = useLocation();
  const selected = search.get('c');
  const [filter, setFilter] = useState<Filter>('unassigned');
  const [department, setDepartment] = useState<WaDepartment | ''>('');
  const [q, setQ] = useState('');
  const [tick, setTick] = useState(0);
  const bump = useCallback(() => {
    setTick((x) => x + 1);
    changed();
  }, []);
  const summary = useAsync(() => api.get<WaSummary>(`${BASE}/summary`), [tick]);
  const list = useAsync(
    () =>
      api.get<Page<WaConversation>>(`${BASE}/conversations`, {
        filter,
        department: department || undefined,
        q: q.trim() || undefined,
        limit: 50,
      }),
    [filter, department, q, tick],
  );
  useEffect(() => {
    const h = window.setInterval(() => setTick((x) => x + 1), 15_000);
    return () => window.clearInterval(h);
  }, []);
  if (summary.data && !summary.data.enabled) {
    return (
      <>
        <PageHead />
        <div className="alert info">{t('waOff')}</div>
      </>
    );
  }
  return (
    <>
      <PageHead />
      <div className="wa-layout">
        <section className="wa-col-list card">
          <div className="chips" role="tablist">
            {FILTERS.map((x) => (
              <button
                key={x.f}
                role="tab"
                aria-selected={filter === x.f}
                className={`chip ${filter === x.f ? 'active' : ''}`}
                onClick={() => setFilter(x.f)}
              >
                {t(x.key)}
              </button>
            ))}
          </div>
          <DepartmentFilter value={department} onChange={setDepartment} />
          <input
            className="input"
            type="search"
            placeholder={t('waSearch')}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            aria-label={t('waSearch')}
          />
          <ErrorAlert error={list.error} />
          {list.loading && !list.data && <Loading />}
          {list.data && (
            <WaConversationList
              items={list.data.data}
              selected={selected}
              onOpen={(id) => navigate(`/whatsapp?c=${encodeURIComponent(id)}`)}
            />
          )}
        </section>
        {selected ? (
          <OpenConversation key={selected} id={selected} tick={tick} onChange={bump} toast={toast} />
        ) : (
          <section className="wa-chat card wa-pick">
            <p className="muted">{t('waPickConversation')}</p>
          </section>
        )}
      </div>
    </>
  );
}

/** D366 (§10.159.4): the inbox's department filter (with «غير مسندة»: that department's queue). */
export function DepartmentFilter({
  value,
  onChange,
}: {
  value: WaDepartment | '';
  onChange: (d: WaDepartment | '') => void;
}) {
  const { t } = useApp();
  return (
    <label className="field wa-dept-filter">
      <span className="small muted">{t('waDeptFilter')}</span>
      <select
        className="input"
        data-wa-department-filter
        value={value}
        onChange={(e) => onChange(e.target.value as WaDepartment | '')}
      >
        <option value="">{t('waDeptAll')}</option>
        {WA_DEPARTMENTS.map((d) => (
          <option key={d} value={d}>
            {departmentName(t, d)}
          </option>
        ))}
      </select>
    </label>
  );
}

function PageHead() {
  const { t } = useApp();
  return (
    <div className="page-head">
      <div>
        <h1>{t('waTitle')}</h1>
        <p className="muted small">{t('waSubtitle')}</p>
      </div>
    </div>
  );
}

function OpenConversation({
  id,
  tick,
  onChange,
  toast,
}: {
  id: string;
  tick: number;
  onChange: () => void;
  toast: (s: string) => void;
}) {
  const { t, can } = useApp();
  const reply = can('support.whatsapp');
  const [local, setLocal] = useState(0);
  const conv = useAsync(() => api.get<WaConversation>(`${BASE}/conversations/${id}`), [id, tick, local]);
  const msgs = useAsync(() => api.get<Page<WaMessage>>(`${BASE}/conversations/${id}/messages`, { limit: 50 }), [id, tick, local]);
  const notes = useAsync(() => api.get<{ data: WaNote[] }>(`${BASE}/conversations/${id}/notes`), [id, local]);
  const history = useAsync(() => api.get<{ data: WaAssignment[] }>(`${BASE}/conversations/${id}/assignments`), [id, tick, local]);
  const [error, setError] = useState<unknown>(null);
  const [dialog, setDialog] = useState<'transfer' | 'link' | 'note' | null>(null);
  const refresh = () => {
    setLocal((x) => x + 1);
    onChange();
  };
  // Reading the conversation marks it read (the unread count and the customer's blue ticks) — not for VIEW (D360):
  // a viewer cannot answer, so the conversation stays unread for those who can and the customer sees no blue ticks.
  const unread = conv.data?.unreadCount ?? 0;
  useEffect(() => {
    if (reply && unread > 0) void api.post(`${BASE}/conversations/${id}/read`).then(onChange, () => undefined);
  }, [id, unread, onChange, reply]);
  const act = async (a: 'claim' | 'release' | 'close' | 'reopen' | 'transfer') => {
    if (a === 'transfer') return setDialog('transfer');
    setError(null);
    try {
      await api.post(`${BASE}/conversations/${id}/${a}`);
      refresh();
    } catch (e) {
      setError(e);
    }
  };
  if (conv.error) return <section className="wa-chat card"><WaError error={conv.error} /></section>;
  if (!conv.data) return <section className="wa-chat card"><Loading /></section>;
  const c = conv.data;
  return (
    <>
      <div className="wa-col-chat card">
        <WaError error={error} />
        <WaChatView c={c} messages={msgs.data?.data ?? []} onAction={(a) => void act(a)} composer={<WaComposer c={c} onSent={refresh} />} />
      </div>
      <WaCustomerPanel
        c={c}
        notes={notes.data?.data ?? []}
        history={history.data?.data ?? []}
        onLink={() => setDialog('link')}
        onUnlink={() =>
          void api.del(`${BASE}/conversations/${id}/link`).then(refresh, (e: unknown) => setError(e))
        }
        onNote={() => setDialog('note')}
      />
      {dialog === 'transfer' && (
        <TransferDialog
          c={c}
          onClose={() => setDialog(null)}
          onDone={(after) => {
            setDialog(null);
            toast(
              after.assignedTo
                ? t('waTransferDoneTo', { name: staffName(t, after.assignedTo) })
                : t('waTransferDoneQueue', { department: departmentName(t, after.department) }),
            );
            refresh();
          }}
        />
      )}
      {dialog === 'link' && (
        <FormDialog
          title={t('waLink')}
          fields={[{ name: 'username', label: t('waUsername'), maxLength: 41 }]}
          confirmLabel={t('waLink')}
          submit={(v) => api.post(`${BASE}/conversations/${id}/link`, { username: v.username })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            refresh();
          }}
        />
      )}
      {dialog === 'note' && (
        <FormDialog
          title={t('waAddNote')}
          intro={<p className="muted small">{t('waNotesHint')}</p>}
          fields={[{ name: 'body', label: t('waNotes'), kind: 'textarea', maxLength: 2000 }]}
          confirmLabel={t('save')}
          submit={(v) => api.post(`${BASE}/conversations/${id}/notes`, { body: v.body })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('waAddNote'));
            refresh();
          }}
        />
      )}
    </>
  );
}

/** D366: what the transfer dialog chose — the department, a person (null: «أول متاح في القسم») and the note. */
export interface TransferChoice {
  department: WaDepartment;
  to: string | null;
  note: string;
}

/**
 * D366 (CONVENTIONS §10.159.2): the transfer dialog's body without its loading (the tests render it) — the department
 * chips, «أول متاح في القسم» first, the department's agents (the on-shift dot and their open conversations), the
 * internal note (never sent) and «تحويل».
 */
export function WaTransferView({
  choice,
  agents,
  loading,
  busy,
  onChange,
  onConfirm,
}: {
  choice: TransferChoice;
  agents: WaAgent[] | null;
  loading: boolean;
  busy: boolean;
  onChange: (next: TransferChoice) => void;
  onConfirm: () => void;
}) {
  const { t, lang } = useApp();
  return (
    <div className="wa-transfer" data-wa-transfer-department={choice.department}>
      <p className="small muted">{t('waTransferDepartment')}</p>
      <div className="chips" role="radiogroup" aria-label={t('waTransferDepartment')}>
        {WA_DEPARTMENTS.map((d) => (
          <button
            key={d}
            type="button"
            role="radio"
            aria-checked={choice.department === d}
            className={`chip ${choice.department === d ? 'active' : ''}`}
            data-wa-dept-chip={d}
            onClick={() => onChange({ ...choice, department: d, to: null })}
          >
            {departmentName(t, d)}
          </button>
        ))}
      </div>
      <p className="small muted">{t('waTransferWho')}</p>
      <ul className="wa-transfer-list" role="radiogroup" aria-label={t('waTransferWho')}>
        <li>
          <button
            type="button"
            role="radio"
            aria-checked={choice.to === null}
            className={`wa-transfer-option${choice.to === null ? ' active' : ''}`}
            data-wa-transfer-first
            onClick={() => onChange({ ...choice, to: null })}
          >
            <span className="wa-transfer-icon" aria-hidden="true">
              ⚡
            </span>
            <span className="grow">
              <b>{t('waTransferFirst')}</b>
              <span className="muted small block">{t('waTransferFirstHint')}</span>
            </span>
          </button>
        </li>
        {loading && (
          <li>
            <Loading />
          </li>
        )}
        {agents && agents.length === 0 && <li className="muted small">{t('waTransferNoAgents')}</li>}
        {agents?.map((a) => (
          <li key={a.userId}>
            <button
              type="button"
              role="radio"
              aria-checked={choice.to === a.userId}
              className={`wa-transfer-option${choice.to === a.userId ? ' active' : ''}`}
              data-wa-transfer-agent={a.userId}
              onClick={() => onChange({ ...choice, to: a.userId })}
            >
              <span
                className={`wa-shift-dot${a.onShift ? ' on' : ''}`}
                role="img"
                aria-label={a.onShift ? t('waOnShift') : t('waOffShift')}
              />
              <span className="grow">
                <b>{staffName(t, a)}</b>
                <span className="muted small block">
                  {[
                    a.displayName && a.staffId ? a.staffId : null,
                    a.onShift ? t('waOnShift') : t('waOffShift'),
                    t('waAgentOpen', { count: formatNumber(a.openCount ?? 0, lang) }),
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </span>
              </span>
            </button>
          </li>
        ))}
      </ul>
      <label className="field">
        <span>{t('waTransferNote')}</span>
        <textarea
          className="input"
          data-wa-transfer-note
          maxLength={500}
          rows={2}
          dir="auto"
          value={choice.note}
          onChange={(e) => onChange({ ...choice, note: e.target.value })}
        />
        <span className="muted small">
          {t('waTransferNoteHint')} · {formatNumber(choice.note.length, lang)}/500
        </span>
      </label>
      <div className="actions">
        <button className="btn primary" data-wa-transfer-confirm disabled={busy} onClick={onConfirm}>
          {t('waTransferConfirm')}
        </button>
      </div>
    </div>
  );
}

function TransferDialog({
  c,
  onClose,
  onDone,
}: {
  c: WaConversation;
  onClose: () => void;
  onDone: (after: WaConversation) => void;
}) {
  const { t } = useApp();
  const [choice, setChoice] = useState<TransferChoice>({ department: c.department ?? 'GENERAL', to: null, note: '' });
  const agents = useAsync(
    () => api.get<{ data: WaAgent[] }>(`${BASE}/agents`, { department: choice.department }),
    [choice.department],
  );
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const confirm = () => {
    setBusy(true);
    setError(null);
    const note = choice.note.trim();
    void api
      .post<WaConversation>(`${BASE}/conversations/${c.id}/transfer`, {
        department: choice.department,
        ...(choice.to ? { toUserId: choice.to } : {}),
        ...(note ? { note } : {}),
      })
      .then(onDone, (e: unknown) => {
        setBusy(false);
        setError(e);
      });
  };
  return (
    <Dialog title={t('waTransferTitle')} onClose={onClose}>
      <ErrorAlert error={agents.error} />
      <WaError error={error} />
      <WaTransferView
        choice={choice}
        agents={agents.data?.data ?? null}
        loading={agents.loading}
        busy={busy}
        onChange={setChoice}
        onConfirm={confirm}
      />
    </Dialog>
  );
}

// ---- settings and quick replies ------------------------------------------------------------------------------------

export function WaSettingsView({ s, test, onTest }: { s: WaStatus; test: WaTestResult | null; onTest: () => void }) {
  const { t, lang } = useApp();
  const row = (k: Key, v: React.ReactNode) => (
    <div className="wa-kv">
      <span className="muted">{t(k)}</span>
      <span>{v}</span>
    </div>
  );
  return (
    <section className="card wa-settings">
      <p>
        <span className={`tag ${s.enabled ? 'open' : ''}`}>{s.enabled ? t('waStatusOn') : t('waStatusOff')}</span>
      </p>
      {s.missing.length > 0 && (
        <div className="alert info">
          {t('waMissing')}:{' '}
          {s.missing.map((m) => (
            <code key={m} className="ltr">
              {m}{' '}
            </code>
          ))}
        </div>
      )}
      {row('waPhoneNumberId', <bdi dir="ltr">{s.phoneNumberId ?? '—'}</bdi>)}
      {row('waBusinessAccountId', <bdi dir="ltr">{s.businessAccountId ?? '—'}</bdi>)}
      {row('waDisplayName', s.displayName ?? '—')}
      {row('waApiVersion', <bdi dir="ltr">{s.graphApiVersion}</bdi>)}
      {row('waWebhookUrl', <code className="ltr wa-copy">{s.webhookUrl}</code>)}
      {row('waWebhookFields', <bdi dir="ltr">{s.subscribedFields.join(', ')}</bdi>)}
      {row('waRetention', t('waRetentionDays', { days: s.retentionDays }))}
      {row('waMediaMax', `${formatNumber(Math.round(s.mediaMaxBytes / 1048576), lang)} MB`)}
      {row('waLastInbound', s.lastInboundAt ? formatDate(s.lastInboundAt, lang) : '—')}
      {row('waConversationsCount', formatNumber(s.conversations, lang))}
      <p>
        <button className="btn primary" onClick={onTest} disabled={!s.enabled}>
          {t('waTest')}
        </button>
      </p>
      {test && (
        <div className={`alert ${test.ok ? 'success' : 'error'}`} role="status">
          {test.ok
            ? t('waTestOk', {
                name: test.verifiedName ?? test.displayPhoneNumber ?? '—',
                quality: test.qualityRating ?? '—',
                templates: test.templates ?? 0,
              })
            : t('waTestFail', {
                status: test.error?.status ?? 0,
                code: test.error?.code !== null && test.error?.code !== undefined ? ` / ${test.error.code}` : '',
              })}
        </div>
      )}
      <p className="muted small">{t('waWhoAnswers')}</p>
      <p>
        <a
          href="/team"
          onClick={(e) => {
            e.preventDefault();
            navigate('/team');
          }}
        >
          {t('waOpenTeam')}
        </a>
      </p>
    </section>
  );
}

export function WhatsAppSettings() {
  const { t } = useApp();
  const { data, error, loading } = useAsync(() => api.get<WaStatus>(`${BASE}/settings`), []);
  const [test, setTest] = useState<WaTestResult | null>(null);
  const [testError, setTestError] = useState<unknown>(null);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('waSettingsTitle')}</h1>
          <p className="muted small">{t('waSettingsSubtitle')}</p>
        </div>
      </div>
      <ErrorAlert error={error ?? testError} />
      {loading && <Loading />}
      {data && (
        <WaSettingsView
          s={data}
          test={test}
          onTest={() => {
            setTestError(null);
            void api.post<WaTestResult>(`${BASE}/settings/test`).then(setTest, setTestError);
          }}
        />
      )}
    </>
  );
}

export function WhatsAppQuickReplies() {
  const { t } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<{ data: WaQuickReply[] }>(`${BASE}/quick-replies`), []);
  const [edit, setEdit] = useState<WaQuickReply | 'new' | null>(null);
  const [delError, setDelError] = useState<unknown>(null);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('waQuickTitle')}</h1>
          <p className="muted small">{t('waQuickSubtitle')}</p>
        </div>
        <button className="btn primary" onClick={() => setEdit('new')}>
          {t('waQuickAdd')}
        </button>
      </div>
      <ErrorAlert error={error ?? delError} />
      {loading && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('waNoQuickReplies')}</p>}
      <ul className="wa-quick-admin">
        {data?.data.map((q) => (
          <li key={q.id} className="card">
            <b>{q.title}</b>
            <p dir="auto">{q.body}</p>
            <div className="wa-actions">
              <button className="btn small" onClick={() => setEdit(q)}>
                {t('waQuickEdit')}
              </button>
              <button
                className="btn small danger"
                onClick={() => void api.del(`${BASE}/quick-replies/${q.id}`).then(reload, setDelError)}
              >
                {t('waQuickDelete')}
              </button>
            </div>
          </li>
        ))}
      </ul>
      {edit && (
        <FormDialog
          title={edit === 'new' ? t('waQuickAdd') : t('waQuickEdit')}
          intro={edit !== 'new' ? <p className="muted small">{edit.title}</p> : undefined}
          fields={[
            { name: 'title', label: t('waQuickName'), maxLength: 60 },
            { name: 'body', label: t('waQuickBody'), kind: 'textarea', maxLength: 1024 },
          ]}
          confirmLabel={t('save')}
          submit={async (v) => {
            try {
              return edit === 'new'
                ? await api.post(`${BASE}/quick-replies`, { title: v.title, body: v.body })
                : await api.patch(`${BASE}/quick-replies/${edit.id}`, { title: v.title, body: v.body });
            } catch (e) {
              if (e instanceof ApiError && e.details[0]?.issue === 'duplicate') throw new Error(t('waQuickDuplicate'), { cause: e });
              throw e;
            }
          }}
          onClose={() => setEdit(null)}
          onDone={() => {
            setEdit(null);
            reload();
          }}
        />
      )}
    </>
  );
}
