import { describe, expect, it } from 'vitest';
import { AppException } from '../../common/errors/app-exception.js';
import { loadConfig } from '../../config/app-config.js';
import { PasswordHasher, type Argon2Backend } from './password-hasher.service.js';

function config(maxConcurrency: number, maxQueue: number) {
  return loadConfig({
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    JWT_ACCESS_SECRET: 'x'.repeat(32),
    APP_PUBLIC_URL: 'http://localhost:3000',
    ARGON2_MAX_CONCURRENCY: String(maxConcurrency),
    ARGON2_MAX_QUEUE: String(maxQueue),
  });
}

/**
 * Fake Argon2 whose operations finish only when the test releases them, so slot occupancy is
 * controlled exactly (no dependence on real hashing time). Records every call.
 */
class ControlledBackend implements Argon2Backend {
  readonly calls: { op: 'hash' | 'verify'; input: string }[] = [];
  private readonly pending: (() => void)[] = [];
  autoRelease = false;

  hash(password: string): Promise<string> {
    this.calls.push({ op: 'hash', input: password });
    return this.gate(() => `fake-hash(${password})`);
  }

  verify(hash: string, password: string): Promise<boolean> {
    this.calls.push({ op: 'verify', input: password });
    return this.gate(() => hash === `fake-hash(${password})`);
  }

  needsRehash(): boolean {
    return false;
  }

  /** Completes the oldest outstanding operation. */
  releaseOne(): void {
    this.pending.shift()?.();
  }

  releaseAll(): void {
    while (this.pending.length > 0) this.releaseOne();
  }

  get outstanding(): number {
    return this.pending.length;
  }

  private gate<T>(value: () => T): Promise<T> {
    if (this.autoRelease) return Promise.resolve(value());
    return new Promise<T>((resolve) => this.pending.push(() => resolve(value())));
  }
}

async function initialized(maxConcurrency: number, maxQueue: number) {
  const backend = new ControlledBackend();
  const hasher = new PasswordHasher(config(maxConcurrency, maxQueue), backend);
  backend.autoRelease = true;
  await hasher.onModuleInit();
  backend.autoRelease = false;
  backend.calls.length = 0;
  return { backend, hasher };
}

const flush = () => new Promise<void>((resolve) => setImmediate(resolve));

describe('PasswordHasher Argon2 concurrency cap (SEC-002)', () => {
  it('sheds load with 503 SERVICE_UNAVAILABLE + Retry-After once slots and queue are full', async () => {
    const { backend, hasher } = await initialized(1, 1);
    const running = hasher.hash('first password');
    const queued = hasher.hash('second password');
    // Slots are taken synchronously on call: no await is needed before checking the load.
    expect(hasher.load).toEqual({ active: 1, queued: 1 });

    for (const attempt of [
      () => hasher.verifyAgainstDummy('third password'),
      () => hasher.verify('fake-hash(x)', 'x'),
      () => hasher.hash('fourth password'),
    ]) {
      const error = await attempt().then(
        () => undefined,
        (err: unknown) => err,
      );
      expect(error).toBeInstanceOf(AppException);
      expect(error).toMatchObject({
        code: 'SERVICE_UNAVAILABLE',
        status: 503,
        headers: { 'Retry-After': '1' },
      });
    }
    // Refused calls never reached Argon2.
    expect(backend.calls.map((c) => c.input)).toEqual(['first password']);

    backend.releaseOne();
    await flush();
    expect(hasher.load).toEqual({ active: 1, queued: 0 });
    expect(backend.calls.map((c) => c.input)).toEqual(['first password', 'second password']);
    backend.releaseOne();
    await expect(Promise.all([running, queued])).resolves.toEqual([
      'fake-hash(first password)',
      'fake-hash(second password)',
    ]);
    expect(hasher.load).toEqual({ active: 0, queued: 0 });
  });

  it('never runs more than the cap concurrently', async () => {
    const { backend, hasher } = await initialized(2, 10);
    const work = Array.from({ length: 6 }, (_, i) => hasher.verify('fake-hash(p)', `p${i}`));
    for (let step = 0; step < 6; step += 1) {
      expect(backend.outstanding).toBeLessThanOrEqual(2);
      backend.releaseOne();
      await flush();
    }
    backend.releaseAll();
    await Promise.all(work);
    expect(backend.calls).toHaveLength(6);
  });

  it('unknown-user verification costs exactly one Argon2 verify, every time, inside the cap', async () => {
    const { backend, hasher } = await initialized(1, 0);
    for (let i = 0; i < 3; i += 1) {
      const pending = hasher.verifyAgainstDummy(`guess ${i}`);
      expect(hasher.load.active).toBe(1);
      expect(backend.calls.slice(-1)).toEqual([{ op: 'verify', input: `guess ${i}` }]);
      backend.releaseOne();
      await expect(pending).resolves.toBe(false);
    }
    // No lazy dummy-hash creation: only verifications, one per call.
    expect(backend.calls.map((c) => c.op)).toEqual(['verify', 'verify', 'verify']);
  });

  it('creates the dummy hash at startup through the limiter', async () => {
    const backend = new ControlledBackend();
    const hasher = new PasswordHasher(config(1, 0), backend);
    const init = hasher.onModuleInit();
    expect(hasher.load.active).toBe(1);
    expect(backend.calls.map((c) => c.op)).toEqual(['hash']);
    backend.releaseOne();
    await init;
    expect(hasher.load.active).toBe(0);
  });

  it('refuses to verify against the dummy before initialization (no uncapped lazy hash)', async () => {
    const backend = new ControlledBackend();
    const hasher = new PasswordHasher(config(1, 0), backend);
    await expect(hasher.verifyAgainstDummy('x')).rejects.toThrow(/before onModuleInit/);
    expect(backend.calls).toEqual([]);
  });

  it('normalizes passwords to NFC before they reach Argon2', async () => {
    const { backend, hasher } = await initialized(1, 0);
    backend.autoRelease = true;
    const nfc = 'café passphrase';
    const nfd = nfc.normalize('NFD');
    expect(nfd).not.toBe(nfc);
    await hasher.hash(nfd);
    await hasher.verify('fake-hash(x)', nfd);
    await hasher.verifyAgainstDummy(nfd);
    expect(backend.calls.map((c) => c.input)).toEqual([nfc, nfc, nfc]);
  });
});
