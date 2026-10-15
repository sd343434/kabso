/**
 * Counting semaphore with a bounded wait queue. `run` returns null immediately (without running
 * the task) when every slot is busy and the queue is full, so callers can shed load.
 */
export class ConcurrencyLimiter {
  private running = 0;
  private readonly waiting: (() => void)[] = [];

  constructor(
    private readonly maxConcurrency: number,
    private readonly maxQueue: number,
  ) {
    if (!Number.isInteger(maxConcurrency) || maxConcurrency < 1) {
      throw new RangeError('maxConcurrency must be a positive integer');
    }
    if (!Number.isInteger(maxQueue) || maxQueue < 0) {
      throw new RangeError('maxQueue must be a non-negative integer');
    }
  }

  get active(): number {
    return this.running;
  }

  get queued(): number {
    return this.waiting.length;
  }

  run<T>(task: () => Promise<T>): Promise<T> | null {
    if (this.running < this.maxConcurrency) {
      this.running += 1;
      return this.execute(task);
    }
    if (this.waiting.length >= this.maxQueue) return null;
    // The slot is handed over directly by the finishing task (running is not decremented),
    // so a newcomer cannot overtake a queued task and exceed the cap.
    return new Promise<void>((resolve) => this.waiting.push(resolve)).then(() => this.execute(task));
  }

  /** Runs `task` in a slot already accounted for in `running`. */
  private async execute<T>(task: () => Promise<T>): Promise<T> {
    try {
      return await task();
    } finally {
      const next = this.waiting.shift();
      if (next) next();
      else this.running -= 1;
    }
  }
}
