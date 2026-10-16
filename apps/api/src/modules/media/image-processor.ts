import { fork, type ChildProcess } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { ConcurrencyLimiter } from '../auth/concurrency-limiter.js';
import type { ProcessJob, ProcessOutcome } from './image-pipeline.js';

/** Heap of the worker (pixel buffers live in libvips, bounded by the 40 MP pixel limit). */
const WORKER_MAX_OLD_SPACE_MB = 256;

/** A job as the media service builds it (the processor adds the inner time limit). */
export type WorkerJob = Omit<ProcessJob, 'timeoutSeconds'>;

export interface ProcessingSlot {
  run(job: WorkerJob): Promise<ProcessOutcome>;
  release(): void;
}

export interface ImageProcessorOptions {
  readonly maxConcurrency: number;
  readonly timeoutMs: number;
  /** Worker entry (tests may point at another module); defaults to image-worker.(js|ts). */
  readonly workerUrl?: URL;
}

/** Worker module next to this file; when running from TypeScript sources (tests), via tsx. */
function defaultWorker(): { path: string; execArgv: string[] } {
  const ts = import.meta.url.endsWith('.ts');
  const url = new URL(ts ? './image-worker.ts' : './image-worker.js', import.meta.url);
  return { path: fileURLToPath(url), execArgv: ts ? ['--import', import.meta.resolve('tsx')] : [] };
}

/**
 * Runs image jobs in isolated, short-lived worker processes (image-worker.ts) with:
 *  - a per-process concurrency cap (MEDIA_PROCESS_MAX_CONCURRENCY) and NO queue: when every slot
 *    is busy the caller gets 503 SERVICE_UNAVAILABLE with Retry-After, as for Argon2 (§11.3);
 *  - a hard time limit (MEDIA_PROCESS_TIMEOUT_MS): the worker is killed with SIGKILL and the job
 *    fails as `invalid_format` (CONVENTIONS §11.2: "processing exceeded its time limit");
 *  - a worker crash or a malformed answer also fails the job as `invalid_format`.
 */
export class ImageProcessor {
  private readonly limiter: ConcurrencyLimiter;
  private readonly worker: { path: string; execArgv: string[] };

  constructor(private readonly options: ImageProcessorOptions) {
    this.limiter = new ConcurrencyLimiter(options.maxConcurrency, 0);
    this.worker = options.workerUrl
      ? {
          path: fileURLToPath(options.workerUrl),
          execArgv: options.workerUrl.pathname.endsWith('.ts')
            ? ['--import', import.meta.resolve('tsx')]
            : [],
        }
      : defaultWorker();
  }

  /** Jobs running now (for tests and diagnostics). */
  get active(): number {
    return this.limiter.active;
  }

  get retryAfterSeconds(): number {
    return Math.max(1, Math.ceil(this.options.timeoutMs / 1000));
  }

  /**
   * Reserves a processing slot or throws 503 + Retry-After at once (no waiting). The caller must
   * either `run` exactly one job in it or `release` it (both are safe to call in any order).
   */
  reserve(): ProcessingSlot {
    let free!: () => void;
    const held = new Promise<void>((resolve) => {
      free = resolve;
    });
    if (!this.limiter.run(() => held)) {
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, undefined, undefined, {
        'Retry-After': String(this.retryAfterSeconds),
      });
    }
    let used = false;
    return {
      run: async (job) => {
        if (used) throw new Error('processing slot already used or released');
        used = true;
        try {
          return await this.runInWorker(job);
        } finally {
          free();
        }
      },
      release: () => {
        if (used) return;
        used = true;
        free();
      },
    };
  }

  /** Convenience: reserve a slot and run one job in it. */
  async process(job: WorkerJob): Promise<ProcessOutcome> {
    return this.reserve().run(job);
  }

  private runInWorker(job: WorkerJob): Promise<ProcessOutcome> {
    return new Promise<ProcessOutcome>((resolve) => {
      let settled = false;
      let child: ChildProcess;
      const finish = (outcome: ProcessOutcome) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
        resolve(outcome);
      };
      try {
        child = fork(this.worker.path, [], {
          execArgv: [...this.worker.execArgv, `--max-old-space-size=${WORKER_MAX_OLD_SPACE_MB}`],
          // Minimal environment: no secrets reach the worker. libvips also blocks untrusted
          // operations by itself (VIPS_BLOCK_UNTRUSTED), in addition to the loader allow-list.
          env: { NODE_ENV: process.env.NODE_ENV ?? 'production', VIPS_BLOCK_UNTRUSTED: '1' },
          serialization: 'advanced',
          stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
        });
      } catch {
        resolve({ ok: false, issue: 'invalid_format', reason: 'worker_spawn_failed' });
        return;
      }
      const timer = setTimeout(
        () => finish({ ok: false, issue: 'invalid_format', reason: 'timeout' }),
        this.options.timeoutMs,
      );
      child.once('message', (message: unknown) => finish(asOutcome(message)));
      child.once('error', () => finish({ ok: false, issue: 'invalid_format', reason: 'worker_error' }));
      child.once('exit', () => finish({ ok: false, issue: 'invalid_format', reason: 'worker_exited' }));
      child.send({ ...job, timeoutSeconds: Math.max(1, Math.ceil(this.options.timeoutMs / 1000)) });
    });
  }
}

const ISSUES = new Set(['too_big', 'too_small', 'invalid_format']);
const TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

function isDerivative(value: unknown): value is { data: Uint8Array; width: number; height: number } {
  const d = value as { data?: unknown; width?: unknown; height?: unknown } | null;
  return (
    typeof d === 'object' &&
    d !== null &&
    d.data instanceof Uint8Array &&
    Number.isInteger(d.width) &&
    Number.isInteger(d.height) &&
    (d.width as number) > 0 &&
    (d.height as number) > 0
  );
}

/** Validates the worker's answer (the worker handles hostile input, so its answer is checked). */
export function asOutcome(message: unknown): ProcessOutcome {
  const m = message as Record<string, unknown> | null;
  if (typeof m === 'object' && m !== null) {
    if (
      m.ok === true &&
      TYPES.has(m.detectedType as string) &&
      isDerivative(m.main) &&
      isDerivative(m.thumb)
    ) {
      return m as unknown as ProcessOutcome;
    }
    if (m.ok === false && ISSUES.has(m.issue as string)) {
      return {
        ok: false,
        issue: m.issue as 'too_big',
        reason: typeof m.reason === 'string' ? m.reason.slice(0, 64) : '',
      };
    }
  }
  return { ok: false, issue: 'invalid_format', reason: 'bad_worker_answer' };
}
