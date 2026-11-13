/**
 * D271 «الموظفون والصلاحيات» (OWNER): the staff cards (username, email, roles, authenticator, last sign-in, shift), the
 * roles the OWNER may take (never their own OWNER, never the last OWNER's), the grant dialog (email or username, the
 * OWNER warning, the step-up code), the next steps after a grant, the request bodies, and the rules' refusals in the
 * panel's words. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError } from "../src/api";
import { AppContext, type AppState } from "../src/context";
import { errorKey } from "../src/errors";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D271, EN_D271 } from "../src/i18n-d271";
import {
  grantStaff,
  GrantDialog,
  MemberCard,
  NextSteps,
  resetStaff2fa,
  revocableRoles,
  revokeStaff,
  type Member,
} from "../src/pages/Team";
import { CAPABILITY_ROLES } from "./capabilities";

const SELF = "11111111-1111-4111-8111-111111111111";
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: SELF, email: "owner@kabso.test", username: "owner", displayName: "المالك" },
    roles: ["OWNER"],
    capabilities: ["team.manage"],
    csrfToken: "csrf",
    expiresAt: "2026-11-04T20:00:00.000Z",
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
  lastSignInAt: "2026-11-04T09:00:00.000Z",
  onShift: true,
  shiftSince: "2026-11-04T10:00:00.000Z",
  ...over,
});
const noop = () => undefined;

describe("D271 strings", () => {
  it("has every string in both languages; the page and menu are «الموظفون والصلاحيات»", () => {
    expect(Object.keys(EN_D271).sort()).toEqual(Object.keys(AR_D271).sort());
    for (const k of Object.keys(AR_D271) as (keyof typeof AR_D271)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D271[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D271[k]);
    }
    expect(DICTIONARIES.ar.navTeam).toBe("الموظفون والصلاحيات");
    expect(DICTIONARIES.en.navTeam).toBe("Staff & permissions");
    expect(CAPABILITY_ROLES["team.manage"]).toEqual(["OWNER"]);
  });
});

describe("D271 the staff cards", () => {
  it("name, @username, email, roles, authenticator, last sign-in and the shift", () => {
    const ar = html("ar", <MemberCard m={member()} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />);
    expect(ar).toContain("سارة");
    expect(ar).toContain("@sara_mod");
    expect(ar).toContain("sara@kabso.test");
    // v1.139-social (D387): MODERATION is shown as TRUST_SAFETY «مراقبة المحتوى والأمان».
    expect(ar).toContain("مراقبة المحتوى والأمان");
    expect(ar).toContain("مفعّلة");
    expect(ar).toContain('data-on-shift="true"');
    expect(ar).toContain("في المناوبة");
    expect(ar).toContain("سحب دور");
    expect(ar).toContain("إعادة ضبط المصادقة");
    const en = html(
      "en",
      <MemberCard
        m={member({ onShift: false, shiftSince: null, totpEnrolled: false })}
        selfId={SELF}
        activeOwners={1}
        onRevoke={noop}
        onReset={noop}
      />,
    );
    expect(en).toContain("Off shift");
    expect(en).toContain("Not set up yet");
    // Nothing to reset before the authenticator is set up.
    expect(en).not.toContain("Reset authenticator");
    // FINANCE has no shift.
    expect(
      html("en", <MemberCard m={member({ roles: ["FINANCE"], onShift: false })} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />),
    ).toContain("No shift for this role");
    // An older API without the shift: no row.
    expect(
      html("en", <MemberCard m={member({ onShift: undefined })} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} />),
    ).not.toContain("Shift");
  });

  it("never one's own OWNER, never the last active OWNER; one's own authenticator is not reset here", () => {
    const me = member({ id: SELF, roles: ["OWNER"] });
    expect(revocableRoles(me, SELF, 2)).toEqual([]);
    const meOut = html("ar", <MemberCard m={me} selfId={SELF} activeOwners={2} onRevoke={noop} onReset={noop} />);
    expect(meOut).toContain("أنت");
    expect(meOut).not.toContain("سحب دور");
    expect(meOut).not.toContain("إعادة ضبط المصادقة");
    // My extra role may go, not my OWNER.
    expect(revocableRoles(member({ id: SELF, roles: ["OWNER", "SUPPORT"] }), SELF, 2)).toEqual(["SUPPORT"]);
    // Another OWNER: only while another active OWNER remains.
    const other = member({ roles: ["OWNER", "MODERATION"] });
    expect(revocableRoles(other, SELF, 2)).toEqual(["OWNER", "MODERATION"]);
    expect(revocableRoles(other, SELF, 1)).toEqual(["MODERATION"]);
    // A banned OWNER does not count and may lose the role.
    expect(revocableRoles(member({ roles: ["OWNER"], status: "SUSPENDED" }), SELF, 1)).toEqual(["OWNER"]);
  });
});

describe("D271 granting", () => {
  it("the dialog asks for an email or username, a reason and a fresh code", () => {
    const ar = html("ar", <GrantDialog onClose={noop} onDone={noop} />);
    expect(ar).toContain("البريد أو اسم المستخدم");
    expect(ar).toContain("رمز تطبيق المصادقة");
    expect(ar).toContain(AR_D271.staffCodeHint);
    expect(ar).toContain("السبب");
    expect(ar).toContain("one-time-code");
    // SUPPORT is the default choice; the OWNER warning appears only for OWNER.
    expect(ar).not.toContain("data-owner-warning");
    expect(ar).toMatch(/aria-pressed="true"[^>]*>دعم</);
  });

  it("the next steps: sign in at the panel, enrol the authenticator, go on shift", () => {
    const res = {
      userId: "u1",
      role: "MODERATION" as const,
      madeAdmin: true,
      already: false,
      account: { email: "new@kabso.test", username: "new_mod", displayName: "Omar", totpEnrolled: false },
    };
    const ar = html("ar", <NextSteps result={res} origin="https://admin.kabsolive.com" onClose={noop} />);
    expect(ar).toContain("أُضيف Omar — الخطوات التالية");
    expect(ar).toContain("https://admin.kabsolive.com");
    expect(ar).toContain("new@kabso.test");
    expect(ar).toContain("تطبيق المصادقة (Google Authenticator");
    expect(ar).toContain("«في المناوبة»");
    const en = html(
      "en",
      <NextSteps
        result={{ ...res, role: "FINANCE", account: { ...res.account, totpEnrolled: true } }}
        origin="https://admin.kabsolive.com"
        onClose={noop}
      />,
    );
    expect(en).toContain("Sign in at https://admin.kabsolive.com");
    expect(en).toContain("already set up");
    expect(en).toContain("Finance has no shift");
    expect(en).not.toContain("On shift");
    const again = html("en", <NextSteps result={{ ...res, already: true }} origin="https://x" onClose={noop} />);
    expect(again).toContain("already holds this role");
    expect(again).not.toContain("Sign in at");
  });
});

describe("D271 requests and refusals", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("each change sends the reason and the code to its route", async () => {
    const calls: { url: string; body: unknown; csrf: string | null }[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string, init: RequestInit) => {
        calls.push({
          url,
          body: JSON.parse(String(init.body)),
          csrf: new Headers(init.headers).get("X-CSRF-Token"),
        });
        return Promise.resolve(new Response(JSON.stringify({}), { status: 200 }));
      }),
    );
    await grantStaff("@new_mod", "MODERATION", "hired", "123456");
    await revokeStaff("u1", "SUPPORT", "left", "654321");
    await resetStaff2fa("u1", "lost phone", "111222");
    expect(calls.map((c) => [c.url, c.body])).toEqual([
      ["/api/v1/admin/team/grant", { account: "@new_mod", role: "MODERATION", reason: "hired", totpCode: "123456" }],
      ["/api/v1/admin/team/u1/revoke", { role: "SUPPORT", reason: "left", totpCode: "654321" }],
      ["/api/v1/admin/team/u1/reset-2fa", { reason: "lost phone", totpCode: "111222" }],
    ]);
  });

  it("the rules' refusals and a wrong code are worded by the panel", () => {
    const refusal = (issue: string) =>
      errorKey(new ApiError(409, "ADMIN_ACTION_REFUSED", "x", null, [{ field: "rule", issue }])).key;
    expect(refusal("team_last_owner")).toBe("teamErrLastOwner");
    expect(refusal("team_self_owner")).toBe("teamErrSelfOwner");
    expect(refusal("team_no_account")).toBe("teamErrNoAccount");
    expect(refusal("team_not_active")).toBe("teamErrNotActive");
    expect(refusal("team_locked")).toBe("teamErrLocked");
    expect(refusal("team_not_held")).toBe("teamErrNotHeld");
    expect(refusal("team_self_reset")).toBe("teamErrSelfReset");
    expect(refusal("team_not_member")).toBe("teamErrNotMember");
    expect(errorKey(new ApiError(403, "ADMIN_TOTP_INVALID", "x")).key).toBe("errTotp");
    expect(errorKey(new ApiError(429, "RATE_LIMITED", "x")).key).toBe("errRateLimited");
    expect(translate("ar", "teamErrLastOwner")).toContain("آخر مالك");
  });
});
