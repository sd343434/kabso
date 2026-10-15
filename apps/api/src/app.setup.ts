import { RequestMethod } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module.js';
import { expressErrorHandler } from './common/errors/all-exceptions.filter.js';
import { requestIdMiddleware } from './common/request-id/request-id.js';
import type { AppConfig } from './config/app-config.js';

export const API_PREFIX = 'api/v1';

/** Applies HTTP-level configuration shared by `main.ts` and the e2e tests. */
export function configureApp(app: NestExpressApplication, config: AppConfig): void {
  app.useLogger(app.get(Logger));
  app.set('trust proxy', config.http.trustProxy);
  app.disable('x-powered-by');

  // Order matters: request id first so every later failure can report it.
  app.use(requestIdMiddleware);
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
  app.useBodyParser('json', { limit: config.http.bodyLimit, strict: true });
  // Body-parser failures happen before routing; render them with the contract envelope.
  app.use(expressErrorHandler);

  app.setGlobalPrefix(API_PREFIX, {
    exclude: [
      { path: 'health/live', method: RequestMethod.GET },
      { path: 'health/ready', method: RequestMethod.GET },
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
