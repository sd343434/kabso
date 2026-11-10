import { randomBytes } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { loadWhatsAppSecrets } from './graph-client.js';
import {
  e164Of,
  fillTemplate,
  mediaAllowed,
  mediaKey,
  parseWebhook,
  phoneSearchOf,
  previewOf,
  signatureOf,
  signatureValid,
  statusAdvances,
  verifyTokenMatches,
  windowOf,
} from './whatsapp-core.js';
import { maskedPhone } from './whatsapp-webhook.service.js';

const NOW = new Date('2026-11-10T12:00:00Z');
const ts = (d: Date) => String(Math.floor(d.getTime() / 1000));

function envelope(value: Record<string, unknown>) {
  return {
    object: 'whatsapp_business_account',
    entry: [
      {
        id: '1111',
        changes: [
          {
            field: 'messages',
            value: { messaging_product: 'whatsapp', metadata: { phone_number_id: '5550001' }, ...value },
          },
        ],
      },
    ],
  };
}

describe('D355 webhook signature (X-Hub-Signature-256)', () => {
  const secret = 'app-secret-for-tests';
  const raw = Buffer.from('{"object":"whatsapp_business_account"}');

  it('accepts the HMAC of the exact bytes and refuses anything else', () => {
    expect(signatureValid(raw, signatureOf(raw, secret), secret)).toBe(true);
    expect(
      signatureValid(raw, signatureOf(raw, secret).toUpperCase().replace('SHA256', 'sha256'), secret),
    ).toBe(true);
    expect(signatureValid(raw, signatureOf(raw, 'other'), secret)).toBe(false);
    expect(signatureValid(Buffer.from(`${raw.toString()} `), signatureOf(raw, secret), secret)).toBe(false);
    expect(signatureValid(raw, undefined, secret)).toBe(false);
    expect(signatureValid(raw, 'sha1=abc', secret)).toBe(false);
    expect(signatureValid(raw, 'sha256=zz', secret)).toBe(false);
  });

  it('compares the verify token exactly', () => {
    expect(verifyTokenMatches('token-1234', 'token-1234')).toBe(true);
    expect(verifyTokenMatches('token-123', 'token-1234')).toBe(false);
    expect(verifyTokenMatches(['token-1234'], 'token-1234')).toBe(false);
    expect(verifyTokenMatches('', 'token-1234')).toBe(false);
  });
});

describe('D355 webhook payload', () => {
  it('parses text, media, location, reaction and contacts messages with the profile name', () => {
    const body = envelope({
      contacts: [{ profile: { name: 'سارة' }, wa_id: '966512345678' }],
      messages: [
        { from: '966512345678', id: 'wamid.T1', timestamp: ts(NOW), type: 'text', text: { body: 'مرحبا' } },
        {
          from: '966512345678',
          id: 'wamid.I1',
          timestamp: ts(NOW),
          type: 'image',
          image: { id: 'media-1', mime_type: 'image/jpeg', caption: 'صورة' },
        },
        {
          from: '966512345678',
          id: 'wamid.A1',
          timestamp: ts(NOW),
          type: 'audio',
          audio: { id: 'media-2', mime_type: 'audio/ogg; codecs=opus', voice: true },
        },
        {
          from: '966512345678',
          id: 'wamid.L1',
          timestamp: ts(NOW),
          type: 'location',
          location: { latitude: 24.7, longitude: 46.6, name: 'الرياض' },
        },
        {
          from: '966512345678',
          id: 'wamid.R1',
          timestamp: ts(NOW),
          type: 'reaction',
          reaction: { message_id: 'wamid.OUT1', emoji: '👍' },
        },
        { from: '966512345678', id: 'wamid.X1', timestamp: ts(NOW), type: 'ephemeral' },
      ],
    });
    const events = parseWebhook(body, NOW);
    expect(events.map((e) => (e.kind === 'message' ? e.type : e.kind))).toEqual([
      'TEXT',
      'IMAGE',
      'AUDIO',
      'LOCATION',
      'REACTION',
      'UNSUPPORTED',
    ]);
    const [text, image, audio, loc, reaction] = events as Extract<
      (typeof events)[number],
      { kind: 'message' }
    >[];
    expect(text).toMatchObject({
      phoneE164: '+966512345678',
      profileName: 'سارة',
      body: 'مرحبا',
      phoneNumberId: '5550001',
    });
    expect(image!.media).toEqual({ id: 'media-1', mime: 'image/jpeg', filename: null, voice: false });
    expect(image!.body).toBe('صورة');
    expect(audio!.media?.voice).toBe(true);
    expect(loc!.location).toEqual({ latitude: 24.7, longitude: 46.6, name: 'الرياض' });
    expect(reaction!.reaction).toEqual({ emoji: '👍', toWaMessageId: 'wamid.OUT1' });
  });

  it('parses statuses with the failure code and ignores other objects, fields and bad ids', () => {
    const body = envelope({
      statuses: [
        { id: 'wamid.O1', status: 'delivered', timestamp: ts(NOW), recipient_id: '966512345678' },
        {
          id: 'wamid.O2',
          status: 'failed',
          timestamp: ts(NOW),
          errors: [{ code: 131026, title: 'Message undeliverable' }],
        },
        { id: 'wamid.O3', status: 'deleted' },
        { id: 'bad id with spaces', status: 'read' },
      ],
    });
    expect(parseWebhook(body, NOW)).toEqual([
      expect.objectContaining({ kind: 'status', waMessageId: 'wamid.O1', status: 'DELIVERED' }),
      expect.objectContaining({
        kind: 'status',
        waMessageId: 'wamid.O2',
        status: 'FAILED',
        errorCode: 131026,
      }),
    ]);
    expect(parseWebhook({ object: 'page', entry: [] }, NOW)).toEqual([]);
    expect(
      parseWebhook({ ...body, entry: [{ changes: [{ field: 'account_update', value: {} }] }] }, NOW),
    ).toEqual([]);
    expect(parseWebhook('nope', NOW)).toEqual([]);
  });

  it('refuses a sender that is not a phone number and a timestamp in the future', () => {
    const body = envelope({
      messages: [
        { from: 'abc', id: 'wamid.1', type: 'text', text: { body: 'x' } },
        { from: '15551234567', id: 'wamid.2', timestamp: '99999999999', type: 'text', text: { body: 'y' } },
      ],
    });
    const events = parseWebhook(body, NOW);
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ phoneE164: '+15551234567', timestamp: NOW });
  });
});

describe('D355 rules', () => {
  it('the 24-hour window opens with the customer’s last message', () => {
    expect(windowOf(null, NOW)).toEqual({ open: false, closesAt: null });
    const last = new Date(NOW.getTime() - 23 * 3600_000);
    expect(windowOf(last, NOW)).toEqual({ open: true, closesAt: new Date(last.getTime() + 24 * 3600_000) });
    expect(windowOf(new Date(NOW.getTime() - 24 * 3600_000), NOW).open).toBe(false);
  });

  it('statuses only move forward; failed is final', () => {
    expect(statusAdvances('SENT', 'DELIVERED')).toBe(true);
    expect(statusAdvances('READ', 'DELIVERED')).toBe(false);
    expect(statusAdvances('READ', 'FAILED')).toBe(true);
    expect(statusAdvances('FAILED', 'READ')).toBe(false);
  });

  it('phones, previews, media and templates', () => {
    expect(e164Of('966512345678')).toBe('+966512345678');
    expect(e164Of('0512345678')).toBeNull();
    expect(phoneSearchOf('00966 51')).toBe('+96651');
    expect(phoneSearchOf('سارة')).toBeNull();
    expect(previewOf('IMAGE', 'hello   world')).toBe('📷 hello world');
    expect(previewOf('TEXT', 'x'.repeat(300))).toHaveLength(120);
    expect(mediaAllowed('audio/ogg; codecs=opus')).toBe(true);
    expect(mediaAllowed('application/x-msdownload')).toBe(false);
    expect(mediaKey('c', 'm', 'image/jpeg')).toBe('private/whatsapp/c/m.jpg');
    expect(fillTemplate('مرحبا {{1}}، طلبك {{2}}', ['سارة', '42'])).toBe('مرحبا سارة، طلبك 42');
    expect(maskedPhone('+966512345678')).toBe('+9665••••5678');
  });
});

describe('D355 configuration', () => {
  const base = {
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    // Generated per run: never commit a secret-like literal (gitleaks).
    JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
    APP_PUBLIC_URL: 'https://kabso.example/',
  };

  it('is off without settings, refuses a partial set, and reads the secret files at boot', () => {
    const config = loadConfig(base);
    expect(config.whatsapp.credentials).toBeNull();
    expect(config.whatsapp.retentionDays).toBe(180);
    expect(() => loadConfig({ ...base, WHATSAPP_PHONE_NUMBER_ID: '123456' })).toThrow(
      /WHATSAPP_ACCESS_TOKEN_FILE/,
    );
    const token = randomBytes(24).toString('base64url');
    const appSecret = randomBytes(16).toString('hex');
    const verify = randomBytes(16).toString('base64url');
    const dir = mkdtempSync(join(tmpdir(), 'wa-'));
    const file = (n: string, v: string) => {
      const p = join(dir, n);
      writeFileSync(p, v);
      return p;
    };
    const full = loadConfig({
      ...base,
      WHATSAPP_PHONE_NUMBER_ID: '123456',
      WHATSAPP_BUSINESS_ACCOUNT_ID: '654321',
      WHATSAPP_ACCESS_TOKEN_FILE: file('t', `${token}\n`),
      WHATSAPP_APP_SECRET_FILE: file('s', appSecret),
      WHATSAPP_VERIFY_TOKEN_FILE: file('v', 'short'),
    });
    expect(() => loadWhatsAppSecrets(full.whatsapp)).toThrow(/WHATSAPP_VERIFY_TOKEN_FILE/);
    writeFileSync(join(dir, 'v'), verify);
    expect(loadWhatsAppSecrets(full.whatsapp)).toEqual({
      accessToken: token,
      appSecret: appSecret,
      verifyToken: verify,
    });
  });
});
