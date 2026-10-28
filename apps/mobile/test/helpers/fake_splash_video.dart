import 'package:kabso_live/features/auth/presentation/splash_video.dart';
import 'package:material_ui/material_ui.dart';

/// The launch video without the plugin (D156): the test decides when it
/// loads, ends or fails. With [endOnPlay] it reports its end as soon as it
/// plays (the default for tests that only pass through the splash).
class FakeSplashVideo extends ChangeNotifier implements SplashVideoController {
  new({
    this.failOnInit = false,
    this.endOnPlay = false,
    this.length = const Duration(milliseconds: 6600),
  });

  static const viewKey = Key('fakeSplashVideo.view');

  final bool failOnInit;
  final bool endOnPlay;
  final Duration length;

  String? asset;
  final volumes = <double>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;

  SplashVideoState _state = const SplashVideoState();

  @override
  SplashVideoState get state => _state;

  @override
  Future<void> initialize() async {
    if (failOnInit) throw StateError('no decoder');
    _state = SplashVideoState(
      initialized: true,
      duration: length,
      size: const Size(720, 1280),
    );
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> play() async {
    plays++;
    if (endOnPlay) end();
  }

  @override
  Future<void> pause() async => pauses++;

  /// Played to the last frame.
  void end() {
    _state = SplashVideoState(
      initialized: true,
      completed: true,
      position: length,
      duration: length,
      size: _state.size,
    );
    notifyListeners();
  }

  /// The player reports an error while playing.
  void fail() {
    _state = SplashVideoState(
      initialized: _state.initialized,
      failed: true,
      duration: length,
      size: _state.size,
    );
    notifyListeners();
  }

  @override
  Widget buildView() =>
      const ColoredBox(key: viewKey, color: Color(0xFFC2000B));

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

/// The ring mode, fixed by the test.
class FakeSilentMode implements DeviceSilentMode {
  const new({this.silent = false});

  final bool silent;

  @override
  Future<bool> isSilent() async => silent;
}
