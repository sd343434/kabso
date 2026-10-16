/**
 * Stand-in for image-worker.ts in the ImageProcessor tests: misbehaves on purpose, selected by
 * the job's `declaredType` field so one file covers every case.
 *  - image/jpeg: never answers (the processor must kill it at its deadline);
 *  - image/png: exits without answering (a crashed decoder);
 *  - image/webp: answers with a forged "success" that has no derivatives.
 */
process.once('message', (job: { declaredType?: string }) => {
  if (job.declaredType === 'image/jpeg') {
    setInterval(() => undefined, 1000);
    return;
  }
  if (job.declaredType === 'image/png') process.exit(1);
  process.send?.({ ok: true, detectedType: 'image/webp', main: { data: 'x' } }, () => process.exit(0));
});
