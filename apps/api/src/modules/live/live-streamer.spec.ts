import { describe, expect, it } from 'vitest';
import { livesQuery } from '../admin-panel/admin-v2.schemas.js';
import { LIVE_KIND_MODES, LIVE_KINDS } from './live-cursor.js';
import { roomMetadataJson } from './live-metadata.service.js';
import { streamerOf } from './live-rooms.service.js';
import { hostSources } from './live-seats.service.js';
import {
  DEFAULT_STREAMER_CORNER,
  hasGuestSeats,
  isVoiceMode,
  startLiveRoomSchema,
  STREAMER_CORNERS,
  updateLiveStreamerSchema,
} from './live.schemas.js';

/** v1.56-live (D213, CONVENTIONS §10.86): the streamer live's rules without a database. */
describe('D213 streamer rules', () => {
  it('`kind=streamer` is STREAMER; the main hub kinds `solo` and `video` list it too, no other', () => {
    expect(LIVE_KINDS).toContain('streamer');
    expect(LIVE_KIND_MODES.streamer).toEqual(['STREAMER']);
    expect(LIVE_KIND_MODES.solo).toEqual(['SOLO', 'PK', 'STREAMER']);
    expect(LIVE_KIND_MODES.video).toEqual(['SOLO', 'PK', 'MULTI', 'STREAMER']);
    for (const kind of ['audio', 'multi', 'party', 'podcast'] as const) {
      expect(LIVE_KIND_MODES[kind]).not.toContain('STREAMER');
    }
  });

  it('the host publishes the screen besides camera and microphone; no seats, not voice', () => {
    expect(hostSources('STREAMER')).toEqual(['camera', 'microphone', 'screen_share', 'screen_share_audio']);
    expect(hostSources('SOLO')).toEqual(['camera', 'microphone']);
    expect(hasGuestSeats('STREAMER')).toBe(false);
    expect(isVoiceMode('STREAMER')).toBe(false);
  });

  it('start: `streamer` only with mode STREAMER, no seat count, valid values', () => {
    const ok = startLiveRoomSchema.safeParse({
      title: 'بث',
      mode: 'STREAMER',
      streamer: { orientation: 'LANDSCAPE', cameraOverlay: { visible: false, corner: 'BOTTOM_LEFT' } },
    });
    expect(ok.success).toBe(true);
    expect(startLiveRoomSchema.safeParse({ title: 'بث', mode: 'STREAMER' }).success).toBe(true);
    expect(startLiveRoomSchema.safeParse({ title: 'بث', mode: 'STREAMER', seatCount: 4 }).success).toBe(
      false,
    );
    expect(startLiveRoomSchema.safeParse({ title: 'بث', streamer: {} }).success).toBe(false);
    expect(
      startLiveRoomSchema.safeParse({ title: 'بث', mode: 'STREAMER', streamer: { cameraOverlay: { x: 1 } } })
        .success,
    ).toBe(false);
    expect(STREAMER_CORNERS).toContain(DEFAULT_STREAMER_CORNER);
  });

  it('update: at least one key, a non-empty bubble, known values only', () => {
    expect(updateLiveStreamerSchema.parse({ orientation: 'PORTRAIT' })).toEqual({ orientation: 'PORTRAIT' });
    expect(updateLiveStreamerSchema.parse({ cameraOverlay: { corner: 'TOP_RIGHT' } })).toEqual({
      cameraOverlay: { corner: 'TOP_RIGHT' },
    });
    // v1.57-live (D247): `main` alone is a change.
    expect(updateLiveStreamerSchema.parse({ main: 'CAMERA' })).toEqual({ main: 'CAMERA' });
    for (const bad of [
      {},
      { cameraOverlay: {} },
      { orientation: 'portrait' },
      { cameraOverlay: { corner: 'TOP' } },
      { main: 'OBS' },
      { main: 'camera' },
    ]) {
      expect(updateLiveStreamerSchema.safeParse(bad).success).toBe(false);
    }
  });

  it('the metadata carries `streamerVersion` once it moved; other keys unchanged', () => {
    expect(roomMetadataJson(3, 1234)).toBe('{"seatsVersion":3,"score":1234}');
    expect(JSON.parse(roomMetadataJson(0, 5, 0, 4))).toEqual({
      seatsVersion: 0,
      score: 5,
      streamerVersion: 4,
    });
    expect(JSON.parse(roomMetadataJson(1, 5, 2, 4))).toEqual({
      seatsVersion: 1,
      score: 5,
      roomInfoVersion: 2,
      streamerVersion: 4,
    });
  });

  it('`LiveStreamer` only for a STREAMER row with its fields', () => {
    const row = {
      mode: 'STREAMER',
      streamer_orientation: 'LANDSCAPE',
      streamer_camera_visible: true,
      streamer_camera_corner: 'TOP_RIGHT',
      streamer_version: 7,
    };
    expect(streamerOf(row)).toEqual({
      orientation: 'LANDSCAPE',
      cameraOverlay: { visible: true, corner: 'TOP_RIGHT' },
      main: 'SCREEN',
      version: 7,
    });
    // v1.57-live (D247): the camera as the main picture; a row without the column reads as SCREEN.
    expect(streamerOf({ ...row, streamer_main: 'CAMERA' })?.main).toBe('CAMERA');
    expect(streamerOf({ ...row, streamer_main: null })?.main).toBe('SCREEN');
    expect(streamerOf({ ...row, mode: 'SOLO' })).toBeNull();
    expect(streamerOf({ ...row, streamer_camera_corner: null })).toBeNull();
  });

  it('the admin panel filters the lives on air by STREAMER', () => {
    expect(livesQuery.parse({ mode: 'STREAMER' }).mode).toBe('STREAMER');
    expect(livesQuery.safeParse({ mode: 'GAME' }).success).toBe(false);
  });
});
