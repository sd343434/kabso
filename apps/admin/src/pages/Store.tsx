import { useRef, useState } from "react";
import { api, uploadStoreArt } from "../api";
import {
  Dialog,
  ErrorAlert,
  FormDialog,
  reasonField,
  useAsync,
} from "../components";
import { useApp } from "../context";
import { formatDate, formatNumber } from "../format";
import type { Key } from "../i18n";
import {
  applyDetection,
  badgeProblems,
  badgesPart,
  badgeState,
  seasonalWithoutEnd,
  type AdminItemBadge,
  type BadgeState,
  type ItemBadgeCode,
} from "../badges";
import { Icon } from "../ui/icons";
import { BadgeChip, BadgePicker, SeasonalNoEndHint, SeasonalNoEndNote } from "./BadgePicker";
import { SvgaPreview, VideoPreview } from "./GiftFiles";
import "./store.css";

/** D270 (§10.98): what a store item is (the bag category it lands in), in the app's tab order. */
export const STORE_KINDS = [
  "AVATAR_FRAME",
  "PROFILE_CARD",
  "CHAT_BUBBLE",
  "ENTRY_BANNER",
  "ENTRY_EFFECT",
] as const;
export type StoreKind = (typeof STORE_KINDS)[number];
export const STORE_DAYS = [7, 14, 30] as const;
export const STORE_CURRENCIES = ["COINS", "CHERRIES"] as const;
export type StoreCurrency = (typeof STORE_CURRENCIES)[number];
export type StoreAlpha = "NONE" | "SIDE_BY_SIDE";

/**
 * v1.128-social (D373, §10.165; owner: «اما بشاشة كاملة او نصف الشاشة»): how an entry car plays — the whole live
 * screen or a band about half the screen high. Set per store entry car and per VIP ENTRY_EFFECT perk.
 */
export const ENTRY_DISPLAYS = ["FULL_SCREEN", "HALF_SCREEN"] as const;
export type EntryDisplay = (typeof ENTRY_DISPLAYS)[number];
/** The store kind / VIP perk code whose art is an entry car (the only one with a display). */
export const ENTRY_CAR = "ENTRY_EFFECT";

/** «طريقة العرض: شاشة كاملة / نصف الشاشة» (pure: rendered in the tests; reused by the VIP perk form). */
export function EntryDisplaySelect({
  id,
  value,
  onChange,
}: {
  id: string;
  value: EntryDisplay;
  onChange: (v: EntryDisplay) => void;
}) {
  const { t } = useApp();
  return (
    <div className="field" data-entry-display-field>
      <label htmlFor={id}>{t("entryDisplay")}</label>
      <select id={id} data-entry-display={id} value={value} onChange={(e) => onChange(e.target.value as EntryDisplay)}>
        {ENTRY_DISPLAYS.map((d) => (
          <option key={d} value={d}>
            {t(`entryDisplay${d}` as Key)}
          </option>
        ))}
      </select>
      <span className="hint">{t("entryDisplayHint")}</span>
    </div>
  );
}

/** `AdminStorePrice`. */
export interface AdminStorePrice {
  currency: StoreCurrency;
  days: number;
  amount: number;
}

/** `AdminStoreItem` (D270). */
export interface AdminStoreItem {
  id: string;
  code: string;
  kind: StoreKind;
  nameAr: string;
  nameEn: string;
  still: string | null;
  animation: string | null;
  animationFormat: "SVGA" | "MP4" | null;
  animationAlpha: StoreAlpha | null;
  artWidth: number | null;
  artHeight: number | null;
  /** v1.128-social (D373): an entry car's display; null for every other kind (absent from an older server). */
  entryDisplay?: EntryDisplay | null;
  prices: AdminStorePrice[];
  sortOrder: number;
  /** Deprecated v1.79-live (D289): «جديد» is in `badges`. */
  isNew: boolean;
  /** v1.79-live (D289): every stored badge, its end and whether it still shows. */
  badges: AdminItemBadge[];
  enabled: boolean;
  /** v1.79-live (D289b): taken out of the store by «حذف» (someone bought or holds it), else null. */
  hiddenAt: string | null;
  owners: number;
  sold: number;
  createdAt: string;
  updatedAt: string;
}

/** `AdminStoreItemList`. */
export interface AdminStoreItemList {
  data: AdminStoreItem[];
  kinds: StoreKind[];
  days: number[];
  currencies: StoreCurrency[];
}

interface SaleUser {
  id: string;
  username: string;
  displayName: string;
}

/** `AdminStoreSales`. */
export interface AdminStoreSales {
  data: {
    id: string;
    createdAt: string;
    item: { id: string; code: string; kind: StoreKind; nameAr: string; nameEn: string };
    buyer: SaleUser;
    recipient: SaleUser | null;
    currency: StoreCurrency;
    days: number;
    price: number;
    extended: boolean;
  }[];
  totals: { purchases: number; gifts: number; coins: number; cherries: number };
}

/** The item form: one text box per currency × duration (empty: not sold). */
export interface ItemDraft {
  kind: StoreKind;
  nameAr: string;
  nameEn: string;
  still: string;
  animation: string;
  animationFormat: "SVGA" | "MP4" | "";
  animationAlpha: StoreAlpha;
  artWidth: string;
  artHeight: string;
  /** v1.128-social (D373): an entry car's display (sent for kind ENTRY_EFFECT only). */
  entryDisplay: EntryDisplay;
  /** `COINS:7` → "50000". */
  prices: Record<string, string>;
  sortOrder: string;
  /** v1.79-live (D289): the badge choice (replaces the «جديد» switch). */
  badges: BadgeState;
  enabled: boolean;
}

const ART = /^https:\/\/\S{1,2040}$/;
const MAX_PRICE = 1_000_000_000_000;
export const priceKey = (c: StoreCurrency, d: number) => `${c}:${d}`;

export function kindLabel(kind: StoreKind): Key {
  return `storeKind${kind}` as Key;
}

export function draftOf(item: AdminStoreItem | null, kind: StoreKind = "AVATAR_FRAME"): ItemDraft {
  const prices: Record<string, string> = {};
  for (const p of item?.prices ?? []) prices[priceKey(p.currency, p.days)] = String(p.amount);
  return {
    kind: item?.kind ?? kind,
    nameAr: item?.nameAr ?? "",
    nameEn: item?.nameEn ?? "",
    still: item?.still ?? "",
    animation: item?.animation ?? "",
    animationFormat: item?.animationFormat ?? "",
    animationAlpha: item?.animationAlpha ?? "NONE",
    artWidth: item && item.artWidth !== null ? String(item.artWidth) : "",
    artHeight: item && item.artHeight !== null ? String(item.artHeight) : "",
    entryDisplay: item?.entryDisplay ?? "FULL_SCREEN",
    prices,
    sortOrder: item ? String(item.sortOrder) : "",
    badges: badgeState(item?.badges ?? []),
    enabled: item?.enabled ?? false,
  };
}

function priceOk(v: string): boolean {
  if (v.trim() === "") return true;
  const n = Number(v);
  return /^\d+$/.test(v.trim()) && Number.isSafeInteger(n) && n >= 1 && n <= MAX_PRICE;
}

/** The same rules as the server (it checks them again). */
export function draftValid(d: ItemDraft, now: Date = new Date()): boolean {
  const art = (v: string) => v.trim() === "" || ART.test(v.trim());
  const size = (v: string) => v.trim() === "" || (/^\d+$/.test(v.trim()) && Number(v) >= 1 && Number(v) <= 8192);
  return (
    d.nameAr.trim() !== "" &&
    d.nameAr.trim().length <= 40 &&
    d.nameEn.trim() !== "" &&
    d.nameEn.trim().length <= 40 &&
    art(d.still) &&
    art(d.animation) &&
    size(d.artWidth) &&
    size(d.artHeight) &&
    (d.sortOrder.trim() === "" || /^\d{1,6}$/.test(d.sortOrder.trim())) &&
    Object.values(d.prices).every(priceOk) &&
    badgeProblems(d.badges, now).length === 0
  );
}

/** The price list of a draft (only the boxes filled), coins first then cherries, shorter first. */
export function pricesOf(d: ItemDraft): AdminStorePrice[] {
  const out: AdminStorePrice[] = [];
  for (const currency of STORE_CURRENCIES) {
    for (const days of STORE_DAYS) {
      const v = (d.prices[priceKey(currency, days)] ?? "").trim();
      if (v !== "") out.push({ currency, days, amount: Number(v) });
    }
  }
  return out;
}

/** The format of an animation URL the panel did not upload in this form (an `.mp4` link is an MP4). */
export function formatOf(d: ItemDraft): "SVGA" | "MP4" | null {
  const url = d.animation.trim();
  if (url === "") return null;
  if (d.animationFormat) return d.animationFormat;
  return /\.mp4(\?|$)/i.test(url) ? "MP4" : "SVGA";
}

/** The form → the request body: on create every field; on an edit only what changed (the prices as a whole list). */
export function itemBody(d: ItemDraft, before: AdminStoreItem | null): Record<string, unknown> {
  const format = formatOf(d);
  const fields: Record<string, unknown> = {
    nameAr: d.nameAr.trim(),
    nameEn: d.nameEn.trim(),
    still: d.still.trim() || null,
    animation: d.animation.trim() || null,
    animationFormat: format,
    animationAlpha: format === "MP4" ? d.animationAlpha : null,
    artWidth: d.artWidth.trim() === "" ? null : Number(d.artWidth),
    artHeight: d.artHeight.trim() === "" ? null : Number(d.artHeight),
    ...(d.sortOrder.trim() === "" ? {} : { sortOrder: Number(d.sortOrder) }),
  };
  const prices = pricesOf(d);
  if (before === null) {
    return {
      kind: d.kind,
      ...fields,
      ...(d.kind === ENTRY_CAR ? { entryDisplay: d.entryDisplay } : {}),
      prices,
      ...badgesPart(d.badges, null),
      enabled: d.enabled,
    };
  }
  const out: Record<string, unknown> = Object.fromEntries(
    Object.entries(fields).filter(
      ([k, v]) => ((before as unknown as Record<string, unknown>)[k] ?? null) !== v,
    ),
  );
  if (JSON.stringify(pricesOf(draftOf(before))) !== JSON.stringify(prices)) out.prices = prices;
  if (before.kind === ENTRY_CAR && d.entryDisplay !== (before.entryDisplay ?? "FULL_SCREEN")) {
    out.entryDisplay = d.entryDisplay;
  }
  Object.assign(out, badgesPart(d.badges, before));
  return out;
}

/**
 * v1.79-live (D289b, §10.102.5): what «حذف» will do — `delete` (nobody bought or holds it: gone for good) or `hide`
 * (out of the store; kept for the people who hold it). The server decides again on the same rule.
 */
export function storeDeleteCase(item: Pick<AdminStoreItem, "owners" | "sold">): "delete" | "hide" {
  return item.sold === 0 && item.owners === 0 ? "delete" : "hide";
}

/** The confirm dialog's sentence for [item]. */
export function StoreDeleteIntro({ item }: { item: AdminStoreItem }) {
  const { t, lang } = useApp();
  const which = storeDeleteCase(item);
  return (
    <p className={`alert ${which === "delete" ? "error" : "warn"}`} data-store-delete-case={which}>
      {which === "delete"
        ? t("storeDeleteForever")
        : item.owners > 0
          ? t("storeDeleteHide", { n: formatNumber(item.owners, lang) })
          : t("storeDeleteHideSold", { n: formatNumber(item.sold, lang) })}
    </p>
  );
}

/** «🪙 50,000 · 7 days». */
function priceText(p: AdminStorePrice, t: ReturnType<typeof useApp>["t"], lang: "ar" | "en"): string {
  const icon = p.currency === "COINS" ? "🪙" : "🍒";
  return `${icon} ${formatNumber(p.amount, lang)} · ${t("storeDays", { n: formatNumber(p.days, lang) })}`;
}

/** The items table (pure: rendered in the tests). */
export function StoreItemsTable({
  items,
  onEdit,
  onToggle,
  onDelete = () => undefined,
  onRestore = () => undefined,
}: {
  items: AdminStoreItem[];
  onEdit: (i: AdminStoreItem) => void;
  onToggle: (i: AdminStoreItem) => void;
  /** v1.79-live (D289b): «حذف» and «إرجاع للمتجر». */
  onDelete?: (i: AdminStoreItem) => void;
  onRestore?: (i: AdminStoreItem) => void;
}) {
  const { t, lang, can } = useApp();
  const manage = can("catalog.manage");
  return (
    <div className="table-wrap">
      <table data-store-items>
        <thead>
          <tr>
            <th>{t("storeArt")}</th>
            <th>{t("storeKind")}</th>
            <th>{t("storePrices")}</th>
            <th className="num">{t("storeSort")}</th>
            <th className="num">{t("storeOwners")}</th>
            <th className="num">{t("storeSold")}</th>
            <th>{t("state")}</th>
            {manage && <th />}
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id} className={item.enabled ? "" : "muted"} data-store-item={item.code}>
              <td>
                <span className="store-name">
                  {item.still ? (
                    <img className="store-thumb" src={item.still} alt="" />
                  ) : (
                    <span className="store-thumb" aria-hidden="true" />
                  )}
                  <span>
                    <strong>{lang === "ar" ? item.nameAr : item.nameEn}</strong>
                    {item.badges
                      .filter((b) => b.active)
                      .map((b) => (
                        <BadgeChip key={b.code} code={b.code} iconOnly />
                      ))}
                    {seasonalWithoutEnd(item.badges) && <SeasonalNoEndHint />}
                    <br />
                    <span className="mono small ltr muted">
                      {item.code}
                      {item.animationFormat ? ` · ${item.animationFormat}` : ""}
                    </span>
                  </span>
                </span>
              </td>
              <td>
                {t(kindLabel(item.kind))}
                {item.kind === ENTRY_CAR && (
                  <>
                    <br />
                    <span
                      className={`badge ${item.entryDisplay === "HALF_SCREEN" ? "warn" : ""}`}
                      data-store-entry-display={item.code}
                    >
                      {t(`entryDisplay${item.entryDisplay ?? "FULL_SCREEN"}` as Key)}
                    </span>
                  </>
                )}
              </td>
              <td>
                <span className="store-prices">
                  {item.prices.length === 0 ? (
                    <span className="badge">{t("storeNoPrice")}</span>
                  ) : (
                    item.prices.map((p) => (
                      <span key={priceKey(p.currency, p.days)} className="badge" data-store-price={priceKey(p.currency, p.days)}>
                        {priceText(p, t, lang)}
                      </span>
                    ))
                  )}
                </span>
              </td>
              <td className="num">{formatNumber(item.sortOrder, lang)}</td>
              <td className="num">{formatNumber(item.owners, lang)}</td>
              <td className="num">{formatNumber(item.sold, lang)}</td>
              <td>
                {item.hiddenAt ? (
                  <span className="badge warn" data-store-hidden={item.code}>
                    {t("storeHidden")}
                  </span>
                ) : (
                  <span className={`badge ${item.enabled ? "ok" : ""}`}>
                    {item.enabled ? t("enabled") : t("disabled")}
                  </span>
                )}
              </td>
              {manage && (
                <td>
                  <div className="row end">
                    <button className="btn small" onClick={() => onEdit(item)} data-store-edit={item.code}>
                      {t("edit")}
                    </button>
                    {item.hiddenAt ? (
                      <button className="btn small primary" onClick={() => onRestore(item)} data-store-restore={item.code}>
                        {t("storeRestore")}
                      </button>
                    ) : (
                      <>
                        <button
                          className={`btn small ${item.enabled ? "" : "primary"}`}
                          onClick={() => onToggle(item)}
                          data-store-toggle={item.code}
                        >
                          {item.enabled ? t("disable") : t("enable")}
                        </button>
                        <button className="btn small danger" onClick={() => onDelete(item)} data-store-delete={item.code}>
                          {t("storeDelete")}
                        </button>
                      </>
                    )}
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {items.length === 0 && <p className="muted state">{t("storeNone")}</p>}
    </div>
  );
}

/** The price grid of the form: rows = currencies, columns = 7 / 14 / 30 days (pure: rendered in the tests). */
export function PriceGrid({
  prices,
  onChange,
}: {
  prices: Record<string, string>;
  onChange: (p: Record<string, string>) => void;
}) {
  const { t, lang } = useApp();
  return (
    <div className="span-2 field" data-store-price-grid>
      <strong>{t("storePrices")}</strong>
      <div className="store-price-grid">
        <span />
        {STORE_DAYS.map((d) => (
          <span key={d} className="muted small">
            {t("storeDays", { n: formatNumber(d, lang) })}
          </span>
        ))}
        {STORE_CURRENCIES.map((c) => (
          <PriceRow key={c} currency={c} prices={prices} onChange={onChange} />
        ))}
      </div>
      <span className="hint">{t("storePricesHint")}</span>
    </div>
  );
}

function PriceRow({
  currency,
  prices,
  onChange,
}: {
  currency: StoreCurrency;
  prices: Record<string, string>;
  onChange: (p: Record<string, string>) => void;
}) {
  const { t } = useApp();
  return (
    <>
      <span>{currency === "COINS" ? `🪙 ${t("storeCoins")}` : `🍒 ${t("storeCherries")}`}</span>
      {STORE_DAYS.map((d) => {
        const k = priceKey(currency, d);
        const v = prices[k] ?? "";
        return (
          <input
            key={k}
            className={`ltr mono ${priceOk(v) ? "" : "invalid"}`}
            inputMode="numeric"
            aria-label={`${currency} ${d}`}
            data-store-price-input={k}
            value={v}
            onChange={(e) => onChange({ ...prices, [k]: e.target.value.replace(/[^0-9]/g, "") })}
          />
        );
      })}
    </>
  );
}

/** The sales table and its totals (pure: rendered in the tests). */
export function SalesTable({ sales }: { sales: AdminStoreSales }) {
  const { t, lang } = useApp();
  const { totals } = sales;
  return (
    <div className="table-wrap" data-store-sales>
      <p className="muted small">
        {t("storeSalesTotals", {
          n: formatNumber(totals.purchases, lang),
          gifts: formatNumber(totals.gifts, lang),
          coins: formatNumber(totals.coins, lang),
          cherries: formatNumber(totals.cherries, lang),
        })}
      </p>
      <table>
        <thead>
          <tr>
            <th>{t("storeSaleWhen")}</th>
            <th>{t("storeSaleItem")}</th>
            <th>{t("storeSaleBuyer")}</th>
            <th>{t("storeSaleRecipient")}</th>
            <th className="num">{t("storeSalePrice")}</th>
          </tr>
        </thead>
        <tbody>
          {sales.data.map((s) => (
            <tr key={s.id} data-store-sale={s.id}>
              <td>{formatDate(s.createdAt, lang)}</td>
              <td>{lang === "ar" ? s.item.nameAr : s.item.nameEn}</td>
              <td className="ltr">@{s.buyer.username}</td>
              <td className="ltr">{s.recipient ? `@${s.recipient.username}` : t("storeSaleSelf")}</td>
              <td className="num">
                {priceText({ currency: s.currency, days: s.days, amount: s.price }, t, lang)}
                {s.extended && <span className="badge">{t("storeSaleExtended")}</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {sales.data.length === 0 && <p className="muted state">{t("storeSalesNone")}</p>}
    </div>
  );
}

function ItemForm({
  item,
  kind,
  onClose,
  onDone,
  onDelete,
}: {
  item: AdminStoreItem | null;
  kind: StoreKind;
  onClose: () => void;
  onDone: () => void;
  /** v1.79-live (D289b): «حذف» from the form (an existing item, not hidden). */
  onDelete?: () => void;
}) {
  const { t } = useApp();
  const [draft, setDraft] = useState<ItemDraft>(() => draftOf(item, kind));
  const [reason, setReason] = useState("");
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [uploading, setUploading] = useState<"still" | "animation" | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const body = itemBody(draft, item);
  const valid = draftValid(draft);
  const ok = reason.trim() !== "" && valid && (item === null || Object.keys(body).length > 0);
  const set = (k: keyof ItemDraft) => (e: { target: { value: string } }) =>
    setDraft((d) => ({ ...d, [k]: e.target.value }));
  const upload = async (kind: "animation" | "still", file: File | undefined) => {
    if (!file) return;
    setUploading(kind);
    setUploadError(null);
    try {
      const up = await uploadStoreArt(kind, file);
      setDraft((d) =>
        kind === "still"
          ? {
              ...d,
              still: up.url,
              artWidth: up.width === null ? d.artWidth : String(up.width),
              artHeight: up.height === null ? d.artHeight : String(up.height),
            }
          : {
              ...d,
              animation: up.url,
              animationFormat: up.format ?? "",
              animationAlpha: up.detectedAlpha ?? "NONE",
              // D289: what the file shows is pre-selected (marked «تلقائي»).
              badges: applyDetection(d.badges, {
                hasEffect: true,
                hasAudio: !!up.hasAudio,
                ...(typeof up.fullscreen === "boolean" ? { fullscreen: up.fullscreen } : {}),
              }),
            },
      );
    } catch (e) {
      setUploadError(e instanceof Error ? e.message : t("storeUploadFailed"));
    } finally {
      setUploading(null);
    }
  };
  const uploadButton = (kind: "animation" | "still") => (
    <label className="btn small">
      {uploading === kind ? t("storeUploading") : t(kind === "animation" ? "storeUploadAnimation" : "storeUploadStill")}
      <input
        type="file"
        hidden
        accept={kind === "animation" ? ".svga,video/mp4,.mp4" : "image/png,image/webp"}
        data-store-upload={kind}
        disabled={uploading !== null}
        onChange={(e) => void upload(kind, e.target.files?.[0])}
      />
    </label>
  );
  const format = formatOf(draft);
  return (
    <Dialog title={item ? t("storeEdit", { name: item.nameAr }) : t("storeAdd")} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          const req = item
            ? api.patch(`/admin/store/items/${item.id}`, { ...body, reason: reason.trim() })
            : api.post("/admin/store/items", { ...body, reason: reason.trim() });
          req.then(onDone, (err: unknown) => {
            setError(err);
            setBusy(false);
          });
        }}
      >
        <div className="field">
          <label htmlFor="store-kind">{t("storeKind")}</label>
          <select
            id="store-kind"
            value={draft.kind}
            disabled={item !== null}
            onChange={(e) => setDraft((d) => ({ ...d, kind: e.target.value as StoreKind }))}
          >
            {STORE_KINDS.map((k) => (
              <option key={k} value={k}>
                {t(kindLabel(k))}
              </option>
            ))}
          </select>
          {item && <span className="hint">{t("storeKindFixed")}</span>}
        </div>
        <div className="field">
          <label htmlFor="store-sort">{t("storeSort")}</label>
          <input id="store-sort" className="num" inputMode="numeric" value={draft.sortOrder} onChange={set("sortOrder")} />
          <span className="hint">{t("storeSortHint")}</span>
        </div>
        <div className="field">
          <label htmlFor="store-ar">{t("storeNameAr")}</label>
          <input id="store-ar" dir="rtl" maxLength={40} value={draft.nameAr} onChange={set("nameAr")} />
        </div>
        <div className="field">
          <label htmlFor="store-en">{t("storeNameEn")}</label>
          <input id="store-en" dir="ltr" maxLength={40} value={draft.nameEn} onChange={set("nameEn")} />
        </div>
        <div className="field">
          <label htmlFor="store-still">{t("storeStill")}</label>
          <input id="store-still" className="ltr" maxLength={2048} value={draft.still} onChange={set("still")} />
          {uploadButton("still")}
        </div>
        <div className="field">
          <label htmlFor="store-anim">{t("storeAnimation")}</label>
          <input
            id="store-anim"
            className="ltr"
            maxLength={2048}
            value={draft.animation}
            onChange={(e) => setDraft((d) => ({ ...d, animation: e.target.value, animationFormat: "" }))}
          />
          {uploadButton("animation")}
        </div>
        {draft.kind === ENTRY_CAR && (
          <EntryDisplaySelect
            id="store-entry-display"
            value={draft.entryDisplay}
            onChange={(entryDisplay) => setDraft((d) => ({ ...d, entryDisplay }))}
          />
        )}
        {format === "MP4" && (
          <div className="field span-2">
            <label htmlFor="store-alpha">{t("storeAlpha")}</label>
            <select
              id="store-alpha"
              data-store-alpha
              value={draft.animationAlpha}
              onChange={(e) => setDraft((d) => ({ ...d, animationAlpha: e.target.value as StoreAlpha }))}
            >
              <option value="NONE">{t("storeAlphaNONE")}</option>
              <option value="SIDE_BY_SIDE">{t("storeAlphaSIDE_BY_SIDE")}</option>
            </select>
          </div>
        )}
        <div className="span-2 store-art">
          {draft.still.trim() && <img className="store-thumb" src={draft.still.trim()} alt="" />}
          {format === "SVGA" && <SvgaPreview url={draft.animation.trim()} />}
          {format === "MP4" && <VideoPreview url={draft.animation.trim()} alpha={draft.animationAlpha} />}
        </div>
        {uploadError && <div className="span-2 alert error">{uploadError}</div>}
        <p className="span-2 muted small">{t("storeArtHint")}</p>
        <PriceGrid prices={draft.prices} onChange={(prices) => setDraft((d) => ({ ...d, prices }))} />
        <BadgePicker
          value={draft.badges}
          onChange={(badges) => setDraft((d) => ({ ...d, badges }))}
          detected={(Object.keys(draft.badges) as ItemBadgeCode[]).filter((c) => draft.badges[c].auto && draft.badges[c].on)}
        />
        {!item && (
          <label className="check">
            <input
              type="checkbox"
              checked={draft.enabled}
              onChange={(e) => setDraft((d) => ({ ...d, enabled: e.target.checked }))}
            />
            {t("storeStartOn")}
          </label>
        )}
        {item && <p className="span-2 muted small">{t("storePriceNote")}</p>}
        {!valid && <div className="span-2 alert error">{t("storeInvalid")}</div>}
        <div className="field span-2">
          <label htmlFor="store-reason">{t("reason")}</label>
          <textarea id="store-reason" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} />
          <span className="hint">{t("reasonHint")}</span>
        </div>
        <div className="actions span-2">
          {item && !item.hiddenAt && onDelete && (
            <button type="button" className="btn danger" onClick={onDelete} data-store-form-delete>
              {t("storeDelete")}
            </button>
          )}
          <button type="button" className="btn" onClick={onClose}>
            {t("cancel")}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {item ? t("save") : t("storeAdd")}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** «المتجر» (D270, CONVENTIONS §10.98.5): the store's items by kind, their art and prices, and the sales. */
export function Store() {
  const { t, can, toast } = useApp();
  const items = useAsync(() => api.get<AdminStoreItemList>("/admin/store/items"), []);
  const sales = useAsync(() => api.get<AdminStoreSales>("/admin/store/sales", { limit: "50" }), []);
  const [tab, setTab] = useState<StoreKind | "ALL">("ALL");
  const [edit, setEdit] = useState<AdminStoreItem | "new" | null>(null);
  const [toggle, setToggle] = useState<AdminStoreItem | null>(null);
  // v1.79-live (D289b): «حذف», «إرجاع للمتجر» and the «مخفية» filter.
  const [del, setDel] = useState<AdminStoreItem | null>(null);
  const [back, setBack] = useState<AdminStoreItem | null>(null);
  const [hiddenOnly, setHiddenOnly] = useState(false);
  const lastDelete = useRef<"DELETED" | "HIDDEN">("HIDDEN");
  const setLastDelete = (r: "DELETED" | "HIDDEN") => {
    lastDelete.current = r;
  };
  const done = (message: string = t("done")) => {
    setEdit(null);
    setToggle(null);
    setDel(null);
    setBack(null);
    toast(message);
    items.reload();
    sales.reload();
  };
  // D289 (owner Q2): the items whose «موسمي» has no end yet, and the filter to show only them.
  const [noEndOnly, setNoEndOnly] = useState(false);
  const noEnd = (items.data?.data ?? []).filter((i) => seasonalWithoutEnd(i.badges)).length;
  const hiddenCount = (items.data?.data ?? []).filter((i) => i.hiddenAt !== null).length;
  const shown = (items.data?.data ?? []).filter(
    (i) =>
      (tab === "ALL" || i.kind === tab) &&
      (!noEndOnly || seasonalWithoutEnd(i.badges)) &&
      (i.hiddenAt !== null) === hiddenOnly,
  );
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t("storeTitle")}</h1>
          <p className="muted small">{t("storeSubtitle")}</p>
        </div>
        {can("catalog.manage") && items.data && (
          <button className="btn primary" onClick={() => setEdit("new")} data-store-add>
            <Icon name="plus" size={16} />
            {t("storeAdd")}
          </button>
        )}
      </div>
      <ErrorAlert error={items.error} />
      <SeasonalNoEndNote count={noEnd} only={noEndOnly} onOnly={setNoEndOnly} />
      <div className="card">
        <div className="store-tabs" role="tablist">
          {(["ALL", ...STORE_KINDS] as const).map((k) => (
            <button
              key={k}
              role="tab"
              aria-selected={tab === k}
              className={`btn small ${tab === k ? "active" : ""}`}
              onClick={() => setTab(k)}
              data-store-tab={k}
            >
              {k === "ALL" ? t("storeAll") : t(kindLabel(k))}
            </button>
          ))}
          <button
            role="tab"
            aria-selected={hiddenOnly}
            className={`btn small ${hiddenOnly ? "active" : ""}`}
            onClick={() => setHiddenOnly((h) => !h)}
            data-store-hidden-filter={hiddenOnly ? "on" : "off"}
          >
            {t("storeHiddenFilter", { n: hiddenCount })}
          </button>
        </div>
        {items.loading && !items.data && <p className="muted state">{t("loading")}</p>}
        {items.data && (
          <StoreItemsTable
            items={shown}
            onEdit={(i) => setEdit(i)}
            onToggle={(i) => setToggle(i)}
            onDelete={(i) => setDel(i)}
            onRestore={(i) => setBack(i)}
          />
        )}
        {hiddenOnly && <p className="muted small">{t("storeHiddenNote")}</p>}
        <p className="muted small">{t("storeOffNote")}</p>
      </div>
      <div className="card">
        <h2>{t("storeSales")}</h2>
        <ErrorAlert error={sales.error} />
        {sales.data && <SalesTable sales={sales.data} />}
      </div>
      {edit && (
        <ItemForm
          item={edit === "new" ? null : edit}
          kind={tab === "ALL" ? "AVATAR_FRAME" : tab}
          onClose={() => setEdit(null)}
          onDone={() => done()}
          onDelete={
            edit === "new"
              ? undefined
              : () => {
                  setDel(edit);
                  setEdit(null);
                }
          }
        />
      )}
      {del && (
        <FormDialog
          title={`${t("storeDelete")} · ${del.nameAr}`}
          intro={<StoreDeleteIntro item={del} />}
          fields={[{ ...reasonField(t), required: false }]}
          confirmLabel={storeDeleteCase(del) === "delete" ? t("storeDeleteConfirm") : t("storeHideConfirm")}
          danger
          submit={async (v) => {
            const r = await api.del<{ result: "DELETED" | "HIDDEN" }>(
              `/admin/store/items/${del.id}`,
              v.reason ? { reason: v.reason } : {},
            );
            setLastDelete(r.result);
          }}
          onClose={() => setDel(null)}
          onDone={() => done(lastDelete.current === "DELETED" ? t("storeDeletedToast") : t("storeHiddenToast"))}
        />
      )}
      {back && (
        <FormDialog
          title={`${t("storeRestore")} · ${back.nameAr}`}
          intro={<p className="muted small">{t("storeRestoreNote")}</p>}
          fields={[{ ...reasonField(t), required: false }]}
          confirmLabel={t("storeRestore")}
          submit={(v) => api.post(`/admin/store/items/${back.id}/restore`, v.reason ? { reason: v.reason } : {})}
          onClose={() => setBack(null)}
          onDone={() => done()}
        />
      )}
      {toggle && (
        <FormDialog
          title={`${toggle.enabled ? t("disable") : t("enable")} · ${toggle.nameAr}`}
          intro={toggle.enabled ? <p className="muted small">{t("storeOffNote")}</p> : undefined}
          fields={[reasonField(t)]}
          confirmLabel={toggle.enabled ? t("disable") : t("enable")}
          danger={toggle.enabled}
          submit={(v) =>
            api.post(`/admin/store/items/${toggle.id}/${toggle.enabled ? "disable" : "enable"}`, { reason: v.reason })
          }
          onClose={() => setToggle(null)}
          onDone={() => done()}
        />
      )}
    </>
  );
}
