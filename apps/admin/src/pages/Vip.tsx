import { useState } from "react";
import { api, uploadVipArt } from "../api";
import {
  Dialog,
  ErrorAlert,
  FormDialog,
  reasonField,
  useAsync,
} from "../components";
import { useApp } from "../context";
import { formatNumber } from "../format";
import { Icon } from "../ui/icons";
import "./vip.css";

/** `AdminVipPerk` (v1.82-social, D252). `available`: the app really does it (server list, read-only). */
export interface AdminVipPerk {
  code: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string | null;
  descriptionEn: string | null;
  enabled: boolean;
  available: boolean;
  animation: string | null;
  still: string | null;
  artWidth: number | null;
  artHeight: number | null;
  /** v1.83-social (D258): the perk's number for this tier (bullets / coins a day, level speed-up %). */
  amount: number | null;
}

/** `AdminVipTier` (v1.82-social, D252). `sortOrder` is the order and the rank. */
export interface AdminVipTier {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  sortOrder: number;
  color: string;
  badgeAnimation: string | null;
  badgeStill: string | null;
  priceCoins: number;
  durationDays: number;
  enabled: boolean;
  activeMembers: number;
  perks: AdminVipPerk[];
  updatedAt: string;
}

/** `AdminVipTierList`. */
export interface AdminVipTierList {
  data: AdminVipTier[];
  builtPerks: string[];
  suggestedPerks: string[];
}

/** One perk row of the form. */
export interface PerkDraft {
  code: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  enabled: boolean;
  animation: string;
  still: string;
  artWidth: string;
  artHeight: string;
  amount: string;
}

/** The tier form. */
export interface TierDraft {
  code: string;
  nameAr: string;
  nameEn: string;
  color: string;
  badgeAnimation: string;
  badgeStill: string;
  priceCoins: string;
  durationDays: string;
  enabled: boolean;
  perks: PerkDraft[];
}

const CODE = /^[A-Z][A-Z0-9_]{0,39}$/;
const COLOR = /^#[0-9A-Fa-f]{6}$/;
/** A hosted https URL (the server checks it again). Art is uploaded; nothing is bundled. */
const ART = /^https:\/\/\S{1,2040}$/;

function artOk(v: string): boolean {
  return v.trim() === "" || ART.test(v.trim());
}
/** D258: the perks that take a number and its bounds (the server checks them again). */
export const PERK_AMOUNTS: Record<string, [number, number]> = {
  DAILY_BULLET: [1, 100],
  DAILY_COINS: [1, 1_000_000_000],
  LEVEL_SPEEDUP: [1, 100],
};

export function amountOk(code: string, v: string): boolean {
  if (v.trim() === "") return true;
  const bounds = PERK_AMOUNTS[code.trim()];
  if (!bounds) return false;
  const n = Number(v);
  return Number.isInteger(n) && n >= bounds[0] && n <= bounds[1];
}

function sizeOk(v: string): boolean {
  if (v.trim() === "") return true;
  const n = Number(v);
  return Number.isInteger(n) && n >= 1 && n <= 8192;
}

export function draftOf(tier: AdminVipTier | null): TierDraft {
  return {
    code: tier?.code ?? "",
    nameAr: tier?.nameAr ?? "",
    nameEn: tier?.nameEn ?? "",
    color: tier?.color ?? "#C9A227",
    badgeAnimation: tier?.badgeAnimation ?? "",
    badgeStill: tier?.badgeStill ?? "",
    priceCoins: tier ? String(tier.priceCoins) : "",
    durationDays: tier ? String(tier.durationDays) : "30",
    enabled: tier?.enabled ?? false,
    perks: (tier?.perks ?? []).map((p) => ({
      code: p.code,
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      descriptionAr: p.descriptionAr ?? "",
      descriptionEn: p.descriptionEn ?? "",
      enabled: p.enabled,
      animation: p.animation ?? "",
      still: p.still ?? "",
      artWidth: p.artWidth === null ? "" : String(p.artWidth),
      artHeight: p.artHeight === null ? "" : String(p.artHeight),
      amount: p.amount === null || p.amount === undefined ? "" : String(p.amount),
    })),
  };
}

/** The same rules as the server (it checks them again): code, names, colour, price, length, unique perk codes. */
export function draftValid(d: TierDraft, creating: boolean): boolean {
  const price = Number(d.priceCoins);
  const days = Number(d.durationDays);
  const codes = d.perks.map((p) => p.code.trim());
  return (
    (!creating || CODE.test(d.code.trim())) &&
    d.nameAr.trim() !== "" &&
    d.nameEn.trim() !== "" &&
    COLOR.test(d.color.trim()) &&
    artOk(d.badgeAnimation) &&
    artOk(d.badgeStill) &&
    Number.isInteger(price) &&
    price >= 1 &&
    price <= 1_000_000_000_000 &&
    Number.isInteger(days) &&
    days >= 1 &&
    days <= 365 &&
    d.perks.length <= 20 &&
    d.perks.every(
      (p) =>
        CODE.test(p.code.trim()) &&
        p.titleAr.trim() !== "" &&
        p.titleEn.trim() !== "" &&
        artOk(p.animation) &&
        artOk(p.still) &&
        sizeOk(p.artWidth) &&
        sizeOk(p.artHeight) &&
        amountOk(p.code, p.amount),
    ) &&
    new Set(codes).size === codes.length
  );
}

function perksBody(perks: PerkDraft[]) {
  return perks.map((p) => ({
    code: p.code.trim(),
    titleAr: p.titleAr.trim(),
    titleEn: p.titleEn.trim(),
    descriptionAr: p.descriptionAr.trim() || null,
    descriptionEn: p.descriptionEn.trim() || null,
    enabled: p.enabled,
    animation: p.animation.trim() || null,
    still: p.still.trim() || null,
    artWidth: p.artWidth.trim() === "" ? null : Number(p.artWidth),
    artHeight: p.artHeight.trim() === "" ? null : Number(p.artHeight),
    amount: p.amount.trim() === "" ? null : Number(p.amount),
  }));
}

/** The form → the request body: on create every field; on an edit only what changed (the perks as a whole list). */
export function tierBody(
  d: TierDraft,
  before: AdminVipTier | null,
): Record<string, unknown> {
  const fields: Record<string, unknown> = {
    nameAr: d.nameAr.trim(),
    nameEn: d.nameEn.trim(),
    color: d.color.trim().toUpperCase(),
    badgeAnimation: d.badgeAnimation.trim() || null,
    badgeStill: d.badgeStill.trim() || null,
    priceCoins: Number(d.priceCoins),
    durationDays: Number(d.durationDays),
  };
  const perks = perksBody(d.perks);
  if (before === null) {
    return { code: d.code.trim(), ...fields, enabled: d.enabled, perks };
  }
  const out: Record<string, unknown> = Object.fromEntries(
    Object.entries(fields).filter(
      ([k, v]) => (before as unknown as Record<string, unknown>)[k] !== v,
    ),
  );
  const beforePerks = perksBody(draftOf(before).perks);
  if (JSON.stringify(beforePerks) !== JSON.stringify(perks)) out.perks = perks;
  return out;
}

/** The ids with the one at [index] moved by [step] (−1 up, +1 down); null when it cannot move. */
export function moveTier(
  ids: readonly string[],
  index: number,
  step: -1 | 1,
): string[] | null {
  const to = index + step;
  if (index < 0 || index >= ids.length || to < 0 || to >= ids.length)
    return null;
  const out = [...ids];
  [out[index], out[to]] = [out[to]!, out[index]!];
  return out;
}

/** The tiers table (pure: rendered in the tests). */
export function VipTiersTable({
  list,
  onEdit,
  onToggle,
  onMove,
}: {
  list: AdminVipTierList;
  onEdit: (t: AdminVipTier) => void;
  onToggle: (t: AdminVipTier) => void;
  onMove: (index: number, step: -1 | 1) => void;
}) {
  const { t, lang, can } = useApp();
  const manage = can("catalog.manage");
  return (
    <div className="table-wrap">
      <table data-vip-tiers>
        <thead>
          <tr>
            <th className="num">{t("vipOrder")}</th>
            <th>{t("vipNameAr")}</th>
            <th>{t("vipNameEn")}</th>
            <th>{t("vipCode")}</th>
            <th className="num">{t("vipPrice")}</th>
            <th>{t("vipDuration")}</th>
            <th>{t("vipPerks")}</th>
            <th className="num">{t("vipMembers")}</th>
            <th>{t("state")}</th>
            {manage && <th />}
          </tr>
        </thead>
        <tbody>
          {list.data.map((tier, i) => (
            <tr
              key={tier.id}
              className={tier.enabled ? "" : "muted"}
              data-vip-tier={tier.code}
            >
              <td className="num">
                <span className="vip-order">
                  {formatNumber(i + 1, lang)}
                  {manage && (
                    <>
                      <button
                        className="btn small"
                        aria-label={t("vipMoveUp")}
                        disabled={i === 0}
                        onClick={() => onMove(i, -1)}
                        data-vip-up={tier.code}
                      >
                        <Icon name="arrowUp" size={14} />
                      </button>
                      <button
                        className="btn small"
                        aria-label={t("vipMoveDown")}
                        disabled={i === list.data.length - 1}
                        onClick={() => onMove(i, 1)}
                        data-vip-down={tier.code}
                      >
                        <Icon name="arrowDown" size={14} />
                      </button>
                    </>
                  )}
                </span>
              </td>
              <td>
                <span className="vip-name">
                  <span
                    className="vip-swatch"
                    style={{ background: tier.color }}
                    aria-hidden="true"
                  />
                  {tier.nameAr}
                </span>
              </td>
              <td dir="ltr">{tier.nameEn}</td>
              <td className="mono small ltr">{tier.code}</td>
              <td className="num">🪙 {formatNumber(tier.priceCoins, lang)}</td>
              <td>
                {t("vipDays", { n: formatNumber(tier.durationDays, lang) })}
              </td>
              <td>
                <span className="vip-perks">
                  {tier.perks.map((p) => (
                    <span
                      key={p.code}
                      className={`badge ${p.available ? "ok" : ""} ${p.enabled ? "" : "muted"}`}
                      title={
                        p.available ? t("vipPerkBuilt") : t("vipPerkNotBuilt")
                      }
                    >
                      {lang === "ar" ? p.titleAr : p.titleEn}
                    </span>
                  ))}
                </span>
              </td>
              <td className="num">{formatNumber(tier.activeMembers, lang)}</td>
              <td>
                <span className={`badge ${tier.enabled ? "ok" : ""}`}>
                  {tier.enabled ? t("enabled") : t("disabled")}
                </span>
              </td>
              {manage && (
                <td>
                  <div className="row end">
                    <button
                      className="btn small"
                      onClick={() => onEdit(tier)}
                      data-vip-edit={tier.code}
                    >
                      {t("edit")}
                    </button>
                    <button
                      className={`btn small ${tier.enabled ? "" : "primary"}`}
                      onClick={() => onToggle(tier)}
                      data-vip-toggle={tier.code}
                    >
                      {tier.enabled ? t("disable") : t("enable")}
                    </button>
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {list.data.length === 0 && <p className="muted state">{t("vipNone")}</p>}
    </div>
  );
}

/** The perks editor of the form (pure: rendered in the tests). */
export function PerksEditor({
  perks,
  built,
  suggested,
  onChange,
  tierCode = "",
}: {
  perks: PerkDraft[];
  built: readonly string[];
  suggested: readonly string[];
  onChange: (p: PerkDraft[]) => void;
  /** D258: the tier's code (the uploads' folder); empty while it is not set. */
  tierCode?: string;
}) {
  const { t } = useApp();
  const set = (i: number, patch: Partial<PerkDraft>) =>
    onChange(perks.map((p, j) => (j === i ? { ...p, ...patch } : p)));
  // D258: one upload at a time («i:kind»), and the last failure.
  const [uploading, setUploading] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const upload = async (i: number, kind: "animation" | "still", file: File | undefined) => {
    if (!file || !CODE.test(tierCode)) return;
    setUploading(`${i}:${kind}`);
    setUploadError(null);
    try {
      const up = await uploadVipArt(kind, tierCode, file);
      set(
        i,
        kind === "animation"
          ? { animation: up.url }
          : {
              still: up.url,
              artWidth: up.width === null ? "" : String(up.width),
              artHeight: up.height === null ? "" : String(up.height),
            },
      );
    } catch (e) {
      setUploadError(e instanceof Error ? e.message : t("vipUploadFailed"));
    } finally {
      setUploading(null);
    }
  };
  const move = (i: number, step: -1 | 1) => {
    const to = i + step;
    if (to < 0 || to >= perks.length) return;
    const out = [...perks];
    [out[i], out[to]] = [out[to]!, out[i]!];
    onChange(out);
  };
  return (
    <div className="span-2 vip-perk-editor" data-vip-perks>
      <div className="row">
        <strong>{t("vipPerks")}</strong>
        <button
          type="button"
          className="btn small"
          disabled={perks.length >= 20}
          onClick={() =>
            onChange([
              ...perks,
              {
                code: "",
                titleAr: "",
                titleEn: "",
                descriptionAr: "",
                descriptionEn: "",
                enabled: true,
                animation: "",
                still: "",
                amount: "",
                artWidth: "",
                artHeight: "",
              },
            ])
          }
          data-vip-perk-add
        >
          <Icon name="plus" size={14} />
          {t("vipPerkAdd")}
        </button>
      </div>
      <p className="muted small">{t("vipPerksNote")}</p>
      <datalist id="vip-perk-codes">
        {suggested.map((c) => (
          <option key={c} value={c} />
        ))}
      </datalist>
      {perks.map((p, i) => (
        <div className="vip-perk" key={i} data-vip-perk={i}>
          <div className="form-grid">
            <div className="field">
              <label htmlFor={`vp-code-${i}`}>{t("vipPerkCode")}</label>
              <input
                id={`vp-code-${i}`}
                className="ltr mono"
                list="vip-perk-codes"
                maxLength={40}
                value={p.code}
                onChange={(e) => set(i, { code: e.target.value.toUpperCase() })}
              />
              <span className={`hint ${built.includes(p.code) ? "ok" : ""}`}>
                {built.includes(p.code)
                  ? t("vipPerkBuilt")
                  : t("vipPerkNotBuilt")}
              </span>
            </div>
            <label className="check">
              <input
                type="checkbox"
                checked={p.enabled}
                onChange={(e) => set(i, { enabled: e.target.checked })}
              />
              {t("vipPerkShown")}
            </label>
            <div className="field">
              <label htmlFor={`vp-tar-${i}`}>{t("vipPerkTitleAr")}</label>
              <input
                id={`vp-tar-${i}`}
                dir="rtl"
                maxLength={40}
                value={p.titleAr}
                onChange={(e) => set(i, { titleAr: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-ten-${i}`}>{t("vipPerkTitleEn")}</label>
              <input
                id={`vp-ten-${i}`}
                dir="ltr"
                maxLength={40}
                value={p.titleEn}
                onChange={(e) => set(i, { titleEn: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-dar-${i}`}>{t("vipPerkDescAr")}</label>
              <input
                id={`vp-dar-${i}`}
                dir="rtl"
                maxLength={200}
                value={p.descriptionAr}
                onChange={(e) => set(i, { descriptionAr: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-den-${i}`}>{t("vipPerkDescEn")}</label>
              <input
                id={`vp-den-${i}`}
                dir="ltr"
                maxLength={200}
                value={p.descriptionEn}
                onChange={(e) => set(i, { descriptionEn: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-still-${i}`}>{t("vipPerkStill")}</label>
              <input
                id={`vp-still-${i}`}
                className="ltr"
                maxLength={2048}
                value={p.still}
                onChange={(e) => set(i, { still: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-anim-${i}`}>{t("vipPerkAnimation")}</label>
              <input
                id={`vp-anim-${i}`}
                className="ltr"
                maxLength={2048}
                value={p.animation}
                onChange={(e) => set(i, { animation: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-aw-${i}`}>{t("vipArtW")}</label>
              <input
                id={`vp-aw-${i}`}
                type="number"
                min={1}
                max={8192}
                className="num"
                value={p.artWidth}
                onChange={(e) => set(i, { artWidth: e.target.value })}
              />
            </div>
            <div className="field">
              <label htmlFor={`vp-ah-${i}`}>{t("vipArtH")}</label>
              <input
                id={`vp-ah-${i}`}
                type="number"
                min={1}
                max={8192}
                className="num"
                value={p.artHeight}
                onChange={(e) => set(i, { artHeight: e.target.value })}
              />
            </div>
          </div>
            <div className="field">
              <label htmlFor={`vp-amount-${i}`}>{t("vipPerkAmount")}</label>
              <input
                id={`vp-amount-${i}`}
                type="number"
                min={1}
                className="num"
                data-vip-amount={p.code}
                disabled={!PERK_AMOUNTS[p.code.trim()] && p.amount === ""}
                aria-invalid={!amountOk(p.code, p.amount)}
                value={p.amount}
                onChange={(e) => set(i, { amount: e.target.value })}
              />
              {!amountOk(p.code, p.amount) && (
                <span className="error small">{t("vipPerkAmountBad")}</span>
              )}
            </div>
            <div className="field">
              <span>{t("vipUploadStill")} / {t("vipUploadAnimation")}</span>
              <div className="row">
                <label className="btn small">
                  {uploading === `${i}:still` ? t("vipUploading") : t("vipUploadStill")}
                  <input
                    type="file"
                    hidden
                    accept="image/png,image/webp"
                    data-vip-upload={`${i}:still`}
                    disabled={uploading !== null || !CODE.test(tierCode)}
                    onChange={(e) => void upload(i, "still", e.target.files?.[0])}
                  />
                </label>
                <label className="btn small">
                  {uploading === `${i}:animation` ? t("vipUploading") : t("vipUploadAnimation")}
                  <input
                    type="file"
                    hidden
                    accept=".svga"
                    data-vip-upload={`${i}:animation`}
                    disabled={uploading !== null || !CODE.test(tierCode)}
                    onChange={(e) => void upload(i, "animation", e.target.files?.[0])}
                  />
                </label>
              </div>
            </div>
          <p className="muted small">{t("vipPerkAmountHint")}</p>
          {uploadError && <div className="alert error">{uploadError}</div>}
          <p className="muted small">{t("vipArtHint")}</p>
          <div className="row end">
            <button
              type="button"
              className="btn small"
              disabled={i === 0}
              onClick={() => move(i, -1)}
            >
              {t("vipPerkUp")}
            </button>
            <button
              type="button"
              className="btn small"
              disabled={i === perks.length - 1}
              onClick={() => move(i, 1)}
            >
              {t("vipPerkDown")}
            </button>
            <button
              type="button"
              className="btn small danger"
              onClick={() => onChange(perks.filter((_, j) => j !== i))}
            >
              {t("remove")}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

function TierForm({
  tier,
  list,
  onClose,
  onDone,
}: {
  tier: AdminVipTier | null;
  list: AdminVipTierList;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const [draft, setDraft] = useState<TierDraft>(() => draftOf(tier));
  const [reason, setReason] = useState("");
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const body = tierBody(draft, tier);
  const valid = draftValid(draft, tier === null);
  const ok =
    reason.trim() !== "" &&
    valid &&
    (tier === null || Object.keys(body).length > 0);
  const set = (k: keyof TierDraft) => (e: { target: { value: string } }) =>
    setDraft((d) => ({
      ...d,
      [k]: k === "code" ? e.target.value.toUpperCase() : e.target.value,
    }));
  return (
    <Dialog
      title={tier ? t("vipEdit", { code: tier.code }) : t("vipAdd")}
      onClose={onClose}
    >
      <ErrorAlert error={error} />
      <form
        className="form-grid vip-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          const req = tier
            ? api.patch(`/admin/vip/tiers/${tier.id}`, {
                ...body,
                reason: reason.trim(),
              })
            : api.post("/admin/vip/tiers", { ...body, reason: reason.trim() });
          req.then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        {!tier && (
          <div className="field">
            <label htmlFor="vip-code">{t("vipCode")}</label>
            <input
              id="vip-code"
              className="ltr mono"
              maxLength={40}
              value={draft.code}
              onChange={set("code")}
            />
          </div>
        )}
        <div className="field">
          <label htmlFor="vip-color">{t("vipColor")}</label>
          <span className="vip-color">
            <input
              type="color"
              aria-label={t("vipColor")}
              value={COLOR.test(draft.color) ? draft.color : "#000000"}
              onChange={(e) =>
                setDraft((d) => ({ ...d, color: e.target.value.toUpperCase() }))
              }
            />
            <input
              id="vip-color"
              className="ltr mono"
              maxLength={7}
              value={draft.color}
              onChange={set("color")}
            />
          </span>
        </div>
        <div className="field">
          <label htmlFor="vip-ar">{t("vipNameAr")}</label>
          <input
            id="vip-ar"
            dir="rtl"
            maxLength={30}
            value={draft.nameAr}
            onChange={set("nameAr")}
          />
        </div>
        <div className="field">
          <label htmlFor="vip-en">{t("vipNameEn")}</label>
          <input
            id="vip-en"
            dir="ltr"
            maxLength={30}
            value={draft.nameEn}
            onChange={set("nameEn")}
          />
        </div>
        <div className="field">
          <label htmlFor="vip-price">{t("vipPrice")}</label>
          <input
            id="vip-price"
            type="number"
            min={1}
            className="ltr mono"
            value={draft.priceCoins}
            onChange={set("priceCoins")}
          />
        </div>
        <div className="field">
          <label htmlFor="vip-days">{t("vipDuration")}</label>
          <input
            id="vip-days"
            type="number"
            min={1}
            max={365}
            className="num"
            value={draft.durationDays}
            onChange={set("durationDays")}
          />
        </div>
        <div className="field">
          <label htmlFor="vip-badge-still">{t("vipBadgeStill")}</label>
          <input
            id="vip-badge-still"
            className="ltr"
            maxLength={2048}
            value={draft.badgeStill}
            onChange={set("badgeStill")}
          />
        </div>
        <div className="field">
          <label htmlFor="vip-badge-anim">{t("vipBadgeAnimation")}</label>
          <input
            id="vip-badge-anim"
            className="ltr"
            maxLength={2048}
            value={draft.badgeAnimation}
            onChange={set("badgeAnimation")}
          />
        </div>
        <p className="span-2 muted small">{t("vipBadgeHint")}</p>
        {!tier && (
          <label className="check span-2">
            <input
              type="checkbox"
              checked={draft.enabled}
              onChange={(e) =>
                setDraft((d) => ({ ...d, enabled: e.target.checked }))
              }
            />
            {t("vipStartOn")}
          </label>
        )}
        {tier && <p className="span-2 muted small">{t("vipPriceNote")}</p>}
        <PerksEditor
          tierCode={draft.code.trim()}
          perks={draft.perks}
          built={list.builtPerks}
          suggested={list.suggestedPerks}
          onChange={(perks) => setDraft((d) => ({ ...d, perks }))}
        />
        {!valid && <div className="span-2 alert error">{t("vipInvalid")}</div>}
        <div className="field span-2">
          <label htmlFor="vip-reason">{t("reason")}</label>
          <textarea
            id="vip-reason"
            maxLength={500}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
          <span className="hint">{t("reasonHint")}</span>
        </div>
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t("cancel")}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {tier ? t("save") : t("vipAdd")}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** «VIP» (v1.82-social, D252, CONVENTIONS §10.93.4): the tiers of «شراء VIP», their order and their own perks. */
export function Vip() {
  const { t, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(
    () => api.get<AdminVipTierList>("/admin/vip/tiers"),
    [],
  );
  const [edit, setEdit] = useState<AdminVipTier | "new" | null>(null);
  const [toggle, setToggle] = useState<AdminVipTier | null>(null);
  const [order, setOrder] = useState<string[] | null>(null);
  const done = () => {
    setEdit(null);
    setToggle(null);
    setOrder(null);
    toast(t("done"));
    reload();
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t("vipTitle")}</h1>
          <p className="muted small">{t("vipSubtitle")}</p>
        </div>
        {can("catalog.manage") && data && (
          <button
            className="btn primary"
            onClick={() => setEdit("new")}
            data-vip-add
          >
            <Icon name="plus" size={16} />
            {t("vipAdd")}
          </button>
        )}
      </div>
      <ErrorAlert error={error} />
      <div className="card">
        {loading && !data && <p className="muted state">{t("loading")}</p>}
        {data && (
          <VipTiersTable
            list={data}
            onEdit={(tier) => setEdit(tier)}
            onToggle={(tier) => setToggle(tier)}
            onMove={(i, step) =>
              setOrder(
                moveTier(
                  data.data.map((x) => x.id),
                  i,
                  step,
                ),
              )
            }
          />
        )}
        <p className="muted small">{t("vipOffNote")}</p>
      </div>
      {edit && data && (
        <TierForm
          tier={edit === "new" ? null : edit}
          list={data}
          onClose={() => setEdit(null)}
          onDone={done}
        />
      )}
      {toggle && (
        <FormDialog
          title={`${toggle.enabled ? t("disable") : t("enable")} · ${toggle.code}`}
          intro={
            toggle.enabled ? (
              <p className="muted small">{t("vipOffNote")}</p>
            ) : undefined
          }
          fields={[reasonField(t)]}
          confirmLabel={toggle.enabled ? t("disable") : t("enable")}
          danger={toggle.enabled}
          submit={(v) =>
            api.post(
              `/admin/vip/tiers/${toggle.id}/${toggle.enabled ? "disable" : "enable"}`,
              { reason: v.reason },
            )
          }
          onClose={() => setToggle(null)}
          onDone={done}
        />
      )}
      {order && (
        <FormDialog
          title={t("vipReorderTitle")}
          intro={<p className="muted small">{t("vipReorderIntro")}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t("save")}
          submit={(v) =>
            api.put("/admin/vip/tier-order", {
              tierIds: order,
              reason: v.reason,
            })
          }
          onClose={() => setOrder(null)}
          onDone={done}
        />
      )}
    </>
  );
}
