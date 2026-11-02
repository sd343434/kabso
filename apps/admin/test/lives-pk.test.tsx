/**
 * D241: «البث الآن» — a live in a PK (an open D195 match; the rooms stay SOLO) shows a «PK» badge and «ضد @handle»;
 * a live not in a PK shows neither. Both languages.
 */
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D241, EN_D241 } from "../src/i18n-d241";
import { LiveCard, type LiveRow } from "../src/pages/Lives";

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const render = (lang: Lang, live: LiveRow) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <LiveCard live={live} onOpen={() => undefined} />
    </AppContext.Provider>,
  );

const base: LiveRow = {
  id: "0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011",
  title: "jgjg",
  mode: "SOLO",
  viewers: 12,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: {
    id: "u1",
    username: "coin0001",
    displayName: "jgjg",
    avatarUrl: null,
  },
  pk: null,
};

describe("D241 lives in a PK in the panel", () => {
  it("has every string in both languages", () => {
    expect(Object.keys(EN_D241).sort()).toEqual(Object.keys(AR_D241).sort());
    for (const k of Object.keys(AR_D241)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D241]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D241]).toBeTruthy();
    }
  });

  it("a SOLO room in a battle: the PK badge and the opponent (ar, en)", () => {
    const live = {
      ...base,
      pk: {
        opponentRoomId: "0192f1d0-2222-7aaa-8bbb-0c0d0e0f1011",
        opponentUsername: "nabulsi301",
        opponentDisplayName: "khh",
      },
    };
    const ar = render("ar", live);
    expect(ar).toContain('data-live-pk="true"');
    expect(ar).toContain("pk-badge");
    expect(ar).toContain("ضد @nabulsi301");
    expect(render("en", live)).toContain("vs @nabulsi301");
  });

  it("a live not in a PK: no badge, no opponent", () => {
    const html = render("ar", base);
    expect(html).not.toContain("pk-badge");
    expect(html).not.toContain("ضد @");
  });

  it("a legacy mode PK room without a match: the badge, no opponent line", () => {
    const html = render("en", {
      ...base,
      mode: "PK",
      pk: {
        opponentRoomId: null,
        opponentUsername: null,
        opponentDisplayName: null,
      },
    });
    expect(html).toContain("pk-badge");
    expect(html).not.toContain("vs @");
  });
});
