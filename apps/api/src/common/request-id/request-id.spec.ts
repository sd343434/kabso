import { describe, expect, it } from 'vitest';
import { resolveRequestId } from './request-id.js';

describe('resolveRequestId', () => {
  it('reuses a valid inbound id', () => {
    expect(resolveRequestId('abc.DEF_123-x')).toBe('abc.DEF_123-x');
    expect(resolveRequestId('a'.repeat(64))).toBe('a'.repeat(64));
  });

  it.each([undefined, '', 'a'.repeat(65), 'has space', 'semi;colon', ['a', 'b'], 'ünicode'])(
    'generates a UUID for %j',
    (inbound) => {
      expect(resolveRequestId(inbound)).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
      );
    },
  );
});
