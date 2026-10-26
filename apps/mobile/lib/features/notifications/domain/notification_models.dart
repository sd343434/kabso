// Wire models of the notifications API (docs/contracts/openapi.yaml
// v1.5-social DRAFT, CP-009, CONVENTIONS §11.10). Hand-written `fromJson`,
// as the posts models: a body that does not match throws, which
// `guardApiCall` turns into an `UnexpectedFailure`.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

/// `NotificationType`. [unknown] is a type a newer server added; the app
/// skips it.
enum NotificationType {
  likePost('LIKE_POST'),
  likeComment('LIKE_COMMENT'),
  comment('COMMENT'),
  reply('REPLY'),
  mention('MENTION'),
  follow('FOLLOW'),
  repost('REPOST'),
  postPublished('POST_PUBLISHED'),
  contentRemoved('CONTENT_REMOVED'),

  /// v1.14-live (CP-016 C): a host you follow goes live in about 15
  /// minutes (target: the host as a user, with the title and the start).
  liveScheduledSoon('LIVE_SCHEDULED_SOON'),

  /// v1.21-live (CP-018): someone sent you a CP request (target: them as a
  /// user).
  cpRequest('CP_REQUEST'),

  /// v1.21-live (CP-018): your CP request was accepted (target: the
  /// partner as a user).
  cpAccepted('CP_ACCEPTED'),

  /// v1.21-live (CP-018): your join request was accepted or declined
  /// (target: the family, its name as `text`; actor: who answered).
  familyJoinAccepted('FAMILY_JOIN_ACCEPTED'),
  familyJoinDeclined('FAMILY_JOIN_DECLINED'),

  /// v1.21-live (CP-018, system): you earned a medal (target: the medal
  /// code; its name and icon come from `GET /medals`).
  medalAwarded('MEDAL_AWARDED'),
  unknown('');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere(
    (t) => t.wire == value && t != unknown,
    orElse: () => unknown,
  );

  final String wire;

  /// No actor: the app or moderation told you (always on).
  bool get isSystem =>
      this == postPublished || this == contentRemoved || this == medalAwarded;
}

/// `NotificationTarget.type`.
enum NotificationTargetType {
  post('POST'),
  comment('COMMENT'),
  story('STORY'),
  user('USER'),

  /// v1.21-live (CP-018): a family (id; `text` its name).
  family('FAMILY'),

  /// v1.21-live (CP-018): a medal (its code as the id).
  medal('MEDAL');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere((t) => t.wire == value);

  /// Whether [value] is a target type this app knows (a newer server may
  /// add one; such a target is read as none rather than failing the page).
  static bool isKnown(Object? value) => values.any((t) => t.wire == value);

  final String wire;
}

/// `NotificationTarget`: what a notification points at.
@immutable
class NotificationTarget {
  const new({
    required this.type,
    required this.id,
    this.postId,
    this.thumbUrl,
    this.text,
    this.startsAt,
  });

  factory fromJson(Map<String, dynamic> json) => NotificationTarget(
    type: NotificationTargetType.fromWire(json['type']),
    id: json['id']! as String,
    postId: json['postId'] as String?,
    thumbUrl: json['thumbUrl'] as String?,
    text: json['text'] as String?,
    startsAt: switch (json['startsAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  final NotificationTargetType type;

  /// A post, comment or story id, a username for a
  /// [NotificationTargetType.user] target, a family id or a medal code.
  final String id;

  /// For a comment: its post.
  final String? postId;

  /// The post or story photo (320 px), when it has one.
  final String? thumbUrl;

  /// A short excerpt (≤ 80 characters) of the comment or caption, or the
  /// scheduled live's title.
  final String? text;

  /// [NotificationType.liveScheduledSoon]: when the live is planned.
  final DateTime? startsAt;
}

/// `Notification`. Likes and reposts on one item group while unread
/// ([actors] are the latest three, [actorCount] all of them).
@immutable
class AppNotification {
  const new({
    required this.id,
    required this.type,
    required this.actors,
    required this.actorCount,
    required this.target,
    required this.createdAt,
    required this.read,
  });

  factory fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id']! as String,
    type: NotificationType.fromWire(json['type']),
    actors: [
      for (final a in json['actors']! as List<dynamic>)
        UserSummary.fromJson(a as Map<String, dynamic>),
    ],
    actorCount: json['actorCount']! as int,
    target: switch (json['target']) {
      final Map<String, dynamic> t
          when NotificationTargetType.isKnown(t['type']) =>
        NotificationTarget.fromJson(t),
      _ => null,
    },
    createdAt: DateTime.parse(json['createdAt']! as String),
    read: json['read']! as bool,
  );

  final String id;
  final NotificationType type;
  final List<UserSummary> actors;
  final int actorCount;
  final NotificationTarget? target;

  /// The latest activity in the group.
  final DateTime createdAt;
  final bool read;

  AppNotification asRead() => AppNotification(
    id: id,
    type: type,
    actors: actors,
    actorCount: actorCount,
    target: target,
    createdAt: createdAt,
    read: true,
  );
}

/// `NotificationSettings`: each switch is on until changed.
@immutable
class NotificationSettings {
  const new({
    this.likes = true,
    this.comments = true,
    this.mentions = true,
    this.follows = true,
    this.reposts = true,
    this.lives = true,
  });

  factory fromJson(Map<String, dynamic> json) => NotificationSettings(
    likes: json['likes']! as bool,
    comments: json['comments']! as bool,
    mentions: json['mentions']! as bool,
    follows: json['follows']! as bool,
    reposts: json['reposts']! as bool,
    // v1.14-live; an older server does not send it (on).
    lives: json['lives'] as bool? ?? true,
  );

  final bool likes;

  /// Comments on your posts and replies to your comments.
  final bool comments;
  final bool mentions;
  final bool follows;
  final bool reposts;

  /// Reminders of lives scheduled by hosts you follow (CP-016 C).
  final bool lives;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.likes == likes &&
      other.comments == comments &&
      other.mentions == mentions &&
      other.follows == follows &&
      other.reposts == reposts &&
      other.lives == lives;

  @override
  int get hashCode =>
      Object.hash(likes, comments, mentions, follows, reposts, lives);
}

/// One switch of [NotificationSettings] (the wire field name).
enum NotificationSetting {
  likes,
  comments,
  mentions,
  follows,
  reposts,
  lives;

  bool of(NotificationSettings s) => switch (this) {
    likes => s.likes,
    comments => s.comments,
    mentions => s.mentions,
    follows => s.follows,
    reposts => s.reposts,
    lives => s.lives,
  };

  NotificationSettings set(NotificationSettings s, {required bool on}) =>
      NotificationSettings(
        likes: this == likes ? on : s.likes,
        comments: this == comments ? on : s.comments,
        mentions: this == mentions ? on : s.mentions,
        follows: this == follows ? on : s.follows,
        reposts: this == reposts ? on : s.reposts,
        lives: this == lives ? on : s.lives,
      );
}
