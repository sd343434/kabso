/**
 * D275 (owner): the moderator «مشرف» reads the top-up records — the recharge agents, the agents' top-ups «شحن الوكلاء»
 * and the users' card top-ups — with no button that changes anything (no top-up, suspend / reinstate, cap, refund,
 * or cases tab); the CSV download is shown (owner «نعم», audited by the API). Its capabilities come from the table copy (`./capabilities`, checked against the API's).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate } from '../src/i18n';
import { AgentActions } from '../src/pages/Agents';
import { AgentTopups, Cards } from '../src/pages/Finance';
import type { AgentRow, Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const state = (role: PanelRole): AppState => ({
  lang: 'ar',
  t: (key, vars) => translate('ar', key, vars),
  session: null,
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (role: PanelRole, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(role)}>{node}</AppContext.Provider>);

const AGENT = {
  userId: '0190f3a0-0000-7000-8000-000000000002',
  username: 'coin0007',
  displayName: 'محمد',
  code: 'coin0007',
  status: 'ACTIVE',
  stockCoins: 1_000_000,
  dailyCherryCap: null,
  countries: ['EG'],
} as unknown as AgentRow;

describe('D275 the moderator «مشرف» and the top-up records', () => {
  it('reads the agents, the top-ups, the card orders, the ledger and the disputes; no money action', () => {
    const mod = capsOf('MODERATION');
    for (const cap of [
      'recharge.agents',
      'recharge.topups.view',
      'users.ledger',
      'recharge.disputes',
      'recharge.disputes.resolve',
    ] as const)
      expect(mod, cap).toContain(cap);
    for (const cap of [
      'recharge.topup',
      'recharge.cap',
      'recharge.status',
      'recharge.rates',
      'withdrawals.view',
      'withdrawals.decide',
      'finance.view',
      'finance.refund',
      'payments.settings',
      'users.balance_adjust',
    ] as const)
      expect(mod, cap).not.toContain(cap);
  });

  it('an agent row: no top-up, suspend or cap button for the moderator; FINANCE keeps them', () => {
    const noop = () => undefined;
    expect(html('MODERATION', <AgentActions agent={AGENT} onAct={noop} />)).toBe('');
    const finance = html('FINANCE', <AgentActions agent={AGENT} onAct={noop} />);
    expect(finance).toContain('شحن مخزون');
    expect(finance).toContain('تعديل السقف');
  });

  it('«شحن الوكلاء» and the card orders: the CSV but no cases tab for the moderator; FINANCE keeps both', () => {
    const csv = translate('ar', 'tableCsv');
    const cases = translate('ar', 'cardsCases');
    expect(html('MODERATION', <AgentTopups />)).toContain(csv);
    const modCards = html('MODERATION', <Cards />);
    expect(modCards).toContain(translate('ar', 'cardsOrders'));
    expect(modCards).not.toContain(cases);
    expect(modCards).toContain(csv);
    expect(modCards).not.toContain(translate('ar', 'cardsRefund'));
    expect(html('FINANCE', <AgentTopups />)).toContain(csv);
    const financeCards = html('FINANCE', <Cards />);
    expect(financeCards).toContain(cases);
    expect(financeCards).toContain(csv);
  });
});
