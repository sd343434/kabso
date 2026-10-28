import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:material_ui/material_ui.dart'
    show AppLifecycleState, WidgetsBinding;

/// D154 (owner: «a local mute»): quips play no sound on this phone while
/// on, in every live (the bubble with the words still shows). Off by
/// default; kept for the app session. The switch is in the quips tab of the
/// gift panel, on the quip bubble and in the host's soundboard (the
/// viewer's ≡ sheet of D151 does not exist yet).
class QuipsMuted extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final NotifierProvider<QuipsMuted, bool> quipsMutedProvider =
    NotifierProvider<QuipsMuted, bool>(QuipsMuted.new);

/// Plays one quip's bundled sound (`assets/sounds/quips/<soundKey>.mp3`).
abstract interface class QuipAudio {
  Future<void> play(String soundKey);

  Future<void> stop();

  Future<void> dispose();
}

/// Plays quips with `audioplayers`, as the owner's reference player does
/// (`kabso_room_sounds.dart`): on Android without audio focus, mixed with
/// the live's own audio (`mixWithOthers`) and silent when the phone is on
/// silent (`respectSilence`); on iOS the live owns the audio session. One
/// player: a new quip stops the one before. Never throws.
class AudioplayersQuipAudio implements QuipAudio {
  new({AudioPlayer Function()? createPlayer})
    : _create = createPlayer ?? AudioPlayer.new;

  /// Off in widget tests (no audio plugin there;
  /// `test/flutter_test_config.dart`).
  static bool enabled = true;

  /// The asset of [soundKey] (`room/clap` → `sounds/quips/room/clap.mp3`).
  static String assetOf(String soundKey) => 'sounds/quips/$soundKey.mp3';

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
  Future<void> play(String soundKey) async {
    if (!enabled || _disposed || kIsWeb) return;
    try {
      final p = _player ??= await _make();
      if (_disposed) return;
      await p.stop();
      await p.play(AssetSource(assetOf(soundKey)), volume: 0.9);
    } on Object catch (e) {
      // No sound on this device: the bubble still shows the words.
      debugPrint('QuipAudio($soundKey): $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } on Object {
      // Nothing playing.
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

final Provider<QuipAudio> quipAudioProvider = Provider<QuipAudio>((ref) {
  final audio = AudioplayersQuipAudio();
  ref.onDispose(() => unawaited(audio.dispose()));
  return audio;
});

/// D154 («إفيهات», CONVENTIONS §10.33): the quips of one live. The server
/// queues every quip of the room and sends it with `delayMs` (topic
/// `quip`); this plays each one that long after it arrived, one at a time
/// (a late one waits for the one playing), its sound from the app's files
/// — only while the app's **Sound effects** setting is on, quips are not
/// muted on this phone ([quipsMutedProvider]) and the app is in the
/// foreground — and exposes it for its `durationMs` as the room's quip bubble
/// (the words show even when muted). A quip from someone this person
/// blocked is skipped (best effort: the block list the room's chat loaded).
class LiveQuips extends Notifier<LiveQuip?> {
  new(this.roomId);

  final String roomId;

  /// At most this many wait for their turn on this phone.
  static const maxWaiting = 12;

  /// Whether the app is in the foreground (tests replace it).
  @visibleForTesting
  static bool Function() foreground = () {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  };

  StreamSubscription<LiveChatEvent>? _events;
  final _timers = <Timer>{};
  Timer? _playing;
  final _waiting = <LiveQuip>[];
  final _seen = <String>{};

  @override
  LiveQuip? build() {
    ref
      ..onDispose(() {
        unawaited(_events?.cancel());
        for (final t in _timers) {
          t.cancel();
        }
        _playing?.cancel();
      })
      // Muting stops the sound at once (the bubble stays).
      ..listen(quipsMutedProvider, (_, muted) {
        if (muted) unawaited(ref.read(quipAudioProvider).stop());
      });
    return null;
  }

  /// Plays the [engine]'s `quip` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LiveQuipReceived) receive(event.quip);
    });
  }

  /// Takes [quip] (a data message, or the sender's own answer): it plays
  /// `delayMs` from now, once.
  void receive(LiveQuip quip) {
    if (!ref.mounted || quip.roomId != roomId) return;
    if (!_seen.add(quip.id) || _blocked(quip.sender.id)) return;
    late final Timer timer;
    timer = Timer(Duration(milliseconds: quip.delayMs), () {
      _timers.remove(timer);
      _ready(quip);
    });
    _timers.add(timer);
  }

  void _ready(LiveQuip quip) {
    if (!ref.mounted) return;
    if (state == null) {
      _start(quip);
    } else if (_waiting.length < maxWaiting) {
      _waiting.add(quip);
    }
  }

  void _start(LiveQuip quip) {
    state = quip;
    if (ref.read(soundEffectsProvider) &&
        !ref.read(quipsMutedProvider) &&
        foreground()) {
      unawaited(ref.read(quipAudioProvider).play(quip.soundKey));
    }
    _playing?.cancel();
    _playing = Timer(Duration(milliseconds: quip.durationMs), _finish);
  }

  void _finish() {
    if (!ref.mounted) return;
    state = null;
    if (_waiting.isNotEmpty) _start(_waiting.removeAt(0));
  }

  bool _blocked(String userId) {
    try {
      return ref.read(liveChatProvider(roomId).notifier).isBlocked(userId);
    } on Object {
      return false;
    }
  }
}

final NotifierProviderFamily<LiveQuips, LiveQuip?, String> liveQuipsProvider =
    NotifierProvider.autoDispose.family<LiveQuips, LiveQuip?, String>(
      LiveQuips.new,
    );
