/**
 * Builds minimal MPEG-4 audio files for tests (CP-017 voice clips): `ftyp`, a `moov` with a movie
 * header of the given length and one track per handler, and an `mdat` of filler bytes. Enough
 * for the server's container checks (it never decodes the audio).
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

function trak(handler: string): Buffer {
  const hdlr = Buffer.alloc(4 + 4 + 4 + 12 + 1);
  hdlr.write(handler, 8, 'latin1');
  return box('trak', box('mdia', box('hdlr', hdlr)));
}

export interface M4aOptions {
  readonly durationMs: number;
  readonly handlers?: readonly string[];
  readonly mvhdVersion?: 0 | 1;
  /** Filler bytes in `mdat` (the "audio"). */
  readonly dataBytes?: number;
}

export function m4a(options: M4aOptions): Buffer {
  const ftyp = box('ftyp', Buffer.from('M4A \u0000\u0000\u0002\u0000M4A isomiso2', 'latin1'));
  const moov = box(
    'moov',
    mvhd(options.durationMs, options.mvhdVersion ?? 0),
    ...(options.handlers ?? ['soun']).map(trak),
  );
  return Buffer.concat([ftyp, moov, box('mdat', Buffer.alloc(options.dataBytes ?? 64, 0x21))]);
}
