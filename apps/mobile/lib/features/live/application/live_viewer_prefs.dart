import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D225: the chat's text size in a live, on this phone.
enum LiveChatTextSize {
  small(0.9),
  normal(1),
  large(1.2);

  new(this.scale);

  /// Multiplies the text scale the person already uses.
  final double scale;
}

/// D225 (owner, «إعدادات المشاهدة»): what a viewer sets for every live on
/// this phone — client only, nothing is sent and nobody else is affected.
/// Kept per device (shared preferences, not sensitive). This live's own
/// mute and volume are not here: they last one visit
/// (`LiveRoomSessionState.soundMuted`).
class LiveViewerPrefs {
  const new({
    this.giftSoundsMuted = false,
    this.giftEffectsHidden = false,
    this.entrancesHidden = false,
    this.chatTextSize = LiveChatTextSize.normal,
    this.dataSaver = false,
  });

  /// The gifts' sounds (their MP3 or the video's own sound) stay silent.
  final bool giftSoundsMuted;

  /// The big full-screen gift animations are skipped (the strip and the
  /// chat line still say who sent what).
  final bool giftEffectsHidden;

  /// The CP and recharge-agent entrance effects are not shown.
  final bool entrancesHidden;
  final LiveChatTextSize chatTextSize;

  /// Video lives play the sound only (the others' video is not received).
  final bool dataSaver;

  LiveViewerPrefs copyWith({
    bool? giftSoundsMuted,
    bool? giftEffectsHidden,
    bool? entrancesHidden,
    LiveChatTextSize? chatTextSize,
    bool? dataSaver,
  }) => LiveViewerPrefs(
    giftSoundsMuted: giftSoundsMuted ?? this.giftSoundsMuted,
    giftEffectsHidden: giftEffectsHidden ?? this.giftEffectsHidden,
    entrancesHidden: entrancesHidden ?? this.entrancesHidden,
    chatTextSize: chatTextSize ?? this.chatTextSize,
    dataSaver: dataSaver ?? this.dataSaver,
  );
}

class LiveViewerPrefsController extends Notifier<LiveViewerPrefs> {
  static const giftSoundsKey = 'pref.live.giftSoundsMuted';
  static const giftEffectsKey = 'pref.live.giftEffectsHidden';
  static const entrancesKey = 'pref.live.entrancesHidden';
  static const chatTextKey = 'pref.live.chatTextSize';
  static const dataSaverKey = 'pref.live.dataSaver';

  @override
  LiveViewerPrefs build() {
    try {
      final p = ref.read(sharedPreferencesProvider);
      return LiveViewerPrefs(
        giftSoundsMuted: p.getBool(giftSoundsKey) ?? false,
        giftEffectsHidden: p.getBool(giftEffectsKey) ?? false,
        entrancesHidden: p.getBool(entrancesKey) ?? false,
        chatTextSize:
            LiveChatTextSize.values
                .where((s) => s.name == p.getString(chatTextKey))
                .firstOrNull ??
            LiveChatTextSize.normal,
        dataSaver: p.getBool(dataSaverKey) ?? false,
      );
    } on Object {
      // No preferences (some tests): the defaults, kept in memory.
      return const LiveViewerPrefs();
    }
  }

  void _save(Future<bool> Function(SharedPreferences prefs) write) {
    try {
      unawaited(write(ref.read(sharedPreferencesProvider)));
    } on Object {
      // Kept in memory only.
    }
  }

  void setGiftSoundsMuted({required bool muted}) {
    state = state.copyWith(giftSoundsMuted: muted);
    _save((p) => p.setBool(giftSoundsKey, muted));
  }

  void setGiftEffectsHidden({required bool hidden}) {
    state = state.copyWith(giftEffectsHidden: hidden);
    _save((p) => p.setBool(giftEffectsKey, hidden));
  }

  void setEntrancesHidden({required bool hidden}) {
    state = state.copyWith(entrancesHidden: hidden);
    _save((p) => p.setBool(entrancesKey, hidden));
  }

  void setChatTextSize(LiveChatTextSize size) {
    state = state.copyWith(chatTextSize: size);
    _save((p) => p.setString(chatTextKey, size.name));
  }

  void setDataSaver({required bool on}) {
    state = state.copyWith(dataSaver: on);
    _save((p) => p.setBool(dataSaverKey, on));
  }
}

final NotifierProvider<LiveViewerPrefsController, LiveViewerPrefs>
liveViewerPrefsProvider =
    NotifierProvider<LiveViewerPrefsController, LiveViewerPrefs>(
      LiveViewerPrefsController.new,
    );
