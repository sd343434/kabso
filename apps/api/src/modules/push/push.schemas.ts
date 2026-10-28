import { z } from 'zod';

/** `RegisterPushTokenRequest` (openapi v1.30-live, D152). */
export const registerPushTokenSchema = z.strictObject({
  token: z
    .string()
    .min(1)
    .max(1024)
    .regex(/^[A-Za-z0-9_:.-]+$/),
  platform: z.enum(['ANDROID', 'IOS']),
  appVersion: z
    .string()
    .min(1)
    .max(32)
    .regex(/^[0-9A-Za-z.+_-]+$/),
});
export type RegisterPushTokenInput = z.output<typeof registerPushTokenSchema>;
