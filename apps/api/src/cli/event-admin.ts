/**
 * Event Center «مركز الفعاليات» administration from the command line (v1.44-social, D166, CONVENTIONS
 * §10.41). There is no admin UI: the team creates, lists and ends events here. Runs as the MIGRATION
 * role (MIGRATION_DATABASE_URL), like `banner-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/event-admin.js …` (docs/DEPLOYMENT.md),
 * locally `pnpm event:admin …`.
 *
 *   pnpm event:admin create --title-ar <text> --title-en <text> --starts <ISO time>
 *                   (--ends <ISO time> | --permanent) --metric <metric>
 *                   [--rules-ar <text>] [--rules-en <text>] [--audience everyone|hosts]
 *                   [--regions SA,EG] [--featured] [--banner <https URL>] [--prizes 1:5000,2:3000,3-10:500]
 *                   [--summary-ar <text>] [--summary-en <text>] [--tone red|gold|teal|blue|pink|amber]
 *   pnpm event:admin style <eventId> [--summary-ar <text>] [--summary-en <text>] [--tone <tone>|none]
 *                   [--featured true|false]
 *   pnpm event:admin list             # every event with its state
 *   pnpm event:admin end <eventId>    # ends a running event now (the sweeper then freezes it)
 *   pnpm event:admin hold <eventId>   # stops the automatic prize payout (during the review)
 *   pnpm event:admin release <eventId>
 *
 * v1.50-social (D176): `--summary-ar` / `--summary-en` are the calendar bar's second line (a short prize
 * line, ≤ 80 characters; empty clears it) and `--tone` its colour among Kabso's hues (none = a hue
 * from the event's id). `style` changes them, and «رائج» (`--featured`), on an existing event.
 *
 * `<metric>` is gift_coins_received, gift_coins_sent, live_minutes, taps_received or new_followers.
 * Prizes are coins per rank (1–100); they are paid once, `EVENT_PRIZE_REVIEW_HOURS` (24) after the end,
 * to ACTIVE winners. Every change writes an audit_logs row in the same transaction (`event.create`,
 * `event.end`, `event.hold`, `event.release`). A bad argument or an unknown event exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type EventMetric } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { parsePrizeText } from '../modules/programs/programs-rules.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm event:admin create --title-ar <text> --title-en <text> --starts <ISO time>',
  '         (--ends <ISO time> | --permanent) --metric <metric> [--rules-ar <text>] [--rules-en <text>]',
  '         [--audience everyone|hosts] [--regions SA,EG] [--featured] [--banner <https URL>]',
  '         [--prizes 1:5000,2:3000,3-10:500] [--summary-ar <text>] [--summary-en <text>] [--tone <tone>]',
  '       pnpm event:admin style <eventId> [--summary-ar <text>] [--summary-en <text>] [--tone <tone>|none]',
  '         [--featured true|false]',
  '       pnpm event:admin list',
  '       pnpm event:admin end|hold|release <eventId>',
].join('\n');

const METRICS: readonly EventMetric[] = [
  'GIFT_COINS_RECEIVED',
  'GIFT_COINS_SENT',
  'LIVE_MINUTES',
  'TAPS_RECEIVED',
  'NEW_FOLLOWERS',
];

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes the events).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const OPTIONS = {
  'title-ar': { type: 'string' },
  'title-en': { type: 'string' },
  'rules-ar': { type: 'string' },
  'rules-en': { type: 'string' },
  starts: { type: 'string' },
  ends: { type: 'string' },
  permanent: { type: 'boolean' },
  metric: { type: 'string' },
  audience: { type: 'string' },
  regions: { type: 'string' },
  featured: { type: 'boolean' },
  banner: { type: 'string' },
  prizes: { type: 'string' },
  'summary-ar': { type: 'string' },
  'summary-en': { type: 'string' },
  tone: { type: 'string' },
} as const;

const STYLE_OPTIONS = {
  'summary-ar': { type: 'string' },
  'summary-en': { type: 'string' },
  tone: { type: 'string' },
  featured: { type: 'string' },
} as const;

/** The calendar tones (CHECK `events_style`). */
const TONES = ['RED', 'GOLD', 'TEAL', 'BLUE', 'PINK', 'AMBER'] as const;

/** `--tone`: one of TONES, or null for `none` (when allowed). */
function tone(raw: string, allowNone: boolean): string | null {
  const value = raw.trim().toUpperCase();
  if (allowNone && value === 'NONE') return null;
  if (!(TONES as readonly string[]).includes(value)) {
    fail(`--tone is ${TONES.join(', ').toLowerCase()}${allowNone ? ' or none' : ''}.`);
  }
  return value;
}

/** A calendar summary line (≤ 80 characters); empty → null. */
function summaryLine(raw: string | undefined, option: string): string | null {
  const value = text(raw, option, 80, false);
  return value === '' ? null : value;
}

function date(raw: string, option: string): Date {
  const value = new Date(raw);
  if (!/^\d{4}-\d{2}-\d{2}/.test(raw) || Number.isNaN(value.getTime())) {
    fail(`${option} is an ISO time such as 2026-11-01T00:00:00+03:00.`);
  }
  return value;
}

function text(raw: string | undefined, option: string, max: number, required: boolean): string {
  const value = (raw ?? '').trim();
  if (required && value === '') fail(`Missing ${option}.\n${USAGE}`);
  if ([...value].length > max) fail(`${option} is at most ${String(max)} characters.`);
  return value;
}

async function create(args: readonly string[]): Promise<void> {
  let values: Partial<Record<keyof typeof OPTIONS, string | boolean>>;
  try {
    ({ values } = parseArgs({ args: [...args], options: OPTIONS, strict: true, allowPositionals: false }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const str = (k: keyof typeof OPTIONS): string | undefined => {
    const v = values[k];
    return typeof v === 'string' ? v : undefined;
  };
  const titleAr = text(str('title-ar'), '--title-ar', 120, true);
  const titleEn = text(str('title-en'), '--title-en', 120, true);
  const rulesAr = text(str('rules-ar'), '--rules-ar', 4000, false);
  const rulesEn = text(str('rules-en'), '--rules-en', 4000, false);
  const startsRaw = str('starts');
  if (startsRaw === undefined) fail(`Missing --starts.\n${USAGE}`);
  const startsAt = date(startsRaw, '--starts');
  const permanent = values.permanent === true;
  const endsRaw = str('ends');
  if (endsRaw === undefined && !permanent)
    fail('Give --ends <ISO time>, or --permanent for an event without an end.');
  const endsAt = endsRaw === undefined ? null : date(endsRaw, '--ends');
  if (endsAt !== null && endsAt <= startsAt) fail('--ends must be after --starts.');
  const metric = (str('metric') ?? '').toUpperCase() as EventMetric;
  if (!METRICS.includes(metric)) fail(`--metric is one of ${METRICS.join(', ').toLowerCase()}.`);
  const audience = (str('audience') ?? 'everyone').toUpperCase();
  if (audience !== 'EVERYONE' && audience !== 'HOSTS') fail('--audience is everyone or hosts.');
  const regionsRaw = (str('regions') ?? '').trim();
  const regions = regionsRaw === '' ? [] : regionsRaw.split(',').map((r) => r.trim().toUpperCase());
  if (regions.some((r) => !/^[A-Z]{2}$/.test(r)) || regions.length > 50) {
    fail('--regions is a comma-separated list of ISO country codes (SA,EG), at most 50.');
  }
  const banner = str('banner');
  if (banner !== undefined && (!/^https:\/\/\S{1,2000}$/.test(banner) || banner.length > 2048)) {
    fail('--banner is an https:// URL of the banner picture.');
  }
  const prizes = parsePrizeText(str('prizes') ?? '');
  if (prizes === null) fail('--prizes is like 1:5000,2:3000,3-10:500 (ranks 1–100 in order, coins each).');
  const summaryAr = summaryLine(str('summary-ar'), '--summary-ar');
  const summaryEn = summaryLine(str('summary-en'), '--summary-en');
  const toneValue = str('tone') === undefined ? null : tone(str('tone')!, false);
  const event = await prisma.$transaction(async (tx) => {
    const row = await tx.event.create({
      data: {
        titleAr,
        titleEn,
        rulesAr,
        rulesEn,
        startsAt,
        endsAt,
        permanent,
        metric,
        audience,
        regions: [...new Set(regions)],
        featured: values.featured === true,
        bannerUrl: banner ?? null,
        prizes: prizes.map((p) => ({ ...p })),
        summaryAr,
        summaryEn,
        tone: toneValue,
      },
      select: { id: true },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.EVENT_CREATE,
        targetType: 'event',
        targetId: row.id,
        metadata: { metric, audience, permanent, regions, prizes: prizes.length, via: 'cli' },
      },
    });
    return row;
  });
  process.stdout.write(`Created event ${event.id}.\n`);
}

async function list(): Promise<void> {
  const now = new Date();
  const rows = await prisma.event.findMany({ orderBy: [{ startsAt: 'desc' }, { id: 'asc' }] });
  if (rows.length === 0) {
    process.stdout.write('No events.\n');
    return;
  }
  for (const e of rows) {
    const state =
      now < e.startsAt
        ? 'UPCOMING'
        : e.endsAt === null || now < e.endsAt
          ? 'RUNNING'
          : e.paidAt
            ? 'PAID'
            : e.frozenAt
              ? e.payoutHold
                ? 'HELD'
                : 'IN REVIEW'
              : 'ENDED';
    process.stdout.write(
      `${e.id} ${state} ${e.metric} ${e.audience}${e.permanent ? ' permanent' : ''}${e.featured ? ' featured' : ''}` +
        `${e.regions.length > 0 ? ` [${e.regions.join(',')}]` : ''} ${e.startsAt.toISOString()} → ` +
        `${e.endsAt?.toISOString() ?? '…'} «${e.titleAr}» / ${e.titleEn}\n`,
    );
  }
}

async function change(command: 'end' | 'hold' | 'release', id: string): Promise<void> {
  if (!/^[0-9a-f-]{36}$/i.test(id)) fail(`No event ${id}.`);
  const now = new Date();
  const event = await prisma.event.findUnique({ where: { id: id.toLowerCase() } });
  if (!event) fail(`No event ${id}.`);
  if (command === 'end') {
    if (now < event.startsAt) fail('This event has not started; nothing to end.');
    if (event.endsAt !== null && event.endsAt <= now) {
      process.stdout.write('Already ended; nothing changed.\n');
      return;
    }
  } else if (event.paidAt !== null) {
    fail('The prizes of this event are already settled.');
  }
  await prisma.$transaction(async (tx) => {
    await tx.event.update({
      where: { id: event.id },
      data: command === 'end' ? { endsAt: now } : { payoutHold: command === 'hold' },
    });
    await tx.auditLog.create({
      data: {
        action:
          command === 'end'
            ? AuditAction.EVENT_END
            : command === 'hold'
              ? AuditAction.EVENT_HOLD
              : AuditAction.EVENT_RELEASE,
        targetType: 'event',
        targetId: event.id,
        metadata: { via: 'cli' },
      },
    });
  });
  process.stdout.write(`Event ${event.id}: ${command} done.\n`);
}

async function style(id: string, args: readonly string[]): Promise<void> {
  let values: Partial<Record<keyof typeof STYLE_OPTIONS, string>>;
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: STYLE_OPTIONS,
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  if (!/^[0-9a-f-]{36}$/i.test(id)) fail(`No event ${id}.`);
  const event = await prisma.event.findUnique({ where: { id: id.toLowerCase() }, select: { id: true } });
  if (!event) fail(`No event ${id}.`);
  const data: {
    summaryAr?: string | null;
    summaryEn?: string | null;
    tone?: string | null;
    featured?: boolean;
  } = {};
  if (values['summary-ar'] !== undefined) data.summaryAr = summaryLine(values['summary-ar'], '--summary-ar');
  if (values['summary-en'] !== undefined) data.summaryEn = summaryLine(values['summary-en'], '--summary-en');
  if (values.tone !== undefined) data.tone = tone(values.tone, true);
  if (values.featured !== undefined) {
    if (values.featured !== 'true' && values.featured !== 'false') fail('--featured is true or false.');
    data.featured = values.featured === 'true';
  }
  if (Object.keys(data).length === 0) fail(`Nothing to change.\n${USAGE}`);
  await prisma.$transaction(async (tx) => {
    await tx.event.update({ where: { id: event.id }, data });
    await tx.auditLog.create({
      data: {
        action: AuditAction.EVENT_STYLE,
        targetType: 'event',
        targetId: event.id,
        metadata: { ...data, via: 'cli' },
      },
    });
  });
  process.stdout.write(`Event ${event.id}: style updated.\n`);
}

const [command, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'create':
      await create(rest);
      break;
    case 'list':
      if (rest.length > 0) fail(USAGE);
      await list();
      break;
    case 'style': {
      const [id, ...options] = rest;
      if (!id) fail(USAGE);
      await style(id, options);
      break;
    }
    case 'end':
    case 'hold':
    case 'release':
      if (rest.length !== 1 || !rest[0]) fail(USAGE);
      await change(command, rest[0]);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
