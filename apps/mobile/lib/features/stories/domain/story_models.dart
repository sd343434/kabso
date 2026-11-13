// Wire models of the stories API (docs/contracts/openapi.yaml v1.5-social
// DRAFT, CP-008, CONVENTIONS §11.9). Hand-written `fromJson`, as the posts
// models: a body that does not match throws, which `guardApiCall` turns
// into an `UnexpectedFailure`.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// The longest story text (§11.9).
const int maxStoryText = 200;

/// `Story`: one photo for 24 hours.
@immutable
class Story {
  const new({
    required this.id,
    required this.author,
    required this.media,
    required this.text,
    required this.mentions,
    required this.createdAt,
    required this.expiresAt,
    required this.viewerHasSeen,
    required this.isSelf,
    this.viewCount,
  });

  factory fromJson(Map<String, dynamic> json) => Story(
    id: json['id']! as String,
    author: UserSummary.fromJson(json['author']! as Map<String, dynamic>),
    media: MediaAsset.fromJson(json['media']! as Map<String, dynamic>),
    text: json['text']! as String,
    mentions: [
      for (final m in json['mentions']! as List<dynamic>)
        UserSummary.fromJson(m as Map<String, dynamic>),
    ],
    createdAt: DateTime.parse(json['createdAt']! as String),
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    viewerHasSeen: json['viewerHasSeen']! as bool,
    isSelf: json['isSelf']! as bool,
    viewCount: json['viewCount'] as int?,
  );

  final String id;
  final UserSummary author;
  final MediaAsset media;
  final String text;
  final List<UserSummary> mentions;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewerHasSeen;
  final bool isSelf;

  /// Distinct viewers; the author only (`null` for everyone else).
  final int? viewCount;

  Story seen() => Story(
    id: id,
    author: author,
    media: media,
    text: text,
    mentions: mentions,
    createdAt: createdAt,
    expiresAt: expiresAt,
    viewerHasSeen: true,
    isSelf: isSelf,
    viewCount: viewCount,
  );
}

/// `StoryTrayItem`: one account in the tray.
@immutable
class StoryTrayItem {
  const new({
    required this.user,
    required this.storyCount,
    required this.hasUnseen,
    required this.latestAt,
  });

  factory fromJson(Map<String, dynamic> json) => StoryTrayItem(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    storyCount: json['storyCount']! as int,
    hasUnseen: json['hasUnseen']! as bool,
    latestAt: DateTime.parse(json['latestAt']! as String),
  );

  final UserSummary user;
  final int storyCount;
  final bool hasUnseen;
  final DateTime latestAt;
}
