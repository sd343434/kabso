/**
 * D283 «تجزئة الإشراف»: the staff regions in «الموظفون والصلاحيات» (OWNER) — a MODERATION / SUPPORT card shows its
 * regions and «المناطق», FINANCE / an OWNER-only card neither; the regions dialog lists the 13 regions as checkboxes;
 * the request sends the whole set with the reason and the code; the refusal `team_regions_role` is worded by the panel.
 * «البث الآن»: the region filter (all, mine, each region) and the card's region badge. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError } from "../src/api";
import { AppContext, type AppState } from "../src/context";
import { errorKey } from "../src/errors";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D283, EN_D283, STAFF_REGIONS } from "../src/i18n-d283";
import { LiveCard, RegionFilter, type LiveRow } from "../src/pages/Lives";
import { MemberCard, RegionsDialog, setStaffRegions, type Member } from "../src/pages/Team";

const SELF = "11111111-1111-4111-8111-111111111111";
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: SELF, email: "owner@kabso.test", username: "owner", displayName: "المالك" },
    roles: ["OWNER"],
    capabilities: ["team.manage", "lives.watch"],
    csrfToken: "csrf",
    expiresAt: "2026-11-05T20:00:00.000Z",
    idleSeconds: 1800,
  },
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);
const noop = () => undefined;

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
  regions: ["ARAB_WORLD", "TURKEY"],
  ...over,
});

const live: LiveRow = {
  id: "0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011",
  title: "سهرة",
  mode: "SOLO",
  viewers: 12,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: { id: "u1", username: "host0", displayName: "Host", avatarUrl: null },
  pk: null,
  hostCountry: "SA",
  region: "ARAB_WORLD",
};

describe("D283 strings", () => {
  it("every string in both languages; the 13 regions named", () => {
    expect(Object.keys(EN_D283).sort()).toEqual(Object.keys(AR_D283).sort());
    for (const k of Object.keys(AR_D283) as (keyof typeof AR_D283)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D283[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D283[k]);
    }
    expect(STAFF_REGIONS).toHaveLength(13);
    for (const r of STAFF_REGIONS) {
      expect(translate("ar", `region${r}` as never)).not.toBe(`region${r}`);
      expect(translate("en", `region${r}` as never)).not.toBe(`region${r}`);
    }
    expect(translate("ar", "regionARAB_WORLD")).toBe("الوطن العربي");
  });
});

describe("D283 the staff card's regions", () => {
  it("a moderator: the regions and «المناطق»; none: assigned by load", () => {
    const ar = html("ar", <MemberCard m={member()} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} onRegions={noop} />);
    expect(ar).toContain('data-regions="ARAB_WORLD,TURKEY"');
    expect(ar).toContain("الوطن العربي");
    expect(ar).toContain("تركيا");
    expect(ar).toContain("data-edit-regions");
    const en = html("en", <MemberCard m={member({ regions: [], roles: ["SUPPORT"] })} selfId={SELF} activeOwners={1} onRevoke={noop} onReset={noop} onRegions={noop} />);
    expect(en).toContain("No region — assigned by load");
    expect(en).toContain(">Regions<");
  });

  it("FINANCE, an OWNER-only account and an older API: no regions", () => {
    for (const m of [member({ roles: ["FINANCE"] }), member({ roles: ["OWNER"] }), member({ regions: undefined })]) {
      const out = html("en", <MemberCard m={m} selfId={SELF} activeOwners={2} onRevoke={noop} onReset={noop} onRegions={noop} />);
      expect(out).not.toContain("data-regions");
      expect(out).not.toContain("data-edit-regions");
    }
  });

  it("the dialog: 13 checkboxes in the catalogue's order, the picked ones checked, the reason and the code", () => {
    const out = html("ar", <RegionsDialog member={member()} onClose={noop} onDone={noop} />);
    const order = [...out.matchAll(/data-region="([A-Z_]+)"/g)].map((m) => m[1]);
    expect(order).toEqual([...STAFF_REGIONS]);
    expect((out.match(/checked=""/g) ?? []).length).toBe(2);
    expect(out).toContain("مناطق سارة");
    expect(out).toContain("رمز");
  });
});

describe("D283 requests and refusals", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("sends the whole set with the reason and the code (PUT, CSRF)", async () => {
    const calls: { url: string; method: string | undefined; body: unknown; csrf: string | null }[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string, init: RequestInit) => {
        calls.push({ url, method: init.method, body: JSON.parse(String(init.body)), csrf: new Headers(init.headers).get("X-CSRF-Token") });
        return Promise.resolve(new Response(JSON.stringify({ userId: "u1", regions: ["EUROPE"], before: [] }), { status: 200 }));
      }),
    );
    await setStaffRegions("u1", ["EUROPE"], "covers EU", "123456");
    expect(calls.map((c) => [c.method, c.url, c.body])).toEqual([
      ["PUT", "/api/v1/admin/team/u1/regions", { regions: ["EUROPE"], reason: "covers EU", totpCode: "123456" }],
    ]);
  });

  it("the regions refusal is worded by the panel", () => {
    const key = errorKey(new ApiError(409, "ADMIN_ACTION_REFUSED", "x", null, [{ field: "rule", issue: "team_regions_role" }])).key;
    expect(key).toBe("teamErrRegionsRole");
    expect(translate("ar", "teamErrRegionsRole")).toContain("الإشراف والدعم");
  });
});

describe("D283 «البث الآن» by region", () => {
  it("the filter: all, my regions (staff who watch) and each region", () => {
    const ar = html("ar", <RegionFilter value="" onChange={noop} mine />);
    expect(ar).toContain("كل المناطق");
    expect(ar).toContain("مناطقي");
    expect((ar.match(/<option/g) ?? []).length).toBe(15);
    const en = html("en", <RegionFilter value="EUROPE" onChange={noop} mine={false} />);
    expect(en).not.toContain("My regions");
    expect(en).toContain("Europe");
  });

  it("a card shows its host's region; none without one", () => {
    expect(html("ar", <LiveCard live={live} onOpen={noop} />)).toContain('data-live-region="ARAB_WORLD"');
    expect(html("en", <LiveCard live={{ ...live, region: null }} onOpen={noop} />)).not.toContain("data-live-region");
  });
});
