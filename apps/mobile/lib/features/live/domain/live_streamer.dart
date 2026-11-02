// v1.56-live (D213, CONVENTIONS §10.86): the streamer live «بث ستريمر» —
// the host's phone screen (a game or an app) with a small round front-camera
// bubble that every viewer lays over it where the host put it.

import 'package:flutter/foundation.dart';

/// `StreamerOrientation`: the screen picture follows the host's screen.
enum StreamerOrientation {
  portrait('PORTRAIT'),
  landscape('LANDSCAPE');

  new(this.wire);

  final String wire;

  /// Unknown values read as portrait (the room's own shape).
  static StreamerOrientation parse(Object? wire) =>
      wire == landscape.wire ? landscape : portrait;
}

/// `StreamerCorner`: the camera bubble's corner of the screen picture.
/// Physical corners — the screen picture is never mirrored for Arabic, so
/// every viewer sees the bubble where the host put it.
enum StreamerCorner {
  topLeft('TOP_LEFT'),
  topRight('TOP_RIGHT'),
  bottomLeft('BOTTOM_LEFT'),
  bottomRight('BOTTOM_RIGHT');

  new(this.wire);

  final String wire;

  bool get top => this == topLeft || this == topRight;
  bool get left => this == topLeft || this == bottomLeft;

  /// The corner nearest to a point of a `size` box (a dropped bubble).
  static StreamerCorner nearest(
    double x,
    double y,
    double width,
    double height,
  ) {
    final left = x < width / 2;
    final top = y < height / 2;
    return top
        ? (left ? topLeft : topRight)
        : (left ? bottomLeft : bottomRight);
  }

  /// Unknown values read as the server's default (top left).
  static StreamerCorner parse(Object? wire) {
    for (final c in values) {
      if (c.wire == wire) return c;
    }
    return topLeft;
  }
}

/// v1.57-live (D247, CONVENTIONS §10.88): `StreamerMain` — the main picture.
/// `screen`: the screen track with the camera as the bubble (D213, the
/// Android host). `camera`: the camera track alone is the picture (the web
/// studio's «الكاميرا فقط», e.g. OBS Virtual Camera holding a whole scene);
/// no bubble, no screen track.
enum StreamerMain {
  screen('SCREEN'),
  camera('CAMERA');

  new(this.wire);

  final String wire;

  /// Unknown values (and a server before v1.57) read as the screen.
  static StreamerMain parse(Object? wire) =>
      wire == camera.wire ? camera : screen;
}

/// `LiveStreamer`: a STREAMER live's layout as the host set it.
@immutable
class LiveStreamer {
  const new({
    this.orientation = StreamerOrientation.portrait,
    this.cameraVisible = true,
    this.corner = StreamerCorner.topLeft,
    this.main = StreamerMain.screen,
    this.version = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    final overlay = json['cameraOverlay'];
    final o = overlay is Map ? overlay : const <String, Object?>{};
    final version = json['version'];
    return LiveStreamer(
      orientation: StreamerOrientation.parse(json['orientation']),
      cameraVisible: o['visible'] is! bool || o['visible'] as bool,
      corner: StreamerCorner.parse(o['corner']),
      main: StreamerMain.parse(json['main']),
      version: version is int ? version : 0,
    );
  }

  final StreamerOrientation orientation;
  final bool cameraVisible;
  final StreamerCorner corner;

  /// D247: the screen (with the bubble) or the camera alone.
  final StreamerMain main;

  /// Increases on every change; the app keeps the highest it saw.
  final int version;

  bool get landscape => orientation == StreamerOrientation.landscape;

  /// D247: the camera is the whole picture (no bubble, no screen expected).
  bool get cameraMain => main == StreamerMain.camera;

  Map<String, dynamic> toJson() => {
    'orientation': orientation.wire,
    'cameraOverlay': {'visible': cameraVisible, 'corner': corner.wire},
    'main': main.wire,
    'version': version,
  };

  LiveStreamer copyWith({
    StreamerOrientation? orientation,
    bool? cameraVisible,
    StreamerCorner? corner,
    StreamerMain? main,
    int? version,
  }) => LiveStreamer(
    orientation: orientation ?? this.orientation,
    cameraVisible: cameraVisible ?? this.cameraVisible,
    corner: corner ?? this.corner,
    main: main ?? this.main,
    version: version ?? this.version,
  );

  /// [other] when it is newer than this one (a data message, a re-read).
  LiveStreamer newest(LiveStreamer? other) =>
      other != null && other.version > version ? other : this;

  @override
  bool operator ==(Object other) =>
      other is LiveStreamer &&
      other.orientation == orientation &&
      other.cameraVisible == cameraVisible &&
      other.corner == corner &&
      other.main == main &&
      other.version == version;

  @override
  int get hashCode =>
      Object.hash(orientation, cameraVisible, corner, main, version);

  @override
  String toString() =>
      'LiveStreamer(${orientation.wire}, ${main.wire}, camera: $cameraVisible '
      '${corner.wire}, v$version)';
}

/// A `streamer` data message (topic `streamer`):
/// `{"type": "streamer", "roomId": "…", "streamer": LiveStreamer}`.
@immutable
class LiveStreamerEvent {
  const new(this.roomId, this.streamer);

  final String roomId;
  final LiveStreamer streamer;

  /// Null when [message] is not one.
  static LiveStreamerEvent? parse(Object? message) {
    if (message is! Map || message['type'] != 'streamer') return null;
    final roomId = message['roomId'];
    final streamer = message['streamer'];
    if (roomId is! String || streamer is! Map) return null;
    return LiveStreamerEvent(
      roomId,
      LiveStreamer.fromJson(Map<String, dynamic>.from(streamer)),
    );
  }
}
