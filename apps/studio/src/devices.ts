/**
 * Cameras and microphones (D247). OBS Virtual Camera is a first-class camera: it is found by its label (Windows,
 * macOS and Linux's v4l2loopback all name it «OBS Virtual Camera»), listed first and marked. Labels are empty until
 * the page may use the camera, so the picker asks for access once and lists again (and again on `devicechange`, e.g.
 * when OBS's «Start Virtual Camera» is pressed after the page opened).
 */

export interface DeviceOption {
  id: string;
  label: string;
  kind: 'videoinput' | 'audioinput';
  obs: boolean;
}

const OBS = /\bobs\b.*virtual|obs-camera|obs virtual/i;

export function isObsCamera(label: string): boolean {
  return OBS.test(label);
}

/**
 * The cameras and microphones of `enumerateDevices`, OBS Virtual Camera first, each labelled (an unlabelled device
 * — no permission yet — gets «Camera 1», …). The `default` / `communications` aliases Chrome adds for microphones are
 * left out when the real device is listed too.
 */
export function deviceOptions(devices: readonly Pick<MediaDeviceInfo, 'deviceId' | 'kind' | 'label' | 'groupId'>[]): {
  cameras: DeviceOption[];
  microphones: DeviceOption[];
  labelled: boolean;
} {
  const cameras: DeviceOption[] = [];
  const microphones: DeviceOption[] = [];
  let labelled = false;
  const realMics = devices.filter((d) => d.kind === 'audioinput' && d.deviceId !== 'default' && d.deviceId !== 'communications');
  for (const d of devices) {
    if (d.kind !== 'videoinput' && d.kind !== 'audioinput') continue;
    if (!d.deviceId) continue;
    if (d.label) labelled = true;
    if (d.kind === 'audioinput' && (d.deviceId === 'default' || d.deviceId === 'communications') && realMics.length > 0) {
      continue;
    }
    const list = d.kind === 'videoinput' ? cameras : microphones;
    list.push({ id: d.deviceId, label: d.label, kind: d.kind, obs: d.kind === 'videoinput' && isObsCamera(d.label) });
  }
  cameras.sort((a, b) => Number(b.obs) - Number(a.obs));
  return { cameras, microphones, labelled };
}

/** The camera to pick by default: the one chosen before if it is still there, else OBS when present, else the first. */
export function defaultCamera(cameras: readonly DeviceOption[], previous: string | null, preferObs: boolean): string | null {
  if (previous && cameras.some((c) => c.id === previous)) return previous;
  if (preferObs) {
    const obs = cameras.find((c) => c.obs);
    if (obs) return obs.id;
  }
  return cameras[0]?.id ?? null;
}

export function defaultMicrophone(mics: readonly DeviceOption[], previous: string | null): string | null {
  if (previous && mics.some((m) => m.id === previous)) return previous;
  return mics[0]?.id ?? null;
}

/** The screen quality presets the host picks (720p30 ≈ 2.5 Mbps as the Android app, 1080p30 ≈ 4 Mbps). */
export const QUALITIES = {
  '720p': { width: 1280, height: 720, frameRate: 30, maxBitrate: 2_500_000 },
  '1080p': { width: 1920, height: 1080, frameRate: 30, maxBitrate: 4_000_000 },
} as const;
export type QualityId = keyof typeof QUALITIES;

/**
 * The camera constraints. A camera that is the whole picture (OBS «camera only») asks for the chosen quality and
 * keeps its own aspect; a bubble asks for a small picture (it is drawn as a circle of ~100 px on a phone).
 */
export function cameraConstraints(deviceId: string | null, asMain: boolean, quality: QualityId): MediaTrackConstraints {
  const q = QUALITIES[quality];
  const base: MediaTrackConstraints = deviceId ? { deviceId: { exact: deviceId } } : {};
  return asMain
    ? { ...base, width: { ideal: q.width }, height: { ideal: q.height }, frameRate: { ideal: 30, max: 30 } }
    : { ...base, width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 } };
}

export function microphoneConstraints(deviceId: string | null): MediaTrackConstraints {
  return {
    ...(deviceId ? { deviceId: { exact: deviceId } } : {}),
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  };
}
