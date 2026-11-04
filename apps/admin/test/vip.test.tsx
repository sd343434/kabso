/**
 * D252 «VIP»: the panel's VIP page rendered to HTML in Node — the tiers in order with their own perks, coins only, every
 * perk marked as not built yet (the server's list), read-only for SUPPORT, the order buttons and the form's rules for
 * the OWNER. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D252, EN_D252 } from "../src/i18n-d252";
import { NAV } from "../src/nav";
import { matchPath } from "../src/router";
import {
  amountOk,
  draftOf,
  draftValid,
  moveTier,
  PerksEditor,
  tierBody,
  VipTiersTable,
  type AdminVipTier,
  type AdminVipTierList,
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
const capsOf = (role: "OWNER" | "SUPPORT" | "FINANCE" | "MODERATION") =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) =>
    CAPABILITY_ROLES[c]!.includes(role),
  );
const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>,
  );

const tier = (
  code: string,
  sortOrder: number,
  extra: Partial<AdminVipTier> = {},
): AdminVipTier => ({
  id: `00000000-0000-7000-8000-00000000000${sortOrder}`,
  code,
  nameAr: `في آي بي ${sortOrder}`,
  nameEn: `VIP ${sortOrder}`,
  sortOrder,
  color: "#C9A227",
  badgeAnimation: "https://cdn.k.test/vip1_badge.svga",
  badgeStill: "https://cdn.k.test/vip1_badge.png",
  priceCoins: 3_000_000 * sortOrder,
  durationDays: 30,
  enabled: true,
  activeMembers: 4,
  perks: [
    {
      code: "BADGE",
      titleAr: "شارة VIP",
      titleEn: "VIP badge",
      descriptionAr: null,
      descriptionEn: null,
      enabled: true,
      available: false,
      animation: "https://cdn.k.test/vip1_badge.svga",
      still: "https://cdn.k.test/vip1_badge.png",
      artWidth: 500,
      artHeight: 500,
      amount: null,
    },
  ],
  updatedAt: "2026-11-03T10:00:00.000Z",
  ...extra,
});

const LIST: AdminVipTierList = {
  data: [
    tier("VIP_1", 1),
    tier("VIP_2", 2, { enabled: false }),
    tier("VIP_3", 3),
  ],
  builtPerks: [],
  suggestedPerks: ["BADGE", "AVATAR_FRAME", "ENTRY_EFFECT"],
};
const noop = () => undefined;

describe("D252 VIP in the panel", () => {
  it("has every string in both languages, a route and a nav item under catalog.view", () => {
    expect(Object.keys(EN_D252).sort()).toEqual(Object.keys(AR_D252).sort());
    for (const k of Object.keys(AR_D252)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D252]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D252]).toBeTruthy();
    }
    expect(matchPath("/vip")?.name).toBe("vip");
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === "/vip");
    expect(item?.cap).toBe("catalog.view");
  });

  it("SUPPORT reads the tiers in order with their perks, in coins only, with no buttons", () => {
    const html = render(
      "ar",
      capsOf("SUPPORT"),
      <VipTiersTable list={LIST} onEdit={noop} onToggle={noop} onMove={noop} />,
    );
    expect(html.indexOf('data-vip-tier="VIP_1"')).toBeLessThan(
      html.indexOf('data-vip-tier="VIP_2"'),
    );
    expect(html.indexOf('data-vip-tier="VIP_2"')).toBeLessThan(
      html.indexOf('data-vip-tier="VIP_3"'),
    );
    expect(html).toContain("9,000,000");
    expect(html).toContain("30 يوماً");
    expect(html).toContain("شارة VIP");
    expect(html).toContain("غير مفعّلة في التطبيق بعد");
    expect(html).toContain("متوقف");
    expect(html).not.toContain("data-vip-edit");
    expect(html).not.toContain("data-vip-up");
    expect(html).not.toMatch(/دينار|\$|USD/);
  });

  it("the OWNER edits, toggles and moves; the first cannot go up nor the last down", () => {
    const html = render(
      "en",
      capsOf("OWNER"),
      <VipTiersTable list={LIST} onEdit={noop} onToggle={noop} onMove={noop} />,
    );
    expect(html).toContain('data-vip-edit="VIP_1"');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*data-vip-up="VIP_1"/);
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*data-vip-down="VIP_3"/);
    expect(html).not.toMatch(/<button[^>]*disabled=""[^>]*data-vip-up="VIP_2"/);
    // The tier switched off offers «Enable».
    expect(html).toMatch(/data-vip-toggle="VIP_2">Enable</);
    const empty = render(
      "en",
      capsOf("OWNER"),
      <VipTiersTable
        list={{ ...LIST, data: [] }}
        onEdit={noop}
        onToggle={noop}
        onMove={noop}
      />,
    );
    expect(empty).toContain("No tiers yet");
  });

  it("the order moves one tier by one place", () => {
    expect(moveTier(["a", "b", "c"], 1, -1)).toEqual(["b", "a", "c"]);
    expect(moveTier(["a", "b", "c"], 1, 1)).toEqual(["a", "c", "b"]);
    expect(moveTier(["a", "b", "c"], 0, -1)).toBeNull();
    expect(moveTier(["a", "b", "c"], 2, 1)).toBeNull();
  });

  it("the form: the same rules as the server; an edit sends only what changed", () => {
    const fresh = {
      ...draftOf(null),
      code: "VIP_4",
      nameAr: "ملكي",
      nameEn: "Royal",
      priceCoins: "5000000",
    };
    expect(draftValid(fresh, true)).toBe(true);
    expect(draftValid({ ...fresh, code: "vip" }, true)).toBe(false);
    expect(draftValid({ ...fresh, color: "gold" }, true)).toBe(false);
    expect(draftValid({ ...fresh, durationDays: "366" }, true)).toBe(false);
    expect(draftValid({ ...fresh, priceCoins: "0" }, true)).toBe(false);
    expect(
      draftValid({ ...fresh, badgeStill: "http://x.example/e.png" }, true),
    ).toBe(false);
    expect(
      draftValid({ ...fresh, badgeStill: "https://cdn.k.test/x.png" }, true),
    ).toBe(true);
    expect(draftValid({ ...fresh, badgeStill: "assets/vip/x.png" }, true)).toBe(
      false,
    );
    const perk = {
      code: "BADGE",
      titleAr: "شارة",
      titleEn: "Badge",
      descriptionAr: "",
      descriptionEn: "",
      enabled: true,
      animation: "",
      still: "",
      artWidth: "",
      artHeight: "",
      amount: "",
    };
    expect(draftValid({ ...fresh, perks: [perk, perk] }, true)).toBe(false);
    expect(tierBody(fresh, null)).toMatchObject({
      code: "VIP_4",
      color: "#C9A227",
      priceCoins: 5_000_000,
      enabled: false,
      perks: [],
    });

    const before = LIST.data[0]!;
    expect(tierBody(draftOf(before), before)).toEqual({});
    expect(
      tierBody({ ...draftOf(before), priceCoins: "4000000" }, before),
    ).toEqual({ priceCoins: 4_000_000 });
    // D258: the special text colour, upper case; a bad one is refused.
    expect(
      tierBody({ ...draftOf(before), nameColor: "#ffd12e" }, before),
    ).toEqual({ nameColor: "#FFD12E" });
    expect(draftValid({ ...draftOf(before), nameColor: "gold" }, false)).toBe(
      false,
    );
    const withPerk = {
      ...draftOf(before),
      perks: [...draftOf(before).perks, { ...perk, code: "ENTRY_EFFECT" }],
    };
    expect(tierBody(withPerk, before)).toEqual({
      perks: [
        {
          code: "BADGE",
          titleAr: "شارة VIP",
          titleEn: "VIP badge",
          descriptionAr: null,
          descriptionEn: null,
          enabled: true,
          animation: "https://cdn.k.test/vip1_badge.svga",
          still: "https://cdn.k.test/vip1_badge.png",
          artWidth: 500,
          artHeight: 500,
          amount: null,
        },
        {
          code: "ENTRY_EFFECT",
          titleAr: "شارة",
          titleEn: "Badge",
          descriptionAr: null,
          descriptionEn: null,
          enabled: true,
          animation: null,
          still: null,
          artWidth: null,
          artHeight: null,
          amount: null,
        },
      ],
    });
    // D258: the amount — only the perks that take one, within their bounds.
    expect(amountOk("DAILY_BULLET", "3")).toBe(true);
    expect(amountOk("DAILY_BULLET", "101")).toBe(false);
    expect(amountOk("LEVEL_SPEEDUP", "1")).toBe(true);
    expect(amountOk("BADGE", "2")).toBe(false);
    expect(amountOk("BADGE", "")).toBe(true);
    const bullets = {
      ...draftOf(before),
      perks: [{ ...perk, code: "DAILY_BULLET", amount: "3" }],
    };
    expect(draftValid(bullets, false)).toBe(true);
    expect(
      (tierBody(bullets, before).perks as { amount: number }[])[0]!.amount,
    ).toBe(3);
    expect(
      draftValid(
        { ...bullets, perks: [{ ...perk, code: "BADGE", amount: "3" }] },
        false,
      ),
    ).toBe(false);
  });

  it("the perks editor says which perks are not built and suggests codes", () => {
    const html = render(
      "en",
      capsOf("OWNER"),
      <PerksEditor
        perks={draftOf(LIST.data[0]!).perks}
        built={[]}
        suggested={LIST.suggestedPerks}
        onChange={noop}
      />,
    );
    expect(html).toContain("Not working in the app yet");
    expect(html).toContain('<option value="AVATAR_FRAME">');
    expect(html).toContain('data-vip-perk="0"');
    // D258: the amount field and the two uploads.
    expect(html).toContain('data-vip-amount="BADGE"');
    expect(html).toContain('data-vip-upload="0:still"');
    expect(html).toContain('data-vip-upload="0:animation"');
  });
});
