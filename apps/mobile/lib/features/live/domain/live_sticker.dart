import 'package:flutter/foundation.dart' show immutable, listEquals;

/// `LiveSticker` (v1.37-live, D154h, CONVENTIONS §10.38): an art or a text
/// on a live, its centre at ([x], [y]) relative to the picture (0–1 from
/// the top-left), its [scale] and [rotation] (radians).
@immutable
final class LiveSticker {
  const new({
    required this.id,
    required this.x,
    required this.y,
    this.artKey,
    this.text,
    this.scale = 1,
    this.rotation = 0,
  });

  /// Reads [json]; throws on a malformed one.
  factory fromJson(Map<String, dynamic> json) => LiveSticker(
    id: json['id']! as String,
    artKey: json['artKey'] as String?,
    text: json['text'] as String?,
    x: (json['x']! as num).toDouble(),
    y: (json['y']! as num).toDouble(),
    scale: (json['scale']! as num).toDouble(),
    rotation: (json['rotation']! as num).toDouble(),
  );

  /// At most this many on a live (the server's limit).
  static const max = 3;

  /// A text's longest, in code points.
  static const textMax = 40;
  static const minScale = 0.25;
  static const maxScale = 4.0;

  /// An id not given by the server yet (a sticker just added).
  static const newId = '';

  final String id;
  final String? artKey;
  final String? text;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  LiveSticker moved({double? x, double? y, double? scale, double? rotation}) =>
      LiveSticker(
        id: id,
        artKey: artKey,
        text: text,
        x: (x ?? this.x).clamp(0, 1),
        y: (y ?? this.y).clamp(0, 1),
        scale: (scale ?? this.scale).clamp(minScale, maxScale),
        rotation: _wrap(rotation ?? this.rotation),
      );

  static double _wrap(double r) {
    const pi = 3.141592653589793;
    var v = r;
    while (v > pi) {
      v -= 2 * pi;
    }
    while (v < -pi) {
      v += 2 * pi;
    }
    return v;
  }

  /// The request body item (`SetLiveStickersRequest`).
  Map<String, Object?> toRequest() => {
    if (id != newId) 'id': id,
    'artKey': ?artKey,
    'text': ?text,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };

  @override
  bool operator ==(Object other) =>
      other is LiveSticker &&
      other.id == id &&
      other.artKey == artKey &&
      other.text == text &&
      other.x == x &&
      other.y == y &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(id, artKey, text, x, y, scale, rotation);
}

/// `LiveStickers`: a live's stickers now, the last on top.
@immutable
final class LiveStickers {
  const new({required this.roomId, required this.items});

  factory fromJson(Map<String, dynamic> json) => LiveStickers(
    roomId: json['roomId']! as String,
    items: [
      for (final i in json['items']! as List<dynamic>)
        LiveSticker.fromJson(i as Map<String, dynamic>),
    ],
  );

  final String roomId;
  final List<LiveSticker> items;

  @override
  bool operator ==(Object other) =>
      other is LiveStickers &&
      other.roomId == roomId &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(roomId, Object.hashAll(items));
}
