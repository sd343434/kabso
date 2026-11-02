import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/data/background/live_background_service_stub.dart'
    if (dart.library.io) 'package:kabso_live/features/live/data/background/live_background_service_io.dart';

/// Who keeps a live running while the app is in the background (D123).
enum LiveBackgroundRole {
  /// The host on air (any mode): microphone, and the camera paused while
  /// the app is away.
  host,

  /// A seated guest publishing their microphone (and camera in MULTI).
  guest,

  /// A viewer listening to the live (audio and, D170, video rooms).
  listener,
}

/// The ongoing notification's words, in the person's language (built by the
/// screen from its l10n).
class LiveBackgroundTexts {
  const new({
    required this.channelName,
    required this.hostTitle,
    required this.guestTitle,
    required this.listenerTitle,
    required this.body,
    required this.endLive,
    required this.leave,
    this.micOff = '',
    this.micOn = '',
    this.cameraHide = '',
    this.cameraShow = '',
  });

  /// D213: a streamer host's notification toggles («كتم المايك» /
  /// «تشغيل المايك», «إخفاء الكاميرا» / «إظهار الكاميرا»).
  final String micOff;
  final String micOn;
  final String cameraHide;
  final String cameraShow;

  /// The Android notification channel ("Live").
  final String channelName;
  final String hostTitle;
  final String guestTitle;
  final String listenerTitle;

  /// "Tap to return to the room".
  final String body;

  /// The host's action: ends the live.
  final String endLive;

  /// A guest's or listener's action: leaves the seat or the room.
  final String leave;
}

/// D213: one more action on a streamer host's notification (Android shows
/// at most 3 actions: «إنهاء», the microphone and the camera bubble).
@immutable
class LiveBackgroundButton {
  const new(this.action, this.label);

  final LiveBackgroundAction action;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is LiveBackgroundButton &&
      other.action == action &&
      other.label == label;

  @override
  int get hashCode => Object.hash(action, label);
}

/// What the platform service shows and keeps running.
@immutable
class LiveBackgroundSpec {
  const new({
    required this.role,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.channelName,
    this.screen = false,
    this.buttons = const [],
    this.askNotifications = true,
  });

  /// The spec of [role] with [texts].
  factory of(LiveBackgroundRole role, LiveBackgroundTexts texts) =>
      LiveBackgroundSpec(
        role: role,
        title: switch (role) {
          LiveBackgroundRole.host => texts.hostTitle,
          LiveBackgroundRole.guest => texts.guestTitle,
          LiveBackgroundRole.listener => texts.listenerTitle,
        },
        body: texts.body,
        actionLabel: role == LiveBackgroundRole.host
            ? texts.endLive
            : texts.leave,
        channelName: texts.channelName,
      );

  final LiveBackgroundRole role;
  final String title;
  final String body;
  final String actionLabel;
  final String channelName;

  /// D213: a streamer host — the phone screen is captured (Android types
  /// `mediaProjection` and `camera`: the camera bubble goes on while the
  /// host is in the game).
  final bool screen;

  /// D213: actions after the main one (a streamer host's microphone and
  /// camera bubble).
  final List<LiveBackgroundButton> buttons;

  /// D251: whether starting the service may ask Android 13+'s notification
  /// permission first (a system dialog over the screen). The second camera
  /// never asks: the dialog came up over its camera at the very moment it
  /// went on air. Without the permission the service still runs; only its
  /// notification is hidden.
  final bool askNotifications;

  /// D213: this spec as a streamer host's, with its two toggles.
  LiveBackgroundSpec streamer({required String mic, required String camera}) =>
      LiveBackgroundSpec(
        role: role,
        title: title,
        body: body,
        actionLabel: actionLabel,
        channelName: channelName,
        screen: true,
        buttons: [
          LiveBackgroundButton(LiveBackgroundAction.toggleMic, mic),
          LiveBackgroundButton(LiveBackgroundAction.toggleCamera, camera),
        ],
        askNotifications: askNotifications,
      );

  /// The microphone is captured (Android foreground service type
  /// `microphone`); a listener only plays (`mediaPlayback`).
  bool get microphone => role != LiveBackgroundRole.listener;

  @override
  bool operator ==(Object other) =>
      other is LiveBackgroundSpec &&
      other.role == role &&
      other.title == title &&
      other.body == body &&
      other.actionLabel == actionLabel &&
      other.channelName == channelName &&
      other.screen == screen &&
      other.askNotifications == askNotifications &&
      listEquals(other.buttons, buttons);

  @override
  int get hashCode => Object.hash(
    role,
    title,
    body,
    actionLabel,
    channelName,
    screen,
    askNotifications,
    Object.hashAll(buttons),
  );
}

/// What the person did on the ongoing notification.
enum LiveBackgroundAction {
  /// Tapped the notification: back to the room.
  open,

  /// Tapped the action button: end the live, or leave.
  end,

  /// D213: a streamer host's microphone on / off.
  toggleMic,

  /// D213: a streamer host's camera bubble shown / hidden.
  toggleCamera,
}

/// The platform side (D123): on Android a foreground service of type
/// `microphone` / `mediaPlayback` with an ongoing notification, which keeps
/// the process (and its Dart timers: heartbeats) alive while the app is in
/// the background. Elsewhere it does nothing (iOS keeps the audio through
/// `UIBackgroundModes` audio).
abstract interface class LiveBackgroundService {
  /// Starts the service with [spec], or updates it when it already runs.
  Future<void> start(LiveBackgroundSpec spec);

  /// Stops the service (nothing when it does not run).
  Future<void> stop();

  /// The notification's taps.
  Stream<LiveBackgroundAction> get actions;
}

/// One holder of the background service (the host's controller, a viewer's
/// session) and what it does on the notification and app lifecycle.
class _Hold {
  new(
    this.spec,
    this.onEnd,
    this.onOpen,
    this.onBackground,
    this.onForeground, {
    this.onToggleMic,
    this.onToggleCamera,
    this.onUnavailable,
  });

  final LiveBackgroundSpec spec;
  final VoidCallback onEnd;
  final VoidCallback? onOpen;
  final VoidCallback? onBackground;
  final VoidCallback? onForeground;
  final VoidCallback? onToggleMic;
  final VoidCallback? onToggleCamera;
  final VoidCallback? onUnavailable;
}

/// Keeps the background service in step with whoever is live (D123).
///
/// Several holders may exist at once (a minimized host watching another
/// room): the service shows the most important one (host, then guest, then
/// listener, the latest first among equals) and its notification acts on
/// that holder. The service stops when the last holder releases it.
///
/// It also tells holders when the app goes to the background and comes
/// back ([handleLifecycle]): nothing ends or disconnects on `inactive`,
/// `hidden` or `paused`; a host or guest with a camera pauses it (Android
/// blocks the camera in the background) and resumes it on return.
class LiveBackgroundKeeper {
  new(this._service) {
    _actions = _service.actions.listen(_onAction);
  }

  final LiveBackgroundService _service;
  late final StreamSubscription<LiveBackgroundAction> _actions;
  final Map<Object, _Hold> _holds = {};
  LiveBackgroundSpec? _shown;
  Future<void> _queue = Future<void>.value();
  bool _away = false;

  /// What the service shows now (`null`: stopped).
  LiveBackgroundSpec? get shown => _shown;

  /// Whether the app is in the background (as last told).
  bool get away => _away;

  /// [owner] is live: starts (or updates) the service. [onEnd] runs on the
  /// notification's action, [onOpen] on a tap of the notification;
  /// [onBackground] / [onForeground] when the app leaves and returns.
  void hold(
    Object owner,
    LiveBackgroundSpec spec, {
    required VoidCallback onEnd,
    VoidCallback? onOpen,
    VoidCallback? onBackground,
    VoidCallback? onForeground,
    VoidCallback? onToggleMic,
    VoidCallback? onToggleCamera,
    VoidCallback? onUnavailable,
  }) {
    _holds.remove(owner);
    _holds[owner] = _Hold(
      spec,
      onEnd,
      onOpen,
      onBackground,
      onForeground,
      onToggleMic: onToggleMic,
      onToggleCamera: onToggleCamera,
      onUnavailable: onUnavailable,
    );
    _sync();
  }

  /// [owner] is no longer live; the service stops after the last one.
  void release(Object owner) {
    if (_holds.remove(owner) == null) return;
    _sync();
  }

  bool holds(Object owner) => _holds.containsKey(owner);

  _Hold? get _top {
    _Hold? best;
    for (final hold in _holds.values) {
      // The most important role first; among equals the latest holder.
      if (best == null || hold.spec.role.index <= best.spec.role.index) {
        best = hold;
      }
    }
    return best;
  }

  /// D251: how long one start / stop may hold the queue. A platform call
  /// that never answers no longer blocks every later start and stop (the
  /// call goes on; when it ends late, what runs is checked again).
  @visibleForTesting
  static Duration stepTimeout = const Duration(seconds: 30);

  void _sync() {
    final want = _top?.spec;
    if (want == _shown) return;
    _shown = want;
    _queue = _queue.then((_) => _apply(want));
  }

  Future<void> _apply(LiveBackgroundSpec? want) async {
    final Future<void> call;
    try {
      call = want == null ? _service.stop() : _service.start(want);
    } on Object {
      _unavailable(want);
      return;
    }
    try {
      await call.timeout(stepTimeout);
    } on TimeoutException {
      _unavailable(want);
      unawaited(
        call.then((_) {
          // Ended late: run what is wanted now if that changed meanwhile.
          final now = _shown;
          if (now != want) _queue = _queue.then((_) => _apply(now));
        }, onError: (Object _) {}),
      );
    } on Object {
      // Best effort: the live goes on in the foreground either way.
      _unavailable(want);
    }
  }

  /// D251: tells the holders of [spec] that the service could not start
  /// (their screens say so; nothing else changes).
  void _unavailable(LiveBackgroundSpec? spec) {
    if (spec == null) return;
    for (final hold in [..._holds.values]) {
      if (hold.spec == spec) hold.onUnavailable?.call();
    }
  }

  /// Waits for the start / stop calls sent so far (tests).
  Future<void> get settled => _queue;

  void _onAction(LiveBackgroundAction action) {
    final top = _top;
    if (top == null) return;
    switch (action) {
      case LiveBackgroundAction.end:
        top.onEnd();
      case LiveBackgroundAction.open:
        top.onOpen?.call();
      case LiveBackgroundAction.toggleMic:
        top.onToggleMic?.call();
      case LiveBackgroundAction.toggleCamera:
        top.onToggleCamera?.call();
    }
  }

  /// The app's lifecycle. Leaving (`hidden`, `paused`) tells the holders
  /// once; `resumed` tells them it is back. `inactive` (a system dialog,
  /// the notification shade) changes nothing.
  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_away) return;
        _away = true;
        for (final hold in [..._holds.values]) {
          hold.onBackground?.call();
        }
      case AppLifecycleState.resumed:
        if (!_away) return;
        _away = false;
        for (final hold in [..._holds.values]) {
          hold.onForeground?.call();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void dispose() {
    unawaited(_actions.cancel());
    _holds.clear();
    _shown = null;
    unawaited(_service.stop().then((_) {}, onError: (_) {}));
  }
}

/// The platform service: Android's foreground service, a no-op elsewhere.
/// Tests override it with a fake.
final Provider<LiveBackgroundService> liveBackgroundServiceProvider =
    Provider<LiveBackgroundService>((_) => createLiveBackgroundService());

/// The app's one keeper, following the app lifecycle.
final Provider<LiveBackgroundKeeper> liveBackgroundKeeperProvider =
    Provider<LiveBackgroundKeeper>((ref) {
      final keeper = LiveBackgroundKeeper(
        ref.watch(liveBackgroundServiceProvider),
      );
      final listener = _listen(keeper);
      ref.onDispose(() {
        listener?.dispose();
        keeper.dispose();
      });
      return keeper;
    });

/// Follows the app lifecycle; `null` without a widgets binding (plain
/// unit tests drive [LiveBackgroundKeeper.handleLifecycle] themselves).
AppLifecycleListener? _listen(LiveBackgroundKeeper keeper) {
  final WidgetsBinding binding;
  try {
    binding = WidgetsBinding.instance;
  } on Object {
    return null;
  }
  return AppLifecycleListener(
    binding: binding,
    onStateChange: keeper.handleLifecycle,
  );
}

/// Taps on the host's ongoing notification while the live is minimized:
/// the floating window opens the live full screen (D123).
class LiveBackgroundOpenRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final NotifierProvider<LiveBackgroundOpenRequests, int>
liveBackgroundOpenRequestsProvider =
    NotifierProvider<LiveBackgroundOpenRequests, int>(
      LiveBackgroundOpenRequests.new,
    );
