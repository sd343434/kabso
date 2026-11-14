import { useState } from "react";
import { api } from "../api";
import { ErrorAlert, FormDialog, reasonField, useAsync } from "../components";
import { useApp } from "../context";
import type { Key } from "../i18n";
import { formatDate } from "../format";
import { Icon } from "../ui/icons";

/** D378 (§10.168.4): the classes of a golden ID «آيدي ذهبي» (`VipGoldenIdClass`). */
export const GOLDEN_ID_CLASSES = [
  "REPEATED",
  "THREE_DIGIT",
  "FOUR_DIGIT",
  "FIVE_DIGIT",
] as const;
export type GoldenIdClass = (typeof GOLDEN_ID_CLASSES)[number];
export type GoldenIdState = "FREE" | "HELD" | "GRACE";

/** `AdminVipGoldenId`. */
export interface AdminVipGoldenId {
  number: string;
  class: GoldenIdClass;
  state: GoldenIdState;
  holder: { id: string; username: string } | null;
  heldUntil: string | null;
  graceUntil: string | null;
  claimedAt: string | null;
}

/** `AdminVipGoldenIdList`. */
export interface AdminVipGoldenIdList {
  data: AdminVipGoldenId[];
  classes: GoldenIdClass[];
}

/** The days a number is kept for its holder after the membership (the server's `VIP_GOLDEN_ID_GRACE_DAYS`). */
export const GOLDEN_ID_GRACE_DAYS = 7;

/** At most this many numbers in one save (the server's `VIP_GOLDEN_ID_ADD_MAX`). */
export const GOLDEN_ID_ADD_MAX = 100;

const GOLDEN = /^[1-9][0-9]{1,7}$/;

/**
 * The class the server gives [n] (its `vipGoldenIdClassOf`), or null when [n] is not a golden ID: one digit repeated
 * (2 … 8 long) is REPEATED; otherwise 3, 4 or 5 digits.
 */
export function goldenIdClassOf(n: string): GoldenIdClass | null {
  if (!GOLDEN.test(n)) return null;
  if (/^(\d)\1+$/.test(n)) return "REPEATED";
  return n.length === 3
    ? "THREE_DIGIT"
    : n.length === 4
      ? "FOUR_DIGIT"
      : n.length === 5
        ? "FIVE_DIGIT"
        : null;
}

/**
 * The numbers typed in the add dialog (commas, spaces, Arabic commas or lines between them; Arabic-Indic digits read
 * as Latin), or the first one that is not a golden ID / is repeated, as the server would refuse it.
 */
export function parseGoldenNumbers(
  raw: string,
): { ok: true; numbers: string[] } | { ok: false; bad: string } {
  const latin = raw.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
  const parts = latin.split(/[\s,،]+/).filter((p) => p !== "");
  if (parts.length === 0 || parts.length > GOLDEN_ID_ADD_MAX) {
    return { ok: false, bad: "" };
  }
  const seen = new Set<string>();
  for (const p of parts) {
    if (goldenIdClassOf(p) === null || seen.has(p))
      return { ok: false, bad: p };
    seen.add(p);
  }
  return { ok: true, numbers: parts };
}

/** The table of the stock (read-only without `catalog.manage`). */
export function GoldenIdTable({
  list,
  onRemove,
}: {
  list: AdminVipGoldenIdList;
  onRemove: (n: AdminVipGoldenId) => void;
}) {
  const { t, lang, can } = useApp();
  const manage = can("catalog.manage");
  if (list.data.length === 0) {
    return <p className="muted state">{t("vipGoldenEmpty")}</p>;
  }
  return (
    <div className="table-wrap">
      <table data-vip-golden-ids>
        <thead>
          <tr>
            <th>{t("vipGoldenColNumber")}</th>
            <th>{t("vipGoldenColClass")}</th>
            <th>{t("vipGoldenColState")}</th>
            <th>{t("vipGoldenColHolder")}</th>
            <th>{t("vipGoldenColUntil")}</th>
            {manage && <th />}
          </tr>
        </thead>
        <tbody>
          {list.data.map((g) => (
            <tr key={g.number} data-vip-golden-id={g.number}>
              <td className="ltr mono">
                <span className="vip-golden-chip">ID {g.number}</span>
              </td>
              <td>{t(`vipGoldenClass_${g.class}` as Key)}</td>
              <td>
                <span
                  className={`badge ${g.state === "FREE" ? "ok" : g.state === "HELD" ? "info" : "warn"}`}
                  data-vip-golden-state={g.state}
                >
                  {t(`vipGoldenState_${g.state}` as Key)}
                </span>
              </td>
              <td className="ltr">
                {g.holder ? `@${g.holder.username}` : "—"}
              </td>
              <td>
                {g.state === "HELD"
                  ? formatDate(g.heldUntil, lang)
                  : g.state === "GRACE"
                    ? formatDate(g.graceUntil, lang)
                    : "—"}
              </td>
              {manage && (
                <td>
                  {g.state === "FREE" && (
                    <button
                      className="btn small danger"
                      onClick={() => onRemove(g)}
                      data-vip-golden-remove={g.number}
                    >
                      {t("vipGoldenRemove")}
                    </button>
                  )}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** D378 «مخزون الآيدي الذهبي»: the owner's stock on the VIP page — filters, add, remove (a reason each, audited). */
export function VipGoldenIds() {
  const { t, can, toast } = useApp();
  const [cls, setCls] = useState<GoldenIdClass | "">("");
  const [state, setState] = useState<GoldenIdState | "">("");
  const { data, error, loading, reload } = useAsync(() => {
    const q = new URLSearchParams();
    if (cls) q.set("class", cls);
    if (state) q.set("state", state);
    const qs = q.toString();
    return api.get<AdminVipGoldenIdList>(
      `/admin/vip/golden-ids${qs ? `?${qs}` : ""}`,
    );
  }, [cls, state]);
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<AdminVipGoldenId | null>(null);
  const done = () => {
    setAdding(false);
    setRemoving(null);
    toast(t("done"));
    reload();
  };
  return (
    <section className="card" data-vip-golden>
      <div className="page-head">
        <div>
          <h2>{t("vipGoldenTitle")}</h2>
          <p className="muted small">
            {t("vipGoldenIntro", { days: String(GOLDEN_ID_GRACE_DAYS) })}
          </p>
        </div>
        {can("catalog.manage") && (
          <button
            className="btn primary"
            onClick={() => setAdding(true)}
            data-vip-golden-add
          >
            <Icon name="plus" size={16} />
            {t("vipGoldenAdd")}
          </button>
        )}
      </div>
      <div className="filters">
        <select
          aria-label={t("vipGoldenColClass")}
          value={cls}
          onChange={(e) => setCls(e.target.value as GoldenIdClass | "")}
        >
          <option value="">{t("vipGoldenAllClasses")}</option>
          {GOLDEN_ID_CLASSES.map((c) => (
            <option key={c} value={c}>
              {t(`vipGoldenClass_${c}` as Key)}
            </option>
          ))}
        </select>
        <select
          aria-label={t("vipGoldenColState")}
          value={state}
          onChange={(e) => setState(e.target.value as GoldenIdState | "")}
        >
          <option value="">{t("vipGoldenAllStates")}</option>
          {(["FREE", "HELD", "GRACE"] as const).map((s) => (
            <option key={s} value={s}>
              {t(`vipGoldenState_${s}` as Key)}
            </option>
          ))}
        </select>
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <p className="muted state">{t("loading")}</p>}
      {data && <GoldenIdTable list={data} onRemove={setRemoving} />}
      {adding && (
        <FormDialog
          title={t("vipGoldenAdd")}
          fields={[
            {
              name: "numbers",
              label: t("vipGoldenNumbers"),
              kind: "textarea",
              required: true,
              hint: t("vipGoldenNumbersHint"),
              maxLength: 2000,
            },
            reasonField(t),
          ]}
          confirmLabel={t("save")}
          submit={(v) => {
            const parsed = parseGoldenNumbers(v.numbers ?? "");
            if (!parsed.ok) {
              return Promise.reject(
                new Error(`${t("vipGoldenNumbersHint")} ${parsed.bad}`.trim()),
              );
            }
            return api.post("/admin/vip/golden-ids", {
              numbers: parsed.numbers,
              reason: v.reason,
            });
          }}
          onClose={() => setAdding(false)}
          onDone={done}
        />
      )}
      {removing && (
        <FormDialog
          title={t("vipGoldenRemoveTitle", { number: removing.number })}
          fields={[reasonField(t)]}
          confirmLabel={t("vipGoldenRemove")}
          danger
          submit={(v) =>
            api.post(`/admin/vip/golden-ids/${removing.number}/remove`, {
              reason: v.reason,
            })
          }
          onClose={() => setRemoving(null)}
          onDone={done}
        />
      )}
    </section>
  );
}
