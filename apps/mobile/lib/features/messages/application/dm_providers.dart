import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:material_ui/material_ui.dart';

/// D155 real time (CONVENTIONS §11.13): there is no socket for signed-in
/// users, so the badge and the list read the server every [dmUnreadPoll]
/// (and on resume, and at once when a `dm` push arrives); the open
/// conversation reads its newest page every [DmPollBackoff.fastest],
/// slowing to [DmPollBackoff.slowest] while nothing changes.
const Duration dmUnreadPoll = Duration(seconds: 30);

/// The open conversation's polling: every [fastest] after activity,
/// ×1.5 for each quiet poll up to [slowest].
class DmPollBackoff {
  new();

  static const fastest = Duration(seconds: 3);
  static const slowest = Duration(seconds: 15);

  Duration _next = fastest;

  /// The wait before the next poll.
  Duration get next => _next;

  /// After a poll: [changed] resets to [fastest], otherwise it slows down.
  Duration after({required bool changed}) => _next = changed
      ? fastest
      : Duration(
          milliseconds: math.min(
            slowest.inMilliseconds,
            (_next.inMilliseconds * 1.5).round(),
          ),
        );

  /// Something happened here (a send, a push): poll fast again.
  void reset() => _next = fastest;
}

/// Bumped when a `dm` push arrives while the app is open: the badge, the
/// list and the open conversation read the server at once.
class DmActivity extends Notifier<int> {
  @override
  int build() => 0;

  void ping() => state++;
}

final dmActivityProvider = NotifierProvider<DmActivity, int>(DmActivity.new);

/// Whether direct messages talk to the server: a real signed-in account
/// (demo data has no server).
bool _dmLive(Ref ref) =>
    ref.watch(currentUserProvider.select((u) => u?.id)) != null &&
    !watchDemo(ref);

/// `GET /dm/unread` for the Messages tab badge (D130 slot): accepted, not
/// muted conversations; requests are counted apart. A failed read keeps the
/// last counts (the badge is a hint, never an error).
class DmUnreadController extends Notifier<DmUnread> {
  Timer? _timer;

  @override
  DmUnread build() {
    if (!_dmLive(ref)) return const DmUnread();
    final repo = ref.watch(dmRepositoryProvider);
    ref.listen(dmActivityProvider, (_, _) => unawaited(refresh()));
    _timer = Timer.periodic(dmUnreadPoll, (_) => unawaited(refresh()));
    final lifecycle = AppLifecycleListener(
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(() {
      _timer?.cancel();
      lifecycle.dispose();
    });
    unawaited(_load(repo));
    return const DmUnread();
  }

  Future<void> _load(DmRepository repo) async {
    try {
      final next = await repo.unread();
      if (ref.mounted && next != state) state = next;
    } on Object {
      // Keep the last counts.
    }
  }

  /// Asks the server again.
  Future<void> refresh() => _load(ref.read(dmRepositoryProvider));
}

final NotifierProvider<DmUnreadController, DmUnread> dmUnreadProvider =
    NotifierProvider.autoDispose(DmUnreadController.new);

/// The conversation list of one box (the inbox, or the message requests).
@immutable
class DmInboxState {
  const new({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
  });

  final List<DmConversation> items;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  DmInboxState copyWith({
    List<DmConversation>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => DmInboxState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// `GET /dm/conversations` for the inbox (`false`) or the requests (`true`),
/// newest message first. [refresh] reads the first page again (polling,
/// pull-to-refresh, a `dm` push); [loadMore] pages on.
class DmInboxController extends AsyncNotifier<DmInboxState> {
  // The provider family's argument (the requests box or not).
  // ignore: avoid_positional_boolean_parameters
  new(this.requests);

  final bool requests;

  DmRepository get _repo => ref.read(dmRepositoryProvider);

  @override
  Future<DmInboxState> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await ref
        .watch(dmRepositoryProvider)
        .conversations(requests: requests);
    return DmInboxState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    try {
      final page = await _repo.conversations(requests: requests);
      if (!ref.mounted) return;
      final first = {for (final c in page.data) c.id};
      final rest = [
        for (final c
            in state.value?.items.skip(page.data.length) ?? <DmConversation>[])
          if (!first.contains(c.id)) c,
      ];
      state = AsyncData(
        DmInboxState(
          items: [...page.data, if (page.nextCursor != null) ...rest],
          nextCursor: page.nextCursor == null
              ? null
              : (state.value?.nextCursor ?? page.nextCursor),
        ),
      );
    } on Object {
      // The list keeps what it shows; the next poll tries again.
    }
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.conversations(
        requests: requests,
        cursor: s.nextCursor,
      );
      if (!ref.mounted) return;
      final known = {for (final c in s.items) c.id};
      state = AsyncData(
        DmInboxState(
          items: [
            ...s.items,
            for (final c in page.data)
              if (!known.contains(c.id)) c,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      if (ref.mounted) state = AsyncData(s.copyWith(loadingMore: false));
    }
  }

  /// A conversation left this box here (deleted, accepted, blocked).
  void drop(String conversationId) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
        items: [
          for (final c in s.items)
            if (c.id != conversationId) c,
        ],
      ),
    );
  }
}

final AsyncNotifierProviderFamily<DmInboxController, DmInboxState, bool>
dmInboxProvider = AsyncNotifierProvider.autoDispose
    .family<DmInboxController, DmInboxState, bool>(DmInboxController.new);

/// One conversation as the screen shows it: the peer (and whether the
/// caller may write), the conversation once it exists, and its messages
/// newest first.
@immutable
class DmChatState {
  const new({
    required this.peer,
    required this.messages,
    this.nextCursor,
    this.loadingMore = false,
  });

  final DmPeer peer;

  /// Newest first; only messages that have not expired.
  final List<DmMessage> messages;
  final String? nextCursor;
  final bool loadingMore;

  DmConversation? get conversation => peer.conversation;
  bool get hasMore => nextCursor != null;

  DmChatState copyWith({
    DmPeer? peer,
    List<DmMessage>? messages,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => DmChatState(
    peer: peer ?? this.peer,
    messages: messages ?? this.messages,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

DmPeer _withConversation(DmPeer peer, DmConversation conversation) => DmPeer(
  user: conversation.peer,
  conversation: conversation,
  canMessage: conversation.canSend,
  reason: conversation.canSend
      ? null
      : (peer.reason ??
            (conversation.status == DmConversationStatus.requestSent
                ? DmBlockedReason.requestLimit
                : DmBlockedReason.notAllowed)),
  asRequest: conversation.status == DmConversationStatus.requestSent,
);

/// The conversation with one username. A message sent keeps its `clientId`
/// until it is answered, so a retry after a lost answer is never a second
/// message.
class DmChatController extends AsyncNotifier<DmChatState> {
  new(this.username);

  final String username;
  final Map<String, String> _pending = {};

  DmRepository get _repo => ref.read(dmRepositoryProvider);

  @override
  Future<DmChatState> build() async {
    final repo = ref.watch(dmRepositoryProvider);
    final peer = await repo.peer(username);
    final conversation = peer.conversation;
    if (conversation == null) {
      return DmChatState(peer: peer, messages: const []);
    }
    final page = await repo.messages(conversation.id);
    return DmChatState(
      peer: _withConversation(peer, page.conversation),
      messages: page.data,
      nextCursor: page.nextCursor,
    );
  }

  /// Reads the newest page again and merges it: new messages appear, ones
  /// deleted or expired inside that page's range disappear, older pages
  /// stay (without the expired ones). Returns whether anything changed.
  Future<bool> refresh() async {
    final s = state.value;
    if (s == null) return false;
    final conversation = s.conversation;
    if (conversation == null) {
      // No conversation yet: the person may have written meanwhile.
      final peer = await _repo.peer(username);
      if (!ref.mounted || peer.conversation == null) return false;
      ref.invalidateSelf();
      return true;
    }
    final page = await _repo.messages(conversation.id);
    if (!ref.mounted) return false;
    final current = state.value ?? s;
    final now = DateTime.now();
    final fresh = page.data;
    final oldest = fresh.isEmpty ? null : fresh.last.createdAt;
    final kept = [
      for (final m in current.messages)
        if (oldest != null &&
            m.createdAt.isBefore(oldest) &&
            m.expiresAt.isAfter(now))
          m,
    ];
    final merged = [...fresh, ...kept];
    final changed =
        merged.length != current.messages.length ||
        [
          for (var i = 0; i < merged.length; i++)
            merged[i].id != current.messages[i].id ||
                merged[i].read != current.messages[i].read,
        ].any((c) => c) ||
        page.conversation.status != current.conversation?.status ||
        page.conversation.canSend != current.conversation?.canSend;
    state = AsyncData(
      current.copyWith(
        peer: _withConversation(current.peer, page.conversation),
        messages: merged,
      ),
    );
    return changed;
  }

  Future<void> loadMore() async {
    final s = state.value;
    final conversation = s?.conversation;
    if (s == null || conversation == null || !s.hasMore || s.loadingMore) {
      return;
    }
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.messages(conversation.id, cursor: s.nextCursor);
      if (!ref.mounted) return;
      final known = {for (final m in s.messages) m.id};
      state = AsyncData(
        DmChatState(
          peer: s.peer,
          messages: [
            ...s.messages,
            for (final m in page.data)
              if (!known.contains(m.id)) m,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      if (ref.mounted) state = AsyncData(s.copyWith(loadingMore: false));
      rethrow;
    }
  }

  void _put(DmSendResult result) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
        peer: _withConversation(s.peer, result.conversation),
        messages: [
          result.message,
          for (final m in s.messages)
            if (m.id != result.message.id) m,
        ],
      ),
    );
  }

  /// Sends [message] ([key] identifies it for a retry); throws the
  /// `AppFailure`.
  Future<DmSendResult> send(DmOutgoing message, {required String key}) async {
    final clientId = _pending[key] ??= newClientId();
    final result = await _repo.send(username, message, clientId: clientId);
    _pending.remove(key);
    if (ref.mounted) _put(result);
    return result;
  }

  /// A gift sent from the gift panel (its answer carries the message).
  void giftSent(DmSendResult result) => _put(result);

  /// Marks everything up to the newest received message as read. Returns
  /// whether the server was told (the badge then reads again).
  Future<bool> markRead() async {
    final s = state.value;
    final conversation = s?.conversation;
    if (s == null || conversation == null) return false;
    final newest = s.messages.where((m) => !m.mine).firstOrNull;
    if (newest == null || conversation.unreadCount == 0) return false;
    try {
      await _repo.markRead(conversation.id, newest.id);
      return true;
    } on Object {
      return false;
    }
  }

  /// Deletes [id] for the caller, or for everyone (own, within an hour).
  Future<void> deleteMessage(String id, {required bool forEveryone}) async {
    await _repo.deleteMessage(id, forEveryone: forEveryone);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(
      s.copyWith(
        messages: [
          for (final m in s.messages)
            if (m.id != id) m,
        ],
      ),
    );
  }

  Future<void> accept() async {
    final conversation = state.value?.conversation;
    if (conversation == null) return;
    await _repo.accept(conversation.id);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(
      s.copyWith(
        peer: _withConversation(
          s.peer,
          conversation.copyWith(status: DmConversationStatus.accepted),
        ),
      ),
    );
  }

  Future<void> setMuted({required bool muted}) async {
    final conversation = state.value?.conversation;
    if (conversation == null) return;
    await _repo.setMuted(conversation.id, muted: muted);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(
      s.copyWith(
        peer: _withConversation(s.peer, conversation.copyWith(muted: muted)),
      ),
    );
  }

  /// Deletes the conversation for the caller (also declines a request).
  Future<void> deleteConversation() async {
    final conversation = state.value?.conversation;
    if (conversation == null) return;
    await _repo.deleteConversation(conversation.id);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(s.copyWith(messages: const []));
  }
}

final AsyncNotifierProviderFamily<DmChatController, DmChatState, String>
dmChatProvider = AsyncNotifierProvider.autoDispose
    .family<DmChatController, DmChatState, String>(DmChatController.new);
