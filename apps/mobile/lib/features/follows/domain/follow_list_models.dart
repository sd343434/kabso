// Follower and following lists (docs/contracts/openapi.yaml v1.25.2-live,
// D121: `listUserFollowers`, `listUserFollowing`, `FollowListItem`;
// v1.26.1-live, D125: `q`, `order`, `removeMyFollower`; CONVENTIONS §10.6).

import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:material_ui/material_ui.dart';

/// Which list of a user: who follows them, or whom they follow.
enum FollowListKind {
  followers('followers'),
  following('following');

  new(this.path);

  /// The path segment (and the route's `tab` query value).
  final String path;

  /// The kind named [value] (a route's `tab`), else [followers].
  static FollowListKind parse(String? value) =>
      value == following.path ? following : followers;
}

/// D125: the order of a list (`order`), by the follow's time.
enum FollowListOrder {
  /// The newest follow first (the server's default).
  newest('newest'),

  /// The oldest follow first.
  oldest('oldest');

  new(this.wire);

  final String wire;
}

/// `FollowListItem`: a `UserSummary` plus the reader's relation to it.
@immutable
class FollowListItem {
  const new({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isSelf,
    required this.isPrivate,
    required this.followedByMe,
    required this.followsMe,
    this.requestedByMe = false,
    this.premiumTier,
  });

  factory fromJson(Map<String, dynamic> json) => FollowListItem(
    id: json['id']! as String,
    username: json['username']! as String,
    displayName: json['displayName']! as String,
    avatarUrl: json['avatarUrl'] as String?,
    isSelf: json['isSelf'] as bool? ?? false,
    isPrivate: json['isPrivate'] as bool? ?? false,
    followedByMe: json['followedByMe'] as bool? ?? false,
    followsMe: json['followsMe'] as bool? ?? false,
    requestedByMe: json['requestedByMe'] as bool? ?? false,
    premiumTier: premiumTierFromJson(json['premiumTier']),
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  /// The row is the reader (no Follow control).
  final bool isSelf;

  /// A private account: v1.47-social (D175) a new follow is a request.
  final bool isPrivate;

  /// v1.47-social (D175): the reader asked to follow this private account
  /// and waits for an answer ("Requested").
  final bool requestedByMe;

  /// The reader follows this account.
  final bool followedByMe;

  /// This account follows the reader ("Follow back").
  final bool followsMe;

  /// v1.28-live (D146, via `UserSummary`): the premium username's tier, or
  /// null for a regular username (D158: shown without «@»).
  final PremiumTier? premiumTier;

  /// The name to show (the username when the display name is empty).
  String get name => displayName.isEmpty ? username : displayName;

  /// Whether a Follow / Following control may be shown.
  bool get canToggle => !isSelf;

  FollowListItem withFollowedByMe({
    required bool followedByMe,
    bool requestedByMe = false,
  }) => FollowListItem(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isSelf: isSelf,
    isPrivate: isPrivate,
    followedByMe: followedByMe,
    followsMe: followsMe,
    requestedByMe: requestedByMe,
    premiumTier: premiumTier,
  );
}
