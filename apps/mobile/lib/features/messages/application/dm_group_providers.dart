import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// v1.104-social (D339, CONVENTIONS §10.133): one group as its screen shows
/// it — the group's state for the caller and its messages, newest first.
@immutable
class DmGroupChatState {
  const new({
    required this.group,
    required this.messages,
    this.nextCursor,
    this.loadingMore = false,
  });

  final DmGroup group;

  /// Newest first; only messages that have not expired.
  final List<DmGroupMessage> messages;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  DmGroupChatState copyWith({
    DmGroup? group,
    List<DmGroupMessage>? messages,
    String? nextCursor,
    bool? loadingMore,
  }) => DmGroupChatState(
    group: group ?? this.group,
    messages: messages ?? this.messages,
    nextCursor: nextCursor ?? this.nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The group [groupId]: reads, sends (a message keeps its `clientId` until it
/// is answered, so a retry is never a second message), read pointer, delete,
/// mute, archive and leave.
class DmGroupChatController extends AsyncNotifier<DmGroupChatState> {
  new(this.groupId);

  final String groupId;
  final Map<String, String> _pending = {};

  DmGroupsRepository get _repo => ref.read(dmGroupsRepositoryProvider);

  @override
  Future<DmGroupChatState> build() async {
    final page = await ref.watch(dmGroupsRepositoryProvider).messages(groupId);
    return DmGroupChatState(
      group: page.group,
      messages: page.data,
      nextCursor: page.nextCursor,
    );
  }

  /// Reads the newest page again and merges it (as a conversation does).
  /// Returns whether anything changed.
  Future<bool> refresh() async {
    final s = state.value;
    if (s == null) return false;
    final page = await _repo.messages(groupId);
    if (!ref.mounted) return false;
    final current = state.value ?? s;
    final now = DateTime.now();
    final oldest = page.data.isEmpty ? null : page.data.last.createdAt;
    final kept = [
      for (final m in current.messages)
        if (oldest != null &&
            m.createdAt.isBefore(oldest) &&
            m.expiresAt.isAfter(now))
          m,
    ];
    final merged = [...page.data, ...kept];
    final changed =
        merged.length != current.messages.length ||
        [
          for (var i = 0; i < merged.length; i++)
            merged[i].id != current.messages[i].id ||
                merged[i].readCount != current.messages[i].readCount,
        ].any((c) => c) ||
        page.group.name != current.group.name ||
        page.group.memberCount != current.group.memberCount;
    state = AsyncData(current.copyWith(group: page.group, messages: merged));
    return changed;
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.messages(groupId, cursor: s.nextCursor);
      if (!ref.mounted) return;
      final known = {for (final m in s.messages) m.id};
      state = AsyncData(
        DmGroupChatState(
          group: s.group,
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

  /// Sends [message] ([key] identifies it for a retry); throws the
  /// `AppFailure`.
  Future<void> send(DmOutgoing message, {required String key}) async {
    final clientId = _pending[key] ??= newClientId();
    final result = await _repo.send(groupId, message, clientId: clientId);
    _pending.remove(key);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(
      s.copyWith(
        group: result.group,
        messages: [
          result.message,
          for (final m in s.messages)
            if (m.id != result.message.id) m,
        ],
      ),
    );
  }

  /// Moves the read pointer to the newest message from someone else.
  /// Returns whether the server was told (the badge then reads again).
  Future<bool> markRead() async {
    final s = state.value;
    if (s == null || s.group.unreadCount == 0) return false;
    final newest = s.messages.where((m) => !m.mine).firstOrNull;
    if (newest == null) return false;
    try {
      await _repo.markRead(groupId, newest.id);
      final now = state.value;
      if (now != null && ref.mounted) {
        state = AsyncData(
          now.copyWith(group: now.group.copyWith(unreadCount: 0)),
        );
      }
      return true;
    } on Object {
      return false;
    }
  }

  /// Deletes [id] for everyone (one's own within an hour; any as an admin).
  Future<void> deleteMessage(String id) async {
    await _repo.deleteMessage(groupId, id);
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

  Future<void> setMuted({required bool muted}) async {
    await _repo.setMuted(groupId, muted: muted);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(s.copyWith(group: s.group.copyWith(muted: muted)));
  }

  Future<void> setArchived({required bool archived}) async {
    await _repo.setArchived(groupId, archived: archived);
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(s.copyWith(group: s.group.copyWith(archived: archived)));
  }
}

final AsyncNotifierProviderFamily<
  DmGroupChatController,
  DmGroupChatState,
  String
>
dmGroupChatProvider = AsyncNotifierProvider.autoDispose
    .family<DmGroupChatController, DmGroupChatState, String>(
      DmGroupChatController.new,
    );

/// `GET /dm/groups/{id}`: the group's info screen (members, roles, the cap).
final FutureProviderFamily<DmGroupDetail, String> dmGroupDetailProvider =
    FutureProvider.autoDispose.family<DmGroupDetail, String>(
      (ref, groupId) => ref.watch(dmGroupsRepositoryProvider).detail(groupId),
    );

/// The group's photo upload is done before `createDmGroup`; this keeps the
/// pending create's `clientId` so a retry after a lost answer is never a
/// second group.
class DmGroupDraft {
  new();

  String clientId = newClientId();

  /// After a definite answer (created, or refused): a new attempt is a new
  /// group.
  void reset() => clientId = newClientId();
}
