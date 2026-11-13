import { describe, expect, it } from 'vitest';
import { wornAvatarFrameOf } from '../posts/post-views.js';
import { canChooseHostFrame, desiredHostFrame, hostFrameStyle } from './host-frames.js';
import { hostFrameStyleBodySchema } from './host-frame.service.js';

describe('active-host frame style (D186)', () => {
  it('male is blue and female is pink, whatever was chosen', () => {
    expect(hostFrameStyle('MALE', null)).toEqual({ style: 'BLUE', from: 'GENDER' });
    expect(hostFrameStyle('MALE', 'PINK')).toEqual({ style: 'BLUE', from: 'GENDER' });
    expect(hostFrameStyle('FEMALE', null)).toEqual({ style: 'PINK', from: 'GENDER' });
    expect(hostFrameStyle('FEMALE', 'BLUE')).toEqual({ style: 'PINK', from: 'GENDER' });
  });

  it('prefer-not-to-say or no gender: the choice, or nothing until chosen', () => {
    expect(hostFrameStyle('UNDISCLOSED', null)).toEqual({ style: null, from: null });
    expect(hostFrameStyle(null, null)).toEqual({ style: null, from: null });
    expect(hostFrameStyle('UNDISCLOSED', 'PINK')).toEqual({ style: 'PINK', from: 'CHOICE' });
    expect(hostFrameStyle(null, 'BLUE')).toEqual({ style: 'BLUE', from: 'CHOICE' });
    expect(canChooseHostFrame('UNDISCLOSED')).toBe(true);
    expect(canChooseHostFrame(null)).toBe(true);
    expect(canChooseHostFrame('MALE')).toBe(false);
    expect(canChooseHostFrame('FEMALE')).toBe(false);
  });

  it('the frame owned is the style’s while active, none otherwise', () => {
    expect(desiredHostFrame(true, 'MALE', null)).toBe('host_frame_blue');
    expect(desiredHostFrame(true, 'FEMALE', null)).toBe('host_frame_pink');
    expect(desiredHostFrame(true, 'UNDISCLOSED', 'PINK')).toBe('host_frame_pink');
    expect(desiredHostFrame(true, 'UNDISCLOSED', null)).toBeNull();
    expect(desiredHostFrame(false, 'MALE', null)).toBeNull();
    expect(desiredHostFrame(false, null, 'BLUE')).toBeNull();
  });

  it('the style request is BLUE or PINK only', () => {
    expect(hostFrameStyleBodySchema.parse({ style: 'BLUE' })).toEqual({ style: 'BLUE' });
    expect(hostFrameStyleBodySchema.safeParse({ style: 'GREEN' }).success).toBe(false);
    expect(hostFrameStyleBodySchema.safeParse({}).success).toBe(false);
    expect(hostFrameStyleBodySchema.safeParse({ style: 'PINK', x: 1 }).success).toBe(false);
  });
});

describe('UserSummary.avatarFrame (D186)', () => {
  const now = new Date('2026-10-30T12:00:00Z');
  const row = (code: string, expiresAt: Date | null) => ({
    itemCode: code,
    expiresAt,
    item: { assetKey: code },
  });

  it('is the worn frame unless it has expired', () => {
    expect(wornAvatarFrameOf(undefined, now)).toBeNull();
    expect(wornAvatarFrameOf([], now)).toBeNull();
    expect(wornAvatarFrameOf([row('host_frame_blue', null)], now)).toEqual({
      code: 'host_frame_blue',
      assetKey: 'host_frame_blue',
    });
    expect(wornAvatarFrameOf([row('support_frame_01', new Date('2026-10-30T11:59:59Z'))], now)).toBeNull();
    expect(wornAvatarFrameOf([row('support_frame_01', new Date('2026-10-31T00:00:00Z'))], now)?.code).toBe(
      'support_frame_01',
    );
  });
});
