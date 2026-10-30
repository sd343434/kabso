import { describe, expect, it } from 'vitest';
import { pickAgentUsername, type AgentCodeCandidate } from '../users/agent-usernames.js';
import { isHostName, isSystemCodeName } from '../users/special-usernames.js';
import { isReservedUsername } from '../users/username.js';
import { hostAgentCode, hostAgentPerksActive } from './host-agents.js';

/** v1.58-social (D189, CONVENTIONS §10.52): the host agents' pure rules. */
describe('host-agent codes', () => {
  it.each([
    [1, 'host01'],
    [9, 'host09'],
    [10, 'host10'],
    [99, 'host99'],
    [100, 'host100'],
    [123, 'host123'],
    [1000, 'host1000'],
  ])('number %i → %s (at least two digits)', (n, code) => {
    expect(hostAgentCode(n)).toBe(code);
  });

  it.each([0, -1, 1.5, Number.NaN])('refuses %s', (n) => {
    expect(() => hostAgentCode(n)).toThrow(RangeError);
  });

  it.each(['host0', 'host01', 'host7', 'host123456', 'host_01', 'ho.st01', 'HOST01'])(
    'reserves %s for the system',
    (name) => {
      expect(isHostName(name)).toBe(true);
      expect(isSystemCodeName(name)).toBe(true);
      expect(isReservedUsername(name)).toBe(true);
    },
  );

  it.each(['host', 'hosts7', 'host7a', 'ghost7', 'host7x8', 'myhost01', 'hostess'])(
    'does not treat %s as a host code',
    (name) => {
      expect(isHostName(name)).toBe(false);
      expect(isReservedUsername(name)).toBe(false);
    },
  );
});

describe('host-agent perks (D189 b)', () => {
  it('are on while the agency has a code and is not suspended, whatever the rank', () => {
    expect(hostAgentPerksActive({ hostCode: 'host01', suspendedAt: null })).toBe(true);
    expect(hostAgentPerksActive({ hostCode: 'host01', suspendedAt: new Date() })).toBe(false);
    expect(hostAgentPerksActive({ hostCode: null, suspendedAt: null })).toBe(false);
  });
});

describe('the agent-username rule (D189 c)', () => {
  const t = (iso: string) => new Date(iso);
  const coin: AgentCodeCandidate = {
    source: 'RECHARGE_AGENT',
    code: 'coin0007',
    activatedAt: t('2026-10-01'),
  };
  const host: AgentCodeCandidate = { source: 'HOST_AGENT', code: 'host03', activatedAt: t('2026-10-05') };

  it('shows the code activated first; none without a live code', () => {
    expect(pickAgentUsername([])).toBeNull();
    expect(pickAgentUsername([host])).toBe(host);
    expect(pickAgentUsername([host, coin])).toBe(coin);
    const earlyHost = { ...host, activatedAt: t('2026-09-01') };
    expect(pickAgentUsername([coin, earlyHost])).toBe(earlyHost);
    // A tie goes to the recharge agent.
    expect(pickAgentUsername([{ ...host, activatedAt: coin.activatedAt }, coin])).toBe(coin);
  });

  it('can be switched to a fixed preference in one place', () => {
    const earlyHost = { ...host, activatedAt: t('2026-09-01') };
    expect(pickAgentUsername([coin, earlyHost], 'RECHARGE_FIRST')).toBe(coin);
    expect(pickAgentUsername([coin, host], 'HOST_FIRST')).toBe(host);
  });
});
