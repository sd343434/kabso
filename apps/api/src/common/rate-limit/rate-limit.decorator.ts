import { SetMetadata } from '@nestjs/common';
import type { AppConfig } from '../../config/app-config.js';
import { clientIpBucket, type AppRequest } from '../http/request-context.js';

export const RATE_LIMITS_KEY = 'kabso:rate-limits';
export const SKIP_RATE_LIMIT_KEY = 'kabso:skip-rate-limit';

export interface RateLimitSpec {
  /** Redis bucket name, e.g. `login:ip`. */
  readonly bucket: string;
  /** Which configured rule applies. */
  readonly rule: keyof AppConfig['rateLimits'];
  /** Derives the raw subject key (hashed before use) from the request. */
  readonly key: (req: AppRequest) => string;
  /**
   * v1.3 (CONVENTIONS §7): this endpoint-specific limit replaces the default per-user
   * ("everything else") bucket for the route instead of adding to it.
   */
  readonly replacesDefault?: boolean;
  /** Log rejections of this bucket (e.g. follow anti-abuse, CONVENTIONS §10.6). */
  readonly logRejections?: boolean;
  /**
   * CP-010: on `@OptionalAuth()` routes, counts only signed-in callers (`user`) or only guests
   * (`guest`). Unset: always.
   */
  readonly appliesTo?: 'user' | 'guest';
}

/** Subject key of the per-user v1.3 buckets: the authenticated user id. */
export const byUserId = (req: AppRequest): string => req.auth?.userId ?? '';

/** Subject key of per-IP buckets (guests, CP-010). */
export const byIp = (req: AppRequest): string => clientIpBucket(req);

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
