/**
 * The studio's layout and how it maps onto the D213 contract (CONVENTIONS §10.86, §10.88):
 *
 * - «الشاشة + فقاعة الكاميرا» → `main: SCREEN`; the screen is the `screen_share` track, the camera the `camera`
 *   track that viewers draw as the round bubble at `cameraOverlay.corner` (physical corners, never mirrored). No
 *   camera, or the bubble hidden → `cameraOverlay.visible: false`.
 * - «الكاميرا فقط» (OBS) → `main: CAMERA`; the camera track alone is the picture, laid out by `orientation`; no
 *   screen track, the bubble keys unused (kept as they were).
 *
 * The orientation follows the main source's shape unless the host fixed it.
 */
import type { LiveStreamer, StreamerCorner, StreamerMain, StreamerOrientation } from './types';

export type LayoutMode = 'screen' | 'camera';
export type OrientationChoice = 'auto' | StreamerOrientation;

export interface StudioLayout {
  mode: LayoutMode;
  orientation: OrientationChoice;
  bubbleVisible: boolean;
  corner: StreamerCorner;
}

export const DEFAULT_LAYOUT: StudioLayout = {
  mode: 'screen',
  orientation: 'auto',
  bubbleVisible: true,
  // D213's default corner (the owner's choice for the app).
  corner: 'TOP_LEFT',
};

export const CORNERS: readonly StreamerCorner[] = ['TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'];

/** Landscape when the picture is wider than tall (a square counts as landscape: a desktop's habit). */
export function orientationOf(width: number | undefined, height: number | undefined): StreamerOrientation | null {
  if (!width || !height || width <= 0 || height <= 0) return null;
  return width >= height ? 'LANDSCAPE' : 'PORTRAIT';
}

/** The orientation sent: the host's choice, else the main source's shape, else landscape (a computer screen). */
export function effectiveOrientation(choice: OrientationChoice, detected: StreamerOrientation | null): StreamerOrientation {
  if (choice !== 'auto') return choice;
  return detected ?? 'LANDSCAPE';
}

export function mainOf(mode: LayoutMode): StreamerMain {
  return mode === 'camera' ? 'CAMERA' : 'SCREEN';
}

/** What the viewers' layout is, from the host's choices and what is actually being sent. */
export function wireLayout(
  layout: StudioLayout,
  detected: StreamerOrientation | null,
  hasCamera: boolean,
): Omit<LiveStreamer, 'version'> {
  return {
    orientation: effectiveOrientation(layout.orientation, detected),
    main: mainOf(layout.mode),
    cameraOverlay: {
      visible: layout.mode === 'screen' && layout.bubbleVisible && hasCamera,
      corner: layout.corner,
    },
  };
}

/** `StartLiveRoomRequest.streamer` (`StreamerSetup`). */
export function startSetup(wire: Omit<LiveStreamer, 'version'>): {
  orientation: StreamerOrientation;
  main: StreamerMain;
  cameraOverlay: { visible: boolean; corner: StreamerCorner };
} {
  return { orientation: wire.orientation, main: wire.main, cameraOverlay: { ...wire.cameraOverlay } };
}

/**
 * The `PUT …/streamer` body that turns `current` (the server's) into `next`: only the keys that differ; null when
 * nothing differs (no call — the server would answer the same layout anyway).
 */
export function layoutUpdate(
  current: Omit<LiveStreamer, 'version'> | null,
  next: Omit<LiveStreamer, 'version'>,
): Partial<{
  orientation: StreamerOrientation;
  main: StreamerMain;
  cameraOverlay: Partial<{ visible: boolean; corner: StreamerCorner }>;
}> | null {
  if (!current) return startSetup(next);
  const body: ReturnType<typeof layoutUpdate> & object = {};
  if (current.orientation !== next.orientation) body.orientation = next.orientation;
  if (current.main !== next.main) body.main = next.main;
  const overlay: Partial<{ visible: boolean; corner: StreamerCorner }> = {};
  if (current.cameraOverlay.visible !== next.cameraOverlay.visible) overlay.visible = next.cameraOverlay.visible;
  if (current.cameraOverlay.corner !== next.cameraOverlay.corner) overlay.corner = next.cameraOverlay.corner;
  if (Object.keys(overlay).length > 0) body.cameraOverlay = overlay;
  return Object.keys(body).length > 0 ? body : null;
}

/** Where the bubble sits in a preview box of `w`×`h` (top-left offset of a `size` circle with `inset` margin). */
export function bubbleOffset(
  corner: StreamerCorner,
  w: number,
  h: number,
  size: number,
  inset: number,
): { left: number; top: number } {
  const left = corner === 'TOP_LEFT' || corner === 'BOTTOM_LEFT' ? inset : Math.max(inset, w - size - inset);
  const top = corner === 'TOP_LEFT' || corner === 'TOP_RIGHT' ? inset : Math.max(inset, h - size - inset);
  return { left, top };
}

/** The corner nearest to a point dropped in a `w`×`h` box. */
export function nearestCorner(x: number, y: number, w: number, h: number): StreamerCorner {
  const left = x < w / 2;
  const top = y < h / 2;
  return top ? (left ? 'TOP_LEFT' : 'TOP_RIGHT') : left ? 'BOTTOM_LEFT' : 'BOTTOM_RIGHT';
}

/** What the host must still choose before going live (i18n keys); empty = ready. */
export function missingForLive(
  layout: StudioLayout,
  sources: { screen: boolean; camera: boolean; microphone: boolean },
  title: string,
): ('needTitle' | 'needScreen' | 'needCamera')[] {
  const missing: ('needTitle' | 'needScreen' | 'needCamera')[] = [];
  if (title.trim().length === 0) missing.push('needTitle');
  if (layout.mode === 'screen' && !sources.screen) missing.push('needScreen');
  if (layout.mode === 'camera' && !sources.camera) missing.push('needCamera');
  return missing;
}
