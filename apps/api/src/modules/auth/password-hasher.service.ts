import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import * as argon2 from 'argon2';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { normalizePassword } from './auth.schemas.js';
import { ConcurrencyLimiter } from './concurrency-limiter.js';
import { generateSecret } from './tokens.js';

/**
 * Argon2id parameters (OWASP Password Storage Cheat Sheet: m=19 MiB, t=2, p=1 minimum).
 * Changing them is safe: hashes carry their parameters and are upgraded on next login.
 */
export const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

/** Seconds a client is asked to wait when the hashing capacity is saturated. */
export const ARGON2_SATURATED_RETRY_AFTER_SECONDS = 1;

/** The Argon2 primitives used by {@link PasswordHasher} (replaceable in tests). */
export interface Argon2Backend {
  hash(password: string): Promise<string>;
  verify(hash: string, password: string): Promise<boolean>;
  needsRehash(hash: string): boolean;
}

export const ARGON2_BACKEND = Symbol('ARGON2_BACKEND');

export const nodeArgon2Backend: Argon2Backend = {
  hash: (password) => argon2.hash(password, ARGON2_OPTIONS),
  verify: (hash, password) => argon2.verify(hash, password),
  needsRehash: (hash) => argon2.needsRehash(hash, ARGON2_OPTIONS),
};

/**
 * Every Argon2 operation — hashing, verification and the creation of the dummy hash — goes
 * through one process-wide concurrency cap (CONVENTIONS §6, SEC-002): at most
 * ARGON2_MAX_CONCURRENCY run, ARGON2_MAX_QUEUE wait, anything beyond is refused with
 * 503 SERVICE_UNAVAILABLE + Retry-After. The slot is requested synchronously when a method is
 * called (no await happens before it). Passwords are NFC-normalized before hashing/verifying.
 */
@Injectable()
export class PasswordHasher implements OnModuleInit {
  private dummyHash: string | undefined;
  private readonly limiter: ConcurrencyLimiter;
  private readonly backend: Argon2Backend;

  constructor(
    @Inject(APP_CONFIG) config: AppConfig,
    @Inject(ARGON2_BACKEND) backend: Argon2Backend = nodeArgon2Backend,
  ) {
    this.limiter = new ConcurrencyLimiter(config.argon2.maxConcurrency, config.argon2.maxQueue);
    this.backend = backend;
  }

  /**
   * Precomputes the dummy hash (through the limiter) before the app serves traffic, so an
   * unknown-user login always costs exactly one Argon2 verification — never a lazy hash on the
   * first call, which would be both uncapped work and a timing side channel.
   */
  async onModuleInit(): Promise<void> {
    this.dummyHash ??= await this.run(() => this.backend.hash(generateSecret()));
  }

  hash(password: string): Promise<string> {
    return this.run(() => this.backend.hash(normalizePassword(password)));
  }

  verify(hash: string, password: string): Promise<boolean> {
    return this.run(() => this.safeVerify(hash, password));
  }

  needsRehash(hash: string): boolean {
    try {
      return this.backend.needsRehash(hash);
    } catch {
      return true;
    }
  }

  /**
   * Burns exactly one Argon2id verification, like a real login, for unknown identifiers so
   * response timing does not reveal whether an account exists. Requires {@link onModuleInit}.
   */
  verifyAgainstDummy(password: string): Promise<false> {
    const dummy = this.dummyHash;
    if (dummy === undefined) {
      return Promise.reject(new Error('PasswordHasher used before onModuleInit (dummy hash missing)'));
    }
    return this.run(async () => {
      await this.safeVerify(dummy, password);
      return false as const;
    });
  }

  /** Current load, for diagnostics and tests. */
  get load(): { active: number; queued: number } {
    return { active: this.limiter.active, queued: this.limiter.queued };
  }

  private async safeVerify(hash: string, password: string): Promise<boolean> {
    try {
      return await this.backend.verify(hash, normalizePassword(password));
    } catch {
      return false;
    }
  }

  /** Requests a limiter slot synchronously; rejects with 503 when the cap and queue are full. */
  private run<T>(task: () => Promise<T>): Promise<T> {
    const result = this.limiter.run(task);
    if (result === null) {
      return Promise.reject(
        new AppException(ErrorCode.SERVICE_UNAVAILABLE, 'Password hashing capacity exhausted.', undefined, {
          'Retry-After': String(ARGON2_SATURATED_RETRY_AFTER_SECONDS),
        }),
      );
    }
    return result;
  }
}
