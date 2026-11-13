import { z } from 'zod';
import { normalizeContentText, type ContentTextLimits } from '../posts/content-text.js';

// Request schemas mirror docs/contracts/openapi.yaml v1.5-social, CP-008 (strict objects).
// Text rules: CONVENTIONS §11.9.

export const STORY_TEXT_LIMITS: ContentTextLimits = {
  maxCodePoints: 200,
  maxLineBreaks: 3,
  allowEmpty: true,
};
/** At most 10 linked mentions per story (§11.9). */
export const MAX_STORY_MENTIONS = 10;

/** `CreateStoryRequest`. */
export const createStorySchema = z.strictObject({
  mediaId: z.uuid(),
  text: z
    .string()
    .max(800)
    .transform((raw, ctx) => {
      const result = normalizeContentText(raw, STORY_TEXT_LIMITS);
      if ('issue' in result) {
        ctx.addIssue({ code: 'custom', message: result.issue, params: { issue: result.issue } });
        return z.NEVER;
      }
      return result.value;
    })
    .optional(),
});
export type CreateStoryInput = z.output<typeof createStorySchema>;
