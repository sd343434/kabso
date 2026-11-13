import { useState, type ReactNode } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatMoney, formatNumber } from '../format';
import type { Key, Lang } from '../i18n';
import type {
  Capability,
  StoreIapOverview,
  StoreIapProduct,
  StoreIapPurchaseRow,
  StoreIapRefundBanRow,
} from '../types';
import { DataTable, type Column } from '../ui/DataTable';

/**
 * D345 (v1.110-social, CONVENTIONS §10.144.6): «مشتريات المتجر» — the stores' status and the once-per-account+device
 * switch, the catalogue (store product id ↔ coins), the purchases and the refund bans with their reason, and the
 * OWNER's «فك الحظر» (the authenticator code again and a reason). The device and the store token are never shown.
 */
type Tab = 'overview' | 'products' | 'purchases' | 'bans';
const TABS: { tab: Tab; key: Key }[] = [
  { tab: 'overview', key: 'iapTabOverview' },
  { tab: 'products', key: 'iapTabProducts' },
  { tab: 'purchases', key: 'iapTabPurchases' },
  { tab: 'bans', key: 'iapTabBans' },
];

type T = ReturnType<typeof useApp>['t'];

/** A table cell's text that wraps (cells do not wrap by default). */
const WRAP = { whiteSpace: 'normal', display: 'inline-block', maxWidth: 340, lineHeight: 1.5 } as const;

/**
 * A refund reason mixes Arabic with Latin runs (the store, the date, the order id): each Latin / digit run is isolated
 * (`<bdi dir="ltr">`) so «بتاريخ 2026-11-09 — طلب GPA.…» keeps its order inside the Arabic sentence.
 */
export function BidiText({ text }: { text: string }) {
  const parts = text.split(/([A-Za-z0-9][A-Za-z0-9.:_-]*(?:[ ()][A-Za-z0-9.:_()-]+)*\)?)/);
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <bdi key={i} dir="ltr">
            {part}
          </bdi>
        ) : (
          part
        ),
      )}
    </>
  );
}

export function StoreIap() {
  const { t } = useApp();
  const [tab, setTab] = useState<Tab>('overview');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('iapTitle')}</h1>
          <p className="muted small">{t('iapSubtitle')}</p>
        </div>
      </div>
      <div className="chips" role="tablist">
        {TABS.map((x) => (
          <button
            key={x.tab}
            role="tab"
            aria-selected={tab === x.tab}
            className={`chip ${tab === x.tab ? 'active' : ''}`}
            onClick={() => setTab(x.tab)}
          >
            {t(x.key)}
          </button>
        ))}
      </div>
      {tab === 'overview' && <OverviewTab />}
      {tab === 'products' && <ProductsTab />}
      {tab === 'purchases' && <PurchasesTab />}
      {tab === 'bans' && <BansTab />}
    </>
  );
}

function OverviewTab() {
  const { t, toast, lang } = useApp();
  const [bump, setBump] = useState(0);
  const [dialog, setDialog] = useState<boolean | null>(null);
  const [syncError, setSyncError] = useState<unknown>(null);
  const { data, error, loading } = useAsync(() => api.get<StoreIapOverview>('/admin/store-iap/overview'), [bump]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const sync = async () => {
    setSyncError(null);
    try {
      const r = await api.post<{ checked: number; refunded: number; unknown: number }>(
        '/admin/store-iap/google/voided-sync',
        {},
      );
      const n = (v: number) => formatNumber(v, lang);
      toast(t('iapVoidedResult', { checked: n(r.checked), refunded: n(r.refunded), unknown: n(r.unknown) }));
      setBump((b) => b + 1);
    } catch (e) {
      setSyncError(e);
    }
  };
  return (
    <>
      <ErrorAlert error={syncError} />
      <StoreIapOverviewView data={data} onToggle={(on) => setDialog(on)} onSync={() => void sync()} />
      {dialog !== null && (
        <FormDialog
          title={t('iapOnce')}
          intro={<p className="muted small">{t('iapOnceHint')}</p>}
          fields={[reasonField(t)]}
          confirmLabel={dialog ? t('iapOnceEnable') : t('iapOnceDisable')}
          submit={(v) => api.patch('/admin/store-iap/settings', { oncePerAccountDevice: dialog, reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={() => {
            setDialog(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}

/** The overview's content for `data` (rendered without the network in the tests). */
export function StoreIapOverviewView({
  data,
  onToggle,
  onSync,
}: {
  data: StoreIapOverview;
  onToggle: (on: boolean) => void;
  onSync: () => void;
}) {
  const { t, lang, can } = useApp();
  const manage = can('store_iap.manage');
  const n = (v: number) => formatNumber(v, lang);
  const state = (on: boolean) => <span className={`badge ${on ? 'ok' : 'warn'}`}>{t(on ? 'iapConfigured' : 'iapNotConfigured')}</span>;
  return (
    <div className="card" data-testid="iap-overview">
      <dl className="kv">
        <dt>{t('iapGooglePlay')}</dt>
        <dd>
          {state(data.googlePlay.configured)} {data.googlePlay.packageName && <span className="ltr">{data.googlePlay.packageName}</span>}
          <div className="muted small">
            {t('iapRtdn')}: {data.googlePlay.rtdnEnabled ? t('iapConfigured') : t('iapRtdnOff')}
          </div>
        </dd>
        <dt>{t('iapAppStore')}</dt>
        <dd>
          {state(data.appStore.configured)} {data.appStore.bundleId && <span className="ltr">{data.appStore.bundleId}</span>}
          <div className="muted small">{t('iapRoots', { n: n(data.appStore.roots) })}</div>
        </dd>
        <dt>{t('iapEnv')}</dt>
        <dd>{data.acceptSandbox ? t('iapSandbox') : t('iapSandboxOff')}</dd>
        <dt>{t('iapEndpoints')}</dt>
        <dd>
          <div className="ltr small">{data.endpoints.appleNotifications}</div>
          <div className="ltr small">{data.endpoints.googleRtdn}</div>
        </dd>
        <dt>{t('iapVoidedLast')}</dt>
        <dd>
          {data.voided.lastRunAt ? <span className="date">{formatDate(data.voided.lastRunAt, lang)}</span> : t('iapVoidedNever')}
          {data.voided.lastError && <div className="alert warn small">{t('iapVoidedError', { error: data.voided.lastError })}</div>}
        </dd>
        <dt>{t('iapOnce')}</dt>
        <dd>
          <b data-testid="iap-once">{data.settings.oncePerAccountDevice ? t('iapOnceOn') : t('iapOnceOff')}</b>
          <div className="muted small">{t('iapOnceHint')}</div>
        </dd>
      </dl>
      <p className="muted small">
        {t('iapCounts', {
          purchases: n(data.counts.purchases),
          refunds: n(data.counts.refunds),
          bans: n(data.counts.activeBans),
        })}
      </p>
      {manage && (
        <div className="row actions-row">
          <button className="btn" onClick={() => onToggle(!data.settings.oncePerAccountDevice)}>
            {data.settings.oncePerAccountDevice ? t('iapOnceDisable') : t('iapOnceEnable')}
          </button>
          {data.googlePlay.configured && (
            <button className="btn" onClick={onSync}>
              {t('iapVoidedSync')}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function ProductsTab() {
  const { t, toast } = useApp();
  const [bump, setBump] = useState(0);
  const [edit, setEdit] = useState<StoreIapProduct | 'new' | null>(null);
  const { data, error, loading } = useAsync(
    () => api.get<{ data: StoreIapProduct[] }>('/admin/store-iap/products'),
    [bump],
  );
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const done = () => {
    setEdit(null);
    toast(t('done'));
    setBump((b) => b + 1);
  };
  return (
    <>
      <StoreIapProductsView products={data.data} onAdd={() => setEdit('new')} onEdit={(p) => setEdit(p)} />
      {edit === 'new' && (
        <FormDialog
          title={t('iapAddProduct')}
          intro={<p className="muted small">{t('iapProductsHint')}</p>}
          fields={[
            { name: 'platform', label: `${t('iapPlatform')} (GOOGLE_PLAY / APP_STORE)`, maxLength: 11 },
            { name: 'productId', label: t('iapProductId'), maxLength: 150 },
            { name: 'coins', label: t('iapCoins'), maxLength: 13 },
            { name: 'referenceUsdCents', label: t('iapRefPrice'), required: false, maxLength: 9 },
            reasonField(t),
          ]}
          confirmLabel={t('confirm')}
          submit={(v) =>
            api.post('/admin/store-iap/products', {
              platform: v.platform?.toUpperCase(),
              productId: v.productId,
              coins: Number(v.coins),
              ...(v.referenceUsdCents ? { referenceUsdCents: Number(v.referenceUsdCents) } : {}),
              reason: v.reason,
            })
          }
          onClose={() => setEdit(null)}
          onDone={done}
        />
      )}
      {edit && edit !== 'new' && (
        <FormDialog
          title={`${t('iapEditProduct')} — ${edit.productId}`}
          fields={[
            { name: 'coins', label: `${t('iapCoins')} (${edit.coins})`, required: false, maxLength: 13 },
            { name: 'enabled', label: `${t('iapEnabled')} (true / false)`, required: false, maxLength: 5 },
            reasonField(t),
          ]}
          confirmLabel={t('confirm')}
          submit={(v) =>
            api.patch(`/admin/store-iap/products/${edit.id}`, {
              ...(v.coins ? { coins: Number(v.coins) } : {}),
              ...(v.enabled ? { enabled: v.enabled === 'true' } : {}),
              reason: v.reason,
            })
          }
          onClose={() => setEdit(null)}
          onDone={done}
        />
      )}
    </>
  );
}

/** The catalogue (rendered without the network in the tests). */
export function StoreIapProductsView({
  products,
  onAdd,
  onEdit,
}: {
  products: StoreIapProduct[];
  onAdd: () => void;
  onEdit: (p: StoreIapProduct) => void;
}) {
  const { t, lang, can } = useApp();
  const manage = can('store_iap.manage');
  return (
    <div className="card" data-testid="iap-products">
      <p className="muted small">{t('iapProductsHint')}</p>
      {products.length === 0 ? (
        <div className="state empty-state">
          <p>{t('iapNoProducts')}</p>
        </div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('iapPlatform')}</th>
                <th>{t('iapProductId')}</th>
                <th>{t('iapCoins')}</th>
                <th>{t('iapRefPrice')}</th>
                <th>{t('colStatus')}</th>
                {manage && <th>{t('colActions')}</th>}
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr key={p.id}>
                  <td>{t(p.platform === 'GOOGLE_PLAY' ? 'iapGooglePlay' : 'iapAppStore')}</td>
                  <td className="ltr">{p.productId}</td>
                  <td>{formatNumber(p.coins, lang)}</td>
                  <td>{p.referenceUsdCents !== null ? formatMoney(p.referenceUsdCents, 'USD', lang) : '—'}</td>
                  <td>
                    <span className={`badge ${p.enabled ? 'ok' : ''}`}>{t(p.enabled ? 'iapEnabled' : 'iapDisabled')}</span>
                  </td>
                  {manage && (
                    <td>
                      <button className="btn small" onClick={() => onEdit(p)}>
                        {t('iapEditProduct')}
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {manage && (
        <div className="row actions-row">
          <button className="btn primary" onClick={onAdd}>
            {t('iapAddProduct')}
          </button>
        </div>
      )}
    </div>
  );
}

const platformLabel = (t: T, p: string) => t(p === 'GOOGLE_PLAY' ? 'iapGooglePlay' : 'iapAppStore');
const userCell = (u: { username: string; displayName: string }) => (
  <span>
    <span className="ltr">@{u.username}</span> {u.displayName && <span className="muted small">{u.displayName}</span>}
  </span>
);

/** The purchases table's columns (exported for the tests). */
export function purchaseColumns(t: T, lang: Lang): Column<StoreIapPurchaseRow>[] {
  return [
    { key: 'user', label: 'colUser', render: (r) => userCell(r.user) },
    { key: 'platform', label: 'iapPlatform', render: (r) => platformLabel(t, r.platform) },
    { key: 'product', label: 'iapProductId', render: (r) => <span className="ltr small">{r.productId}</span> },
    { key: 'coins', label: 'iapCoins', sort: 'coins', numeric: true, render: (r) => formatNumber(r.coins, lang) },
    {
      key: 'status',
      label: 'colStatus',
      render: (r) => (
        <span className={`badge ${r.status === 'CREDITED' ? 'ok' : r.status === 'REFUNDED' ? 'bad' : 'warn'}`}>
          {t(`iapStatus${r.status}`)}
          {r.rejectReason ? ` (${r.rejectReason})` : ''}
        </span>
      ),
    },
    {
      key: 'env',
      label: 'iapEnv',
      render: (r) => <span className={`badge ${r.environment === 'SANDBOX' ? 'warn' : 'info'}`}>{t(`iapEnv${r.environment}`)}</span>,
    },
    { key: 'tx', label: 'iapTransaction', optional: true, render: (r) => <span className="ltr small">{r.transactionId}</span> },
    {
      key: 'consent',
      label: 'iapConsent',
      optional: true,
      render: (r) => (
        <span className="small">
          {r.consentVersion} — {t(r.consentShareData ? 'iapConsentShare' : 'iapConsentNoShare')}
        </span>
      ),
    },
    {
      key: 'refund',
      label: 'iapRefund',
      width: '280px',
      render: (r) =>
        r.refundReason ? (
          <span className="small" style={WRAP}>
            <BidiText text={r.refundReason} />
          </span>
        ) : (
          '—'
        ),
    },
    { key: 'created', label: 'colCreated', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
  ];
}

function PurchasesTab() {
  const { t, lang } = useApp();
  return (
    <DataTable<StoreIapPurchaseRow>
      id="iap-purchases"
      endpoint="/admin/store-iap/purchases"
      rowKey={(r) => r.id}
      defaultSort={{ sort: 'createdAt', order: 'desc' }}
      searchLabel="usersSearch"
      csv
      filters={[
        {
          name: 'platform',
          label: 'iapPlatform',
          options: [
            { value: 'GOOGLE_PLAY', label: 'iapGooglePlay' },
            { value: 'APP_STORE', label: 'iapAppStore' },
          ],
        },
        {
          name: 'status',
          label: 'colStatus',
          options: (['CREDITED', 'REJECTED', 'REFUNDED'] as const).map((s) => ({ value: s, label: `iapStatus${s}` })),
        },
        {
          name: 'environment',
          label: 'iapEnv',
          options: (['PRODUCTION', 'SANDBOX'] as const).map((s) => ({ value: s, label: `iapEnv${s}` })),
        },
      ]}
      columns={purchaseColumns(t, lang)}
    />
  );
}

/** The refund bans' columns; the unban buttons only with `store_iap.unban` (exported for the tests). */
export function refundBanColumns(
  t: T,
  lang: Lang,
  can: (c: Capability) => boolean,
  onUnban: (row: StoreIapRefundBanRow, part: 'account' | 'device') => void,
): Column<StoreIapRefundBanRow>[] {
  const owner = can('store_iap.unban');
  const part = (banned: boolean, liftedAt: string | null, reason: string | null, none?: ReactNode) =>
    banned ? (
      <span className="badge bad">{t('iapBanned')}</span>
    ) : liftedAt ? (
      <div className="small" style={{ ...WRAP, maxWidth: 240 }}>
        <span className="badge ok">{t('iapLifted')}</span> <span className="date">{formatDate(liftedAt, lang)}</span>
        {reason && (
          <div className="muted">{reason}</div>
        )}
      </div>
    ) : (
      (none ?? '—')
    );
  return [
    { key: 'user', label: 'colUser', render: (r) => userCell(r.user) },
    {
      key: 'reason',
      label: 'iapBanReason',
      width: '340px',
      render: (r) => (
        <span style={WRAP} data-testid="iap-ban-reason">
          <BidiText text={r.reason} />
        </span>
      ),
    },
    { key: 'coins', label: 'iapCoins', numeric: true, optional: true, render: (r) => formatNumber(r.coins, lang) },
    { key: 'account', label: 'iapAccount', render: (r) => part(r.accountBanned, r.accountLiftedAt, r.accountLiftReason) },
    {
      key: 'device',
      label: 'iapDevice',
      render: (r) =>
        part(r.deviceBanned, r.deviceLiftedAt, r.deviceLiftReason, r.devicesBanned === 0 ? t('iapNoDevice') : undefined),
    },
    {
      key: 'created',
      label: 'colCreated',
      sort: 'createdAt',
      optional: true,
      render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span>,
    },
    {
      key: 'act',
      label: 'colActions',
      render: (r) =>
        !r.accountBanned && !r.deviceBanned ? (
          '—'
        ) : owner ? (
          <span className="row">
            {r.accountBanned && (
              <button className="btn small" onClick={() => onUnban(r, 'account')}>
                {t('iapUnbanAccount')}
              </button>
            )}
            {r.deviceBanned && (
              <button className="btn small" onClick={() => onUnban(r, 'device')}>
                {t('iapUnbanDevice')}
              </button>
            )}
          </span>
        ) : (
          <span className="muted small">{t('iapOwnerOnly')}</span>
        ),
    },
  ];
}

function BansTab() {
  const { t, lang, can, toast } = useApp();
  const [bump, setBump] = useState(0);
  const [unban, setUnban] = useState<{ row: StoreIapRefundBanRow; part: 'account' | 'device' } | null>(null);
  return (
    <>
      <DataTable<StoreIapRefundBanRow>
        id="iap-refund-bans"
        endpoint="/admin/store-iap/refund-bans"
        rowKey={(r) => r.id}
        reloadKey={bump}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        filters={[
          {
            name: 'status',
            label: 'colStatus',
            options: (['ACTIVE', 'LIFTED'] as const).map((s) => ({ value: s, label: `iapBanStatus${s}` })),
          },
        ]}
        columns={refundBanColumns(t, lang, can, (row, part) => setUnban({ row, part }))}
      />
      {unban && (
        <FormDialog
          title={`${t(unban.part === 'account' ? 'iapUnbanAccount' : 'iapUnbanDevice')} — @${unban.row.user.username}`}
          intro={
            <>
              <p className="small">{unban.row.reason}</p>
              <p className="muted small">{t('iapUnbanIntro')}</p>
            </>
          }
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t(unban.part === 'account' ? 'iapUnbanAccount' : 'iapUnbanDevice')}
          danger
          submit={(v) =>
            api.post(`/admin/store-iap/refund-bans/${unban.row.id}/unban`, {
              account: unban.part === 'account',
              device: unban.part === 'device',
              reason: v.reason,
              totpCode: v.totpCode,
            })
          }
          onClose={() => setUnban(null)}
          onDone={() => {
            setUnban(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
