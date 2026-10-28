import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/push/notification_sounds.dart';
import 'package:kabso_live/features/push/open_conversation.dart';
import 'package:kabso_live/features/push/push_messaging.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/push/push_tokens_repository.dart';

/// D152 (CONVENTIONS §11.12): ties pushes to the session and the screen.
///
/// - **Token:** registered (`PUT /me/push-token`) whenever a real account is
///   signed in (after sign-in, at every launch, on every token refresh);
///   the logout removes it first ([unregisterPushToken]; `POST /auth/logout`
///   removes it on the server too).
/// - **Foreground:** a push for the chat on screen does nothing; another
///   chat's plays the message sound, a notification the general sound
///   (Settings → Sound effects; [NotificationSounds]); the unread badge
///   refreshes.
/// - **Tap** (background or closed): opens the target through GoRouter —
///   once signed in and past the launch animation.
class PushController {
  new(this._ref);

  final Ref _ref;
  final _subs = <StreamSubscription<Object?>>[];
  bool _started = false;
  bool _ready = false;
  String? _pendingRoute;
  String? _registeredFor;

  /// Starts once (the app watches [pushControllerProvider]).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final messaging = _ref.read(pushMessagingProvider);
    _ready = await messaging.init();
    if (!_ready || !_ref.mounted) return;
    _subs
      ..add(messaging.onTokenRefresh.listen((t) => unawaited(_register(t))))
      ..add(messaging.onForeground.listen(onForeground))
      ..add(messaging.onOpened.listen(onOpened));
    _onAuth(_ref.read(sessionControllerProvider));
    final initial = await messaging.initialMessage();
    if (initial != null) onOpened(initial);
  }

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  bool get _realUser {
    final state = _ref.read(sessionControllerProvider);
    if (state is! Authenticated) return false;
    // D86: the demo account has no server session.
    return !(kDemoAvailable && _ref.read(demoModeProvider));
  }

  void _onAuth(AuthState state) {
    if (!_ready) return;
    if (state is Authenticated && _realUser) {
      if (_registeredFor != state.user.id) {
        _registeredFor = state.user.id;
        unawaited(_register(null));
      }
      _flushRoute();
    } else if (state is Unauthenticated) {
      _registeredFor = null;
    }
  }

  Future<void> _register(String? fresh) async {
    if (!_ready || !_realUser) return;
    final token = fresh ?? await _ref.read(pushMessagingProvider).token();
    if (token == null || !_ref.mounted) return;
    try {
      await _ref
          .read(pushTokensRepositoryProvider)
          .register(
            token: token,
            platform: defaultTargetPlatform == TargetPlatform.iOS
                ? 'IOS'
                : 'ANDROID',
            appVersion: _appVersion(),
          );
      if (_ref.mounted) {
        _ref.read(pushTokenRegisteredProvider.notifier).registered = true;
      }
    } on Object catch (e) {
      // Offline or refused: the next launch or token refresh tries again.
      debugPrint('Push token not registered: $e');
    }
  }

  String _appVersion() {
    final raw = _ref.read(appConfigProvider).appVersion;
    final clean = raw.replaceAll(RegExp('[^0-9A-Za-z.+_-]'), '');
    if (clean.isEmpty) return '0';
    return clean.length > 32 ? clean.substring(0, 32) : clean;
  }

  /// Before signing out: no more pushes to this phone for that account
  /// (the session calls [unregisterPushToken] itself).
  Future<void> signingOut() async {
    _registeredFor = null;
    await unregisterPushToken(_ref);
  }

  /// A push while the app is open (the system shows nothing).
  @visibleForTesting
  void onForeground(PushPayload push) {
    if (!_realUser) return;
    if (push.isMessage) {
      final conversation = push.conversation;
      if (conversation != null &&
          conversation == _ref.read(openConversationProvider)) {
        return;
      }
      _ref.read(notificationSoundsProvider).message();
      return;
    }
    if (push.kind == PushPayload.kindNotification) {
      _ref.read(notificationSoundsProvider).general();
      if (_ref.exists(unreadNotificationsProvider)) {
        unawaited(_ref.read(unreadNotificationsProvider.notifier).refresh());
      }
    }
  }

  /// A tap on a shown push.
  @visibleForTesting
  void onOpened(PushPayload push) {
    final route = push.route();
    if (route == null) return;
    _pendingRoute = route;
    _flushRoute();
  }

  void _flushRoute() {
    final route = _pendingRoute;
    if (route == null || !_realUser || !_ref.read(splashIntroProvider)) {
      return;
    }
    _pendingRoute = null;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _go(route))
      // A frame must come for the callback (the app may be idle).
      ..ensureVisualUpdate();
  }

  void _go(String route) {
    if (!_ref.mounted) return;
    final router = _ref.read(routerProvider);
    final here = router.routerDelegate.currentConfiguration.uri.path;
    // From a cold start the app is still on the splash or an auth screen:
    // land on Home first, so Back leads into the app.
    if (here == AppRoutes.splash || AppRoutes.publicAuthRoutes.contains(here)) {
      router.go(AppRoutes.home);
    }
    unawaited(router.push<void>(route));
  }
}

final Provider<PushController> pushControllerProvider =
    Provider<PushController>((ref) {
      final controller = PushController(ref);
      ref
        ..listen<AuthState>(
          sessionControllerProvider,
          (_, next) => controller._onAuth(next),
        )
        ..listen<bool>(splashIntroProvider, (_, _) => controller._flushRoute())
        ..onDispose(controller.dispose);
      return controller;
    });
