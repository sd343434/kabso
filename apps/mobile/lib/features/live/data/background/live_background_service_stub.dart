import 'package:kabso_live/features/live/application/live_background.dart';

/// The web (and any platform without `dart:io`): nothing to keep running.
LiveBackgroundService createLiveBackgroundService() =>
    NoLiveBackgroundService();

/// A [LiveBackgroundService] that does nothing.
class NoLiveBackgroundService implements LiveBackgroundService {
  @override
  Future<void> start(LiveBackgroundSpec spec) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<LiveBackgroundAction> get actions => const Stream.empty();
}
