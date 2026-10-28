import 'package:flutter/foundation.dart' show immutable;

/// `LiveProgramItem` (v1.36-live, D154e, CONVENTIONS §10.37): one segment
/// of a live's program «قائمة البرامج».
@immutable
final class LiveProgramItem {
  const new({
    required this.position,
    required this.startsAt,
    required this.title,
  });

  /// Reads [json]; throws on a malformed one.
  factory fromJson(Map<String, dynamic> json) => LiveProgramItem(
    position: (json['position']! as num).toInt(),
    startsAt: DateTime.parse(json['startsAt']! as String),
    title: json['title']! as String,
  );

  final int position;
  final DateTime startsAt;

  /// Masked with the host's blocked words by the server.
  final String title;

  @override
  bool operator ==(Object other) =>
      other is LiveProgramItem &&
      other.position == position &&
      other.startsAt == startsAt &&
      other.title == title;

  @override
  int get hashCode => Object.hash(position, startsAt, title);
}

/// `LiveProgram`: a live's segments in order and the one on now.
@immutable
final class LiveProgram {
  const new({required this.roomId, required this.items, this.current});

  /// Reads [json]; throws on a malformed one.
  factory fromJson(Map<String, dynamic> json) => LiveProgram(
    roomId: json['roomId']! as String,
    items: [
      for (final i in json['items']! as List<dynamic>)
        LiveProgramItem.fromJson(i as Map<String, dynamic>),
    ],
    current: (json['current'] as num?)?.toInt(),
  );

  /// At most this many segments (the server's limit).
  static const maxItems = 10;

  /// A title's longest, in code points (the server's limit).
  static const titleMax = 60;

  final String roomId;
  final List<LiveProgramItem> items;

  /// The segment on now (the last one started, while the live is on), else
  /// null.
  final int? current;

  LiveProgramItem? get currentItem => current == null
      ? null
      : items.where((i) => i.position == current).firstOrNull;

  /// The first segment after the current one (or the first one when none
  /// started yet).
  LiveProgramItem? get nextItem {
    final from = current ?? -1;
    return items.where((i) => i.position > from).firstOrNull;
  }

  LiveProgram withRoom(String id) =>
      LiveProgram(roomId: id, items: items, current: current);

  LiveProgram withCurrent(int? position) =>
      LiveProgram(roomId: roomId, items: items, current: position);
}
