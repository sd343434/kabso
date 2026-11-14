/**
 * D378 (§10.168.4) «مخزون الآيدي الذهبي»: the golden ID stock on the VIP page rendered in Node — the classes the server
 * gives, the numbers the add dialog accepts, the table read-only for SUPPORT and with «إزالة» on FREE numbers only for
 * the OWNER; the perk value's class labels. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D378, EN_D378 } from "../src/i18n-d378";
import {
  GOLDEN_ID_CLASSES,
  GoldenIdTable,
  goldenIdClassOf,
  parseGoldenNumbers,
  type AdminVipGoldenIdList,
} from "../src/pages/VipGoldenIds";
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
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) =>
    CAPABILITY_ROLES[c]!.includes(role),
  );
const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>,
  );

const LIST: AdminVipGoldenIdList = {
  classes: [...GOLDEN_ID_CLASSES],
  data: [
    {
      number: "88",
      class: "REPEATED",
      state: "HELD",
      holder: { id: "00000000-0000-7000-8000-000000000001", username: "layla" },
      heldUntil: "2026-12-11T10:00:00.000Z",
      graceUntil: null,
      claimedAt: "2026-11-11T10:00:00.000Z",
    },
    {
      number: "2026",
      class: "FOUR_DIGIT",
      state: "FREE",
      holder: null,
      heldUntil: null,
      graceUntil: null,
      claimedAt: null,
    },
    {
      number: "12345",
      class: "FIVE_DIGIT",
      state: "GRACE",
      holder: { id: "00000000-0000-7000-8000-000000000002", username: "omar" },
      heldUntil: null,
      graceUntil: "2026-11-18T10:00:00.000Z",
      claimedAt: "2026-10-01T10:00:00.000Z",
    },
  ],
};

describe("D378 golden ID stock in the panel", () => {
  it("has every string in both languages, the four classes and three states named", () => {
    expect(Object.keys(EN_D378).sort()).toEqual(Object.keys(AR_D378).sort());
    for (const k of Object.keys(AR_D378)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D378]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D378]).toBeTruthy();
    }
    for (const c of GOLDEN_ID_CLASSES) {
      expect(
        DICTIONARIES.ar[`vipGoldenClass_${c}` as keyof typeof AR_D378],
      ).toBeTruthy();
    }
  });

  it("gives each number the server's class; others are not golden IDs", () => {
    expect(goldenIdClassOf("88")).toBe("REPEATED");
    expect(goldenIdClassOf("88888888")).toBe("REPEATED");
    expect(goldenIdClassOf("123")).toBe("THREE_DIGIT");
    expect(goldenIdClassOf("2026")).toBe("FOUR_DIGIT");
    expect(goldenIdClassOf("12345")).toBe("FIVE_DIGIT");
    for (const bad of ["8", "0888", "12", "123456", "123456789", "12a4", ""]) {
      expect(goldenIdClassOf(bad)).toBeNull();
    }
  });

  it("the add dialog reads commas, spaces, lines and Arabic digits; refuses a bad or repeated one", () => {
    expect(parseGoldenNumbers("8888, 2026\n123 ٧٧٧")).toEqual({
      ok: true,
      numbers: ["8888", "2026", "123", "777"],
    });
    expect(parseGoldenNumbers("8888، 0123")).toEqual({
      ok: false,
      bad: "0123",
    });
    expect(parseGoldenNumbers("8888 8888")).toEqual({ ok: false, bad: "8888" });
    expect(parseGoldenNumbers("  ")).toEqual({ ok: false, bad: "" });
    const many = Array.from({ length: 101 }, (_, i) => String(10000 + i)).join(
      " ",
    );
    expect(parseGoldenNumbers(many).ok).toBe(false);
  });

  it("SUPPORT reads the stock with no buttons; the OWNER removes FREE numbers only", () => {
    for (const lang of ["ar", "en"] as const) {
      const support = render(
        lang,
        capsOf("SUPPORT"),
        <GoldenIdTable list={LIST} onRemove={() => undefined} />,
      );
      expect(support).toContain('data-vip-golden-id="88"');
      expect(support).toContain("@layla");
      expect(support).not.toContain("data-vip-golden-remove");
      const owner = render(
        lang,
        capsOf("OWNER"),
        <GoldenIdTable list={LIST} onRemove={() => undefined} />,
      );
      expect(owner).toContain('data-vip-golden-remove="2026"');
      expect(owner).not.toContain('data-vip-golden-remove="88"');
      expect(owner).not.toContain('data-vip-golden-remove="12345"');
      expect(owner).toContain('data-vip-golden-state="GRACE"');
      expect(owner).toContain(translate(lang, "vipGoldenState_GRACE"));
    }
  });

  it("an empty stock says so", () => {
    const html = render(
      "ar",
      capsOf("OWNER"),
      <GoldenIdTable
        list={{ classes: [], data: [] }}
        onRemove={() => undefined}
      />,
    );
    expect(html).toContain(AR_D378.vipGoldenEmpty);
  });
});
