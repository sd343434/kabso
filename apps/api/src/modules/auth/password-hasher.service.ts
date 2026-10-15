import { Injectable, type OnModuleInit } from '@nestjs/common';
import * as argon2 from 'argon2';
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

@Injectable()
export class PasswordHasher implements OnModuleInit {
  private dummyHash: string | undefined;

  async onModuleInit(): Promise<void> {
    await this.getDummyHash();
  }

  hash(password: string): Promise<string> {
    return argon2.hash(password, ARGON2_OPTIONS);
  }

  async verify(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      return false;
    }
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
    await this.verify(await this.getDummyHash(), password);
    return false;
  }

  private async getDummyHash(): Promise<string> {
    this.dummyHash ??= await this.hash(generateSecret());
    return this.dummyHash;
  }
}
