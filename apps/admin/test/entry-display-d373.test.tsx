/**
 * D373 (v1.128-social, CONVENTIONS §10.165; owner: «سيارات الدخول ستكون اما بشاشة كاملة او نصف الشاشة … من لوحة الادمن
 * انت تحدد كيف ستكون الدخلة»): «طريقة العرض: شاشة كاملة / الجزء السفلي (٧٠٪)» on the store's entry car form and items table and
 * on the VIP ENTRY_EFFECT perk — only for an entry car, sent only when it changes, in both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D373, EN_D373 } from "../src/i18n-d373";
import {
  draftOf,
  ENTRY_DISPLAYS,
  EntryDisplaySelect,
  itemBody,
  StoreItemsTable,
  type AdminStoreItem,
} from "../src/pages/Store";
import {
  draftOf as tierDraftOf,
  PerksEditor,
  tierBody,
  VipTiersTable,
  type AdminVipPerk,
  type AdminVipTier,
} from "../src/pages/Vip";
import type { Capability } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const owner = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes("OWNER"));
const render = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, owner)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const item = (extra: Partial<AdminStoreItem> = {}): AdminStoreItem => ({
  id: "01a27000-0000-7000-8000-000000000001",
  code: "store_0123456789ab",
  kind: "ENTRY_EFFECT",
  nameAr: "سيارة",
  nameEn: "Car",
  still: null,
  animation: "https://cdn.k.test/media/store/car.svga",
  animationFormat: "SVGA",
  animationAlpha: null,
  artWidth: 750,
  artHeight: 1334,
  entryDisplay: "HALF_SCREEN",
  prices: [{ currency: "COINS", days: 7, amount: 10_000 }],
  sortOrder: 10,
  isNew: false,
  badges: [],
  hiddenAt: null,
  enabled: true,
  owners: 0,
  sold: 0,
  createdAt: "2026-11-11T10:00:00.000Z",
  updatedAt: "2026-11-11T10:00:00.000Z",
  ...extra,
});

const perk = (code: string, extra: Partial<AdminVipPerk> = {}): AdminVipPerk => ({
  code,
  titleAr: code === "ENTRY_EFFECT" ? "مؤثر الدخول" : "شارة",
  titleEn: code === "ENTRY_EFFECT" ? "Entry effect" : "Badge",
  descriptionAr: null,
  descriptionEn: null,
  enabled: true,
  available: true,
  animation: null,
  still: null,
  artWidth: null,
  artHeight: null,
  amount: null,
  entryDisplay: code === "ENTRY_EFFECT" ? "FULL_SCREEN" : null,
  ...extra,
});
const tier = (perks: AdminVipPerk[]): AdminVipTier => ({
  id: "01a25200-0000-7000-8000-000000000001",
  code: "VIP_1",
  nameAr: "في آي بي 1",
  nameEn: "VIP 1",
  sortOrder: 1,
  color: "#2E8B3D",
  nameColor: null,
  renewalDiscountPercent: 15,
  pointsPrice: null,
  badgeAnimation: null,
  badgeStill: null,
  priceCoins: 1_000_000,
  durationDays: 30,
  enabled: true,
  activeMembers: 0,
  perks,
  updatedAt: "2026-11-11T10:00:00.000Z",
});

describe("D373 an entry car's display in the panel", () => {
  it("has every string in both languages: «طريقة العرض: شاشة كاملة / الجزء السفلي (٧٠٪)»", () => {
    expect(Object.keys(EN_D373).sort()).toEqual(Object.keys(AR_D373).sort());
    for (const k of Object.keys(AR_D373)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D373]).toBe(AR_D373[k as keyof typeof AR_D373]);
      expect(DICTIONARIES.en[k as keyof typeof AR_D373]).toBe(EN_D373[k as keyof typeof AR_D373]);
    }
    expect(AR_D373.entryDisplay).toBe("طريقة العرض");
    expect(AR_D373.entryDisplayFULL_SCREEN).toBe("شاشة كاملة");
    expect(AR_D373.entryDisplayHALF_SCREEN).toBe("الجزء السفلي (٧٠٪)");
    expect(EN_D373.entryDisplayHALF_SCREEN).toBe("Bottom (70%)");
    expect(ENTRY_DISPLAYS).toEqual(["FULL_SCREEN", "HALF_SCREEN"]);
  });

  it("the select offers the two displays with the chosen one selected (ar and en)", () => {
    const ar = render("ar", <EntryDisplaySelect id="x" value="HALF_SCREEN" onChange={noop} />);
    expect(ar).toContain("طريقة العرض");
    expect(ar).toContain('<option value="FULL_SCREEN">شاشة كاملة</option>');
    expect(ar).toContain('<option value="HALF_SCREEN" selected="">الجزء السفلي (٧٠٪)</option>');
    const en = render("en", <EntryDisplaySelect id="x" value="FULL_SCREEN" onChange={noop} />);
    expect(en).toContain('<option value="FULL_SCREEN" selected="">Full screen</option>');
    expect(en).toContain("Bottom (70%)");
  });

  it("the items table shows an entry car's display; other kinds show none", () => {
    const html = render(
      "ar",
      <StoreItemsTable
        items={[
          item(),
          item({ id: "x2", code: "store_0123456789ac", entryDisplay: "FULL_SCREEN" }),
          item({ id: "x3", code: "store_0123456789ad", kind: "AVATAR_FRAME", entryDisplay: null }),
        ]}
        onEdit={noop}
        onToggle={noop}
      />,
    );
    expect(html).toMatch(/data-store-entry-display="store_0123456789ab">الجزء السفلي \(٧٠٪\)</);
    expect(html).toMatch(/data-store-entry-display="store_0123456789ac">شاشة كاملة</);
    expect(html).not.toContain('data-store-entry-display="store_0123456789ad"');
    // An item from an older server (no field) reads as full screen.
    const old = render("en", <StoreItemsTable items={[item({ entryDisplay: undefined })]} onEdit={noop} onToggle={noop} />);
    expect(old).toMatch(/data-store-entry-display="store_0123456789ab">Full screen</);
  });

  it("the store body: sent on create for an entry car only, and on edit only when it changed", () => {
    const fresh = draftOf(null, "ENTRY_EFFECT");
    expect(fresh.entryDisplay).toBe("FULL_SCREEN");
    expect(itemBody({ ...fresh, nameAr: "س", nameEn: "c", entryDisplay: "HALF_SCREEN" }, null)).toMatchObject({
      kind: "ENTRY_EFFECT",
      entryDisplay: "HALF_SCREEN",
    });
    expect(itemBody({ ...draftOf(null, "AVATAR_FRAME"), nameAr: "س", nameEn: "f" }, null)).not.toHaveProperty(
      "entryDisplay",
    );
    const before = item();
    expect(draftOf(before).entryDisplay).toBe("HALF_SCREEN");
    expect(itemBody(draftOf(before), before)).toEqual({});
    expect(itemBody({ ...draftOf(before), entryDisplay: "FULL_SCREEN" }, before)).toEqual({
      entryDisplay: "FULL_SCREEN",
    });
    const frame = item({ kind: "AVATAR_FRAME", entryDisplay: null });
    expect(itemBody({ ...draftOf(frame), entryDisplay: "HALF_SCREEN" }, frame)).toEqual({});
  });

  it("the VIP ENTRY_EFFECT perk: the select in the perks editor, its display in the tiers table, the body", () => {
    const t = tier([perk("BADGE"), perk("ENTRY_EFFECT", { entryDisplay: "HALF_SCREEN" })]);
    const editor = render(
      "ar",
      <PerksEditor perks={tierDraftOf(t).perks} built={[]} suggested={[]} onChange={noop} />,
    );
    expect(editor).toContain('data-entry-display="vp-entry-display-1"');
    expect(editor).not.toContain('data-entry-display="vp-entry-display-0"');
    expect(editor).toContain('<option value="HALF_SCREEN" selected="">الجزء السفلي (٧٠٪)</option>');
    const table = render(
      "en",
      <VipTiersTable
        list={{ data: [t], builtPerks: [], suggestedPerks: [] }}
        onEdit={noop}
        onToggle={noop}
        onMove={noop}
      />,
    );
    expect(table).toMatch(/data-vip-entry-display="VIP_1"> · Bottom \(70%\)</);

    // Unchanged: nothing sent. Changed: the perks with the display on the entry car only.
    expect(tierBody(tierDraftOf(t), t)).toEqual({});
    const draft = tierDraftOf(t);
    const changed = {
      ...draft,
      perks: draft.perks.map((p) => (p.code === "ENTRY_EFFECT" ? { ...p, entryDisplay: "FULL_SCREEN" as const } : p)),
    };
    const body = tierBody(changed, t) as { perks: Record<string, unknown>[] };
    expect(body.perks.find((p) => p.code === "ENTRY_EFFECT")!.entryDisplay).toBe("FULL_SCREEN");
    expect(body.perks.find((p) => p.code === "BADGE")).not.toHaveProperty("entryDisplay");
  });
});
