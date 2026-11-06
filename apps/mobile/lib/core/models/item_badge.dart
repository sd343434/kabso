import 'package:flutter/foundation.dart' show immutable;

/// v1.79-live (D289, CONVENTIONS §10.102): a badge of a gift or a store item.
/// The values are in the **display priority** (the server lists them in this
/// order): a small tile shows the first one or two that are running, the
/// details all of them. Each has one icon and one colour everywhere.
enum ItemBadgeCode {
  limited('LIMITED'),
  isNew('NEW'),
  seasonal('SEASONAL'),
  exclusive('EXCLUSIVE'),
  mostWanted('MOST_WANTED'),
  featured('FEATURED'),
  fullscreen('FULLSCREEN'),
  sound('SOUND'),
  noSound('NO_SOUND');

  new(this.wire);

  final String wire;

  /// Null for a code this app does not know (ignored).
  static ItemBadgeCode? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;

  /// Whether the badge carries an end (`until`).
  bool get timed => this == limited || this == isNew || this == seasonal;
}

/// `ItemBadge`: a badge that is showing, and its end (null: none).
@immutable
final class ItemBadge {
  const new(this.code, {this.until});

  final ItemBadgeCode code;
  final DateTime? until;

  /// Shown at [now]: no end, or the end is ahead (the server lists only the
  /// running ones; the device clock hides one that ended since).
  bool runningAt(DateTime now) => until == null || until!.isAfter(now);

  /// Whole days left (rounded up), or null without an end.
  int? daysLeft(DateTime now) {
    final end = until;
    if (end == null) return null;
    final ms = end.difference(now).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / Duration.millisecondsPerDay).ceil();
  }

  static ItemBadge? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = ItemBadgeCode.fromWire(json['code']);
    if (code == null) return null;
    final until = json['until'];
    return ItemBadge(
      code,
      until: until is String ? DateTime.tryParse(until) : null,
    );
  }

  Map<String, Object?> toJson() => {
    'code': code.wire,
    'until': until?.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is ItemBadge && other.code == code && other.until == until;

  @override
  int get hashCode => Object.hash(code, until);

  @override
  String toString() => 'ItemBadge(${code.wire}, $until)';
}

/// `badges` of a gift or a store item: known codes only, in the priority
/// order, each once (an older API without the field: none).
List<ItemBadge> itemBadgesFromJson(Object? json) {
  if (json is! List) return const [];
  final seen = <ItemBadgeCode>{};
  final out = <ItemBadge>[
    for (final raw in json)
      if (ItemBadge.fromJson(raw) case final b? when seen.add(b.code)) b,
  ]..sort((a, b) => a.code.index.compareTo(b.code.index));
  return List.unmodifiable(out);
}

List<Map<String, Object?>> itemBadgesToJson(List<ItemBadge> badges) => [
  for (final b in badges) b.toJson(),
];

/// The badges running at [now], in priority order.
List<ItemBadge> runningBadges(List<ItemBadge> badges, DateTime now) => [
  for (final b in badges)
    if (b.runningAt(now)) b,
];
