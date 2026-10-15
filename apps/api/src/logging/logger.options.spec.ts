import { Writable } from 'node:stream';
import { pino } from 'pino';
import { describe, expect, it } from 'vitest';
import { REDACT_PATHS } from './logger.options.js';

describe('log redaction', () => {
  it('removes credentials and tokens from log lines', () => {
    const lines: string[] = [];
    const sink = new Writable({
      write(chunk: Buffer, _enc, cb) {
        lines.push(chunk.toString());
        cb();
      },
    });
    const logger = pino({ redact: { paths: REDACT_PATHS, censor: '[REDACTED]' } }, sink);
    logger.info({
      req: { headers: { authorization: 'Bearer eyJhbGciOi.secret.sig', cookie: 'sid=1' } },
      body: {
        password: 'hunter2hunter2',
        newPassword: 'n3w-passw0rd',
        refreshToken: 'sid.secret',
        token: 't0k3n',
      },
      password: 'top-level-pw',
    });
    const out = lines.join('');
    for (const secret of [
      'eyJhbGciOi',
      'sid=1',
      'hunter2hunter2',
      'n3w-passw0rd',
      'sid.secret',
      't0k3n',
      'top-level-pw',
    ]) {
      expect(out).not.toContain(secret);
    }
    expect(out).toContain('[REDACTED]');
  });
});
