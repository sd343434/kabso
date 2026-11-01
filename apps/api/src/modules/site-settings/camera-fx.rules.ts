import { z } from 'zod';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.49-live (D228, CONVENTIONS §10.79): which camera effects engine the Android app runs on the host's published
 * camera — `DEEPAR` (D144, the default) or `FREE` (Google ML Kit + MediaPipe on the device). The OWNER flips it in the
 * panel («إعدادات الموقع» → «محرك مؤثرات الكاميرا»); the app reads it in `LiveConfig.cameraFxEngine`. Stored as one row
 * of `site_settings` (key `cameraFxEngine`); absent or unknown → `DEEPAR`. Kept free of Nest so the unit tests share
 * it. Removing the free engine removes this file, its two routes and the field (docs/KNOWN_LIMITATIONS.md, D228).
 */
export const CAMERA_FX_ENGINES = ['DEEPAR', 'FREE'] as const;
export type CameraFxEngine = (typeof CAMERA_FX_ENGINES)[number];

export const CAMERA_FX_DEFAULT: CameraFxEngine = 'DEEPAR';

/** The `site_settings` key (the D228 migration adds it to the table's CHECK). */
export const CAMERA_FX_SETTING_KEY = 'cameraFxEngine';

export interface CameraFxSettingsDto {
  cameraFxEngine: CameraFxEngine;
}

/** A stored value read back: only the exact `FREE` selects the free engine. */
export function storedCameraFxEngine(value: unknown): CameraFxEngine {
  return value === 'FREE' ? 'FREE' : CAMERA_FX_DEFAULT;
}

/** The current engine (a primary-key read); any read failure answers the default. */
export async function readCameraFxEngine(
  db: Pick<Prisma.TransactionClient, 'siteSetting'>,
): Promise<CameraFxEngine> {
  try {
    const row = await db.siteSetting.findUnique({ where: { key: CAMERA_FX_SETTING_KEY } });
    return storedCameraFxEngine(row?.value);
  } catch {
    return CAMERA_FX_DEFAULT;
  }
}

/** `PUT /admin/camera-fx` (`reason` goes to the audit row). */
export const updateCameraFxSchema = z.strictObject({
  cameraFxEngine: z.enum(CAMERA_FX_ENGINES),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type UpdateCameraFxInput = z.output<typeof updateCameraFxSchema>;
