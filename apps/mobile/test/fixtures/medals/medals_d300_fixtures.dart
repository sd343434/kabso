// D300 (v1.83-live, CONVENTIONS §10.111): `GET /medals` payloads with
// «مدرسة المحتوى» (Content School: followers, likes and views together,
// creators only) and «لاعب الأحكام» (Dares Player: PK points), shaped like
// docs/contracts/openapi.yaml `Medal` — test data only (G-26). Added to the
// D291 catalogue.

import 'package:kabso_live/features/medals/domain/medal_models.dart';

import 'medals_d291_fixtures.dart';

const d300SchoolCode = 'CONTENT_SCHOOL';
const d300DaresCode = 'DARES_PLAYER';

/// The owner's thresholds per level: followers, likes, views.
const d300SchoolThresholds = [
  [2000, 10000, 20000],
  [10000, 50000, 100000],
  [100000, 200000, 500000],
  [1000000, 2000000, 5000000],
];

/// The owner's PK points thresholds.
const d300DaresThresholds = [1500, 3000, 5000, 20000];

/// A creator's followers, likes and views while at [level] (0 … 4).
List<int> d300SchoolValues(int level) => switch (level) {
  0 => [1850, 10400, 16200],
  1 => [6200, 41000, 88000],
  2 => [48000, 190000, 230000],
  3 => [410000, 1250000, 3900000],
  _ => [1200000, 2600000, 7100000],
};

/// «PK أحكام» points while at [level] (0 … 4).
int d300DaresValue(int level) => switch (level) {
  0 => 900,
  1 => 2140,
  2 => 3700,
  3 => 12400,
  _ => 21300,
};

const _metrics = ['CREATOR_FOLLOWERS', 'CREATOR_LIKES', 'CREATOR_VIEWS'];

Map<String, Object?> d300SchoolJson({
  required bool ar,
  required int level,
  bool eligible = true,
  int? showcasePosition,
}) {
  final values = eligible ? d300SchoolValues(level) : const [0, 0, 0];
  final targets = level < 4 ? d300SchoolThresholds[level] : null;
  return {
    'code': d300SchoolCode,
    'name': ar ? 'مدرسة المحتوى' : 'Content School',
    'description': ar
        ? 'لصنّاع المحتوى: المتابعون والإعجابات والمشاهدات معاً.'
        : 'For content creators: followers, likes and views together.',
    'iconKey': 'medal_content_school',
    'sortOrder': 7,
    'awardedAt': level > 0 ? '2026-11-07T08:00:00.000Z' : null,
    'category': 'ACHIEVEMENT',
    'metric': 'ALL_REQUIREMENTS',
    'level': level,
    'maxLevel': 4,
    'levels': [
      for (final (i, t) in d300SchoolThresholds.indexed)
        {
          'level': i + 1,
          'threshold': i + 1,
          'name': null,
          'iconUrl': null,
          'iconAsset': 'medal_content_school_l${i + 1}',
          'requirements': [
            for (final (k, m) in _metrics.indexed)
              {'metric': m, 'threshold': t[k]},
          ],
        },
    ],
    'progress': {
      'value': eligible ? level : 0,
      'next': level < 4 ? level + 1 : null,
      'requirements': [
        for (final (k, m) in _metrics.indexed)
          {
            'metric': m,
            'value': values[k],
            'next': targets == null
                ? null
                : (eligible ? targets[k] : d300SchoolThresholds[0][k]),
          },
      ],
    },
    'iconUrl': null,
    'iconAsset': 'medal_content_school_l${level < 1 ? 1 : level}',
    'showcasePosition': showcasePosition,
    'eligible': eligible,
  };
}

Map<String, Object?> d300DaresJson({
  required bool ar,
  required int level,
  int? showcasePosition,
}) => {
  ...d291MedalJson(
    code: d300DaresCode,
    name: ar ? 'لاعب الأحكام' : 'Dares Player',
    description: ar
        ? 'نقاط PK التي جمعتها في التحديات.'
        : 'PK points you earned in battles.',
    category: 'ACHIEVEMENT',
    metric: 'PK_DARES_POINTS',
    thresholds: d300DaresThresholds,
    level: level,
    value: d300DaresValue(level),
    sortOrder: 8,
    showcasePosition: showcasePosition,
  ),
  'iconKey': 'medal_dares_player',
  'iconAsset': 'medal_dares_player_l${level < 1 ? 1 : level}',
  'levels': [
    for (final (k, t) in d300DaresThresholds.indexed)
      {
        'level': k + 1,
        'threshold': t,
        'name': null,
        'iconUrl': null,
        'iconAsset': 'medal_dares_player_l${k + 1}',
      },
  ],
};

/// The D291 catalogue plus the two D300 medals: «مدرسة المحتوى» at
/// [schoolLevel] (a creator unless [creator] is false) and «لاعب الأحكام»
/// at [daresLevel]. [worn]: the showcase in order.
List<Medal> d300Medals({
  required bool ar,
  int schoolLevel = 2,
  bool creator = true,
  int daresLevel = 3,
  List<String> worn = const [d300SchoolCode, d291WealthCode],
}) {
  int? pos(String code) {
    final i = worn.indexOf(code);
    return i < 0 ? null : i + 1;
  }

  final base = d291Medals(
    ar: ar,
    worn: [
      for (final c in worn)
        if (c != d300SchoolCode && c != d300DaresCode) c,
    ],
  );
  return [
    Medal.fromJson(
      d300SchoolJson(
        ar: ar,
        level: schoolLevel,
        eligible: creator,
        showcasePosition: pos(d300SchoolCode),
      ),
    ),
    Medal.fromJson(
      d300DaresJson(
        ar: ar,
        level: daresLevel,
        showcasePosition: pos(d300DaresCode),
      ),
    ),
    for (final m in base)
      if (m.showcasePosition == null)
        m
      else
        m.copyWith(showcasePosition: pos(m.code)),
  ];
}
