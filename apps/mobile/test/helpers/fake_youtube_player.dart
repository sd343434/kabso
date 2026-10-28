// A YouTube player without a web view (D154i, tests only): it records the
// commands and tests send its events.

import 'dart:async';

import 'package:kabso_live/features/live/data/youtube_player.dart';
import 'package:material_ui/material_ui.dart';

class FakeYoutubePlayer implements YoutubePlayer {
  new({required this.controls});

  final bool controls;
  final calls = <String>[];
  final events$ = StreamController<YoutubePlayerEvent>.broadcast();

  /// What [positionMs] answers.
  int? position;

  static const viewKey = Key('test.youtube');

  @override
  Widget view() => const ColoredBox(key: viewKey, color: Color(0xFF000000));

  @override
  Stream<YoutubePlayerEvent> get events => events$.stream;

  @override
  Future<void> load(
    String videoId, {
    required int startMs,
    required bool play,
  }) async => calls.add('load:$videoId@${startMs ~/ 1000}:$play');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(int ms) async => calls.add('seek:${ms ~/ 1000}');

  @override
  Future<int?> positionMs() async => position;

  @override
  void dispose() => unawaited(events$.close());
}

/// The players made, in order.
class FakeYoutubePlayers {
  final made = <FakeYoutubePlayer>[];

  FakeYoutubePlayer call({required bool controls}) {
    final p = FakeYoutubePlayer(controls: controls);
    made.add(p);
    return p;
  }
}
