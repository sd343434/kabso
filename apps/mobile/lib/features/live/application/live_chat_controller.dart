import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;
import 'package:kabso_live/features/safety/safety_repository.dart';

/// A line of the room chat on screen.
sealed class LiveChatItem {
  const new();

  /// Stable across rebuilds (widget keys).
  String get key;
}

/// A message the server stored.
final class LiveChatPosted extends LiveChatItem {
  const new(this.entry);

  final LiveChatEntry entry;

  @override
  String get key => 'm:${entry.id}';
}

/// This person's message on its way, or [failed] (kept with a retry).
final class LiveChatPending extends LiveChatItem {
  const new({
    required this.clientId,
    required this.text,
    required this.authorName,
    this.failed = false,
  });

  final String clientId;
  final String text;

  /// This person's display name.
  final String authorName;
  final bool failed;

  @override
  String get key => 'p:$clientId';
}

/// "X joined" (signed-in viewers, at most one a second per room).
final class LiveChatJoinLine extends LiveChatItem {
  const new(this.user, this.serial);

  final UserSummary user;
  final int serial;

  @override
  String get key => 'j:$serial';
}

/// CP-017 (owner, 2026-10-26): a bullet ("public message") in the chat, as
/// a box of its own; it stays like a message.
final class LiveChatBulletLine extends LiveChatItem {
  const new(this.bullet);

  final LiveBullet bullet;

  @override
  String get key => 'b:${bullet.id}';
}

class LiveChatState {
  const new({
    this.items = const [],
    this.enabled = true,
    this.muted = false,
    this.loaded = false,
    this.kicked = false,
  });

  /// v1.20-live (D105): this person was kicked out of the live (the kick
  /// data message named them, or the server answered `LIVE_KICKED`).
  final bool kicked;

  /// Oldest first.
  final List<LiveChatItem> items;

  /// The host has not turned the chat off.
  final bool enabled;

  /// The host or a moderator muted this person in this live's chat.
  final bool muted;

  /// The last messages were read (or failed to; the live ones still come).
  final bool loaded;

  LiveChatState copyWith({
    List<LiveChatItem>? items,
    bool? enabled,
    bool? muted,
    bool? loaded,
    bool? kicked,
  }) => LiveChatState(
    items: items ?? this.items,
    enabled: enabled ?? this.enabled,
    muted: muted ?? this.muted,
    loaded: loaded ?? this.loaded,
    kicked: kicked ?? this.kicked,
  );
}

/// The room chat of one live (CP-013, CONVENTIONS §10.11): the last
/// messages from the API, then the server's data messages from the media
/// room; sending, deleting, muting, the host's chat switch and reports.
///
/// The screen that owns the media session [attach]es its engine once.
class LiveChatController extends Notifier<LiveChatState> {
  new(this.roomId);

  final String roomId;

  /// Lines kept on screen (the API returns the last 50 too).
  static const maxLines = 50;

  /// CP-017: how long a voice clip or picture stays (§10.19).
  static const mediaLifetime = Duration(seconds: 60);

  late LiveRepository _repo;
  StreamSubscription<LiveChatEvent>? _events;
  final _blocked = <String>{};
  final _random = Random.secure();
  int _serial = 0;
  bool _attached = false;

  /// CP-017: when each VOICE / IMAGE message goes (message id → timer).
  final _expiry = <String, Timer>{};

  /// Bullets already queued or shown (a data message may come twice).
  final _bulletIds = <String>{};

  @override
  LiveChatState build() {
    _repo = ref.read(liveRepositoryProvider);
    ref.onDispose(() {
      unawaited(_events?.cancel());
      for (final timer in _expiry.values) {
        timer.cancel();
      }
      _expiry.clear();
    });
    return const LiveChatState();
  }

  /// Whether [entry] can be shown: a VOICE or IMAGE message needs its media
  /// (null once it expired, §10.19).
  static bool _showable(LiveChatEntry entry) =>
      entry.kind == LiveChatKind.text || entry.media != null;

  /// Hides a VOICE / IMAGE message at its `expiresAt`. A message that just
  /// arrived ([fresh]) lives as long as the server gave it from sending
  /// (no synced clock needed); one from the list lives until `expiresAt` by
  /// this device's clock. Returns false when it is already gone.
  bool _scheduleExpiry(LiveChatEntry entry, {required bool fresh}) {
    final expiresAt = entry.expiresAt;
    if (entry.kind == LiveChatKind.text) return true;
    var left = expiresAt == null
        ? mediaLifetime
        : fresh
        ? expiresAt.difference(entry.createdAt)
        : expiresAt.difference(clock.now());
    if (left > mediaLifetime) left = mediaLifetime;
    if (left <= Duration.zero) return false;
    _expiry[entry.id]?.cancel();
    _expiry[entry.id] = Timer(left, () => _expire(entry.id));
    return true;
  }

  void _expire(String id) {
    _expiry.remove(id)?.cancel();
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [
        for (final it in state.items)
          if (it is! LiveChatPosted || it.entry.id != id) it,
      ],
    );
  }

  /// CP-017: [bullet] joins the chat once (by id).
  void _addBullet(LiveBullet bullet) {
    if (!_bulletIds.add(bullet.id)) return;
    state = state.copyWith(
      items: _trim([...state.items, LiveChatBulletLine(bullet)]),
    );
  }

  /// Starts the chat with the room's [enabled] / [muted] and the [engine]'s
  /// data messages. Later calls only update [enabled] / [muted].
  Future<void> attach(
    LiveMediaEngine engine, {
    required bool enabled,
    required bool muted,
  }) async {
    state = state.copyWith(enabled: enabled, muted: muted);
    if (_attached) return;
    _attached = true;
    _events = engine.chatEvents.listen(_onEvent);
    unawaited(_loadBlocks());
    try {
      final messages = [
        for (final m in await _repo.chatMessages(roomId))
          if (_showable(m) && _scheduleExpiry(m, fresh: false)) m,
      ];
      if (!ref.mounted) return;
      // Live messages may have arrived first: keep them, without doubles.
      final known = {for (final m in messages) m.id};
      final live = state.items.where(
        (i) => i is! LiveChatPosted || !known.contains(i.entry.id),
      );
      state = state.copyWith(
        items: _trim([...messages.map(LiveChatPosted.new), ...live]),
        loaded: true,
      );
    } on Object {
      if (ref.mounted) state = state.copyWith(loaded: true);
    }
  }

  /// The people this person blocked (`GET /me/blocks`): their live lines
  /// are hidden (the API already leaves them out of the last messages).
  Future<void> _loadBlocks() async {
    if (ref.read(currentUserProvider) == null) return;
    final safety = ref.read(safetyRepositoryProvider);
    String? cursor;
    try {
      // Bounded: 10 pages of blocks.
      for (var page = 0; page < 10; page++) {
        final result = await safety.blocks(cursor: cursor);
        _blocked.addAll(result.items.map((u) => u.id));
        cursor = result.next;
        if (cursor == null) break;
      }
    } on Object {
      // Best effort: the server filters the last messages anyway.
    }
  }

  void _onEvent(LiveChatEvent event) {
    if (!ref.mounted) return;
    final me = ref.read(currentUserProvider);
    switch (event) {
      case LiveChatReceived(:final message):
        if (_blocked.contains(message.author.id)) return;
        if (_has(message.id) || !_showable(message)) return;
        if (!_scheduleExpiry(message, fresh: true)) return;
        var items = state.items;
        if (me != null && message.author.id == me.id) {
          // Our own message, before the API answered: it replaces the
          // pending line.
          final i = items.indexWhere(
            (it) =>
                it is LiveChatPending && !it.failed && it.text == message.text,
          );
          if (i >= 0) items = [...items]..removeAt(i);
        }
        state = state.copyWith(
          items: _trim([...items, LiveChatPosted(message)]),
        );
      case LiveChatDeleted(:final id):
        _expiry.remove(id)?.cancel();
        state = state.copyWith(
          items: [
            for (final it in state.items)
              if (it is! LiveChatPosted || it.entry.id != id) it,
          ],
        );
      case LiveChatJoined(:final user):
        if (_blocked.contains(user.id) || user.id == me?.id) return;
        state = state.copyWith(
          items: _trim([...state.items, LiveChatJoinLine(user, _serial++)]),
        );
      case LiveChatStateChanged(:final enabled):
        state = state.copyWith(enabled: enabled);
      case LiveKickReceived(:final user):
        if (user.id == me?.id) state = state.copyWith(kicked: true);
      case LiveBulletReceived(:final bullet):
        // Hidden from people this person blocked (§10.19).
        if (_blocked.contains(bullet.sender.id)) return;
        _addBullet(bullet);
    }
  }

  bool _has(String id) =>
      state.items.any((it) => it is LiveChatPosted && it.entry.id == id);

  /// Keeps the newest [maxLines] lines; this person's pending ones stay.
  List<LiveChatItem> _trim(List<LiveChatItem> items) {
    var extra = items.length - maxLines;
    if (extra <= 0) return items;
    final kept = <LiveChatItem>[];
    for (final it in items) {
      if (extra > 0 && it is! LiveChatPending) {
        extra--;
        continue;
      }
      kept.add(it);
    }
    return kept;
  }

  /// Sends [text] (trimmed). Returns why it was refused, or `null`.
  Future<AppFailure?> send(String text, {String? retryOf}) async {
    final me = ref.read(currentUserProvider);
    final trimmed = text.trim();
    if (me == null || trimmed.isEmpty) return null;
    final clientId = retryOf ?? _uuidV4();
    final pending = LiveChatPending(
      clientId: clientId,
      text: trimmed,
      authorName: me.displayName,
    );
    state = state.copyWith(
      items: [
        for (final it in state.items)
          if (it is! LiveChatPending || it.clientId != clientId) it,
        pending,
      ],
    );
    try {
      final message = await _repo.sendChat(
        roomId,
        text: trimmed,
        clientId: clientId,
      );
      if (!ref.mounted) return null;
      final items = [
        for (final it in state.items)
          if (it is! LiveChatPending || it.clientId != clientId) it,
      ];
      state = state.copyWith(
        items: _has(message.id)
            ? items
            : _trim([...items, LiveChatPosted(message)]),
      );
      return null;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!ref.mounted) return failure;
      final code = failure.code;
      // Refused for good: the line goes and the composer says why.
      final gone =
          code == ErrorCode.liveChatMuted || code == ErrorCode.liveChatClosed;
      final items = <LiveChatItem>[];
      for (final it in state.items) {
        if (it is! LiveChatPending || it.clientId != clientId) {
          items.add(it);
        } else if (!gone) {
          items.add(
            LiveChatPending(
              clientId: clientId,
              text: trimmed,
              authorName: me.displayName,
              failed: true,
            ),
          );
        }
      }
      state = state.copyWith(
        muted: code == ErrorCode.liveChatMuted ? true : null,
        enabled: code == ErrorCode.liveChatClosed ? false : null,
        kicked: code == ErrorCode.liveKicked ? true : null,
        items: items,
      );
      return failure;
    }
  }

  /// CP-017: uploads a voice clip or picture ([kind]; [bytes] of
  /// [contentType], already checked) and sends it. Returns why it failed, or
  /// `null`. It finishes even if the chat box closed meanwhile.
  Future<AppFailure?> uploadAndSend(
    Uint8List bytes,
    String contentType, {
    required LiveChatKind kind,
  }) async {
    final String mediaId;
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadLiveChatMedia(
            bytes,
            contentType,
            voice: kind == LiveChatKind.voice,
          );
      mediaId = asset.id;
    } on Object catch (e) {
      return toAppFailure(e);
    }
    if (!ref.mounted) return null;
    final failure = await sendMedia(kind: kind, mediaId: mediaId);
    return failure;
  }

  /// CP-017: sends an uploaded voice clip or picture ([kind], [mediaId]).
  /// Returns why it was refused, or `null`.
  Future<AppFailure?> sendMedia({
    required LiveChatKind kind,
    required String mediaId,
  }) async {
    if (ref.read(currentUserProvider) == null) return null;
    try {
      final message = await _repo.sendChatMedia(
        roomId,
        kind: kind,
        mediaId: mediaId,
        clientId: _uuidV4(),
      );
      if (!ref.mounted) return null;
      if (!_has(message.id) &&
          _showable(message) &&
          _scheduleExpiry(message, fresh: true)) {
        state = state.copyWith(
          items: _trim([...state.items, LiveChatPosted(message)]),
        );
      }
      return null;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!ref.mounted) return failure;
      final code = failure.code;
      state = state.copyWith(
        muted: code == ErrorCode.liveChatMuted ? true : null,
        enabled: code == ErrorCode.liveChatClosed ? false : null,
        kicked: code == ErrorCode.liveKicked ? true : null,
      );
      return failure;
    }
  }

  /// CP-017: sends [text] (trimmed) as a bullet over every live for 15
  /// coins; the balance follows the answer. Returns why it was refused, or
  /// `null`.
  Future<AppFailure?> sendBullet(String text) async {
    final trimmed = text.trim();
    if (ref.read(currentUserProvider) == null || trimmed.isEmpty) return null;
    try {
      final result = await _repo.sendBullet(
        roomId,
        text: trimmed,
        clientId: _uuidV4(),
      );
      if (ref.mounted) {
        ref.read(liveCoinsProvider.notifier).set(result.coins);
        // In the chat at once; the room's copy of it is not added again.
        _addBullet(result.bullet);
      }
      return null;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!ref.mounted) return failure;
      if (failure.code == ErrorCode.insufficientCoins) {
        // Show the real balance again.
        ref.invalidate(liveCoinsProvider);
      }
      if (failure.code == ErrorCode.liveChatMuted) {
        state = state.copyWith(muted: true);
      }
      if (failure.code == ErrorCode.liveKicked) {
        state = state.copyWith(kicked: true);
      }
      return failure;
    }
  }

  /// Sends a failed line again (same `clientId`: never twice).
  Future<AppFailure?> retry(LiveChatPending line) =>
      send(line.text, retryOf: line.clientId);

  /// Drops a failed line.
  void discard(LiveChatPending line) => state = state.copyWith(
    items: [
      for (final it in state.items)
        if (it is! LiveChatPending || it.clientId != line.clientId) it,
    ],
  );

  /// The author, the host or a moderator. Throws an AppFailure.
  Future<void> delete(LiveChatEntry entry) async {
    await _repo.deleteChat(roomId, entry.id);
    if (!ref.mounted) return;
    _onEvent(LiveChatDeleted(entry.id));
  }

  /// The host or a moderator. Throws an AppFailure.
  Future<void> setMuted(String username, {required bool muted}) =>
      _repo.setChatMuted(roomId, username, muted: muted);

  /// Reads the room again for [LiveChatState.muted] and `enabled`: an
  /// unmute reaches nobody live (§10.11), so a muted person asks when they
  /// try to write. Failures keep the current state.
  Future<void> refresh() async {
    try {
      final room = await _repo.getRoom(roomId);
      if (ref.mounted) {
        state = state.copyWith(
          muted: room.chatMuted,
          enabled: room.chatEnabled,
        );
      }
    } on Object {
      // Kept.
    }
  }

  /// Who is muted in this live's chat (host, moderator). Throws an
  /// AppFailure.
  Future<List<LiveChatMute>> mutes() => _repo.chatMutes(roomId);

  /// The host. Throws an AppFailure.
  Future<void> setEnabled({required bool enabled}) async {
    final room = await _repo.setChatEnabled(roomId, enabled: enabled);
    if (ref.mounted) state = state.copyWith(enabled: room.chatEnabled);
  }

  /// Throws an AppFailure.
  Future<void> report(LiveChatEntry entry, ReportReason reason) =>
      _repo.reportChatMessage(entry.id, reason);

  String _uuidV4() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    final variant = (8 + _random.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }
}

final NotifierProviderFamily<LiveChatController, LiveChatState, String>
liveChatProvider = NotifierProvider.autoDispose
    .family<LiveChatController, LiveChatState, String>(LiveChatController.new);
