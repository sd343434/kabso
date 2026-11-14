import 'package:flutter/foundation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// v1.62-live (D254, CONVENTIONS §10.92; owner: «شريط متحرك لاعلان عن ترقية
/// الحسابات وصعود ليفيلات لليفيلات المرتفعة»): the `level-ticker` data
/// message (topic `level`) — someone's support level (gift senders) or charm
/// level (hosts and seated guests) rose, in [room], to the panel's threshold
/// (default 30) or above. Every live gets it, its own room too; the app
/// scrolls it under the header and a tap opens [room].
@immutable
class LevelTicker {
  const new({
    required this.id,
    required this.user,
    required this.category,
    required this.level,
    required this.room,
    this.previousLevel,
  });

  /// Throws (`TypeError` / `FormatException`) when the message does not
  /// match the contract or names a level system other than the two
  /// announced ones.
  factory fromJson(Map<String, dynamic> json) {
    final up = json['levelUp']! as Map<String, dynamic>;
    final category = LevelCategory.fromWire(up['category']);
    if (category != LevelCategory.support &&
        category != LevelCategory.attractiveness) {
      throw const FormatException('category');
    }
    return LevelTicker(
      id: up['id']! as String,
      user: UserSummary.fromJson(up['user']! as Map<String, dynamic>),
      category: category,
      level: (up['level']! as num).toInt(),
      previousLevel: (up['previousLevel'] as num?)?.toInt(),
      room: LuckyTickerRoom.fromJson(json['room']! as Map<String, dynamic>),
    );
  }

  /// One per person, level system and level (`<userId>:<category>:<level>`).
  final String id;

  /// Who reached the level.
  final UserSummary user;

  /// [LevelCategory.support] or [LevelCategory.attractiveness] (charm).
  final LevelCategory category;
  final int level;
  final int? previousLevel;

  /// The live it happened in (a tap opens it).
  final LuckyTickerRoom room;
}
