// D72: JSON shaped like docs/contracts/openapi.yaml v1.4-levels (DRAFT)
// `LevelSummary` / `LevelDetail`. Test data only — labelled as fixtures and
// never reachable from production.

Map<String, dynamic> levelBriefJson(
  int number, {
  String? name,
  String requiredPoints = '0',
  String? iconKey,
}) => {
  'levelNumber': number,
  'name': name ?? 'Level name $number',
  'requiredPoints': requiredPoints,
  'iconKey': iconKey,
};

const _names = {
  'ATTRACTIVENESS': ('مستوى الجاذبية', 'Attractiveness'),
  'SUPPORT': ('مستوى الدعم', 'Support'),
  'WIZARD': ('مستوى الساحر', 'Wizard'),
  'GAMING': ('مستوى اللعب', 'Gaming'),
};

Map<String, dynamic> levelSummaryJson(
  String category, {
  bool available = true,
  String points = '0',
  String carriedPoints = '0',
  Map<String, dynamic>? level,
  Map<String, dynamic>? nextLevel,
  String? pointsToNext,
  double? progressPercent,
  bool maxLevel = false,
  int? versionNumber = 1,
  bool arabic = false,
}) {
  final (ar, en) = _names[category]!;
  return {
    'category': category,
    'status': available ? 'AVAILABLE' : 'UNAVAILABLE',
    'name': arabic ? ar : en,
    'description': arabic
        ? 'يرتفع بقيمة النشاط المؤكد.'
        : 'Grows with confirmed activity.',
    'points': points,
    'carriedPoints': available ? carriedPoints : '0',
    'level': available ? level : null,
    'nextLevel': available ? nextLevel : null,
    'pointsToNext': available ? pointsToNext : null,
    'progressPercent': available ? progressPercent : null,
    'maxLevel': available && maxLevel,
    'versionNumber': available ? versionNumber : null,
  };
}

/// The four categories with a spread of states: mid-ladder, early, top
/// level, and one the server has not switched on.
List<Map<String, dynamic>> mixedLevelsJson({bool arabic = false}) => [
  levelSummaryJson(
    'ATTRACTIVENESS',
    arabic: arabic,
    points: '12500',
    level: levelBriefJson(
      37,
      name: arabic ? 'نجم صاعد' : 'Rising star',
      requiredPoints: '12000',
    ),
    nextLevel: levelBriefJson(38, requiredPoints: '13000'),
    pointsToNext: '500',
    progressPercent: 50,
  ),
  levelSummaryJson(
    'SUPPORT',
    arabic: arabic,
    points: '150',
    level: levelBriefJson(
      2,
      name: arabic ? 'داعم' : 'Supporter',
      requiredPoints: '100',
    ),
    nextLevel: levelBriefJson(
      3,
      name: arabic ? 'داعم فضي' : 'Silver supporter',
      requiredPoints: '500',
      iconKey: 'tier_03',
    ),
    pointsToNext: '350',
    progressPercent: 12.5,
  ),
  levelSummaryJson(
    'WIZARD',
    arabic: arabic,
    points: '9800000',
    level: levelBriefJson(
      100,
      name: arabic ? 'أسطورة' : 'Legend',
      requiredPoints: '9000000',
    ),
    progressPercent: 100,
    maxLevel: true,
  ),
  levelSummaryJson('GAMING', arabic: arabic, available: false),
];

List<Map<String, dynamic>> allUnavailableJson({bool arabic = false}) => [
  for (final c in ['ATTRACTIVENESS', 'SUPPORT', 'WIZARD', 'GAMING'])
    levelSummaryJson(c, arabic: arabic, available: false),
];

Map<String, dynamic> supportDetailJson({bool arabic = false}) => {
  ...mixedLevelsJson(arabic: arabic)[1],
  'levels': [
    levelBriefJson(1, name: arabic ? 'مبتدئ' : 'Starter'),
    levelBriefJson(
      2,
      name: arabic ? 'داعم' : 'Supporter',
      requiredPoints: '100',
    ),
    levelBriefJson(
      3,
      name: arabic ? 'داعم فضي' : 'Silver supporter',
      requiredPoints: '500',
      iconKey: 'tier_03',
    ),
    levelBriefJson(
      4,
      name: arabic ? 'داعم ذهبي' : 'Gold supporter',
      requiredPoints: '1000',
    ),
  ],
};

/// D194: the repriced ladder's thresholds (points; 1 point per 10 coins),
/// level 1 → 100: 0 … 2 000 840 500.
List<BigInt> d194Thresholds() {
  const bands = [
    (10, 4500),
    (20, 20000),
    (30, 100000),
    (40, 360000),
    (50, 1100000),
    (60, 3200000),
    (80, 13600000),
    (99, 59000000),
    (100, 560000000),
  ];
  var required = BigInt.zero;
  return [
    for (var n = 1; n <= 100; n++)
      required += n == 1
          ? BigInt.zero
          : BigInt.from(bands.firstWhere((b) => n <= b.$1).$2),
  ];
}

/// D194: support kept at level 50 after the ladder change (16 500 earned
/// points, the rest carried), with the whole 100-level ladder.
Map<String, dynamic> d194SupportDetailJson({bool arabic = false}) {
  final t = d194Thresholds();
  final points = BigInt.from(16500);
  final carried = t[49] + BigInt.from(410) - points;
  return {
    ...levelSummaryJson(
      'SUPPORT',
      arabic: arabic,
      points: '$points',
      carriedPoints: '$carried',
      level: levelBriefJson(
        50,
        name: arabic ? 'زمردي' : 'Emerald',
        requiredPoints: '${t[49]}',
        iconKey: 'tier_06',
      ),
      nextLevel: levelBriefJson(
        51,
        name: arabic ? 'ياقوتي' : 'Sapphire',
        requiredPoints: '${t[50]}',
        iconKey: 'tier_06',
      ),
      pointsToNext: '${t[50] - t[49] - BigInt.from(410)}',
      progressPercent: 0,
    ),
    'levels': [
      for (var n = 1; n <= 100; n++)
        levelBriefJson(
          n,
          name: arabic ? 'مستوى' : 'Level',
          requiredPoints: '${t[n - 1]}',
        ),
    ],
  };
}

/// D194: the four categories near the top of the new ladder (billions).
List<Map<String, dynamic>> d194LevelsJson({bool arabic = false}) {
  final t = d194Thresholds();
  final support = d194SupportDetailJson(arabic: arabic)..remove('levels');
  return [
    levelSummaryJson(
      'ATTRACTIVENESS',
      arabic: arabic,
      points: '${t[98] + BigInt.from(123456789)}',
      level: levelBriefJson(99, requiredPoints: '${t[98]}'),
      nextLevel: levelBriefJson(100, requiredPoints: '${t[99]}'),
      pointsToNext: '${t[99] - t[98] - BigInt.from(123456789)}',
      progressPercent: 22,
    ),
    support,
    levelSummaryJson(
      'WIZARD',
      arabic: arabic,
      points: '${t[99]}',
      level: levelBriefJson(100, requiredPoints: '${t[99]}'),
      progressPercent: 100,
      maxLevel: true,
    ),
    levelSummaryJson('GAMING', arabic: arabic, available: false),
  ];
}
