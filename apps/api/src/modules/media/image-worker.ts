/**
 * Entry point of the isolated image worker (CONVENTIONS §11.11, §11.13; A7 review item).
 *
 * The API forks one short-lived child process per `complete` job (image-processor.ts). The child:
 *  - receives exactly one job over IPC and answers with exactly one outcome, then exits;
 *  - gets a minimal environment (no database, Redis, JWT or storage credentials) and a bounded
 *    V8 heap; it opens no network connection and reads no file: the bytes arrive over IPC;
 *  - blocks every libvips loader except JPEG/PNG/WebP (image-pipeline.ts).
 * The parent kills it (SIGKILL) at the job's deadline, so a decoder that hangs, or crashes the
 * process, cannot take the API down or exceed MEDIA_PROCESS_TIMEOUT_MS. One job per process also
 * means no image of one user ever shares a process with another user's image.
 */
import { processImage, type ProcessJob, type ProcessOutcome } from './image-pipeline.js';

function reply(outcome: ProcessOutcome): void {
  if (!process.send) process.exit(2);
  process.send(outcome, () => process.exit(0));
}

process.once('message', (job: ProcessJob) => {
  processImage(job)
    .then(reply)
    .catch(() => reply({ ok: false, issue: 'invalid_format', reason: 'worker_error' }));
});

// Fail closed if the parent goes away before sending a job.
process.once('disconnect', () => process.exit(3));
