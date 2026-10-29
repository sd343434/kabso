// Wire models of the posts API (docs/contracts/openapi.yaml v1.5-social
// DRAFT, CONVENTIONS §11). Hand-written `fromJson`: a body that does not
// match throws a `TypeError`/`FormatException`, which `guardApiCall` turns
// into an `UnexpectedFailure`.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

DateTime? _dateOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

/// `MediaAsset`: a processed image (WebP 1080 and 320 wide), a voice clip
/// (CP-017) or (v1.41-social, D162) a video, served as uploaded, with its
/// poster ([posterUrl], [thumbUrl]) and length ([durationMs]).
@immutable
class MediaAsset {
  const new({
    required this.id,
    required this.url,
    required this.thumbUrl,
    required this.width,
    required this.height,
    this.blurhash,
    this.type = MediaType.image,
    this.posterUrl,
    this.durationMs,
  });

  factory fromJson(Map<String, dynamic> json) => MediaAsset(
    id: json['id']! as String,
    url: json['url']! as String,
    thumbUrl: json['thumbUrl']! as String,
    width: json['width']! as int,
    height: json['height']! as int,
    blurhash: json['blurhash'] as String?,
    type: switch (json['type']) {
      'VIDEO' => MediaType.video,
      'AUDIO' => MediaType.audio,
      _ => MediaType.image,
    },
    posterUrl: json['posterUrl'] as String?,
    durationMs: json['durationMs'] as int?,
  );

  final String id;

  /// The image (1080 px), the clip, or the video file.
  final String url;
  final String thumbUrl;
  final int width;
  final int height;
  final String? blurhash;
  final MediaType type;

  /// D162: a video's poster (its first frame, 1 080 px).
  final String? posterUrl;

  /// A clip's or a video's length.
  final int? durationMs;

  bool get isVideo => type == MediaType.video;

  /// What to show before a video plays (the poster), or the image itself.
  String get coverUrl => isVideo ? (posterUrl ?? thumbUrl) : url;

  double get aspect => height == 0 ? 1 : width / height;
}

/// `MediaAsset.type`.
enum MediaType { image, audio, video }

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
    this.isReel = false,
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
      isReel: json['format'] == 'REEL',
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

  /// D162: `format: REEL` — one vertical video, listed in Moments' reels.
  final bool isReel;

  /// The post's video (a reel's, or a video post's), if it has one.
  MediaAsset? get video =>
      media.length == 1 && media.first.isVideo ? media.first : null;
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

/// One item of `RecordViewsRequest`: how long a post was on screen.
typedef PostView = ({String postId, int watchedMs});

/// `RepostState`.
typedef RepostState = ({bool reposted, int repostCount});

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

/// `UpdatePostRequest`: only the fields set are sent. [location] `''`
/// clears the place (sent as `null`). Images never change.
@immutable
class PostUpdate {
  const new({
    this.text,
    this.location,
    this.commentsEnabled,
    this.whoCanComment,
    this.hideLikeCount,
    this.status,
    this.publishAt,
  });

  final String? text;
  final String? location;
  final bool? commentsEnabled;
  final WhoCanComment? whoCanComment;
  final bool? hideLikeCount;

  /// `DRAFT`, `SCHEDULED` or `PUBLISHED` (CONVENTIONS §11.2 transitions).
  final String? status;
  final DateTime? publishAt;

  bool get isEmpty => toJson().isEmpty;

  Map<String, Object?> toJson() {
    final settings = <String, Object>{
      'commentsEnabled': ?commentsEnabled,
      'whoCanComment': ?whoCanComment?.wire,
      'hideLikeCount': ?hideLikeCount,
    };
    return {
      'text': ?text,
      if (location case final l?) 'location': l.isEmpty ? null : l,
      if (settings.isNotEmpty) 'settings': settings,
      'status': ?status,
      'publishAt': ?publishAt?.toUtc().toIso8601String(),
    };
  }
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

/// `Hashtag`: a tag (lower case, no `#`) and its visible post count.
@immutable
class Hashtag {
  const new({required this.tag, required this.postCount});

  factory fromJson(Map<String, dynamic> json) => Hashtag(
    tag: json['tag']! as String,
    postCount: json['postCount']! as int,
  );

  final String tag;
  final int postCount;
}

/// D147: the tag of a [TrendingSearch].
enum TrendingSearchTag {
  /// Searched by at least 3 people in the last 24 h, twice the day before.
  trending,

  /// First searched in the last 24 h.
  newTerm,
}

/// D147: one term people search most (`GET /search/trending`, CONVENTIONS
/// §11.11): the server's counted form (lower case) and an optional tag.
@immutable
class TrendingSearch {
  const new({required this.term, this.tag});

  factory fromJson(Map<String, dynamic> json) => TrendingSearch(
    term: json['term']! as String,
    tag: switch (json['tag']) {
      'TRENDING' => TrendingSearchTag.trending,
      'NEW' => TrendingSearchTag.newTerm,
      // Unknown or absent tags show no pill.
      _ => null,
    },
  );

  final String term;
  final TrendingSearchTag? tag;

  @override
  bool operator ==(Object other) =>
      other is TrendingSearch && other.term == term && other.tag == tag;

  @override
  int get hashCode => Object.hash(term, tag);
}

/// What `GET /search` looks for.
enum SearchType { users, hashtags, posts }

/// The order of a hashtag's posts (`GET /hashtags/{tag}/posts?sort=`).
enum HashtagSort { recent, top }
