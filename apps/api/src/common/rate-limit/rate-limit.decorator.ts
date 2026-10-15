import { SetMetadata } from '@nestjs/common';
import type { AppConfig } from '../../config/app-config.js';
import type { AppRequest } from '../http/request-context.js';

export const RATE_LIMITS_KEY = 'kabso:rate-limits';
export const SKIP_RATE_LIMIT_KEY = 'kabso:skip-rate-limit';

export interface RateLimitSpec {
  /** Redis bucket name, e.g. `login:ip`. */
  readonly bucket: string;
  /** Which configured rule applies. */
  readonly rule: keyof AppConfig['rateLimits'];
  /** Derives the raw subject key (hashed before use) from the request. */
  readonly key: (req: AppRequest) => string;
}

/** Endpoint-specific limits (CONVENTIONS §7), evaluated in order before the handler. */
export const RateLimit = (...specs: RateLimitSpec[]) => SetMetadata(RATE_LIMITS_KEY, specs);

/** Excludes a route (e.g. health probes) from every rate limit. */
export const SkipRateLimit = () => SetMetadata(SKIP_RATE_LIMIT_KEY, true);

/** Reads a string field from the (not yet validated) JSON body, normalized for keying. */
export function bodyField(req: AppRequest, field: string): string {
  const body: unknown = req.body;
  if (typeof body !== 'object' || body === null) return '';
  const value = (body as Record<string, unknown>)[field];
  return typeof value === 'string' ? value.trim().toLowerCase().slice(0, 256) : '';
}
