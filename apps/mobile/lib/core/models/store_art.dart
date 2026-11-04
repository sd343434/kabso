// D270 (owner: «المتجر», CONVENTIONS §10.98.4): a store item's hosted art —
// shared by the store, the bag and every renderer of a worn store item.

import 'package:flutter/foundation.dart' show immutable;

/// How an MP4 animation carries transparency (the gifts' D207 rule): a plain
/// video played as is, or the left half the colour and the right half the
/// alpha mask, composited by the gift alpha shader.
enum ArtVideo {
  plain('NONE'),
  sideBySide('SIDE_BY_SIDE');

  new(this.wire);

  final String wire;

  static ArtVideo? fromWire(Object? wire) =>
      values.where((v) => v.wire == wire).firstOrNull;
}

/// `StoreArt`: the still (PNG / WebP) and the animation — an SVGA, or an MP4
/// ([video] set) — and the picture's size. The still shows while the
/// animation loads, with reduced motion and in tests.
@immutable
final class StoreArt {
  const new({this.still, this.animation, this.video, this.width, this.height});

  /// Reads `StoreArt` (also the art fields of `StoreWornItem`); anything
  /// that is not a map is null.
  static StoreArt? fromJson(Object? json) {
    if (json is! Map) return null;
    String? url(Object? v) => v is String && v.isNotEmpty ? v : null;
    int? size(Object? v) => v is num && v > 0 ? v.toInt() : null;
    final animation = url(json['animation']);
    final mp4 = json['format'] == 'MP4';
    return StoreArt(
      still: url(json['still']),
      animation: animation,
      video: animation == null || !mp4
          ? null
          : (ArtVideo.fromWire(json['alpha']) ?? ArtVideo.plain),
      width: size(json['width']),
      height: size(json['height']),
    );
  }

  final String? still;
  final String? animation;

  /// Null: the animation (if any) is an SVGA.
  final ArtVideo? video;
  final int? width;
  final int? height;

  bool get isEmpty => still == null && animation == null;

  /// Width over height (the art's size; null when unknown).
  double? get aspect {
    final w = width;
    final h = height;
    return w != null && h != null && w > 0 && h > 0 ? w / h : null;
  }

  Map<String, Object?> toJson() => {
    'still': still,
    'animation': animation,
    'format': animation == null ? null : (video == null ? 'SVGA' : 'MP4'),
    'alpha': video?.wire,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreArt &&
      other.still == still &&
      other.animation == animation &&
      other.video == video &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(still, animation, video, width, height);

  @override
  String toString() => 'StoreArt($still, $animation, $video)';
}

/// `StoreWear` keys → the VIP perk / bag category codes they replace (one
/// worn item per kind).
const Map<String, String> storeWearKinds = {
  'avatarFrame': 'AVATAR_FRAME',
  'profileCard': 'PROFILE_CARD',
  'chatBubble': 'CHAT_BUBBLE',
  'entryBanner': 'ENTRY_BANNER',
  'entryEffect': 'ENTRY_EFFECT',
};

/// Reads `StoreWear` to {kind code → art}; empty for anything else.
Map<String, StoreArt> storeWearFromJson(Object? json) {
  if (json is! Map) return const {};
  final out = <String, StoreArt>{};
  for (final MapEntry(:key, :value) in storeWearKinds.entries) {
    final art = StoreArt.fromJson(json[key]);
    if (art != null && !art.isEmpty) out[value] = art;
  }
  return out;
}

/// The wire shape of [storeWearFromJson].
Map<String, Object?> storeWearToJson(Map<String, StoreArt> wear) => {
  for (final MapEntry(:key, :value) in storeWearKinds.entries)
    if (wear[value] case final art?) key: art.toJson(),
};

/// The wire shape of a nullable [StoreArt] (json_serializable `toJson`).
Map<String, Object?>? storeArtToJson(StoreArt? art) => art?.toJson();
