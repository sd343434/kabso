import { z } from 'zod';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';
import { limitSchema } from '../posts/posts.schemas.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.5-social (strict objects). CONVENTIONS §11.7.

const NOTE_LIMITS: ContentTextLimits = { maxCodePoints: 500, maxLineBreaks: 10, allowEmpty: true };

/** An optional free-text note (§6 hygiene); empty after trimming → absent. */
const noteSchema = z
  .string()
  .max(2000)
  .transform((raw, ctx) => {
    const result = normalizeContentText(raw, NOTE_LIMITS);
    if ('issue' in result) {
      ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
      return z.NEVER;
    }
    return result.value === '' ? null : result.value;
  });

export const REPORT_REASONS = [
  'SPAM',
  'NUDITY',
  'VIOLENCE',
  'HATE',
  'HARASSMENT',
  'ILLEGAL',
  'OTHER',
] as const;

/** `CreateReportRequest`. */
export const createReportSchema = z.strictObject({
  // v1.24-live (CP-021): CP_CONFESSION, a confession on a CP couple's page (§10.24).
  // v1.25-live (CP-022): FAMILY_CHAT_MESSAGE, a message in the reporter's family chat (§10.25).
  targetType: z.enum([
    'POST',
    'COMMENT',
    'STORY',
    'USER',
    'LIVE_ROOM',
    'LIVE_CHAT_MESSAGE',
    'CP_CONFESSION',
    'FAMILY_CHAT_MESSAGE',
    // v1.40-social (D155): a direct message the reporter received (§11.13).
    'DM_MESSAGE',
    // v1.47-social (D175): a link on someone's profile (`targetId` the link's id, §10.47).
    'PROFILE_LINK',
  ]),
  targetId: z.string().min(1).max(64),
  reason: z.enum(REPORT_REASONS),
  note: noteSchema.optional(),
});
export type CreateReportInput = z.output<typeof createReportSchema>;

/** `ReportActionRequest`. */
export const reportActionSchema = z.strictObject({
  action: z.enum(['REMOVE_TARGET', 'DISMISS']),
  note: noteSchema.optional(),
});
export type ReportActionInput = z.output<typeof reportActionSchema>;

/** `UpdatePrivacyRequest` (at least one field). */
export const updatePrivacySchema = z
  .strictObject({
    whoCanMention: z.enum(['EVERYONE', 'FOLLOWING', 'NOBODY']).optional(),
    defaultWhoCanComment: z.enum(['EVERYONE', 'FOLLOWERS', 'NOBODY']).optional(),
    // v1.25-live (CP-022, D116): others may see when the user was last active (§10.25).
    showActivityStatus: z.boolean().optional(),
    // v1.40-social (D155): who may send the user direct messages (§11.13).
    whoCanMessage: z.enum(['EVERYONE', 'FOLLOWING', 'NOBODY']).optional(),
    // v1.47-social (D175): a private account (§10.47).
    isPrivate: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'too_small', params: { issue: 'too_small' } });

export const adminReportsQuerySchema = z.strictObject({
  status: z
    .string()
    .pipe(z.enum(['OPEN', 'ACTIONED', 'DISMISSED']))
    .optional()
    .transform((v) => v ?? 'OPEN'),
  cursor: z.string().min(1).max(512).optional(),
  limit: limitSchema.optional().transform((v) => v ?? 20),
});
export type AdminReportsQuery = z.output<typeof adminReportsQuerySchema>;
