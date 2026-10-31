import { SetMetadata } from '@nestjs/common';

export const CONSENT_EXEMPT_KEY = 'kabso:consent-exempt';

/**
 * v1.66-social (D198, §10.61.2): the route works while a new version of the terms or the privacy policy waits to be
 * accepted — accepting it, signing out, the sessions list, `GET /me`, the push token's removal, deleting the account
 * and the data export. Every other signed-in route answers 428 CONSENT_REQUIRED until then.
 */
export const ConsentExempt = () => SetMetadata(CONSENT_EXEMPT_KEY, true);
