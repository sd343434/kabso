import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// `LiveRoomStats` (v1.27.6-live, D140, CONVENTIONS §10.31): the host's own
/// statistics of one live — `GET /live/rooms/{roomId}/stats`. Aggregates
/// only; nothing says who watched from where.
@immutable
final class LiveRoomStats {
  const new({
    required this.roomId,
    required this.ended,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.total,
    required this.tapPoints,
    required this.supportPoints,
    required this.hostOwnPoints,
    required this.supporters,
    required this.topSupporters,
    required this.giftCount,
    required this.chatMessages,
    required this.newFollowers,
    required this.viewers,
    required this.viewerCountries,
    this.giftCoins = 0,
    this.earningsCoins = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    final score = json['score']! as Map<String, dynamic>;
    final viewers = json['viewers'] as Map<String, dynamic>?;
    return LiveRoomStats(
      roomId: json['roomId']! as String,
      ended: json['status'] == 'ENDED',
      startedAt: DateTime.parse(json['startedAt']! as String),
      endedAt: switch (json['endedAt']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
      duration: Duration(seconds: _int(json['durationSeconds'])),
      total: _int(score['total']),
      tapPoints: _int(score['tapPoints']),
      supportPoints: _int(score['supportPoints']),
      hostOwnPoints: _int(json['hostOwnPoints']),
      supporters: _int(json['supporters']),
      topSupporters: [
        for (final s in json['topSupporters']! as List<dynamic>)
          LiveStatsSupporter.fromJson(s as Map<String, dynamic>),
      ],
      giftCount: _int(json['giftCount']),
      // v1.35-live (D154d): absent from an older server → 0.
      giftCoins: json['giftCoins'] == null ? 0 : _int(json['giftCoins']),
      earningsCoins: json['earningsCoins'] == null
          ? 0
          : _int(json['earningsCoins']),
      chatMessages: _int(json['chatMessages']),
      newFollowers: _int(json['newFollowers']),
      viewers: viewers == null ? null : LiveViewerStats.fromJson(viewers),
      viewerCountries: [
        for (final c in json['viewerCountries']! as List<dynamic>)
          LiveViewerCountry.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  final String roomId;

  /// `status` is `ENDED` (else the live is still on).
  final bool ended;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// From the start to the end (or now while live).
  final Duration duration;

  /// The live's cherries (`score.total`): taps + 100 a counted gift coin.
  final int total;
  final int tapPoints;
  final int supportPoints;

  /// The host's own taps and gifts in [total] (the host is not their own
  /// supporter, so [supporters] leaves them out).
  final int hostOwnPoints;

  /// Everyone else who gave this live points (taps or gifts).
  final int supporters;

  /// The first three of the Contribution list.
  final List<LiveStatsSupporter> topSupporters;

  /// Gifts sent in the live (the sum of quantities), the host's included.
  final int giftCount;

  /// v1.35-live (D154d): the gifts' value in coins, and the host's share
  /// of those they received (display only; 0 from an older server).
  final int giftCoins;
  final int earningsCoins;
  final int chatMessages;

  /// People who started following the host during the live and still do.
  final int newFollowers;

  /// `null` for a live from before the audience was recorded (D140).
  final LiveViewerStats? viewers;

  /// Up to five countries, then `OTHER` and `UNKNOWN`; empty without
  /// viewers.
  final List<LiveViewerCountry> viewerCountries;
}

/// `LiveRoomViewerStats` (D140).
@immutable
final class LiveViewerStats {
  const new({
    required this.unique,
    required this.guests,
    required this.peak,
    required this.atEnd,
    required this.averageWatch,
  });

  factory fromJson(Map<String, dynamic> json) => LiveViewerStats(
    unique: _int(json['unique']),
    guests: _int(json['guests']),
    peak: _int(json['peak']),
    atEnd: _int(json['atEnd']),
    averageWatch: Duration(seconds: _int(json['averageWatchSeconds'])),
  );

  /// Different people (and guests) who watched, the host left out.
  final int unique;
  final int guests;

  /// The most watching at once.
  final int peak;

  /// Watching when it ended (now, while live).
  final int atEnd;
  final Duration averageWatch;
}

/// One `LiveViewerCountry` bucket (D140).
@immutable
final class LiveViewerCountry {
  const new({
    required this.country,
    required this.viewers,
    required this.percent,
  });

  factory fromJson(Map<String, dynamic> json) => LiveViewerCountry(
    country: json['country']! as String,
    viewers: _int(json['viewers']),
    percent: (json['percent']! as num).toDouble(),
  );

  static const other = 'OTHER';
  static const unknown = 'UNKNOWN';

  /// An ISO 3166-1 alpha-2 code, [other] or [unknown].
  final String country;
  final int viewers;

  /// Of the unique viewers, one decimal (rounded on its own).
  final double percent;
}

/// One of `LiveRoomStats.topSupporters`.
@immutable
final class LiveStatsSupporter {
  const new({required this.user, required this.points});

  factory fromJson(Map<String, dynamic> json) => LiveStatsSupporter(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    points: _int(json['points']),
  );

  final UserSummary user;
  final int points;
}

int _int(Object? v) => (v! as num).toInt();
