import type { IncomingMessage } from 'node:http';
import type { Params } from 'nestjs-pino';
import type { AppConfig } from '../config/app-config.js';
import { resolveRequestId } from '../common/request-id/request-id.js';

/**
 * Paths removed from every log line. pino-http does not log bodies, but services may log
 * objects that contain these fields; keep this list broad.
 */
export const REDACT_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["x-api-key"]',
  'res.headers["set-cookie"]',
  'password',
  'newPassword',
  'passwordHash',
  'token',
  'refreshToken',
  'accessToken',
  '*.password',
  '*.newPassword',
  '*.passwordHash',
  '*.token',
  '*.refreshToken',
  '*.accessToken',
  '*.secret',
  // v1.64-social (D196): the Stripe keys the OWNER types into the panel and the code re-entered with them.
  'secretKey',
  'webhookSecret',
  'totpCode',
  '*.secretKey',
  '*.webhookSecret',
  '*.totpCode',
];

export function buildLoggerOptions(config: AppConfig): Params {
  return {
    pinoHttp: {
      level: config.logLevel,
      redact: { paths: REDACT_PATHS, censor: '[REDACTED]' },
      // The request-id middleware runs before pino-http and sets req.id.
      genReqId: (req: IncomingMessage) => {
        const existing = (req as IncomingMessage & { id?: unknown }).id;
        return typeof existing === 'string' ? existing : resolveRequestId(req.headers['x-request-id']);
      },
      customProps: (req: IncomingMessage) => ({ requestId: (req as IncomingMessage & { id?: unknown }).id }),
      // Strip query strings from logged URLs (they may carry identifiers).
      serializers: {
        req: (req: { id: unknown; method: string; url: string }) => ({
          id: req.id,
          method: req.method,
          url: req.url.split('?')[0],
        }),
      },
      autoLogging: { ignore: (req: IncomingMessage) => req.url?.startsWith('/health/') ?? false },
      ...(config.env === 'development'
        ? { transport: { target: 'pino-pretty', options: { singleLine: true } } }
        : {}),
    },
  };
}
