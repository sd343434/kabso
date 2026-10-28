import { describe, expect, it } from 'vitest';
import { loginSchema, registerSchema } from '../../modules/auth/auth.schemas.js';
import { AppException } from '../errors/app-exception.js';
import { ZodValidationPipe } from './zod-validation.pipe.js';

function detailsOf(fn: () => unknown) {
  try {
    fn();
  } catch (err) {
    expect(err).toBeInstanceOf(AppException);
    return (err as AppException).details;
  }
  throw new Error('expected validation to fail');
}

describe('ZodValidationPipe', () => {
  const register = new ZodValidationPipe(registerSchema);

  it('returns parsed (normalized) data on success', () => {
    const out = register.transform({
      email: ' A@B.CO ',
      password: 'password1',
      username: 'abc123',
      displayName: ' Name ',
    });
    expect(out).toEqual({ email: 'a@b.co', password: 'password1', username: 'abc123', displayName: 'Name' });
  });

  it('produces { field, issue } details with dotted paths', () => {
    const details = detailsOf(() =>
      register.transform({
        email: 'x',
        password: 1,
        username: 'ab_1',
        displayName: 'x'.repeat(51),
        locale: 'fr',
        device: { platform: 'symbian', extra: 1 },
      }),
    );
    expect(details).toEqual(
      expect.arrayContaining([
        { field: 'email', issue: 'invalid_email' },
        { field: 'password', issue: 'invalid_type' },
        { field: 'username', issue: 'too_short' },
        { field: 'displayName', issue: 'too_long' },
        { field: 'locale', issue: 'invalid_value' },
        { field: 'device.platform', issue: 'invalid_value' },
        { field: 'device.extra', issue: 'unknown_field' },
      ]),
    );
  });

  it('rejects non-object bodies', () => {
    expect(detailsOf(() => new ZodValidationPipe(loginSchema).transform(undefined))).toEqual([
      { field: '', issue: 'required' },
    ]);
    expect(detailsOf(() => new ZodValidationPipe(loginSchema).transform([]))).toEqual([
      { field: '', issue: 'invalid_type' },
    ]);
  });
});
