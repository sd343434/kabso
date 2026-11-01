import { createHmac } from 'node:crypto';
import { createServer, type IncomingMessage, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  createDiditApi,
  DiditKeyRejectedError,
  DiditRequestError,
  DiditUnreachableError,
} from './didit-api.js';
import {
  canonicalJson,
  countsFor,
  documentHash,
  documentHashKey,
  factsOf,
  mediaOf,
  missingFields,
  newKycSecretBox,
  KYC_AAD,
  signWebhookV2,
  startKycSchema,
  statusOf,
  updateKycSettingsSchema,
  verifyWebhook,
  workflowFor,
} from './kyc.rules.js';

const SECRET = ['whsec', 'unit', 'test', 'value', '0001'].join('_');
const NOW = Date.UTC(2026, 10, 1, 12, 0, 0);
const TS = String(Math.floor(NOW / 1000));
/** A made-up 12-character session token (built at run time). */
const TOKEN = ['tok', 'en', 'unit', 'test'].join('').slice(0, 12);

describe('D227 Didit status mapping', () => {
  it('maps every documented Didit status (case-insensitive) and nothing else', () => {
    expect(statusOf('Not Started')).toBe('NOT_STARTED');
    expect(statusOf('In Progress')).toBe('IN_PROGRESS');
    expect(statusOf('Awaiting User')).toBe('IN_PROGRESS');
    expect(statusOf('Resubmitted')).toBe('IN_PROGRESS');
    expect(statusOf('In Review')).toBe('IN_REVIEW');
    expect(statusOf('Approved')).toBe('APPROVED');
    expect(statusOf('APPROVED')).toBe('APPROVED');
    expect(statusOf('Declined')).toBe('DECLINED');
    expect(statusOf('Expired')).toBe('EXPIRED');
    expect(statusOf('Kyc Expired')).toBe('EXPIRED');
    expect(statusOf('Abandoned')).toBe('ABANDONED');
    expect(statusOf('Something New')).toBeNull();
  });
});

describe('D227 webhook signature', () => {
  const body = { b: 1, a: { z: 'نورة', y: [2, { d: 1, c: 2 }] }, decision: null, score: 95.4 };
  const raw = Buffer.from(JSON.stringify(body));
  const v2 = createHmac('sha256', SECRET).update(canonicalJson(body)).digest('hex');

  it('canonical JSON sorts keys recursively, is compact and keeps Unicode unescaped', () => {
    expect(canonicalJson(body)).toBe(
      '{"a":{"y":[2,{"c":2,"d":1}],"z":"نورة"},"b":1,"decision":null,"score":95.4}',
    );
    expect(canonicalJson(JSON.parse('{"x":1.0}'))).toBe('{"x":1}');
    expect(signWebhookV2(SECRET, body)).toBe(v2);
  });

  it('accepts X-Signature-V2 and the raw-body X-Signature within ±300 s', () => {
    const base = { raw, parsed: body, timestamp: TS, signature: undefined, signatureV2: undefined };
    expect(verifyWebhook({ ...base, signatureV2: v2 }, [SECRET], NOW)).toEqual({ ok: true, scheme: 'v2' });
    expect(verifyWebhook({ ...base, signatureV2: v2.toUpperCase() }, [SECRET], NOW).ok).toBe(true);
    const rawSig = createHmac('sha256', SECRET).update(raw).digest('hex');
    expect(verifyWebhook({ ...base, signature: rawSig }, [SECRET], NOW)).toEqual({ ok: true, scheme: 'raw' });
    expect(verifyWebhook({ ...base, signatureV2: v2 }, [SECRET], NOW + 299_000).ok).toBe(true);
  });

  it('refuses a wrong secret, a tampered body, an old or future timestamp, missing headers', () => {
    const base = { raw, parsed: body, timestamp: TS, signature: undefined, signatureV2: v2 };
    expect(verifyWebhook(base, ['other-secret-value-xyz'], NOW)).toEqual({
      ok: false,
      issue: 'invalid_signature',
    });
    expect(verifyWebhook({ ...base, parsed: { ...body, b: 2 } }, [SECRET], NOW).ok).toBe(false);
    expect(verifyWebhook(base, [SECRET], NOW + 301_000)).toEqual({ ok: false, issue: 'stale_timestamp' });
    expect(verifyWebhook(base, [SECRET], NOW - 301_000)).toEqual({ ok: false, issue: 'stale_timestamp' });
    expect(verifyWebhook({ ...base, timestamp: undefined }, [SECRET], NOW)).toEqual({
      ok: false,
      issue: 'missing_timestamp',
    });
    expect(verifyWebhook({ ...base, timestamp: 'abc' }, [SECRET], NOW).ok).toBe(false);
    expect(verifyWebhook({ ...base, signatureV2: undefined }, [SECRET], NOW)).toEqual({
      ok: false,
      issue: 'missing_signature',
    });
    expect(verifyWebhook({ ...base, signatureV2: 'zz' }, [SECRET], NOW).ok).toBe(false);
  });
});

describe('D227 what a decision keeps', () => {
  const decision = {
    session_number: 43762,
    id_verifications: [
      {
        status: 'Approved',
        document_number: 'CAA 000-000',
        first_name: 'Carmen',
        last_name: 'Española',
        full_name: 'Carmen Española Española',
        date_of_birth: '1980-01-01',
        issuing_state: 'esp',
        address: 'Avda de Madrid 34',
        portrait_image: 'https://media.example/p.jpg?x=1',
        front_image: 'https://media.example/f.jpg?x=1',
        back_image: 'http://insecure.example/b.jpg',
        warnings: [{ risk: 'DOCUMENT_EXPIRED' }],
      },
    ],
    liveness_checks: [
      { warnings: [{ risk: 'LOW_LIVENESS_SCORE' }, { risk: 'LOW_LIVENESS_SCORE' }, { risk: 'bad code' }] },
    ],
    face_matches: [{ warnings: [] }],
  };

  it('keeps the name, birth date, country, number (for hashing) and reasons only when declined / in review', () => {
    const f = factsOf('Declined', decision);
    expect(f).toMatchObject({
      status: 'DECLINED',
      fullName: 'Carmen Española Española',
      documentCountry: 'ESP',
      documentNumber: 'CAA 000-000',
      sessionNumber: 43762,
      reasons: ['DOCUMENT_EXPIRED', 'LOW_LIVENESS_SCORE'],
    });
    expect(f.dateOfBirth?.toISOString().slice(0, 10)).toBe('1980-01-01');
    expect(JSON.stringify(f)).not.toContain('Madrid');
    expect(factsOf('Approved', decision).reasons).toEqual([]);
    expect(factsOf('In Progress', null)).toMatchObject({
      status: 'IN_PROGRESS',
      fullName: null,
      documentNumber: null,
    });
    expect(
      factsOf('Approved', {
        id_verifications: [{ first_name: 'A', last_name: 'B', date_of_birth: '1990-02-30' }],
      }),
    ).toMatchObject({ fullName: 'A B', dateOfBirth: null });
  });

  it('only https image links, never stored', () => {
    expect(mediaOf(decision)).toEqual({
      portrait: 'https://media.example/p.jpg?x=1',
      front: 'https://media.example/f.jpg?x=1',
      back: null,
      liveness: null,
    });
  });

  it('hashes a document number with the server key, normalized (spaces, dashes, case)', () => {
    const key = documentHashKey('admin-totp-test-key-0123456789-abcdefghijklmnop')!;
    const a = documentHash(key, 'ESP', 'CAA 000-000');
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(documentHash(key, 'esp', 'caa000000')).toBe(a);
    expect(documentHash(key, 'FRA', 'CAA000000')).not.toBe(a);
    expect(
      documentHash(documentHashKey('another-admin-totp-key-0123456789-abcdef')!, 'ESP', 'CAA000000'),
    ).not.toBe(a);
    expect(documentHash(key, 'ESP', '-')).toBeNull();
    expect(documentHashKey(null)).toBeNull();
  });
});

describe('D227 settings rules', () => {
  const row = {
    workflowId: 'a1111111-1111-4111-8111-111111111111',
    workflowIdHost: null,
    workflowIdAgency: 'b2222222-2222-4222-8222-222222222222',
    workflowIdRecharge: null,
  };

  it('a purpose runs on its own workflow, else the default; an approval counts across purposes on the same workflow', () => {
    expect(workflowFor(row, 'HOST_APPLICATION')).toBe(row.workflowId);
    expect(workflowFor(row, 'AGENCY_OPEN')).toBe(row.workflowIdAgency);
    expect(workflowFor(null, 'AGENCY_OPEN')).toBeNull();
    const hostCheck = { purpose: 'HOST_APPLICATION' as const, workflowId: row.workflowId };
    expect(countsFor(hostCheck, 'HOST_APPLICATION', row)).toBe(true);
    expect(countsFor(hostCheck, 'RECHARGE_AGENT', row)).toBe(true);
    expect(countsFor(hostCheck, 'AGENCY_OPEN', row)).toBe(false);
    expect(
      countsFor(
        { purpose: 'AGENCY_OPEN', workflowId: 'c3333333-3333-4333-8333-333333333333' },
        'AGENCY_OPEN',
        row,
      ),
    ).toBe(true);
  });

  it('the shapes: purposes, the update needs a change, the code and a reason', () => {
    expect(startKycSchema.safeParse({ purpose: 'AGENCY_OPEN', language: 'en' }).success).toBe(true);
    expect(startKycSchema.safeParse({ purpose: 'X' }).success).toBe(false);
    expect(startKycSchema.safeParse({ purpose: 'AGENCY_OPEN', extra: 1 }).success).toBe(false);
    expect(updateKycSettingsSchema.safeParse({ totpCode: '123456', reason: 'r' }).success).toBe(false);
    expect(
      updateKycSettingsSchema.safeParse({ enabled: true, totpCode: '123456', reason: 'r' }).success,
    ).toBe(true);
    expect(
      updateKycSettingsSchema.safeParse({ apiKey: 'short', totpCode: '123456', reason: 'r' }).success,
    ).toBe(false);
    expect(
      updateKycSettingsSchema.safeParse({ maxSessionsPerDay: 11, totpCode: '123456', reason: 'r' }).success,
    ).toBe(false);
    expect(missingFields({ apiKey: true, webhookSecret: false, workflowId: null })).toEqual([
      'webhookSecret',
      'workflowId',
    ]);
  });

  it('seals the secrets with its own key and per-column AAD', () => {
    const box = newKycSecretBox('admin-totp-test-key-0123456789-abcdefghijklmnop')!;
    const sealed = box.seal('didit-api-key-value-0001', KYC_AAD.apiKey);
    expect(sealed).not.toContain('didit');
    expect(box.open(sealed, KYC_AAD.apiKey)).toBe('didit-api-key-value-0001');
    expect(box.open(sealed, KYC_AAD.webhookSecret)).toBeNull();
    expect(newKycSecretBox(null)).toBeNull();
  });
});

describe('D227 Didit client (against a local stub, no network)', () => {
  let server: Server;
  let base = '';
  const seen: { method: string; url: string; key: string | undefined; body: string }[] = [];
  let reply: (req: IncomingMessage) => { status: number; body: string } = () => ({ status: 200, body: '{}' });

  beforeAll(async () => {
    server = createServer((req, res) => {
      let body = '';
      req.on('data', (c: Buffer) => (body += c.toString('utf8')));
      req.on('end', () => {
        seen.push({
          method: req.method ?? '',
          url: req.url ?? '',
          key: req.headers['x-api-key'] as string | undefined,
          body,
        });
        const r = reply(req);
        res.writeHead(r.status, { 'Content-Type': 'application/json' });
        res.end(r.body);
      });
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });
  afterAll(() => new Promise<void>((resolve) => server.close(() => resolve())));

  it('creates a session with the documented body and reads the answer', async () => {
    reply = () => ({
      status: 201,
      body: JSON.stringify({
        session_id: '11111111-2222-3333-4444-555555555555',
        session_number: 43762,
        session_token: TOKEN,
        url: `https://verify.didit.me/ar/session/${TOKEN}`,
        status: 'Not Started',
        workflow_id: '66666666-7777-8888-9999-000000000000',
      }),
    });
    const api = createDiditApi('key-unit-000000000001', base);
    const s = await api.createSession({
      workflowId: '66666666-7777-8888-9999-000000000000',
      vendorData: 'user-1',
      callback: 'kabsolive://kyc/done',
      language: 'ar',
      metadata: { purpose: 'HOST_APPLICATION' },
    });
    expect(s).toEqual({
      sessionId: '11111111-2222-3333-4444-555555555555',
      sessionNumber: 43762,
      url: `https://verify.didit.me/ar/session/${TOKEN}`,
      status: 'Not Started',
      workflowId: '66666666-7777-8888-9999-000000000000',
    });
    const last = seen.at(-1)!;
    expect(last).toMatchObject({ method: 'POST', url: '/v3/session/', key: 'key-unit-000000000001' });
    expect(JSON.parse(last.body)).toEqual({
      workflow_id: '66666666-7777-8888-9999-000000000000',
      vendor_data: 'user-1',
      callback: 'kabsolive://kyc/done',
      metadata: { purpose: 'HOST_APPLICATION' },
      language: 'ar',
    });
  });

  it('reads a decision and the workflows (paginated `results` or a plain list)', async () => {
    reply = (req) =>
      req.url?.startsWith('/v3/session/')
        ? { status: 200, body: JSON.stringify({ status: 'Approved', id_verifications: [] }) }
        : {
            status: 200,
            body: JSON.stringify({
              count: 1,
              results: [
                {
                  uuid: 'w1',
                  workflow_label: 'KYC',
                  status: 'published',
                  is_archived: false,
                  features: 'OCR + LIVENESS',
                },
              ],
            }),
          };
    const api = createDiditApi('key-unit-000000000001', base);
    expect((await api.decision('abc')).status).toBe('Approved');
    expect(seen.at(-1)!.url).toBe('/v3/session/abc/decision/');
    expect(await api.workflows()).toEqual([
      { id: 'w1', label: 'KYC', status: 'published', archived: false, features: 'OCR + LIVENESS' },
    ]);
    reply = () => ({ status: 200, body: JSON.stringify([{ workflow_id: 'w2' }]) });
    expect((await api.workflows())[0]!.id).toBe('w2');
  });

  it('maps errors: 403 → key rejected, 400 → request error, 500 / 429 / bad JSON / no server → unreachable', async () => {
    const api = createDiditApi('key-unit-000000000001', base);
    reply = () => ({ status: 403, body: '{"detail":"You do not have permission to perform this action."}' });
    await expect(api.workflows()).rejects.toBeInstanceOf(DiditKeyRejectedError);
    reply = () => ({ status: 400, body: '{}' });
    await expect(api.workflows()).rejects.toBeInstanceOf(DiditRequestError);
    reply = () => ({ status: 500, body: '{}' });
    await expect(api.workflows()).rejects.toBeInstanceOf(DiditUnreachableError);
    reply = () => ({ status: 429, body: '{}' });
    await expect(api.workflows()).rejects.toBeInstanceOf(DiditUnreachableError);
    reply = () => ({ status: 200, body: 'not json' });
    await expect(api.workflows()).rejects.toBeInstanceOf(DiditUnreachableError);
    await expect(createDiditApi('k', 'http://127.0.0.1:1').workflows()).rejects.toBeInstanceOf(
      DiditUnreachableError,
    );
  });
});
