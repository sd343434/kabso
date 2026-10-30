import { describe, expect, it } from 'vitest';
import { bioSchema, updateMeSchema } from '../auth/auth.schemas.js';
import { setAvatarSchema } from './profile-edit.service.js';

/** The first issue code of a failed parse (the pipe's `details[].issue`). */
function issueOf(result: {
  success: boolean;
  error?: { issues: { params?: { issue?: string }; code: string }[] };
}) {
  const first = result.error?.issues[0];
  return first?.params?.issue ?? first?.code;
}

describe('D168 PATCH /me: name and bio (CONVENTIONS §10.42)', () => {
  it('accepts a display name alone, normalised like registration', () => {
    const r = updateMeSchema.safeParse({ displayName: '  سارة  ' });
    expect(r.success).toBe(true);
    expect(r.data).toEqual({ displayName: 'سارة' });
  });

  it('refuses a display name that breaks the §6 rules', () => {
    expect(issueOf(updateMeSchema.safeParse({ displayName: '' }))).toBe('too_short');
    expect(issueOf(updateMeSchema.safeParse({ displayName: '   ' }))).toBe('invalid_format');
    expect(issueOf(updateMeSchema.safeParse({ displayName: 'a'.repeat(51) }))).toBe('too_long');
    expect(issueOf(updateMeSchema.safeParse({ displayName: 'abc‮def' }))).toBe('invalid_format');
  });

  it('a bio: trimmed, NFC, line breaks kept up to 4, null or empty clears it', () => {
    expect(bioSchema.parse('  hello\r\nworld  ')).toBe('hello\nworld');
    expect(bioSchema.parse('a\nb\nc\nd\ne')).toBe('a\nb\nc\nd\ne');
    expect(bioSchema.parse('')).toBeNull();
    expect(bioSchema.parse('  \n  ')).toBeNull();
    expect(bioSchema.parse(null)).toBeNull();
    expect(bioSchema.parse('é')).toBe('é');
    const r = updateMeSchema.safeParse({ bio: null });
    expect(r.success).toBe(true);
    expect(r.data).toEqual({ bio: null });
  });

  it('a bio: at most 300 code points and 4 line breaks; hygiene per line', () => {
    expect(bioSchema.safeParse('ب'.repeat(300)).success).toBe(true);
    expect(issueOf(bioSchema.safeParse('ب'.repeat(301)))).toBe('too_long');
    expect(issueOf(bioSchema.safeParse('a\nb\nc\nd\ne\nf'))).toBe('too_long');
    expect(issueOf(bioSchema.safeParse('x'.repeat(1201)))).toBe('too_big');
    expect(issueOf(bioSchema.safeParse('hi​there'))).toBe('invalid_format');
    expect(issueOf(bioSchema.safeParse('a\u0000b'))).toBe('invalid_format');
  });

  it('needs at least one field; unknown fields are refused', () => {
    expect(issueOf(updateMeSchema.safeParse({}))).toBe('required');
    expect(updateMeSchema.safeParse({ avatarUrl: 'https://x.test/a.png' }).success).toBe(false);
    expect(updateMeSchema.safeParse({ locale: 'en', bio: 'hi' }).success).toBe(true);
  });
});

describe('D168 SetAvatarRequest', () => {
  it('is strict and needs a UUID', () => {
    expect(setAvatarSchema.safeParse({ mediaId: '0192f1d0-3333-7000-8000-000000000031' }).success).toBe(true);
    expect(issueOf(setAvatarSchema.safeParse({ mediaId: 'nope' }))).toBe('invalid_value');
    expect(setAvatarSchema.safeParse({}).success).toBe(false);
    expect(setAvatarSchema.safeParse({ mediaId: '0192f1d0-3333-7000-8000-000000000031', x: 1 }).success).toBe(
      false,
    );
  });
});
