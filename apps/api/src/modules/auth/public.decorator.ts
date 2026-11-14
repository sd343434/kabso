import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'kabso:is-public';

/** Marks a route/controller as not requiring an access token (the guard is global). */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

export const IS_OPTIONAL_AUTH_KEY = 'kabso:optional-auth';

/**
 * CP-010 (§10.8): the route also serves guests. Without an `Authorization` header the request
 * goes on with no `req.auth`; with one, the token must be valid as on every other route.
 */
export const OptionalAuth = () => SetMetadata(IS_OPTIONAL_AUTH_KEY, true);
