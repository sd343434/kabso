import 'package:flutter/foundation.dart';

/// The physical side of a banner picture left empty for its text (the same
/// picture serves both languages, so this is not a reading direction).
enum HomeBannerTitleSide { left, right }

/// v1.97-social (D303, CONVENTIONS §10.114.6): a still picture, an animated
/// WebP (`imageUrl` moves), or a short muted video (`videoUrl`, `posterUrl`
/// its poster). An unknown kind reads as [image].
enum HomeBannerKind {
  image,
  animated,
  video;

  static HomeBannerKind fromWire(Object? wire) => switch (wire) {
    'ANIMATED' => animated,
    'VIDEO' => video,
    _ => image,
  };
}

/// `HomeBanner` (openapi v1.26-live draft, D124): a promo banner of the live
/// hub, a 3:1 picture with optional overlay text and a link.
@immutable
class HomeBanner {
  const new({
    required this.id,
    required this.imageUrl,
    required this.link,
    this.width = 1500,
    this.height = 500,
    this.title,
    this.titleSide = HomeBannerTitleSide.right,
    this.kind = HomeBannerKind.image,
    this.posterUrl,
    this.videoUrl,
    this.durationMs,
    this.eventId,
  });

  /// Parses one banner; throws a `TypeError` when the body does not match
  /// the contract (mapped to an `UnexpectedFailure` by `guardApiCall`).
  factory fromJson(Map<String, dynamic> json) => HomeBanner(
    id: json['id']! as String,
    imageUrl: json['imageUrl']! as String,
    width: json['width']! as int,
    height: json['height']! as int,
    title: json['title'] as String?,
    titleSide: json['titleSide'] == 'LEFT'
        ? HomeBannerTitleSide.left
        : HomeBannerTitleSide.right,
    link: json['link']! as String,
    // v1.97-social (D303): older servers send none of these (a still).
    kind: HomeBannerKind.fromWire(json['kind']),
    posterUrl: json['posterUrl'] as String?,
    videoUrl: json['videoUrl'] as String?,
    durationMs: json['durationMs'] as int?,
    eventId: json['eventId'] as String?,
  );

  final String id;
  final String imageUrl;
  final int width;
  final int height;

  /// Already localized by the server; `null` shows no text.
  final String? title;
  final HomeBannerTitleSide titleSide;

  /// An allowlisted in-app route or an https URL (`openHomeBannerLink`).
  final String link;

  /// v1.97-social (D303): what [imageUrl] is, and the video.
  final HomeBannerKind kind;

  /// The still (an animation's first frame, a video's poster); null from an
  /// older server — then [imageUrl].
  final String? posterUrl;

  /// [HomeBannerKind.video] only: the MP4 / MOV, played muted and looping.
  final String? videoUrl;

  /// A video's length or an animation's loop (ms), null for a still.
  final int? durationMs;

  /// The event the banner opens (`link` is then `/events/<id>`).
  final String? eventId;

  /// The picture shown with reduced motion and before a video plays.
  String get stillUrl => posterUrl ?? imageUrl;

  /// Whether this banner plays a video (a video kind with its file).
  bool get isVideo => kind == HomeBannerKind.video && videoUrl != null;
}

/// D248 (openapi v1.59-live draft, CONVENTIONS §10.90): the live hub's
/// card-size banners (`GET /home/banners?placement=hub_card`, 720 × 805
/// pictures, the live card's aspect) and the grid [cell] they take.
@immutable
class HubCardBanners {
  const new({this.banners = const [], this.cell = defaultCell});

  /// Parses the list response; a missing or out-of-range `cell` falls back
  /// to [defaultCell].
  factory fromJson(Map<String, dynamic> json) {
    final cell = json['cell'];
    return HubCardBanners(
      banners: [
        for (final item in json['data']! as List<dynamic>)
          HomeBanner.fromJson(item as Map<String, dynamic>),
      ],
      cell: cell is int && cell >= 0 && cell <= 40 ? cell : defaultCell,
    );
  }

  /// The first cell of the third row (the server's default).
  static const int defaultCell = 4;

  static const empty = HubCardBanners();

  /// In server order; they take turns in the one cell.
  final List<HomeBanner> banners;

  /// 0-based, in reading order over every cell of the 2-column grid.
  final int cell;
}
