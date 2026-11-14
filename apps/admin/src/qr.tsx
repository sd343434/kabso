import qrcode from 'qrcode-generator';
import { useMemo } from 'react';

/** The modules (dark = true) of a QR code for `text` (error correction M). */
export function qrModules(text: string): boolean[][] {
  const qr = qrcode(0, 'M');
  qr.addData(text);
  qr.make();
  const n = qr.getModuleCount();
  return Array.from({ length: n }, (_, r) => Array.from({ length: n }, (_, c) => qr.isDark(r, c)));
}

/** The authenticator's QR code as an SVG drawn by React (no innerHTML, no image URL: CSP-safe). */
export function QrCode({ text, size = 208, label }: { text: string; size?: number; label: string }) {
  const modules = useMemo(() => qrModules(text), [text]);
  const n = modules.length;
  const quiet = 2;
  const total = n + quiet * 2;
  const path = modules
    .flatMap((row, r) => row.map((dark, c) => (dark ? `M${c + quiet} ${r + quiet}h1v1h-1z` : '')))
    .join('');
  return (
    <div className="qr">
      <svg width={size} height={size} viewBox={`0 0 ${total} ${total}`} role="img" aria-label={label} shapeRendering="crispEdges">
        <rect width={total} height={total} fill="#fff" />
        <path d={path} fill="#000" />
      </svg>
    </div>
  );
}
