import { isIP } from 'node:net';
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
import { uuidv7 } from '../levels/uuidv7.js';
import { newS3Client, PUBLIC_KEY_PREFIX, S3ObjectStorage } from '../media/s3-object-storage.js';
import {
  CONNECTION_FIELDS,
  HEALTHCHECK_PREFIX,
  issueOfError,
  maskedOf,
  missingFields,
  resolveStorageSettings,
  s3SettingsOf,
  STORAGE_AAD,
  targetOf,
  type ClearStorageSettingsInput,
  type StorageSettingsRow,
  type StorageTarget,
  type StorageTestReport,
  type StorageTestStep,
  type TestIssue,
  type TestStepName,
  type TestStorageSettingsInput,
  type UpdateStorageSettingsInput,
} from './storage-settings.rules.js';
import { StorageSettingsStore } from './storage-settings.store.js';

/** One network step of «اختبار الاتصال» may take this long. */
export const STORAGE_TEST_STEP_TIMEOUT_MS = 10_000;

interface Person {
  id: string;
  displayName: string;
}

/** `StorageKeyInfo`: all the panel ever shows of a key. */
export interface StorageKeyInfoDto {
  last4: string;
  setBy: Person | null;
  setAt: string | null;
}

/** `AdminStorageSettings` (openapi v1.75-social): never a key, only its last 4. */
export interface AdminStorageSettingsDto {
  status: 'active' | 'env' | 'off' | 'not_configured';
  source: 'panel' | 'env' | 'none';
  uploadsEnabled: boolean;
  publicBaseUrl: string | null;
  enabled: boolean;
  panel: {
    provider: 'R2' | 'S3';
    accountId: string | null;
    endpoint: string | null;
    region: string | null;
    forcePathStyle: boolean;
    publicBucket: string | null;
    publicBaseUrl: string | null;
    privateBucket: string | null;
    accessKeyId: StorageKeyInfoDto | null;
    secretAccessKey: StorageKeyInfoDto | null;
    missing: string[];
    updatedAt: string | null;
  };
  env: {
    configured: boolean;
    uploadsEnabled: boolean;
    endpoint: string | null;
    region: string;
    bucket: string | null;
    publicBaseUrl: string | null;
    accessKeyIdLast4: string | null;
  };
  panelIgnored: 'unreadable' | null;
  lastTest: (StorageTestReport & { by: Person | null }) | null;
  publicPrefix: string;
  healthcheckPrefix: string;
  connectionTestSkippable: boolean;
}

type Refusal =
  | 'same_bucket'
  | 'storage_incomplete'
  | 'storage_test_required'
  | 'storage_test_failed'
  | 'https_required'
  | 'storage_nothing_to_clear';

const REFUSAL_MESSAGE: Record<Refusal, string> = {
  same_bucket: 'The public and the private bucket must be two different buckets.',
  storage_incomplete: 'The storage cannot be turned on before every required field is filled in.',
  storage_test_required:
    'The connection must be tested before it is saved (skipping is only allowed outside production).',
  storage_test_failed: 'The connection test failed (see the last test in the section). Nothing was saved.',
  https_required: 'In production the endpoint and the public URL must be https:// on a domain name.',
  storage_nothing_to_clear: 'No storage settings are saved in the panel.',
};

function refuse(issue: Refusal, field: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, REFUSAL_MESSAGE[issue], [{ field, issue }]);
}

/** The masked summary an audit row carries (never a key: the last 4 only). */
function summaryOf(row: StorageSettingsRow | null) {
  return {
    enabled: row?.enabled ?? false,
    provider: row?.provider ?? 'R2',
    accountId: row?.accountId ?? null,
    endpoint: row?.endpoint ?? null,
    region: row?.region ?? null,
    forcePathStyle: row?.forcePathStyle ?? false,
    accessKeyId: maskedOf(row?.accessKeyIdLast4),
    secretAccessKey: maskedOf(row?.secretAccessKeyLast4),
    publicBucket: row?.publicBucket ?? null,
    publicBaseUrl: row?.publicBaseUrl ?? null,
    privateBucket: row?.privateBucket ?? null,
  };
}

/** The row's connection values with the body's on top (null clears; undefined keeps). */
function merged(row: StorageSettingsRow | null, input: TestStorageSettingsInput) {
  const pick = <
    K extends 'accountId' | 'endpoint' | 'region' | 'publicBucket' | 'publicBaseUrl' | 'privateBucket',
  >(
    k: K,
  ): string | null => (input[k] !== undefined ? input[k] : (row?.[k] ?? null));
  return {
    provider: input.provider ?? row?.provider ?? 'R2',
    accountId: pick('accountId'),
    endpoint: pick('endpoint'),
    region: pick('region'),
    forcePathStyle: input.forcePathStyle ?? row?.forcePathStyle ?? false,
    publicBucket: pick('publicBucket'),
    publicBaseUrl: pick('publicBaseUrl'),
    privateBucket: pick('privateBucket'),
  };
}

/**
 * The OWNER's «التخزين (R2 / S3)» section (v1.75-social, D222, CONVENTIONS §10.72), D196's pattern. Owns
 * `storage_settings`: the provider (R2 or S3), the account / endpoint, the access key id and the secret (sealed
 * AES-256-GCM with a key derived from ADMIN_TOTP_KEY, `storage-settings/v1`; write-only), the public bucket with its
 * public base URL and the private bucket; the «تفعيل» switch; the last «اختبار الاتصال». Every change needs the
 * authenticator code again and a reason, and is audited with the last 4 characters only. Turning on (or changing the
 * connection while on) runs a real round trip on both buckets first.
 */
@Injectable()
export class StorageSettingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    private readonly store: StorageSettingsStore,
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

  private async people(ids: (string | null | undefined)[]): Promise<Map<string, Person>> {
    const wanted = [...new Set(ids.filter((x): x is string => !!x))];
    if (wanted.length === 0) return new Map();
    const rows = await this.prisma.user.findMany({
      where: { id: { in: wanted } },
      select: { id: true, profile: { select: { displayName: true } } },
    });
    return new Map(rows.map((u) => [u.id, { id: u.id, displayName: u.profile?.displayName ?? '' }]));
  }

  async view(): Promise<AdminStorageSettingsDto> {
    const box = this.box();
    const row = await this.prisma.storageSettings.findUnique({ where: { id: 1 } });
    const r = resolveStorageSettings(row, this.config, box);
    const who = await this.people([row?.accessKeyIdSetById, row?.secretAccessKeySetById, row?.lastTestById]);
    const key = (
      last4: string | null | undefined,
      by: string | null | undefined,
      at: Date | null | undefined,
    ) => (last4 ? { last4, setBy: (by && who.get(by)) || null, setAt: at?.toISOString() ?? null } : null);
    const t = targetOf(merged(row, {}));
    const e = this.config.media;
    const envConfigured = Boolean(e.s3.bucket && e.s3.accessKeyId && e.s3.secretAccessKey);
    const lastTest =
      row?.lastTest && typeof row.lastTest === 'object'
        ? {
            ...(row.lastTest as unknown as StorageTestReport),
            by: (row.lastTestById && who.get(row.lastTestById)) || null,
          }
        : null;
    return {
      status:
        r.source === 'panel'
          ? 'active'
          : r.source === 'env' && r.uploadsEnabled
            ? 'env'
            : row?.accessKeyIdEnc || row?.publicBucket
              ? 'off'
              : 'not_configured',
      source: r.source,
      uploadsEnabled: r.uploadsEnabled,
      publicBaseUrl: r.publicBaseUrl ?? null,
      enabled: row?.enabled ?? false,
      panel: {
        provider: t.provider,
        accountId: t.accountId,
        endpoint: t.endpoint,
        region: t.provider === 'R2' ? 'auto' : (row?.region ?? null),
        forcePathStyle: t.forcePathStyle,
        publicBucket: t.publicBucket,
        publicBaseUrl: t.publicBaseUrl,
        privateBucket: t.privateBucket,
        accessKeyId: key(row?.accessKeyIdLast4, row?.accessKeyIdSetById, row?.accessKeyIdSetAt),
        secretAccessKey: key(
          row?.secretAccessKeyLast4,
          row?.secretAccessKeySetById,
          row?.secretAccessKeySetAt,
        ),
        missing: missingFields(t, {
          accessKeyId: !!row?.accessKeyIdEnc,
          secretAccessKey: !!row?.secretAccessKeyEnc,
        }),
        updatedAt: row?.updatedAt.toISOString() ?? null,
      },
      env: {
        configured: envConfigured,
        uploadsEnabled: e.uploadsEnabled,
        endpoint: e.s3.endpoint ?? null,
        region: e.s3.region,
        bucket: e.s3.bucket ?? null,
        publicBaseUrl: e.publicBaseUrl ?? null,
        accessKeyIdLast4: e.s3.accessKeyId ? e.s3.accessKeyId.slice(-4) : null,
      },
      panelIgnored: r.panelIgnored,
      lastTest,
      publicPrefix: PUBLIC_KEY_PREFIX,
      healthcheckPrefix: HEALTHCHECK_PREFIX,
      connectionTestSkippable: !this.production,
    };
  }

  /** The stored keys, opened (null when missing or sealed with another ADMIN_TOTP_KEY). */
  private storedKeys(row: StorageSettingsRow | null, box: AdminSecretBox) {
    return {
      accessKeyId: row?.accessKeyIdEnc ? box.open(row.accessKeyIdEnc, STORAGE_AAD.accessKeyId) : null,
      secretAccessKey: row?.secretAccessKeyEnc
        ? box.open(row.secretAccessKeyEnc, STORAGE_AAD.secretAccessKey)
        : null,
    };
  }

  /** Production: https on a domain name (no plain http, no IP literal, no localhost) for both URLs. */
  private checkUrls(t: StorageTarget): void {
    if (!this.production) return;
    for (const [field, url] of [
      ['endpoint', t.endpoint],
      ['publicBaseUrl', t.publicBaseUrl],
    ] as const) {
      if (!url) continue;
      const u = new URL(url);
      const host = u.hostname.replace(/^\[|\]$/g, '');
      if (
        u.protocol !== 'https:' ||
        isIP(host) !== 0 ||
        host === 'localhost' ||
        host.endsWith('.localhost')
      ) {
        throw refuse('https_required', field);
      }
    }
  }

  private checkBuckets(t: StorageTarget): void {
    if (t.publicBucket && t.privateBucket && t.publicBucket === t.privateBucket) {
      throw refuse('same_bucket', 'privateBucket');
    }
  }

  /** «اختبار الاتصال» (no code needed: nothing is saved but the result). Audited with the target and the outcome. */
  async test(input: TestStorageSettingsInput, ctx: AdminContext): Promise<StorageTestReport> {
    const box = this.box();
    const row = await this.prisma.storageSettings.findUnique({ where: { id: 1 } });
    const t = targetOf(merged(row, input));
    this.checkUrls(t);
    this.checkBuckets(t);
    const stored = this.storedKeys(row, box);
    const accessKeyId = input.accessKeyId ?? stored.accessKeyId;
    const secretAccessKey = input.secretAccessKey ?? stored.secretAccessKey;
    const missing = missingFields(t, { accessKeyId: !!accessKeyId, secretAccessKey: !!secretAccessKey });
    if (missing.length > 0)
      throw AppException.validation(missing.map((field) => ({ field, issue: 'required' })));
    const report = await this.roundTrip(t, accessKeyId!, secretAccessKey!);
    await this.saveReport(report, ctx);
    return report;
  }

  private async saveReport(report: StorageTestReport, ctx: AdminContext): Promise<void> {
    const now = this.clock.now();
    const data = {
      lastTestAt: new Date(report.at),
      lastTestOk: report.ok,
      lastTestById: ctx.userId,
      lastTest: report as unknown as Prisma.InputJsonValue,
    };
    await this.prisma.$transaction(async (tx) => {
      await tx.storageSettings.upsert({
        where: { id: 1 },
        create: { id: 1, updatedAt: now, ...data },
        update: data,
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.STORAGE_SETTINGS_TEST,
        actorUserId: ctx.userId,
        targetType: 'storage_settings',
        metadata: {
          target: { ...report.target },
          accessKeyId: report.accessKeyIdLast4 ? `…${report.accessKeyIdLast4}` : null,
          result: report.ok ? 'ok' : 'failed',
          failed: report.steps.filter((s) => !s.ok).map((s) => `${s.bucket}.${s.step}:${s.issue ?? ''}`),
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
  }

  /**
   * The real round trip on each bucket, under `_healthcheck/`: put a tiny object, head it, read it back (through the
   * public URL for the public bucket; for the private one, check that neither the public URL nor an anonymous request
   * reads it), delete it. Never throws: each step's outcome is in the report.
   */
  async roundTrip(
    t: StorageTarget,
    accessKeyId: string,
    secretAccessKey: string,
  ): Promise<StorageTestReport> {
    const settings = s3SettingsOf(t, accessKeyId, secretAccessKey);
    const client = newS3Client(settings, {
      maxAttempts: 1,
      requestHandler: {
        connectionTimeout: STORAGE_TEST_STEP_TIMEOUT_MS,
        requestTimeout: STORAGE_TEST_STEP_TIMEOUT_MS,
      },
    });
    const steps: StorageTestStep[] = [];
    try {
      for (const which of ['public', 'private'] as const) {
        const bucket = which === 'public' ? t.publicBucket! : t.privateBucket!;
        const one = new S3ObjectStorage({ ...settings, bucket, privateBucket: null }, client);
        const id = uuidv7(this.clock.now().getTime());
        const key = `${HEALTHCHECK_PREFIX}${id}.txt`;
        const body = Buffer.from(`kabso storage check ${id}\n`, 'utf8');
        const run = async (
          step: TestStepName,
          fn: () => Promise<{ issue: TestIssue; detail: string | null } | null>,
        ): Promise<boolean> => {
          const started = Date.now();
          let failure: { issue: TestIssue; detail: string | null } | null;
          try {
            failure = await fn();
          } catch (err) {
            failure = issueOfError(err);
          }
          steps.push({
            bucket: which,
            step,
            ok: failure === null,
            ms: Date.now() - started,
            issue: failure?.issue ?? null,
            detail: failure?.detail ?? null,
          });
          return failure === null;
        };
        const put = await run('put', async () => {
          await one.put(key, body, 'text/plain; charset=utf-8', 'no-store');
          return null;
        });
        if (put) {
          const ok =
            (await run('head', async () => {
              const head = await one.head(key);
              return head && head.size === body.length ? null : { issue: 'mismatch', detail: 'head' };
            })) &&
            (await run('get', async () => {
              const got = await one.get(key, 1024);
              return got?.equals(body) ? null : { issue: 'mismatch', detail: 'get' };
            }));
          if (ok && which === 'public') {
            await run('public_read', async () => {
              const res = await this.fetchPlain(`${t.publicBaseUrl}/${key}`);
              if (res.status !== 200) return { issue: 'not_public', detail: `HTTP ${res.status}` };
              return res.body.equals(body) ? null : { issue: 'mismatch', detail: 'public_read' };
            });
          }
          if (ok && which === 'private') {
            await run('not_public', async () => {
              const urls = [`${t.publicBaseUrl}/${key}`, anonymousUrl(t, bucket, key)];
              for (const url of urls) {
                const res = await this.fetchPlain(url).catch(() => null);
                if (res?.status === 200 && res.body.equals(body)) {
                  return { issue: 'publicly_readable', detail: new URL(url).host };
                }
              }
              return null;
            });
          }
          await run('delete', async () => {
            await one.delete([key]);
            return (await one.head(key)) === null ? null : { issue: 'mismatch', detail: 'delete' };
          });
        }
      }
    } finally {
      client.destroy();
    }
    return {
      ok: steps.length > 0 && steps.every((s) => s.ok),
      at: this.clock.now().toISOString(),
      target: t,
      accessKeyIdLast4: accessKeyId.slice(-4),
      steps,
    };
  }

  /** An unauthenticated GET (at most 4 KiB read), as a browser or the app would. */
  private async fetchPlain(url: string): Promise<{ status: number; body: Buffer }> {
    const res = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      headers: { 'Cache-Control': 'no-cache' },
      signal: AbortSignal.timeout(STORAGE_TEST_STEP_TIMEOUT_MS),
    });
    const bytes = Buffer.from(await res.arrayBuffer()).subarray(0, 4096);
    return { status: res.status, body: bytes };
  }

  /** Saves what the body names (TOTP again + reason); turning on, or a new connection while on, is tested first. */
  async update(input: UpdateStorageSettingsInput, ctx: AdminContext): Promise<AdminStorageSettingsDto> {
    const box = this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const before = await this.prisma.storageSettings.findUnique({ where: { id: 1 } });
    const t = targetOf(merged(before, input));
    this.checkUrls(t);
    this.checkBuckets(t);
    const stored = this.storedKeys(before, box);
    const accessKeyId = input.accessKeyId ?? stored.accessKeyId;
    const secretAccessKey = input.secretAccessKey ?? stored.secretAccessKey;
    const enabled = input.enabled ?? before?.enabled ?? false;
    const connectionChanged = CONNECTION_FIELDS.some((k) => input[k] !== undefined);
    let connectionTest: 'ok' | 'skipped' | null = null;
    if (enabled) {
      const missing = missingFields(t, { accessKeyId: !!accessKeyId, secretAccessKey: !!secretAccessKey });
      if (missing.length > 0) {
        throw new AppException(
          ErrorCode.ADMIN_ACTION_REFUSED,
          REFUSAL_MESSAGE.storage_incomplete,
          missing.map((field) => ({ field, issue: 'storage_incomplete' })),
        );
      }
      if (connectionChanged || !before?.enabled) {
        if (input.skipConnectionTest) {
          if (this.production) throw refuse('storage_test_required', 'skipConnectionTest');
          connectionTest = 'skipped';
        } else {
          const report = await this.roundTrip(t, accessKeyId!, secretAccessKey!);
          await this.saveReport(report, ctx);
          if (!report.ok) throw refuse('storage_test_failed', 'enabled');
          connectionTest = 'ok';
        }
      }
    }
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`INSERT INTO storage_settings (id, updated_at) VALUES (1, ${now}) ON CONFLICT (id) DO NOTHING`;
      await tx.$queryRaw`SELECT id FROM storage_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.storageSettings.findUniqueOrThrow({ where: { id: 1 } });
      const data: Prisma.StorageSettingsUncheckedUpdateInput = {
        updatedAt: now,
        updatedById: ctx.userId,
        enabled,
      };
      for (const k of [
        'provider',
        'accountId',
        'endpoint',
        'region',
        'forcePathStyle',
        'publicBucket',
        'publicBaseUrl',
        'privateBucket',
      ] as const) {
        if (input[k] !== undefined) Object.assign(data, { [k]: input[k] });
      }
      if (input.accessKeyId !== undefined) {
        Object.assign(data, {
          accessKeyIdEnc: box.seal(input.accessKeyId, STORAGE_AAD.accessKeyId),
          accessKeyIdLast4: input.accessKeyId.slice(-4),
          accessKeyIdSetAt: now,
          accessKeyIdSetById: ctx.userId,
        });
      }
      if (input.secretAccessKey !== undefined) {
        Object.assign(data, {
          secretAccessKeyEnc: box.seal(input.secretAccessKey, STORAGE_AAD.secretAccessKey),
          secretAccessKeyLast4: input.secretAccessKey.slice(-4),
          secretAccessKeySetAt: now,
          secretAccessKeySetById: ctx.userId,
        });
      }
      const after = await tx.storageSettings.update({ where: { id: 1 }, data });
      const b = summaryOf(row);
      const a = summaryOf(after);
      await this.audit.recordIn(tx, {
        action: AuditAction.STORAGE_SETTINGS_UPDATE,
        actorUserId: ctx.userId,
        targetType: 'storage_settings',
        metadata: {
          before: b,
          after: a,
          changed: (Object.keys(a) as (keyof typeof a)[]).filter(
            (k) =>
              b[k] !== a[k] ||
              (k === 'accessKeyId' && input.accessKeyId !== undefined) ||
              (k === 'secretAccessKey' && input.secretAccessKey !== undefined),
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

  /** Removes the panel's storage settings (TOTP again + reason): the server's env applies again (or 503). */
  async clear(input: ClearStorageSettingsInput, ctx: AdminContext): Promise<AdminStorageSettingsDto> {
    this.box();
    await this.auth.reauthenticate(ctx, input.totpCode);
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM storage_settings WHERE id = 1 FOR UPDATE`;
      const row = await tx.storageSettings.findUnique({ where: { id: 1 } });
      if (
        !row ||
        (!row.accessKeyIdEnc && !row.secretAccessKeyEnc && !row.publicBucket && !row.privateBucket)
      ) {
        throw refuse('storage_nothing_to_clear', 'enabled');
      }
      const after = await tx.storageSettings.update({
        where: { id: 1 },
        data: {
          enabled: false,
          provider: 'R2',
          accountId: null,
          endpoint: null,
          region: null,
          forcePathStyle: false,
          accessKeyIdEnc: null,
          accessKeyIdLast4: null,
          accessKeyIdSetAt: null,
          accessKeyIdSetById: null,
          secretAccessKeyEnc: null,
          secretAccessKeyLast4: null,
          secretAccessKeySetAt: null,
          secretAccessKeySetById: null,
          publicBucket: null,
          publicBaseUrl: null,
          privateBucket: null,
          updatedAt: now,
          updatedById: ctx.userId,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.STORAGE_SETTINGS_CLEAR,
        actorUserId: ctx.userId,
        targetType: 'storage_settings',
        metadata: {
          before: summaryOf(row),
          after: summaryOf(after),
          fallback: this.config.media.uploadsEnabled ? 'env' : 'none',
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
}

/** The URL an anonymous client would read the object at, straight from the S3 endpoint (path style). */
function anonymousUrl(t: StorageTarget, bucket: string, key: string): string {
  return t.endpoint
    ? `${t.endpoint.replace(/\/+$/, '')}/${bucket}/${key}`
    : `https://${bucket}.s3.${t.region}.amazonaws.com/${key}`;
}
