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
