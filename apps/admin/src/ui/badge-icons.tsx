/**
 * v1.79-live (D289, CONVENTIONS §10.102): the nine badge icons — the same SVG paths as the app's
 * `assets/icons/badges/*.svg` (drawn for Kabso on a 24-unit grid, 2.2 round strokes, `currentColor`; no third-party set).
 */
export type ItemBadgeCode =
  | 'LIMITED'
  | 'NEW'
  | 'SEASONAL'
  | 'EXCLUSIVE'
  | 'MOST_WANTED'
  | 'FEATURED'
  | 'FULLSCREEN'
  | 'SOUND'
  | 'NO_SOUND';

export const BADGE_ICON_PATHS: Record<ItemBadgeCode, readonly string[]> = {
  SOUND: ['M4 9.5h3l4.5-3.7a.6.6 0 0 1 1 .5v11.4a.6.6 0 0 1-1 .5L7 14.5H4a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1z', 'M16 9a4 4 0 0 1 0 6', 'M18.5 6.5a7.5 7.5 0 0 1 0 11'],
  NO_SOUND: ['M4 9.5h3l4.5-3.7a.6.6 0 0 1 1 .5v11.4a.6.6 0 0 1-1 .5L7 14.5H4a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1z', 'M16 9.5l5 5', 'M21 9.5l-5 5'],
  NEW: ['M11 3.5c.6 4.3 2.2 5.9 6.5 6.5-4.3.6-5.9 2.2-6.5 6.5-.6-4.3-2.2-5.9-6.5-6.5 4.3-.6 5.9-2.2 6.5-6.5z', 'M18.5 15.5v5', 'M16 18h5'],
  MOST_WANTED: ['M12 21c-4 0-7-2.8-7-6.6 0-3.4 2.3-5.6 4-7.5.3 1.7 1.2 3 2.4 3.6C11 7.3 12.2 4.6 14.5 3c-.1 3 1.4 4.6 2.8 6.3 1.2 1.4 1.7 2.9 1.7 4.6 0 4.1-3 7.1-7 7.1z'],
  FEATURED: ['M7 4h10l4 5-9 11L3 9z', 'M3 9h18', 'M9.6 4 8 9l4 11 4-11-1.6-5'],
  LIMITED: ['M6.5 3h11', 'M6.5 21h11', 'M7.5 3v2.5c0 2.2 2 3.9 4.5 6.5-2.5 2.6-4.5 4.3-4.5 6.5V21', 'M16.5 3v2.5c0 2.2-2 3.9-4.5 6.5 2.5 2.6 4.5 4.3 4.5 6.5V21'],
  FULLSCREEN: ['M4 9V4h5', 'M20 9V4h-5', 'M4 15v5h5', 'M20 15v5h-5'],
  EXCLUSIVE: ['M3.5 7.8 7.6 12 12 5.5l4.4 6.5 4.1-4.2-1.8 10.4H5.3z'],
  SEASONAL: ['M6 5.5h12a1.5 1.5 0 0 1 1.5 1.5v11.5A1.5 1.5 0 0 1 18 20H6a1.5 1.5 0 0 1-1.5-1.5V7A1.5 1.5 0 0 1 6 5.5z', 'M4.5 10h15', 'M8.5 3.5v4', 'M15.5 3.5v4'],
};

/** One badge icon at `size` px in `currentColor`. */
export function BadgeIcon({ code, size = 14 }: { code: ItemBadgeCode; size?: number }) {
  return (
    <svg
      className="badge-icon"
      data-badge-icon={code}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {BADGE_ICON_PATHS[code].map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}
