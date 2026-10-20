import { Injectable } from '@nestjs/common';
import type { LevelSourceEventInput } from './level-qualification.js';

export type VerificationResult = { readonly ok: true } | { readonly ok: false; readonly reason: string };

/**
 * Port (CP-005 §6): confirms with the authoritative ledger of the producing module (gifts,
 * wallet, games) that a source transaction is committed and matches the event — users, value,
 * lucky flag; for a reversal, that the original was actually reversed. The engine never awards
 * points from data it could not verify.
 */
export interface SourceTransactionVerifier {
  verify(event: LevelSourceEventInput): Promise<VerificationResult>;
}

export const LEVEL_SOURCE_VERIFIER = Symbol('LEVEL_SOURCE_VERIFIER');

/**
 * Default until a gifts/games module exists (no source ledger in the repository today): every
 * event is refused, so nothing can be awarded in production from unverified data.
 */
@Injectable()
export class UnavailableSourceVerifier implements SourceTransactionVerifier {
  verify(): Promise<VerificationResult> {
    return Promise.resolve({ ok: false, reason: 'source_unavailable' });
  }
}
