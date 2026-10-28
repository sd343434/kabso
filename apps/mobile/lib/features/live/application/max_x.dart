import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:material_ui/material_ui.dart'
    show AppLifecycleState, WidgetsBinding;

/// D145d (owner's MAX X design, `kabso_max_x_button.dart`): how hot the
/// button looks for a streak of N sends — x1–9 red, x10–29 pink, x30–99
/// purple, x100 and more gold.
enum MaxXHeat {
  red(1),
  pink(10),
  purple(30),
  gold(100);

  new(this.from);

  /// The first streak length of this tier.
  final int from;

  static MaxXHeat of(int streak) {
    var heat = MaxXHeat.red;
    for (final h in values) {
      if (streak >= h.from) heat = h;
    }
    return heat;
  }
}

/// D145d: the owner's win celebrations, one per lucky multiplier — ×5 ×10
/// ×25 ×50 ×100 ×250 ×500 (JACKPOT) ×1000 (SUPER JACKPOT). A celebration
/// is played only for a send the server answered with a win
/// (`luckyResult.topMultiplier`); the app never makes one up.
abstract final class MaxXTiers {
  static const win = [5, 10, 25, 50, 100, 250, 500, 1000];

  /// The celebration of a send that won ×[multiplier]: the largest tier at
  /// or under it (owner: «any other multiplier uses the closest lower tier,
  /// e.g. ×30 → ×25»); a smaller win than ×5 (a table may hold ×2) plays
  /// the ×5 one. Null for no win.
  static int? winTierOf(int? multiplier) {
    if (multiplier == null || multiplier <= 0) return null;
    var tier = win.first;
    for (final t in win) {
      if (multiplier >= t) tier = t;
    }
    return tier;
  }
}

/// D145d: the MAX X sounds — the owner's files in `assets/sounds/`
/// (`PROVENANCE.md`): a pop on every tap and a jingle per win tier.
abstract interface class MaxXSoundPlayer {
  Future<void> tap();

  /// The jingle of win tier [tier] (one of [MaxXTiers.win]).
  Future<void> win(int tier);

  Future<void> dispose();
}

/// Plays the MAX X sounds with `audioplayers` (the splash voice's plugin).
/// On Android each player uses the ring/notification usage without audio
/// focus (`respectSilence`): a phone on silent or vibrate plays nothing,
/// and the live's audio is never ducked. On iOS the live owns the audio
/// session (play and record), so nothing here changes it (the ring/silent
/// switch does not apply to that session). Never throws.
class AudioplayersMaxXSounds implements MaxXSoundPlayer {
  new({AudioPlayer Function()? createPlayer})
    : _create = createPlayer ?? AudioPlayer.new;

  static const tapAsset = 'sounds/max_tap.mp3';
  static String winAsset(int tier) => 'sounds/max_win_$tier.mp3';

  /// Off in widget tests (no audio plugin there;
  /// `test/flutter_test_config.dart`).
  static bool enabled = true;

  /// Taps overlap: a few players take turns.
  static const tapPlayers = 3;

  final AudioPlayer Function() _create;
  final _taps = <AudioPlayer>[];
  AudioPlayer? _win;
  var _next = 0;
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

  Future<void> _play(
    Future<AudioPlayer> Function() player,
    String asset,
    double volume,
  ) async {
    if (!enabled || _disposed || kIsWeb) return;
    try {
      final p = await player();
      if (_disposed) return;
      await p.stop();
      await p.play(AssetSource(asset), volume: volume);
    } on Object catch (e) {
      // No sound on this device: the button stays silent.
      debugPrint('MaxXSounds($asset): $e');
    }
  }

  @override
  Future<void> tap() => _play(
    () async {
      if (_taps.length < tapPlayers) _taps.add(await _make());
      return _taps[_next++ % _taps.length];
    },
    tapAsset,
    0.7,
  );

  @override
  Future<void> win(int tier) =>
      _play(() async => _win ??= await _make(), winAsset(tier), 0.9);

  @override
  Future<void> dispose() async {
    _disposed = true;
    final players = [..._taps, ?_win];
    _taps.clear();
    _win = null;
    for (final p in players) {
      try {
        await p.dispose();
      } on Object {
        // Already gone.
      }
    }
  }
}

final Provider<MaxXSoundPlayer> maxXSoundPlayerProvider =
    Provider<MaxXSoundPlayer>((ref) {
      final player = AudioplayersMaxXSounds();
      ref.onDispose(() => unawaited(player.dispose()));
      return player;
    });

/// D145d: when the MAX X sounds play — only on the sender's own phone (the
/// button and its results exist only there; the room never hears them),
/// only while the app's sound effects are on (Settings) and the app is in
/// the foreground, and a win's jingle only for a send the server answered
/// with a win.
class MaxXSounds {
  new(this._ref);

  final Ref _ref;

  /// Whether the app is in the foreground (tests replace it).
  @visibleForTesting
  static bool Function() foreground = () {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  };

  bool get _on => _ref.read(soundEffectsProvider) && foreground();

  /// An accepted tap.
  void tap() {
    if (_on) unawaited(_ref.read(maxXSoundPlayerProvider).tap());
  }

  /// A send the server answered with ×[multiplier] (0 or null: no win, no
  /// sound).
  void win(int? multiplier) {
    final tier = MaxXTiers.winTierOf(multiplier);
    if (tier != null && _on) {
      unawaited(_ref.read(maxXSoundPlayerProvider).win(tier));
    }
  }
}

final Provider<MaxXSounds> maxXSoundsProvider = Provider<MaxXSounds>(
  MaxXSounds.new,
);
