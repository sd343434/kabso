/**
 * D283c «الموظفون والصلاحيات»: each card shows the official staff ID «Kabso01», the staff list is searched by it (or the
 * name, username, email), and the next steps after a grant name it. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D283C, EN_D283C } from "../src/i18n-d283c";
import { matchesStaffQuery, MemberCard, NextSteps, type Member } from "../src/pages/Team";

const SELF = "11111111-1111-4111-8111-111111111111";
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: SELF, email: "owner@kabso.test", username: "owner", displayName: "المالك" },
    roles: ["OWNER"],
    capabilities: ["team.manage"],
    csrfToken: "csrf",
    expiresAt: "2026-11-05T20:00:00.000Z",
    idleSeconds: 1800,
  },
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const member = (over: Partial<Member> = {}): Member => ({
  id: "22222222-2222-4222-8222-222222222222",
  email: "sara@kabso.test",
  username: "sara_mod",
  displayName: "سارة",
  avatarUrl: null,
  status: "ACTIVE",
  roles: ["MODERATION"],
  totpEnrolled: true,
  lockedUntil: null,
  lastSignInAt: "2026-11-05T09:00:00.000Z",
  onShift: false,
  shiftSince: null,
  regions: [],
  staffId: "Kabso02",
  ...over,
});
const noop = () => undefined;

describe("D283c strings", () => {
  it("has every string in both languages, merged into the dictionaries", () => {
    expect(Object.keys(EN_D283C).sort()).toEqual(Object.keys(AR_D283C).sort());
    for (const k of Object.keys(AR_D283C) as (keyof typeof AR_D283C)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D283C[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D283C[k]);
    }
  });
});

describe("D283c the staff ID on the cards", () => {
  it("shows «ID: Kabso02» beside the @username (ar / en)", () => {
    for (const lang of ["ar", "en"] as const) {
      const out = html(lang, <MemberCard m={member()} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />);
      expect(out).toContain('data-staff-id="Kabso02"');
      expect(out).toContain("ID: Kabso02");
      expect(out).toContain("@sara_mod");
    }
    expect(
      html("ar", <MemberCard m={member()} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />),
    ).toContain("رقم الموظف الرسمي");
  });

  it("D283d: the primary OWNER's plain «ID: Kabso»", () => {
    const owner = member({ roles: ["OWNER"], staffId: "Kabso", username: "kabso.owner" });
    const out = html("ar", <MemberCard m={owner} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />);
    expect(out).toContain('data-staff-id="Kabso"');
    expect(out).toContain("ID: Kabso<");
  });

  it("an older API (no staffId) or a null one shows no badge", () => {
    for (const staffId of [undefined, null]) {
      const out = html("en", <MemberCard m={member({ staffId })} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />);
      expect(out).not.toContain("data-staff-id");
    }
  });

  it("the next steps after a grant name the staff ID", () => {
    const result = {
      userId: "22222222-2222-4222-8222-222222222222",
      role: "SUPPORT" as const,
      madeAdmin: true,
      already: false,
      staffId: "Kabso07",
      account: { email: "n@kabso.test", username: "new_one", displayName: "New", totpEnrolled: false },
    };
    const ar = html("ar", <NextSteps result={result} origin="https://admin.kabso.test" onClose={noop} />);
    expect(ar).toContain('data-staff-id="Kabso07"');
    expect(ar).toContain("رقم الموظف: Kabso07");
    const en = html("en", <NextSteps result={result} origin="https://admin.kabso.test" onClose={noop} />);
    expect(en).toContain("Staff ID: Kabso07 — shown in the app instead of the username.");
  });
});

describe("D283c the staff list search", () => {
  const sara = member();
  const omar = member({
    id: "33333333-3333-4333-8333-333333333333",
    username: "omar.support",
    displayName: "Omar",
    email: "omar@kabso.test",
    staffId: "Kabso100",
  });
  const legacy = member({ staffId: null, username: "old_one", displayName: "Old", email: "old@kabso.test" });

  it("finds by staff ID in any case, without the prefix or the leading zero", () => {
    for (const q of ["Kabso02", "kabso02", "KABSO2", "kabso", "02", "2", " @Kabso02 "]) {
      expect(matchesStaffQuery(sara, q), q).toBe(true);
    }
    expect(matchesStaffQuery(omar, "kabso100")).toBe(true);
    expect(matchesStaffQuery(omar, "100")).toBe(true);
    expect(matchesStaffQuery(sara, "Kabso03")).toBe(false);
    expect(matchesStaffQuery(omar, "Kabso02")).toBe(false);
    // D283d: «Kabso» is the primary OWNER's own ID (and the prefix of every staff ID).
    const owner = member({ roles: ["OWNER"], staffId: "Kabso", username: "kabso.owner" });
    expect(matchesStaffQuery(owner, "Kabso")).toBe(true);
    expect(matchesStaffQuery(owner, "@kabso")).toBe(true);
    expect(matchesStaffQuery(owner, "Kabso01")).toBe(false);
    expect(matchesStaffQuery(owner, "1")).toBe(false);
  });

  it("finds by name, username (@ optional) or email; an empty query shows everyone", () => {
    expect(matchesStaffQuery(omar, "omar")).toBe(true);
    expect(matchesStaffQuery(omar, "@omar.sup")).toBe(true);
    expect(matchesStaffQuery(omar, "OMAR@KABSO")).toBe(true);
    expect(matchesStaffQuery(sara, "سارة")).toBe(true);
    expect(matchesStaffQuery(legacy, "old")).toBe(true);
    expect(matchesStaffQuery(legacy, "kabso01")).toBe(false);
    for (const m of [sara, omar, legacy]) expect(matchesStaffQuery(m, "  ")).toBe(true);
  });
});
