import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_seat_emoji.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// One emoji playing on a tile now.
@immutable
final class SeatEmojiShow {
  const new({required this.id, required this.emoji});

  /// Names this play: a new one on the same tile restarts the animation.
  final String id;
  final KabsoEmoji emoji;
}

/// D138 (owner: «في البث الصوتي المستخدم يستخدمها على الكرسي … مرة واحدة
/// وتختفي دون تكرار تلقائي»): the emojis playing on the tiles of one room —
/// tile index (0 = the host) → what plays there. The `seat-emoji` data
/// messages of the media room fill it; the caller's own emoji shows at once
/// (before the server answers) and its echo is dropped. A new emoji on a
/// tile replaces the one playing there; the tile says when it has played
/// ([done]), and [maxTime] clears a tile that never says so (off screen).
class LiveSeatEmojis extends Notifier<Map<int, SeatEmojiShow>> {
  new(this.roomId);

  final String roomId;

  /// The longest an emoji stays on a tile (its 2 s cycle, the fade, room
  /// for a slow first load).
  static const maxTime = Duration(seconds: 6);

  StreamSubscription<LiveChatEvent>? _events;
  final _seen = <String>{};
  final _timers = <int, Timer>{};
  var _local = 0;

  @override
  Map<int, SeatEmojiShow> build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  /// Plays the [engine]'s `seat-emoji` messages from now on (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LiveSeatEmojiReceived) receive(event.emoji);
    });
  }

  /// A `seat-emoji` message: played unless it is the caller's own (already
  /// shown when it was sent) or seen before; unknown tokens are ignored.
  void receive(LiveSeatEmoji message) {
    if (!ref.mounted || !_seen.add(message.id)) return;
    if (_seen.length > 500) {
      _seen
        ..clear()
        ..add(message.id);
    }
    if (message.user.id == ref.read(currentUserProvider)?.id) return;
    final emoji = emojiOfToken(message.token);
    if (emoji == null) return;
    _play(message.seat, SeatEmojiShow(id: message.id, emoji: emoji));
  }

  /// Plays [emoji] on the caller's own tile [seat] at once and sends it;
  /// a refused send takes it off again and returns why.
  Future<AppFailure?> send({
    required int seat,
    required KabsoEmoji emoji,
  }) async {
    final local = SeatEmojiShow(id: 'local:${_local++}', emoji: emoji);
    _play(seat, local);
    try {
      final sent = await ref
          .read(liveRepositoryProvider)
          .sendSeatEmoji(roomId, emoji.token);
      _seen.add(sent.id);
      return null;
    } on AppFailure catch (failure) {
      if (ref.mounted && state[seat]?.id == local.id) done(seat, local.id);
      return failure;
    }
  }

  /// The tile [seat] has played [id] (or let it go).
  void done(int seat, String id) {
    if (!ref.mounted || state[seat]?.id != id) return;
    _timers.remove(seat)?.cancel();
    state = {...state}..remove(seat);
  }

  void _play(int seat, SeatEmojiShow show) {
    if (!ref.mounted) return;
    state = {...state, seat: show};
    _timers.remove(seat)?.cancel();
    _timers[seat] = Timer(maxTime, () => done(seat, show.id));
  }

  /// The pack emoji of `:<pack>_<id>:`, or null.
  static KabsoEmoji? emojiOfToken(String token) {
    final m = KabsoEmoji.tokenPattern.matchAsPrefix(token);
    if (m == null || m.end != token.length) return null;
    return KabsoEmoji.byKey(m.group(1)!);
  }
}

final NotifierProviderFamily<LiveSeatEmojis, Map<int, SeatEmojiShow>, String>
liveSeatEmojisProvider = NotifierProvider.autoDispose
    .family<LiveSeatEmojis, Map<int, SeatEmojiShow>, String>(
      LiveSeatEmojis.new,
    );
