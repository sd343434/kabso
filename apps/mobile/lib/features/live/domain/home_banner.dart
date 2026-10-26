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
