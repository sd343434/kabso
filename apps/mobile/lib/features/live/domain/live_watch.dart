import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/shared_models.dart';

/// `LiveWatchVideo` (v1.38-live, D154i, CONVENTIONS §10.39).
@immutable
final class LiveWatchVideo {
  const new({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.channel,
  });

  factory fromJson(Map<String, dynamic> json) => LiveWatchVideo(
    videoId: json['videoId']! as String,
    title: json['title']! as String,
    channel: json['channel'] as String?,
    thumbnailUrl: json['thumbnailUrl']! as String,
  );

  final String videoId;
  final String title;
  final String? channel;
  final String thumbnailUrl;

  @override
  bool operator ==(Object other) =>
      other is LiveWatchVideo &&
      other.videoId == videoId &&
      other.title == title &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(videoId, title, channel);
}

/// `LiveWatch`: what a live watches together, and when the server said so.
@immutable
final class LiveWatch {
  const new({
    required this.roomId,
    required this.playing,
    required this.positionMs,
    required this.serverTime,
    this.video,
    this.updatedAt,
    this.searchEnabled = false,
  });

  factory fromJson(Map<String, dynamic> json) => LiveWatch(
    roomId: json['roomId']! as String,
    video: switch (json['video']) {
      final Map<String, dynamic> v => LiveWatchVideo.fromJson(v),
      _ => null,
    },
    playing: json['playing']! as bool,
    positionMs: (json['positionMs']! as num).toInt(),
    updatedAt: switch (json['updatedAt']) {
      final String t => DateTime.parse(t),
      _ => null,
    },
    serverTime: DateTime.parse(json['serverTime']! as String),
    searchEnabled: json['searchEnabled'] as bool? ?? false,
  );

  final String roomId;
  final LiveWatchVideo? video;
  final bool playing;
  final int positionMs;
  final DateTime? updatedAt;
  final DateTime serverTime;
  final bool searchEnabled;

  /// Where the video is [since] after this state arrived (the server's
  /// clock places `positionMs`; this phone's clock adds the rest).
  int positionAfter(Duration since) {
    if (!playing) return positionMs;
    final at = updatedAt;
    final lag = at == null ? Duration.zero : serverTime.difference(at);
    final ms = positionMs + lag.inMilliseconds + since.inMilliseconds;
    return ms < 0 ? 0 : ms;
  }
}

/// `LiveWatchSuggestion`: a viewer's suggestion.
@immutable
final class LiveWatchSuggestion {
  const new({
    required this.id,
    required this.roomId,
    required this.video,
    required this.suggester,
    required this.status,
  });

  factory fromJson(Map<String, dynamic> json) => LiveWatchSuggestion(
    id: json['id']! as String,
    roomId: json['roomId']! as String,
    video: LiveWatchVideo.fromJson(json['video']! as Map<String, dynamic>),
    suggester: UserSummary.fromJson(json['suggester']! as Map<String, dynamic>),
    status: json['status']! as String,
  );

  final String id;
  final String roomId;
  final LiveWatchVideo video;
  final UserSummary suggester;

  /// PENDING, APPROVED or REJECTED.
  final String status;
}

/// The 11-character YouTube id of [input] (an id or a YouTube link), as the
/// server reads it; null otherwise.
String? youtubeVideoId(String input) {
  final id = RegExp(r'^[A-Za-z0-9_-]{11}$');
  final text = input.trim();
  if (id.hasMatch(text)) return text;
  final uri = Uri.tryParse(
    RegExp('^https?://', caseSensitive: false).hasMatch(text)
        ? text
        : 'https://$text',
  );
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst(
    RegExp(r'^(www|m|music)\.'),
    '',
  );
  String? found;
  if (host == 'youtu.be') {
    found = uri.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (parts.firstOrNull == 'watch') {
      found = uri.queryParameters['v'];
    } else if (const {
      'shorts',
      'embed',
      'live',
      'v',
    }.contains(parts.firstOrNull)) {
      found = parts.length > 1 ? parts[1] : null;
    }
  }
  return found != null && id.hasMatch(found) ? found : null;
}
