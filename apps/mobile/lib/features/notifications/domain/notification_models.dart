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
  unknown('');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere(
    (t) => t.wire == value && t != unknown,
    orElse: () => unknown,
  );

  final String wire;

  /// No actor: the app or moderation told you (always on).
  bool get isSystem => this == postPublished || this == contentRemoved;
}

/// `NotificationTarget.type`.
enum NotificationTargetType {
  post('POST'),
  comment('COMMENT'),
  story('STORY'),
  user('USER');

  new(this.wire);

  factory fromWire(Object? value) => values.firstWhere((t) => t.wire == value);

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
  });

  factory fromJson(Map<String, dynamic> json) => NotificationTarget(
    type: NotificationTargetType.fromWire(json['type']),
    id: json['id']! as String,
    postId: json['postId'] as String?,
    thumbUrl: json['thumbUrl'] as String?,
    text: json['text'] as String?,
  );

  final NotificationTargetType type;

  /// A post, comment or story id, or a username for a
  /// [NotificationTargetType.user] target.
  final String id;

  /// For a comment: its post.
  final String? postId;

  /// The post or story photo (320 px), when it has one.
  final String? thumbUrl;

  /// A short excerpt (≤ 80 characters) of the comment or caption.
  final String? text;
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
      final Map<String, dynamic> t => NotificationTarget.fromJson(t),
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
  });

  factory fromJson(Map<String, dynamic> json) => NotificationSettings(
    likes: json['likes']! as bool,
    comments: json['comments']! as bool,
    mentions: json['mentions']! as bool,
    follows: json['follows']! as bool,
    reposts: json['reposts']! as bool,
  );

  final bool likes;

  /// Comments on your posts and replies to your comments.
  final bool comments;
  final bool mentions;
  final bool follows;
  final bool reposts;

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.likes == likes &&
      other.comments == comments &&
      other.mentions == mentions &&
      other.follows == follows &&
      other.reposts == reposts;

  @override
  int get hashCode => Object.hash(likes, comments, mentions, follows, reposts);
}

/// One switch of [NotificationSettings] (the wire field name).
enum NotificationSetting {
  likes,
  comments,
  mentions,
  follows,
  reposts;

  bool of(NotificationSettings s) => switch (this) {
    likes => s.likes,
    comments => s.comments,
    mentions => s.mentions,
    follows => s.follows,
    reposts => s.reposts,
  };

  NotificationSettings set(NotificationSettings s, {required bool on}) =>
      NotificationSettings(
        likes: this == likes ? on : s.likes,
        comments: this == comments ? on : s.comments,
        mentions: this == mentions ? on : s.mentions,
        follows: this == follows ? on : s.follows,
        reposts: this == reposts ? on : s.reposts,
      );
}
