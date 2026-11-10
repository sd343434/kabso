// D356 (CONVENTIONS §10.152): the panel's live preview of the event page.
//
// The admin panel embeds the Flutter-web preview bundle
// (`lib/preview_main.dart`) in an iframe and posts the draft event to it with
// `window.postMessage`. This file is the protocol and its pure parts (no
// `dart:js_interop`, so the VM tests run it):
//
//   panel → preview  {"type": "kabso.eventPreview.render", "v": 1, "seq": n,
//                     "language": "ar" | "en", "theme": "dark" | "light",
//                     "state": "UPCOMING" | "RUNNING" | "FINAL_HOUR" | "ENDED",
//                     "reduceMotion": bool, "event": <EventDetail JSON>}
//   preview → panel  {"type": "kabso.eventPreview.ready", "v": 1}
//                    {"type": "kabso.eventPreview.rendered", "v": 1, "seq": n,
//                     "designed": bool}
//                    {"type": "kabso.eventPreview.error", "v": 1, "seq": n?,
//                     "reason": "…"}
//
// Messages travel as JSON text. Only the allowed origins are listened to (the
// preview's own origin — the panel serves it — plus any compile-time
// `PREVIEW_PARENT_ORIGINS` for local development). `event` is the same shape as
// `GET /events/{id}` (`EventDetail`, including `design`); the preview never
// calls the API. The leaderboards are SAMPLE rows made here (labelled «بيانات
// تجريبية» on the page), never real users.

import 'dart:convert';

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';

const kPreviewRender = 'kabso.eventPreview.render';
const kPreviewReady = 'kabso.eventPreview.ready';
const kPreviewRendered = 'kabso.eventPreview.rendered';
const kPreviewError = 'kabso.eventPreview.error';
const kPreviewVersion = 1;

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
  });

  final int seq;

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
  return PreviewOk(
    PreviewRequest(
      seq: seq,
      event: detail,
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

/// The asset path of a sample photo (served next to the bundle; the page
/// loads it like any other URL).
String previewPhotoUrl(String name) => 'assets/assets/preview/$name.webp';

const _samplePhotos = [
  'avatar_layla',
  'avatar_karim',
  'avatar_rania',
  'avatar_omar',
  'avatar_huda',
];

const _namesAr = [
  'سارة',
  'خالد',
  'ليان',
  'عمر',
  'نورة',
  'أحمد',
  'ريم',
  'يوسف',
  'هدى',
  'كريم',
  'لمى',
  'زياد',
];
const _namesEn = [
  'Sara',
  'Khaled',
  'Layan',
  'Omar',
  'Noura',
  'Ahmed',
  'Reem',
  'Yousef',
  'Huda',
  'Karim',
  'Lama',
  'Ziad',
];

/// A SAMPLE board for the preview (12 made-up entrants, the sample photos on
/// the first five; the viewer at 8th) — never real users. [photos] off draws
/// Kabso's default picture (tests).
EventLeaderboard previewLeaderboard(
  EventBoardKind kind, {
  required bool ar,
  required bool ended,
  required int minPoints,
  bool photos = true,
}) {
  final names = ar ? _namesAr : _namesEn;
  UserSummary user(int i, [String suffix = '']) => UserSummary(
    id: 'sample-$i$suffix',
    username: 'sample$i$suffix',
    displayName: names[i % names.length],
    avatarUrl: photos && i < _samplePhotos.length
        ? previewPhotoUrl(_samplePhotos[i])
        : null,
  );
  final rows = [
    for (var i = 0; i < names.length; i++)
      GiftBoardRow(
        rank: i + 1,
        user: user(i),
        partner: kind == EventBoardKind.cp
            ? user(names.length - 1 - i, 'p')
            : null,
        isAgency: kind == EventBoardKind.agencies,
        agencyName: kind == EventBoardKind.agencies
            ? (ar ? 'وكالة ${names[i]}' : '${names[i]} Agency')
            : null,
        score: (8650000 / (i + 1) / (i + 1)).round() + minPoints,
        qualified: true,
        prize: const [],
      ),
  ];
  return EventLeaderboard(
    isFinal: ended,
    rows: const [],
    myRank: 8,
    myScore: rows[7].score,
    myPrize: 0,
    board: kind,
    minPoints: minPoints,
    myQualified: true,
    giftRows: rows,
  );
}

/// A message to the panel.
String previewReply(String type, {int? seq, bool? designed, String? reason}) =>
    jsonEncode({
      'type': type,
      'v': kPreviewVersion,
      'seq': ?seq,
      'designed': ?designed,
      'reason': ?reason,
    });
