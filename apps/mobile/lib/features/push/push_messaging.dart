import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/push/push_payload.dart';

/// D152: the device side of push notifications (Firebase Cloud Messaging).
///
/// While the app is in the background or closed, Android shows a push by
/// itself on its channel (`kabso_general` / `kabso_messages`, created with
/// the owner's sounds by `MainActivity`); a tap opens the app and arrives
/// here as [onOpened] (app in the background) or [initialMessage] (app was
/// closed). In the foreground nothing is shown by the system: pushes arrive
/// as [onForeground] and the app plays its own sound.
abstract interface class PushMessaging {
  /// Starts Firebase; false when push cannot work here (iOS until APNs, the
  /// web, a build without `google-services.json`).
  Future<bool> init();

  /// This device's token, or `null` (push off, no network).
  Future<String?> token();

  Stream<String> get onTokenRefresh;

  Stream<PushPayload> get onForeground;

  Stream<PushPayload> get onOpened;

  /// The push whose tap started the app, once.
  Future<PushPayload?> initialMessage();
}

/// Push is off on this platform or build: nothing ever arrives.
class NoPushMessaging implements PushMessaging {
  const new();

  @override
  Future<bool> init() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushPayload> get onForeground => const Stream.empty();

  @override
  Stream<PushPayload> get onOpened => const Stream.empty();

  @override
  Future<PushPayload?> initialMessage() async => null;
}

/// Firebase Cloud Messaging, **Android only** (D152: iOS push waits for an
/// Apple Developer account and an APNs key, so iOS never starts Firebase and
/// needs no `GoogleService-Info.plist`).
class FirebasePushMessaging implements PushMessaging {
  new();

  /// Off in widget tests (no Firebase there; `test/flutter_test_config.dart`).
  static bool enabled = true;

  bool _ready = false;

  static PushPayload _payload(RemoteMessage m) =>
      PushPayload({for (final e in m.data.entries) e.key: '${e.value}'});

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } on Object catch (e) {
      // No google-services.json in this build (forks, a fresh clone): the
      // app works without pushes.
      debugPrint('Push off: $e');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<String?> token() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } on Object catch (e) {
      debugPrint('Push token unavailable: $e');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh =>
      _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  @override
  Stream<PushPayload> get onForeground =>
      _ready ? FirebaseMessaging.onMessage.map(_payload) : const Stream.empty();

  @override
  Stream<PushPayload> get onOpened => _ready
      ? FirebaseMessaging.onMessageOpenedApp.map(_payload)
      : const Stream.empty();

  @override
  Future<PushPayload?> initialMessage() async {
    if (!_ready) return null;
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _payload(m);
    } on Object {
      return null;
    }
  }
}

/// Whether this platform may use Firebase pushes (Android apps only).
bool get pushPlatformSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// The device's [PushMessaging] (tests override it).
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging.enabled && pushPlatformSupported
      ? FirebasePushMessaging()
      : const NoPushMessaging(),
);
