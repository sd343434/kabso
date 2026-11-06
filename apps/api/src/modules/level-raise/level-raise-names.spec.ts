import { describe, expect, it } from 'vitest';
import {
  accountKey,
  exactApp,
  matchScore,
  nameKey,
  sourceAppKey,
  suggest,
  type NamedApp,
} from './level-raise-names.js';

const apps: NamedApp[] = [
  {
    code: 'ZAFA',
    nameAr: 'زفة',
    nameEn: 'Zafa',
    aliases: ['زافا', 'زفه', 'Zafa Live', 'زفة لايف'],
    isOther: false,
  },
  {
    code: 'BIGO_LIVE',
    nameAr: 'بيقو لايف',
    nameEn: 'Bigo Live',
    aliases: ['Bigo', 'بيجو', 'بيغو'],
    isOther: false,
  },
  { code: 'YALLA', nameAr: 'يلا', nameEn: 'Yalla', aliases: ['يلّا', 'Yalla Live'], isOther: false },
  { code: 'OTHER', nameAr: 'تطبيق آخر', nameEn: 'Other app', aliases: [], isOther: true },
];

describe('nameKey', () => {
  it('ignores case, spaces, punctuation and Latin diacritics', () => {
    expect(nameKey('  Zafa  Live ')).toBe('zafalive');
    expect(nameKey('ZAFA-live!')).toBe('zafalive');
    expect(nameKey('Zâfá')).toBe('zafa');
  });
  it('ignores Arabic tashkeel and tatweel and unifies the swapped letters', () => {
    expect(nameKey('زفة')).toBe(nameKey('زفه'));
    expect(nameKey('يلّا')).toBe(nameKey('يلا'));
    expect(nameKey('أهلاً')).toBe(nameKey('اهلا'));
    expect(nameKey('هـــلا')).toBe(nameKey('هلا'));
    expect(nameKey('مُوسى')).toBe(nameKey('موسي'));
    expect(nameKey('تطبيق ٣')).toBe('تطبيق3');
  });
  it('account IDs are trimmed and lower-cased only', () => {
    expect(accountKey('  AbC-12 ')).toBe('abc-12');
  });
  it('the canonical source key', () => {
    expect(sourceAppKey(apps[0]!, null)).toBe('APP:ZAFA');
    expect(sourceAppKey(apps[3]!, ' Voice X ')).toBe('NAME:voicex');
  });
});

describe('matching and suggestions', () => {
  it('scores equal > prefix > contained', () => {
    expect(matchScore('zafa', 'zafa')).toBe(3);
    expect(matchScore('zaf', 'zafa')).toBe(2);
    expect(matchScore('afa', 'zafa')).toBe(1);
    expect(matchScore('a', 'zafa')).toBe(0);
  });
  it('an alias names the listed app exactly, in Arabic or Latin', () => {
    expect(exactApp(apps, 'زفه')?.code).toBe('ZAFA');
    expect(exactApp(apps, 'zafa live')?.code).toBe('ZAFA');
    expect(exactApp(apps, 'بيجو')?.code).toBe('BIGO_LIVE');
    expect(exactApp(apps, 'تطبيق آخر')).toBeNull();
    expect(exactApp(apps, 'Voice X')).toBeNull();
  });
  it('suggests listed apps (Arabic / Latin / aliases) before earlier typed names', () => {
    expect(suggest('زفه', apps, [])[0]).toMatchObject({ kind: 'APP', app: { code: 'ZAFA' }, score: 3 });
    expect(suggest('zaf', apps, [])[0]).toMatchObject({ kind: 'APP', app: { code: 'ZAFA' }, score: 2 });
    expect(suggest('بيغو', apps, [])[0]).toMatchObject({ kind: 'APP', app: { code: 'BIGO_LIVE' } });
    const earlier = [
      { key: nameKey('Voice X'), name: 'Voice X', count: 3 },
      { key: nameKey('زفة'), name: 'زفة', count: 1 },
    ];
    expect(suggest('voice  x', apps, earlier)).toEqual([
      { kind: 'NAME', name: 'Voice X', count: 3, score: 3 },
    ]);
    // An earlier typed name that is now a listed app's spelling is not suggested twice.
    expect(suggest('زفة', apps, earlier).map((s) => s.kind)).toEqual(['APP']);
    expect(suggest('   ', apps, earlier)).toEqual([]);
    expect(suggest('xyz', apps, earlier)).toEqual([]);
  });
});
