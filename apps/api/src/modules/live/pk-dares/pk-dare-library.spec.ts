import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  PK_DARE_CATEGORIES,
  checkDareSafety,
  findDuplicates,
  parseCsv,
  parseDareImport,
  toCsv,
  type PkDareImport,
} from './pk-dare-rules.js';

const here = dirname(fileURLToPath(import.meta.url));
const SEED = join(here, '../../../../prisma/seed/pk-dares/pk-dares.v1.jsonl');

function library(): PkDareImport[] {
  return readFileSync(SEED, 'utf8')
    .split('\n')
    .filter((l) => l.trim().length > 0)
    .map((l) => {
      const parsed = parseDareImport(JSON.parse(l));
      if (typeof parsed === 'string') throw new Error(`Bad seed line (${parsed}): ${l}`);
      return parsed;
    });
}

describe('D229 the seed library (pk-dares.v1.jsonl)', () => {
  const dares = library();

  it('holds 20 000 dares with unique codes', () => {
    expect(dares.length).toBe(20000);
    expect(new Set(dares.map((d) => d.code)).size).toBe(dares.length);
  });

  it('has 0 safety violations over the whole file', () => {
    const bad = dares.map((d) => ({ code: d.code, v: checkDareSafety(d) })).filter((x) => x.v.length > 0);
    expect(bad.slice(0, 5)).toEqual([]);
    expect(bad.length).toBe(0);
  }, 120_000);

  it('has 0 exact or near duplicates (normalized text, word-set Jaccard ≥ 0.8, both languages)', () => {
    const dups = findDuplicates(dares);
    expect(dups.slice(0, 5).map((p) => [dares[p.a]!.code, dares[p.b]!.code, p.lang, p.similarity])).toEqual(
      [],
    );
    expect(dups.length).toBe(0);
  }, 120_000);

  it('levels are about a third each (33 / 33 / 34 %) and every category is present', () => {
    const by = (l: string) => dares.filter((d) => d.level === l).length / dares.length;
    expect(by('EASY')).toBeCloseTo(0.33, 2);
    expect(by('MEDIUM')).toBeCloseTo(0.33, 2);
    expect(by('HARD')).toBeCloseTo(0.34, 2);
    for (const c of PK_DARE_CATEGORIES) {
      const n = dares.filter((d) => d.category === c).length;
      expect(n, c).toBeGreaterThan(1000);
      for (const l of ['EASY', 'MEDIUM', 'HARD']) {
        expect(
          dares.some((d) => d.category === c && d.level === l),
          `${c}/${l}`,
        ).toBe(true);
      }
    }
  });

  it('Arabic ≤ 90 characters, English ≤ 140', () => {
    expect(dares.filter((d) => [...d.textAr].length > 90 || [...d.textEn].length > 140)).toEqual([]);
  });
});

describe('D229 the safety checker', () => {
  const v = (textAr: string, textEn: string) => checkDareSafety({ textAr, textEn }).map((x) => x.rule);

  it.each([
    ['تقليد قطة قرب النار', 'Imitate a cat near the fire', 'danger'],
    ['القفز من على الكرسي', 'Jump off the chair', 'danger'],
    ['أكل ملعقة من الملح', 'Eat a spoon of salt', 'ingest'],
    ['خلع القميص أمام الكاميرا', 'Take off your shirt and undress', 'sexual'],
    ['إرسال قبلة للمشاهدين', 'Blow a kiss to the viewers', 'sexual'],
    ['وصف الفائز بأنه غبي', 'Call the winner stupid', 'insult'],
    ['تقليد شخص يدخن سيجارة', 'Pretend to smoke a cigarette', 'substances'],
    ['قول رقم هاتفك', 'Say your phone number', 'personal_info'],
    ['الاتصال بصديق', 'Phone a friend', 'third_parties'],
    ['شراء هدية للفائز', 'Buy a gift for the winner', 'money'],
    ['تمثيل سرقة بنك', 'Act out a bank theft', 'illegal'],
    ['تقليد شخص أعمى', 'Imitate a blind person', 'disability'],
    ['أداء صلاة قصيرة', 'Say a short prayer', 'religion'],
    ['خطاب عن الرئيس والحكومة', 'A speech about the president', 'politics'],
  ])('blocks «%s» / «%s» (%s)', (ar, en, rule) => {
    expect(v(ar, en)).toContain(rule);
  });

  it('a stated duration over 3 minutes, a missing language, an overlong text, contact handles', () => {
    expect(v('غناء أغنية لمدة 5 دقائق', 'Sing a song for 5 minutes')).toContain('duration');
    expect(v('', 'Sing a song')).toContain('missing');
    expect(v('غ'.repeat(91), 'Sing')).toContain('length');
    expect(v('ذكر الحساب @kabso', 'Say @kabso')).toContain('contact');
    expect(v('تقليد بطريق', 'Imitate a penguin بالعربية')).toContain('language');
  });

  it('no false positives on common words («huge», «called», «كبيرة», «خطرت»)', () => {
    expect(v('غناء أغنية بحماس شديد', 'Sing a song with huge excitement')).toEqual([]);
    expect(v('ابتكار رقصة اسمها «الموجة»', 'Invent a dance called «The Wave»')).toEqual([]);
    expect(v('تقليد بطريق بسرعة كبيرة', 'Imitate a penguin really fast')).toEqual([]);
    expect(v('ما أفضل فكرة خطرت لك؟', 'What is the best idea you had?')).toEqual([]);
  });

  it('flags gendered Arabic pronouns («أنتِ / أنتَ»)', () => {
    expect(v('غناء أغنية وأنت جالس', 'Sing a song while seated')).toContain('gendered');
  });

  it('finds an added near-duplicate against the library', () => {
    const base = [
      {
        textAr: 'تقليد بطريق أثناء غسل الصحون بصوت هامس',
        textEn: 'Imitate a penguin washing the dishes, in a whisper',
      },
    ];
    const near = {
      textAr: 'تقليد بطريق أثناء غسل الصحون بصوت هامس جداً',
      textEn: 'Imitate a penguin washing dishes in a whisper',
    };
    expect(findDuplicates([...base, near], 1).length).toBeGreaterThan(0);
  });

  it('CSV round trip (quotes, commas, new lines)', () => {
    const rows: PkDareImport[] = [
      {
        code: 'a-001',
        category: 'FUNNY',
        level: 'EASY',
        textAr: 'تقديم «كوب»، بحماس',
        textEn: 'Say "hi", twice',
      },
    ];
    const back = parseCsv(toCsv(rows)).map(parseDareImport);
    expect(back).toEqual(rows);
  });
});
