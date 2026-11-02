import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { FxRatesService } from './fx-rates.service.js';
import {
  FX_AAD,
  FX_PAID_PROVIDERS,
  FxFetchError,
  maskedOf,
  PROVIDER_INFO,
  type ClearFxSettingsInput,
  type FxPaidProvider,
  type FxTestReport,
  type TestFxSettingsInput,
  type UpdateFxSettingsInput,
} from './fx.rules.js';

interface Person {
  id: string;
  displayName: string;
}

/** `AdminFxSettings` (openapi v1.81-social): never the key, only its last 4. */
export interface AdminFxSettingsDto {
  status: 'active' | 'off' | 'not_configured';
  provider: FxPaidProvider;
  enabled: boolean;
  apiKey: { last4: string; setBy: Person | null; setAt: string | null } | null;
  updatedAt: string | null;
  panelIgnored: 'unreadable' | null;
  lastTest: (FxTestReport & { by: Person | null }) | null;
  paidIntervalSeconds: number;
  freeIntervalSeconds: number;
  providers: {
    code: FxPaidProvider;
    name: string;
    site: string;
    signupUrl: string | null;
    docsUrl: string;
  }[];
  connectionTestSkippable: boolean;
}

type Refusal = 'fx_key_missing' | 'fx_test_required' | 'fx_test_failed' | 'fx_nothing_to_clear';

const REFUSAL_MESSAGE: Record<Refusal, string> = {
  fx_key_missing: 'The paid provider cannot be turned on before its API key is saved.',
  fx_test_required:
    'The connection must be tested before the provider is turned on (skipping is only allowed outside production).',
  fx_test_failed: 'The connection test failed (see the last test in the section). Nothing was saved.',
  fx_nothing_to_clear: 'No paid exchange-rate provider is saved in the panel.',
};

function refuse(issue: Refusal, field: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, REFUSAL_MESSAGE[issue], [{ field, issue }]);
}

function providerOf(value: string | null | undefined): FxPaidProvider {
  return (FX_PAID_PROVIDERS as readonly string[]).includes(value ?? '')
    ? (value as FxPaidProvider)
    : 'CURRENCYAPI';
}

/** The masked summary an audit row carries (never the key: the last 4 only). */
function summaryOf(row: { enabled: boolean; provider: string; apiKeyLast4: string | null } | null) {
  return {
    enabled: row?.enabled ?? false,
    provider: providerOf(row?.provider),
    apiKey: maskedOf(row?.apiKeyLast4),
  };
}

/**
 * The OWNER's «مزوّد أسعار الصرف» section (v1.81-social, D245, CONVENTIONS §10.85.4) — D196 / D222 / D227's pattern:
 * the provider (currencyapi.com or ExchangeRate-API), the API key (write-only, sealed AES-256-GCM with a key derived
 * from ADMIN_TOTP_KEY with HKDF info `fx-settings/v1`, AAD = the column; last 4 shown), the «تفعيل» switch and the
 * last «اختبار الاتصال». Every change needs the authenticator code again and a reason, and is audited with the last 4
 * only. Turning on (or a new key / provider while on) runs the connection test first. While on, the poller reads the
 * paid provider every FX_PAID_INTERVAL_SECONDS (60 s) instead of the free feed hourly.
 */
@Injectable()
export class FxSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly rates: FxRatesService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get production(): boolean {
    return this.config.env === 'production';
  }

  private box(): AdminSecretBox {
    const box = this.rates.secretBox();
    if (!box) throw new AppException(ErrorCode.ADMIN_PANEL_UNAVAILABLE);
    return box;
  }

  private async people(ids: (string | null | undefined)[]): Promise<Map<string, Person>> {
    const wanted = [...new Set(ids.filter((x): x is string => !!x))];
    if (wanted.length === 0) return new Map();
    const rows = await this.prisma.user.findMany({
      where: { id: { in: wanted } },
      select: { id: true, profile: { select: { displayName: true } } },
    });
    return new Map(rows.map((u) => [u.id, { id: u.id, displayName: u.profile?.displayName ?? '' }]));
  }

  async view(): Promise<AdminFxSettingsDto> {
    this.box();
    const row = await this.prisma.fxSettings.findUnique({ where: { id: 1 } });
    const who = await this.people([row?.apiKeySetById, row?.lastTestById]);
    const active = this.rates.activeOf(row);
    return {
      status: row?.enabled ? 'active' : row?.apiKeyEnc ? 'off' : 'not_configured',
      provider: providerOf(row?.provider),
      enabled: row?.enabled ?? false,
      apiKey: row?.apiKeyLast4
        ? {
            last4: row.apiKeyLast4,
            setBy: (row.apiKeySetById && who.get(row.apiKeySetById)) || null,
            setAt: row.apiKeySetAt?.toISOString() ?? null,
          }
        : null,
      updatedAt: row?.updatedAt.toISOString() ?? null,
      panelIgnored: active.paidIgnored,
      lastTest:
        row?.lastTest && typeof row.lastTest === 'object'
          ? {
              ...(row.lastTest as unknown as FxTestReport),
              by: (row.lastTestById && who.get(row.lastTestById)) || null,
            }
          : null,
      paidIntervalSeconds: this.config.fx.paidIntervalSeconds,
      freeIntervalSeconds: this.config.fx.freeIntervalSeconds,
      providers: FX_PAID_PROVIDERS.map((code) => ({ code, ...PROVIDER_INFO[code] })),
      connectionTestSkippable: !this.production,
    };
  }

  private storedKey(row: { apiKeyEnc: string | null } | null, box: AdminSecretBox): string | null {
    return row?.apiKeyEnc ? box.open(row.apiKeyEnc, FX_AAD.apiKey) : null;
  }

  /** «اختبار الاتصال» (no code needed: nothing is saved but the result). Audited with the outcome. */
  async test(input: TestFxSettingsInput, ctx: AdminContext): Promise<FxTestReport> {
    const box = this.box();
    const row = await this.prisma.fxSettings.findUnique({ where: { id: 1 } });
    const apiKey = input.apiKey ?? this.storedKey(row, box);
    if (!apiKey) throw AppException.validation([{ field: 'apiKey', issue: 'required' }]);
    const report = await this.check(input.provider ?? providerOf(row?.provider), apiKey);
    await this.saveReport(report, ctx);
    return report;
  }

  /** One real request to the provider with the key (a stub server in tests). Never throws. */
  async check(provider: FxPaidProvider, apiKey: string): Promise<FxTestReport> {
    const started = Date.now();
    let issue: FxTestReport['issue'] = null;
    let detail: string | null = null;
    let currencies = 0;
    let providerUpdatedAt: string | null = null;
    try {
      const feed = await this.rates.feed.paid(provider, apiKey);
      currencies = Object.keys(feed.rates).filter((c) => /^[A-Z]{3}$/.test(c)).length;
      providerUpdatedAt = feed.providerUpdatedAt?.toISOString() ?? null;
      if (currencies === 0) {
        issue = 'no_rates';
        detail = 'the answer has no rates';
      }
    } catch (err) {
      issue = err instanceof FxFetchError ? err.issue : 'bad_response';
      detail = err instanceof FxFetchError ? err.detail.slice(0, 300) : 'unexpected error';
    }
    return {
      ok: issue === null,
      at: this.clock.now().toISOString(),
      provider,
      apiKeyLast4: apiKey.slice(-4),
      ms: Date.now() - started,
      issue,
      detail,
      currencies,
      providerUpdatedAt,
    };
  }

  private async saveReport(report: FxTestReport, ctx: AdminContext): Promise<void> {
    const now = this.clock.now();
    const data = {
      lastTestAt: new Date(report.at),
      lastTestOk: report.ok,
      lastTestById: ctx.userId,
      lastTest: report as unknown as Prisma.InputJsonValue,
    };
    await this.prisma.$transaction(async (tx) => {
      await tx.fxSettings.upsert({
        where: { id: 1 },
        create: { id: 1, updatedAt: now, ...data },
        update: data,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.FX_SETTINGS_TEST,
        actorUserId: ctx.userId,
        targetType: 'fx_settings',
        metadata: {
          provider: report.provider,
          apiKey: `…${report.apiKeyLast4}`,
          result: report.ok ? 'ok' : 'failed',
          issue: report.issue,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
  }

  /** Saves what the body names (TOTP again + reason); turning on, or a new key / provider while on, is tested first. */
  async update(input: UpdateFxSettingsInput, ctx: AdminContext): Promise<AdminFxSettingsDto> {
    const box = this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const before = await this.prisma.fxSettings.findUnique({ where: { id: 1 } });
    const apiKey = input.apiKey ?? this.storedKey(before, box);
    const provider = input.provider ?? providerOf(before?.provider);
    const enabled = input.enabled ?? before?.enabled ?? false;
    const connectionChanged = input.apiKey !== undefined || input.provider !== undefined;
    let connectionTest: 'ok' | 'skipped' | null = null;
    if (enabled) {
      if (!apiKey) throw refuse('fx_key_missing', 'apiKey');
      if (connectionChanged || !before?.enabled) {
        if (input.skipConnectionTest) {
          if (this.production) throw refuse('fx_test_required', 'skipConnectionTest');
          connectionTest = 'skipped';
        } else {
          const report = await this.check(provider, apiKey);
          await this.saveReport(report, ctx);
          if (!report.ok) throw refuse('fx_test_failed', 'enabled');
          connectionTest = 'ok';
        }
      }
    }
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT INTO fx_settings (id, updated_at) VALUES (1, ${now}) ON CONFLICT (id) DO NOTHING`;
      await tx.$queryRaw`SELECT id FROM fx_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.fxSettings.findUniqueOrThrow({ where: { id: 1 } });
      const data: Prisma.FxSettingsUncheckedUpdateInput = {
        updatedAt: now,
        updatedById: ctx.userId,
        enabled,
        provider,
      };
      if (input.apiKey !== undefined) {
        Object.assign(data, {
          apiKeyEnc: box.seal(input.apiKey, FX_AAD.apiKey),
          apiKeyLast4: input.apiKey.slice(-4),
          apiKeySetAt: now,
          apiKeySetById: ctx.userId,
        });
      }
      // A switch to or from the paid provider (or a new key) is fetched at the next tick, not after the old interval.
      if (enabled !== row.enabled || (enabled && connectionChanged)) data.nextFetchAt = now;
      const after = await tx.fxSettings.update({ where: { id: 1 }, data });
      const b = summaryOf(row);
      const a = summaryOf(after);
      await this.audit.recordIn(tx, {
        action: AuditAction.FX_SETTINGS_UPDATE,
        actorUserId: ctx.userId,
        targetType: 'fx_settings',
        metadata: {
          before: b,
          after: a,
          changed: (Object.keys(a) as (keyof typeof a)[]).filter(
            (k) => b[k] !== a[k] || (k === 'apiKey' && input.apiKey !== undefined),
          ),
          ...(connectionTest ? { connectionTest } : {}),
          reason: input.reason,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.view();
  }

  /** Removes the paid provider and its key (TOTP again + reason): the free feed applies again (hourly). */
  async clear(input: ClearFxSettingsInput, ctx: AdminContext): Promise<AdminFxSettingsDto> {
    this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM fx_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.fxSettings.findUnique({ where: { id: 1 } });
      if (!row?.apiKeyEnc) throw refuse('fx_nothing_to_clear', 'apiKey');
      const after = await tx.fxSettings.update({
        where: { id: 1 },
        data: {
          enabled: false,
          apiKeyEnc: null,
          apiKeyLast4: null,
          apiKeySetAt: null,
          apiKeySetById: null,
          nextFetchAt: row.enabled ? now : row.nextFetchAt,
          updatedAt: now,
          updatedById: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.FX_SETTINGS_CLEAR,
        actorUserId: ctx.userId,
        targetType: 'fx_settings',
        metadata: { before: summaryOf(row), after: summaryOf(after), reason: input.reason, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.view();
  }
}
