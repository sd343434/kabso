import { describe, expect, it } from 'vitest';
import { cameraConstraints, defaultCamera, defaultMicrophone, deviceOptions, isObsCamera, microphoneConstraints } from '../src/devices';

const dev = (kind: MediaDeviceKind, deviceId: string, label: string) => ({ kind, deviceId, label, groupId: 'g' });

describe('source selection', () => {
  it('finds OBS Virtual Camera by its label on every desktop OS', () => {
    expect(isObsCamera('OBS Virtual Camera')).toBe(true);
    expect(isObsCamera('OBS Virtual Camera (obs-camera)')).toBe(true);
    expect(isObsCamera('obs virtual camera')).toBe(true);
    expect(isObsCamera('Integrated Webcam (0bda:58f4)')).toBe(false);
    expect(isObsCamera('Logitech BRIO')).toBe(false);
    expect(isObsCamera('Jobs Camera')).toBe(false);
  });

  it('lists OBS first and marks it; drops the default / communications microphone aliases', () => {
    const list = deviceOptions([
      dev('videoinput', 'cam1', 'Integrated Webcam'),
      dev('videoinput', 'obs', 'OBS Virtual Camera'),
      dev('audioinput', 'default', 'Default - Microphone Array'),
      dev('audioinput', 'communications', 'Communications - Microphone Array'),
      dev('audioinput', 'mic1', 'Microphone Array'),
      dev('audiooutput', 'spk', 'Speakers'),
    ]);
    expect(list.cameras.map((c) => [c.id, c.obs])).toEqual([
      ['obs', true],
      ['cam1', false],
    ]);
    expect(list.microphones.map((m) => m.id)).toEqual(['mic1']);
    expect(list.labelled).toBe(true);
  });

  it('before the permission the labels are empty (the studio asks once, then lists again)', () => {
    const list = deviceOptions([dev('videoinput', 'a', ''), dev('audioinput', 'default', '')]);
    expect(list.labelled).toBe(false);
    expect(list.microphones.map((m) => m.id)).toEqual(['default']);
  });

  it('the default camera: the previous choice, else OBS for the camera-only layout, else the first', () => {
    const { cameras } = deviceOptions([dev('videoinput', 'cam1', 'Webcam'), dev('videoinput', 'obs', 'OBS Virtual Camera')]);
    expect(defaultCamera(cameras, 'cam1', true)).toBe('cam1');
    expect(defaultCamera(cameras, 'gone', true)).toBe('obs');
    expect(defaultCamera(cameras, null, false)).toBe('obs');
    const plain = deviceOptions([dev('videoinput', 'cam1', 'Webcam'), dev('videoinput', 'cam2', 'USB')]).cameras;
    expect(defaultCamera(plain, null, true)).toBe('cam1');
    expect(defaultCamera([], null, true)).toBeNull();
    expect(defaultMicrophone([], 'x')).toBeNull();
  });

  it('a camera that is the whole picture asks for the chosen quality; a bubble a small picture', () => {
    expect(cameraConstraints('obs', true, '1080p')).toEqual({
      deviceId: { exact: 'obs' },
      width: { ideal: 1920 },
      height: { ideal: 1080 },
      frameRate: { ideal: 30, max: 30 },
    });
    expect(cameraConstraints('cam', false, '1080p')).toMatchObject({ width: { ideal: 640 }, height: { ideal: 480 } });
    expect(microphoneConstraints('mic')).toMatchObject({ deviceId: { exact: 'mic' }, echoCancellation: true });
    expect(microphoneConstraints(null)).not.toHaveProperty('deviceId');
  });
});
