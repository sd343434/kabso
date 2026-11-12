/**
 * D252 «VIP»: the panel's VIP page rendered to HTML in Node — the tiers in order with their own perks, coins only, every
 * perk marked as not built yet (the server's list), read-only for SUPPORT, the order buttons and the form's rules for
 * the OWNER. Both languages. D374: the perks are the catalogue's checkbox grid with typed values and art fields.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D252, EN_D252 } from "../src/i18n-d252";
import { NAV } from "../src/nav";
import { matchPath } from "../src/router";
import {
  draftOf,
  draftValid,
  moveTier,
  PerksEditor,
  perkOf,
  tierBody,
  valueBody,
  valueOk,
  VipTiersTable,
  type AdminVipTier,
  type AdminVipTierList,
  type CatalogueEntry,
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
  renewalDiscountPercent: 15,
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

/** D374: a part of the server's perk catalogue (`listAdminVipTiers.catalogue`), one perk per value kind. */
const entry = (
  code: string,
  category: string,
  built: boolean,
  value: CatalogueEntry["value"],
  art: CatalogueEntry["art"] = null,
  legacyAmount = false,
): CatalogueEntry => ({
  code,
  category,
  titleAr: `ميزة ${code}`,
  titleEn: `Perk ${code}`,
  descriptionAr: "وصف",
  descriptionEn: "About",
  built,
  value,
  art,
  legacyAmount,
});
const STILL_SVGA = ["SVGA", "PNG", "WEBP"];
const CATALOGUE: CatalogueEntry[] = [
  entry("BADGE", "IDENTITY", true, { kind: "none" }, { kinds: STILL_SVGA, width: 1943, height: 634 }),
  entry("AVATAR_FRAME", "IDENTITY", true, { kind: "none" }, { kinds: STILL_SVGA, width: 600, height: 600 }),
  entry("ANIMATED_COVER", "IDENTITY", false, { kind: "none" }, { kinds: ["SVGA", "MP4", "PNG", "WEBP"], width: 1080, height: 720 }),
  entry("STORY_RING", "IDENTITY", false, { kind: "color" }),
  entry("ENTRY_EFFECT", "ENTRANCE", true, { kind: "none" }, { kinds: STILL_SVGA, width: 750, height: 1334 }),
  entry("DAILY_BULLET", "CHAT", true, { kind: "int", min: 1, max: 100, unit: "per_day" }, null, true),
  entry("LONGER_VOICE", "CHAT", false, { kind: "int", min: 31, max: 600, unit: "seconds" }),
  entry("SEAT_EMOJI", "ROOM", false, { kind: "art_list", kinds: STILL_SVGA, maxItems: 24 }),
  entry("EXCLUSIVE_GIFTS", "GIFTS", false, { kind: "list", item: "GIFT_CODE", maxItems: 50 }),
  entry("MONTHLY_ROCKETS", "REWARDS", false, {
    kind: "composite",
    fields: [
      { key: "count", labelAr: "العدد شهرياً", labelEn: "A month", schema: { kind: "int", min: 1, max: 30, unit: "per_month" } },
      { key: "stage", labelAr: "نوع الصاروخ", labelEn: "Rocket type", schema: { kind: "enum", source: "ROCKET_STAGE", options: ["STAGE_1", "STAGE_2", "STAGE_3", "STAGE_4"] } },
    ],
  }),
  entry("PROFILE_VISIT_HIDE", "ROOM", false, { kind: "none" }),
];

const LIST: AdminVipTierList = {
  data: [
    tier("VIP_1", 1),
    tier("VIP_2", 2, { enabled: false }),
    tier("VIP_3", 3),
  ],
  builtPerks: [],
  suggestedPerks: CATALOGUE.map((e) => e.code),
  catalogue: CATALOGUE,
  maxPerks: 64,
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
    const perk = perkOf(CATALOGUE[0]!);
    expect(draftValid({ ...fresh, perks: [perk, perk] }, true, CATALOGUE)).toBe(false);
    expect(tierBody(fresh, null, CATALOGUE)).toMatchObject({
      code: "VIP_4",
      color: "#C9A227",
      priceCoins: 5_000_000,
      enabled: false,
      perks: [],
    });

    const before = LIST.data[0]!;
    expect(tierBody(draftOf(before, CATALOGUE), before, CATALOGUE)).toEqual({});
    expect(
      tierBody({ ...draftOf(before, CATALOGUE), priceCoins: "4000000" }, before, CATALOGUE),
    ).toEqual({ priceCoins: 4_000_000 });
    // D258: the special text colour, upper case; a bad one is refused.
    expect(
      tierBody({ ...draftOf(before, CATALOGUE), nameColor: "#ffd12e" }, before, CATALOGUE),
    ).toEqual({ nameColor: "#FFD12E" });
    expect(draftValid({ ...draftOf(before, CATALOGUE), nameColor: "gold" }, false, CATALOGUE)).toBe(
      false,
    );
    // D374: a ticked perk carries the catalogue's titles; the list is sent whole, each with its value.
    const withPerk = {
      ...draftOf(before, CATALOGUE),
      perks: [...draftOf(before, CATALOGUE).perks, perkOf(CATALOGUE[4]!)],
    };
    expect(tierBody(withPerk, before, CATALOGUE)).toEqual({
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
          video: null,
          artWidth: 500,
          artHeight: 500,
          value: null,
        },
        {
          code: "ENTRY_EFFECT",
          titleAr: "ميزة ENTRY_EFFECT",
          titleEn: "Perk ENTRY_EFFECT",
          descriptionAr: null,
          descriptionEn: null,
          enabled: true,
          animation: null,
          still: null,
          video: null,
          artWidth: null,
          artHeight: null,
          value: null,
        },
      ],
    });
    // D374: a code outside the catalogue is not valid; more than maxPerks neither.
    expect(draftValid({ ...fresh, perks: [{ ...perk, code: "MADE_UP" }] }, true, CATALOGUE)).toBe(false);
    expect(draftValid({ ...fresh, perks: [perk] }, true, CATALOGUE, 0)).toBe(false);
    // D258 / D374: DAILY_BULLET's number is its value (the server keeps it in `amount` too), within its bounds.
    const bullets = {
      ...draftOf(before, CATALOGUE),
      perks: [{ ...perkOf(CATALOGUE[5]!), value: "3" }],
    };
    expect(draftValid(bullets, false, CATALOGUE)).toBe(true);
    expect((tierBody(bullets, before, CATALOGUE).perks as { value: number }[])[0]!.value).toBe(3);
    expect(
      draftValid({ ...bullets, perks: [{ ...perkOf(CATALOGUE[5]!), value: "101" }] }, false, CATALOGUE),
    ).toBe(false);
    // An older tier row with only `amount` reads as the value.
    const legacy = tier("VIP_9", 9, {
      perks: [{ ...before.perks[0]!, code: "DAILY_BULLET", amount: 3, value: undefined }],
    });
    expect(draftOf(legacy, CATALOGUE).perks[0]!.value).toBe("3");
    // A MP4 only where the art takes one.
    expect(
      draftValid({ ...fresh, perks: [{ ...perkOf(CATALOGUE[2]!), video: "https://cdn.k.test/c.mp4" }] }, true, CATALOGUE),
    ).toBe(true);
    expect(
      draftValid({ ...fresh, perks: [{ ...perk, video: "https://cdn.k.test/c.mp4" }] }, true, CATALOGUE),
    ).toBe(false);
  });

  it("D374: the value of every kind, checked and sent as the server takes it", () => {
    const schema = (code: string) => CATALOGUE.find((e) => e.code === code)!.value;
    expect(valueOk(schema("BADGE"), "")).toBe(true);
    expect(valueBody(schema("BADGE"), "")).toBeNull();
    expect(valueOk(schema("LONGER_VOICE"), "180")).toBe(true);
    expect(valueOk(schema("LONGER_VOICE"), "30")).toBe(false);
    expect(valueOk(schema("LONGER_VOICE"), "1.5")).toBe(false);
    expect(valueBody(schema("LONGER_VOICE"), "180")).toBe(180);
    expect(valueBody(schema("LONGER_VOICE"), " ")).toBeNull();
    expect(valueOk(schema("STORY_RING"), "#ffaa00")).toBe(true);
    expect(valueBody(schema("STORY_RING"), "#ffaa00")).toBe("#FFAA00");
    expect(valueOk(schema("STORY_RING"), "red")).toBe(false);
    expect(valueOk(schema("EXCLUSIVE_GIFTS"), ["rose", " castle"])).toBe(true);
    expect(valueBody(schema("EXCLUSIVE_GIFTS"), ["rose", " castle", ""])).toEqual(["rose", "castle"]);
    expect(valueOk(schema("EXCLUSIVE_GIFTS"), ["rose", "rose"])).toBe(false);
    expect(valueOk(schema("EXCLUSIVE_GIFTS"), ["Rose!"])).toBe(false);
    expect(valueOk(schema("SEAT_EMOJI"), ["https://cdn.k.test/a.png"])).toBe(true);
    expect(valueOk(schema("SEAT_EMOJI"), ["http://cdn.k.test/a.png"])).toBe(false);
    expect(valueBody(schema("SEAT_EMOJI"), [])).toBeNull();
    expect(valueOk(schema("MONTHLY_ROCKETS"), { count: "2", stage: "STAGE_3" })).toBe(true);
    expect(valueBody(schema("MONTHLY_ROCKETS"), { count: "2", stage: "STAGE_3" })).toEqual({
      count: 2,
      stage: "STAGE_3",
    });
    // All fields or none.
    expect(valueOk(schema("MONTHLY_ROCKETS"), { count: "2" })).toBe(false);
    expect(valueOk(schema("MONTHLY_ROCKETS"), {})).toBe(true);
    expect(valueBody(schema("MONTHLY_ROCKETS"), {})).toBeNull();
    expect(valueOk(schema("MONTHLY_ROCKETS"), { count: "31", stage: "STAGE_1" })).toBe(false);
  });

  it("D374: a retired or unknown row saved before is listed, never sent, and its removal sends the list", () => {
    const before = tier("VIP_1", 1, {
      perks: [
        ...LIST.data[0]!.perks,
        { ...LIST.data[0]!.perks[0]!, code: "DAILY_COINS", retired: true, catalogued: false },
      ],
    });
    const d = draftOf(before, CATALOGUE);
    expect(d.perks.map((p) => p.stale ?? null)).toEqual([null, "retired"]);
    expect(draftValid(d, false, CATALOGUE)).toBe(true);
    expect(tierBody(d, before, CATALOGUE)).toEqual({});
    const removed = { ...d, perks: d.perks.filter((p) => p.stale === undefined) };
    expect((tierBody(removed, before, CATALOGUE).perks as { code: string }[]).map((p) => p.code)).toEqual([
      "BADGE",
    ]);
    const html = render(
      "ar",
      capsOf("OWNER"),
      <PerksEditor perks={d.perks} catalogue={CATALOGUE} onChange={noop} tierCode="VIP_1" />,
    );
    expect(html).toContain("data-vip-stale");
    expect(html).toContain('data-vip-stale-remove="DAILY_COINS"');
    expect(html).toContain("أزيلت");
  });

  it("D374 (owner): a perk with no art and no value is a tick only, no box opens for it", () => {
    const simple = CATALOGUE.find((e) => e.code === "PROFILE_VISIT_HIDE")!;
    const editor = (perks: ReturnType<typeof perkOf>[]) =>
      render(
        "ar",
        capsOf("OWNER"),
        <PerksEditor perks={perks} catalogue={CATALOGUE} onChange={noop} tierCode="VIP_1" />,
      );
    const on = editor([perkOf(simple)]);
    expect(on).toContain('data-vip-perk-pick="PROFILE_VISIT_HIDE"');
    expect(on).not.toContain('data-vip-perk-fields="PROFILE_VISIT_HIDE"');
    expect(on).not.toContain('data-vip-upload="PROFILE_VISIT_HIDE');
    // A ticked perk that was switched off keeps its box, so it can be switched back on.
    const off = editor([{ ...perkOf(simple), enabled: false }]);
    expect(off).toContain('data-vip-perk-fields="PROFILE_VISIT_HIDE"');
    // A perk with art still opens its upload box.
    const art = editor([perkOf(CATALOGUE[1]!)]);
    expect(art).toContain('data-vip-perk-fields="AVATAR_FRAME"');
    expect(art).toContain('data-vip-upload="AVATAR_FRAME:animation"');
  });

  it("D374: the perks are a checkbox grid by category, «مبنية / قريباً» each; a ticked perk shows its fields", () => {
    const perks = [
      ...draftOf(LIST.data[0]!, CATALOGUE).perks,
      { ...perkOf(CATALOGUE[2]!) },
      { ...perkOf(CATALOGUE[5]!), value: "3" },
      { ...perkOf(CATALOGUE[7]!), value: ["https://cdn.k.test/e1.png"] },
      { ...perkOf(CATALOGUE[8]!), value: ["rose"] },
      { ...perkOf(CATALOGUE[9]!), value: { count: "2", stage: "STAGE_1" } },
    ];
    const en = render(
      "en",
      capsOf("OWNER"),
      <PerksEditor perks={perks} catalogue={CATALOGUE} maxPerks={64} onChange={noop} tierCode="VIP_1" />,
    );
    // Every catalogue perk is a checkbox, grouped by category, with its built state.
    for (const e of CATALOGUE) expect(en).toContain(`data-vip-perk-pick="${e.code}"`);
    for (const c of ["IDENTITY", "ENTRANCE", "CHAT", "ROOM", "GIFTS", "REWARDS"])
      expect(en).toContain(`data-vip-cat="${c}"`);
    expect(en).toContain("Identity and look");
    expect(en).toContain('data-vip-built="built"');
    expect(en).toContain('data-vip-built="soon"');
    expect(en).toContain(">Soon<");
    expect(en).toContain(">Built<");
    expect(en).toContain("6 / 64 perks");
    // The inheritance hint.
    expect(en).toContain("data-vip-inherit-hint");
    expect(en).toContain("Each tier also holds the perks of the tiers before it");
    // Ticked: its fields; not ticked: none.
    expect(en).toContain('data-vip-perk-fields="BADGE"');
    expect(en).not.toContain('data-vip-perk-fields="AVATAR_FRAME"');
    // D268: the BADGE perk is labelled as the badge beside the name, with its uploads.
    expect(en).toContain("data-vip-name-badge");
    expect(en).toContain("Upload the name badge (PNG)");
    expect(en).toContain('data-vip-upload="BADGE:still"');
    expect(en).toContain('data-vip-upload="BADGE:animation"');
    expect(en).toContain("Suggested size 1943×634");
    // MP4 art for the animated cover.
    expect(en).toContain('data-vip-upload="ANIMATED_COVER:video"');
    expect(en).toContain("Upload MP4");
    // The values: an int with its unit and range, an art pack, gift codes, a composite with an enum.
    expect(en).toContain('data-vip-value="vp-DAILY_BULLET"');
    expect(en).toContain("Value (a day)");
    expect(en).toContain("1 to 100");
    expect(en).toContain('data-vip-art-pack="SEAT_EMOJI"');
    expect(en).toContain('data-vip-upload="SEAT_EMOJI:pack"');
    expect(en).toContain('data-vip-value="vp-EXCLUSIVE_GIFTS"');
    expect(en).toContain('data-vip-value="vp-MONTHLY_ROCKETS-count"');
    expect(en).toContain("Rocket 3");
    const ar = render(
      "ar",
      capsOf("OWNER"),
      <PerksEditor perks={perks} catalogue={CATALOGUE} onChange={noop} tierCode="VIP_1" />,
    );
    expect(ar).toContain(">قريباً<");
    expect(ar).toContain(">مبنية<");
    expect(ar).toContain("الهوية والمظهر");
    expect(ar).toContain("صاروخ 3");
    expect(ar).toContain("كل مستوى يملك أيضاً ميزات المستويات التي قبله");
  });

  it("D374: at the limit, an unticked perk cannot be ticked", () => {
    const html = render(
      "en",
      capsOf("OWNER"),
      <PerksEditor
        perks={[perkOf(CATALOGUE[0]!)]}
        catalogue={CATALOGUE}
        maxPerks={1}
        onChange={noop}
      />,
    );
    expect(html).toMatch(/disabled=""[^>]*data-vip-perk-pick="AVATAR_FRAME"|data-vip-perk-pick="AVATAR_FRAME"[^>]*disabled=""/);
  });
});
