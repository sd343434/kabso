import 'package:flutter/foundation.dart';
import 'package:kabso_live/core/models/shared_models.dart';

/// v1.114-live (D363, CONVENTIONS §10.157): the video podcast's own wire
/// types — the director's shot (relayed by the host, `podcast` topic) and
/// a question's upvotes.

/// The director's shots (`LivePodcastDirectorShot.shot`).
enum PodcastShotKind {
  /// One person full screen, the others as side thumbnails.
  speaker('SPEAKER'),

  /// Two people alternating: top / bottom.
  split('SPLIT'),

  /// Three or more at once: everyone, briefly.
  grid('GRID'),

  /// The hot seat's question card.
  hotSeat('HOT_SEAT');

  new(this.wire);

  final String wire;

  static PodcastShotKind? parse(Object? raw) {
    for (final k in values) {
      if (k.wire == raw) return k;
    }
    return null;
  }
}

/// A shot: what everyone sees. [userIds] are the people on screen, the
/// main one first; [locked] = the host pinned it; [seq] increases with each
/// change (an older one is dropped).
@immutable
class PodcastDirectorShot {
  const new({
    required this.kind,
    required this.userIds,
    this.locked = false,
    this.seq = 0,
  });

  final PodcastShotKind kind;
  final List<String> userIds;
  final bool locked;
  final int seq;

  /// The main person (the speaker shot's, the split's top).
  String? get main => userIds.isEmpty ? null : userIds.first;

  /// The same picture (kind and people), whatever the sequence.
  bool sameAs(PodcastDirectorShot other) =>
      kind == other.kind &&
      locked == other.locked &&
      listEquals(userIds, other.userIds);

  PodcastDirectorShot copyWith({
    PodcastShotKind? kind,
    List<String>? userIds,
    bool? locked,
    int? seq,
  }) => PodcastDirectorShot(
    kind: kind ?? this.kind,
    userIds: userIds ?? this.userIds,
    locked: locked ?? this.locked,
    seq: seq ?? this.seq,
  );

  Map<String, dynamic> toJson() => {
    'shot': kind.wire,
    'userIds': userIds,
    'locked': locked,
    'seq': seq,
  };

  @override
  bool operator ==(Object other) =>
      other is PodcastDirectorShot && sameAs(other) && seq == other.seq;

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(userIds), locked, seq);

  @override
  String toString() =>
      'PodcastDirectorShot(${kind.wire}, $userIds, locked: $locked, #$seq)';
}

/// A `podcast` topic data message (§10.157).
sealed class PodcastEvent {
  const new();

  /// `{"type":"director",…}` / `{"type":"question-votes",…}`, else null.
  static PodcastEvent? parse(Object? message) {
    if (message is! Map) return null;
    switch (message['type']) {
      case 'director':
        final kind = PodcastShotKind.parse(message['shot']);
        final ids = message['userIds'];
        final seq = message['seq'];
        if (kind == null || ids is! List || seq is! int) return null;
        return PodcastDirectorEvent(
          PodcastDirectorShot(
            kind: kind,
            userIds: [for (final id in ids) '$id'],
            locked: message['locked'] == true,
            seq: seq,
          ),
        );
      case 'question-votes':
        final id = message['requestId'];
        final votes = message['votes'];
        if (id is! String || votes is! int) return null;
        return PodcastVotesEvent(requestId: id, votes: votes);
      case 'studio':
        final studio = message['studio'];
        if (studio is! Map) return null;
        try {
          return PodcastStudioEvent(
            LivePodcastStudio.fromJson(Map<String, dynamic>.from(studio)),
          );
        } on Object {
          return null;
        }
    }
    return null;
  }
}

/// v1.114-live (D363 scope extension): the studio changed (the whole
/// state; an older `seq` is dropped).
final class PodcastStudioEvent extends PodcastEvent {
  const new(this.studio);

  final LivePodcastStudio studio;
}

/// The host's director chose [shot].
final class PodcastDirectorEvent extends PodcastEvent {
  const new(this.shot);

  final PodcastDirectorShot shot;
}

/// A question's upvotes changed.
final class PodcastVotesEvent extends PodcastEvent {
  const new({required this.requestId, required this.votes});

  final String requestId;
  final int votes;
}

/// `LivePodcastQuestionVotes`.
@immutable
class LivePodcastQuestionVotes {
  const new({
    required this.requestId,
    required this.votes,
    required this.votedByMe,
  });

  factory fromJson(Map<String, dynamic> json) => LivePodcastQuestionVotes(
    requestId: json['requestId']! as String,
    votes: json['votes']! as int,
    votedByMe: json['votedByMe'] == true,
  );

  final String requestId;
  final int votes;
  final bool votedByMe;
}

/// `LivePodcastSegment` (v1.114-live, D363 scope extension): one segment
/// «فقرة» of an episode — a title (1–40 characters) and optional planned
/// minutes.
@immutable
class LivePodcastSegment {
  const new({required this.title, this.minutes});

  factory fromJson(Map<String, dynamic> json) => LivePodcastSegment(
    title: json['title']! as String,
    minutes: json['minutes'] as int?,
  );

  /// At most this many segments in an episode.
  static const max = 8;

  /// A title's length in characters.
  static const titleMax = 40;

  final String title;
  final int? minutes;

  Map<String, dynamic> toJson() => {'title': title, 'minutes': ?minutes};

  @override
  bool operator ==(Object other) =>
      other is LivePodcastSegment &&
      other.title == title &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(title, minutes);
}

/// `LivePodcastOnScreen`: the listener question shown over the video.
@immutable
class LivePodcastOnScreen {
  const new({
    required this.requestId,
    required this.user,
    required this.question,
    this.answerUserId,
  });

  factory fromJson(Map<String, dynamic> json) => LivePodcastOnScreen(
    requestId: json['requestId']! as String,
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    question: json['question']! as String,
    answerUserId: json['answerUserId'] as String?,
  );

  final String requestId;
  final UserSummary user;
  final String question;

  /// Who answers: the director prefers their shot while the card is up.
  final String? answerUserId;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'user': user.toJson(),
    'question': question,
    'answerUserId': answerUserId,
  };

  @override
  bool operator ==(Object other) =>
      other is LivePodcastOnScreen &&
      other.requestId == requestId &&
      other.user == user &&
      other.question == question &&
      other.answerUserId == answerUserId;

  @override
  int get hashCode => Object.hash(requestId, user, question, answerUserId);
}

/// `LivePodcastStudio` (v1.114-live, D363 scope extension): a video
/// podcast's studio — the host's manual control ([pinUserId], [layout];
/// both null = «تلقائي»), the segments and the current one, the closing
/// card and the question on screen. [seq] grows with each change.
@immutable
class LivePodcastStudio {
  const new({
    this.seq = 0,
    this.pinUserId,
    this.layout,
    this.segments = const [],
    this.segmentIndex,
    this.segmentStartedAt,
    this.closing = false,
    this.onScreen,
  });

  factory fromJson(Map<String, dynamic> json) => LivePodcastStudio(
    seq: json['seq'] as int? ?? 0,
    pinUserId: json['pinUserId'] as String?,
    layout: PodcastShotKind.parse(json['layout']),
    segments: [
      for (final g in json['segments'] as List<dynamic>? ?? const [])
        LivePodcastSegment.fromJson(Map<String, dynamic>.from(g as Map)),
    ],
    segmentIndex: json['segmentIndex'] as int?,
    segmentStartedAt: switch (json['segmentStartedAt']) {
      final String at => DateTime.tryParse(at),
      _ => null,
    },
    closing: json['closing'] == true,
    onScreen: switch (json['onScreen']) {
      final Map<dynamic, dynamic> m => LivePodcastOnScreen.fromJson(
        Map<String, dynamic>.from(m),
      ),
      _ => null,
    },
  );

  final int seq;
  final String? pinUserId;

  /// SPEAKER / SPLIT / HOT_SEAT kept by the host; null = automatic.
  final PodcastShotKind? layout;
  final List<LivePodcastSegment> segments;
  final int? segmentIndex;
  final DateTime? segmentStartedAt;
  final bool closing;
  final LivePodcastOnScreen? onScreen;

  /// Neither a pinned person nor a locked layout: «تلقائي».
  bool get automatic => pinUserId == null && layout == null;

  /// The current segment, or null (not started, none).
  LivePodcastSegment? get segment {
    final i = segmentIndex;
    return i == null || i < 0 || i >= segments.length ? null : segments[i];
  }

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'pinUserId': pinUserId,
    'layout': layout?.wire,
    'segments': [for (final g in segments) g.toJson()],
    'segmentIndex': segmentIndex,
    'segmentStartedAt': segmentStartedAt?.toUtc().toIso8601String(),
    'closing': closing,
    'onScreen': onScreen?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is LivePodcastStudio &&
      other.seq == seq &&
      other.pinUserId == pinUserId &&
      other.layout == layout &&
      listEquals(other.segments, segments) &&
      other.segmentIndex == segmentIndex &&
      other.segmentStartedAt == segmentStartedAt &&
      other.closing == closing &&
      other.onScreen == onScreen;

  @override
  int get hashCode => Object.hash(
    seq,
    pinUserId,
    layout,
    Object.hashAll(segments),
    segmentIndex,
    segmentStartedAt,
    closing,
    onScreen,
  );
}
