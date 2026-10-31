import { useEffect, useId, useLayoutEffect, useRef, useState } from 'react';

/**
 * Hand-rolled SVG charts (D197): a sparkline and a two-axis line chart with a legend, a tooltip and keyboard
 * stepping. No chart library: the panel draws three small charts, and ~200 lines of SVG keep the bundle and the
 * CSP (`default-src 'self'`, no inline styles from a library) as they were. The geometry is pure and unit-tested.
 */

/** A "nice" axis top ≥ `value` (1, 2, 2.5 or 5 × 10ⁿ), at least 1. */
export function niceMax(value: number): number {
  if (!(value > 0)) return 1;
  const exp = Math.floor(Math.log10(value));
  const base = 10 ** exp;
  for (const m of [1, 2, 2.5, 5, 10]) if (m * base >= value) return m * base;
  return 10 * base;
}

/** The y of `v` on an axis [0, max] drawn over `height` (0 at the bottom). */
export function yOf(v: number, max: number, height: number): number {
  return height - (Math.max(0, v) / (max || 1)) * height;
}

/** The x of point `i` of `n` across `width` (a single point sits in the middle). */
export function xOf(i: number, n: number, width: number): number {
  return n <= 1 ? width / 2 : (i / (n - 1)) * width;
}

/** An SVG path through the values (straight segments). */
export function linePath(values: readonly number[], width: number, height: number, max: number): string {
  return values
    .map((v, i) => `${i === 0 ? 'M' : 'L'}${xOf(i, values.length, width).toFixed(1)} ${yOf(v, max, height).toFixed(1)}`)
    .join(' ');
}

/** The same path closed down to the baseline (for a soft area fill). */
export function areaPath(values: readonly number[], width: number, height: number, max: number): string {
  if (values.length === 0) return '';
  return `${linePath(values, width, height, max)} L${xOf(values.length - 1, values.length, width).toFixed(1)} ${height} L${xOf(0, values.length, width).toFixed(1)} ${height} Z`;
}

/** The index nearest to `x` over `width`. */
export function nearestIndex(x: number, n: number, width: number): number {
  if (n <= 1 || width <= 0) return 0;
  return Math.min(n - 1, Math.max(0, Math.round((x / width) * (n - 1))));
}

/** Compact numbers for axes: 1.2K, 3.4M (Latin digits). */
export function compact(v: number): string {
  const abs = Math.abs(v);
  if (abs >= 1e9) return `${+(v / 1e9).toFixed(1)}B`;
  if (abs >= 1e6) return `${+(v / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `${+(v / 1e3).toFixed(1)}K`;
  return String(+v.toFixed(abs < 10 ? 1 : 0));
}

export function Sparkline({ values, label }: { values: readonly number[]; label: string }) {
  const id = useId();
  const w = 120;
  const h = 36;
  const max = Math.max(1, ...values);
  return (
    <svg className="spark" viewBox={`0 0 ${w} ${h + 2}`} preserveAspectRatio="none" role="img" aria-label={label}>
      <defs>
        <linearGradient id={`sg${id}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="currentColor" stopOpacity="0.35" />
          <stop offset="1" stopColor="currentColor" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaPath(values, w, h, max)} fill={`url(#sg${id})`} transform="translate(0 1)" />
      <path d={linePath(values, w, h, max)} fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" transform="translate(0 1)" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

export interface Series {
  key: string;
  label: string;
  /** A CSS colour (a token variable). */
  color: string;
  values: readonly number[];
  /** `end`: drawn against the second axis (another magnitude, e.g. people next to coins). */
  axis?: 'start' | 'end';
}

function useWidth<T extends HTMLElement>(): [React.RefObject<T | null>, number] {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(640);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    setWidth(el.clientWidth);
    if (typeof ResizeObserver === 'undefined') return;
    const ro = new ResizeObserver((entries) => setWidth(entries[0]?.contentRect.width ?? el.clientWidth));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width];
}

/**
 * A line chart over shared x labels: a start axis and an optional end axis (its own magnitude), a legend that
 * shows / hides each series, a tooltip with every visible value at the hovered (or arrow-key selected) point.
 */
export function LineChart({
  labels,
  series,
  format,
  label,
  rtl,
}: {
  labels: readonly string[];
  series: readonly Series[];
  format: (v: number) => string;
  label: string;
  rtl: boolean;
}) {
  const [box, width] = useWidth<HTMLDivElement>();
  const [hidden, setHidden] = useState<Set<string>>(new Set());
  const [hover, setHover] = useState<number | null>(null);
  useEffect(() => setHover(null), [labels.length]);
  const height = 260;
  const pad = { top: 16, bottom: 28, side: 48 };
  const shown = series.filter((s) => !hidden.has(s.key));
  const hasEnd = shown.some((s) => s.axis === 'end');
  const plotW = Math.max(40, width - pad.side * (hasEnd ? 2 : 1) - 8);
  const plotH = height - pad.top - pad.bottom;
  const maxOf = (axis: 'start' | 'end') =>
    niceMax(Math.max(0, ...shown.filter((s) => (s.axis ?? 'start') === axis).flatMap((s) => [...s.values])));
  const maxStart = maxOf('start');
  const maxEnd = maxOf('end');
  const n = labels.length;
  // In RTL the time axis runs right to left: the oldest day at the right edge, where an Arabic reader starts.
  const xAt = (i: number) => (rtl ? plotW - xOf(i, n, plotW) : xOf(i, n, plotW));
  const startX = rtl ? (hasEnd ? pad.side : 8) : pad.side;
  const ticks = [0, 0.25, 0.5, 0.75, 1];
  const every = Math.max(1, Math.ceil(n / Math.max(2, Math.floor(plotW / 70))));
  const pointFor = (clientX: number, rect: DOMRect) => {
    const x = clientX - rect.left - startX;
    const raw = nearestIndex(x, n, plotW);
    return rtl ? n - 1 - raw : raw;
  };
  const tipIndex = hover;
  return (
    <div className="chart" ref={box}>
      <div className="legend" role="group" aria-label={label}>
        {series.map((s) => (
          <button
            key={s.key}
            type="button"
            className="legend-item"
            aria-pressed={!hidden.has(s.key)}
            onClick={() =>
              setHidden((h) => {
                const next = new Set(h);
                if (next.has(s.key)) next.delete(s.key);
                else if (series.length - next.size > 1) next.add(s.key);
                return next;
              })
            }
          >
            <span className="dot" style={{ background: s.color }} />
            {s.label}
          </button>
        ))}
      </div>
      <svg
        className="chart-svg"
        width={width}
        height={height}
        role="img"
        aria-label={label}
        tabIndex={0}
        onMouseMove={(e) => setHover(pointFor(e.clientX, e.currentTarget.getBoundingClientRect()))}
        onMouseLeave={() => setHover(null)}
        onKeyDown={(e) => {
          if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
          e.preventDefault();
          const forward = (e.key === 'ArrowRight') !== rtl;
          setHover((h) => Math.min(n - 1, Math.max(0, (h ?? n - 1) + (forward ? 1 : -1))));
        }}
        onBlur={() => setHover(null)}
      >
        <g transform={`translate(${startX} ${pad.top})`}>
          {ticks.map((t) => (
            <g key={t}>
              <line className="grid-line" x1={0} x2={plotW} y1={plotH - t * plotH} y2={plotH - t * plotH} />
              <text className="axis-text" x={rtl ? plotW + 6 : -6} y={plotH - t * plotH} dy="0.32em" textAnchor={rtl ? 'start' : 'end'}>
                {compact(t * maxStart)}
              </text>
              {hasEnd && (
                <text className="axis-text" x={rtl ? -6 : plotW + 6} y={plotH - t * plotH} dy="0.32em" textAnchor={rtl ? 'end' : 'start'}>
                  {compact(t * maxEnd)}
                </text>
              )}
            </g>
          ))}
          {labels.map((l, i) =>
            (i % every === 0 && n - 1 - i >= every / 2) || i === n - 1 ? (
              <text key={l} className="axis-text" x={xAt(i)} y={plotH + 18} textAnchor="middle">
                {l.slice(5)}
              </text>
            ) : null,
          )}
          {shown.map((s) => {
            const max = s.axis === 'end' ? maxEnd : maxStart;
            const d = s.values.map((v, i) => `${i === 0 ? 'M' : 'L'}${xAt(i).toFixed(1)} ${yOf(v, max, plotH).toFixed(1)}`).join(' ');
            return <path key={s.key} d={d} fill="none" stroke={s.color} strokeWidth={2.4} strokeLinejoin="round" strokeLinecap="round" />;
          })}
          {tipIndex !== null && (
            <g>
              <line className="guide" x1={xAt(tipIndex)} x2={xAt(tipIndex)} y1={0} y2={plotH} />
              {shown.map((s) => (
                <circle
                  key={s.key}
                  cx={xAt(tipIndex)}
                  cy={yOf(s.values[tipIndex] ?? 0, s.axis === 'end' ? maxEnd : maxStart, plotH)}
                  r={4.5}
                  fill="var(--raised)"
                  stroke={s.color}
                  strokeWidth={2.4}
                />
              ))}
            </g>
          )}
        </g>
      </svg>
      {tipIndex !== null && labels[tipIndex] !== undefined && (
        <div
          className="tooltip"
          role="status"
          style={{
            insetInlineStart: Math.min(
              Math.max(8, (rtl ? width - (startX + xAt(tipIndex)) : startX + xAt(tipIndex)) + 14),
              Math.max(8, width - 190),
            ),
          }}
        >
          <div className="tip-title">{labels[tipIndex]}</div>
          {shown.map((s) => (
            <div className="tip-row" key={s.key}>
              <span className="dot" style={{ background: s.color }} />
              <span>{s.label}</span>
              <strong className="num">{format(s.values[tipIndex] ?? 0)}</strong>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
