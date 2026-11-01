import { useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import { isKey } from '../i18n';
import { navigate } from '../router';
import type { AdminOrder, DisputeRow, OrderMessage, Page, RechargePrice } from '../types';
import { StatusTabs } from './Applications';

const STATUSES = ['OPEN', 'RESOLVED'] as const;

/** `$12.50 · 631.25 EGP` — USD always, the local amount when the order has one. */
export function PriceText({ price }: { price: RechargePrice }) {
  return (
    <span className="num ltr">
      ${price.usd}
      {price.local ? ` · ${price.local.amount} ${price.local.currency}` : ''}
    </span>
  );
}

/** «نزاعات الشحن» (v1.69-social, D204, CONVENTIONS §10.64.9): the queue of disputed recharge orders. */
export function Disputes() {
  const { t, lang } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('OPEN');
  const pages = useCursorPages(status);
  const { data, error, loading } = useAsync(
    () => api.get<Page<DisputeRow>>('/admin/recharge/disputes', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('disputesTitle')}</h1>
          <p className="muted small">{t('disputesSubtitle')}</p>
        </div>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colBuyer')}</th>
                <th>{t('colAgent')}</th>
                <th>{t('colCoins')}</th>
                <th>{t('colPrice')}</th>
                <th>{t('colDisputedBy')}</th>
                <th>{t('colDisputedAt')}</th>
                <th>{t('colStatus')}</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((o) => (
                <tr
                  key={o.id}
                  className="clickable"
                  tabIndex={0}
                  onClick={() => navigate(`/recharge/disputes/${o.id}`)}
                  onKeyDown={(e) => e.key === 'Enter' && navigate(`/recharge/disputes/${o.id}`)}
                >
                  <td>
                    <UserCell username={o.buyer.username} displayName={o.buyer.displayName} />
                  </td>
                  <td>
                    <UserCell username={o.agent.username} displayName={o.agent.displayName} />
                  </td>
                  <td className="num">{formatNumber(o.coins, lang)}</td>
                  <td>
                    <PriceText price={o.price} />
                  </td>
                  <td>{o.disputedBy && isKey(`by${o.disputedBy}`) ? t(`by${o.disputedBy}` as never) : t('none')}</td>
                  <td className="date small">{formatDate(o.disputedAt, lang)}</td>
                  <td>
                    <StatusBadge status={o.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
    </>
  );
}

/** A payment-method type in the panel's language (the raw value when unknown). */
export function methodLabel(t: ReturnType<typeof useApp>['t'], method: string | null): string {
  if (!method) return t('none');
  const key = `method${method}`;
  return isKey(key) ? t(key as never) : method;
}

function Bubble({ m, orderId }: { m: OrderMessage; orderId: string }) {
  const { t, lang } = useApp();
  if (m.kind === 'SYSTEM') {
    const key = `ev${m.event ?? ''}`;
    return (
      <div className="chat-system" data-event={m.event ?? ''}>
        <span>{isKey(key) ? t(key as never) : m.event}</span>
        {m.text ? <span className="muted"> — {m.text}</span> : null}
        <span className="date muted"> · {formatDate(m.createdAt, lang)}</span>
      </div>
    );
  }
  const side = m.role === 'BUYER' ? 'start' : m.role === 'ADMIN' ? 'admin' : 'end';
  return (
    <div className={`chat-line ${side}`} data-role={m.role}>
      <div className="chat-bubble">
        <div className="chat-who small">
          <strong>{t(`role${m.role}` as never)}</strong>{' '}
          {m.author ? <span className="muted ltr">@{m.author.username}</span> : null}
        </div>
        {m.kind === 'PAYMENT_DETAILS' && <div className="chat-tag small">{t('msgDetails', { method: methodLabel(t, m.method) })}</div>}
        {m.kind === 'TRANSFER_PROOF' && <div className="chat-tag small">{t('msgProof')}</div>}
        {m.text ? <div className="chat-text">{m.text}</div> : null}
        {m.hasImage ? (
          <a href={`/api/v1/admin/recharge/orders/${orderId}/messages/${m.id}/image`} target="_blank" rel="noreferrer noopener">
            <img
              className="chat-image"
              src={`/api/v1/admin/recharge/orders/${orderId}/messages/${m.id}/image`}
              alt={m.kind === 'TRANSFER_PROOF' ? t('msgProof') : t('msgImage')}
              referrerPolicy="no-referrer"
              loading="lazy"
            />
          </a>
        ) : null}
        <div className="date small muted">{formatDate(m.createdAt, lang)}</div>
      </div>
    </div>
  );
}

/** One disputed order: the facts, the whole chat (audited), «الإدارة» lines and the decision with the code. */
export function DisputeDetail({ id }: { id: string }) {
  const { data, error, loading, reload } = useAsync(() => api.get<AdminOrder>(`/admin/recharge/orders/${id}`), [id]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return <DisputeOrderView data={data} onChange={reload} />;
}

/** The disputed order's page without the loading (rendered to HTML by the component tests). */
export function DisputeOrderView({ data, onChange }: { data: AdminOrder; onChange: () => void }) {
  const { t, lang, can, toast } = useApp();
  const id = data.id;
  const reload = onChange;
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<unknown>(null);
  const [deciding, setDeciding] = useState<'CREDIT_BUYER' | 'REFUND_AGENT' | null>(null);
  const chatRef = useRef<HTMLDivElement>(null);
  // The newest lines first in view (the chat reads top to bottom, oldest first).
  useEffect(() => {
    const el = chatRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [data.messages.length]);
  const send = () => {
    if (!text.trim()) return;
    setSending(true);
    setSendError(null);
    api.post(`/admin/recharge/orders/${id}/messages`, { text: text.trim() }).then(
      () => {
        setSending(false);
        setText('');
        reload();
      },
      (e: unknown) => {
        setSending(false);
        setSendError(e);
      },
    );
  };
  const steps: [string, string | null][] = [
    ['orderCreated', data.createdAt],
    ['orderDetailsAt', data.detailsAt],
    ['orderNoticeAt', data.noticeAcknowledgedAt],
    ['orderPaidAt', data.paidAt],
    ['orderDisputedAt', data.disputedAt],
    ['orderClosedAt', data.closedAt],
  ];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('orderTitle')}</h1>
          <div className="row small">
            <StatusBadge status={data.status} />
            <span className="mono muted ltr">{data.id}</span>
          </div>
        </div>
        <button className="btn" onClick={() => navigate('/recharge/disputes')}>
          {t('back')}
        </button>
      </div>
      <div className="alert info">{t('orderPrivate')}</div>
      <div className="grid cols-2 order-grid">
        <div className="grid">
          <div className="card">
            <dl className="kv">
              <dt>{t('colBuyer')}</dt>
              <dd>
                <a href={`/users/${data.buyer.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${data.buyer.id}`))}>
                  {data.buyer.displayName} <span className="ltr">@{data.buyer.username}</span>
                </a>
              </dd>
              <dt>{t('colAgent')}</dt>
              <dd>
                <a href={`/users/${data.agent.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${data.agent.id}`))}>
                  {data.agent.displayName} <span className="ltr">@{data.agent.username}</span>
                </a>{' '}
                <span className="mono ltr">{data.agent.code}</span>
              </dd>
              <dt>{t('colCoins')}</dt>
              <dd className="num">
                {formatNumber(data.coins, lang)}
                {data.heldCoins > 0 ? <span className="badge warn"> {t('orderFrozen')}</span> : null}
              </dd>
              <dt>{t('colPrice')}</dt>
              <dd>
                <PriceText price={data.price} />
              </dd>
              <dt>{t('orderCountry')}</dt>
              <dd className="mono">{data.country}</dd>
              <dt>{t('orderPaymentType')}</dt>
              <dd>{methodLabel(t, data.paymentType)}</dd>
              <dt>{t('colDisputedBy')}</dt>
              <dd>{data.disputedBy && isKey(`by${data.disputedBy}`) ? t(`by${data.disputedBy}` as never) : t('none')}</dd>
              <dt>{t('orderStock')}</dt>
              <dd className="num">{formatNumber(data.agent.stockCoins ?? 0, lang)}</dd>
              {data.closeReason ? (
                <>
                  <dt>{t('orderDecision')}</dt>
                  <dd>{data.closeReason}</dd>
                </>
              ) : null}
            </dl>
          </div>
          <div className="card">
            <h2 className="card-title">{t('orderTimeline')}</h2>
            <dl className="kv">
              {steps.map(([key, at]) => (
                <div key={key} style={{ display: 'contents' }}>
                  <dt>{t(key as never)}</dt>
                  <dd className="date small">{at ? formatDate(at, lang) : t('none')}</dd>
                </div>
              ))}
            </dl>
          </div>
          {data.status === 'DISPUTED' && (
            <div className="card">
              <h2 className="card-title">{t('orderDecision')}</h2>
              {can('recharge.disputes.resolve') ? (
                <div className="row">
                  <button className="btn primary" onClick={() => setDeciding('CREDIT_BUYER')}>
                    {t('resolveBuyer')}
                  </button>
                  <button className="btn danger" onClick={() => setDeciding('REFUND_AGENT')}>
                    {t('resolveAgent')}
                  </button>
                </div>
              ) : (
                <p className="muted small">{t('resolveNoRole')}</p>
              )}
            </div>
          )}
        </div>
        <div className="card chat-card">
          <h2 className="card-title">{t('orderChat')}</h2>
          <div className="chat" aria-live="polite" ref={chatRef}>
            {data.messages.map((m) => (
              <Bubble key={m.id} m={m} orderId={data.id} />
            ))}
          </div>
          <ErrorAlert error={sendError} />
          <form
            className="chat-compose"
            onSubmit={(e) => {
              e.preventDefault();
              send();
            }}
          >
            <label htmlFor="admin-chat" className="sr-only">
              {t('adminWrite')}
            </label>
            <textarea id="admin-chat" maxLength={1000} placeholder={t('adminWrite')} value={text} onChange={(e) => setText(e.target.value)} />
            <button type="submit" className="btn primary" disabled={sending || !text.trim()}>
              {t('adminSend')}
            </button>
          </form>
        </div>
      </div>
      {deciding && (
        <FormDialog
          title={deciding === 'CREDIT_BUYER' ? t('resolveBuyer') : t('resolveAgent')}
          intro={<p className="small">{t('resolveIntro', { coins: formatNumber(data.coins, lang) })}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={deciding === 'CREDIT_BUYER' ? t('resolveBuyer') : t('resolveAgent')}
          danger={deciding === 'REFUND_AGENT'}
          submit={(v) =>
            api.post(`/admin/recharge/orders/${id}/resolve`, { outcome: deciding, reason: v.reason, totpCode: v.totpCode })
          }
          onClose={() => setDeciding(null)}
          onDone={() => {
            setDeciding(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}
