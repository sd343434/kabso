// Wire models of the posts API (docs/contracts/openapi.yaml v1.5-social
// DRAFT, CONVENTIONS §11). Hand-written `fromJson`: a body that does not
// match throws a `TypeError`/`FormatException`, which `guardApiCall` turns
// into an `UnexpectedFailure`.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

DateTime? _dateOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

/// `MediaAsset`: a processed image (WebP 1080 and 320 wide).
@immutable
class MediaAsset {
  const new({
    required this.id,
    required this.url,
    required this.thumbUrl,
    required this.width,
    required this.height,
    this.blurhash,
  });

  factory fromJson(Map<String, dynamic> json) => MediaAsset(
    id: json['id']! as String,
    url: json['url']! as String,
    thumbUrl: json['thumbUrl']! as String,
    width: json['width']! as int,
    height: json['height']! as int,
    blurhash: json['blurhash'] as String?,
  );

  final String id;
  final String url;
  final String thumbUrl;
  final int width;
  final int height;
  final String? blurhash;

  double get aspect => height == 0 ? 1 : width / height;
}

/// Who may comment on a post (`whoCanComment`).
enum WhoCanComment {
  everyone('EVERYONE'),
  followers('FOLLOWERS'),
  nobody('NOBODY');

  new(this.wire);

  final String wire;

  static WhoCanComment fromWire(Object? v) => values.firstWhere(
    (w) => w.wire == v,
    orElse: () => throw const FormatException('whoCanComment'),
  );
}

/// `Post`.
@immutable
class Post {
  const new({
    required this.id,
    required this.author,
    required this.text,
    required this.media,
    required this.hashtags,
    required this.mentions,
    required this.status,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.repostCount,
    required this.viewCount,
    required this.viewerHasLiked,
    required this.viewerHasSaved,
    required this.viewerHasReposted,
    required this.isSelf,
    required this.pinned,
    required this.commentsEnabled,
    required this.whoCanComment,
    required this.hideLikeCount,
    required this.pendingModeration,
    this.location,
    this.publishAt,
    this.publishedAt,
    this.editedAt,
    this.repostedBy,
  });

  factory fromJson(Map<String, dynamic> json) {
    final settings = json['settings']! as Map<String, dynamic>;
    return Post(
      id: json['id']! as String,
      author: UserSummary.fromJson(json['author']! as Map<String, dynamic>),
      text: json['text']! as String,
      media: [
        for (final m in json['media']! as List<dynamic>)
          MediaAsset.fromJson(m as Map<String, dynamic>),
      ],
      location: json['location'] as String?,
      hashtags: [
        for (final t in json['hashtags']! as List<dynamic>) t as String,
      ],
      mentions: [
        for (final m in json['mentions']! as List<dynamic>)
          UserSummary.fromJson(m as Map<String, dynamic>),
      ],
      status: json['status']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      publishAt: _dateOrNull(json['publishAt']),
      publishedAt: _dateOrNull(json['publishedAt']),
      editedAt: _dateOrNull(json['editedAt']),
      pinned: json['pinned']! as bool,
      likeCount: json['likeCount'] as int?,
      commentCount: json['commentCount']! as int,
      shareCount: json['shareCount']! as int,
      repostCount: json['repostCount']! as int,
      viewCount: json['viewCount']! as int,
      viewerHasLiked: json['viewerHasLiked']! as bool,
      viewerHasSaved: json['viewerHasSaved']! as bool,
      viewerHasReposted: json['viewerHasReposted']! as bool,
      isSelf: json['isSelf']! as bool,
      commentsEnabled: settings['commentsEnabled']! as bool,
      whoCanComment: WhoCanComment.fromWire(settings['whoCanComment']),
      hideLikeCount: settings['hideLikeCount']! as bool,
      pendingModeration: json['moderation'] == 'PENDING',
      repostedBy: switch (json['repostedBy']) {
        final Map<String, dynamic> by => UserSummary.fromJson(by),
        _ => null,
      },
    );
  }

  final String id;
  final UserSummary author;
  final String text;
  final List<MediaAsset> media;
  final String? location;
  final List<String> hashtags;
  final List<UserSummary> mentions;

  /// `DRAFT`, `SCHEDULED` or `PUBLISHED`.
  final String status;
  final DateTime createdAt;
  final DateTime? publishAt;
  final DateTime? publishedAt;
  final DateTime? editedAt;
  final bool pinned;

  /// `null` when the author hides it (and the viewer is not the author).
  final int? likeCount;
  final int commentCount;
  final int shareCount;
  final int repostCount;
  final int viewCount;
  final bool viewerHasLiked;
  final bool viewerHasSaved;
  final bool viewerHasReposted;
  final bool isSelf;
  final bool commentsEnabled;
  final WhoCanComment whoCanComment;
  final bool hideLikeCount;

  /// `moderation: PENDING`: visible to its author only (CP-006 Q2).
  final bool pendingModeration;
  final UserSummary? repostedBy;
}

/// One page of a list (`PostPage`, `UserSummaryPage`, …).
@immutable
class PageOf<T> {
  const new(this.items, this.page);

  final List<T> items;
  final PageInfo page;

  /// The cursor of the next page, or `null` at the end.
  String? get next => page.hasMore ? page.nextCursor : null;
}

/// `LikeState`.
typedef LikeState = ({bool liked, int? likeCount});

/// The reasons of `ReportReason`.
enum ReportReason {
  spam('SPAM'),
  nudity('NUDITY'),
  violence('VIOLENCE'),
  hate('HATE'),
  harassment('HARASSMENT'),
  illegal('ILLEGAL'),
  other('OTHER');

  new(this.wire);

  final String wire;
}

/// The comment and like settings of a new post (`PostSettingsPatch`).
@immutable
class PostSettingsDraft {
  const new({
    this.commentsEnabled = true,
    this.whoCanComment,
    this.hideLikeCount = false,
  });

  final bool commentsEnabled;

  /// `null`: the author's default (`privacy_settings`, §11.7).
  final WhoCanComment? whoCanComment;
  final bool hideLikeCount;

  bool get isDefault =>
      commentsEnabled && whoCanComment == null && !hideLikeCount;

  PostSettingsDraft copyWith({
    bool? commentsEnabled,
    WhoCanComment? whoCanComment,
    bool? hideLikeCount,
  }) => PostSettingsDraft(
    commentsEnabled: commentsEnabled ?? this.commentsEnabled,
    whoCanComment: whoCanComment ?? this.whoCanComment,
    hideLikeCount: hideLikeCount ?? this.hideLikeCount,
  );

  /// The request body; only what differs from the defaults.
  Map<String, Object> toJson() => {
    if (!commentsEnabled) 'commentsEnabled': false,
    if (whoCanComment case final w?) 'whoCanComment': w.wire,
    if (hideLikeCount) 'hideLikeCount': true,
  };
}

/// Text limit of a comment (CONVENTIONS §11.5), checked again by the
/// server, which also allows at most five line breaks.
const int maxCommentText = 500;

/// `Comment`: top level (`parentId == null`) or a reply (one level).
@immutable
class Comment {
  const new({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.likeCount,
    required this.viewerHasLiked,
    required this.replyCount,
    required this.parentId,
    required this.mentions,
    required this.pinned,
    required this.canDelete,
  });

  factory fromJson(Map<String, dynamic> json) => Comment(
    id: json['id']! as String,
    postId: json['postId']! as String,
    author: UserSummary.fromJson(json['author']! as Map<String, dynamic>),
    text: json['text']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    likeCount: json['likeCount']! as int,
    viewerHasLiked: json['viewerHasLiked']! as bool,
    replyCount: json['replyCount']! as int,
    parentId: json['parentId'] as String?,
    mentions: [
      for (final m in json['mentions']! as List<dynamic>)
        UserSummary.fromJson(m as Map<String, dynamic>),
    ],
    pinned: json['pinned']! as bool,
    canDelete: json['canDelete']! as bool,
  );

  final String id;
  final String postId;
  final UserSummary author;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final bool viewerHasLiked;
  final int replyCount;

  /// The top-level comment of a reply.
  final String? parentId;

  /// The linked `@mentions` (others stay plain text, §11.6).
  final List<UserSummary> mentions;
  final bool pinned;

  /// The caller wrote it or owns the post.
  final bool canDelete;

  Comment copyWith({
    int? likeCount,
    bool? viewerHasLiked,
    int? replyCount,
    bool? pinned,
  }) => Comment(
    id: id,
    postId: postId,
    author: author,
    text: text,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
    replyCount: replyCount ?? this.replyCount,
    parentId: parentId,
    mentions: mentions,
    pinned: pinned ?? this.pinned,
    canDelete: canDelete,
  );
}
