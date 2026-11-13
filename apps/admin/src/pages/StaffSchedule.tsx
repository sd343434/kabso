import { useState } from 'react';
import { api } from '../api';
import { Avatar, Dialog, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import type { Key } from '../i18n';
import type { ScheduleSlot, StaffSchedule } from '../types';
import { Icon } from '../ui/icons';
import { minuteLabel, ShiftCard } from './RoleHomes';
import type { Member } from './Team';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.6): «جدول المناوبات» — the weekly 24/7 schedule of TRUST_SAFETY
 * (MODERATION), SUPPORT and VIP_CARE. Everyone with `staff.schedule.view` reads it with «في المناوبة الآن»; the OWNER
 * (`staff.schedule.manage`) adds, edits and removes slots with a reason (audited). Times are in the app's zone and, when
 * it differs, also in the viewer's own.
 */

export const SCHEDULE_ROLES = ['MODERATION', 'SUPPORT', 'VIP_CARE'] as const;
export const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;

/** "HH:MM" → minutes, or null. 24:00 is the end of the day. */
export function parseClock(v: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(v.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (min > 59 || h > 24 || (h === 24 && min !== 0)) return null;
  return h * 60 + min;
}

/** The slots of one weekday, by start; `onlyNow` keeps those on shift now. */
export function slotsOf(schedule: StaffSchedule, weekday: number, onlyNow: boolean): ScheduleSlot[] {
  return schedule.slots
    .filter((s) => s.weekday === weekday && (!onlyNow || s.onShiftNow))
    .sort((a, b) => a.startMinute - b.startMinute || a.endMinute - b.endMinute);
}

/** The viewer's own clock time for a minute of the schedule's zone today (null when the zones agree). */
export function viewerTime(minute: number, zone: string, now: Date = new Date()): string | null {
  const viewerZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  if (viewerZone === zone) return null;
  const part = (tz: string) => {
    const p = new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
      .formatToParts(now)
      .reduce<Record<string, string>>((acc, x) => ({ ...acc, [x.type]: x.value }), {});
    return Number(p.hour) * 60 + Number(p.minute);
  };
  const offset = part(viewerZone) - part(zone);
  const m = (((minute + offset) % 1440) + 1440) % 1440;
  return minuteLabel(m);
}

/** The week grid (pure: rendered in the tests). */
export function ScheduleGrid({
  schedule,
  onlyNow,
  onEdit,
}: {
  schedule: StaffSchedule;
  onlyNow: boolean;
  onEdit?: (slot: ScheduleSlot) => void;
}) {
  const { t } = useApp();
  return (
    <div className="schedule-grid" data-schedule-grid>
      {WEEKDAYS.map((d) => {
        const slots = slotsOf(schedule, d, onlyNow);
        return (
          <section key={d} className={`card schedule-day ${schedule.now.weekday === d ? 'today' : ''}`}>
            <h3>{t(`weekday${d}` as Key)}</h3>
            {slots.length === 0 && <p className="muted small">{t('schedEmpty')}</p>}
            <ul className="activity">
              {slots.map((s) => {
                const local = viewerTime(s.startMinute, schedule.timeZone);
                return (
                  <li key={s.id} className={s.onShiftNow ? 'on-shift' : ''} data-on-shift={s.onShiftNow || undefined}>
                    <Avatar url={s.person.avatarUrl} name={s.person.displayName} />
                    <span className="names">
                      <strong>{s.person.displayName}</strong>
                      {s.onShiftNow && <span className="badge ok">{t('shiftOnNow')}</span>}
                      <span className="small">
                        {'\u2066'}
                        {minuteLabel(s.startMinute)}–{minuteLabel(s.endMinute)}
                        {'\u2069'}
                      </span>
                      {local && <span className="muted small">{t('schedYourTime', { time: local })}</span>}
                      <span className="muted small">{s.person.roles.map((r) => t(`role${r}`)).join(' · ')}</span>
                    </span>
                    {onEdit && (
                      <button type="button" className="btn small ghost" onClick={() => onEdit(s)} aria-label={t('schedEdit')}>
                        <Icon name="settings" size={14} />
                      </button>
                    )}
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
    </div>
  );
}

function SlotDialog({
  slot,
  people,
  onClose,
  onDone,
  onRemove,
}: {
  slot: ScheduleSlot | null;
  people: Member[];
  onClose: () => void;
  onDone: () => void;
  onRemove?: () => void;
}) {
  const { t } = useApp();
  const [userId, setUserId] = useState(slot?.person.userId ?? people[0]?.id ?? '');
  const [weekday, setWeekday] = useState(slot?.weekday ?? 1);
  const [start, setStart] = useState(slot ? minuteLabel(slot.startMinute) : '08:00');
  const [end, setEnd] = useState(slot ? minuteLabel(slot.endMinute) : '16:00');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const s = parseClock(start);
  const e = parseClock(end);
  const ok = userId !== '' && s !== null && e !== null && e > s && s < 1440 && reason.trim() !== '';
  const save = () => {
    setBusy(true);
    setError(null);
    const body = { userId, weekday, startMinute: s!, endMinute: e!, reason: reason.trim() };
    (slot ? api.put(`/admin/staff-schedule/${slot.id}`, body) : api.post('/admin/staff-schedule', body)).then(onDone, (err: unknown) => {
      setBusy(false);
      setError(err);
    });
  };
  return (
    <Dialog title={t(slot ? 'schedEdit' : 'schedAdd')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        onSubmit={(ev) => {
          ev.preventDefault();
          if (ok && !busy) save();
        }}
      >
        <div className="field">
          <label htmlFor="sched-person">{t('schedPerson')}</label>
          <select id="sched-person" value={userId} onChange={(ev) => setUserId(ev.target.value)}>
            {people.map((p) => (
              <option key={p.id} value={p.id}>
                {p.displayName} {p.staffId ? `(${p.staffId})` : ''} — {p.roles.map((r) => t(`role${r}`)).join(' · ')}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="sched-day">{t('schedWeekday')}</label>
          <select id="sched-day" value={weekday} onChange={(ev) => setWeekday(Number(ev.target.value))}>
            {WEEKDAYS.map((d) => (
              <option key={d} value={d}>
                {t(`weekday${d}` as Key)}
              </option>
            ))}
          </select>
        </div>
        <div className="row">
          <div className="field">
            <label htmlFor="sched-start">{t('schedStart')}</label>
            <input id="sched-start" className="ltr" value={start} onChange={(ev) => setStart(ev.target.value)} placeholder="08:00" />
          </div>
          <div className="field">
            <label htmlFor="sched-end">{t('schedEnd')}</label>
            <input id="sched-end" className="ltr" value={end} onChange={(ev) => setEnd(ev.target.value)} placeholder="16:00" />
          </div>
        </div>
        <p className="muted small">{t('schedNightNote')}</p>
        <div className="field">
          <label htmlFor="sched-reason">{t('reason')}</label>
          <textarea id="sched-reason" maxLength={500} value={reason} onChange={(ev) => setReason(ev.target.value)} />
        </div>
        <div className="actions">
          {onRemove && (
            <button type="button" className="btn danger" onClick={onRemove}>
              {t('schedRemove')}
            </button>
          )}
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button type="submit" className="btn primary" disabled={!ok || busy}>
            {t('save')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

export function StaffSchedulePage() {
  const { t, can, toast } = useApp();
  const manage = can('staff.schedule.manage');
  const res = useAsync(() => api.get<StaffSchedule>('/admin/staff-schedule'), []);
  const team = useAsync(
    () => (manage ? api.get<{ data: Member[] }>('/admin/team') : Promise.resolve({ data: [] as Member[] })),
    [manage],
  );
  const [onlyNow, setOnlyNow] = useState(false);
  const [dialog, setDialog] = useState<'add' | { edit: ScheduleSlot } | { remove: ScheduleSlot } | null>(null);
  const people = (team.data?.data ?? []).filter(
    (m) => m.status === 'ACTIVE' && m.roles.some((r) => (SCHEDULE_ROLES as readonly string[]).includes(r)),
  );
  const done = () => {
    setDialog(null);
    toast(t('done'));
    res.reload();
  };
  if (res.loading && !res.data) return <Loading />;
  if (!res.data) return <ErrorAlert error={res.error} />;
  const data = res.data;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('schedTitle')}</h1>
          <p className="muted small">{t('schedSubtitle')}</p>
          <p className="small">
            <span className="badge">{t('schedZone', { zone: data.timeZone })}</span>{' '}
            {data.me.onShiftNow && (
              <span className="badge ok" data-on-shift-badge>
                {t('schedMe')}
              </span>
            )}
          </p>
        </div>
        {manage && (
          <button className="btn primary" onClick={() => setDialog('add')}>
            <Icon name="plus" size={16} />
            {t('schedAdd')}
          </button>
        )}
      </div>
      <label className="check field">
        <input type="checkbox" checked={onlyNow} onChange={(e) => setOnlyNow(e.target.checked)} />
        {t('schedOnlyNow')}
      </label>
      <div className="dash-grid">
        <ShiftCard shift={data.shift} />
      </div>
      <ScheduleGrid schedule={data} onlyNow={onlyNow} onEdit={manage ? (slot) => setDialog({ edit: slot }) : undefined} />
      {dialog === 'add' && <SlotDialog slot={null} people={people} onClose={() => setDialog(null)} onDone={done} />}
      {dialog && dialog !== 'add' && 'edit' in dialog && (
        <SlotDialog
          slot={dialog.edit}
          people={people}
          onClose={() => setDialog(null)}
          onDone={done}
          onRemove={() => setDialog({ remove: dialog.edit })}
        />
      )}
      {dialog && dialog !== 'add' && 'remove' in dialog && (
        <FormDialog
          title={t('schedRemove')}
          fields={[reasonField(t)]}
          confirmLabel={t('schedRemove')}
          danger
          submit={(v) => api.post(`/admin/staff-schedule/${dialog.remove.id}/remove`, { reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
    </>
  );
}
