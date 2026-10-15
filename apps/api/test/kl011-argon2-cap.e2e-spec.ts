/**
 * KL-011 / SEC-002: the process-wide Argon2 cap answers 503 + Retry-After when saturated.
 * Deterministic: the real Argon2 backend is replaced by one whose operations complete only when
 * the test releases them, so slot occupancy does not depend on hashing time.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { ARGON2_BACKEND, type Argon2Backend } from '../src/modules/auth/password-hasher.service.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

class HeldArgon2 implements Argon2Backend {
  readonly ops: string[] = [];
  hold = false;
  private readonly held: (() => void)[] = [];

  hash(password: string): Promise<string> {
    this.ops.push('hash');
    return this.gate(`fake$${password}`);
  }

  verify(hash: string, password: string): Promise<boolean> {
    this.ops.push('verify');
    return this.gate(hash === `fake$${password}`);
  }

  needsRehash(): boolean {
    return false;
  }

  get heldCount(): number {
    return this.held.length;
  }

  releaseAll(): void {
    while (this.held.length > 0) this.held.shift()?.();
  }

  private gate<T>(value: T): Promise<T> {
    if (!this.hold) return Promise.resolve(value);
    return new Promise<T>((resolve) => this.held.push(() => resolve(value)));
  }
}

async function until(condition: () => boolean, timeoutMs = 5000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (!condition()) {
    if (Date.now() > deadline) throw new Error('condition not met in time');
    await new Promise((r) => setTimeout(r, 5));
  }
}

describe('KL-011 Argon2 concurrency cap (SEC-002)', () => {
  const argon2 = new HeldArgon2();
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ ARGON2_MAX_CONCURRENCY: '1', ARGON2_MAX_QUEUE: '0' }, [
      { token: ARGON2_BACKEND, value: argon2 },
    ]);
  });

  afterAll(async () => {
    argon2.releaseAll();
    await ctx?.close();
  });

  it('answers 503 SERVICE_UNAVAILABLE with Retry-After while the only slot is busy', async () => {
    // The dummy hash was created once at startup; logins below only verify.
    expect(argon2.ops).toEqual(['hash']);
    argon2.hold = true;

    const login = (identifier: string) =>
      ctx.http.post('/api/v1/auth/login').send({ identifier, password: 'x'.repeat(12) });

    // Request A takes the single slot and is held inside Argon2.
    const first = login('nobody-a@example.com').then((r) => r);
    await until(() => argon2.heldCount === 1);

    const shed = await login('nobody-b@example.com');
    expect(shed.status).toBe(503);
    expect(shed.body.error.code).toBe('SERVICE_UNAVAILABLE');
    expect(shed.headers['retry-after']).toBe('1');
    expect(shed.headers['cache-control']).toBe('no-store');
    // The refused request never reached Argon2.
    expect(argon2.ops).toEqual(['hash', 'verify']);

    argon2.hold = false;
    argon2.releaseAll();
    expect((await first).status).toBe(401);

    // Capacity is back: an unknown user again costs exactly one verification.
    const after = await login('nobody-c@example.com');
    expect(after.status).toBe(401);
    expect(argon2.ops).toEqual(['hash', 'verify', 'verify']);
  });
});
