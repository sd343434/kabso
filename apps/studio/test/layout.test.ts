import { describe, expect, it } from 'vitest';
import {
  DEFAULT_LAYOUT,
  bubbleOffset,
  effectiveOrientation,
  layoutUpdate,
  missingForLive,
  nearestCorner,
  orientationOf,
  startSetup,
  wireLayout,
} from '../src/layout';

describe('layout → the D213 contract (+ D247 main)', () => {
  it('screen + bubble = main SCREEN with the corner; no camera or hidden = no bubble', () => {
    expect(wireLayout({ ...DEFAULT_LAYOUT, corner: 'BOTTOM_RIGHT' }, 'LANDSCAPE', true)).toEqual({
      orientation: 'LANDSCAPE',
      main: 'SCREEN',
      cameraOverlay: { visible: true, corner: 'BOTTOM_RIGHT' },
    });
    expect(wireLayout(DEFAULT_LAYOUT, 'LANDSCAPE', false).cameraOverlay.visible).toBe(false);
    expect(wireLayout({ ...DEFAULT_LAYOUT, bubbleVisible: false }, 'LANDSCAPE', true).cameraOverlay.visible).toBe(false);
  });

  it('camera only (OBS) = main CAMERA, never a bubble, oriented by the camera picture', () => {
    const w = wireLayout({ ...DEFAULT_LAYOUT, mode: 'camera' }, orientationOf(1920, 1080), true);
    expect(w).toEqual({ orientation: 'LANDSCAPE', main: 'CAMERA', cameraOverlay: { visible: false, corner: 'TOP_LEFT' } });
    expect(wireLayout({ ...DEFAULT_LAYOUT, mode: 'camera' }, orientationOf(1080, 1920), true).orientation).toBe('PORTRAIT');
  });

  it('orientation: auto follows the source, an override wins, unknown = landscape', () => {
    expect(orientationOf(1280, 720)).toBe('LANDSCAPE');
    expect(orientationOf(720, 1280)).toBe('PORTRAIT');
    expect(orientationOf(1000, 1000)).toBe('LANDSCAPE');
    expect(orientationOf(0, 720)).toBeNull();
    expect(effectiveOrientation('auto', 'PORTRAIT')).toBe('PORTRAIT');
    expect(effectiveOrientation('LANDSCAPE', 'PORTRAIT')).toBe('LANDSCAPE');
    expect(effectiveOrientation('auto', null)).toBe('LANDSCAPE');
  });

  it('the start body and the PUT diff (only the keys that changed; nothing → no call)', () => {
    const a = wireLayout(DEFAULT_LAYOUT, 'LANDSCAPE', true);
    expect(startSetup(a)).toEqual({ orientation: 'LANDSCAPE', main: 'SCREEN', cameraOverlay: { visible: true, corner: 'TOP_LEFT' } });
    expect(layoutUpdate(a, a)).toBeNull();
    expect(layoutUpdate(a, { ...a, cameraOverlay: { visible: true, corner: 'BOTTOM_LEFT' } })).toEqual({
      cameraOverlay: { corner: 'BOTTOM_LEFT' },
    });
    expect(layoutUpdate(a, { ...a, orientation: 'PORTRAIT', main: 'CAMERA', cameraOverlay: { visible: false, corner: 'TOP_LEFT' } })).toEqual({
      orientation: 'PORTRAIT',
      main: 'CAMERA',
      cameraOverlay: { visible: false },
    });
    expect(layoutUpdate(null, a)).toEqual(startSetup(a));
  });

  it('the bubble sits in the host\'s physical corner, and a drop picks the nearest corner', () => {
    expect(bubbleOffset('TOP_LEFT', 640, 360, 90, 12)).toEqual({ left: 12, top: 12 });
    expect(bubbleOffset('BOTTOM_RIGHT', 640, 360, 90, 12)).toEqual({ left: 538, top: 258 });
    expect(bubbleOffset('TOP_RIGHT', 640, 360, 90, 12)).toEqual({ left: 538, top: 12 });
    expect(nearestCorner(10, 10, 640, 360)).toBe('TOP_LEFT');
    expect(nearestCorner(600, 20, 640, 360)).toBe('TOP_RIGHT');
    expect(nearestCorner(30, 300, 640, 360)).toBe('BOTTOM_LEFT');
    expect(nearestCorner(600, 300, 640, 360)).toBe('BOTTOM_RIGHT');
  });

  it('what is still missing before going live', () => {
    const none = { screen: false, camera: false, microphone: false };
    expect(missingForLive(DEFAULT_LAYOUT, none, ' ')).toEqual(['needTitle', 'needScreen']);
    expect(missingForLive({ ...DEFAULT_LAYOUT, mode: 'camera' }, { ...none, screen: true }, 'x')).toEqual(['needCamera']);
    expect(missingForLive(DEFAULT_LAYOUT, { ...none, screen: true }, 'x')).toEqual([]);
  });
});
