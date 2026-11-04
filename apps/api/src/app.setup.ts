import { RequestMethod } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module.js';
import { expressErrorHandler } from './common/errors/all-exceptions.filter.js';
import { requestIdMiddleware } from './common/request-id/request-id.js';
import { BANNER_UPLOAD_PATH, GIFT_UPLOAD_PATH } from './modules/admin-panel/admin-v2.controller.js';
import { VIP_UPLOAD_PATH } from './modules/admin-panel/admin-vip.controller.js';
import { STORE_UPLOAD_PATH } from './modules/admin-panel/admin-store.controller.js';
import { STRIPE_WEBHOOK_PATH } from './modules/topup/topup.controller.js';
import { KYC_WEBHOOK_PATH } from './modules/kyc/kyc.rules.js';
import type { AppConfig } from './config/app-config.js';

export const API_PREFIX = 'api/v1';

function noStore(_req: Request, res: Response, next: NextFunction): void {
  res.setHeader('Cache-Control', 'no-store');
  next();
}

/** Applies HTTP-level configuration shared by `main.ts` and the e2e tests. */
export function configureApp(app: NestExpressApplication, config: AppConfig): void {
  app.useLogger(app.get(Logger));
  app.set('trust proxy', config.http.trustProxy);
  // Effective client-IP derivation, logged once so deployments can verify it (SEC-003).
  app
    .get(Logger)
    .log(
      `trust proxy = ${JSON.stringify(config.http.trustProxy)}; Argon2 cap = ${config.argon2.maxConcurrency} ` +
        `(+${config.argon2.maxQueue} queued)`,
      'HttpSetup',
    );
  app.disable('x-powered-by');

  // Order matters: request id first so every later failure can report it.
  app.use(requestIdMiddleware);
  // CONVENTIONS §1 (SEC-006): responses are user-specific and may carry tokens — never cache.
  // Set first so it also covers errors (including body-parser failures). Applied to every
  // response, which is a superset of the required /api/v1 scope.
  app.use(noStore);
  app.use(helmet());
  app.enableCors({
    origin: config.http.corsOrigins.length > 0 ? [...config.http.corsOrigins] : false,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
    allowedHeaders: [
      'Authorization',
      'Content-Type',
      'Accept-Language',
      'X-Request-Id',
      'X-Client',
      'Idempotency-Key',
    ],
    exposedHeaders: ['X-Request-Id', 'Retry-After'],
    maxAge: 600,
  });
  // v1.59-social (D190): Stripe signs the exact bytes of its webhook, so that one path keeps a raw Buffer (read
  // before the JSON parser, which then skips the already-read body). Stripe events stay far below 1 MB.
  app.useBodyParser('raw', {
    type: (req: { url?: string }) => (req.url ?? '').split('?')[0] === STRIPE_WEBHOOK_PATH,
    limit: '1mb',
  });
  // v1.80-kyc (D227): Didit signs its webhook (`X-Signature` over the raw bytes, `X-Signature-V2` over the canonical
  // JSON), so that one path keeps a raw Buffer too; the service parses it. Didit's events stay far below 1 MB.
  app.useBodyParser('raw', {
    type: (req: { url?: string }) => (req.url ?? '').split('?')[0] === KYC_WEBHOOK_PATH,
    limit: '1mb',
  });
  // v1.71-social (D207): the admin panel's gift file uploads are the raw bytes (an SVGA is at most 25 MiB); only that
  // path (v1.59-live, D248: and the banner picture upload, at most 15 MiB, checked by the service; v1.83-social, D258:
  // and the VIP art upload), and only
  // `application/octet-stream`.
  app.useBodyParser('raw', {
    type: (req: { url?: string; headers?: Record<string, string | string[] | undefined> }) =>
      [GIFT_UPLOAD_PATH, BANNER_UPLOAD_PATH, VIP_UPLOAD_PATH, STORE_UPLOAD_PATH].includes(
        (req.url ?? '').split('?')[0] ?? '',
      ) && String(req.headers?.['content-type'] ?? '').startsWith('application/octet-stream'),
    limit: '26mb',
  });
  app.useBodyParser('json', { limit: config.http.bodyLimit, strict: true });
  // CP-010: the media server's signed webhook (`application/webhook+json`) is verified against
  // its exact bytes, so that one content type is kept raw (a Buffer); no route but the webhook
  // accepts it.
  app.useBodyParser('raw', { type: 'application/webhook+json', limit: config.http.bodyLimit });
  // Body-parser failures happen before routing; render them with the contract envelope.
  app.use(expressErrorHandler);

  app.setGlobalPrefix(API_PREFIX, {
    exclude: [
      { path: 'health/live', method: RequestMethod.GET },
      { path: 'health/ready', method: RequestMethod.GET },
      { path: 'internal/livekit/webhook', method: RequestMethod.POST },
      // v1.59-social (D190): the top-up website's pages and assets.
      { path: 'topup', method: RequestMethod.GET },
      { path: 'topup/success', method: RequestMethod.GET },
      { path: 'topup/cancel', method: RequestMethod.GET },
      { path: 'topup/assets/topup.js', method: RequestMethod.GET },
      { path: 'topup/assets/topup.css', method: RequestMethod.GET },
    ],
  });
  app.enableShutdownHooks();
}

export async function createApp(config: AppConfig): Promise<NestExpressApplication> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule.register(config), {
    bodyParser: false,
    bufferLogs: true,
  });
  configureApp(app, config);
  return app;
}
