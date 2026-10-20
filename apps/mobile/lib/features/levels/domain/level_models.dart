import 'package:material_ui/material_ui.dart';

/// The four independent level systems (CP-005 §2), in display order.
enum LevelCategory {
  attractiveness('ATTRACTIVENESS'),
  support('SUPPORT'),
  wizard('WIZARD'),
  gaming('GAMING');

  new(this.wire);

  /// The API code (`LevelCategoryCode`).
  final String wire;

  /// The path segment of `GET /levels/me/{category}` (lower case).
  String get slug => name;

  static LevelCategory fromWire(Object? value) =>
      LevelCategory.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => throw const FormatException('category'),
      );

  static LevelCategory? fromSlug(String slug) {
    for (final c in LevelCategory.values) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

/// A whole number of points sent as a decimal string (`PointsAmount`), so
/// 64-bit values survive JSON.
BigInt _points(Object? value) {
  if (value is! String) throw const FormatException('points');
  return BigInt.parse(value);
}

BigInt? _pointsOrNull(Object? value) => value == null ? null : _points(value);

/// One level of a category's ladder (`LevelBrief`).
@immutable
class LevelBrief {
  const new({
    required this.levelNumber,
    required this.name,
    required this.requiredPoints,
    this.iconKey,
  });

  factory fromJson(Map<String, dynamic> json) => LevelBrief(
    levelNumber: json['levelNumber']! as int,
    name: json['name']! as String,
    requiredPoints: _points(json['requiredPoints']),
    iconKey: json['iconKey'] as String?,
  );

  final int levelNumber;

  /// Localized by the server (`Accept-Language`).
  final String name;
  final BigInt requiredPoints;

  /// Optional server-chosen art (`tier_01`…`tier_11`); see `levelTier`.
  final String? iconKey;

  @override
  bool operator ==(Object other) =>
      other is LevelBrief &&
      other.levelNumber == levelNumber &&
      other.name == name &&
      other.requiredPoints == requiredPoints &&
      other.iconKey == iconKey;

  @override
  int get hashCode => Object.hash(levelNumber, name, requiredPoints, iconKey);
}

/// The caller's progress in one category (`LevelSummary`). The server
/// computes everything; the app never derives points or levels itself.
@immutable
class LevelSummary {
  const new({
    required this.category,
    required this.available,
    required this.name,
    required this.description,
    required this.points,
    this.level,
    this.nextLevel,
    this.pointsToNext,
    this.progressPercent,
    this.maxLevel = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status != 'AVAILABLE' && status != 'UNAVAILABLE') {
      throw const FormatException('status');
    }
    Map<String, dynamic>? map(Object? v) => v as Map<String, dynamic>?;
    final level = map(json['level']);
    final next = map(json['nextLevel']);
    return LevelSummary(
      category: LevelCategory.fromWire(json['category']),
      available: status == 'AVAILABLE',
      name: json['name']! as String,
      description: json['description']! as String,
      points: _points(json['points']),
      level: level == null ? null : LevelBrief.fromJson(level),
      nextLevel: next == null ? null : LevelBrief.fromJson(next),
      pointsToNext: _pointsOrNull(json['pointsToNext']),
      progressPercent: (json['progressPercent'] as num?)?.toDouble(),
      maxLevel: json['maxLevel']! as bool,
    );
  }

  final LevelCategory category;

  /// `false` = UNAVAILABLE: the category is switched off or not configured
  /// yet (CP-005 §4); it has no level.
  final bool available;
  final String name;
  final String description;
  final BigInt points;
  final LevelBrief? level;
  final LevelBrief? nextLevel;
  final BigInt? pointsToNext;

  /// 0–100, one decimal; 100 at the top level.
  final double? progressPercent;
  final bool maxLevel;
}

/// One category with its whole ladder (`LevelDetail`).
@immutable
class LevelDetail {
  const new({required this.summary, required this.levels});

  factory fromJson(Map<String, dynamic> json) => LevelDetail(
    summary: LevelSummary.fromJson(json),
    levels: [
      for (final item in json['levels']! as List<dynamic>)
        LevelBrief.fromJson(item as Map<String, dynamic>),
    ],
  );

  final LevelSummary summary;

  /// Empty while the category is unavailable.
  final List<LevelBrief> levels;
}

/// Another user's level in one category, as their profile shows it
/// (`PublicLevel`): never points.
@immutable
class PublicLevel {
  const new({required this.category, required this.name, this.level});

  factory fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status != 'AVAILABLE' && status != 'UNAVAILABLE') {
      throw const FormatException('status');
    }
    final level = json['level'] as Map<String, dynamic>?;
    return PublicLevel(
      category: LevelCategory.fromWire(json['category']),
      name: json['name']! as String,
      level: status == 'AVAILABLE' && level != null
          ? LevelBrief.fromJson(level)
          : null,
    );
  }

  final LevelCategory category;
  final String name;

  /// Null while the category is not active (or before a first level).
  final LevelBrief? level;
}
