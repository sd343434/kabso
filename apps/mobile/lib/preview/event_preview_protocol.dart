// D356 (CONVENTIONS §10.152): the panel's live preview of the event page.
//
// The admin panel embeds the Flutter-web preview bundle
// (`lib/preview_main.dart`) in an iframe and posts the draft event to it with
// `window.postMessage`. This file is the protocol and its pure parts (no
// `dart:js_interop`, so the VM tests run it):
//
//   panel → preview  {"type": "kabso.eventPreview.render", "v": 2, "seq": n,
//                     "language": "ar" | "en", "theme": "dark" | "light",
//                     "state": "UPCOMING" | "RUNNING" | "FINAL_HOUR" | "ENDED",
//                     "reduceMotion": bool, "event": <EventDetail JSON>,
//                     "leaderboards": {"SENDERS": <EventLeaderboard JSON>, …}}
//   preview → panel  {"type": "kabso.eventPreview.ready", "v": 2}
//                    {"type": "kabso.eventPreview.rendered", "v": 2, "seq": n,
//                     "designed": bool}
//                    {"type": "kabso.eventPreview.error", "v": 2, "seq": n?,
//                     "reason": "…"}
//
// Messages travel as JSON text. Only the allowed origins are listened to (the
// preview's own origin — the panel serves it — plus any compile-time
// `PREVIEW_PARENT_ORIGINS` for local development). `event` is the same shape as
// `GET /events/{id}` (`EventDetail`, including `design`); the preview never
// calls the API. The leaderboards are the panel's SAMPLE rows (its labelled
// sample-data module, apps/admin/src/event-preview-sample.ts), read with the
// app's own `EventLeaderboard.fromJson` — the page says «بيانات تجريبية».
// v2 (D356 follow-up): the leaderboards moved from here to the message.

import 'dart:convert';

import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';

const kPreviewRender = 'kabso.eventPreview.render';
const kPreviewReady = 'kabso.eventPreview.ready';
const kPreviewRendered = 'kabso.eventPreview.rendered';
const kPreviewError = 'kabso.eventPreview.error';
const kPreviewVersion = 2;

/// The event id the preview uses when the draft has none yet.
const kPreviewEventId = 'preview';

/// The lifecycle moment the panel asks to see (the dates are moved around
/// "now" so the countdown shows it; the event's real dates are not used).
enum PreviewState {
  upcoming('UPCOMING'),
  running('RUNNING'),
  finalHour('FINAL_HOUR'),
  ended('ENDED');

  new(this.wire);

  final String wire;

  static PreviewState? fromWire(Object? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// One render request from the panel.
final class PreviewRequest {
  const new({
    required this.seq,
    required this.event,
    required this.language,
    required this.dark,
    required this.state,
    required this.reduceMotion,
    this.leaderboards = const {},
  });

  final int seq;

  /// The panel's sample boards, by board (a board it sent none for is
  /// empty).
  final Map<EventBoardKind, EventLeaderboard> leaderboards;

  /// The parsed event with the [state]'s dates.
  final EventDetail event;
  final AppLanguage language;
  final bool dark;
  final PreviewState state;
  final bool reduceMotion;
}

/// The outcome of one incoming message.
sealed class PreviewParse {
  const new();
}

/// A render request to draw.
final class PreviewOk extends PreviewParse {
  const new(this.request);

  final PreviewRequest request;
}

/// Not for us (another origin, another message type): dropped silently.
final class PreviewIgnored extends PreviewParse {
  const new(this.reason);

  final String reason;
}

/// For us but unusable: reported back to the panel, the last page stays.
final class PreviewInvalid extends PreviewParse {
  const new(this.reason, {this.seq});

  final String reason;
  final int? seq;
}

/// The origins the preview listens to: its own and the build's
/// `PREVIEW_PARENT_ORIGINS` (comma-separated, development only).
Set<String> previewAllowedOrigins(String own, String extra) => {
  if (own.isNotEmpty && own != 'null') own,
  for (final o in extra.split(','))
    if (o.trim().isNotEmpty) o.trim(),
};

/// Parses a message's [data] sent from [origin]. [now] places the dates.
PreviewParse parsePreviewMessage(
  Object? data, {
  required String origin,
  required Set<String> allowedOrigins,
  required DateTime now,
}) {
  if (!allowedOrigins.contains(origin)) {
    return const PreviewIgnored('origin');
  }
  if (data is! String) return const PreviewIgnored('not text');
  final Object? json;
  try {
    json = jsonDecode(data);
  } on FormatException {
    return const PreviewInvalid('not JSON');
  }
  if (json is! Map<String, dynamic>) {
    return const PreviewInvalid('not an object');
  }
  if (json['type'] != kPreviewRender) return const PreviewIgnored('type');
  final seq = json['seq'] is int ? json['seq'] as int : 0;
  if (json['v'] != kPreviewVersion) {
    return PreviewInvalid('version ${json['v']}', seq: seq);
  }
  final event = json['event'];
  if (event is! Map<String, dynamic>) {
    return PreviewInvalid('no event', seq: seq);
  }
  final state = PreviewState.fromWire(json['state']) ?? PreviewState.running;
  final EventDetail detail;
  try {
    detail = EventDetail.fromJson(
      previewEventJson(event, state: state, now: now),
    );
  } on Object catch (e) {
    return PreviewInvalid('event: ${e.runtimeType}', seq: seq);
  }
  final boards = <EventBoardKind, EventLeaderboard>{};
  final rawBoards = json['leaderboards'];
  if (rawBoards != null && rawBoards is! Map<String, dynamic>) {
    return PreviewInvalid('leaderboards', seq: seq);
  }
  try {
    for (final MapEntry(:key, :value)
        in (rawBoards as Map<String, dynamic>? ?? const {}).entries) {
      final kind = EventBoardKind.fromWire(key);
      if (kind == null || value is! Map<String, dynamic>) continue;
      boards[kind] = EventLeaderboard.fromJson(value);
    }
  } on Object catch (e) {
    return PreviewInvalid('leaderboards: ${e.runtimeType}', seq: seq);
  }
  return PreviewOk(
    PreviewRequest(
      seq: seq,
      event: detail,
      leaderboards: boards,
      language: json['language'] == 'en' ? AppLanguage.en : AppLanguage.ar,
      dark: json['theme'] != 'light',
      state: state,
      reduceMotion: json['reduceMotion'] == true,
    ),
  );
}

/// [event] with the dates and status of [state] around [now] (a permanent
/// event keeps no end until it is shown ended).
Map<String, dynamic> previewEventJson(
  Map<String, dynamic> event, {
  required PreviewState state,
  required DateTime now,
}) {
  final permanent = event['permanent'] == true;
  String at(Duration d) => now.toUtc().add(d).toIso8601String();
  final (start, end, status) = switch (state) {
    PreviewState.upcoming => (
      const Duration(days: 2, hours: 3),
      const Duration(days: 9, hours: 3),
      'UPCOMING',
    ),
    PreviewState.running => (
      const Duration(days: -2),
      const Duration(days: 3, hours: 5, minutes: 20),
      'RUNNING',
    ),
    PreviewState.finalHour => (
      const Duration(days: -7),
      const Duration(minutes: 42),
      'RUNNING',
    ),
    PreviewState.ended => (
      const Duration(days: -7),
      const Duration(hours: -2),
      'ENDED',
    ),
  };
  return {
    ...event,
    'id': event['id'] is String && (event['id'] as String).isNotEmpty
        ? event['id']
        : kPreviewEventId,
    'startsAt': at(start),
    'endsAt': permanent && state != PreviewState.ended ? null : at(end),
    'status': status,
    'metric': event['metric'] ?? 'EVENT_GIFTS',
    'prizes': event['prizes'] ?? const <Object?>[],
    'frozenAt': state == PreviewState.ended
        ? at(const Duration(hours: -2))
        : null,
  };
}

/// An empty board (`EventLeaderboard` JSON, read like the API's) for a board
/// the panel sent no sample for.
EventLeaderboard previewEmptyBoard(
  EventBoardKind kind, {
  required bool ended,
  required int minPoints,
}) => EventLeaderboard.fromJson({
  'board': kind.wire,
  'minPoints': minPoints,
  'final': ended,
  'data': const <Object?>[],
  'me': const {'rank': null, 'score': 0, 'prizeCoins': 0, 'prize': <Object?>[]},
});

/// A message to the panel.
String previewReply(String type, {int? seq, bool? designed, String? reason}) =>
    jsonEncode({
      'type': type,
      'v': kPreviewVersion,
      'seq': ?seq,
      'designed': ?designed,
      'reason': ?reason,
    });
