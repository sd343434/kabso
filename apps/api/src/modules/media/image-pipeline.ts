import sharp, { type Sharp, type SharpOptions } from 'sharp';
import { detectContentType, readImageHeader } from './image-header.js';
import {
  MEDIA_MAX_PIXELS,
  MEDIA_MAX_SIDE,
  type DerivativeSpec,
  type MediaContentType,
  type MediaFailureIssue,
} from './media.constants.js';

/**
 * Bounded image verification and processing (CONVENTIONS §11.2, §11.11). This module is the code
 * that runs inside the isolated image worker (image-worker.ts); tests also call it in-process.
 *
 * Order: magic bytes must match the declared type → header-only width/height/animation check
 * against the limits (no decoder involved yet) → decode with only the JPEG/PNG/WebP loaders and the
 * decoder's own pixel limit → EXIF orientation → centre-crop to the purpose's ratio → sRGB →
 * resize (never upscale) → WebP. Output carries no metadata (EXIF/GPS, XMP, IPTC, comments, PNG
 * text, ICC): sharp writes none unless asked, and nothing here asks.
 */

export interface ProcessRules {
  readonly ratio: readonly [number, number];
  readonly minWidth: number;
  readonly minHeight: number;
  readonly main: DerivativeSpec;
  readonly thumb: DerivativeSpec;
}

export interface ProcessJob {
  readonly bytes: Uint8Array;
  readonly declaredType: MediaContentType;
  readonly rules: ProcessRules;
  /** Inner per-pipeline time limit (the parent also kills the worker at its own deadline). */
  readonly timeoutSeconds: number;
}

export interface Derivative {
  readonly data: Uint8Array;
  readonly width: number;
  readonly height: number;
}

export type ProcessOutcome =
  | {
      readonly ok: true;
      readonly detectedType: MediaContentType;
      readonly main: Derivative;
      readonly thumb: Derivative;
    }
  | { readonly ok: false; readonly issue: MediaFailureIssue; readonly reason: string };

const SHARP_FORMAT: Readonly<Record<MediaContentType, string>> = {
  'image/jpeg': 'jpeg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/** libvips loaders allowed: JPEG, PNG and WebP from a buffer. Everything else is blocked. */
export const ALLOWED_LOADERS = [
  'VipsForeignLoadJpegBuffer',
  'VipsForeignLoadPngBuffer',
  'VipsForeignLoadWebpBuffer',
];

let configured = false;

/**
 * Process-wide sharp settings for untrusted input: block every libvips loader except the three
 * above (no SVG/XML, TIFF, GIF, HEIF, PDF, RAW, …, so no external fetches and a minimal decoder
 * surface), no operation cache, one libvips thread per image.
 */
export function configureSharp(): void {
  if (configured) return;
  sharp.block({ operation: ['VipsForeignLoad'] });
  sharp.unblock({ operation: ALLOWED_LOADERS });
  sharp.cache(false);
  sharp.concurrency(1);
  configured = true;
}

function fail(issue: MediaFailureIssue, reason: string): ProcessOutcome {
  return { ok: false, issue, reason };
}

/** Largest centred crop with the given ratio inside `width` × `height`. */
export function centredCrop(
  width: number,
  height: number,
  ratio: readonly [number, number],
): { left: number; top: number; width: number; height: number } {
  const [rw, rh] = ratio;
  let cropW = Math.min(width, Math.floor((height * rw) / rh));
  let cropH = Math.floor((cropW * rh) / rw);
  if (cropH > height) {
    cropH = height;
    cropW = Math.floor((cropH * rw) / rh);
  }
  return {
    left: Math.floor((width - cropW) / 2),
    top: Math.floor((height - cropH) / 2),
    width: cropW,
    height: cropH,
  };
}

/** Never upscale: a crop smaller than the target keeps its own size (same ratio). */
export function derivativeSize(
  crop: { width: number; height: number },
  spec: DerivativeSpec,
): { width: number; height: number } {
  return crop.width >= spec.width ? { width: spec.width, height: spec.height } : crop;
}

/** Header checks only (no decoding): type, dimensions, pixel and side limits, animation. */
export function precheck(
  bytes: Buffer,
  declaredType: MediaContentType,
): { ok: true; detectedType: MediaContentType } | { ok: false; issue: MediaFailureIssue; reason: string } {
  const detectedType = detectContentType(bytes);
  if (detectedType === null) return { ok: false, issue: 'invalid_format', reason: 'unsupported_type' };
  if (detectedType !== declaredType) return { ok: false, issue: 'invalid_format', reason: 'type_mismatch' };
  const header = readImageHeader(bytes, detectedType);
  if (!header) return { ok: false, issue: 'invalid_format', reason: 'bad_header' };
  if (header.width > MEDIA_MAX_SIDE || header.height > MEDIA_MAX_SIDE) {
    return { ok: false, issue: 'too_big', reason: 'side_limit' };
  }
  if (header.width * header.height > MEDIA_MAX_PIXELS)
    return { ok: false, issue: 'too_big', reason: 'pixel_limit' };
  if (header.animated) return { ok: false, issue: 'invalid_format', reason: 'animated' };
  return { ok: true, detectedType };
}

async function encode(
  image: Sharp,
  crop: { width: number; height: number },
  spec: DerivativeSpec,
): Promise<Derivative> {
  const size = derivativeSize(crop, spec);
  const pipeline =
    size.width === crop.width && size.height === crop.height
      ? image.clone()
      : image.clone().resize(size.width, size.height, { fit: 'fill', kernel: 'lanczos3' });
  const { data, info } = await pipeline
    .webp({ quality: 82, effort: 4 })
    .toBuffer({ resolveWithObject: true });
  return {
    data: new Uint8Array(data.buffer, data.byteOffset, data.byteLength),
    width: info.width,
    height: info.height,
  };
}

/** Verifies and processes one upload. Never throws for bad input: returns `ok: false`. */
export async function processImage(job: ProcessJob): Promise<ProcessOutcome> {
  configureSharp();
  const bytes = Buffer.from(job.bytes.buffer, job.bytes.byteOffset, job.bytes.byteLength);
  const pre = precheck(bytes, job.declaredType);
  if (!pre.ok) return fail(pre.issue, pre.reason);

  const options: SharpOptions = {
    failOn: 'truncated',
    limitInputPixels: MEDIA_MAX_PIXELS,
    animated: false,
    pages: 1,
    autoOrient: true,
  };
  try {
    const meta = await sharp(bytes, options).metadata();
    if (meta.format !== SHARP_FORMAT[pre.detectedType]) return fail('invalid_format', 'decoder_type');
    if ((meta.pages ?? 1) > 1) return fail('invalid_format', 'animated');
    // The displayed (EXIF-oriented) size: `autoOrient` in the metadata, else the stored size.
    const width = meta.autoOrient?.width ?? meta.width;
    const height = meta.autoOrient?.height ?? meta.height;
    if (width === undefined || height === undefined) return fail('invalid_format', 'no_size');
    const crop = centredCrop(width, height, job.rules.ratio);
    if (crop.width < job.rules.minWidth || crop.height < job.rules.minHeight) {
      return fail('too_small', 'below_minimum');
    }
    const base = sharp(bytes, options)
      .timeout({ seconds: job.timeoutSeconds })
      .extract(crop)
      .toColourspace('srgb');
    const main = await encode(base, crop, job.rules.main);
    const thumb = await encode(base, crop, job.rules.thumb);
    return { ok: true, detectedType: pre.detectedType, main, thumb };
  } catch {
    // Undecodable, truncated, blocked loader, pixel limit or inner timeout: never surface details.
    return fail('invalid_format', 'decode_failed');
  }
}
