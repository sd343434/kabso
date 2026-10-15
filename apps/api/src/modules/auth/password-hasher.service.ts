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

/**
 * All Argon2 work goes through a process-wide concurrency cap (CONVENTIONS §6, SEC-002): at most
 * ARGON2_MAX_CONCURRENCY operations run, ARGON2_MAX_QUEUE wait, anything beyond is refused with
 * 503 SERVICE_UNAVAILABLE + Retry-After. Passwords are NFC-normalized before hashing/verifying.
 */
@Injectable()
export class PasswordHasher implements OnModuleInit {
  private dummyHash: string | undefined;
  private readonly limiter: ConcurrencyLimiter;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    this.limiter = new ConcurrencyLimiter(config.argon2.maxConcurrency, config.argon2.maxQueue);
  }

  async onModuleInit(): Promise<void> {
    this.dummyHash ??= await argon2.hash(generateSecret(), ARGON2_OPTIONS);
  }

  hash(password: string): Promise<string> {
    return this.run(() => argon2.hash(normalizePassword(password), ARGON2_OPTIONS));
  }

  verify(hash: string, password: string): Promise<boolean> {
    return this.run(async () => {
      try {
        return await argon2.verify(hash, normalizePassword(password));
      } catch {
        return false;
      }
    });
  }

  needsRehash(hash: string): boolean {
    try {
      return argon2.needsRehash(hash, ARGON2_OPTIONS);
    } catch {
      return true;
    }
  }

  /**
   * Burns the same Argon2id cost as a real verification. Used when the login identifier is
   * unknown so response timing does not reveal whether an account exists.
   */
  async verifyAgainstDummy(password: string): Promise<false> {
    this.dummyHash ??= await argon2.hash(generateSecret(), ARGON2_OPTIONS);
    await this.verify(this.dummyHash, password);
    return false;
  }

  /** Current load, for diagnostics and tests. */
  get load(): { active: number; queued: number } {
    return { active: this.limiter.active, queued: this.limiter.queued };
  }

  private run<T>(task: () => Promise<T>): Promise<T> {
    const result = this.limiter.run(task);
    if (result === null) {
      throw new AppException(
        ErrorCode.SERVICE_UNAVAILABLE,
        'Password hashing capacity exhausted.',
        undefined,
        {
          'Retry-After': String(ARGON2_SATURATED_RETRY_AFTER_SECONDS),
        },
      );
    }
    return result;
  }
}
