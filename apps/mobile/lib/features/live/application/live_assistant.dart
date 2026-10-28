import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';

/// The kinds of hint the live assistant gives (D154f, owner item 11); each
/// can be turned off.
enum LiveAssistantKind {
  /// Someone joined: welcome them.
  welcome,

  /// A big gift arrived: thank its sender.
  thank,

  /// The host has been quiet for a while (microphone on).
  silence,

  /// More / fewer people than a few minutes ago.
  audience,

  /// A long live: a short break.
  rest,

  /// Few chat messages: ask the room a question.
  question,
}

/// One hint: its kind, the people it names (welcome, thank) and a number
/// (how many more joined; the viewers then and now; hours on air).
typedef LiveAssistantHint = ({
  LiveAssistantKind kind,
  String? name,
  int count,
  int other,
});

/// The rules, as plain Dart so they are tested without a room (D154f:
/// rule-based, from the room's own events, nothing leaves the phone).
/// Every `on…` call takes the time it happened and may return a hint.
class LiveAssistantRules {
  new({required this.startedAt, this.selfId});

  final DateTime startedAt;

  /// The host's id (their own join or gift is not a hint).
  final String? selfId;

  /// A gift of at least this many coins is a "big" one.
  static const bigGiftCoins = 500;
  static const welcomeGap = Duration(seconds: 90);
  static const thankGap = Duration(seconds: 20);
  static const silenceAfter = Duration(minutes: 3);
  static const silenceGap = Duration(minutes: 5);
  static const audienceWindow = Duration(minutes: 5);
  static const audienceGap = Duration(minutes: 10);
  static const restEvery = Duration(hours: 2);
  static const questionWindow = Duration(minutes: 5);
  static const questionGap = Duration(minutes: 10);

  final _last = <LiveAssistantKind, DateTime>{};
  final _joined = <String>[];
  final _chats = <DateTime>[];
  final _viewers = <(DateTime, int)>[];
  DateTime? _spoke;
  int _restsGiven = 0;

  bool _due(LiveAssistantKind kind, DateTime now, Duration gap) {
    final last = _last[kind];
    return last == null || now.difference(last) >= gap;
  }

  LiveAssistantHint _hint(
    LiveAssistantKind kind,
    DateTime now, {
    String? name,
    int count = 0,
    int other = 0,
  }) {
    _last[kind] = now;
    return (kind: kind, name: name, count: count, other: other);
  }

  /// Someone joined; a welcome for the people since the last one, at most
  /// every [welcomeGap].
  LiveAssistantHint? onJoin(UserSummary user, DateTime now) {
    if (user.id == selfId) return null;
    if (!_joined.contains(user.displayName)) _joined.add(user.displayName);
    return welcomeDue(now);
  }

  LiveAssistantHint? welcomeDue(DateTime now) {
    if (_joined.isEmpty || !_due(LiveAssistantKind.welcome, now, welcomeGap)) {
      return null;
    }
    final hint = _hint(
      LiveAssistantKind.welcome,
      now,
      name: _joined.first,
      count: _joined.length - 1,
    );
    _joined.clear();
    return hint;
  }

  /// A gift arrived; a big one (not the host's own) is a thank-you.
  LiveAssistantHint? onGift(UserSummary sender, int coins, DateTime now) {
    if (sender.id == selfId || coins < bigGiftCoins) return null;
    if (!_due(LiveAssistantKind.thank, now, thankGap)) return null;
    return _hint(
      LiveAssistantKind.thank,
      now,
      name: sender.displayName,
      count: coins,
    );
  }

  /// A chat message (anyone's, the host's too).
  void onChat(DateTime now) => _chats.add(now);

  /// The time-based rules: [speaking] whether the host speaks now, [micOn]
  /// their microphone, [viewers] the people in the room now (null:
  /// unknown).
  LiveAssistantHint? tick(
    DateTime now, {
    required bool speaking,
    required bool micOn,
    int? viewers,
  }) {
    if (speaking || !micOn) _spoke = now;
    _spoke ??= startedAt.isAfter(now) ? now : startedAt;
    _chats.removeWhere((t) => now.difference(t) > questionWindow);
    if (viewers != null) {
      _viewers
        ..add((now, viewers))
        ..removeWhere((v) => now.difference(v.$1) > audienceWindow * 2);
    }
    final onAir = now.difference(startedAt);

    // A long live: a break every two hours.
    if (onAir >= restEvery * (_restsGiven + 1)) {
      _restsGiven = onAir.inMinutes ~/ restEvery.inMinutes;
      return _hint(LiveAssistantKind.rest, now, count: onAir.inHours);
    }
    if (now.difference(_spoke!) >= silenceAfter &&
        _due(LiveAssistantKind.silence, now, silenceGap)) {
      return _hint(
        LiveAssistantKind.silence,
        now,
        count: now.difference(_spoke!).inMinutes,
      );
    }
    if (viewers != null && _due(LiveAssistantKind.audience, now, audienceGap)) {
      final then = _viewers
          .where((v) => now.difference(v.$1) >= audienceWindow)
          .lastOrNull;
      if (then != null) {
        final before = then.$2;
        if (viewers - before >= 5 && viewers >= before * 1.5) {
          return _hint(
            LiveAssistantKind.audience,
            now,
            count: viewers,
            other: before,
          );
        }
        if (before - viewers >= 3 && viewers <= before * 0.7) {
          return _hint(
            LiveAssistantKind.audience,
            now,
            count: viewers,
            other: before,
          );
        }
      }
    }
    if (onAir >= questionWindow &&
        (viewers ?? 0) >= 3 &&
        _chats.length < 2 &&
        _due(LiveAssistantKind.question, now, questionGap)) {
      return _hint(LiveAssistantKind.question, now);
    }
    return welcomeDue(now);
  }
}

/// The host's choices for the assistant on this phone (D154f): on/off and
/// the kinds turned off. On, every kind, by default.
typedef LiveAssistantSettingsState = ({
  bool enabled,
  Set<LiveAssistantKind> off,
});

class LiveAssistantSettings extends Notifier<LiveAssistantSettingsState> {
  static const enabledKey = 'liveAssistant.enabled';
  static const offKey = 'liveAssistant.off';

  @override
  LiveAssistantSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final off = prefs.getStringList(offKey) ?? const [];
    return (
      enabled: prefs.getBool(enabledKey) ?? true,
      off: {
        for (final k in LiveAssistantKind.values)
          if (off.contains(k.name)) k,
      },
    );
  }

  void setEnabled({required bool enabled}) {
    unawaited(ref.read(sharedPreferencesProvider).setBool(enabledKey, enabled));
    state = (enabled: enabled, off: state.off);
  }

  void setKind(LiveAssistantKind kind, {required bool on}) {
    final off = {...state.off};
    on ? off.remove(kind) : off.add(kind);
    unawaited(
      ref.read(sharedPreferencesProvider).setStringList(offKey, [
        for (final k in off) k.name,
      ]),
    );
    state = (enabled: state.enabled, off: off);
  }

  bool allows(LiveAssistantKind kind) =>
      state.enabled && !state.off.contains(kind);
}

final NotifierProvider<LiveAssistantSettings, LiveAssistantSettingsState>
liveAssistantSettingsProvider =
    NotifierProvider<LiveAssistantSettings, LiveAssistantSettingsState>(
      LiveAssistantSettings.new,
    );

/// D154f («مساعد البث», owner item 11): the host's assistant in their own
/// live — light hints that never block anything (one at a time, gone after
/// [showTime] or a tap), from the room's own events ([LiveAssistantRules]):
/// joins, gifts and chat from the media room, the host's speaking and
/// microphone from the engine and the viewers the host screen already
/// polls ([viewers]). Only the host's phone runs it; nothing is sent.
class LiveAssistant extends Notifier<LiveAssistantHint?> {
  new(this.roomId);

  final String roomId;

  static const showTime = Duration(seconds: 8);
  static const tickEvery = Duration(seconds: 15);

  LiveAssistantRules? _rules;
  LiveMediaEngine? _engine;
  String? _self;
  int? _viewers;
  StreamSubscription<LiveChatEvent>? _events;
  Timer? _tick;
  Timer? _hide;

  @override
  LiveAssistantHint? build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _tick?.cancel();
      _hide?.cancel();
    });
    return null;
  }

  /// Starts on the host's [engine] for a live that started at [startedAt]
  /// (once). [selfId]: the host.
  void attach(
    LiveMediaEngine engine, {
    required DateTime startedAt,
    required String? selfId,
  }) {
    if (_rules != null) return;
    _engine = engine;
    _self = selfId;
    _rules = LiveAssistantRules(startedAt: startedAt, selfId: selfId);
    _events = engine.chatEvents.listen(_onEvent);
    _tick = Timer.periodic(tickEvery, (_) => check());
  }

  /// The people in the room now (the host screen's viewer list).
  // ignore: avoid_setters_without_getters, the screen feeds it.
  set viewers(int? count) => _viewers = count;

  void _onEvent(LiveChatEvent event) {
    final rules = _rules;
    if (rules == null) return;
    final now = clock.now();
    switch (event) {
      case LiveChatJoined(:final user):
        _offer(rules.onJoin(user, now));
      case LiveGiftReceived(:final gift):
        _offer(rules.onGift(gift.sender, gift.totalCoins, now));
      case LiveChatReceived():
        rules.onChat(now);
      default:
        break;
    }
  }

  /// Runs the time-based rules now (every [tickEvery]).
  void check() {
    final rules = _rules;
    final engine = _engine;
    if (rules == null || engine == null || !ref.mounted) return;
    _offer(
      rules.tick(
        clock.now(),
        speaking: _self != null && engine.speaking.contains(_self),
        micOn: engine.micEnabled,
        viewers: _viewers,
      ),
    );
  }

  void _offer(LiveAssistantHint? hint) {
    if (hint == null || !ref.mounted) return;
    if (!ref.read(liveAssistantSettingsProvider.notifier).allows(hint.kind)) {
      return;
    }
    // A thank-you replaces anything; others wait for the screen to clear.
    if (state != null && hint.kind != LiveAssistantKind.thank) return;
    _hide?.cancel();
    _hide = Timer(showTime, dismiss);
    state = hint;
  }

  void dismiss() {
    _hide?.cancel();
    if (ref.mounted) state = null;
  }
}

final NotifierProviderFamily<LiveAssistant, LiveAssistantHint?, String>
liveAssistantProvider =
    NotifierProvider.family<LiveAssistant, LiveAssistantHint?, String>(
      LiveAssistant.new,
    );
