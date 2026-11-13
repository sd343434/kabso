import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart'
    show WaDepartment;
import 'package:material_ui/material_ui.dart';

/// Whether the support thread and the pins talk to the server: a real
/// signed-in account (demo data has no server), as the direct messages.
bool _live(Ref ref) =>
    ref.watch(currentUserProvider.select((u) => u?.id)) != null &&
    !watchDemo(ref);

/// v1.137-social (D385, §10.174.1): the «دعم كابسو» circle's thread — its
/// unread replies and whether a ticket is open. Read with the Messages
/// tab's poll, on a `dm` / `support` push and on resume; a failed read
/// keeps the last state (the circle is always there).
class SupportThreadController extends Notifier<SupportThread> {
  Timer? _timer;
  bool _on = false;

  @override
  SupportThread build() {
    _on = _live(ref);
    if (!_on) return SupportThread.empty;
    final repo = ref.watch(supportRepositoryProvider);
    ref.listen(dmActivityProvider, (_, _) => unawaited(refresh()));
    _timer = Timer.periodic(dmUnreadPoll, (_) => unawaited(refresh()));
    ref.onDispose(() => _timer?.cancel());
    unawaited(_load(repo));
    return SupportThread.empty;
  }

  Future<void> _load(SupportRepository repo) async {
    try {
      final next = await repo.thread();
      if (ref.mounted) state = next;
    } on Object {
      // Keep the last state.
    }
  }

  Future<void> refresh() async {
    if (_on) await _load(ref.read(supportRepositoryProvider));
  }

  /// After a send or a read: the server's newest view of the thread.
  void put(SupportThread thread) {
    if (ref.mounted) state = thread;
  }
}

final NotifierProvider<SupportThreadController, SupportThread>
supportThreadProvider = NotifierProvider.autoDispose(
  SupportThreadController.new,
);

/// v1.137-social (D385, §10.174.4): the chats pinned at the top of
/// «الرسائل», first pinned first (kept on the server: every device shows
/// the same row). A failed read keeps the last list.
class DmPinsController extends Notifier<DmPinList> {
  bool _on = false;

  @override
  DmPinList build() {
    _on = _live(ref);
    if (!_on) return const DmPinList([]);
    final repo = ref.watch(dmPinsRepositoryProvider);
    ref.listen(dmActivityProvider, (_, _) => unawaited(refresh()));
    unawaited(_load(repo));
    return const DmPinList([]);
  }

  Future<void> _load(DmPinsRepository repo) async {
    try {
      final next = await repo.pins();
      if (ref.mounted) state = next;
    } on Object {
      // Keep the last list.
    }
  }

  Future<void> refresh() async {
    if (_on) await _load(ref.read(dmPinsRepositoryProvider));
  }

  /// Pins or unpins [chat]; throws the server's failure (409 `DM_PIN_LIMIT`
  /// for a 6th) and leaves the row as it was.
  Future<void> setPinned(DmChat chat, {required bool pinned}) async {
    final next = await ref
        .read(dmPinsRepositoryProvider)
        .setPinned(chat, pinned: pinned);
    if (ref.mounted) state = next;
  }
}

final NotifierProvider<DmPinsController, DmPinList> dmPinsProvider =
    NotifierProvider.autoDispose(DmPinsController.new);

/// The open «دعم كابسو» conversation: its messages (newest first) and the
/// thread.
@immutable
class SupportChatState {
  const new({
    required this.thread,
    required this.messages,
    this.nextCursor,
    this.loadingMore = false,
  });

  final SupportThread thread;
  final List<SupportMessage> messages;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  SupportChatState copyWith({
    SupportThread? thread,
    List<SupportMessage>? messages,
    bool? loadingMore,
  }) => SupportChatState(
    thread: thread ?? this.thread,
    messages: messages ?? this.messages,
    nextCursor: nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// v1.137-social (D385, §10.174.2–3): the support conversation. A send
/// keeps its client id until it is answered (a retry is never a second
/// message, like a direct message's).
class SupportChatController extends AsyncNotifier<SupportChatState> {
  final Map<String, String> _pending = {};

  SupportRepository get _repo => ref.read(supportRepositoryProvider);

  @override
  Future<SupportChatState> build() async {
    final repo = ref.watch(supportRepositoryProvider);
    final page = await repo.messages();
    return SupportChatState(
      thread: page.thread,
      messages: page.data,
      nextCursor: page.nextCursor,
    );
  }

  /// Reads the newest page again (new replies appear, older pages stay).
  /// Returns whether anything changed.
  Future<bool> refresh() async {
    final s = state.value;
    if (s == null) return false;
    final page = await _repo.messages();
    if (!ref.mounted) return false;
    final current = state.value ?? s;
    final fresh = page.data;
    final known = {for (final m in fresh) m.id};
    final oldest = fresh.isEmpty ? null : fresh.last.createdAt;
    final merged = [
      ...fresh,
      for (final m in current.messages)
        if (!known.contains(m.id) &&
            oldest != null &&
            m.createdAt.isBefore(oldest))
          m,
    ];
    final changed =
        merged.length != current.messages.length ||
        [
          for (var i = 0; i < merged.length; i++)
            merged[i].id != current.messages[i].id ||
                merged[i].receipt != current.messages[i].receipt,
        ].any((c) => c) ||
        page.thread.status != current.thread.status;
    state = AsyncData(current.copyWith(thread: page.thread, messages: merged));
    return changed;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.messages(cursor: s.nextCursor);
      if (!ref.mounted) return;
      final known = {for (final m in s.messages) m.id};
      state = AsyncData(
        SupportChatState(
          thread: s.thread,
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

  /// Sends [message]; [topic] names a new ticket's department (required by
  /// the server when no ticket is open). Throws the server's failure.
  Future<void> send(
    SupportOutgoing message, {
    required String key,
    WaDepartment? topic,
  }) async {
    final clientId = _pending[key] ??= newClientId();
    final result = await _repo.send(message, clientId: clientId, topic: topic);
    _pending.remove(key);
    if (!ref.mounted) return;
    final s = state.value;
    if (s != null) {
      state = AsyncData(
        s.copyWith(
          thread: result.thread,
          messages: [
            result.message,
            for (final m in s.messages)
              if (m.id != result.message.id) m,
          ],
        ),
      );
    }
    if (ref.exists(supportThreadProvider)) {
      ref.read(supportThreadProvider.notifier).put(result.thread);
    }
  }

  /// The team's replies are read (the circle's count goes to 0).
  Future<void> markRead() async {
    final s = state.value;
    if (s == null || s.thread.unreadCount == 0) return;
    try {
      await _repo.read();
    } on Object {
      return;
    }
    if (!ref.mounted) return;
    final read = SupportThread(
      id: s.thread.id,
      status: s.thread.status,
      department: s.thread.department,
      lastMessageAt: s.thread.lastMessageAt,
      lastPreview: s.thread.lastPreview,
    );
    state = AsyncData(s.copyWith(thread: read));
    if (ref.exists(supportThreadProvider)) {
      ref.read(supportThreadProvider.notifier).put(read);
    }
    // D385 (owner): the replies leave the Messages tab badge at once.
    if (ref.exists(dmUnreadProvider)) {
      unawaited(ref.read(dmUnreadProvider.notifier).refresh());
    }
  }
}

final AsyncNotifierProvider<SupportChatController, SupportChatState>
supportChatProvider = AsyncNotifierProvider.autoDispose(
  SupportChatController.new,
);
