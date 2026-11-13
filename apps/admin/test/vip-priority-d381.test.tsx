/**
 * D381 (v1.134-social, CONVENTIONS §10.171.3) PRIORITY_SUPPORT in the panel: the «أولوية VIP» badge on a holder's open
 * report and the «عاجل» badge on a safety report in the shared queue, and the badge on a holder's WhatsApp conversation
 * (the API lists them first). Both languages; nothing for an ordinary report or conversation.
 */
import type { ReactNode } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D381, EN_D381 } from '../src/i18n-d381';
import { ReportCard } from '../src/pages/Reports';
import { WaConversationList } from '../src/pages/WhatsApp';
import type { Capability, PanelReport, WaConversation } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const OWNER_CAPS = (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) =>
  CAPABILITY_ROLES[c]!.includes('OWNER'),
);
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => OWNER_CAPS.includes(c),
  toast: () => undefined,
});
const wrap = (lang: Lang, node: ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);
const noop = () => undefined;

const report = (priority: number | undefined, status: PanelReport['status'] = 'OPEN'): PanelReport => ({
  id: '0192f1d0-2222-7aaa-8bbb-0c0d0e0f1011',
  targetType: 'USER',
  targetId: 'someone',
  reason: priority === 2 ? 'NUDITY' : 'SPAM',
  note: null,
  status,
  createdAt: '2026-11-12T10:00:00.000Z',
  resolvedAt: status === 'OPEN' ? null : '2026-11-12T11:00:00.000Z',
  resolvedBy: null,
  resolutionNote: null,
  ...(priority !== undefined ? { priority } : {}),
  preview: { text: null, mediaUrl: null, author: null, gone: false },
});
const card = (lang: Lang, r: PanelReport) =>
  wrap(lang, <ReportCard r={r} busy={false} onQuick={noop} onAct={noop} onResolve={noop} onReopen={noop} />);

const CONV: WaConversation = {
  id: 'c1',
  phone: '+966512345678',
  name: 'سارة',
  status: 'OPEN',
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 1,
  lastMessageAt: '2026-11-12T10:00:00.000Z',
  lastPreview: 'مرحبا',
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: '2026-11-13T10:00:00.000Z' },
  linkedAccount: null,
  closedAt: null,
  createdAt: '2026-11-12T09:00:00.000Z',
  department: 'GENERAL',
};

describe('D381 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D381).sort()).toEqual(Object.keys(AR_D381).sort());
    for (const k of Object.keys(AR_D381) as (keyof typeof AR_D381)[]) {
      expect(DICTIONARIES.ar[k as keyof typeof DICTIONARIES.ar], k).toBe(AR_D381[k]);
      expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBe(EN_D381[k]);
    }
    expect(AR_D381.priorityVip).toBe('أولوية VIP');
  });
});

describe('D381 the shared report queue', () => {
  it('a holder\'s open report carries «أولوية VIP», a safety report «عاجل»', () => {
    const vip = card('ar', report(1));
    expect(vip).toContain('data-priority="1"');
    expect(vip).toContain('أولوية VIP');
    expect(card('en', report(1))).toContain('VIP priority');
    const safety = card('ar', report(2));
    expect(safety).toContain('data-priority="2"');
    expect(safety).toContain('عاجل');
  });

  it('nothing for an ordinary report, an older API (no priority) or a resolved one', () => {
    for (const r of [report(0), report(undefined), report(1, 'ACTIONED')]) {
      expect(card('ar', r)).not.toContain('data-priority');
    }
  });
});

describe('D381 the WhatsApp inbox', () => {
  it("a holder's conversation carries the badge; others do not", () => {
    const html = wrap(
      'ar',
      <WaConversationList items={[{ ...CONV, priority: true }, { ...CONV, id: 'c2', priority: false }]} selected={null} onOpen={noop} />,
    );
    expect(html.match(/data-wa-priority/g)).toHaveLength(1);
    expect(html).toContain('أولوية VIP');
    expect(wrap('en', <WaConversationList items={[{ ...CONV, priority: true }]} selected={null} onOpen={noop} />)).toContain(
      'VIP priority',
    );
  });
});
