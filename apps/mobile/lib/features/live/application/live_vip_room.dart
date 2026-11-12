import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_vip_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';

/// v1.132-social (D379, CONVENTIONS §10.169): what the VIP perks put on a
/// live's screen — the pinned message (PINNED_MESSAGE), the host's greeting
/// card (HOST_GREETING) and the uploaded rain effect (BIG_GIFT_RAIN).
@immutable
class LiveVipRoomState {
  const new({this.pin, this.pinLeft, this.greeting, this.rain});

  /// The pin showing now, and how long it has left from when it arrived.
  final LiveChatPin? pin;
  final Duration? pinLeft;

  /// The newest member holding HOST_GREETING who joined (only the host's
  /// screen shows it), or null.
  final UserSummary? greeting;

  /// The rain playing now, or null.
  final VipGiftRain? rain;

  LiveVipRoomState copyWith({
    LiveChatPin? Function()? pin,
    Duration? Function()? pinLeft,
    UserSummary? Function()? greeting,
    VipGiftRain? Function()? rain,
  }) => LiveVipRoomState(
    pin: pin == null ? this.pin : pin(),
    pinLeft: pinLeft == null ? this.pinLeft : pinLeft(),
    greeting: greeting == null ? this.greeting : greeting(),
    rain: rain == null ? this.rain : rain(),
  );
}

/// D379: one live's VIP pin, greeting card and rain effect, from the room's
/// data messages (`chat-pin`, `chat-unpin`, `chat-delete`, `join` with
/// `hostGreeting`, `vip-rain`). A pin or rain by someone this person blocked
/// is not shown.
class LiveVipRoom extends Notifier<LiveVipRoomState> {
  new(this.roomId);

  final String roomId;

  /// A greeting card goes by itself after this long.
  static const greetingTime = Duration(seconds: 8);

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _pinTimer;
  Timer? _greetTimer;
  Timer? _rainTimer;
  final _rained = <String>{};

  @override
  LiveVipRoomState build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _pinTimer?.cancel();
      _greetTimer?.cancel();
      _rainTimer?.cancel();
    });
    return const LiveVipRoomState();
  }

  /// Follows [engine]'s data messages from now on (once), and reads the pin
  /// showing now.
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen(onEvent);
    unawaited(_loadPin());
  }

  Future<void> _loadPin() async {
    try {
      final pin = await ref.read(liveVipRepositoryProvider).currentPin(roomId);
      if (!ref.mounted || pin == null || state.pin != null) return;
      // Read from the list: its time left by this device's clock, never more
      // than its whole length.
      var left = pin.until.difference(clock.now());
      if (left > pin.length) left = pin.length;
      if (left > Duration.zero) _showPin(pin, left);
    } on Object {
      // Best effort: the next pin arrives as a data message.
    }
  }

  bool _blocked(String userId) {
    try {
      return ref.read(liveChatProvider(roomId).notifier).isBlocked(userId);
    } on Object {
      return false;
    }
  }

  /// Applies one data message (the engine's, or a test's).
  @visibleForTesting
  void onEvent(LiveChatEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case LiveChatPinned(:final pin):
        if (pin.roomId != roomId || _blocked(pin.author.id)) return;
        // A fresh pin shows for its whole length (no synced clock needed).
        _showPin(pin, pin.length);
      case LiveChatUnpinned(:final id):
        if (state.pin?.id == id) _clearPin();
      case LiveChatDeleted(:final id):
        if (state.pin?.messageId == id) _clearPin();
      case LiveChatJoined(:final user, :final hostGreeting):
        if (!hostGreeting || _blocked(user.id)) return;
        if (user.id == ref.read(currentUserProvider)?.id) return;
        _greetTimer?.cancel();
        state = state.copyWith(greeting: () => user);
        _greetTimer = Timer(greetingTime, dismissGreeting);
      case VipGiftRainReceived(:final rain):
        if (rain.roomId != roomId || !_rained.add(rain.giftId)) return;
        if (_blocked(rain.sender.id)) return;
        _rainTimer?.cancel();
        state = state.copyWith(rain: () => rain);
        _rainTimer = Timer(rain.duration, () {
          if (ref.mounted) state = state.copyWith(rain: () => null);
        });
      default:
        break;
    }
  }

  void _showPin(LiveChatPin pin, Duration left) {
    _pinTimer?.cancel();
    state = state.copyWith(pin: () => pin, pinLeft: () => left);
    _pinTimer = Timer(left, () {
      if (ref.mounted && state.pin?.id == pin.id) _clearPin();
    });
  }

  void _clearPin() {
    _pinTimer?.cancel();
    state = state.copyWith(pin: () => null, pinLeft: () => null);
  }

  /// Pins [entry] (the caller's own message). Returns why it was refused
  /// (`LIVE_PIN_BUSY`, `VIP_UNAVAILABLE` used up …), or null.
  Future<AppFailure?> pin(LiveChatEntry entry) async {
    try {
      final pin = await ref
          .read(liveVipRepositoryProvider)
          .pin(roomId, entry.id);
      if (ref.mounted) _showPin(pin, pin.length);
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }

  /// Takes the pin down (its author, the host or a moderator).
  Future<AppFailure?> unpin() async {
    try {
      await ref.read(liveVipRepositoryProvider).unpin(roomId);
      if (ref.mounted) _clearPin();
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }

  /// The host closed the greeting card (or greeted).
  void dismissGreeting() {
    _greetTimer?.cancel();
    if (ref.mounted) state = state.copyWith(greeting: () => null);
  }
}

final NotifierProviderFamily<LiveVipRoom, LiveVipRoomState, String>
liveVipRoomProvider = NotifierProvider.autoDispose
    .family<LiveVipRoom, LiveVipRoomState, String>(LiveVipRoom.new);
