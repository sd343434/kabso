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
import type { Key } from "../i18n";
import { formatNumber } from "../format";
import { Icon } from "../ui/icons";
import { ENTRY_CAR, EntryDisplaySelect, type EntryDisplay } from "./Store";
import "./vip.css";
import { VipGoldenIds } from "./VipGoldenIds";

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
  /** v1.83-social (D258): the perk's number for this tier (bullets a day, level speed-up %). */
  amount: number | null;
  /** v1.129-social (D374): the perk's value (its catalogue schema), or null. */
  value?: PerkValue | null;
  /** v1.129-social (D374): the perk's MP4 art, or null. */
  video?: string | null;
  category?: string | null;
  /** v1.129-social (D374): the code is in the catalogue (false: saved before; dropped on the next save). */
  catalogued?: boolean;
  /** v1.129-social (D374): a perk the owner removed (DAILY_COINS). */
  retired?: boolean;
  /** v1.128-social (D373): the ENTRY_EFFECT perk's display; null for other perks (absent from an older server). */
  entryDisplay?: EntryDisplay | null;
}

/** v1.129-social (D374): a stored perk value. */
export type PerkValue =
  | number
  | string
  | string[]
  | Record<string, number | string>;

/** v1.129-social (D374): `VipPerkValueSchema`. */
export interface PerkValueSchema {
  kind: "none" | "int" | "enum" | "color" | "list" | "art_list" | "composite";
  min?: number;
  max?: number;
  unit?: string;
  source?: string;
  options?: string[];
  item?: string;
  maxItems?: number;
  kinds?: string[];
  fields?: {
    key: string;
    labelAr: string;
    labelEn: string;
    schema: PerkValueSchema;
  }[];
}

/** v1.129-social (D374, §10.166.1): `VipPerkCatalogueEntry`. */
export interface CatalogueEntry {
  code: string;
  category: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string;
  descriptionEn: string;
  built: boolean;
  value: PerkValueSchema;
  art: { kinds: string[]; width: number | null; height: number | null } | null;
  legacyAmount: boolean;
}

/** `AdminVipTier` (v1.82-social, D252). `sortOrder` is the order and the rank. */
export interface AdminVipTier {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  sortOrder: number;
  color: string;
  /** D258: the special text colour of the tier's members, or null. */
  nameColor?: string | null;
  /** D258: percent off a renewal (0 = none). */
  renewalDiscountPercent?: number;
  badgeAnimation: string | null;
  badgeStill: string | null;
  priceCoins: number;
  /** v1.126-social (D370): the price in recharge points; null = not redeemable with points. */
  pointsPrice?: number | null;
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
  /** v1.129-social (D374): the perk catalogue, in order (the checkbox grid). */
  catalogue: CatalogueEntry[];
  /** v1.129-social (D374): the most perks a tier holds (64). */
  maxPerks: number;
}

/** v1.129-social (D374): a value as the form holds it — text, a list of texts, or the composite's texts. */
export type ValueDraft = string | string[] | Record<string, string>;

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
  /** D374: the MP4 art. */
  video: string;
  artWidth: string;
  artHeight: string;
  /** D374: the value (D258's amount for DAILY_BULLET / LEVEL_SPEEDUP too). */
  value: ValueDraft;
  /** D374: saved before but outside the catalogue (retired or unknown): shown, never sent (removed on save). */
  stale?: "retired" | "unknown";
  /** v1.128-social (D373): the ENTRY_EFFECT perk's display (sent for that code only); absent: FULL_SCREEN. */
  entryDisplay?: EntryDisplay;
}

/** The tier form. */
export interface TierDraft {
  code: string;
  nameAr: string;
  nameEn: string;
  color: string;
  /** D258: "" = none. */
  nameColor: string;
  /** D258: 0 – 90. */
  renewalDiscountPercent: string;
  badgeAnimation: string;
  badgeStill: string;
  priceCoins: string;
  /** D370: "" = not redeemable with points. */
  pointsPrice: string;
  durationDays: string;
  enabled: boolean;
  perks: PerkDraft[];
}

const CODE = /^[A-Z][A-Z0-9_]{0,39}$/;
const COLOR = /^#[0-9A-Fa-f]{6}$/;
/** A hosted https URL (the server checks it again). Art is uploaded; nothing is bundled. */
const ART = /^https:\/\/\S{1,2040}$/;
const GIFT_CODE = /^[a-z0-9][a-z0-9_]{0,39}$/;

function artOk(v: string): boolean {
  return v.trim() === "" || ART.test(v.trim());
}

function sizeOk(v: string): boolean {
  if (v.trim() === "") return true;
  const n = Number(v);
  return Number.isInteger(n) && n >= 1 && n <= 8192;
}

/** D374: a stored value → the form's draft. */
export function valueDraftOf(v: PerkValue | null | undefined): ValueDraft {
  if (v === null || v === undefined) return "";
  if (Array.isArray(v)) return [...v];
  if (typeof v === "object")
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, String(x)]));
  return String(v);
}

const asText = (d: ValueDraft): string => (typeof d === "string" ? d : "");
const asList = (d: ValueDraft): string[] =>
  Array.isArray(d) ? d : typeof d === "string" && d.trim() !== "" ? d.split(",") : [];
const asFields = (d: ValueDraft): Record<string, string> =>
  typeof d === "object" && !Array.isArray(d) ? d : {};

function scalarBody(schema: PerkValueSchema, s: string): number | string | null {
  const v = s.trim();
  if (v === "") return null;
  if (schema.kind === "int") return Number(v);
  if (schema.kind === "color") return v.toUpperCase();
  return v;
}

function scalarOk(schema: PerkValueSchema, s: string): boolean {
  const v = s.trim();
  if (v === "") return true;
  switch (schema.kind) {
    case "int": {
      const n = Number(v);
      return (
        /^\d+$/.test(v) &&
        Number.isSafeInteger(n) &&
        n >= (schema.min ?? 1) &&
        n <= (schema.max ?? Number.MAX_SAFE_INTEGER)
      );
    }
    case "enum":
      return schema.source === "VIP_TIER"
        ? CODE.test(v)
        : (schema.options ?? []).includes(v);
    case "color":
      return COLOR.test(v);
    default:
      return false;
  }
}

/** D374: the form's value → the request's `value` (null = not set). */
export function valueBody(
  schema: PerkValueSchema,
  d: ValueDraft,
): PerkValue | null {
  switch (schema.kind) {
    case "none":
      return null;
    case "int":
    case "enum":
    case "color":
      return scalarBody(schema, asText(d));
    case "list":
    case "art_list": {
      const list = asList(d)
        .map((x) => x.trim())
        .filter((x) => x !== "");
      return list.length === 0 ? null : list;
    }
    case "composite": {
      const f = asFields(d);
      const fields = schema.fields ?? [];
      if (fields.every((x) => (f[x.key] ?? "").trim() === "")) return null;
      return Object.fromEntries(
        fields.map((x) => [x.key, scalarBody(x.schema, f[x.key] ?? "") ?? ""]),
      );
    }
  }
}

/** D374: the same value rules as the server (it checks them again; gift / tier existence is the server's). */
export function valueOk(schema: PerkValueSchema, d: ValueDraft): boolean {
  switch (schema.kind) {
    case "none":
      return true;
    case "int":
    case "enum":
    case "color":
      return scalarOk(schema, asText(d));
    case "list":
    case "art_list": {
      const list = asList(d)
        .map((x) => x.trim())
        .filter((x) => x !== "");
      const re = schema.kind === "list" ? GIFT_CODE : ART;
      return (
        list.length <= (schema.maxItems ?? 50) &&
        new Set(list).size === list.length &&
        list.every((x) => re.test(x))
      );
    }
    case "composite": {
      const f = asFields(d);
      const fields = schema.fields ?? [];
      const filled = fields.filter((x) => (f[x.key] ?? "").trim() !== "");
      // All or nothing: every field once one is set.
      return (
        (filled.length === 0 || filled.length === fields.length) &&
        fields.every((x) => scalarOk(x.schema, f[x.key] ?? ""))
      );
    }
  }
}

/** D374: a new perk row of [e] (ticked in the grid): the catalogue's titles, no value, no art. */
export function perkOf(e: CatalogueEntry): PerkDraft {
  return {
    code: e.code,
    titleAr: e.titleAr,
    titleEn: e.titleEn,
    descriptionAr: "",
    descriptionEn: "",
    enabled: true,
    animation: "",
    still: "",
    video: "",
    artWidth: "",
    artHeight: "",
    value: e.value.kind === "composite" ? {} : e.value.kind.endsWith("list") ? [] : "",
  };
}

export function draftOf(
  tier: AdminVipTier | null,
  catalogue: readonly CatalogueEntry[] = [],
): TierDraft {
  const known = new Set(catalogue.map((e) => e.code));
  return {
    code: tier?.code ?? "",
    nameAr: tier?.nameAr ?? "",
    nameEn: tier?.nameEn ?? "",
    color: tier?.color ?? "#C9A227",
    nameColor: tier?.nameColor ?? "",
    renewalDiscountPercent: String(tier?.renewalDiscountPercent ?? 15),
    badgeAnimation: tier?.badgeAnimation ?? "",
    badgeStill: tier?.badgeStill ?? "",
    priceCoins: tier ? String(tier.priceCoins) : "",
    pointsPrice:
      tier?.pointsPrice === null || tier?.pointsPrice === undefined
        ? ""
        : String(tier.pointsPrice),
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
      video: p.video ?? "",
      artWidth: p.artWidth === null ? "" : String(p.artWidth),
      artHeight: p.artHeight === null ? "" : String(p.artHeight),
      // D258's amount is the value of DAILY_BULLET / LEVEL_SPEEDUP (an older server sends only `amount`).
      value: valueDraftOf(p.value ?? p.amount),
      ...(p.retired
        ? { stale: "retired" as const }
        : catalogue.length > 0 && !known.has(p.code)
          ? { stale: "unknown" as const }
          : {}),
      ...(p.code === ENTRY_CAR ? { entryDisplay: p.entryDisplay ?? "FULL_SCREEN" } : {}),
    })),
  };
}

/** D370: empty (not redeemable) or a whole number of points, 1 … 10^12. */
function pointsOk(v: string): boolean {
  const s = v.trim();
  if (s === "") return true;
  const n = Number(s);
  return /^\d+$/.test(s) && Number.isSafeInteger(n) && n >= 1 && n <= 1_000_000_000_000;
}

/** The same rules as the server (it checks them again): code, names, colour, price, length, catalogue perks. */
export function draftValid(
  d: TierDraft,
  creating: boolean,
  catalogue: readonly CatalogueEntry[] = [],
  maxPerks = 64,
): boolean {
  const price = Number(d.priceCoins);
  const days = Number(d.durationDays);
  const live = d.perks.filter((p) => p.stale === undefined);
  const codes = live.map((p) => p.code.trim());
  const byCode = new Map(catalogue.map((e) => [e.code, e]));
  return (
    (!creating || CODE.test(d.code.trim())) &&
    d.nameAr.trim() !== "" &&
    d.nameEn.trim() !== "" &&
    COLOR.test(d.color.trim()) &&
    (d.nameColor.trim() === "" || COLOR.test(d.nameColor.trim())) &&
    /^\d{1,2}$/.test(d.renewalDiscountPercent.trim()) &&
    Number(d.renewalDiscountPercent) <= 90 &&
    artOk(d.badgeAnimation) &&
    artOk(d.badgeStill) &&
    Number.isInteger(price) &&
    price >= 1 &&
    price <= 1_000_000_000_000 &&
    pointsOk(d.pointsPrice) &&
    Number.isInteger(days) &&
    days >= 1 &&
    days <= 365 &&
    live.length <= maxPerks &&
    live.every((p) => {
      const e = byCode.get(p.code.trim());
      return (
        e !== undefined &&
        p.titleAr.trim() !== "" &&
        p.titleEn.trim() !== "" &&
        artOk(p.animation) &&
        artOk(p.still) &&
        artOk(p.video) &&
        (p.video.trim() === "" || (e.art?.kinds ?? []).includes("MP4")) &&
        sizeOk(p.artWidth) &&
        sizeOk(p.artHeight) &&
        valueOk(e.value, p.value)
      );
    }) &&
    new Set(codes).size === codes.length
  );
}

/** The perks to send: the catalogue's only (a stale row is dropped — the server refuses it), each with its value. */
function perksBody(perks: PerkDraft[], catalogue: readonly CatalogueEntry[]) {
  const byCode = new Map(catalogue.map((e) => [e.code, e]));
  return perks
    .filter((p) => p.stale === undefined && byCode.has(p.code.trim()))
    .map((p) => ({
      code: p.code.trim(),
      titleAr: p.titleAr.trim(),
      titleEn: p.titleEn.trim(),
      descriptionAr: p.descriptionAr.trim() || null,
      descriptionEn: p.descriptionEn.trim() || null,
      enabled: p.enabled,
      animation: p.animation.trim() || null,
      still: p.still.trim() || null,
      video: p.video.trim() || null,
      artWidth: p.artWidth.trim() === "" ? null : Number(p.artWidth),
      artHeight: p.artHeight.trim() === "" ? null : Number(p.artHeight),
      value: valueBody(byCode.get(p.code.trim())!.value, p.value),
      // v1.128-social (D373): only the entry car perk has a display (the server refuses it elsewhere); none chosen
      // yet: not sent (the server keeps the stored one, FULL_SCREEN for a new perk).
      ...(p.code.trim() === ENTRY_CAR && p.entryDisplay ? { entryDisplay: p.entryDisplay } : {}),
    }));
}

/** The form → the request body: on create every field; on an edit only what changed (the perks as a whole list). */
export function tierBody(
  d: TierDraft,
  before: AdminVipTier | null,
  catalogue: readonly CatalogueEntry[] = [],
): Record<string, unknown> {
  const fields: Record<string, unknown> = {
    nameAr: d.nameAr.trim(),
    nameEn: d.nameEn.trim(),
    color: d.color.trim().toUpperCase(),
    nameColor: d.nameColor.trim() ? d.nameColor.trim().toUpperCase() : null,
    renewalDiscountPercent: Number(d.renewalDiscountPercent),
    badgeAnimation: d.badgeAnimation.trim() || null,
    badgeStill: d.badgeStill.trim() || null,
    priceCoins: Number(d.priceCoins),
    pointsPrice: d.pointsPrice.trim() === "" ? null : Number(d.pointsPrice),
    durationDays: Number(d.durationDays),
  };
  const perks = perksBody(d.perks, catalogue);
  if (before === null) {
    return { code: d.code.trim(), ...fields, enabled: d.enabled, perks };
  }
  const out: Record<string, unknown> = Object.fromEntries(
    Object.entries(fields).filter(
      ([k, v]) =>
        ((before as unknown as Record<string, unknown>)[k] ?? null) !== v,
    ),
  );
  const beforeDraft = draftOf(before, catalogue).perks;
  const beforePerks = perksBody(beforeDraft, catalogue);
  // D374: a stale row (retired / outside the catalogue) is removed by sending the list without it.
  const hadStale = beforeDraft.some((p) => p.stale !== undefined);
  const hasStale = d.perks.some((p) => p.stale !== undefined);
  if (
    JSON.stringify(beforePerks) !== JSON.stringify(perks) ||
    (hadStale && !hasStale)
  )
    out.perks = perks;
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
              <td className="num">
                🪙 {formatNumber(tier.priceCoins, lang)}
                <div className="muted small">
                  {tier.pointsPrice === null || tier.pointsPrice === undefined
                    ? t("vipPointsPriceNone")
                    : t("vipPointsPriceShort", {
                        n: formatNumber(tier.pointsPrice, lang),
                      })}
                </div>
              </td>
              <td>
                {t("vipDays", { n: formatNumber(tier.durationDays, lang) })}
              </td>
              <td>
                <span className="vip-perks">
                  {tier.perks.filter((p) => !p.retired).map((p) => (
                    <span
                      key={p.code}
                      className={`badge ${p.available ? "ok" : ""} ${p.enabled ? "" : "muted"}`}
                      title={
                        p.available ? t("vipPerkBuilt") : t("vipPerkNotBuilt")
                      }
                    >
                      {lang === "ar" ? p.titleAr : p.titleEn}
                      {p.code === ENTRY_CAR && (
                        <span data-vip-entry-display={tier.code}>
                          {" · "}
                          {t(`entryDisplay${p.entryDisplay ?? "FULL_SCREEN"}` as Key)}
                        </span>
                      )}
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

/** D374: the upload kind of an art kind (SVGA → animation, PNG / WebP → still, MP4 → video). */
type UploadKind = "animation" | "still" | "video";

/** D374: one value field (int / enum / color) of a perk. */
function ScalarInput({
  id,
  schema,
  value,
  onChange,
  label,
}: {
  id: string;
  schema: PerkValueSchema;
  value: string;
  onChange: (v: string) => void;
  label: string;
}) {
  const { t } = useApp();
  const bad = !scalarOk(schema, value);
  if (schema.kind === "enum") {
    return (
      <div className="field">
        <label htmlFor={id}>{label}</label>
        <select
          id={id}
          data-vip-value={id}
          value={value}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">{t("vipPickNone")}</option>
          {(schema.options ?? []).map((o) => (
            <option key={o} value={o}>
              {schema.source === "ROCKET_STAGE"
                ? t("vipRocketStage", { n: o.replace("STAGE_", "") })
                : schema.source === "GOLDEN_ID_CLASS"
                  ? t(`vipGoldenClass_${o}` as Key)
                  : o}
            </option>
          ))}
        </select>
      </div>
    );
  }
  if (schema.kind === "color") {
    return (
      <div className="field">
        <label htmlFor={id}>{label}</label>
        <span className="vip-color">
          <input
            type="color"
            aria-label={label}
            value={COLOR.test(value) ? value : "#FFC928"}
            onChange={(e) => onChange(e.target.value.toUpperCase())}
          />
          <input
            id={id}
            data-vip-value={id}
            className="ltr mono"
            maxLength={7}
            aria-invalid={bad}
            value={value}
            onChange={(e) => onChange(e.target.value)}
          />
        </span>
      </div>
    );
  }
  return (
    <div className="field">
      <label htmlFor={id}>
        {label} ({t(`vipUnit_${schema.unit ?? "count"}` as Key)})
      </label>
      <input
        id={id}
        data-vip-value={id}
        type="number"
        min={schema.min}
        max={schema.max}
        className="num"
        aria-invalid={bad}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
      <span className="hint">
        {t("vipPerkValueRange", { min: schema.min ?? 1, max: schema.max ?? "" })}
      </span>
    </div>
  );
}

/**
 * The perks of the form (pure: rendered in the tests). D374 (§10.166.3): a checkbox grid of the perk catalogue, by
 * category, «مبنية / قريباً» on each; a ticked perk shows its value and art fields (uploads via `uploadAdminVipArt`).
 * Perks are kept in the catalogue's order. A row saved before that is outside the catalogue is listed and dropped.
 */
export function PerksEditor({
  perks,
  catalogue,
  maxPerks = 64,
  onChange,
  tierCode = "",
}: {
  perks: PerkDraft[];
  catalogue: readonly CatalogueEntry[];
  maxPerks?: number;
  onChange: (p: PerkDraft[]) => void;
  /** D258: the tier's code (the uploads' folder); empty while it is not set. */
  tierCode?: string;
}) {
  const { t, lang } = useApp();
  const order = new Map(catalogue.map((e, i) => [e.code, i]));
  const live = perks.filter((p) => p.stale === undefined);
  const stale = perks.filter((p) => p.stale !== undefined);
  const byCode = new Map(perks.map((p) => [p.code, p]));
  const sorted = (list: PerkDraft[]) =>
    [...list].sort(
      (a, b) =>
        (order.get(a.code) ?? catalogue.length) -
        (order.get(b.code) ?? catalogue.length),
    );
  const setPerk = (code: string, patch: Partial<PerkDraft>) =>
    onChange(perks.map((p) => (p.code === code ? { ...p, ...patch } : p)));
  const toggle = (e: CatalogueEntry, on: boolean) =>
    onChange(
      on
        ? sorted([...perks, perkOf(e)])
        : perks.filter((p) => p.code !== e.code),
    );
  // D258: one upload at a time («code:kind»), and the last failure.
  const [uploading, setUploading] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const upload = async (
    code: string,
    kind: UploadKind,
    files: FileList | null | undefined,
    pack = false,
  ) => {
    const list = files ? Array.from(files) : [];
    if (list.length === 0 || !CODE.test(tierCode)) return;
    setUploading(`${code}:${pack ? "pack" : kind}`);
    setUploadError(null);
    try {
      const urls: string[] = [];
      let last: { width: number | null; height: number | null } | null = null;
      for (const file of pack ? list : list.slice(0, 1)) {
        const fileKind: UploadKind = pack
          ? file.name.toLowerCase().endsWith(".svga")
            ? "animation"
            : "still"
          : kind;
        const up = await uploadVipArt(fileKind, tierCode, file);
        urls.push(up.url);
        last = up;
      }
      const p = byCode.get(code);
      if (!p) return;
      if (pack) {
        setPerk(code, { value: [...asList(p.value).filter((x) => x.trim() !== ""), ...urls] });
      } else if (kind === "animation") {
        setPerk(code, { animation: urls[0]! });
      } else if (kind === "video") {
        setPerk(code, { video: urls[0]! });
      } else {
        setPerk(code, {
          still: urls[0]!,
          artWidth: last?.width === null || !last ? "" : String(last.width),
          artHeight: last?.height === null || !last ? "" : String(last.height),
        });
      }
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : t("vipUploadFailed"));
    } finally {
      setUploading(null);
    }
  };
  const uploadButton = (
    code: string,
    kind: UploadKind,
    label: string,
    accept: string,
  ) => (
    <label className="btn small">
      {uploading === `${code}:${kind}` ? t("vipUploading") : label}
      <input
        type="file"
        hidden
        accept={accept}
        data-vip-upload={`${code}:${kind}`}
        disabled={uploading !== null || !CODE.test(tierCode)}
        onChange={(ev) => void upload(code, kind, ev.target.files)}
      />
    </label>
  );
  const categories = [...new Set(catalogue.map((e) => e.category))];
  return (
    <div className="span-2 vip-perk-editor" data-vip-perks>
      <div className="row">
        <strong>{t("vipPerksPick")}</strong>
        <span className="muted small" data-vip-perk-count>
          {t("vipPerksCount", { n: live.length, max: maxPerks })}
        </span>
      </div>
      <p className="muted small" data-vip-inherit-hint>
        {t("vipPerksInherit")}
      </p>
      {stale.length > 0 && (
        <div className="alert" data-vip-stale>
          {t("vipPerkStale")}{" "}
          {stale.map((p) => (
            <span key={p.code} className="badge muted">
              <span className="mono ltr">{p.code}</span>
              {p.stale === "retired" && ` · ${t("vipPerkRetired")}`}{" "}
              <button
                type="button"
                className="btn small danger"
                data-vip-stale-remove={p.code}
                onClick={() => onChange(perks.filter((x) => x !== p))}
              >
                {t("remove")}
              </button>
            </span>
          ))}
        </div>
      )}
      {categories.map((cat) => (
        <fieldset className="vip-perk-cat" key={cat} data-vip-cat={cat}>
          <legend>{t(`vipCat${cat}` as Key)}</legend>
          <div className="vip-perk-grid">
            {catalogue
              .filter((e) => e.category === cat)
              .map((e) => {
                const p = byCode.get(e.code);
                const on = p !== undefined && p.stale === undefined;
                const title = lang === "ar" ? e.titleAr : e.titleEn;
                const ok = !on || valueOk(e.value, p.value);
                // Owner: a perk with no art and no value is just a tick, no box opens for it
                // (one that was switched off keeps its box, so it can be switched back on).
                const simple =
                  e.art === null &&
                  e.value.kind === "none" &&
                  e.code !== "BADGE" &&
                  p?.enabled !== false;
                return (
                  <div
                    className={`vip-perk ${on ? "on" : ""}`}
                    key={e.code}
                    data-vip-perk={e.code}
                  >
                    <label className="check">
                      <input
                        type="checkbox"
                        checked={on}
                        disabled={!on && live.length >= maxPerks}
                        data-vip-perk-pick={e.code}
                        onChange={(ev) => toggle(e, ev.target.checked)}
                      />
                      <span className="vip-perk-title">{title}</span>
                      <span
                        className={`badge ${e.built ? "ok" : ""}`}
                        data-vip-built={e.built ? "built" : "soon"}
                        title={e.built ? t("vipPerkBuilt") : t("vipPerkNotBuilt")}
                      >
                        {e.built ? t("vipPerkBuiltShort") : t("vipPerkSoon")}
                      </span>
                    </label>
                    <span className="muted small">
                      {lang === "ar" ? e.descriptionAr : e.descriptionEn}
                    </span>
                    {on && !simple && (
                      <div className="vip-perk-fields" data-vip-perk-fields={e.code}>
                        {e.code === "BADGE" && (
                          // D268: the BADGE perk's art is the badge right after the name.
                          <div className="field" data-vip-name-badge>
                            <strong>{t("vipNameBadgeTitle")}</strong>
                            <p className="muted small">{t("vipNameBadgeHint")}</p>
                          </div>
                        )}
                        <label className="check">
                          <input
                            type="checkbox"
                            checked={p.enabled}
                            onChange={(ev) =>
                              setPerk(e.code, { enabled: ev.target.checked })
                            }
                          />
                          {t("vipPerkShown")}
                        </label>
                        {(e.value.kind === "int" ||
                          e.value.kind === "enum" ||
                          e.value.kind === "color") && (
                          <ScalarInput
                            id={`vp-${e.code}`}
                            schema={e.value}
                            label={t("vipPerkValue")}
                            value={asText(p.value)}
                            onChange={(v) => setPerk(e.code, { value: v })}
                          />
                        )}
                        {e.value.kind === "composite" &&
                          (e.value.fields ?? []).map((f) => (
                            <ScalarInput
                              key={f.key}
                              id={`vp-${e.code}-${f.key}`}
                              schema={f.schema}
                              label={lang === "ar" ? f.labelAr : f.labelEn}
                              value={asFields(p.value)[f.key] ?? ""}
                              onChange={(v) =>
                                setPerk(e.code, {
                                  value: { ...asFields(p.value), [f.key]: v },
                                })
                              }
                            />
                          ))}
                        {e.value.kind === "list" && (
                          <div className="field">
                            <label htmlFor={`vp-${e.code}`}>
                              {t("vipPerkGiftCodes")}
                            </label>
                            <input
                              id={`vp-${e.code}`}
                              data-vip-value={`vp-${e.code}`}
                              className="ltr mono"
                              value={asList(p.value).join(",")}
                              onChange={(ev) =>
                                setPerk(e.code, {
                                  value: ev.target.value.split(","),
                                })
                              }
                            />
                          </div>
                        )}
                        {e.value.kind === "art_list" && (
                          <div className="field" data-vip-art-pack={e.code}>
                            <span>{t("vipPerkArtPack")}</span>
                            {asList(p.value).map((url, j) => (
                              <span className="row" key={`${url}-${j}`}>
                                <span className="mono ltr small">{url}</span>
                                <button
                                  type="button"
                                  className="btn small danger"
                                  onClick={() =>
                                    setPerk(e.code, {
                                      value: asList(p.value).filter(
                                        (_, k) => k !== j,
                                      ),
                                    })
                                  }
                                >
                                  {t("remove")}
                                </button>
                              </span>
                            ))}
                            <label className="btn small">
                              {uploading === `${e.code}:pack`
                                ? t("vipUploading")
                                : t("vipPerkArtPackAdd")}
                              <input
                                type="file"
                                hidden
                                multiple
                                accept=".svga,image/png,image/webp"
                                data-vip-upload={`${e.code}:pack`}
                                disabled={uploading !== null || !CODE.test(tierCode)}
                                onChange={(ev) =>
                                  void upload(e.code, "still", ev.target.files, true)
                                }
                              />
                            </label>
                          </div>
                        )}
                        {e.code === ENTRY_CAR && (
                          <EntryDisplaySelect
                            id={`vp-entry-display-${e.code}`}
                            value={p.entryDisplay ?? "FULL_SCREEN"}
                            onChange={(entryDisplay) => setPerk(e.code, { entryDisplay })}
                          />
                        )}
                        {!ok && (
                          <span className="error small">{t("vipPerkValueBad")}</span>
                        )}
                        {e.art && (
                          <div className="field" data-vip-art={e.code}>
                            <span className="muted small">
                              {t("vipPerkArtKinds", { kinds: e.art.kinds.join(" · ") })}
                              {e.art.width !== null &&
                                e.art.height !== null &&
                                ` — ${t("vipPerkArtCanvas", { w: e.art.width, h: e.art.height })}`}
                            </span>
                            <div className="form-grid">
                              {(e.art.kinds.includes("PNG") ||
                                e.art.kinds.includes("WEBP")) && (
                                <div className="field">
                                  <label htmlFor={`vp-still-${e.code}`}>
                                    {t("vipPerkStill")}
                                  </label>
                                  <input
                                    id={`vp-still-${e.code}`}
                                    className="ltr"
                                    maxLength={2048}
                                    value={p.still}
                                    onChange={(ev) =>
                                      setPerk(e.code, { still: ev.target.value })
                                    }
                                  />
                                  {uploadButton(
                                    e.code,
                                    "still",
                                    e.code === "BADGE"
                                      ? t("vipNameBadgeUpload")
                                      : t("vipUploadStill"),
                                    "image/png,image/webp",
                                  )}
                                </div>
                              )}
                              {e.art.kinds.includes("SVGA") && (
                                <div className="field">
                                  <label htmlFor={`vp-anim-${e.code}`}>
                                    {t("vipPerkAnimation")}
                                  </label>
                                  <input
                                    id={`vp-anim-${e.code}`}
                                    className="ltr"
                                    maxLength={2048}
                                    value={p.animation}
                                    onChange={(ev) =>
                                      setPerk(e.code, { animation: ev.target.value })
                                    }
                                  />
                                  {uploadButton(
                                    e.code,
                                    "animation",
                                    t("vipUploadAnimation"),
                                    ".svga",
                                  )}
                                </div>
                              )}
                              {e.art.kinds.includes("MP4") && (
                                <div className="field">
                                  <label htmlFor={`vp-video-${e.code}`}>
                                    {t("vipPerkVideo")}
                                  </label>
                                  <input
                                    id={`vp-video-${e.code}`}
                                    className="ltr"
                                    maxLength={2048}
                                    value={p.video}
                                    onChange={(ev) =>
                                      setPerk(e.code, { video: ev.target.value })
                                    }
                                  />
                                  {uploadButton(
                                    e.code,
                                    "video",
                                    t("vipUploadVideo"),
                                    "video/mp4",
                                  )}
                                </div>
                              )}
                            </div>
                          </div>
                        )}
                        <details>
                          <summary className="small">{t("vipPerkTexts")}</summary>
                          <div className="form-grid">
                            <div className="field">
                              <label htmlFor={`vp-tar-${e.code}`}>
                                {t("vipPerkTitleAr")}
                              </label>
                              <input
                                id={`vp-tar-${e.code}`}
                                dir="rtl"
                                maxLength={40}
                                value={p.titleAr}
                                onChange={(ev) =>
                                  setPerk(e.code, { titleAr: ev.target.value })
                                }
                              />
                            </div>
                            <div className="field">
                              <label htmlFor={`vp-ten-${e.code}`}>
                                {t("vipPerkTitleEn")}
                              </label>
                              <input
                                id={`vp-ten-${e.code}`}
                                dir="ltr"
                                maxLength={40}
                                value={p.titleEn}
                                onChange={(ev) =>
                                  setPerk(e.code, { titleEn: ev.target.value })
                                }
                              />
                            </div>
                            <div className="field">
                              <label htmlFor={`vp-dar-${e.code}`}>
                                {t("vipPerkDescAr")}
                              </label>
                              <input
                                id={`vp-dar-${e.code}`}
                                dir="rtl"
                                maxLength={200}
                                value={p.descriptionAr}
                                onChange={(ev) =>
                                  setPerk(e.code, { descriptionAr: ev.target.value })
                                }
                              />
                            </div>
                            <div className="field">
                              <label htmlFor={`vp-den-${e.code}`}>
                                {t("vipPerkDescEn")}
                              </label>
                              <input
                                id={`vp-den-${e.code}`}
                                dir="ltr"
                                maxLength={200}
                                value={p.descriptionEn}
                                onChange={(ev) =>
                                  setPerk(e.code, { descriptionEn: ev.target.value })
                                }
                              />
                            </div>
                          </div>
                        </details>
                      </div>
                    )}
                  </div>
                );
              })}
          </div>
        </fieldset>
      ))}
      {uploadError && <div className="alert error">{uploadError}</div>}
      <p className="muted small">{t("vipArtHint")}</p>
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
  const [draft, setDraft] = useState<TierDraft>(() =>
    draftOf(tier, list.catalogue),
  );
  const [reason, setReason] = useState("");
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const body = tierBody(draft, tier, list.catalogue);
  const valid = draftValid(draft, tier === null, list.catalogue, list.maxPerks);
  const ok =
    reason.trim() !== "" &&
    valid &&
    (tier === null || Object.keys(body).length > 0);
  const set = (k: keyof TierDraft) => (e: { target: { value: string } }) =>
    setDraft((d) => ({
      ...d,
      [k]: k === "code" ? e.target.value.toUpperCase() : e.target.value,
    }));
  // D263: the badge's own upload (it took a pasted link only).
  const [badgeUploading, setBadgeUploading] = useState<string | null>(null);
  const [badgeUploadError, setBadgeUploadError] = useState<string | null>(null);
  const tierCode = draft.code.trim();
  const uploadBadge = async (
    kind: "animation" | "still",
    file: File | undefined,
  ) => {
    if (!file || !CODE.test(tierCode)) return;
    setBadgeUploading(kind);
    setBadgeUploadError(null);
    try {
      const up = await uploadVipArt(kind, tierCode, file);
      setDraft((d) => ({
        ...d,
        [kind === "animation" ? "badgeAnimation" : "badgeStill"]: up.url,
      }));
    } catch (e) {
      setBadgeUploadError(
        e instanceof Error ? e.message : t("vipUploadFailed"),
      );
    } finally {
      setBadgeUploading(null);
    }
  };
  const badgeUpload = (kind: "animation" | "still") => (
    <label className="btn small">
      {badgeUploading === kind
        ? t("vipUploading")
        : t(kind === "animation" ? "vipUploadAnimation" : "vipUploadStill")}
      <input
        type="file"
        hidden
        accept={kind === "animation" ? ".svga" : "image/png,image/webp"}
        data-vip-badge-upload={kind}
        disabled={badgeUploading !== null || !CODE.test(tierCode)}
        onChange={(e) => void uploadBadge(kind, e.target.files?.[0])}
      />
    </label>
  );
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
          <label htmlFor="vip-name-color">{t("vipNameColor")}</label>
          <span className="vip-color">
            <input
              type="color"
              aria-label={t("vipNameColor")}
              value={COLOR.test(draft.nameColor) ? draft.nameColor : "#FFC928"}
              onChange={(e) =>
                setDraft((d) => ({
                  ...d,
                  nameColor: e.target.value.toUpperCase(),
                }))
              }
            />
            <input
              id="vip-name-color"
              data-vip-name-color
              className="ltr mono"
              maxLength={7}
              placeholder="#FFC928"
              value={draft.nameColor}
              onChange={set("nameColor")}
            />
          </span>
          <small>{t("vipNameColorHint")}</small>
        </div>
        <div className="field">
          <label htmlFor="vip-renewal">{t("vipRenewalDiscount")}</label>
          <input
            id="vip-renewal"
            data-vip-renewal
            className="ltr"
            inputMode="numeric"
            maxLength={2}
            value={draft.renewalDiscountPercent}
            onChange={set("renewalDiscountPercent")}
          />
          <small>{t("vipRenewalDiscountHint")}</small>
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
          <label htmlFor="vip-points-price">{t("vipPointsPrice")}</label>
          <input
            id="vip-points-price"
            type="number"
            min={1}
            className="ltr mono"
            value={draft.pointsPrice}
            onChange={set("pointsPrice")}
          />
          <span className="hint">{t("vipPointsPriceHint")}</span>
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
          {badgeUpload("still")}
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
          {badgeUpload("animation")}
        </div>
        {badgeUploadError && (
          <div className="span-2 alert error">{badgeUploadError}</div>
        )}
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
          catalogue={list.catalogue}
          maxPerks={list.maxPerks}
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
      {/* D378 (§10.168.4): the golden ID stock «آيدي ذهبي». */}
      <VipGoldenIds />
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
