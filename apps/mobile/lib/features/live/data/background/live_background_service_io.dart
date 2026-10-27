import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/data/background/live_background_service_stub.dart'
    show NoLiveBackgroundService;

/// Android: [AndroidLiveBackgroundService]; other `dart:io` platforms
/// (iOS keeps the audio with `UIBackgroundModes` audio; desktop, tests):
/// nothing.
LiveBackgroundService createLiveBackgroundService() => Platform.isAndroid
    ? AndroidLiveBackgroundService()
    : NoLiveBackgroundService();

/// The notification's action button id.
const String _endButton = 'kabso.live.end';

/// The messages the service's task sends to the app.
const String _openMessage = 'kabso.live.open';
const String _endMessage = 'kabso.live.end';

/// D123: a foreground service (`flutter_foreground_task`, MIT) while the
/// person is live — type `microphone|mediaPlayback` for a host or seated
/// guest, `mediaPlayback` for a listener — with an ongoing notification:
/// a tap brings the app back, the button ends the live (or leaves). It
/// keeps the process out of Android's cached/frozen state, so the media
/// session, the microphone and the Dart heartbeat timer keep running.
class AndroidLiveBackgroundService implements LiveBackgroundService {
  new() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final _actions = StreamController<LiveBackgroundAction>.broadcast();
  bool _askedNotifications = false;
  String? _channel;

  /// Whether the running service was started with the `microphone` type.
  bool _runningMic = false;

  static const int _serviceId = 4123;

  void _onData(Object data) {
    switch (data) {
      case _openMessage:
        _actions.add(LiveBackgroundAction.open);
      case _endMessage:
        _actions.add(LiveBackgroundAction.end);
    }
  }

  @override
  Stream<LiveBackgroundAction> get actions => _actions.stream;

  void _init(String channelName) {
    if (_channel == channelName) return;
    _channel = channelName;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kabso_live_on_air',
        channelName: channelName,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWifiLock: true,
        // A process the system killed has no live left to keep.
        allowAutoRestart: false,
        // Stops with the app's task (swiped away): the live then times out
        // on the server like any lost host.
        stopWithTask: true,
      ),
    );
  }

  @override
  Future<void> start(LiveBackgroundSpec spec) async {
    // Android 13+: the ongoing notification needs POST_NOTIFICATIONS. The
    // service runs either way; asked once per run.
    if (!_askedNotifications) {
      _askedNotifications = true;
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
    _init(spec.channelName);
    final buttons = [
      NotificationButton(id: _endButton, text: spec.actionLabel),
    ];
    var running = await FlutterForegroundTask.isRunningService;
    if (running && spec.microphone && !_runningMic) {
      // A listener took a seat: the service's types are fixed when it
      // starts, and Android 14 cuts a background microphone without the
      // `microphone` type, so it starts again with it.
      await FlutterForegroundTask.stopService();
      running = false;
    }
    if (running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: spec.title,
        notificationText: spec.body,
        notificationButtons: buttons,
      );
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [
        if (spec.microphone) ForegroundServiceTypes.microphone,
        ForegroundServiceTypes.mediaPlayback,
      ],
      notificationTitle: spec.title,
      notificationText: spec.body,
      notificationButtons: buttons,
      callback: liveBackgroundTaskStart,
    );
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Live foreground service: $error');
    }
    _runningMic = spec.microphone;
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// The service's task (its own isolate): forwards the notification's taps
/// to the app, which ends or opens the live through its usual path.
@pragma('vm:entry-point')
void liveBackgroundTaskStart() {
  FlutterForegroundTask.setTaskHandler(_LiveTaskHandler());
}

class _LiveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _endButton) FlutterForegroundTask.sendDataToMain(_endMessage);
  }

  @override
  void onNotificationPressed() =>
      FlutterForegroundTask.sendDataToMain(_openMessage);
}
