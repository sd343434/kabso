/**
 * D260 staff presence in lives: the shift switch «في المناوبة», «بثوثي», the OWNER's list of who is on shift, a card's
 * watcher and «فريق كابسو» count, the watch view's visible / hidden mode per role, and what the watch token asks for.
 * Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D260, EN_D260 } from "../src/i18n-d260";
import { PreviewPool, watchToken } from "../src/live-media";
import { LiveCard, type LiveRow } from "../src/pages/Lives";
import { WatchMode } from "../src/pages/LiveWatch";
import {
  MineTab,
  ShiftsPanel,
  ShiftSwitch,
  type ShiftList,
} from "../src/pages/StaffShifts";
import type { Capability, PanelRole } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const state = (
  lang: Lang,
  can: (c: Capability) => boolean = () => true,
): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can,
  toast: () => undefined,
});
const roleCan = (role: PanelRole) => (c: Capability) =>
  (CAPABILITY_ROLES[c] ?? []).includes(role);
const html = (
  lang: Lang,
  node: React.ReactNode,
  can?: (c: Capability) => boolean,
) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, can)}>{node}</AppContext.Provider>,
  );

const live: LiveRow = {
  id: "0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011",
  title: "سهرة",
  mode: "SOLO",
  viewers: 42,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: {
    id: "h1",
    username: "coin0001",
    displayName: "jgjg",
    avatarUrl: null,
  },
  pk: null,
  openReports: 0,
};

describe("D260 strings", () => {
  it("has every string in both languages", () => {
    expect(Object.keys(EN_D260).sort()).toEqual(Object.keys(AR_D260).sort());
    for (const k of Object.keys(AR_D260) as (keyof typeof AR_D260)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D260[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D260[k]);
    }
    expect(AR_D260.kabsoTeam).toBe("فريق كابسو");
    expect(EN_D260.kabsoTeam).toBe("Kabso Team");
  });
});

describe("D260 the shift and «بثوثي»", () => {
  it("the switch shows off / on with my lives", () => {
    const off = html(
      "ar",
      <ShiftSwitch
        shift={{ onShift: false, since: null, assignedLives: 0 }}
        onChange={() => undefined}
      />,
    );
    expect(off).toContain('data-on-shift="false"');
    expect(off).toContain("خارج المناوبة");
    expect(off).not.toContain('checked=""');
    expect(off).not.toContain("مسند إليك");
    const on = html(
      "ar",
      <ShiftSwitch
        shift={{
          onShift: true,
          since: "2026-11-04T10:00:00.000Z",
          assignedLives: 3,
        }}
        onChange={() => undefined}
      />,
    );
    expect(on).toContain('data-on-shift="true"');
    expect(on).toContain("في المناوبة");
    expect(on).toContain('checked=""');
    expect(on).toContain("3 بث مسند إليك");
    const en = html(
      "en",
      <ShiftSwitch
        shift={{ onShift: true, since: null, assignedLives: 2 }}
        onChange={() => undefined}
      />,
    );
    expect(en).toContain("On shift");
    expect(en).toContain("2 lives assigned to you");
    // Until the shift loads, the switch waits.
    expect(
      html("en", <ShiftSwitch shift={null} onChange={() => undefined} />),
    ).toContain('disabled=""');
  });

  it("«بثوثي» chip with my count", () => {
    const out = html(
      "ar",
      <MineTab pressed count={4} onClick={() => undefined} />,
    );
    expect(out).toContain("بثوثي");
    expect(out).toContain('aria-pressed="true"');
    expect(out).toContain(">4<");
    expect(
      html(
        "en",
        <MineTab pressed={false} count={0} onClick={() => undefined} />,
      ),
    ).not.toContain("count-pill");
  });

  it("OWNER: who is on shift, their load, and the lives nobody watches", () => {
    const list: ShiftList = {
      onShift: 1,
      unassignedLives: 2,
      data: [
        {
          user: {
            id: "a1",
            username: "mod_one",
            displayName: "سارة",
            avatarUrl: null,
          },
          roles: ["MODERATION"],
          onShift: true,
          since: "2026-11-04T10:00:00.000Z",
          assignedLives: 5,
        },
        {
          user: {
            id: "a2",
            username: "help_two",
            displayName: "Omar",
            avatarUrl: null,
          },
          roles: ["SUPPORT"],
          onShift: false,
          since: null,
          assignedLives: 0,
        },
      ],
    };
    const ar = html("ar", <ShiftsPanel list={list} />);
    expect(ar).toContain("من في المناوبة");
    expect(ar).toContain("1 في المناوبة");
    expect(ar).toContain('data-unassigned="2"');
    expect(ar).toContain("2 بث بلا مراقب");
    expect(ar.match(/data-on-shift="true"/g)).toHaveLength(1);
    expect(ar).toContain("@mod_one");
    expect(
      html(
        "en",
        <ShiftsPanel list={{ ...list, onShift: 0, unassignedLives: 0 }} />,
      ),
    ).toContain("Nobody is on shift — new lives wait.");
  });

  it("a card shows who watches it and the «فريق كابسو» in it", () => {
    const pool = new PreviewPool();
    const mine = html(
      "ar",
      <LiveCard
        live={{
          ...live,
          assignedTo: { id: "a1", displayName: "سارة" },
          staffWatching: 1,
        }}
        pool={pool}
        onOpen={() => undefined}
      />,
    );
    expect(mine).toContain('data-assigned="a1"');
    expect(mine).toContain("المراقب: سارة");
    expect(mine).toContain("1 من فريق كابسو");
    const none = html(
      "en",
      <LiveCard
        live={{ ...live, assignedTo: null, staffWatching: 0 }}
        pool={pool}
        onOpen={() => undefined}
      />,
    );
    expect(none).toContain('data-assigned="none"');
    expect(none).toContain("Nobody watching");
    expect(none).not.toContain("team-badge");
    // An older API without the fields: no line at all.
    expect(
      html("en", <LiveCard live={live} pool={pool} onOpen={() => undefined} />),
    ).not.toContain("data-assigned");
  });
});

describe("D260 the watch view: visible «فريق كابسو» by default, hidden for OWNER / MODERATION", () => {
  it("SUPPORT watches visibly and has no hidden switch", () => {
    const out = html(
      "ar",
      <WatchMode hidden={false} onHidden={() => undefined} />,
      roleCan("SUPPORT"),
    );
    expect(out).toContain('data-watch-mode="VISIBLE"');
    expect(out).toContain("فريق كابسو");
    expect(out).not.toContain("مراقبة خفية");
    // Even if asked, SUPPORT stays visible.
    expect(
      html(
        "ar",
        <WatchMode hidden onHidden={() => undefined} />,
        roleCan("SUPPORT"),
      ),
    ).toContain('data-watch-mode="VISIBLE"');
  });

  it("MODERATION may switch to hidden", () => {
    const visible = html(
      "en",
      <WatchMode hidden={false} onHidden={() => undefined} />,
      roleCan("MODERATION"),
    );
    expect(visible).toContain('data-watch-mode="VISIBLE"');
    expect(visible).toContain("Kabso Team");
    expect(visible).toContain("Hidden watch");
    const hidden = html(
      "ar",
      <WatchMode hidden onHidden={() => undefined} />,
      roleCan("MODERATION"),
    );
    expect(hidden).toContain('data-watch-mode="HIDDEN"');
    expect(hidden).toContain("أنت مراقب مخفي");
    expect(roleCan("OWNER")("lives.watch.hidden")).toBe(true);
    expect(roleCan("FINANCE")("lives.watch")).toBe(false);
    expect(roleCan("OWNER")("staff.shifts")).toBe(true);
    expect(roleCan("MODERATION")("staff.shifts")).toBe(false);
  });

  afterEach(() => vi.unstubAllGlobals());

  it("the watch token asks for the visibility; a preview asks for none", async () => {
    const bodies: unknown[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn((_url: string, init: RequestInit) => {
        bodies.push(JSON.parse(String(init.body)));
        return Promise.resolve(
          new Response(
            JSON.stringify({ purpose: "WATCH", main: {}, opponent: null }),
            { status: 200 },
          ),
        );
      }),
    );
    await watchToken(live.id, "WATCH", "HIDDEN");
    await watchToken(live.id, "WATCH", "VISIBLE");
    await watchToken(live.id, "PREVIEW");
    expect(bodies).toEqual([
      { purpose: "WATCH", visibility: "HIDDEN" },
      { purpose: "WATCH", visibility: "VISIBLE" },
      { purpose: "PREVIEW" },
    ]);
  });
});
