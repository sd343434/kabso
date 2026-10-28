/**
 * Builds minimal MPEG-4 / QuickTime video files for tests (v1.41-social, D162): `ftyp`, a `moov`
 * with a movie header of the given length and tracks (a video track with `tkhd` size and matrix and
 * an `stsd` sample entry, optionally a sound track), and an `mdat` of filler bytes. Enough for the
 * server's container checks (it never decodes the video).
 */

function box(type: string, ...payload: Buffer[]): Buffer {
  const body = Buffer.concat(payload);
  const header = Buffer.alloc(8);
  header.writeUInt32BE(8 + body.length, 0);
  header.write(type, 4, 'latin1');
  return Buffer.concat([header, body]);
}

function mvhd(durationMs: number, version: 0 | 1): Buffer {
  const timescale = 1000;
  if (version === 1) {
    const p = Buffer.alloc(4 + 8 + 8 + 4 + 8 + 80);
    p[0] = 1;
    p.writeUInt32BE(timescale, 20);
    p.writeBigUInt64BE(BigInt(durationMs), 24);
    return box('mvhd', p);
  }
  const p = Buffer.alloc(4 + 4 + 4 + 4 + 4 + 80);
  p.writeUInt32BE(timescale, 12);
  p.writeUInt32BE(durationMs, 16);
  return box('mvhd', p);
}

/** `tkhd` version 0 with a 0° or 90° matrix and a 16.16 size. */
function tkhd(width: number, height: number, rotate90: boolean): Buffer {
  const p = Buffer.alloc(84);
  const m = 40;
  const one = 0x10000;
  if (rotate90) {
    p.writeInt32BE(0, m);
    p.writeInt32BE(one, m + 4);
    p.writeInt32BE(-one, m + 12);
    p.writeInt32BE(0, m + 16);
  } else {
    p.writeInt32BE(one, m);
    p.writeInt32BE(one, m + 16);
  }
  p.writeInt32BE(0x40000000, m + 32);
  p.writeUInt32BE(width * one, 76);
  p.writeUInt32BE(height * one, 80);
  return box('tkhd', p);
}

function hdlr(handler: string): Buffer {
  const p = Buffer.alloc(4 + 4 + 4 + 12 + 1);
  p.write(handler, 8, 'latin1');
  return box('hdlr', p);
}

function stsd(entry: string): Buffer {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(1, 4);
  return box('stsd', head, box(entry, Buffer.alloc(78)));
}

function videoTrak(width: number, height: number, rotate90: boolean, codec: string): Buffer {
  return box(
    'trak',
    tkhd(width, height, rotate90),
    box('mdia', hdlr('vide'), box('minf', box('stbl', stsd(codec)))),
  );
}

function soundTrak(): Buffer {
  return box('trak', box('mdia', hdlr('soun'), box('minf', box('stbl', stsd('mp4a')))));
}

export interface Mp4Options {
  readonly durationMs: number;
  /** Stored size (before rotation). Default 1080 × 1920. */
  readonly width?: number;
  readonly height?: number;
  /** A 90° display matrix (how phones store portrait video). */
  readonly rotate90?: boolean;
  readonly codec?: string;
  /** No video track (an audio-only file). */
  readonly noVideo?: boolean;
  readonly sound?: boolean;
  readonly mvhdVersion?: 0 | 1;
  /** `qt  ` for QuickTime; default `isom`. */
  readonly brand?: string;
  /** `moov` after `mdat` (not "fast start"). */
  readonly moovLast?: boolean;
  /** Filler bytes in `mdat` (the "video"). */
  readonly dataBytes?: number;
}

export function mp4(options: Mp4Options): Buffer {
  const brand = options.brand ?? 'isom';
  const ftyp = box('ftyp', Buffer.from(`${brand}\u0000\u0000\u0002\u0000isomiso2avc1mp41`, 'latin1'));
  const traks = [
    ...(options.noVideo
      ? []
      : [
          videoTrak(
            options.width ?? 1080,
            options.height ?? 1920,
            options.rotate90 ?? false,
            options.codec ?? 'avc1',
          ),
        ]),
    ...(options.sound === false ? [] : [soundTrak()]),
  ];
  const moov = box('moov', mvhd(options.durationMs, options.mvhdVersion ?? 0), ...traks);
  const mdat = box('mdat', Buffer.alloc(options.dataBytes ?? 256, 0x42));
  return Buffer.concat(options.moovLast ? [ftyp, mdat, moov] : [ftyp, moov, mdat]);
}
