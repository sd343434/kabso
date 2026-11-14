/**
 * D288 (owner: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله»): the shared report queue — «تم حله» for
 * OWNER, MODERATION and SUPPORT (the target actions stay with the moderators), who resolved it and when, the OWNER's
 * reopen, the nav badge (hidden at 0, «99+»), the second press. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { ApiError } from "../src/api";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D288, EN_D288 } from "../src/i18n-d288";
import { NAV } from "../src/nav";
import {
  badgeText,
  isAlreadyResolved,
  REPORT_TABS,
  ReportCard,
  resolveBody,
} from "../src/pages/Reports";
import type { Capability, PanelReport, PanelRole } from "../src/types";
import { NavCount } from "../src/ui/Shell";
import { CAPABILITY_ROLES } from "./capabilities";

const roleCan = (role: PanelRole) => (c: Capability) =>
  (CAPABILITY_ROLES[c] ?? []).includes(role);
const state = (lang: Lang, can: (c: Capability) => boolean): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can,
  toast: () => undefined,
});
const html = (lang: Lang, role: PanelRole, node: React.ReactNode) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, roleCan(role))}>{node}</AppContext.Provider>,
  );
const noop = () => undefined;
const card = (r: PanelReport) => (
  <ReportCard r={r} busy={false} onQuick={noop} onAct={noop} onResolve={noop} onReopen={noop} />
);

const open: PanelReport = {
  id: "0192f1d0-2222-7aaa-8bbb-0c0d0e0f1011",
  targetType: "POST",
  targetId: "0192f1d0-3333-7aaa-8bbb-0c0d0e0f1011",
  reason: "SPAM",
  note: null,
  status: "OPEN",
  createdAt: "2026-11-06T10:00:00.000Z",
  resolvedAt: null,
  resolvedBy: null,
  resolutionNote: null,
  reporter: { id: "r1", username: "reader01", displayName: "Reader", avatarUrl: null },
  preview: {
    text: "spam link",
    mediaUrl: null,
    author: { id: "a1", username: "author01", displayName: "Author", status: "ACTIVE" },
    gone: false,
  },
};
const resolved: PanelReport = {
  ...open,
  id: "0192f1d0-4444-7aaa-8bbb-0c0d0e0f1011",
  status: "ACTIONED",
  resolvedAt: "2026-11-06T11:00:00.000Z",
  resolvedBy: { id: "s1", username: "support01", displayName: "سارة" },
  resolutionNote: "تواصلت مع الكاتب",
};

describe("D288 the shared report queue", () => {
  it("SUPPORT sees «تم حله» but no action on the target; MODERATION sees both", () => {
    const support = html("ar", "SUPPORT", card(open));
    expect(support).toContain(AR_D288.repResolve);
    expect(support).not.toContain(translate("ar", "dismiss"));
    expect(support).not.toContain(translate("ar", "banAuthor"));
    const mod = html("ar", "MODERATION", card(open));
    expect(mod).toContain(AR_D288.repResolve);
    expect(mod).toContain(translate("ar", "dismiss"));
    expect(mod).toContain(translate("ar", "banAuthor"));
    // FINANCE has no `reports.resolve`: no buttons at all.
    expect(html("ar", "FINANCE", card(open))).not.toContain(AR_D288.repResolve);
  });

  it("a resolved report says who resolved it and when, with the note; no «تم حله» again", () => {
    const ar = html("ar", "MODERATION", card(resolved));
    expect(ar).toContain("حلّه سارة");
    expect(ar).toContain("تواصلت مع الكاتب");
    expect(ar).toContain('data-resolved-by="s1"');
    expect(ar).toContain(AR_D288.repOutcomeACTIONED);
    expect(ar).not.toContain(`>${AR_D288.repResolve}</button>`);
    const en = html("en", "SUPPORT", card(resolved));
    expect(en).toContain("Resolved by سارة");
    expect(en).toContain(EN_D288.repResolutionNote);
  });

  it("OWNER and MODERATION can reopen; SUPPORT cannot (owner: option B)", () => {
    expect(html("ar", "OWNER", card(resolved))).toContain(AR_D288.repReopen);
    expect(html("ar", "MODERATION", card(resolved))).toContain(AR_D288.repReopen);
    expect(html("ar", "SUPPORT", card(resolved))).not.toContain(AR_D288.repReopen);
  });

  it("the tabs, the note body and the second press", () => {
    expect(REPORT_TABS).toEqual(["OPEN", "RESOLVED"]);
    expect(resolveBody(undefined)).toEqual({});
    expect(resolveBody("   ")).toEqual({});
    expect(resolveBody(" checked ")).toEqual({ note: "checked" });
    expect(
      isAlreadyResolved(new ApiError(409, "REPORT_ALREADY_RESOLVED", "The report was already resolved.")),
    ).toBe(true);
    expect(isAlreadyResolved(new ApiError(409, "ADMIN_ACTION_REFUSED", "x"))).toBe(false);
  });

  it("the nav badge: hidden at 0, the number, «99+» above 99, at the row's logical end", () => {
    expect(badgeText(0)).toBeNull();
    expect(badgeText(-1)).toBeNull();
    expect(badgeText(7)).toBe("7");
    expect(badgeText(99)).toBe("99");
    expect(badgeText(100)).toBe("99+");
    expect(html("ar", "SUPPORT", <NavCount count={0} />)).toBe("");
    expect(html("ar", "SUPPORT", <NavCount count={null} />)).toBe("");
    const ar = html("ar", "SUPPORT", <NavCount count={150} />);
    expect(ar).toContain(">99+<");
    expect(ar).toContain('class="nav-count"');
    expect(ar).toContain('aria-label="150 بلاغ غير محلول"');
    expect(html("en", "SUPPORT", <NavCount count={3} />)).toContain('aria-label="3 unresolved reports"');
  });

  it("«البلاغات» is in SUPPORT's nav now (reports.view)", () => {
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === "/reports")!;
    expect(item.cap).toBe("reports.view");
    expect(roleCan("SUPPORT")(item.cap)).toBe(true);
    expect(roleCan("FINANCE")(item.cap)).toBe(false);
  });

  it("every D288 string exists in both languages", () => {
    for (const key of Object.keys(AR_D288) as (keyof typeof AR_D288)[]) {
      expect(DICTIONARIES.ar[key]).toBe(AR_D288[key]);
      expect(DICTIONARIES.en[key]).toBe(EN_D288[key]);
      expect(EN_D288[key].length).toBeGreaterThan(0);
    }
  });
});
