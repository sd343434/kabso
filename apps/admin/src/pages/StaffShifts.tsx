import { useState } from "react";
import { api } from "../api";
import { Avatar, ErrorAlert, useAsync } from "../components";
import { useApp } from "../context";
import { formatDate, formatNumber } from "../format";
import type { PersonRef } from "../types";
import { Icon } from "../ui/icons";

/** `AdminShift` (D260): the signed-in staff member's shift. */
export interface ShiftDto {
  onShift: boolean;
  since: string | null;
  assignedLives: number;
}

/** `AdminShiftRow` (D260): one watch staff member on the OWNER's list. */
export interface ShiftRow {
  user: PersonRef;
  roles: string[];
  onShift: boolean;
  since: string | null;
  assignedLives: number;
}

export interface ShiftList {
  data: ShiftRow[];
  onShift: number;
  unassignedLives: number;
}

/**
 * D260 «في المناوبة»: the staff member's own shift switch (lives.watch). On shift, new lives are assigned to them (by load,
 * the reported ones first); off shift, their lives move to the others. Shows how many lives are theirs now.
 */
export function ShiftSwitch({
  shift,
  onChange,
}: {
  shift: ShiftDto | null;
  onChange: (next: ShiftDto) => void;
}) {
  const { t, lang, toast } = useApp();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const on = shift?.onShift ?? false;
  const flip = async () => {
    setBusy(true);
    setError(null);
    try {
      const next = await api.put<ShiftDto>("/admin/me/shift", { onShift: !on });
      onChange(next);
      toast(t(next.onShift ? "shiftStartedToast" : "shiftEndedToast"));
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="shift-switch card" data-on-shift={on ? "true" : "false"}>
      <label className="switch-row">
        <input
          type="checkbox"
          role="switch"
          checked={on}
          disabled={busy || !shift}
          onChange={() => void flip()}
        />
        <span>
          {t(on ? "shiftOn" : "shiftOff")}
          {on && shift && (
            <span className="muted small shift-count">
              {" "}
              ·{" "}
              {t("shiftMyLives", {
                n: formatNumber(shift.assignedLives, lang),
              })}
            </span>
          )}
        </span>
      </label>
      <p className="muted small">{t("shiftHint")}</p>
      <ErrorAlert error={error} />
    </div>
  );
}

/** D260: the «بثوثي» chip (the lives assigned to me). */
export function MineTab({
  pressed,
  count,
  onClick,
}: {
  pressed: boolean;
  count: number | null;
  onClick: () => void;
}) {
  const { t, lang } = useApp();
  return (
    <button className="tab mine-tab" aria-pressed={pressed} onClick={onClick}>
      <Icon name="eye" size={14} /> {t("liveMine")}
      {count !== null && count > 0 && (
        <span className="count-pill neutral">{formatNumber(count, lang)}</span>
      )}
    </button>
  );
}

/** D260 (OWNER): who is on shift and how many lives each watches; the lives nobody watches. */
export function ShiftsPanel({ list }: { list: ShiftList }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  return (
    <section className="card shifts-panel" aria-label={t("shiftsTitle")}>
      <div className="row">
        <h2 className="h-small">{t("shiftsTitle")}</h2>
        <span className="spacer" />
        <span className="muted small">
          {t("shiftsOnCount", { n: n(list.onShift) })}
        </span>
        {list.unassignedLives > 0 && (
          <span
            className="unassigned small"
            data-unassigned={list.unassignedLives}
          >
            <span className="red-dot" aria-hidden="true" />{" "}
            {t("shiftsUnassigned", { n: n(list.unassignedLives) })}
          </span>
        )}
      </div>
      {list.onShift === 0 && <p className="muted small">{t("shiftsNone")}</p>}
      <table className="table compact">
        <thead>
          <tr>
            <th>{t("colUser")}</th>
            <th>{t("shiftSwitch")}</th>
            <th className="num">{t("shiftsColLives")}</th>
            <th>{t("shiftsColSince")}</th>
          </tr>
        </thead>
        <tbody>
          {list.data.map((r) => (
            <tr key={r.user.id} data-on-shift={r.onShift ? "true" : "false"}>
              <td>
                <span className="row small">
                  <Avatar
                    url={r.user.avatarUrl ?? null}
                    name={r.user.displayName || r.user.username}
                  />
                  <span>{r.user.displayName}</span>
                  <span className="muted ltr">@{r.user.username}</span>
                  <span className="muted">{r.roles.join(" · ")}</span>
                </span>
              </td>
              <td>
                <span className={`shift-pill${r.onShift ? " on" : ""}`}>
                  {t(r.onShift ? "shiftOn" : "shiftOff")}
                </span>
              </td>
              <td className="num">{n(r.assignedLives)}</td>
              <td className="muted small">
                {r.since ? formatDate(r.since, lang) : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

/** The signed-in staff member's shift (lives.watch) and, for OWNER, everyone's (refreshed with the lives). */
export function useShifts(bump: number) {
  const { can } = useApp();
  const mine = useAsync(
    () =>
      can("lives.watch")
        ? api.get<ShiftDto>("/admin/me/shift")
        : Promise.resolve(null),
    [bump],
  );
  const all = useAsync(
    () =>
      can("staff.shifts")
        ? api.get<ShiftList>("/admin/shifts")
        : Promise.resolve(null),
    [bump],
  );
  return { mine, all };
}
