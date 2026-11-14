// D291 (v1.81-live, CONVENTIONS §10.104): `GET /medals` payloads with
// levels, shaped like docs/contracts/openapi.yaml `Medal` — test data only
// (fixtures stay under test/fixtures, G-26). The nine catalogue medals with
// their default levels; names in the request's language.

import 'package:kabso_live/features/medals/domain/medal_models.dart';

const _earned = '2026-10-26T18:30:00.000Z';

/// D291 «ملوك الثروة»: the owner's medal, its thresholds and art per level.
const d291WealthCode = 'WEALTH_KINGS';
const d291WealthThresholds = [
  50000000,
  150000000,
  300000000,
  500000000,
  1000000000,
  3000000000,
];

/// D291 «سيد الحظ»: the owner's lucky-gifts medal (10 B above 2^32).
const d291LuckyCode = 'LUCKY_MASTER';
const d291LuckyThresholds = [500000000, 1500000000, 3000000000, 10000000000];

/// A lucky-gifts total inside [level] (0: below level 1; 4: exactly 10 B).
int luckyValue(int level) => switch (level) {
  0 => 120000000,
  4 => 10000000000,
  _ => d291LuckyThresholds[level - 1] + 1000000,
};

/// A sent-gifts total inside [level] (0: below level 1).
int wealthValue(int level) => switch (level) {
  0 => 12000000,
  6 => 3200000000,
  _ => d291WealthThresholds[level - 1] + 1000000,
};

Map<String, Object?> _levels(
  List<int> thresholds, {
  Map<int, String>? names,
}) => {
  'levels': [
    for (final (i, t) in thresholds.indexed)
      {'level': i + 1, 'threshold': t, 'name': names?[i + 1], 'iconUrl': null},
  ],
  'maxLevel': thresholds.length,
};

Map<String, Object?> d291MedalJson({
  required String code,
  required String name,
  required String description,
  required String category,
  required String metric,
  required List<int> thresholds,
  required int level,
  required int value,
  int sortOrder = 10,
  int? showcasePosition,
  Map<int, String>? levelNames,
}) => {
  'code': code,
  'name': name,
  'description': description,
  'iconKey': 'medal_${code.toLowerCase()}',
  'sortOrder': sortOrder,
  'awardedAt': level > 0 ? _earned : null,
  'category': category,
  'metric': metric,
  'level': level,
  ..._levels(thresholds, names: levelNames),
  'progress': {
    'value': value,
    'next': level < thresholds.length ? thresholds[level] : null,
  },
  'iconUrl': null,
  'showcasePosition': showcasePosition,
};

/// The wearable catalogue as a person sees it (D291: the charm and
/// live-hours codes are retired name-side icons, never sent): FIRST_LIVE
/// level 2 (12 lives), FIRST_FAMILY not earned,
/// FIRST_CP earned, BULLET_FIRST level 3, and «ملوك الثروة» (WEALTH_KINGS)
/// at [wealthLevel] with the owner's art of each level. [worn]: the
/// showcase in order.
List<Medal> d291Medals({
  required bool ar,
  int wealthLevel = 1,
  int luckyLevel = 2,
  List<String> worn = const [d291WealthCode, 'FIRST_LIVE', 'FIRST_CP'],
}) {
  String n(String a, String e) => ar ? a : e;
  int? pos(String code) {
    final i = worn.indexOf(code);
    return i < 0 ? null : i + 1;
  }

  return [
    {
      ...d291MedalJson(
        code: d291WealthCode,
        name: n('ملوك الثروة', 'Wealth Kings'),
        description: n(
          'مجموع قيمة الهدايا التي أرسلتها لأي مستخدم، عدا هدايا الحظ.',
          'Total value of gifts you sent to anyone, except lucky gifts.',
        ),
        category: 'ACHIEVEMENT',
        metric: 'GIFTS_SENT_COINS',
        thresholds: d291WealthThresholds,
        level: wealthLevel,
        value: wealthValue(wealthLevel),
        sortOrder: 5,
        showcasePosition: pos(d291WealthCode),
      ),
      'iconKey': 'medal_wealth_kings',
      'iconAsset': 'medal_wealth_l${wealthLevel < 1 ? 1 : wealthLevel}',
      'levels': [
        for (final (k, t) in d291WealthThresholds.indexed)
          {
            'level': k + 1,
            'threshold': t,
            'name': null,
            'iconUrl': null,
            'iconAsset': 'medal_wealth_l${k + 1}',
          },
      ],
    },
    {
      ...d291MedalJson(
        code: d291LuckyCode,
        name: n('سيد الحظ', 'Lucky Master'),
        description: n(
          'مجموع قيمة هدايا الحظ التي أرسلتها.',
          'Total value of lucky gifts you sent.',
        ),
        category: 'ACHIEVEMENT',
        metric: 'LUCKY_GIFTS_SENT_COINS',
        thresholds: d291LuckyThresholds,
        level: luckyLevel,
        value: luckyValue(luckyLevel),
        sortOrder: 6,
        showcasePosition: pos(d291LuckyCode),
      ),
      'iconKey': 'medal_lucky_master',
      'iconAsset': 'medal_lucky_l${luckyLevel < 1 ? 1 : luckyLevel}',
      'levels': [
        for (final (k, t) in d291LuckyThresholds.indexed)
          {
            'level': k + 1,
            'threshold': t,
            'name': null,
            'iconUrl': null,
            'iconAsset': 'medal_lucky_l${k + 1}',
          },
      ],
    },
    d291MedalJson(
      code: 'FIRST_LIVE',
      name: n('أول لايف', 'First live'),
      description: n('استضفت أول بث مباشر لك.', 'Hosted your first live.'),
      category: 'ACTIVITY',
      metric: 'LIVES_HOSTED',
      thresholds: [1, 10, 50, 100, 500],
      level: 2,
      value: 12,
      showcasePosition: pos('FIRST_LIVE'),
    ),
    d291MedalJson(
      code: 'FIRST_FAMILY',
      name: n('أول عائلة', 'First family'),
      description: n(
        'انضممت إلى عائلة أو أنشأت واحدة.',
        'Joined or created a family.',
      ),
      category: 'ACHIEVEMENT',
      metric: 'FAMILY_JOINED',
      thresholds: [1],
      level: 0,
      value: 0,
      sortOrder: 70,
      showcasePosition: pos('FIRST_FAMILY'),
    ),
    d291MedalJson(
      code: 'FIRST_CP',
      name: n('أول ثنائي', 'First couple'),
      description: n('كوّنت أول ثنائي (CP).', 'Formed your first CP couple.'),
      category: 'ACHIEVEMENT',
      metric: 'CP_FORMED',
      thresholds: [1],
      level: 1,
      value: 1,
      sortOrder: 80,
      showcasePosition: pos('FIRST_CP'),
    ),
    d291MedalJson(
      code: 'BULLET_FIRST',
      name: n('أول رسالة عامة', 'First bullet message'),
      description: n(
        'أرسلت أول رسالة عامة.',
        'Sent your first bullet message.',
      ),
      category: 'ACTIVITY',
      metric: 'BULLETS_SENT',
      thresholds: [1, 10, 100, 1000],
      level: 3,
      value: 140,
      levelNames: {3: n('نجم الرسائل', 'Bullet star')},
      sortOrder: 90,
      showcasePosition: pos('BULLET_FIRST'),
    ),
  ].map(Medal.fromJson).toList();
}

/// The same catalogue with nothing earned yet (the empty stage).
List<Medal> d291NothingEarned({required bool ar}) => [
  for (final m in d291Medals(
    ar: ar,
    worn: const [],
    wealthLevel: 0,
    luckyLevel: 0,
  ))
    m.copyWith(
      awardedAt: null,
      level: 0,
      showcasePosition: null,
      progress: MedalProgress(next: m.levels.firstOrNull?.threshold),
    ),
];
