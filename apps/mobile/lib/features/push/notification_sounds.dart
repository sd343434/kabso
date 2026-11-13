import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';

/// D152 (phase 1): the owner's two sounds, played **in the app** while it is
/// open — the same files the Android channels play for pushes.
enum NotificationSound {
  /// `kabi_voice_a` (≈ 2.4 s): a new notification.
  general('sounds/kabi_voice_a.mp3', Duration(milliseconds: 2450)),

  /// `kabso_message` (≈ 0.6 s): a new message in another chat.
  message('sounds/kabso_message.mp3', Duration(milliseconds: 650));

  new(this.asset, this.length);

  final String asset;

  /// How long it plays (no other sound starts meanwhile).
  final Duration length;
}

/// Plays one sound (a seam for tests).
abstract interface class NotificationSoundPlayer {
  Future<void> play(NotificationSound sound);

  Future<void> dispose();
}

/// [NotificationSoundPlayer] with `audioplayers` (the MAX X sounds' plugin,
/// D145d): on Android the notification usage without audio focus
/// (`respectSilence`), so a phone on silent or vibrate plays nothing and a
/// live or video is not ducked. Never throws.
class AudioplayersNotificationSounds implements NotificationSoundPlayer {
  new({AudioPlayer Function()? createPlayer})
    : _create = createPlayer ?? AudioPlayer.new;

  /// Off in widget tests (no audio plugin; `test/flutter_test_config.dart`).
  static bool enabled = true;

  final AudioPlayer Function() _create;
  AudioPlayer? _player;
  var _disposed = false;

  Future<AudioPlayer> _make() async {
    final p = _create();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await p.setAudioContext(
        AudioContext(
          android: AudioContextConfig(
            respectSilence: true,
            focus: AudioContextConfigFocus.mixWithOthers,
          ).buildAndroid(),
        ),
      );
    }
    await p.setReleaseMode(ReleaseMode.stop);
    return p;
  }

  @override
  Future<void> play(NotificationSound sound) async {
    if (!enabled || _disposed || kIsWeb) return;
    try {
      final p = _player ??= await _make();
      if (_disposed) return;
      await p.stop();
      await p.play(AssetSource(sound.asset), volume: 0.9);
    } on Object catch (e) {
      debugPrint('NotificationSounds(${sound.name}): $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final p = _player;
    _player = null;
    try {
      await p?.dispose();
    } on Object {
      // Already gone.
    }
  }
}

final Provider<NotificationSoundPlayer> notificationSoundPlayerProvider =
    Provider<NotificationSoundPlayer>((ref) {
      final player = AudioplayersNotificationSounds();
      ref.onDispose(() => unawaited(player.dispose()));
      return player;
    });

/// D152 phase 1: when the in-app sounds play — only while Settings → Sound
/// effects is on and the app is in the foreground; **never two at once**
/// (a sound that would start while another plays is dropped), and each at
/// most once per its gap (a push and the next unread-count poll for the
/// same notification make one sound).
class NotificationSounds {
  new(this._ref);

  final Ref _ref;

  /// Whether the app is in the foreground (tests replace it).
  @visibleForTesting
  static bool Function() foreground = () {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  };

  /// At most one of each per this long.
  static const Map<NotificationSound, Duration> gaps = {
    NotificationSound.general: Duration(seconds: 8),
    NotificationSound.message: Duration(seconds: 2),
  };

  DateTime? _busyUntil;
  final _last = <NotificationSound, DateTime>{};

  /// A new notification (a push in the foreground, or the unread count grew).
  void general() => _play(NotificationSound.general);

  /// A new message in a chat that is not on screen.
  void message() => _play(NotificationSound.message);

  void _play(NotificationSound sound) {
    if (!_ref.read(soundEffectsProvider) || !foreground()) return;
    final now = clock.now();
    final busy = _busyUntil;
    if (busy != null && now.isBefore(busy)) return;
    final last = _last[sound];
    if (last != null && now.difference(last) < gaps[sound]!) return;
    _last[sound] = now;
    _busyUntil = now.add(sound.length);
    unawaited(_ref.read(notificationSoundPlayerProvider).play(sound));
  }
}

final Provider<NotificationSounds> notificationSoundsProvider =
    Provider<NotificationSounds>(NotificationSounds.new);
