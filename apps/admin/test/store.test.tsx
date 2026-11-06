/**
 * D270 «المتجر»: the panel's store page rendered to HTML in Node — the items with their kind, art, prices per duration
 * per currency, «جديد», owners and sales; read-only for SUPPORT; the price grid and the form's rules (only the boxes
 * filled are sold, MP4 needs its transparency, the kind fixed on edit); the sales and totals. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D270, EN_D270 } from "../src/i18n-d270";
import { CAP_OF_ROUTE, NAV } from "../src/nav";
import { matchPath } from "../src/router";
import {
  draftOf,
  draftValid,
  formatOf,
  itemBody,
  PriceGrid,
  pricesOf,
  SalesTable,
  StoreItemsTable,
  STORE_KINDS,
  type AdminStoreItem,
  type AdminStoreSales,
} from "../src/pages/Store";
import type { Capability } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: "OWNER" | "SUPPORT") =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const item = (extra: Partial<AdminStoreItem> = {}): AdminStoreItem => ({
  id: "01a27000-0000-7000-8000-000000000001",
  code: "store_0123456789ab",
  kind: "AVATAR_FRAME",
  nameAr: "إطار الوردة",
  nameEn: "Rose frame",
  still: "https://cdn.k.test/media/store/a.png",
  animation: "https://cdn.k.test/media/store/a.svga",
  animationFormat: "SVGA",
  animationAlpha: null,
  artWidth: 300,
  artHeight: 300,
  prices: [
    { currency: "COINS", days: 7, amount: 50_000 },
    { currency: "COINS", days: 30, amount: 150_000 },
    { currency: "CHERRIES", days: 7, amount: 400_000 },
  ],
  sortOrder: 10,
  isNew: true,
  badges: [{ code: "NEW", until: "2099-01-01T00:00:00.000Z", active: true }],
  hiddenAt: null,
  enabled: true,
  owners: 3,
  sold: 7,
  createdAt: "2026-11-04T10:00:00.000Z",
  updatedAt: "2026-11-04T10:00:00.000Z",
  ...extra,
});

describe("D270 store page", () => {
  it("has a route, a nav entry (catalog.view) and every string in both languages", () => {
    expect(matchPath("/store")?.name).toBe("store");
    const entry = NAV.flatMap((g) => g.items).find((i) => i.to === "/store");
    expect(entry).toMatchObject({ key: "navStore", cap: "catalog.view" });
    expect(CAP_OF_ROUTE.store).toBe("catalog.view");
    expect(Object.keys(EN_D270).sort()).toEqual(Object.keys(AR_D270).sort());
    for (const k of STORE_KINDS) {
      expect(DICTIONARIES.ar[`storeKind${k}` as keyof typeof AR_D270]).toBeTruthy();
      expect(DICTIONARIES.en[`storeKind${k}` as keyof typeof AR_D270]).toBeTruthy();
    }
    expect(translate("ar", "navStore")).toBe("المتجر");
  });

  it("lists the items with art, kind, prices, «جديد», owners and sales; the OWNER edits and switches", () => {
    const html = render(
      "ar",
      capsOf("OWNER"),
      <StoreItemsTable items={[item(), item({ id: "x", code: "store_ffffffffffff", enabled: false, prices: [], isNew: false })]} onEdit={noop} onToggle={noop} />,
    );
    expect(html).toContain("إطار الوردة");
    expect(html).toContain("إطارات الصور");
    expect(html).toContain("جديد");
    expect(html).toContain('data-store-price="COINS:7"');
    expect(html).toContain('data-store-price="CHERRIES:7"');
    expect(html).toContain("🍒");
    expect(html).toContain("بلا سعر — لا يُعرض");
    expect(html).toContain('data-store-edit="store_0123456789ab"');
    expect(html).toContain('data-store-toggle="store_ffffffffffff"');
    expect(html).toContain("store_0123456789ab · SVGA");
  });

  it("SUPPORT reads only (no edit / switch buttons); English labels", () => {
    const html = render("en", capsOf("SUPPORT"), <StoreItemsTable items={[item()]} onEdit={noop} onToggle={noop} />);
    expect(html).toContain("Rose frame");
    expect(html).toContain("Avatar frames");
    expect(html).not.toContain("data-store-edit");
    expect(html).not.toContain("data-store-toggle");
    expect(render("en", capsOf("OWNER"), <StoreItemsTable items={[]} onEdit={noop} onToggle={noop} />)).toContain(
      "No items yet",
    );
  });

  it("the price grid: a box per currency × duration, the economy hint", () => {
    const html = render("ar", capsOf("OWNER"), <PriceGrid prices={{ "COINS:7": "50000" }} onChange={noop} />);
    for (const k of ["COINS:7", "COINS:14", "COINS:30", "CHERRIES:7", "CHERRIES:14", "CHERRIES:30"]) {
      expect(html).toContain(`data-store-price-input="${k}"`);
    }
    expect(html).toContain('value="50000"');
    expect(html).toContain("1,000,000 كرزة = 1.10$");
  });

  it("the form: only the boxes filled are sold; create sends everything, an edit only what changed", () => {
    const d = draftOf(null, "CHAT_BUBBLE");
    expect(d.kind).toBe("CHAT_BUBBLE");
    expect(draftValid(d)).toBe(false);
    const filled = {
      ...d,
      nameAr: "فقاعة",
      nameEn: "Bubble",
      animation: "https://cdn.k.test/media/store/b.mp4",
      prices: { "CHERRIES:30": "900000", "COINS:14": "20000", "COINS:7": "" },
    };
    expect(draftValid(filled)).toBe(true);
    expect(pricesOf(filled)).toEqual([
      { currency: "COINS", days: 14, amount: 20_000 },
      { currency: "CHERRIES", days: 30, amount: 900_000 },
    ]);
    expect(formatOf(filled)).toBe("MP4");
    const body = itemBody({ ...filled, animationAlpha: "SIDE_BY_SIDE" }, null);
    expect(body).toMatchObject({
      kind: "CHAT_BUBBLE",
      animationFormat: "MP4",
      animationAlpha: "SIDE_BY_SIDE",
      enabled: false,
    });
    expect(draftValid({ ...filled, prices: { "COINS:7": "0" } })).toBe(false);
    expect(draftValid({ ...filled, still: "http://insecure/a.png" })).toBe(false);

    const before = item();
    expect(itemBody(draftOf(before), before)).toEqual({});
    const renamed = itemBody({ ...draftOf(before), nameEn: "Rose II" }, before);
    expect(renamed).toEqual({ nameEn: "Rose II" });
    const repriced = itemBody({ ...draftOf(before), prices: { "COINS:7": "60000" } }, before);
    expect(repriced).toEqual({ prices: [{ currency: "COINS", days: 7, amount: 60_000 }] });
    expect(itemBody(draftOf(before), before)).not.toHaveProperty("kind");
  });

  it("the sales: totals, buyer, recipient or «لنفسه», the price and an extension", () => {
    const sales: AdminStoreSales = {
      data: [
        {
          id: "s1",
          createdAt: "2026-11-04T10:00:00.000Z",
          item: { id: "i", code: "store_0123456789ab", kind: "AVATAR_FRAME", nameAr: "إطار الوردة", nameEn: "Rose frame" },
          buyer: { id: "b", username: "sara", displayName: "Sara" },
          recipient: { id: "r", username: "omar", displayName: "Omar" },
          currency: "CHERRIES",
          days: 7,
          price: 400_000,
          extended: true,
        },
        {
          id: "s2",
          createdAt: "2026-11-04T11:00:00.000Z",
          item: { id: "i", code: "store_0123456789ab", kind: "AVATAR_FRAME", nameAr: "إطار الوردة", nameEn: "Rose frame" },
          buyer: { id: "b", username: "sara", displayName: "Sara" },
          recipient: null,
          currency: "COINS",
          days: 30,
          price: 150_000,
          extended: false,
        },
      ],
      totals: { purchases: 2, gifts: 1, coins: 150_000, cherries: 400_000 },
    };
    const ar = render("ar", capsOf("SUPPORT"), <SalesTable sales={sales} />);
    expect(ar).toContain("@omar");
    expect(ar).toContain("لنفسه");
    expect(ar).toContain("تمديد");
    const en = render("en", capsOf("SUPPORT"), <SalesTable sales={sales} />);
    expect(en).toContain("2 purchases · 1 gifts · 150,000 coins · 400,000 cherries");
    expect(en).toContain("Themselves");
  });
});
