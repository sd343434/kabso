import 'package:flutter/foundation.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// D386 (v1.138-social, CONVENTIONS §10.175): the wire models of a profile
/// page per account category — the featured section, the person's pins and
/// «طلب توثيق الفئة». Unknown enum values read as nothing (an older app
/// never breaks on a newer server).

/// `ProfileFeatured.source`.
enum FeaturedSource { pinned, auto, none }

/// `LiveScheduleSlot` as the PROGRAM section lists it.
@immutable
class FeaturedScheduleItem {
  const new({
    required this.id,
    required this.title,
    required this.startsAt,
    this.podcast = false,
    this.video = false,
  });

  factory fromJson(Map<String, dynamic> json) => FeaturedScheduleItem(
    id: json['id']! as String,
    title: json['title']! as String,
    startsAt: DateTime.parse(json['startsAt']! as String),
    podcast: json['mode'] == 'PODCAST',
    video: json['podcastVideo'] == true,
  );

  final String id;
  final String title;
  final DateTime startsAt;

  /// An announced podcast episode.
  final bool podcast;

  /// A video podcast episode.
  final bool video;
}

/// `ProfileFeatured`: the section under a verified category's header.
@immutable
class ProfileFeatured {
  const new({
    this.section,
    this.source = FeaturedSource.none,
    this.items = const [],
    this.schedule = const [],
  });

  factory fromJson(Map<String, dynamic> json) => ProfileFeatured(
    section: FeaturedSection.fromWire(json['section']),
    source: switch (json['source']) {
      'PINNED' => FeaturedSource.pinned,
      'AUTO' => FeaturedSource.auto,
      _ => FeaturedSource.none,
    },
    items: [
      for (final p in json['items'] as List<dynamic>? ?? const [])
        Post.fromJson(p as Map<String, dynamic>),
    ],
    schedule: [
      for (final s in json['schedule'] as List<dynamic>? ?? const [])
        FeaturedScheduleItem.fromJson(s as Map<String, dynamic>),
    ],
  );

  static const empty = ProfileFeatured();

  /// Null: no section (not verified, no section for the category, a Kabso
  /// Team account, or a value this app does not know).
  final FeaturedSection? section;
  final FeaturedSource source;
  final List<Post> items;
  final List<FeaturedScheduleItem> schedule;

  bool get isEmpty => items.isEmpty && schedule.isEmpty;
}

/// `FeaturedPinList`: the caller's pins, in order.
@immutable
class FeaturedPinList {
  const new(this.postIds, {this.max = 6});

  factory fromJson(Map<String, dynamic> json) => FeaturedPinList([
    for (final id in json['postIds']! as List<dynamic>) id as String,
  ], max: json['max'] as int? ?? 6);

  final List<String> postIds;
  final int max;

  bool contains(String postId) => postIds.contains(postId);
}

/// `CategoryRequestStatus`.
enum CategoryRequestStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  new(this.wire);

  final String wire;

  static CategoryRequestStatus? fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull;
}

/// `CategoryVerificationRequest`.
@immutable
class CategoryRequest {
  const new({
    required this.id,
    required this.status,
    this.category,
    this.rejectReason,
  });

  final String id;
  final CategoryRequestStatus status;
  final AccountCategory? category;
  final String? rejectReason;
}

/// `CategoryVerificationStatus`.
@immutable
class CategoryVerification {
  const new({
    this.category,
    this.verified = false,
    this.locked = false,
    this.request,
  });

  factory fromJson(Map<String, dynamic> json) {
    final r = json['request'];
    final status = r is Map<String, dynamic>
        ? CategoryRequestStatus.fromWire(r['status'])
        : null;
    return CategoryVerification(
      category: AccountCategory.fromWire(json['category']),
      verified: json['verified'] == true,
      locked: json['locked'] == true,
      request: r is Map<String, dynamic> && status != null
          ? CategoryRequest(
              id: r['id']! as String,
              status: status,
              category: AccountCategory.fromWire(r['category']),
              rejectReason: r['rejectReason'] as String?,
            )
          : null,
    );
  }

  final AccountCategory? category;
  final bool verified;
  final bool locked;
  final CategoryRequest? request;

  /// An open request is waiting for the team.
  bool get pending => request?.status == CategoryRequestStatus.pending;
}
