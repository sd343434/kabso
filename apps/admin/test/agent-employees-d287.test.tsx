/**
 * D287: the agent's employees in the panel — what each did for the agent (sales, cherry purchases, orders done) and
 * the two permissions, in Arabic and English; a removed employee is marked.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AgentEmployeesTable } from '../src/pages/AgentEmployees';
import { AgentActions, AgentEmployeesButton } from '../src/pages/Agents';
import type { AgentEmployee, AgentRow, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const zero = { count: 0, coins: 0 };
const ROWS: AgentEmployee[] = [
  {
    userId: 'e1',
    username: 'sami',
    displayName: 'سامي',
    timeZone: 'Africa/Cairo',
    onShiftNow: true,
    canBuyCherries: true,
    receivesOrders: false,
    addedAt: '2026-10-30T09:00:00.000Z',
    removedAt: null,
    sales: {
      today: { count: 2, coins: 3_000_000 },
      last7Days: zero,
      last30Days: zero,
    },
    cherryPurchases: {
      today: { count: 1, coins: 93_220 },
      last7Days: { count: 1, coins: 93_220 },
      last30Days: { count: 1, coins: 93_220 },
    },
    orders: {
      today: zero,
      last7Days: zero,
      last30Days: { count: 4, coins: 21_000_000 },
    },
  },
  {
    userId: 'e2',
    username: 'rami',
    displayName: 'رامي',
    timeZone: 'UTC',
    onShiftNow: false,
    canBuyCherries: false,
    receivesOrders: true,
    addedAt: '2026-10-01T09:00:00.000Z',
    removedAt: '2026-10-20T09:00:00.000Z',
    sales: { today: zero, last7Days: zero, last30Days: zero },
    cherryPurchases: { today: zero, last7Days: zero, last30Days: zero },
    orders: { today: zero, last7Days: zero, last30Days: zero },
  },
];
const render = (lang: Lang, rows = ROWS) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <AgentEmployeesTable rows={rows} />
    </AppContext.Provider>,
  );

describe('AgentEmployeesTable', () => {
  it('Arabic: the acts per employee and the permissions', () => {
    const html = render('ar');
    expect(html).toContain('شراء الكرز');
    expect(html).toContain('الطلبات المنجزة');
    expect(html).toContain('✓ يمكنه شراء الكرز');
    expect(html).toContain('✗ يستقبل طلبات الشراء');
    expect(html).toContain('في الدوام');
    expect(html).toContain('أُزيل');
  });
  it('English: counts with the coins', () => {
    const html = render('en');
    expect(html).toContain('1 (93,220)');
    expect(html).toContain('4 (21,000,000)');
    expect(html).toContain('Removed');
  });
  it('empty', () => {
    expect(render('en', [])).toContain('No employees.');
  });
});

describe('«الموظفون» on an agent row (recharge.agents)', () => {
  const AGENT = { userId: 'a1', username: 'coin0007', displayName: 'محمد', status: 'ACTIVE' } as unknown as AgentRow;
  const noop = () => undefined;
  const asRole = (role: PanelRole | null, node: React.ReactNode) =>
    renderToStaticMarkup(
      <AppContext.Provider
        value={{
          ...state('ar'),
          can: (cap) => role !== null && (CAPABILITY_ROLES[cap] ?? []).includes(role),
        }}
      >
        {node}
      </AppContext.Provider>,
    );
  it('the moderator «مشرف» (D275) reads the employees but still has no action buttons', () => {
    expect(asRole('MODERATION', <AgentEmployeesButton agent={AGENT} onAct={noop} />)).toContain('الموظفون');
    expect(asRole('MODERATION', <AgentActions agent={AGENT} onAct={noop} />)).toBe('');
    expect(asRole('FINANCE', <AgentEmployeesButton agent={AGENT} onAct={noop} />)).toContain('الموظفون');
  });
  it('nothing without recharge.agents', () => {
    expect(asRole(null, <AgentEmployeesButton agent={AGENT} onAct={noop} />)).toBe('');
  });
});
