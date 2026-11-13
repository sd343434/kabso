import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// What the family chat shows (CP-022, §10.25): the messages newest first,
/// whether older ones exist, and the caller's state in the chat.
@immutable
class FamilyChatState {
  const new({
    required this.messages,
    required this.hasMore,
    required this.muted,
    required this.canModerate,
    this.loadingMore = false,
  });

  /// Newest first.
  final List<FamilyChatMessage> messages;
  final bool hasMore;
  final bool muted;
  final bool canModerate;
  final bool loadingMore;

  FamilyChatState copyWith({
    List<FamilyChatMessage>? messages,
    bool? hasMore,
    bool? muted,
    bool? canModerate,
    bool? loadingMore,
  }) => FamilyChatState(
    messages: messages ?? this.messages,
    hasMore: hasMore ?? this.hasMore,
    muted: muted ?? this.muted,
    canModerate: canModerate ?? this.canModerate,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The family chat of one family. There is no push (§10.25): the screen
/// calls [refresh] every few seconds while it is open; [loadMore] pages
/// back. A send keeps its `clientId` until it succeeds, so a retry after a
/// lost answer is never a second message.
class FamilyChatController extends AsyncNotifier<FamilyChatState> {
  new(this.familyId);

  final String familyId;
  String? _older;

  /// The `clientId` of the text being sent (kept across retries).
  final Map<String, String> _pending = {};

  FamiliesRepository get _repo => ref.read(familiesRepositoryProvider);

  @override
  Future<FamilyChatState> build() async {
    final page = await _repo.chat(familyId);
    _older = page.page.nextCursor;
    return FamilyChatState(
      messages: page.data,
      hasMore: page.page.hasMore,
      muted: page.muted,
      canModerate: page.canModerate,
    );
  }

  /// Reads the newest page again and merges it: new messages appear, ones
  /// deleted inside that page's range disappear, older pages stay.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null) return;
    final page = await _repo.chat(familyId);
    if (!ref.mounted) return;
    final fresh = page.data;
    final oldest = fresh.isEmpty ? null : fresh.last.createdAt;
    final kept = [
      for (final m in state.value?.messages ?? current.messages)
        if (oldest != null && m.createdAt.isBefore(oldest)) m,
    ];
    state = AsyncData(
      (state.value ?? current).copyWith(
        messages: [...fresh, ...kept],
        muted: page.muted,
        canModerate: page.canModerate,
      ),
    );
  }

  /// The next older page.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore || _older == null) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.chat(familyId, cursor: _older);
      if (!ref.mounted) return;
      _older = page.page.nextCursor;
      final known = {for (final m in s.messages) m.id};
      state = AsyncData(
        s.copyWith(
          messages: [
            ...s.messages,
            for (final m in page.data)
              if (!known.contains(m.id)) m,
          ],
          hasMore: page.page.hasMore,
          loadingMore: false,
        ),
      );
    } on Object {
      if (ref.mounted) state = AsyncData(s.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Sends [text]; throws the `AppFailure` (the text stays for a retry).
  Future<void> send(String text) async {
    final clientId = _pending[text] ??= newClientId();
    final message = await _repo.sendChat(
      familyId,
      text: text,
      clientId: clientId,
    );
    _pending.remove(text);
    if (!ref.mounted) return;
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
        messages: [
          message,
          for (final m in s.messages)
            if (m.id != message.id) m,
        ],
      ),
    );
  }

  /// Deletes [id] (author, leader or deputy); throws the `AppFailure`.
  Future<void> delete(String id) async {
    await _repo.deleteChat(familyId, id);
    if (!ref.mounted) return;
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
        messages: [
          for (final m in s.messages)
            if (m.id != id) m,
        ],
      ),
    );
  }

  /// The server said the caller is muted: the composer turns off.
  void markMuted() {
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(muted: true));
  }
}

final AsyncNotifierProviderFamily<FamilyChatController, FamilyChatState, String>
familyChatProvider = AsyncNotifierProvider.autoDispose
    .family<FamilyChatController, FamilyChatState, String>(
      FamilyChatController.new,
    );
