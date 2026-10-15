/** CONVENTIONS §6: passwords are 8–128 characters. */
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 128;

export type PasswordIssue = 'too_short' | 'too_long';

/**
 * Returns the policy violation for `password`, or null when acceptable. Length is measured in
 * Unicode code points so that e.g. Arabic or emoji passwords are not penalised; the UTF-16
 * length is additionally capped (2 × max) to bound hashing input.
 */
export function passwordPolicyIssue(password: string): PasswordIssue | null {
  const codePoints = [...password].length;
  if (codePoints < PASSWORD_MIN_LENGTH) return 'too_short';
  if (codePoints > PASSWORD_MAX_LENGTH || password.length > PASSWORD_MAX_LENGTH * 2) return 'too_long';
  return null;
}
