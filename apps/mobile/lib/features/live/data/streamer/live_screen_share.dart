import 'package:flutter/widgets.dart';
import 'package:kabso_live/features/live/domain/live_streamer.dart';

/// D213 (v1.56-live, CONVENTIONS §10.86): the streamer live's screen track,
/// kept apart from `LiveMediaEngine` like the other extras (a screen checks
/// `engine is LiveScreenShare`). The camera bubble is the ordinary camera
/// track, which every viewer lays over the screen.
abstract interface class LiveScreenShare {
  // ---- the host (Android) ------------------------------------------------

  /// Publishes the phone screen (the capture consent was given and the
  /// foreground service has the `mediaProjection` type). Throws when the
  /// capture cannot start.
  Future<void> publishScreen();

  /// Stops and unpublishes the screen (the live goes on).
  Future<void> unpublishScreen();

  /// Whether the screen track is published.
  bool get screenPublished;

  /// Pauses the screen track (muted, the capture kept: Android 14 allows one
  /// capture per consent) — viewers show «الشاشة متوقفة مؤقتاً».
  Future<void> setScreenPaused({required bool paused});

  bool get screenPaused;

  // ---- viewers -------------------------------------------------------------

  /// [identity]'s screen, fitted inside its box (letterboxed), or null.
  Widget? remoteScreen(String identity);

  /// Whether [identity] publishes a screen track (paused or not).
  bool hasRemoteScreen(String identity);

  /// Whether [identity]'s screen track is published but paused.
  bool remoteScreenPaused(String identity);

  /// The camera bubble of [identity] (cover-fit), or null (none, or paused).
  Widget? remoteCamera(String identity);

  /// The `streamer` data messages of the room.
  Stream<LiveStreamerEvent> get streamerEvents;

  /// `streamerVersion` from the media room's metadata.
  int? get streamerVersion;
}
