import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, UserCell, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';

/**
 * D295 (owner 2026-11-06, CONVENTIONS §10.108.8): «حظر الوكالة — تفعيل صانع محتوى وهمي». OWNER only (`agencies.ban`),
 * the authenticator code again and a reason. The dialog first loads the figures (`GET /admin/agencies/{id}/ban`) and
 * shows the amount to be forfeited before the OWNER confirms; money already withdrawn (or held for a withdrawal) and
 * the members' own earnings are never touched.
 */
export interface AgencyBanPreview {
  agencyId: string;
  status: 'OPEN' | 'CLOSED';
  ban: {
    reason: string;
    commissionCherries: number;
    forfeitedCherries: number;
    creators: number;
    createdAt: string;
  } | null;
  commissionCherries: number;
  balanceCherries: number;
  lockedCherries: number;
  heldCherries: number;
  forfeitCherries: number;
  creators: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl: string | null;
    applicationId: string;
    activatedAt: string;
  }[];
}

export interface AgencyBanResult {
  status: 'BANNED';
  alreadyBanned: boolean;
  commissionCherries: number;
  forfeitedCherries: number;
  revokedCreators: number;
  releasedHosts: number;
  endedRooms: number;
}

/** The figure rows the confirmation shows, in order (pure, for the tests). */
export function banFigureRows(p: AgencyBanPreview): { key: string; value: number; strong?: boolean }[] {
  return [
    { key: 'agencyBanCommission', value: p.commissionCherries },
    { key: 'agencyBanBalance', value: p.balanceCherries },
    { key: 'agencyBanLocked', value: p.lockedCherries },
    { key: 'agencyBanHeld', value: p.heldCherries },
    { key: 'agencyBanForfeit', value: p.forfeitCherries, strong: true },
  ];
}

/** The ban's request body: ONLY the ticked creators are revoked as fake (pure, for the tests). */
export function banBody(v: { reason: string; totpCode: string }, ticked: ReadonlySet<string>) {
  return { reason: v.reason, totpCode: v.totpCode, fakeCreatorUserIds: [...ticked] };
}

/**
 * The figures and the creators this agency activated (rendered inside the confirmation). Owner 2026-11-06: each creator
 * has a checkbox, NONE pre-selected; the OWNER ticks only the fake ones (the others stay creators).
 */
export function AgencyBanFigures({
  preview,
  ticked = new Set<string>(),
  onToggle,
}: {
  preview: AgencyBanPreview;
  ticked?: ReadonlySet<string>;
  onToggle?: (userId: string) => void;
}) {
  const { t, lang } = useApp();
  return (
    <div data-agency-ban-figures>
      <p className="muted small">{t('agencyBanIntro')}</p>
      <dl className="kv small">
        {banFigureRows(preview).map((r) => (
          <div key={r.key} className="contents">
            <dt>{t(r.key as never)}</dt>
            <dd className="mono ltr" data-figure={r.key}>
              {r.strong ? <strong>{formatNumber(r.value, lang)}</strong> : formatNumber(r.value, lang)}
            </dd>
          </div>
        ))}
      </dl>
      <p className="small">{t('agencyBanCreators')}</p>
      {preview.creators.length === 0 ? (
        <p className="muted small">{t('agencyBanNoCreators')}</p>
      ) : (
        <>
          <p className="muted small">{t('agencyBanTickHint')}</p>
          <ul className="plain">
            {preview.creators.map((c) => (
              <li key={c.id} data-ban-creator={c.id}>
                <label className="row">
                  <input
                    type="checkbox"
                    data-ban-tick={c.id}
                    checked={ticked.has(c.id)}
                    onChange={() => onToggle?.(c.id)}
                  />
                  <UserCell username={c.username} displayName={c.displayName} avatarUrl={c.avatarUrl} />{' '}
                  <span className="date muted small">{formatDate(c.activatedAt, lang)}</span>
                </label>
              </li>
            ))}
          </ul>
          <p className="small" data-ban-ticked={ticked.size}>
            {t('agencyBanTicked', { n: ticked.size })}
          </p>
        </>
      )}
    </div>
  );
}

export function AgencyBanDialog({
  agencyId,
  onClose,
  onDone,
}: {
  agencyId: string;
  onClose: () => void;
  onDone: (r: AgencyBanResult) => void;
}) {
  const { t } = useApp();
  const [ticked, setTicked] = useState<ReadonlySet<string>>(new Set());
  const { data, error, loading } = useAsync(
    () => api.get<AgencyBanPreview>(`/admin/agencies/${agencyId}/ban`),
    [agencyId],
  );
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const toggle = (id: string) =>
    setTicked((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  return (
    <FormDialog
      title={t('agencyBanTitle')}
      intro={<AgencyBanFigures preview={data} ticked={ticked} onToggle={toggle} />}
      fields={[reasonField(t), codeField(t)]}
      confirmLabel={t('agencyBan')}
      danger
      submit={(v) =>
        api
          .post<AgencyBanResult>(
            `/admin/agencies/${agencyId}/ban`,
            banBody({ reason: v.reason ?? '', totpCode: v.totpCode ?? '' }, ticked),
          )
          .then((r) => onDone(r))
      }
      onClose={onClose}
      onDone={() => undefined}
    />
  );
}
