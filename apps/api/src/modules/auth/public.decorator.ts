import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'kabso:is-public';

/** Marks a route/controller as not requiring an access token (the guard is global). */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
