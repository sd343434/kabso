import { useCallback, useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { useT } from './context';
import { bubbleOffset, nearestCorner, type LayoutMode } from './layout';
import type { StreamerCorner, StreamerOrientation } from './types';
import { Video } from './Video';

/**
 * The composited look viewers get (D213 viewer stage, §10.86 / §10.88): the main picture fitted inside a box of the
 * live's orientation, and — with the screen as the picture — the round camera bubble at the host's corner (physical:
 * the stage never mirrors for Arabic). The host drags the bubble to another corner.
 */
export function Stage({
  mode,
  orientation,
  screen,
  camera,
  bubbleVisible,
  corner,
  onCorner,
  onMainSize,
  paused,
  overlay,
  testId = 'stage',
}: {
  mode: LayoutMode;
  orientation: StreamerOrientation;
  screen: MediaStreamTrack | null;
  camera: MediaStreamTrack | null;
  bubbleVisible: boolean;
  corner: StreamerCorner;
  onCorner?: (c: StreamerCorner) => void;
  onMainSize?: (w: number, h: number) => void;
  /** A note over the picture (the screen paused / stopped). */
  paused?: string | null;
  overlay?: React.ReactNode;
  testId?: string;
}) {
  const { t } = useT();
  const box = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null);
  const main = mode === 'camera' ? camera : screen;
  const showBubble = mode === 'screen' && bubbleVisible && camera !== null;

  const [{ w, h }, setBoxSize] = useState({ w: 0, h: 0 });
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const measure = () => setBoxSize({ w: el.clientWidth, h: el.clientHeight });
    measure();
    if (typeof ResizeObserver === 'undefined') return;
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const size = Math.round(Math.max(56, Math.min(w, h) * (orientation === 'LANDSCAPE' ? 0.26 : 0.2)));
  const inset = Math.round(Math.max(8, Math.min(w, h) * 0.035));
  const at = bubbleOffset(corner, w, h, size, inset);

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      if (!onCorner) return;
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
      const r = box.current?.getBoundingClientRect();
      if (r) setDrag({ x: e.clientX - r.left - size / 2, y: e.clientY - r.top - size / 2 });
    },
    [onCorner, size],
  );
  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!drag) return;
    const r = box.current?.getBoundingClientRect();
    if (r) setDrag({ x: e.clientX - r.left - size / 2, y: e.clientY - r.top - size / 2 });
  };
  const onPointerUp = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!drag) return;
    const r = box.current?.getBoundingClientRect();
    setDrag(null);
    if (r && onCorner) onCorner(nearestCorner(e.clientX - r.left, e.clientY - r.top, r.width, r.height));
  };

  return (
    <div className={`stage-frame ${orientation === 'LANDSCAPE' ? 'landscape' : 'portrait'}`} dir="ltr">
      <div className="stage" ref={box} data-testid={testId} data-orientation={orientation} data-main={mode === 'camera' ? 'CAMERA' : 'SCREEN'}>
        {main ? (
          <Video track={main} className="stage-main" fit="contain" label={t('previewTitle')} onSize={onMainSize} />
        ) : (
          <div className="stage-empty">{t('previewEmpty')}</div>
        )}
        {paused && (
          <div className="stage-paused" role="status">
            {paused}
          </div>
        )}
        {showBubble && (
          <div
            className={`bubble ${onCorner ? 'draggable' : ''} ${drag ? 'dragging' : ''}`}
            data-testid="bubble"
            data-corner={corner}
            style={{
              width: size,
              height: size,
              left: drag ? drag.x : at.left,
              top: drag ? drag.y : at.top,
            }}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            title={onCorner ? t('bubbleDragHint') : undefined}
          >
            <Video track={camera} fit="cover" mirror={false} />
          </div>
        )}
        {overlay}
      </div>
    </div>
  );
}
