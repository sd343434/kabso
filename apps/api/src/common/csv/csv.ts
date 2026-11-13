/**
 * CSV for the admin exports (the `waitlist-admin export` CLI, D192; the admin panel's table exports, v1.65-social,
 * D197, CONVENTIONS §10.60.1): RFC 4180 fields, CRLF lines, and a leading `= + - @` (or tab / CR) neutralised with a
 * `'` so a spreadsheet never runs a cell as a formula.
 */
export function csvField(value: string): string {
  const safe = /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

export type CsvValue = string | number | boolean | null | undefined;

/** A whole document: a header line and one line per row (empty cells for null / undefined). */
export function csvDocument(header: readonly string[], rows: readonly (readonly CsvValue[])[]): string {
  const line = (cells: readonly CsvValue[]) =>
    cells.map((c) => (c === null || c === undefined ? '' : csvField(String(c)))).join(',');
  return [line(header), ...rows.map(line)].join('\r\n') + '\r\n';
}
