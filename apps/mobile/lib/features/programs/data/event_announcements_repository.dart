import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';

// v1.105-social (D340, CONVENTIONS §10.134.2): the full-screen event
// announcements — an event the person may join has started, or the person
// won a prize. The server decides who sees what and keeps «seen».

/// `EventAnnouncement.kind`.
enum EventAnnouncementKind {
  start('EVENT_START'),
  win('EVENT_WIN');

  new(this.wire);

  final String wire;

  static EventAnnouncementKind? fromWire(Object? wire) =>
      values.where((k) => k.wire == wire).firstOrNull;
}

/// `EventAnnouncement`: one full-screen announcement.
@immutable
final class EventAnnouncement {
  const new({
    required this.id,
    required this.kind,
    required this.event,
    this.titleUrl,
    this.backgroundUrl,
    this.prize = const [],
    this.board,
    this.rank,
  });

  /// Null for a kind this app does not know (it is skipped, not marked).
  static EventAnnouncement? fromJson(Map<String, dynamic> json) {
    final kind = EventAnnouncementKind.fromWire(json['kind']);
    if (kind == null) return null;
    return EventAnnouncement(
      id: json['id']! as String,
      kind: kind,
      event: EventSummary.fromJson(json['event']! as Map<String, dynamic>),
      titleUrl: json['titleUrl'] as String?,
      backgroundUrl: json['backgroundUrl'] as String?,
      prize: [
        for (final item in (json['prize'] as List<dynamic>?) ?? const [])
          EventPrizeItem.fromJson(item as Map<String, dynamic>),
      ],
      board: EventBoardKind.fromWire(json['board']),
      rank: (json['rank'] as num?)?.toInt(),
    );
  }

  /// `start_<eventId>` or `win_<payoutId>`.
  final String id;
  final EventAnnouncementKind kind;
  final EventSummary event;

  /// The event's uploaded title art and page background (a still), if any.
  final String? titleUrl;
  final String? backgroundUrl;

  /// START: the key prize (the first board's rank 1); WIN: the bundle won.
  final List<EventPrizeItem> prize;

  /// WIN: the board and the final rank.
  final EventBoardKind? board;
  final int? rank;
}

/// `getEventAnnouncements` / `markEventAnnouncementSeen`.
abstract interface class EventAnnouncementsRepository {
  /// The announcements not seen yet (wins first), at most 10.
  Future<List<EventAnnouncement>> pending();

  /// Idempotent.
  Future<void> markSeen(String announcementId);
}

class EventAnnouncementsRepositoryImpl implements EventAnnouncementsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<EventAnnouncement>> pending() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/events/announcements');
    return [
      for (final item in res.data!['data']! as List<dynamic>)
        ?EventAnnouncement.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> markSeen(String announcementId) => guardApiCall(() async {
    await _dio.post<void>(
      '/events/announcements/${Uri.encodeComponent(announcementId)}/seen',
    );
  });
}

final eventAnnouncementsRepositoryProvider =
    Provider<EventAnnouncementsRepository>(
      (ref) => EventAnnouncementsRepositoryImpl(ref.watch(apiDioProvider)),
    );
