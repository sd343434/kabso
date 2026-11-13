import { useEffect, useRef } from 'react';

/** A local track's picture (muted: the host never hears themself). */
export function Video({
  track,
  className,
  fit = 'contain',
  mirror = false,
  label,
  onSize,
}: {
  track: MediaStreamTrack | null;
  className?: string;
  fit?: 'contain' | 'cover';
  mirror?: boolean;
  label?: string;
  onSize?: (w: number, h: number) => void;
}) {
  const ref = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.srcObject = track ? new MediaStream([track]) : null;
    if (track) void el.play().catch(() => undefined);
  }, [track]);
  useEffect(() => {
    const el = ref.current;
    if (!el || !onSize) return;
    const report = () => {
      if (el.videoWidth > 0 && el.videoHeight > 0) onSize(el.videoWidth, el.videoHeight);
    };
    el.addEventListener('resize', report);
    el.addEventListener('loadedmetadata', report);
    return () => {
      el.removeEventListener('resize', report);
      el.removeEventListener('loadedmetadata', report);
    };
  }, [onSize]);
  return (
    <video
      ref={ref}
      className={className}
      autoPlay
      playsInline
      muted
      aria-label={label}
      style={{ objectFit: fit, transform: mirror ? 'scaleX(-1)' : undefined }}
    />
  );
}
