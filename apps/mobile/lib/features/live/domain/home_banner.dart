import 'package:flutter/foundation.dart';

/// The physical side of a banner picture left empty for its text (the same
/// picture serves both languages, so this is not a reading direction).
enum HomeBannerTitleSide { left, right }

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
