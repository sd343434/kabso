/**
 * D385 (v1.137-social, CONVENTIONS §10.174.6): the in-app «دعم كابسو» threads in the panel's WhatsApp inbox — the
 * «داخل التطبيق» tag in the list, no 24-hour window, a composer without templates (pictures only, owner) and no unlink.
 * WhatsApp threads are unchanged. Both languages.
 */
import type { ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AppContext, type AppState } from "../src/context";
import { DICTIONARIES, translate, type Lang } from "../src/i18n";
import { AR_D385, EN_D385 } from "../src/i18n-d385";
import {
  WaComposer,
  WaConversationList,
  WaCustomerPanel,
  WindowBanner,
} from "../src/pages/WhatsApp";
import type { Capability, WaConversation } from "../src/types";
import { CAPABILITY_ROLES } from "./capabilities";

const OWNER_CAPS = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) =>
  CAPABILITY_ROLES[c]!.includes("OWNER"),
);
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => OWNER_CAPS.includes(c),
  toast: () => undefined,
});
const wrap = (lang: Lang, node: ReactNode) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>,
  );
const noop = () => undefined;

const WA: WaConversation = {
  id: "w1",
  phone: "+966512345678",
  name: "سارة",
  status: "OPEN",
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 1,
  lastMessageAt: "2026-11-12T10:00:00.000Z",
  lastPreview: "مرحبا",
  lastDirection: "INBOUND",
  window: { open: true, closesAt: "2026-11-13T10:00:00.000Z" },
  linkedAccount: null,
  closedAt: null,
  createdAt: "2026-11-12T09:00:00.000Z",
  department: "GENERAL",
  channel: "WHATSAPP",
};
const APP: WaConversation = {
  ...WA,
  id: "a1",
  phone: null,
  name: "ليلى",
  window: { open: true, closesAt: null },
  department: "PAYMENTS",
  channel: "IN_APP",
  linkedAccount: {
    userId: "u1",
    username: "layla",
    displayName: "ليلى",
    avatarUrl: null,
    status: "ACTIVE",
    countryCode: "SA",
    createdAt: "2026-01-01T00:00:00.000Z",
  },
};

describe("D385 strings", () => {
  it("has every string in both languages, merged into the dictionaries", () => {
    expect(Object.keys(EN_D385).sort()).toEqual(Object.keys(AR_D385).sort());
    for (const k of Object.keys(AR_D385) as (keyof typeof AR_D385)[]) {
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(
        AR_D385[k],
      );
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(
        EN_D385[k],
      );
    }
    expect(AR_D385.waInApp).toBe("داخل التطبيق");
  });
});

describe("D385 the in-app threads in the inbox", () => {
  it("the list marks only the in-app thread «داخل التطبيق»", () => {
    const html = wrap(
      "ar",
      <WaConversationList items={[APP, WA]} selected={null} onOpen={noop} />,
    );
    expect(html.match(/data-wa-in-app/g)).toHaveLength(1);
    expect(html).toContain("داخل التطبيق");
    expect(
      wrap(
        "en",
        <WaConversationList items={[APP]} selected={null} onOpen={noop} />,
      ),
    ).toContain("In app");
  });

  it("no window or template for an in-app thread, pictures only; WhatsApp unchanged", () => {
    expect(wrap("ar", <WindowBanner c={APP} />)).toContain(
      "data-wa-in-app-banner",
    );
    expect(wrap("ar", <WindowBanner c={WA} />)).not.toContain(
      "data-wa-in-app-banner",
    );
    const app = wrap("en", <WaComposer c={APP} onSent={noop} />);
    // Owner (2026-11-12): a picture yes (images only), a template never.
    expect(app).toContain('type="file"');
    expect(app).toContain('accept="image/jpeg,image/png,image/webp"');
    expect(app).not.toContain(translate("en", "waSendTemplate"));
    const wa = wrap("en", <WaComposer c={WA} onSent={noop} />);
    expect(wa).toContain('type="file"');
    expect(wa).toContain(translate("en", "waSendTemplate"));
  });

  it("the account of an in-app thread cannot be unlinked", () => {
    const panel = (c: WaConversation) =>
      wrap(
        "en",
        <WaCustomerPanel
          c={c}
          notes={[]}
          history={[]}
          onLink={noop}
          onUnlink={noop}
          onNote={noop}
        />,
      );
    expect(panel(APP)).not.toContain(translate("en", "waUnlink"));
    expect(panel({ ...WA, linkedAccount: APP.linkedAccount })).toContain(
      translate("en", "waUnlink"),
    );
  });
});
