/**
 * D370 (v1.126-social, CONVENTIONS §10.163) «نقاط الشحن» in the panel: the tier form's points price (empty = not
 * redeemable, sent as null; checked like the server), the tiers table shows it, the adjustment dialog offers recharge
 * points, and every new string exists in both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D370, EN_D370 } from "../src/i18n-d370";
import { AdjustDialog } from "../src/pages/UserControl";
import {
  draftOf,
  draftValid,
  tierBody,
  VipTiersTable,
  type AdminVipTier,
} from "../src/pages/Vip";
import type { Capability, PanelRole, UserDetail } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const state = (lang: Lang, role: PanelRole): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: "a", email: "a@x", username: "a", displayName: "A" },
    roles: [role],
    capabilities: [],
    csrfToken: "x",
    expiresAt: "2026-11-01T00:00:00.000Z",
  } as never,
  can: (cap: Capability) => (CAPABILITY_ROLES[cap] ?? []).includes(role),
  toast: () => undefined,
});
const render = (lang: Lang, node: React.ReactNode, role: PanelRole = "OWNER") =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);

const tier = (code: string, sortOrder: number, pointsPrice: number | null): AdminVipTier => ({
  id: `00000000-0000-7000-8000-00000000000${sortOrder}`,
  code,
  nameAr: `في آي بي ${sortOrder}`,
  nameEn: `VIP ${sortOrder}`,
  sortOrder,
  color: "#C9A227",
  renewalDiscountPercent: 15,
  badgeAnimation: null,
  badgeStill: null,
  priceCoins: 1_000_000 * sortOrder,
  pointsPrice,
  durationDays: 30,
  enabled: true,
  activeMembers: 0,
  perks: [],
  updatedAt: "2026-11-11T10:00:00.000Z",
});

describe("D370 the tier form's points price", () => {
  it("reads, validates and sends it (empty → null; only when changed)", () => {
    const vip1 = tier("VIP_1", 1, 2_000_000);
    const d = draftOf(vip1);
    expect(d.pointsPrice).toBe("2000000");
    expect(draftValid(d, false)).toBe(true);
    expect(tierBody(d, vip1)).not.toHaveProperty("pointsPrice");
    expect(tierBody({ ...d, pointsPrice: "3500000" }, vip1)).toMatchObject({ pointsPrice: 3_500_000 });
    expect(tierBody({ ...d, pointsPrice: " " }, vip1)).toMatchObject({ pointsPrice: null });
    for (const bad of ["0", "-1", "1.5", "abc", "1000000000001"]) {
      expect(draftValid({ ...d, pointsPrice: bad }, false), bad).toBe(false);
    }
    const fresh = draftOf(null);
    expect(fresh.pointsPrice).toBe("");
    expect(
      tierBody({ ...fresh, code: "VIP_2", nameAr: "ب", nameEn: "B", priceCoins: "2000000" }, null),
    ).toMatchObject({ code: "VIP_2", pointsPrice: null });
    // An older server without the field reads as not redeemable.
    const old = { ...vip1 } as Partial<AdminVipTier>;
    delete old.pointsPrice;
    expect(draftOf(old as AdminVipTier).pointsPrice).toBe("");
  });

  it("the tiers table shows the points price or «not redeemable», ar and en", () => {
    const list = {
      data: [tier("VIP_1", 1, 2_000_000), tier("VIP_2", 2, null)],
      builtPerks: [],
      suggestedPerks: [],
      // D374: the perk catalogue (not needed by the table).
      catalogue: [],
      maxPerks: 64,
    };
    const noop = () => undefined;
    const ar = render("ar", <VipTiersTable list={list} onEdit={noop} onToggle={noop} onMove={noop} />);
    expect(ar).toContain("2,000,000 نقطة");
    expect(ar).toContain("لا يُستبدل بالنقاط");
    const en = render("en", <VipTiersTable list={list} onEdit={noop} onToggle={noop} onMove={noop} />);
    expect(en).toContain("2,000,000 points");
    expect(en).toContain("Not redeemable");
  });
});

describe("D370 the adjustment dialog", () => {
  const detail = {
    user: { id: "u" },
    balances: {
      coins: 1,
      cherries: 2,
      lockedTaskCherries: 0,
      cherriesReceived: 0,
      coinsSent: 0,
      rechargePoints: 2_500_000,
    },
  } as unknown as UserDetail;
  it("offers recharge points beside coins and cherries", () => {
    const node = (
      <AdjustDialog userId="u" detail={detail} control={null} onClose={() => undefined} onDone={() => undefined} />
    );
    expect(render("ar", node, "FINANCE")).toContain("نقاط الشحن");
    expect(render("en", node, "FINANCE")).toContain("Recharge points");
  });
});

describe("D370 strings", () => {
  it("every key in both languages, merged into the dictionaries", () => {
    expect(Object.keys(EN_D370).sort()).toEqual(Object.keys(AR_D370).sort());
    for (const k of Object.keys(AR_D370)) {
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D370[k as keyof typeof AR_D370]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D370[k as keyof typeof EN_D370]);
    }
  });
});
