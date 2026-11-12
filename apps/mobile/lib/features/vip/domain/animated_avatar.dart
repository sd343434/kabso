// v1.136-social (D384, CONVENTIONS §10.173): the VIP animated picture
// «صورة متحركة» — `AnimatedAvatar` in docs/contracts/openapi.yaml.

import 'package:flutter/foundation.dart';

/// `AnimatedAvatar`: the member's short clip with its background removed —
/// a looping animated WebP with alpha ([url]) and its first frame as a still
/// ([stillUrl]), square frames of [width] × [height] px.
@immutable
class AnimatedAvatar {
  const new({
    required this.url,
    required this.stillUrl,
    required this.width,
    required this.height,
  });

  /// Null when [json] is not a complete `AnimatedAvatar`.
  static AnimatedAvatar? tryParse(Object? json) => switch (json) {
    {
      'url': final String url,
      'stillUrl': final String stillUrl,
      'width': final int width,
      'height': final int height,
    }
        when url.isNotEmpty && stillUrl.isNotEmpty =>
      AnimatedAvatar(
        url: url,
        stillUrl: stillUrl,
        width: width,
        height: height,
      ),
    _ => null,
  };

  /// The looping animated WebP.
  final String url;

  /// Its first frame (reduced motion, «إخفاء المؤثرات»).
  final String stillUrl;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'url': url,
    'stillUrl': stillUrl,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is AnimatedAvatar &&
      other.url == url &&
      other.stillUrl == stillUrl &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(url, stillUrl, width, height);

  @override
  String toString() => 'AnimatedAvatar($url)';
}

/// `PublicProfile.animatedAvatar` from JSON (absent or malformed → null).
AnimatedAvatar? animatedAvatarFromJson(Object? json) =>
    AnimatedAvatar.tryParse(json);

Object? animatedAvatarToJson(AnimatedAvatar? value) => value?.toJson();
