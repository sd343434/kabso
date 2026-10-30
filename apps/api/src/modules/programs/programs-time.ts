import type { Prisma } from '../../generated/prisma/client.js';

type Db = Pick<Prisma.TransactionClient, '$queryRaw'>;

/** A day or a week of the programs' clock (UTC instants; `date` is its first day, `YYYY-MM-DD`). */
export interface ProgramWindow {
  readonly date: string;
  readonly start: Date;
  readonly end: Date;
}

/**
 * The day, the ISO week (Monday 00:00) and (v1.57-social, D188) the calendar month of `now` in `tz`
 * (`LIVE_RANKINGS_TIME_ZONE`, the boards' and the CP space's clock, CONVENTIONS §10.15, §10.24).
 */
export async function programWindowsIn(
  db: Db,
  now: Date,
  tz: string,
): Promise<{ day: ProgramWindow; week: ProgramWindow; month: ProgramWindow }> {
  const [w] = await db.$queryRaw<
    {
      day: string;
      day_start: Date;
      day_end: Date;
      week: string;
      week_start: Date;
      week_end: Date;
      month: string;
      month_start: Date;
      month_end: Date;
    }[]
  >`
    SELECT to_char((${now}::timestamptz AT TIME ZONE ${tz}::text)::date, 'YYYY-MM-DD') AS day,
           (((${now}::timestamptz AT TIME ZONE ${tz}::text)::date)::timestamp AT TIME ZONE ${tz}::text) AS day_start,
           ((((${now}::timestamptz AT TIME ZONE ${tz}::text)::date) + 1)::timestamp
              AT TIME ZONE ${tz}::text) AS day_end,
           to_char(date_trunc('week', ${now}::timestamptz AT TIME ZONE ${tz}::text), 'YYYY-MM-DD') AS week,
           (date_trunc('week', ${now}::timestamptz AT TIME ZONE ${tz}::text) AT TIME ZONE ${tz}::text) AS week_start,
           ((date_trunc('week', ${now}::timestamptz AT TIME ZONE ${tz}::text) + interval '7 days')
              AT TIME ZONE ${tz}::text) AS week_end,
           to_char(date_trunc('month', ${now}::timestamptz AT TIME ZONE ${tz}::text), 'YYYY-MM-DD') AS month,
           (date_trunc('month', ${now}::timestamptz AT TIME ZONE ${tz}::text) AT TIME ZONE ${tz}::text) AS month_start,
           ((date_trunc('month', ${now}::timestamptz AT TIME ZONE ${tz}::text) + interval '1 month')
              AT TIME ZONE ${tz}::text) AS month_end`;
  return {
    day: { date: w!.day, start: w!.day_start, end: w!.day_end },
    week: { date: w!.week, start: w!.week_start, end: w!.week_end },
    month: { date: w!.month, start: w!.month_start, end: w!.month_end },
  };
}

/** A `DATE` column value for `YYYY-MM-DD`. */
export function dateValue(date: string): Date {
  return new Date(`${date}T00:00:00.000Z`);
}

/** `YYYY-MM-DD` moved by `days` (calendar arithmetic, no time zone). */
export function addDays(date: string, days: number): string {
  const d = dateValue(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
