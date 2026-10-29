import 'package:kabso_live/core/media/inline_video.dart';
import 'package:material_ui/material_ui.dart';

/// A post or reel video without the plugin (D162): the test decides
/// whether it loads; every created player is kept in [FakeInlineVideos].
class FakeInlineVideo extends ChangeNotifier implements InlineVideoController {
  new(this.url, {this.failOnInit = false});

  static const viewKey = Key('fakeInlineVideo.view');

  final String url;
  final bool failOnInit;
  final volumes = <double>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  InlineVideoState _state = const InlineVideoState();

  @override
  InlineVideoState get state => _state;

  @override
  Future<void> initialize() async {
    if (failOnInit) throw StateError('no decoder');
    _state = const InlineVideoState(
      initialized: true,
      duration: Duration(seconds: 8),
      size: Size(1080, 1920),
    );
    notifyListeners();
  }

  @override
  Future<void> play() async {
    plays++;
    _set(playing: true);
  }

  @override
  Future<void> pause() async {
    pauses++;
    _set(playing: false);
  }

  void _set({required bool playing}) {
    _state = InlineVideoState(
      initialized: true,
      playing: playing,
      position: const Duration(milliseconds: 40),
      duration: _state.duration,
      size: _state.size,
    );
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Widget buildView() =>
      const ColoredBox(key: viewKey, color: Color(0xFF202020));

  @override
  // ignore: must_call_super — the fake keeps its listeners for assertions.
  Future<void> dispose() async => disposed = true;
}

/// Makes [FakeInlineVideo]s (failing for URLs in [failing]) and keeps them.
class FakeInlineVideos {
  final List<FakeInlineVideo> created = [];
  final Set<String> failing = {};

  InlineVideoController call(String url) {
    final video = FakeInlineVideo(url, failOnInit: failing.contains(url));
    created.add(video);
    return video;
  }
}
