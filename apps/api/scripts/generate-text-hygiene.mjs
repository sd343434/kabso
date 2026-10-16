#!/usr/bin/env node
// Generates src/modules/users/data/text-hygiene.generated.ts from the vendored Unicode 17.0.0
// data files in src/modules/users/data/unicode-17/ (CONVENTIONS §6 "Text hygiene", v1.3.1,
// SEC-036; v1.4, SEC-039). Run: node scripts/generate-text-hygiene.mjs
//
// The output is ASCII-only and compact:
//  - GC_DATA: "start:group" records (hex start; the range ends where the next record starts),
//    covering U+0000..U+10FFFF. Groups: L N M S P Z (= Zs) and X (Cc Cf Zl Zp Co Cs Cn).
//  - DI_DATA / VS_DATA: "start-end" ranges of Default_Ignorable_Code_Point / Variation_Selector.
//  - RGI_DATA: the RGI emoji set, one sequence per record ("1F468 200D 1F469"), and code point
//    ranges of single-code-point Basic_Emoji as "1F600..1F64F".
//  - VARIATION_DATA (SEC-039): every listed variation sequence of StandardizedVariants.txt and
//    emoji-variation-sequences.txt, as "BASE:SEL,SEL" records (hex code points).
//  - IVD_DATA (SEC-039): the registered ideographic variation sequences of the IVD file
//    ivd/IVD_Sequences.txt, as "BASE:n,n" records (n = selector - U+E0100, hex). The IVD file is
//    optional for the generator: when it is not vendored, IVD_RELEASE is null and IVD_DATA empty,
//    and the runtime applies the documented interim rule (see text-hygiene.ts).
//  - UI_DATA: Unified_Ideograph ranges (PropList.txt), used only by that interim rule.
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = join(root, 'src/modules/users/data');
const unicodeDir = join(dataDir, 'unicode-17');
const ivdDir = join(dataDir, 'ivd');

export const HYGIENE_SOURCE_FILES = [
  'DerivedCoreProperties.txt',
  'DerivedGeneralCategory.txt',
  'PropList.txt',
  'emoji-sequences.txt',
  'emoji-zwj-sequences.txt',
  // v1.4 (SEC-039)
  'StandardizedVariants.txt',
  'emoji-variation-sequences.txt',
];

/** Optional (SEC-039): the IVD release named by the contract (2022-09-13), in data/ivd/. */
export const IVD_FILE = 'IVD_Sequences.txt';

const REJECTED_GC = new Set(['Cc', 'Cf', 'Zl', 'Zp', 'Co', 'Cs', 'Cn']);

function records(text) {
  const out = [];
  for (const line of text.split('\n')) {
    const body = line.split('#')[0]?.trim();
    if (!body) continue;
    out.push(body.split(';').map((field) => field.trim()));
  }
  return out;
}

function parseRange(field) {
  const [a, b] = field.split('..').map((hex) => parseInt(hex, 16));
  return [a, b ?? a];
}

function hex(n) {
  return n.toString(16).toUpperCase();
}

function propertyRanges(text, property) {
  const ranges = [];
  for (const [range, prop] of records(text)) {
    if (prop === property) ranges.push(parseRange(range));
  }
  ranges.sort((x, y) => x[0] - y[0]);
  const merged = [];
  for (const [a, b] of ranges) {
    const last = merged.at(-1);
    if (last && a <= last[1] + 1) last[1] = Math.max(last[1], b);
    else merged.push([a, b]);
  }
  return merged;
}

function groupOf(gc) {
  if (REJECTED_GC.has(gc)) return 'X';
  if (gc === 'Zs') return 'Z';
  return gc[0];
}

function generalCategoryRecords(text) {
  // Every code point defaults to Cn (unassigned) unless listed.
  const groups = new Array(0x110000).fill('X');
  for (const [range, gc] of records(text)) {
    const [a, b] = parseRange(range);
    const group = groupOf(gc);
    for (let c = a; c <= b; c += 1) groups[c] = group;
  }
  const out = [];
  let previous = '';
  for (let c = 0; c < groups.length; c += 1) {
    if (groups[c] !== previous) {
      out.push(`${hex(c)}:${groups[c]}`);
      previous = groups[c];
    }
  }
  return out;
}

function rgiRecords(sequencesText, zwjText) {
  const out = [];
  for (const text of [sequencesText, zwjText]) {
    for (const [codePoints] of records(text)) {
      if (codePoints.includes('..')) {
        const [a, b] = parseRange(codePoints);
        out.push(`${hex(a)}..${hex(b)}`);
      } else {
        out.push(
          codePoints
            .split(/\s+/)
            .map((h) => hex(parseInt(h, 16)))
            .join(' '),
        );
      }
    }
  }
  return out;
}

/** Variation sequences "BASE SEL" of one or more files, grouped by base: Map<base, Set<sel>>. */
function variationPairs(texts) {
  const pairs = new Map();
  for (const text of texts) {
    for (const [sequence] of records(text)) {
      const points = sequence.split(/\s+/).map((h) => parseInt(h, 16));
      if (points.length !== 2) throw new Error(`unexpected variation sequence "${sequence}"`);
      const [base, selector] = points;
      if (!pairs.has(base)) pairs.set(base, new Set());
      pairs.get(base).add(selector);
    }
  }
  return pairs;
}

function pairRecords(pairs, encodeSelector) {
  return [...pairs.keys()]
    .sort((a, b) => a - b)
    .map(
      (base) =>
        `${hex(base)}:${[...pairs.get(base)]
          .sort((a, b) => a - b)
          .map(encodeSelector)
          .join(',')}`,
    );
}

/** Release date of an IVD_Sequences.txt: the first ISO date in its header (newest history entry). */
export function ivdRelease(text) {
  const header = text
    .split('\n')
    .filter((line) => line.startsWith('#'))
    .join('\n');
  return /\b(\d{4}-\d{2}-\d{2})\b/.exec(header)?.[1] ?? null;
}

export function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

/**
 * `files` maps each name of HYGIENE_SOURCE_FILES to its text; `ivd` is the text of
 * IVD_Sequences.txt, or null when it is not vendored.
 */
export function buildTextHygieneModule(files, ivd = null) {
  const version = /^# DerivedGeneralCategory-(\S+)\.txt/m.exec(files['DerivedGeneralCategory.txt'])?.[1];
  const hashes = HYGIENE_SOURCE_FILES.map((name) => `  '${name}': '${sha256(files[name])}',`);
  const gc = generalCategoryRecords(files['DerivedGeneralCategory.txt']);
  const di = propertyRanges(files['DerivedCoreProperties.txt'], 'Default_Ignorable_Code_Point');
  const vs = propertyRanges(files['PropList.txt'], 'Variation_Selector');
  const rgi = rgiRecords(files['emoji-sequences.txt'], files['emoji-zwj-sequences.txt']);
  const variation = pairRecords(
    variationPairs([files['StandardizedVariants.txt'], files['emoji-variation-sequences.txt']]),
    hex,
  );
  const ivdPairs = ivd === null ? null : variationPairs([ivd]);
  if (ivdPairs) {
    for (const selectors of ivdPairs.values()) {
      for (const sel of selectors) {
        if (sel < 0xe0100 || sel > 0xe01ef) throw new Error(`IVD selector out of range: ${hex(sel)}`);
      }
    }
  }
  const ivdRecords = ivdPairs ? pairRecords(ivdPairs, (sel) => hex(sel - 0xe0100)) : [];
  const ui = propertyRanges(files['PropList.txt'], 'Unified_Ideograph');
  const ranges = (list) => list.map(([a, b]) => `${hex(a)}-${hex(b)}`).join(';');
  return [
    '/* eslint-disable */',
    '// GENERATED by scripts/generate-text-hygiene.mjs from data/unicode-17/*.txt; do not edit.',
    `// Unicode ${version ?? 'unknown'} text-hygiene tables (CONVENTIONS section 6, v1.3.1 SEC-036, v1.4 SEC-039).`,
    `export const HYGIENE_UNICODE_VERSION = '${version ?? 'unknown'}';`,
    'export const HYGIENE_SOURCE_SHA256: Readonly<Record<string, string>> = {',
    ...hashes,
    '};',
    `/** ${gc.length} records "start:group"; groups L N M S P Z(=Zs) X(=Cc Cf Zl Zp Co Cs Cn). */`,
    `export const GC_DATA =`,
    `  '${gc.join(';')}';`,
    `/** Default_Ignorable_Code_Point = Yes (${di.length} ranges). */`,
    `export const DI_DATA = '${ranges(di)}';`,
    `/** Variation_Selector = Yes (${vs.length} ranges). */`,
    `export const VS_DATA = '${ranges(vs)}';`,
    `/** RGI emoji set: ${rgi.length} records (sequences, or ranges of single code points). */`,
    `export const RGI_DATA =`,
    `  '${rgi.join(';')}';`,
    `/** Listed variation sequences (StandardizedVariants + emoji-variation-sequences): ${variation.length} bases. */`,
    `export const VARIATION_DATA =`,
    `  '${variation.join(';')}';`,
    `/** IVD release vendored in data/ivd/ (null: not vendored; the interim rule applies). */`,
    `export const IVD_RELEASE: string | null = ${ivd === null ? 'null' : `'${ivdRelease(ivd)}'`};`,
    `export const IVD_SHA256: string | null = ${ivd === null ? 'null' : `'${sha256(ivd)}'`};`,
    `/** Registered ideographic variation sequences: ${ivdRecords.length} bases ("BASE:n", n = selector - E0100). */`,
    `export const IVD_DATA =`,
    `  '${ivdRecords.join(';')}';`,
    `/** Unified_Ideograph = Yes (${ui.length} ranges). */`,
    `export const UI_DATA = '${ranges(ui)}';`,
    '',
  ].join('\n');
}

export function readSourceFiles(dir = unicodeDir) {
  return Object.fromEntries(
    HYGIENE_SOURCE_FILES.map((name) => [name, readFileSync(join(dir, name), 'utf8')]),
  );
}

/** The vendored IVD file, or null when it is not vendored (data/ivd/IVD_Sequences.txt). */
export function readIvdFile(dir = ivdDir) {
  const path = join(dir, IVD_FILE);
  return existsSync(path) ? readFileSync(path, 'utf8') : null;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(
    join(dataDir, 'text-hygiene.generated.ts'),
    buildTextHygieneModule(readSourceFiles(), readIvdFile()),
  );
  process.stdout.write('wrote src/modules/users/data/text-hygiene.generated.ts\n');
}
