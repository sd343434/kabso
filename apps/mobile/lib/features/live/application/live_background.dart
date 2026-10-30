import 'dart:async';

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
  });

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

/// What the platform service shows and keeps running.
@immutable
class LiveBackgroundSpec {
  const new({
    required this.role,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.channelName,
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
      other.channelName == channelName;

  @override
  int get hashCode => Object.hash(role, title, body, actionLabel, channelName);
}

/// What the person did on the ongoing notification.
enum LiveBackgroundAction {
  /// Tapped the notification: back to the room.
  open,

  /// Tapped the action button: end the live, or leave.
  end,
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
  new(this.spec, this.onEnd, this.onOpen, this.onBackground, this.onForeground);

  final LiveBackgroundSpec spec;
  final VoidCallback onEnd;
  final VoidCallback? onOpen;
  final VoidCallback? onBackground;
  final VoidCallback? onForeground;
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
  }) {
    _holds.remove(owner);
    _holds[owner] = _Hold(spec, onEnd, onOpen, onBackground, onForeground);
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

  void _sync() {
    final want = _top?.spec;
    if (want == _shown) return;
    _shown = want;
    _queue = _queue.then((_) async {
      try {
        if (want == null) {
          await _service.stop();
        } else {
          await _service.start(want);
        }
      } on Object {
        // Best effort: the live goes on in the foreground either way.
      }
    });
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
