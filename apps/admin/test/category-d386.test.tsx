/**
 * D386 (v1.138-social, CONVENTIONS §10.175.5): the account category on the user page — the category, «موثّقة» /
 * «مقفلة», the latest request and only the actions that change something; a Kabso Team account's note; the actions
 * hidden without `users.profile_edit`. Both languages, every category named.
 */
import type { ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D386, EN_D386 } from "../src/i18n-d386";
import { NAV } from "../src/nav";
import { categoryActions, UserCategoryView } from "../src/pages/Categories";
import type { AccountCategory, AdminUserCategory, Capability } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const capsOf = (role: string) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role as never));
const state = (lang: Lang, role = "OWNER"): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => capsOf(role).includes(c),
  toast: () => undefined,
});
const wrap = (lang: Lang, node: ReactNode, role = "OWNER") =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const CATEGORIES: AccountCategory[] = [
  "SINGER",
  "MUSICIAN",
  "POET",
  "PRESENTER",
  "GAMER",
  "CONTENT_CREATOR",
  "ATHLETE",
  "ARTIST",
  "BLOGGER",
  "PUBLIC_FIGURE",
  "OTHER",
  "QURAN_RECITER",
  "STORYTELLER",
  "WRITER",
  "JOURNALIST",
  "PHOTOGRAPHER",
  "ACTOR",
  "COMEDIAN",
  "CALLIGRAPHER",
  "DESIGNER",
  "CHEF",
  "TEACHER",
  "DJ",
  "TRAVELER",
];

const BASE: AdminUserCategory = {
  category: "QURAN_RECITER",
  verified: false,
  verifiedAt: null,
  verifiedBy: null,
  locked: false,
  lockedAt: null,
  kabsoTeam: false,
  request: {
    id: "r1",
    category: "QURAN_RECITER",
    status: "PENDING",
    createdAt: "2026-11-12T10:00:00.000Z",
    decidedAt: null,
    rejectReason: null,
  },
};

describe("D386 strings", () => {
  it("has every string in both languages, merged into the dictionaries", () => {
    expect(Object.keys(EN_D386).sort()).toEqual(Object.keys(AR_D386).sort());
    for (const k of Object.keys(AR_D386) as (keyof typeof AR_D386)[]) {
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D386[k]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D386[k]);
    }
  });

  it("names all 24 categories", () => {
    for (const c of CATEGORIES) {
      expect(AR_D386[`cat${c}` as keyof typeof AR_D386], c).toBeTruthy();
      expect(EN_D386[`cat${c}` as keyof typeof EN_D386], c).toBeTruthy();
    }
    expect(AR_D386.catQURAN_RECITER).toBe("قارئ قرآن");
    expect(EN_D386.catSTORYTELLER).toBe("Storyteller");
  });

  it("lists «طلبات توثيق الفئة» under the users group for users.control_view", () => {
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === "/category-requests");
    expect(item?.cap).toBe("users.control_view");
  });
});

describe("D386 the user page's category block", () => {
  it("offers only the actions that change something", () => {
    expect(categoryActions(BASE)).toEqual(["VERIFY", "CLEAR", "LOCK"]);
    expect(categoryActions({ ...BASE, verified: true, locked: true })).toEqual(["UNVERIFY", "CLEAR", "UNLOCK"]);
    expect(categoryActions({ ...BASE, category: null, request: null })).toEqual(["LOCK"]);
  });

  it("shows the category, its state and the latest request (ar and en)", () => {
    const ar = wrap("ar", <UserCategoryView state={BASE} onAction={noop} />);
    expect(ar).toContain("قارئ قرآن");
    expect(ar).toContain("غير موثّقة");
    expect(ar).toContain("آخر طلب");
    expect(ar).toContain('data-category-action="VERIFY"');
    expect(ar).toContain("توثيق الفئة");
    const verified = wrap(
      "en",
      <UserCategoryView
        state={{
          ...BASE,
          verified: true,
          verifiedAt: "2026-11-12T11:00:00.000Z",
          verifiedBy: { id: "s1", username: "staff1", displayName: "Staff", avatarUrl: null },
          locked: true,
          lockedAt: "2026-11-12T11:00:00.000Z",
        }}
        onAction={noop}
      />,
    );
    expect(verified).toContain("✓ Verified");
    expect(verified).toContain('data-category-locked="true"');
    expect(verified).toContain("@staff1");
    expect(verified).toContain('data-category-action="UNLOCK"');
    expect(verified).not.toContain('data-category-action="VERIFY"');
  });

  it("notes a Kabso Team account, and hides the actions without users.profile_edit", () => {
    const team = wrap("ar", <UserCategoryView state={{ ...BASE, kabsoTeam: true }} onAction={noop} />);
    expect(team).toContain("حساب فريق كابسو");
    const finance = wrap("en", <UserCategoryView state={BASE} onAction={noop} />, "FINANCE");
    expect(finance).toContain("Quran reciter");
    expect(finance).not.toContain("data-category-action");
  });
});
