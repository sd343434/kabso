import { describe, expect, it } from 'vitest';
import { mp4 } from '../../../test/helpers/mp4.js';
import {
  InvalidVideoError,
  MAX_MOOV_BYTES,
  VIDEO_LIMITS,
  inspectVideo,
  type VideoContentType,
  type VideoKind,
} from './media-video.js';

/** Inspects in-memory bytes through ranged reads, counting them. */
async function inspect(
  bytes: Buffer,
  kind: VideoKind = 'REEL_VIDEO',
  type: VideoContentType = 'video/mp4',
  size = bytes.length,
) {
  let reads = 0;
  let largest = 0;
  const info = await inspectVideo(
    (offset, length) => {
      reads += 1;
      largest = Math.max(largest, length);
      return Promise.resolve(bytes.subarray(offset, offset + length));
    },
    size,
    type,
    kind,
  );
  return { info, reads, largest };
}

const rejects = (bytes: Buffer, kind: VideoKind = 'REEL_VIDEO', type: VideoContentType = 'video/mp4') =>
  expect(inspect(bytes, kind, type)).rejects.toBeInstanceOf(InvalidVideoError);

describe('videos (v1.41-social, D162, CONVENTIONS §11.14)', () => {
  it('reads the length, codec and display size (versions 0 and 1)', async () => {
    expect((await inspect(mp4({ durationMs: 12_345 }))).info).toEqual({
      width: 1080,
      height: 1920,
      durationMs: 12_345,
      codec: 'avc1',
    });
    const v1 = await inspect(mp4({ durationMs: 59_000, mvhdVersion: 1, codec: 'hvc1' }));
    expect(v1.info).toMatchObject({ durationMs: 59_000, codec: 'hvc1' });
  });

  it('applies a 90° matrix (a phone portrait stored landscape)', async () => {
    const { info } = await inspect(mp4({ durationMs: 5_000, width: 1920, height: 1080, rotate90: true }));
    expect(info).toMatchObject({ width: 1080, height: 1920 });
  });

  it('accepts moov after mdat, reading headers and the moov only (never the whole file)', async () => {
    const bytes = mp4({ durationMs: 5_000, moovLast: true, dataBytes: 2_000_000 });
    const { info, reads, largest } = await inspect(bytes);
    expect(info.durationMs).toBe(5_000);
    expect(reads).toBeLessThan(10);
    expect(largest).toBeLessThan(10_000);
  });

  // D168 (owner): a post video is at most 90 s (was 180 s); a reel stays at most 60 s.
  it('enforces each kind length: reel ≤ 60 s, post ≤ 90 s (+ 500 ms padding), ≥ 1 s', async () => {
    expect(VIDEO_LIMITS.POST_VIDEO.maxDurationMs).toBe(90_000);
    expect(VIDEO_LIMITS.REEL_VIDEO.maxDurationMs).toBe(60_000);
    expect((await inspect(mp4({ durationMs: 60_500 }))).info.durationMs).toBe(60_000);
    await rejects(mp4({ durationMs: 60_501 }));
    expect((await inspect(mp4({ durationMs: 90_000 }), 'POST_VIDEO')).info.durationMs).toBe(90_000);
    expect((await inspect(mp4({ durationMs: 90_500 }), 'POST_VIDEO')).info.durationMs).toBe(90_000);
    await rejects(mp4({ durationMs: 90_501 }), 'POST_VIDEO');
    await rejects(mp4({ durationMs: 120_000 }), 'POST_VIDEO');
    await rejects(mp4({ durationMs: 180_000 }), 'POST_VIDEO');
    await rejects(mp4({ durationMs: 999 }));
  });

  it('enforces each kind size before reading', async () => {
    const bytes = mp4({ durationMs: 5_000 });
    await expect(
      inspect(bytes, 'REEL_VIDEO', 'video/mp4', VIDEO_LIMITS.REEL_VIDEO.maxBytes + 1),
    ).rejects.toBeInstanceOf(InvalidVideoError);
  });

  it('the brand decides with the declared type (QuickTime ⇔ qt)', async () => {
    const mov = mp4({ durationMs: 3_000, brand: 'qt  ' });
    expect((await inspect(mov, 'POST_VIDEO', 'video/quicktime')).info.durationMs).toBe(3_000);
    await rejects(mov, 'POST_VIDEO', 'video/mp4');
    await rejects(mp4({ durationMs: 3_000 }), 'POST_VIDEO', 'video/quicktime');
  });

  it('refuses audio-only files, other codecs and odd sizes', async () => {
    await rejects(mp4({ durationMs: 3_000, noVideo: true }));
    await rejects(mp4({ durationMs: 3_000, codec: 'vp09' }));
    await rejects(mp4({ durationMs: 3_000, width: 8, height: 8 }));
    await rejects(mp4({ durationMs: 3_000, width: 8192, height: 4320 }));
  });

  it('refuses a file that is not a well-formed box list', async () => {
    const good = mp4({ durationMs: 3_000 });
    await rejects(Buffer.from('not a video at all, just text....'));
    await rejects(good.subarray(0, good.length - 10)); // the last box overruns the file
    await rejects(Buffer.concat([good, Buffer.from('junk')])); // trailing bytes are not a box
    const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, ...Buffer.alloc(60)]);
    await rejects(jpeg);
  });

  it('refuses a missing mdat or a moov larger than 16 MiB', async () => {
    const good = mp4({ durationMs: 3_000, dataBytes: 8 });
    await rejects(good.subarray(0, good.length - 16)); // ftyp + moov only
    const huge = Buffer.alloc(16);
    huge.writeUInt32BE(MAX_MOOV_BYTES + 16, 0);
    huge.write('moov', 4, 'latin1');
    const ftyp = good.subarray(0, good.readUInt32BE(0));
    const mdat = Buffer.alloc(16);
    mdat.writeUInt32BE(16, 0);
    mdat.write('mdat', 4, 'latin1');
    const sized = Buffer.concat([ftyp, mdat, huge]);
    await expect(
      inspectVideo(
        (offset, length) => Promise.resolve(sized.subarray(offset, offset + length)),
        ftyp.length + 16 + MAX_MOOV_BYTES + 16,
        'video/mp4',
        'REEL_VIDEO',
      ),
    ).rejects.toBeInstanceOf(InvalidVideoError);
  });
});
