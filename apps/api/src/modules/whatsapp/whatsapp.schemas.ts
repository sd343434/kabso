import { z } from 'zod';
import { WA_DEPARTMENTS } from './whatsapp-departments.js';

/** v1.116-social (D355, CONVENTIONS §10.151): the request shapes of «واتساب». */
export const listQuery = z.strictObject({
  filter: z.enum(['unassigned', 'mine', 'all', 'closed']).default('all'),
  /** D364 (§10.157.4): only the conversations of one department. */
  department: z.enum(WA_DEPARTMENTS).optional(),
  q: z.string().trim().max(80).optional(),
  cursor: z.string().max(512).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
export type ListQuery = z.output<typeof listQuery>;

export const messagesQuery = z.strictObject({
  cursor: z.string().max(512).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});
export type MessagesQuery = z.output<typeof messagesQuery>;

export const sendBody = z.discriminatedUnion('type', [
  z.strictObject({ type: z.literal('TEXT'), text: z.string().trim().min(1).max(4096) }),
  z.strictObject({
    type: z.literal('TEMPLATE'),
    template: z.strictObject({
      name: z
        .string()
        .trim()
        .regex(/^[a-z0-9_]{1,512}$/),
      language: z
        .string()
        .trim()
        .regex(/^[A-Za-z]{2,3}(_[A-Za-z0-9]{2,8})?$/),
      parameters: z.array(z.string().trim().min(1).max(1024)).max(20).default([]),
    }),
  }),
]);
export type SendBody = z.output<typeof sendBody>;

export const mediaQuery = z.strictObject({
  mime: z.string().trim().min(3).max(100),
  filename: z.string().trim().max(240).optional(),
  caption: z.string().trim().max(1024).optional(),
});
export type MediaQuery = z.output<typeof mediaQuery>;

/**
 * D355 `{toUserId}`; D364 (§10.157.2) `{department, toUserId?, note?}` — no `toUserId`: «أول متاح في القسم». Without a
 * department (an app or panel before D364) `toUserId` is required and the department is GENERAL.
 */
export const transferBody = z
  .strictObject({
    toUserId: z.uuid().optional(),
    department: z.enum(WA_DEPARTMENTS).optional(),
    note: z.string().trim().max(500).optional(),
  })
  .refine((v) => v.department !== undefined || v.toUserId !== undefined, {
    message: 'toUserId is required without a department',
    path: ['toUserId'],
    params: { issue: 'required' },
  });
export type TransferBody = z.output<typeof transferBody>;
export const agentsQuery = z.strictObject({ department: z.enum(WA_DEPARTMENTS).optional() });
export type AgentsQuery = z.output<typeof agentsQuery>;
export const noteBody = z.strictObject({ body: z.string().trim().min(1).max(2000) });
export const linkBody = z.strictObject({
  username: z
    .string()
    .trim()
    .min(1)
    .max(41)
    .transform((u) => u.replace(/^@/, '')),
});
export const quickReplyBody = z.strictObject({
  title: z.string().trim().min(1).max(60),
  body: z.string().trim().min(1).max(1024),
});
export const quickReplyPatch = quickReplyBody
  .partial()
  .refine((v) => v.title !== undefined || v.body !== undefined, { message: 'nothing to change' });
export const settingsBody = z.strictObject({ pushMuted: z.boolean() });
export const templatesQuery = z.strictObject({
  refresh: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => v === 'true'),
});
