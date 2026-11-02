import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { formatRate } from '../recharge/recharge-order-rules.js';
import { FxFeedClient } from './fx-feed.js';
import {
  allCountries,
  decide,
  FREE_ATTRIBUTION,
  FX_AAD,
  FX_LEASE_SECONDS,
  FX_PAID_PROVIDERS,
  FX_REFRESH_MIN_SECONDS,
  FxFetchError,
  newFxSecretBox,
  nextDelaySeconds,
  PROVIDER_INFO,
  resolveRate,
  type AutoRate,
  type EffectiveRate,
  type FxFeed,
  type FxIssue,
  type FxPaidProvider,
  type FxSource,
  type ManualRate,
} from './fx.rules.js';

type Db = Pick<Prisma.TransactionClient, 'rechargeExchangeRate' | 'fxRate'>;

/** The effective rate of a country: the manual row, else the automatic one of its currency (one read each). */
export async function effectiveRateIn(
  db: Db,
  country: string,
  now: Date,
  staleAfterHours: number,
): Promise<EffectiveRate> {
  const m = await db.rechargeExchangeRate.findUnique({ where: { country } });
  const manual: ManualRate | null = m
    ? { currency: m.currency, rateMicro: m.rateMicro, digits: m.digits, updatedAt: m.updatedAt }
    : null;
  let auto: AutoRate | null = null;
  if (!manual) {
    const probe = resolveRate(country, null, null, now, staleAfterHours);
    if (probe.currency && probe.currency !== 'USD') {
      auto = await db.fxRate.findUnique({ where: { currency: probe.currency } });
    }
  }
  return resolveRate(country, manual, auto, now, staleAfterHours);
}

/** The outcome of one poller step. */
export type FxRunResult =
  | { status: 'not_due' | 'locked' }
  | { status: 'failed'; source: FxSource; issue: FxIssue; nextFetchAt: string }
  | {
      status: 'ok';
      source: FxSource;
      accepted: number;
      held: number;
      rejected: number;
      nextFetchAt: string;
    };

/** The paid provider in use now (null = the free feed), and why a saved one is not used. */
interface ActiveProvider {
  readonly paid: { provider: FxPaidProvider; apiKey: string } | null;
  readonly paidIgnored: 'unreadable' | null;
}

/**
 * v1.81-social (D245, CONVENTIONS §10.85): automatic exchange rates for every country.
 *
 * - **The resolver** ({@link effective}): every price reads its rate here — the admin's manual rate «يدوي» of the country
 *   wins, else the automatic rate of the country's currency (stale data → USD only), D204's «USD always» kept.
 * - **The poller step** ({@link runIfDue}): the free feed every FX_FREE_INTERVAL_SECONDS (1 h), or the OWNER's paid
 *   provider every FX_PAID_INTERVAL_SECONDS (60 s). Single-instance safe: the step claims a lease on the `fx_settings`
 *   row (`FOR UPDATE`, `running_until`), and the shared `next_fetch_at` says when a fetch is due, so N API instances
 *   fetch once per period. A failure keeps the last rates, records the error and backs off.
 */
@Injectable()
export class FxRatesService {
  private readonly logger = new Logger(FxRatesService.name);
  private readonly box: AdminSecretBox | null;
  readonly feed: FxFeedClient;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly audit: AuditService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.box = newFxSecretBox(config.adminPanel.totpKey);
    this.feed = new FxFeedClient(config.fx);
  }

  /** The box that seals the paid key (null without ADMIN_TOTP_KEY: the provider section is then 503). */
  secretBox(): AdminSecretBox | null {
    return this.box;
  }

  // ---- the resolver -------------------------------------------------------------------------------------------

  /** The rate a price of `country` uses now. */
  effective(country: string, now: Date = this.clock.now()): Promise<EffectiveRate> {
    return effectiveRateIn(this.prisma, country, now, this.config.fx.staleAfterHours);
  }

  /** Every country (the table and any manual row) with its effective rate and both sources, for the panel. */
  async table(now: Date = this.clock.now()) {
    const [manualRows, autoRows] = await Promise.all([
      this.prisma.rechargeExchangeRate.findMany(),
      this.prisma.fxRate.findMany(),
    ]);
    const manual = new Map(manualRows.map((r) => [r.country, r]));
    const auto = new Map(autoRows.map((r) => [r.currency, r]));
    const countries = [...new Set([...allCountries(), ...manualRows.map((r) => r.country)])].sort();
    return countries.map((country) => {
      const m = manual.get(country) ?? null;
      const probe = resolveRate(country, null, null, now, this.config.fx.staleAfterHours);
      const a = probe.currency ? (auto.get(probe.currency) ?? null) : null;
      const e = resolveRate(country, m, a, now, this.config.fx.staleAfterHours);
      const autoEffective = resolveRate(country, null, a, now, this.config.fx.staleAfterHours);
      return {
        country,
        currency: e.currency,
        digits: e.digits,
        unitsPerUsd: e.rate ? formatRate(e.rate.rateMicro) : null,
        updatedAt: e.updatedAt?.toISOString() ?? null,
        source: e.source,
        stale: e.stale,
        manual: m
          ? {
              currency: m.currency,
              digits: m.digits,
              unitsPerUsd: formatRate(m.rateMicro),
              updatedAt: m.updatedAt.toISOString(),
            }
          : null,
        auto:
          probe.currency === 'USD'
            ? null
            : a
              ? {
                  currency: a.currency,
                  unitsPerUsd: formatRate(a.rateMicro),
                  source: a.source,
                  fetchedAt: a.fetchedAt.toISOString(),
                  providerUpdatedAt: a.providerUpdatedAt?.toISOString() ?? null,
                  stale: autoEffective.stale,
                  held:
                    a.heldRateMicro !== null && a.heldAt !== null
                      ? {
                          unitsPerUsd: formatRate(a.heldRateMicro),
                          source: a.heldSource,
                          at: a.heldAt.toISOString(),
                          jumpPercent:
                            Math.round(
                              (Math.abs(Number(a.heldRateMicro - a.rateMicro)) / Number(a.rateMicro)) * 1000,
                            ) / 10,
                        }
                      : null,
                }
              : null,
      };
    });
  }

  /** The status card «الحالة»: which source, when fetched, when next, the last error. */
  async status(now: Date = this.clock.now()) {
    const row = await this.prisma.fxSettings.findUnique({ where: { id: 1 } });
    const active = this.activeOf(row);
    const source: FxSource = active.paid?.provider ?? 'OPEN_ER_API';
    const [currencies, held, fromFree] = await Promise.all([
      this.prisma.fxRate.count(),
      this.prisma.fxRate.count({ where: { heldRateMicro: { not: null } } }),
      this.prisma.fxRate.count({ where: { source: 'OPEN_ER_API' } }),
    ]);
    const polling = this.config.fx.tickSeconds > 0;
    return {
      source,
      sourceName: PROVIDER_INFO[source].name,
      paidActive: active.paid !== null,
      paidIgnored: active.paidIgnored,
      intervalSeconds: active.paid ? this.config.fx.paidIntervalSeconds : this.config.fx.freeIntervalSeconds,
      polling,
      lastAttemptAt: row?.lastAttemptAt?.toISOString() ?? null,
      lastSuccessAt: row?.lastSuccessAt?.toISOString() ?? null,
      lastSource: row?.lastSource ?? null,
      lastProviderUpdatedAt: row?.lastProviderUpdatedAt?.toISOString() ?? null,
      nextFetchAt: polling ? (row?.nextFetchAt ?? now).toISOString() : null,
      lastError:
        row?.lastErrorAt && row.lastErrorIssue
          ? { at: row.lastErrorAt.toISOString(), issue: row.lastErrorIssue, detail: row.lastErrorDetail }
          : null,
      failures: row?.failures ?? 0,
      lastReport: (row?.lastReport as Record<string, unknown> | null) ?? null,
      currencies,
      held,
      staleAfterHours: this.config.fx.staleAfterHours,
      maxJumpPercent: this.config.fx.maxJumpPercent,
      attribution: source === 'OPEN_ER_API' || fromFree > 0 ? FREE_ATTRIBUTION : null,
    };
  }

  // ---- the poller step ----------------------------------------------------------------------------------------

  /** The saved paid provider, opened (null = free); an unreadable key falls back to the free feed. */
  activeOf(row: { enabled: boolean; provider: string; apiKeyEnc: string | null } | null): ActiveProvider {
    if (!row?.enabled || !row.apiKeyEnc) return { paid: null, paidIgnored: null };
    const apiKey = this.box?.open(row.apiKeyEnc, FX_AAD.apiKey) ?? null;
    if (apiKey === null) return { paid: null, paidIgnored: 'unreadable' };
    const provider = (FX_PAID_PROVIDERS as readonly string[]).includes(row.provider)
      ? (row.provider as FxPaidProvider)
      : 'CURRENCYAPI';
    return { paid: { provider, apiKey }, paidIgnored: null };
  }

  /**
   * One step: fetch when due (or `force`), unless another instance holds the lease. Never throws for a feed problem
   * (the failure is recorded); a database error propagates (the poller logs it).
   */
  async runIfDue(now: Date = this.clock.now(), force = false): Promise<FxRunResult> {
    const claim = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT INTO fx_settings (id, updated_at) VALUES (1, ${now}) ON CONFLICT (id) DO NOTHING`;
      await tx.$queryRaw`SELECT id FROM fx_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.fxSettings.findUniqueOrThrow({ where: { id: 1 } });
      if (row.runningUntil && row.runningUntil > now) return { kind: 'locked' as const };
      if (!force && row.nextFetchAt && row.nextFetchAt > now) return { kind: 'not_due' as const };
      await tx.fxSettings.update({
        where: { id: 1 },
        data: { runningUntil: new Date(now.getTime() + FX_LEASE_SECONDS * 1000), lastAttemptAt: now },
      });
      return { kind: 'claimed' as const, row };
    });
    if (claim.kind !== 'claimed') return { status: claim.kind };
    const active = this.activeOf(claim.row);
    const source: FxSource = active.paid?.provider ?? 'OPEN_ER_API';
    const interval = active.paid ? this.config.fx.paidIntervalSeconds : this.config.fx.freeIntervalSeconds;
    let feed: FxFeed;
    try {
      feed = active.paid
        ? await this.feed.paid(active.paid.provider, active.paid.apiKey)
        : await this.feed.free();
    } catch (err) {
      return this.recordFailure(err, source, claim.row.failures, interval, !!active.paid, now);
    }
    const applied = await this.apply(feed, now);
    if (applied.accepted + applied.held === 0) {
      return this.recordFailure(
        new FxFetchError('no_rates', `no usable rate (${applied.rejected} rejected)`),
        source,
        claim.row.failures,
        interval,
        !!active.paid,
        now,
      );
    }
    const next = new Date(now.getTime() + interval * 1000);
    await this.prisma.fxSettings.update({
      where: { id: 1 },
      data: {
        runningUntil: null,
        nextFetchAt: next,
        lastSuccessAt: now,
        lastSource: source,
        lastProviderUpdatedAt: feed.providerUpdatedAt,
        lastReport: {
          accepted: applied.accepted,
          held: applied.held,
          rejected: applied.rejected,
          heldCurrencies: applied.heldCurrencies.slice(0, 20),
          rejectedCurrencies: applied.rejectedCurrencies.slice(0, 20),
        },
        failures: 0,
      },
    });
    if (applied.held + applied.rejected > 0) {
      this.logger.warn(
        { source, held: applied.heldCurrencies, rejected: applied.rejectedCurrencies },
        'Exchange rates: some values were held or rejected',
      );
    }
    return {
      status: 'ok',
      source,
      accepted: applied.accepted,
      held: applied.held,
      rejected: applied.rejected,
      nextFetchAt: next.toISOString(),
    };
  }

  private async recordFailure(
    err: unknown,
    source: FxSource,
    failuresBefore: number,
    interval: number,
    paid: boolean,
    now: Date,
  ): Promise<FxRunResult> {
    const e =
      err instanceof FxFetchError ? err : new FxFetchError('bad_response', 'unexpected error while reading');
    if (!(err instanceof FxFetchError)) {
      this.logger.error({ error: safeErrorLog(err) }, 'Exchange rates: unexpected error');
    }
    const failures = failuresBefore + 1;
    const next = new Date(now.getTime() + nextDelaySeconds(interval, failures, paid) * 1000);
    await this.prisma.fxSettings.update({
      where: { id: 1 },
      data: {
        runningUntil: null,
        nextFetchAt: next,
        lastErrorAt: now,
        lastErrorIssue: e.issue,
        lastErrorDetail: e.detail.slice(0, 300),
        failures,
      },
    });
    this.logger.warn(
      { source, issue: e.issue, detail: e.detail, failures, nextFetchAt: next.toISOString() },
      'Exchange rates: fetch failed; the last good rates stay in use',
    );
    return { status: 'failed', source, issue: e.issue, nextFetchAt: next.toISOString() };
  }

  /** Checks every value of a feed against the last good one and writes the accepted and held ones. */
  private async apply(feed: FxFeed, now: Date) {
    const existing = new Map(
      (await this.prisma.fxRate.findMany({ select: { currency: true, rateMicro: true } })).map((r) => [
        r.currency,
        r.rateMicro,
      ]),
    );
    const accepted: { currency: string; rateMicro: bigint }[] = [];
    const held: { currency: string; rateMicro: bigint }[] = [];
    const rejectedCurrencies: string[] = [];
    for (const [code, value] of Object.entries(feed.rates)) {
      if (!/^[A-Z]{3}$/.test(code) || code === 'USD') continue;
      const d = decide(value, existing.get(code) ?? null, this.config.fx.maxJumpPercent);
      if (d.kind === 'accept') accepted.push({ currency: code, rateMicro: d.rateMicro });
      else if (d.kind === 'hold') held.push({ currency: code, rateMicro: d.rateMicro });
      else rejectedCurrencies.push(code);
    }
    await this.prisma.$transaction(async (tx) => {
      if (accepted.length > 0) {
        await tx.$executeRaw`
          INSERT INTO fx_rates (currency, rate_micro, source, provider_updated_at, fetched_at, updated_at)
          SELECT t.c, t.r::bigint, ${feed.source}, ${feed.providerUpdatedAt}, ${now}, ${now}
            FROM unnest(${accepted.map((a) => a.currency)}::text[], ${accepted.map((a) => a.rateMicro.toString())}::text[]) AS t(c, r)
          ON CONFLICT (currency) DO UPDATE
             SET rate_micro = EXCLUDED.rate_micro, source = EXCLUDED.source,
                 provider_updated_at = EXCLUDED.provider_updated_at, fetched_at = EXCLUDED.fetched_at,
                 held_rate_micro = NULL, held_source = NULL, held_provider_updated_at = NULL, held_at = NULL,
                 updated_at = EXCLUDED.updated_at`;
      }
      if (held.length > 0) {
        await tx.$executeRaw`
          UPDATE fx_rates f
             SET held_rate_micro = t.r::bigint, held_source = ${feed.source},
                 held_provider_updated_at = ${feed.providerUpdatedAt},
                 held_at = CASE WHEN f.held_rate_micro IS NULL THEN ${now} ELSE f.held_at END,
                 updated_at = ${now}
            FROM unnest(${held.map((a) => a.currency)}::text[], ${held.map((a) => a.rateMicro.toString())}::text[]) AS t(c, r)
           WHERE f.currency = t.c`;
      }
    });
    return {
      accepted: accepted.length,
      held: held.length,
      rejected: rejectedCurrencies.length,
      heldCurrencies: held.map((h) => h.currency).sort(),
      rejectedCurrencies: rejectedCurrencies.sort(),
    };
  }

  // ---- the panel's actions ------------------------------------------------------------------------------------

  /** «تحديث الآن» (recharge.rates): fetch now, unless the last attempt was under a minute ago. Audited. */
  async refresh(by: { actorUserId: string; ip: string | null; requestId: string | null }) {
    const now = this.clock.now();
    const row = await this.prisma.fxSettings.findUnique({ where: { id: 1 } });
    if (row?.lastAttemptAt && now.getTime() - row.lastAttemptAt.getTime() < FX_REFRESH_MIN_SECONDS * 1000) {
      throw new AppException(
        ErrorCode.ADMIN_ACTION_REFUSED,
        `The rates were fetched less than ${FX_REFRESH_MIN_SECONDS} seconds ago.`,
        [{ field: 'refresh', issue: 'fx_refresh_too_soon' }],
      );
    }
    const result = await this.runIfDue(now, true);
    await this.audit.record({
      action: AuditAction.FX_RATES_REFRESH,
      actorUserId: by.actorUserId,
      targetType: 'fx_rates',
      metadata: {
        result: result.status,
        ...('issue' in result ? { issue: result.issue } : {}),
        via: 'panel',
      },
      ip: by.ip,
      requestId: by.requestId,
    });
    return { result, status: await this.status() };
  }

  /** Accepts a held value (recharge.rates; reason; audited before / after). 409 when nothing is held. */
  async acceptHeld(
    currency: string,
    reason: string,
    by: { actorUserId: string; ip: string | null; requestId: string | null },
  ) {
    const now = this.clock.now();
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT currency FROM fx_rates WHERE currency = ${currency} FOR UPDATE`;
      const row = await tx.fxRate.findUnique({ where: { currency } });
      if (!row || row.heldRateMicro === null || row.heldSource === null) {
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, `No held rate for ${currency}.`, [
          { field: 'currency', issue: 'fx_nothing_held' },
        ]);
      }
      const after = await tx.fxRate.update({
        where: { currency },
        data: {
          rateMicro: row.heldRateMicro,
          source: row.heldSource,
          providerUpdatedAt: row.heldProviderUpdatedAt,
          fetchedAt: row.heldAt ?? now,
          heldRateMicro: null,
          heldSource: null,
          heldProviderUpdatedAt: null,
          heldAt: null,
          updatedAt: now,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.FX_RATE_ACCEPT_HELD,
        actorUserId: by.actorUserId,
        targetType: 'fx_rate',
        targetId: currency,
        metadata: {
          before: formatRate(row.rateMicro),
          after: formatRate(after.rateMicro),
          source: after.source,
          reason,
          via: 'panel',
        },
        ip: by.ip,
        requestId: by.requestId,
      });
      return { currency, unitsPerUsd: formatRate(after.rateMicro), source: after.source };
    });
  }
}

/**
 * The poller (D245): every FX_POLL_TICK_SECONDS (0 = off — tests) each instance asks {@link FxRatesService.runIfDue};
 * the shared `next_fetch_at` and the lease make one fetch per period across instances (hourly free / every minute
 * paid).
 */
@Injectable()
export class FxPoller implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(FxPoller.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly rates: FxRatesService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.fx.tickSeconds > 0) this.schedule(5_000);
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(ms: number): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.rates
        .runIfDue()
        .then((r) => {
          if (r.status === 'ok') this.logger.log(r, 'Exchange rates updated');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Exchange-rate poll failed');
        })
        .finally(() => {
          this.inFlight = null;
          if (this.timer) this.schedule(this.config.fx.tickSeconds * 1000);
        });
    }, ms);
    this.timer.unref();
  }
}
