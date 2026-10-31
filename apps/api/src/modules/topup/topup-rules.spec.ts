import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from '../../config/app-config.js';
import {
  buildEvidence,
  disputeHoldsCoins,
  fifoAttribution,
  findPackage,
  simplePdf,
  targetReversal,
  TOPUP_TERMS,
  type LedgerRow,
} from './topup-rules.js';

/** Built at run time so no key-shaped literal is committed (gitleaks). */
const key = (kind: 'sk' | 'rk', mode: 'test' | 'live') =>
  `${kind}_${mode}_${randomBytes(16).toString('hex')}`;
const whsec = () => `whsec_${randomBytes(16).toString('hex')}`;

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

function problems(env: Record<string, string>): string[] {
  try {
    loadConfig(env);
    return [];
  } catch (err) {
    if (err instanceof ConfigValidationError) return [...err.problems];
    throw err;
  }
}

describe('D190 top-up config', () => {
  const stripe = () => ({
    STRIPE_SECRET_KEY: key('sk', 'test'),
    STRIPE_WEBHOOK_SECRET: whsec(),
    TOPUP_PUBLIC_BASE_URL: 'https://pay.kabso.example/',
  });

  it('is off without the keys and prices the owner packages from $12.50 per million', () => {
    const c = loadConfig(base);
    expect(c.topup.stripe).toBeNull();
    expect(c.topup.appLinkEnabled).toBe(false);
    expect(c.topup.bankTransfer.enabled).toBe(false);
    expect(c.topup.packages).toEqual([
      { id: '100000', coins: 100_000, priceMinor: 125 },
      { id: '500000', coins: 500_000, priceMinor: 625 },
      { id: '1000000', coins: 1_000_000, priceMinor: 1250 },
      { id: '5000000', coins: 5_000_000, priceMinor: 6250 },
      { id: '10000000', coins: 10_000_000, priceMinor: 12_500 },
      { id: '50000000', coins: 50_000_000, priceMinor: 62_500 },
    ]);
  });

  it('turns on with all three settings (origin without the trailing slash)', () => {
    const env = { ...base, ...stripe() };
    const c = loadConfig(env);
    expect(c.topup.stripe).toMatchObject({ publicBaseUrl: 'https://pay.kabso.example', testMode: true });
  });

  it('refuses a partial setup (a key without the webhook secret would never credit)', () => {
    const env: Record<string, string> = { ...base, ...stripe() };
    delete env.STRIPE_WEBHOOK_SECRET;
    expect(problems(env).some((p) => p.startsWith('STRIPE_WEBHOOK_SECRET:'))).toBe(true);
  });

  it('refuses malformed keys', () => {
    expect(problems({ ...base, ...stripe(), STRIPE_SECRET_KEY: 'pk_test_abcdefghij' })[0]).toMatch(
      /^STRIPE_SECRET_KEY:/,
    );
    expect(problems({ ...base, ...stripe(), STRIPE_WEBHOOK_SECRET: 'nope' })[0]).toMatch(
      /^STRIPE_WEBHOOK_SECRET:/,
    );
  });

  it('production refuses a test key unless explicitly allowed, and needs https', () => {
    const hex = () => randomBytes(32).toString('hex');
    const prod = {
      ...base,
      NODE_ENV: 'production',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      LIVE_CURSOR_KEY: hex(),
      ...stripe(),
    };
    const about = (env: Record<string, string>, k: string) =>
      problems(env).filter((p) => p.startsWith(`${k}:`));
    expect(about(prod, 'STRIPE_SECRET_KEY')).toHaveLength(1);
    expect(about({ ...prod, STRIPE_SECRET_KEY: key('rk', 'test') }, 'STRIPE_SECRET_KEY')).toHaveLength(1);
    expect(about({ ...prod, STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION: 'true' }, 'STRIPE_SECRET_KEY')).toEqual([]);
    expect(about({ ...prod, STRIPE_SECRET_KEY: key('sk', 'live') }, 'STRIPE_SECRET_KEY')).toEqual([]);
    expect(
      about({ ...prod, TOPUP_PUBLIC_BASE_URL: 'http://pay.kabso.example' }, 'TOPUP_PUBLIC_BASE_URL'),
    ).toHaveLength(1);
    // A test key is fine outside production.
    expect(loadConfig({ ...base, ...stripe() }).topup.stripe?.testMode).toBe(true);
  });

  it('refuses packages that are not a whole number of cents ≥ 50', () => {
    expect(problems({ ...base, ...stripe(), TOPUP_PACKAGES: '1000,100000' })[0]).toMatch(/^TOPUP_PACKAGES:/);
    expect(problems({ ...base, ...stripe(), TOPUP_PACKAGES: '123457' })[0]).toMatch(/^TOPUP_PACKAGES:/);
    expect(problems({ ...base, TOPUP_PACKAGES: '100000,100000' })[0]).toMatch(/^TOPUP_PACKAGES:/);
    // Off: the retail price (it also prices task rewards, D188) is not held to whole cents per package.
    expect(problems({ ...base, COIN_RETAIL_USD_PER_MILLION: '9.99' })).toEqual([]);
  });
});

describe('D190 pricing and reversal rules', () => {
  const packages = loadConfig(base).topup.packages;

  it('only the server packages exist (the client never sends a price)', () => {
    expect(findPackage(packages, '1000000')).toEqual({ id: '1000000', coins: 1_000_000, priceMinor: 1250 });
    expect(findPackage(packages, '999')).toBeNull();
    expect(findPackage(packages, '1000000 ')).toBeNull();
  });

  const facts = {
    coins: 1_000_000n,
    amountMinor: 1250,
    refundedMinor: 0,
    fraudWarning: false,
    disputeStatus: null,
    disputeAmountMinor: 0,
  };

  it('takes back the refunded share, rounded up, and everything on a full refund', () => {
    expect(targetReversal(facts)).toBe(0n);
    expect(targetReversal({ ...facts, refundedMinor: 625 })).toBe(500_000n);
    expect(targetReversal({ ...facts, refundedMinor: 1 })).toBe(800n);
    expect(targetReversal({ ...facts, coins: 3n, amountMinor: 100, refundedMinor: 1 })).toBe(1n);
    expect(targetReversal({ ...facts, refundedMinor: 1250 })).toBe(1_000_000n);
    expect(targetReversal({ ...facts, refundedMinor: 99_999 })).toBe(1_000_000n);
  });

  it('an early-fraud warning takes everything; a dispute holds its share until won', () => {
    expect(targetReversal({ ...facts, fraudWarning: true })).toBe(1_000_000n);
    expect(targetReversal({ ...facts, disputeStatus: 'needs_response', disputeAmountMinor: 1250 })).toBe(
      1_000_000n,
    );
    expect(targetReversal({ ...facts, disputeStatus: 'lost', disputeAmountMinor: 1250 })).toBe(1_000_000n);
    expect(targetReversal({ ...facts, disputeStatus: 'won', disputeAmountMinor: 1250 })).toBe(0n);
    expect(
      targetReversal({
        ...facts,
        refundedMinor: 250,
        disputeStatus: 'under_review',
        disputeAmountMinor: 1000,
      }),
    ).toBe(1_000_000n);
    expect(
      targetReversal({ ...facts, refundedMinor: 250, disputeStatus: 'won', disputeAmountMinor: 1000 }),
    ).toBe(200_000n);
    expect(disputeHoldsCoins('warning_closed')).toBe(false);
    expect(disputeHoldsCoins('warning_needs_response')).toBe(true);
  });
});

describe('D190 FIFO attribution', () => {
  let n = 0;
  const row = (reason: string, delta: bigint, ref = `r${++n}`): LedgerRow => ({
    id: `id${n}`,
    reason,
    delta,
    referenceId: ref,
    createdAt: new Date(1_800_000_000_000 + n * 1000),
  });

  it('spends the coins held before the purchase first, then the purchase; later credits queue behind', () => {
    const later = [
      row('LIVE_GIFT', -300n, 'g1'), // all from the 500 held before
      row('LIVE_GIFT', -400n, 'g2'), // 200 held + 200 purchased
      row('TASK_REWARD', 1000n),
      row('DM_GIFT', -900n, 'g3'), // 800 purchased left → 800
      row('LIVE_GIFT', -50n, 'g4'), // none left
    ];
    const { spends, unspent } = fifoAttribution(500n, 1000n, later);
    expect(spends.map((s) => [s.referenceId, s.coins])).toEqual([
      ['g2', 200n],
      ['g3', 800n],
    ]);
    expect(unspent).toBe(0n);
  });

  it('a debt before the purchase is paid first; reversals are not spending', () => {
    const later = [row('CARD_TOPUP_REVERSAL', -100n), row('LIVE_GIFT', -1000n, 'g5')];
    const { spends, unspent } = fifoAttribution(-300n, 1000n, later);
    expect(spends.map((s) => [s.referenceId, s.coins])).toEqual([['g5', 700n]]);
    expect(unspent).toBe(0n);
    expect(fifoAttribution(0n, 1000n, []).unspent).toBe(1000n);
  });
});

describe('D190 dispute evidence', () => {
  const input = {
    order: {
      id: '0190a000-0000-7000-8000-000000000001',
      coins: 1_000_000n,
      amountMinor: 1250,
      currency: 'USD',
      createdAt: new Date('2026-10-31T10:00:00Z'),
      creditedAt: new Date('2026-10-31T10:01:00Z'),
      paymentIntentId: 'pi_123',
      paymentMethodType: 'card',
    },
    buyer: { email: 'buyer@example.com', displayName: 'Buyer', username: 'buyer1' },
    terms: {
      version: '2026-10-31',
      text: TOPUP_TERMS.ar,
      locale: 'ar',
      acceptedAt: new Date('2026-10-31T09:59:00Z'),
      ip: '203.0.113.7',
      userAgent: 'Mozilla/5.0',
    },
    logins: [
      {
        at: new Date('2026-10-30T08:00:00Z'),
        lastUsedAt: new Date('2026-10-31T10:05:00Z'),
        ip: '203.0.113.7',
        userAgent: 'Kabso/1.0',
        device: 'Pixel android',
      },
    ],
    spends: [
      { at: new Date('2026-10-31T10:10:00Z'), what: 'sent the gift "rose" in a live room', coins: 5000n },
    ],
    unspentCoins: 995_000n,
    statementDescriptor: 'KABSO LIVE',
  };

  it('carries the owner fields, factual and about the buyer only', () => {
    const { evidence, receiptLines } = buildEvidence(input);
    expect(Object.keys(evidence).sort()).toEqual(
      [
        'access_activity_log',
        'customer_email_address',
        'customer_name',
        'customer_purchase_ip',
        'product_description',
        'refund_policy',
        'refund_policy_disclosure',
        'service_date',
        'uncategorized_text',
      ].sort(),
    );
    expect(evidence.customer_email_address).toBe('buyer@example.com');
    expect(evidence.access_activity_log).toContain('203.0.113.7');
    expect(evidence.access_activity_log).toContain('Pixel android');
    expect(evidence.access_activity_log).toContain('"rose"');
    expect(evidence.refund_policy_disclosure).toContain(TOPUP_TERMS.ar);
    expect(evidence.refund_policy_disclosure).toContain('2026-10-31T09:59:00Z');
    expect(evidence.service_date).toBe('2026-10-31');
    expect(receiptLines.join('\n')).toContain('12.50 USD');
  });

  it('writes a well-formed one-page PDF (ASCII, xref offsets)', () => {
    const pdf = simplePdf(['Kabso (receipt)', 'العربية', 'back\\slash']).toString('latin1');
    expect(pdf.startsWith('%PDF-1.4\n')).toBe(true);
    expect(pdf.trimEnd().endsWith('%%EOF')).toBe(true);
    expect(pdf).toContain('(Kabso \\(receipt\\)) Tj');
    expect(pdf).toContain('(???????) Tj');
    const start = Number(/startxref\n(\d+)/.exec(pdf)![1]);
    expect(pdf.slice(start, start + 4)).toBe('xref');
    const offsets = [...pdf.matchAll(/^(\d{10}) 00000 n $/gm)].map((m) => Number(m[1]));
    offsets.forEach((off, i) => expect(pdf.slice(off, off + `${i + 1} 0 obj`.length)).toBe(`${i + 1} 0 obj`));
  });
});
