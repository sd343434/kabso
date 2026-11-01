import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import type { AdminSecretBox } from '../admin-panel/admin-crypto.js';
import { DiditKeyRejectedError, DiditUnreachableError } from './didit-api.js';
import {
  CONNECTION_FIELDS,
  DEFAULT_MAX_SESSIONS_PER_DAY,
  DIDIT_CONSOLE_URL,
  KYC_AAD,
  KYC_CALLBACK_URL,
  KYC_WEBHOOK_PATH,
  maskedOf,
  missingFields,
  WORKFLOW_FIELDS,
  type ClearKycSettingsInput,
  type KycSettingsRow,
  type KycTestIssue,
  type KycTestReport,
  type KycTestWorkflow,
  type TestKycSettingsInput,
  type UpdateKycSettingsInput,
} from './kyc.rules.js';
import { KycSettingsStore } from './kyc.store.js';

interface Person {
  id: string;
  displayName: string;
}

export interface KycKeyInfoDto {
  last4: string;
  setBy: Person | null;
  setAt: string | null;
}

/** `AdminKycSettings` (openapi v1.80-kyc): never a secret, only its last 4. */
export interface AdminKycSettingsDto {
  status: 'active' | 'off' | 'not_configured';
  enabled: boolean;
  apiKey: KycKeyInfoDto | null;
  webhookSecret: KycKeyInfoDto | null;
  workflowId: string | null;
  workflowIdHost: string | null;
  workflowIdAgency: string | null;
  workflowIdRecharge: string | null;
  maxSessionsPerDay: number;
  missing: string[];
  updatedAt: string | null;
  panelIgnored: 'unreadable' | null;
  lastTest: (KycTestReport & { by: Person | null }) | null;
  webhookUrl: string;
  callbackUrl: string;
  consoleUrl: string;
  connectionTestSkippable: boolean;
}

type Refusal = 'kyc_incomplete' | 'kyc_test_required' | 'kyc_test_failed' | 'kyc_nothing_to_clear';

const REFUSAL_MESSAGE: Record<Refusal, string> = {
  kyc_incomplete:
    'Didit cannot be turned on before the API key, the webhook secret and a workflow id are saved.',
  kyc_test_required:
    'The connection must be tested before it is turned on (skipping is only allowed outside production).',
  kyc_test_failed: 'The connection test failed (see the last test in the section). Nothing was saved.',
  kyc_nothing_to_clear: 'No Didit settings are saved in the panel.',
};

function refuse(issue: Refusal, field: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, REFUSAL_MESSAGE[issue], [{ field, issue }]);
}

/** The masked summary an audit row carries (never a secret: the last 4 only). */
function summaryOf(row: KycSettingsRow | null) {
  return {
    enabled: row?.enabled ?? false,
    apiKey: maskedOf(row?.apiKeyLast4),
    webhookSecret: maskedOf(row?.webhookSecretLast4),
    workflowId: row?.workflowId ?? null,
    workflowIdHost: row?.workflowIdHost ?? null,
    workflowIdAgency: row?.workflowIdAgency ?? null,
    workflowIdRecharge: row?.workflowIdRecharge ?? null,
    maxSessionsPerDay: row?.maxSessionsPerDay ?? DEFAULT_MAX_SESSIONS_PER_DAY,
  };
}

type Workflows = Record<(typeof WORKFLOW_FIELDS)[number], string | null>;

function workflowsOf(
  row: KycSettingsRow | null,
  input: Partial<Record<(typeof WORKFLOW_FIELDS)[number], string | null>>,
): Workflows {
  const pick = (k: (typeof WORKFLOW_FIELDS)[number]) =>
    input[k] !== undefined ? input[k] : (row?.[k] ?? null);
  return {
    workflowId: pick('workflowId'),
    workflowIdHost: pick('workflowIdHost'),
    workflowIdAgency: pick('workflowIdAgency'),
    workflowIdRecharge: pick('workflowIdRecharge'),
  };
}

/**
 * The OWNER's «التحقق من الهوية (Didit)» section (v1.80-kyc, D227, CONVENTIONS §10.77), D196 / D222's pattern. Owns
 * `kyc_settings`: the API key and the webhook secret (sealed AES-256-GCM with a key derived from ADMIN_TOTP_KEY,
 * `kyc-settings/v1`; write-only), the workflow ids (one default, one per purpose optional), the daily limit per
 * person, the «تفعيل» switch and the last «اختبار الاتصال». Every change needs the authenticator code again and a
 * reason, and is audited with the last 4 characters only. Turning on (or a new key / workflow while on) runs the
 * connection test first.
 */
@Injectable()
export class KycSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly store: KycSettingsStore,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get production(): boolean {
    return this.config.env === 'production';
  }

  private box(): AdminSecretBox {
    const box = this.store.secretBox();
    if (!box) throw new AppException(ErrorCode.ADMIN_PANEL_UNAVAILABLE);
    return box;
  }

  /** The address the OWNER pastes in Didit (from the public API base when the server knows it). */
  private webhookUrl(): string {
    return `${this.config.kyc.publicApiBaseUrl.replace(/\/+$/, '')}${KYC_WEBHOOK_PATH}`;
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

  async view(): Promise<AdminKycSettingsDto> {
    this.box();
    const row = await this.prisma.kycSettings.findUnique({ where: { id: 1 } });
    const r = await this.store.resolved();
    const who = await this.people([row?.apiKeySetById, row?.webhookSecretSetById, row?.lastTestById]);
    const key = (
      last4: string | null | undefined,
      by: string | null | undefined,
      at: Date | null | undefined,
    ) => (last4 ? { last4, setBy: (by && who.get(by)) || null, setAt: at?.toISOString() ?? null } : null);
    const lastTest =
      row?.lastTest && typeof row.lastTest === 'object'
        ? {
            ...(row.lastTest as unknown as KycTestReport),
            by: (row.lastTestById && who.get(row.lastTestById)) || null,
          }
        : null;
    return {
      status: row?.enabled
        ? 'active'
        : row?.apiKeyEnc || row?.webhookSecretEnc || row?.workflowId
          ? 'off'
          : 'not_configured',
      enabled: row?.enabled ?? false,
      apiKey: key(row?.apiKeyLast4, row?.apiKeySetById, row?.apiKeySetAt),
      webhookSecret: key(row?.webhookSecretLast4, row?.webhookSecretSetById, row?.webhookSecretSetAt),
      workflowId: row?.workflowId ?? null,
      workflowIdHost: row?.workflowIdHost ?? null,
      workflowIdAgency: row?.workflowIdAgency ?? null,
      workflowIdRecharge: row?.workflowIdRecharge ?? null,
      maxSessionsPerDay: row?.maxSessionsPerDay ?? DEFAULT_MAX_SESSIONS_PER_DAY,
      missing: missingFields({
        apiKey: !!row?.apiKeyEnc,
        webhookSecret: !!row?.webhookSecretEnc,
        workflowId: row?.workflowId ?? null,
      }),
      updatedAt: row?.updatedAt.toISOString() ?? null,
      panelIgnored: r.unreadable ? 'unreadable' : null,
      lastTest,
      webhookUrl: this.webhookUrl(),
      callbackUrl: KYC_CALLBACK_URL,
      consoleUrl: DIDIT_CONSOLE_URL,
      connectionTestSkippable: !this.production,
    };
  }

  private storedKey(row: KycSettingsRow | null, box: AdminSecretBox): string | null {
    return row?.apiKeyEnc ? box.open(row.apiKeyEnc, KYC_AAD.apiKey) : null;
  }

  /** «اختبار الاتصال» (no code needed: nothing is saved but the result). Audited with the outcome. */
  async test(input: TestKycSettingsInput, ctx: AdminContext): Promise<KycTestReport> {
    const box = this.box();
    const row = await this.prisma.kycSettings.findUnique({ where: { id: 1 } });
    const apiKey = input.apiKey ?? this.storedKey(row, box);
    const wf = workflowsOf(row, input);
    const missing = [...(apiKey ? [] : ['apiKey']), ...(wf.workflowId ? [] : ['workflowId'])];
    if (missing.length > 0)
      throw AppException.validation(missing.map((field) => ({ field, issue: 'required' })));
    const report = await this.check(apiKey!, wf);
    await this.saveReport(report, ctx);
    return report;
  }

  /**
   * The real check: `GET /v3/workflows/` with the key (401/403 → `bad_api_key`), then each workflow id saved or typed
   * must be one of the application's workflows, published and not archived. Never throws.
   */
  async check(apiKey: string, wf: Workflows): Promise<KycTestReport> {
    const started = Date.now();
    let issue: KycTestIssue | null = null;
    let list: Awaited<ReturnType<ReturnType<KycSettingsStore['apiFor']>['workflows']>> = [];
    try {
      list = await this.store.apiFor(apiKey).workflows();
    } catch (err) {
      issue =
        err instanceof DiditKeyRejectedError
          ? 'bad_api_key'
          : err instanceof DiditUnreachableError
            ? 'unreachable'
            : 'error';
    }
    const ms = Date.now() - started;
    const workflows: KycTestWorkflow[] = [];
    for (const field of WORKFLOW_FIELDS) {
      const id = wf[field];
      if (!id) continue;
      const found = list.find((w) => w.id.toLowerCase() === id.toLowerCase());
      const wIssue: KycTestIssue | null =
        issue !== null
          ? issue
          : !found
            ? 'workflow_not_found'
            : found.archived
              ? 'workflow_archived'
              : found.status && found.status.toLowerCase() !== 'published'
                ? 'workflow_not_published'
                : null;
      workflows.push({
        field,
        workflowId: id,
        ok: wIssue === null,
        label: found?.label?.slice(0, 120) ?? null,
        features: found?.features?.slice(0, 200) ?? null,
        issue: wIssue,
      });
    }
    return {
      ok: issue === null && workflows.length > 0 && workflows.every((w) => w.ok),
      at: this.clock.now().toISOString(),
      apiKeyLast4: apiKey.slice(-4),
      apiKey: { ok: issue === null, issue, ms },
      workflows,
    };
  }

  private async saveReport(report: KycTestReport, ctx: AdminContext): Promise<void> {
    const now = this.clock.now();
    const data = {
      lastTestAt: new Date(report.at),
      lastTestOk: report.ok,
      lastTestById: ctx.userId,
      lastTest: report as unknown as Prisma.InputJsonValue,
    };
    await this.prisma.$transaction(async (tx) => {
      await tx.kycSettings.upsert({
        where: { id: 1 },
        create: { id: 1, updatedAt: now, ...data },
        update: data,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.KYC_SETTINGS_TEST,
        actorUserId: ctx.userId,
        targetType: 'kyc_settings',
        metadata: {
          apiKey: report.apiKeyLast4 ? `…${report.apiKeyLast4}` : null,
          result: report.ok ? 'ok' : 'failed',
          failed: [
            ...(report.apiKey.ok ? [] : [`apiKey:${report.apiKey.issue ?? ''}`]),
            ...report.workflows.filter((w) => !w.ok).map((w) => `${w.field}:${w.issue ?? ''}`),
          ],
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
  }

  /** Saves what the body names (TOTP again + reason); turning on, or a new key / workflow while on, is tested first. */
  async update(input: UpdateKycSettingsInput, ctx: AdminContext): Promise<AdminKycSettingsDto> {
    const box = this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const before = await this.prisma.kycSettings.findUnique({ where: { id: 1 } });
    const apiKey = input.apiKey ?? this.storedKey(before, box);
    const webhookSecret = input.webhookSecret !== undefined || !!before?.webhookSecretEnc;
    const wf = workflowsOf(before, input);
    const enabled = input.enabled ?? before?.enabled ?? false;
    const connectionChanged = CONNECTION_FIELDS.some((k) => input[k] !== undefined);
    let connectionTest: 'ok' | 'skipped' | null = null;
    if (enabled) {
      const missing = missingFields({ apiKey: !!apiKey, webhookSecret, workflowId: wf.workflowId });
      if (missing.length > 0) {
        throw new AppException(
          ErrorCode.ADMIN_ACTION_REFUSED,
          REFUSAL_MESSAGE.kyc_incomplete,
          missing.map((field) => ({ field, issue: 'kyc_incomplete' })),
        );
      }
      if (connectionChanged || !before?.enabled) {
        if (input.skipConnectionTest) {
          if (this.production) throw refuse('kyc_test_required', 'skipConnectionTest');
          connectionTest = 'skipped';
        } else {
          const report = await this.check(apiKey!, wf);
          await this.saveReport(report, ctx);
          if (!report.ok) throw refuse('kyc_test_failed', 'enabled');
          connectionTest = 'ok';
        }
      }
    }
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT INTO kyc_settings (id, updated_at) VALUES (1, ${now}) ON CONFLICT (id) DO NOTHING`;
      await tx.$queryRaw`SELECT id FROM kyc_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.kycSettings.findUniqueOrThrow({ where: { id: 1 } });
      const data: Prisma.KycSettingsUncheckedUpdateInput = {
        updatedAt: now,
        updatedById: ctx.userId,
        enabled,
      };
      for (const k of WORKFLOW_FIELDS) if (input[k] !== undefined) Object.assign(data, { [k]: input[k] });
      if (input.maxSessionsPerDay !== undefined) data.maxSessionsPerDay = input.maxSessionsPerDay;
      if (input.apiKey !== undefined) {
        Object.assign(data, {
          apiKeyEnc: box.seal(input.apiKey, KYC_AAD.apiKey),
          apiKeyLast4: input.apiKey.slice(-4),
          apiKeySetAt: now,
          apiKeySetById: ctx.userId,
        });
      }
      if (input.webhookSecret !== undefined) {
        Object.assign(data, {
          webhookSecretEnc: box.seal(input.webhookSecret, KYC_AAD.webhookSecret),
          webhookSecretLast4: input.webhookSecret.slice(-4),
          webhookSecretSetAt: now,
          webhookSecretSetById: ctx.userId,
        });
      }
      const after = await tx.kycSettings.update({ where: { id: 1 }, data });
      const b = summaryOf(row);
      const a = summaryOf(after);
      await this.audit.recordIn(tx, {
        action: AuditAction.KYC_SETTINGS_UPDATE,
        actorUserId: ctx.userId,
        targetType: 'kyc_settings',
        metadata: {
          before: b,
          after: a,
          changed: (Object.keys(a) as (keyof typeof a)[]).filter(
            (k) =>
              b[k] !== a[k] ||
              (k === 'apiKey' && input.apiKey !== undefined) ||
              (k === 'webhookSecret' && input.webhookSecret !== undefined),
          ),
          ...(connectionTest ? { connectionTest } : {}),
          reason: input.reason,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    await this.store.reload();
    return this.view();
  }

  /** Removes the panel's Didit settings (TOTP again + reason): Didit is off; the manual ID pictures apply again. */
  async clear(input: ClearKycSettingsInput, ctx: AdminContext): Promise<AdminKycSettingsDto> {
    this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM kyc_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.kycSettings.findUnique({ where: { id: 1 } });
      if (!row || (!row.apiKeyEnc && !row.webhookSecretEnc && !row.workflowId)) {
        throw refuse('kyc_nothing_to_clear', 'enabled');
      }
      const after = await tx.kycSettings.update({
        where: { id: 1 },
        data: {
          enabled: false,
          apiKeyEnc: null,
          apiKeyLast4: null,
          apiKeySetAt: null,
          apiKeySetById: null,
          webhookSecretEnc: null,
          webhookSecretLast4: null,
          webhookSecretSetAt: null,
          webhookSecretSetById: null,
          workflowId: null,
          workflowIdHost: null,
          workflowIdAgency: null,
          workflowIdRecharge: null,
          updatedAt: now,
          updatedById: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.KYC_SETTINGS_CLEAR,
        actorUserId: ctx.userId,
        targetType: 'kyc_settings',
        metadata: { before: summaryOf(row), after: summaryOf(after), reason: input.reason, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    await this.store.reload();
    return this.view();
  }
}
