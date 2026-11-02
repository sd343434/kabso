import { describe, expect, it } from 'vitest';
import {
  CAMERA_FX_DEFAULT,
  readCameraFxEngine,
  storedCameraFxEngine,
  updateCameraFxSchema,
} from './camera-fx.rules.js';

describe('D228 camera effects engine rules', () => {
  it('only an exact FREE selects the free engine; everything else is DEEPAR', () => {
    expect(CAMERA_FX_DEFAULT).toBe('DEEPAR');
    expect(storedCameraFxEngine('FREE')).toBe('FREE');
    for (const v of ['DEEPAR', 'free', ' FREE', null, undefined, true, 1, { engine: 'FREE' }]) {
      expect(storedCameraFxEngine(v), JSON.stringify(v)).toBe('DEEPAR');
    }
  });

  it('the PUT body: one of the two engines, an optional reason, nothing else', () => {
    expect(updateCameraFxSchema.parse({ cameraFxEngine: 'FREE', reason: ' test ' })).toEqual({
      cameraFxEngine: 'FREE',
      reason: 'test',
    });
    expect(updateCameraFxSchema.safeParse({ cameraFxEngine: 'free' }).success).toBe(false);
    expect(updateCameraFxSchema.safeParse({}).success).toBe(false);
    expect(updateCameraFxSchema.safeParse({ cameraFxEngine: 'DEEPAR', extra: 1 }).success).toBe(false);
    expect(updateCameraFxSchema.safeParse({ cameraFxEngine: 'DEEPAR', reason: '' }).success).toBe(false);
  });

  it('reads the row; no row or a failing read answers DEEPAR', async () => {
    const db = (value: unknown, fail = false) =>
      ({
        siteSetting: {
          findUnique: async () => {
            if (fail) throw new Error('db down');
            return value === undefined ? null : { key: 'cameraFxEngine', value };
          },
        },
      }) as never;
    expect(await readCameraFxEngine(db('FREE'))).toBe('FREE');
    expect(await readCameraFxEngine(db(undefined))).toBe('DEEPAR');
    expect(await readCameraFxEngine(db('FREE', true))).toBe('DEEPAR');
  });
});
