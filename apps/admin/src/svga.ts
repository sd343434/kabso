/**
 * v1.71-social (D207): a small SVGA 2.x reader for the panel's preview of a gift effect — the file is a zlib stream of
 * the protobuf `MovieEntity` (svga.proto): `params` (view box, fps, frames), `images` (PNG bytes by key) and `sprites`
 * (an image key and one `FrameEntity` per frame: alpha, layout, transform). The preview draws the bitmap sprites
 * frame by frame; vector shapes, mattes and embedded audio are not drawn (the app's player shows them). No
 * dependency: the panel stays offline-buildable and the bundle small.
 */

export interface SvgaFrame {
  alpha: number;
  layout: { x: number; y: number; width: number; height: number };
  transform: { a: number; b: number; c: number; d: number; tx: number; ty: number };
}

export interface SvgaSprite {
  imageKey: string;
  frames: SvgaFrame[];
}

export interface SvgaMovie {
  version: string;
  width: number;
  height: number;
  fps: number;
  frames: number;
  images: Map<string, Uint8Array>;
  sprites: SvgaSprite[];
  /** Sprites drawn with vector shapes only (not previewed). */
  vectorSprites: number;
}

/** A minimal protobuf reader (varint, fixed32, length-delimited). */
class Reader {
  pos = 0;
  constructor(
    readonly buf: Uint8Array,
    readonly end = buf.length,
  ) {}
  done(): boolean {
    return this.pos >= this.end;
  }
  varint(): number {
    let result = 0;
    let shift = 0;
    for (;;) {
      if (this.pos >= this.end) throw new Error('truncated varint');
      const b = this.buf[this.pos++]!;
      result += (b & 0x7f) * 2 ** shift;
      if ((b & 0x80) === 0) return result;
      shift += 7;
      if (shift > 63) throw new Error('bad varint');
    }
  }
  float(): number {
    if (this.pos + 4 > this.end) throw new Error('truncated float');
    const v = new DataView(this.buf.buffer, this.buf.byteOffset + this.pos, 4).getFloat32(0, true);
    this.pos += 4;
    return v;
  }
  bytes(): Uint8Array {
    const len = this.varint();
    if (this.pos + len > this.end) throw new Error('truncated field');
    const out = this.buf.subarray(this.pos, this.pos + len);
    this.pos += len;
    return out;
  }
  skip(wire: number): void {
    if (wire === 0) this.varint();
    else if (wire === 1) this.pos += 8;
    else if (wire === 2) this.bytes();
    else if (wire === 5) this.pos += 4;
    else throw new Error(`wire type ${String(wire)}`);
  }
  /** Each field of the message: its number and wire type, the reader positioned on its value. */
  *fields(): Generator<[number, number]> {
    while (!this.done()) {
      const tag = this.varint();
      yield [Math.floor(tag / 8), tag & 7];
    }
  }
}

const text = new TextDecoder();
const sub = (bytes: Uint8Array) => new Reader(bytes);

function floats<T extends string>(bytes: Uint8Array, names: readonly T[]): Record<T, number> {
  const out = Object.fromEntries(names.map((n) => [n, 0])) as Record<T, number>;
  const r = sub(bytes);
  for (const [field, wire] of r.fields()) {
    const name = names[field - 1];
    if (name && wire === 5) out[name] = r.float();
    else r.skip(wire);
  }
  return out;
}

function frameOf(bytes: Uint8Array): SvgaFrame & { shapes: number } {
  const frame: SvgaFrame & { shapes: number } = {
    alpha: 0,
    layout: { x: 0, y: 0, width: 0, height: 0 },
    transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 },
    shapes: 0,
  };
  const r = sub(bytes);
  for (const [field, wire] of r.fields()) {
    if (field === 1 && wire === 5) frame.alpha = r.float();
    else if (field === 2 && wire === 2) frame.layout = floats(r.bytes(), ['x', 'y', 'width', 'height'] as const);
    else if (field === 3 && wire === 2) frame.transform = floats(r.bytes(), ['a', 'b', 'c', 'd', 'tx', 'ty'] as const);
    else if (field === 5 && wire === 2) {
      r.bytes();
      frame.shapes += 1;
    } else r.skip(wire);
  }
  return frame;
}

/** Decodes an inflated `MovieEntity`. Throws on bytes that are not one. */
export function parseMovieEntity(bytes: Uint8Array): SvgaMovie {
  const movie: SvgaMovie = { version: '', width: 0, height: 0, fps: 20, frames: 0, images: new Map(), sprites: [], vectorSprites: 0 };
  const r = sub(bytes);
  for (const [field, wire] of r.fields()) {
    if (field === 1 && wire === 2) movie.version = text.decode(r.bytes());
    else if (field === 2 && wire === 2) {
      const p = sub(r.bytes());
      for (const [f, w] of p.fields()) {
        if (f === 1 && w === 5) movie.width = p.float();
        else if (f === 2 && w === 5) movie.height = p.float();
        else if (f === 3 && w === 0) movie.fps = p.varint();
        else if (f === 4 && w === 0) movie.frames = p.varint();
        else p.skip(w);
      }
    } else if (field === 3 && wire === 2) {
      const e = sub(r.bytes());
      let key = '';
      let value: Uint8Array = new Uint8Array();
      for (const [f, w] of e.fields()) {
        if (f === 1 && w === 2) key = text.decode(e.bytes());
        else if (f === 2 && w === 2) value = new Uint8Array(e.bytes());
        else e.skip(w);
      }
      movie.images.set(key, value);
    } else if (field === 4 && wire === 2) {
      const s = sub(r.bytes());
      const sprite: SvgaSprite = { imageKey: '', frames: [] };
      let shapes = 0;
      for (const [f, w] of s.fields()) {
        if (f === 1 && w === 2) sprite.imageKey = text.decode(s.bytes());
        else if (f === 2 && w === 2) {
          const fr = frameOf(s.bytes());
          shapes += fr.shapes;
          sprite.frames.push(fr);
        } else s.skip(w);
      }
      if (!movie.images.has(sprite.imageKey) && shapes > 0) movie.vectorSprites += 1;
      movie.sprites.push(sprite);
    } else r.skip(wire);
  }
  if (!movie.version && movie.frames === 0) throw new Error('not an SVGA movie');
  return movie;
}

/** Inflates (zlib) and decodes an SVGA 2.x file. */
export async function readSvga(file: Blob): Promise<SvgaMovie> {
  const stream = file.stream().pipeThrough(new DecompressionStream('deflate'));
  const inflated = new Uint8Array(await new Response(stream).arrayBuffer());
  return parseMovieEntity(inflated);
}

/**
 * Plays `movie` on `canvas` (scaled to fit), looping, until the returned stop function is called. Images that do not
 * decode are skipped.
 */
export async function playSvga(movie: SvgaMovie, canvas: HTMLCanvasElement): Promise<() => void> {
  const bitmaps = new Map<string, ImageBitmap>();
  for (const [key, bytes] of movie.images) {
    try {
      bitmaps.set(key, await createImageBitmap(new Blob([new Uint8Array(bytes)])));
    } catch {
      // Not a bitmap (or broken): not drawn.
    }
  }
  const ctx = canvas.getContext('2d');
  let stopped = false;
  let frame = 0;
  const scale = Math.min(canvas.width / (movie.width || 1), canvas.height / (movie.height || 1));
  const ox = (canvas.width - movie.width * scale) / 2;
  const oy = (canvas.height - movie.height * scale) / 2;
  const total = Math.max(1, movie.frames);
  const timer = setInterval(() => {
    if (stopped || !ctx) return;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (const sprite of movie.sprites) {
      const f = sprite.frames[frame];
      const img = bitmaps.get(sprite.imageKey);
      if (!f || !img || f.alpha <= 0) continue;
      const t = f.transform;
      ctx.setTransform(t.a * scale, t.b * scale, t.c * scale, t.d * scale, t.tx * scale + ox, t.ty * scale + oy);
      ctx.globalAlpha = Math.min(1, f.alpha);
      ctx.drawImage(img, f.layout.x, f.layout.y, f.layout.width, f.layout.height);
    }
    ctx.globalAlpha = 1;
    frame = (frame + 1) % total;
  }, 1000 / Math.max(1, Math.min(60, movie.fps || 20)));
  return () => {
    stopped = true;
    clearInterval(timer);
    for (const b of bitmaps.values()) b.close();
  };
}
