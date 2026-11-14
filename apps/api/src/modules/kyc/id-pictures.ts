import { AppException } from '../../common/errors/app-exception.js';
import type { MediaService } from '../media/media.service.js';

/**
 * v1.80-kyc (D227, §10.77): the manual ID card + selfie of D185 / D206 / D209 are the fallback only while Didit is
 * OFF. With Didit ON they are not asked: the two upload ids may be left out, and when sent they are ignored (not
 * consumed: the pending uploads expire like any unused upload) — no ID picture is stored next to a Didit check.
 * With Didit OFF both are required (400 `required`) and consumed into the application's private keys, as before.
 */
export async function takeIdPictures(
  media: MediaService,
  userId: string,
  input: { photoUploadId?: string | undefined; selfieUploadId?: string | undefined },
  keys: { photo: string; selfie: string },
  kycOn: boolean,
): Promise<{ photoKey: string | null; selfieKey: string | null }> {
  if (kycOn) return { photoKey: null, selfieKey: null };
  const missing = [
    ...(input.photoUploadId ? [] : [{ field: 'photoUploadId', issue: 'required' }]),
    ...(input.selfieUploadId ? [] : [{ field: 'selfieUploadId', issue: 'required' }]),
  ];
  if (missing.length > 0) throw AppException.validation(missing);
  await media.assertEnabled();
  if (!(await media.consumePrivateImage(userId, input.photoUploadId!, 'RECHARGE_AGENT_PHOTO', keys.photo))) {
    throw AppException.validation([{ field: 'photoUploadId', issue: 'invalid_value' }]);
  }
  if (
    !(await media.consumePrivateImage(userId, input.selfieUploadId!, 'RECHARGE_AGENT_SELFIE', keys.selfie))
  ) {
    await media.deletePrivateObjects([keys.photo]).catch(() => undefined);
    throw AppException.validation([{ field: 'selfieUploadId', issue: 'invalid_value' }]);
  }
  return { photoKey: keys.photo, selfieKey: keys.selfie };
}
