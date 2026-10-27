import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

part 'live_rooms_provider.freezed.dart';

/// What scopes live discovery data: who is asking (Following is personal)
/// and in which language (category names are localized by the server,
/// CONVENTIONS §10.1). A change reloads every tab.
typedef LiveScope = ({String? userId, AppLanguage language});

final liveScopeProvider = Provider<LiveScope>(
  (ref) => (
    userId: ref.watch(currentUserProvider.select((u) => u?.id)),
    language: ref.watch(languageControllerProvider),
  ),
);

/// D129: the hub's "voice rooms · live" switch. Voice rooms first (the
/// owner named them first); the last choice is kept on this device.
class LiveHubKindController extends Notifier<LiveRoomsKind> {
  @override
  LiveRoomsKind build() =>
      LiveRoomsKind.tryParse(readSaved()) ?? LiveRoomsKind.audio;

  /// Shows [kind] on every tab (each reloads from its first page) and
  /// remembers it.
  Future<void> select(LiveRoomsKind kind) async {
    if (kind == state) return;
    state = kind;
    await save(kind);
  }

  /// The choice saved on this device (tests replace the storage).
  @protected
  String? readSaved() => ref
      .watch(sharedPreferencesProvider)
      .getString(PreferenceKeys.liveHubKind);

  @protected
  Future<void> save(LiveRoomsKind kind) => ref
      .read(sharedPreferencesProvider)
      .setString(PreferenceKeys.liveHubKind, kind.wire);
}

final liveHubKindProvider =
    NotifierProvider<LiveHubKindController, LiveRoomsKind>(
      LiveHubKindController.new,
    );

extension FeedTabLiveRooms on FeedTab {
  /// The `tab` query value of `GET /live/rooms` for this hub tab.
  LiveRoomsTab get liveRoomsTab => switch (this) {
    FeedTab.following => LiveRoomsTab.following,
    FeedTab.popular => LiveRoomsTab.popular,
    FeedTab.latest => LiveRoomsTab.latest,
  };
}

/// One Live hub tab: config switch, categories (Popular only) and the
/// cursor-paginated room list (HL-H3–H6).
@freezed
abstract class LiveHubState with _$LiveHubState {
  const factory({
    /// `GET /live/config` `hostingEnabled`. While `false` nobody can go live,
    /// so the tab shows the honest unavailable state and lists nothing.
    required bool hostingEnabled,

    /// When this state was loaded from the first page.
    required DateTime fetchedAt,

    /// Active categories (Popular only; empty elsewhere).
    @Default(<LiveCategory>[]) List<LiveCategory> categories,

    /// Selected category slug; `null` is "All".
    String? category,

    /// Rooms in server order, deduplicated by id across pages.
    @Default(<LiveRoomSummary>[]) List<LiveRoomSummary> rooms,
    String? nextCursor,
    @Default(false) bool hasMore,

    /// A next page is loading (footer skeletons).
    @Default(false) bool loadingMore,

    /// The last next-page request failed (inline footer error + retry).
    AppFailure? loadMoreError,

    /// The first page is reloading for a new category (grid skeletons).
    @Default(false) bool reloading,

    /// Reloading the first page for a new category failed.
    AppFailure? reloadError,
  }) = _LiveHubState;

  const new _();

  /// A next page may be requested now (prefetch).
  bool get canLoadMore =>
      hostingEnabled &&
      hasMore &&
      nextCursor != null &&
      !loadingMore &&
      loadMoreError == null &&
      !reloading &&
      reloadError == null;
}

/// Loads and paginates one Live hub tab against the v1.3 API.
///
/// - `GET /live/config` first: `hostingEnabled == false` → unavailable
///   (no list calls). Re-checked on every [refresh].
/// - Popular: `GET /live/categories`, and the selected category is sent with
///   the list call. Other tabs never send a category (HL-H3).
/// - D129: every list call carries the hub's kind (`liveHubKindProvider`);
///   switching it reloads the tab from its first page (the category stays).
/// - `GET /live/rooms` from the first cursor, then [loadMore] page by page;
///   rooms are deduplicated by id (ranking drift, §10.4).
/// - A rejected cursor (400 `VALIDATION_FAILED`, field `cursor`) restarts
///   from the first page once; a second consecutive rejection shows the
///   footer error.
class LiveRoomsController extends AsyncNotifier<LiveHubState> {
  new(this.tab);

  final FeedTab tab;

  /// Survives rebuilds (locale change, retry, kind switch) of this tab.
  String? _category;

  /// D129: the kind this state was loaded for (set by [build]).
  LiveRoomsKind _kind = LiveRoomsKind.audio;

  /// Bumped by every first-page load; late responses of older loads are
  /// dropped.
  int _generation = 0;

  bool _restartedForBadCursor = false;

  LiveRepository get _repo => ref.read(liveRepositoryProvider);

  String? get _categoryParam => tab == FeedTab.popular ? _category : null;

  @override
  Future<LiveHubState> build() {
    ref
      ..watch(liveScopeProvider)
      ..watch(liveRepositoryProvider);
    _kind = ref.watch(liveHubKindProvider);
    _generation++;
    _restartedForBadCursor = false;
    return _loadAll();
  }

  Future<LiveHubState> _loadAll() async {
    final repo = _repo;
    final config = await repo.getConfig();
    final now = clock.now();
    if (!config.hostingEnabled) {
      return LiveHubState(hostingEnabled: false, fetchedAt: now);
    }
    var categories = const <LiveCategory>[];
    if (tab == FeedTab.popular) {
      categories = List.unmodifiable(await repo.listCategories());
      final selected = _category;
      if (selected != null && !categories.any((c) => c.slug == selected)) {
        // The category was deactivated meanwhile: back to "All".
        _category = null;
      }
    }
    final page = await repo.listRooms(
      tab: tab.liveRoomsTab,
      category: _categoryParam,
      kind: _kind,
    );
    return LiveHubState(
      hostingEnabled: true,
      fetchedAt: now,
      categories: categories,
      category: _categoryParam,
      rooms: _dedupe(const [], page.data),
      nextCursor: page.page.nextCursor,
      hasMore: _hasMore(page),
    );
  }

  /// Pull-to-refresh, tab re-select and resume: reloads config, categories
  /// and the first page, keeping the category. On failure the current state
  /// is kept and the `AppFailure` is rethrown (the caller decides whether to
  /// show it).
  Future<void> refresh() async {
    final generation = ++_generation;
    _restartedForBadCursor = false;
    final next = await _loadAll();
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData(next);
  }

  /// Selects a category chip (Popular only); `null` is "All". Reloads the
  /// list from the first cursor.
  Future<void> selectCategory(String? slug) async {
    final current = state.value;
    if (tab != FeedTab.popular || current == null) return;
    if (!current.hostingEnabled || slug == current.category) return;
    _category = slug;
    await _reloadFirstPage(current);
  }

  /// "Try again" on the tab's error state.
  Future<void> retry() async {
    final current = state.value;
    if (current != null && current.reloadError != null && !state.hasError) {
      await _reloadFirstPage(current);
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> _reloadFirstPage(LiveHubState current) async {
    final generation = ++_generation;
    _restartedForBadCursor = false;
    state = AsyncData(
      current.copyWith(
        category: _categoryParam,
        rooms: const [],
        nextCursor: null,
        hasMore: false,
        loadingMore: false,
        loadMoreError: null,
        reloading: true,
        reloadError: null,
      ),
    );
    try {
      final page = await _repo.listRooms(
        tab: tab.liveRoomsTab,
        category: _categoryParam,
        kind: _kind,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        state.requireValue.copyWith(
          fetchedAt: clock.now(),
          rooms: _dedupe(const [], page.data),
          nextCursor: page.page.nextCursor,
          hasMore: _hasMore(page),
          reloading: false,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        state.requireValue.copyWith(
          reloading: false,
          reloadError: toAppFailure(e),
        ),
      );
    }
  }

  /// Loads the next page if one exists and nothing is in flight or failed
  /// (prefetch calls this freely).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || !current.canLoadMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _repo.listRooms(
        tab: tab.liveRoomsTab,
        category: current.category,
        kind: _kind,
        cursor: current.nextCursor,
      );
      if (!ref.mounted || generation != _generation) return;
      _restartedForBadCursor = false;
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          rooms: _dedupe(latest.rooms, page.data),
          nextCursor: page.page.nextCursor,
          hasMore: _hasMore(page),
          loadingMore: false,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final failure = toAppFailure(e);
      if (_isBadCursor(failure) && !_restartedForBadCursor) {
        _restartedForBadCursor = true;
        await _restartFromFirstPage(generation);
        return;
      }
      state = AsyncData(
        state.requireValue.copyWith(loadingMore: false, loadMoreError: failure),
      );
    }
  }

  /// "Retry" on the footer error.
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || current.loadMoreError == null) return;
    state = AsyncData(current.copyWith(loadMoreError: null));
    await loadMore();
  }

  /// The server rejected the cursor: reload the list from the first page
  /// (CONVENTIONS §5), replacing what is shown.
  Future<void> _restartFromFirstPage(int generation) async {
    try {
      final page = await _repo.listRooms(
        tab: tab.liveRoomsTab,
        category: state.requireValue.category,
        kind: _kind,
      );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        state.requireValue.copyWith(
          fetchedAt: clock.now(),
          rooms: _dedupe(const [], page.data),
          nextCursor: page.page.nextCursor,
          hasMore: _hasMore(page),
          loadingMore: false,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        state.requireValue.copyWith(
          loadingMore: false,
          loadMoreError: toAppFailure(e),
        ),
      );
    }
  }

  static bool _hasMore(LiveRoomPage page) =>
      page.page.hasMore && page.page.nextCursor != null;

  static bool _isBadCursor(AppFailure failure) =>
      failure is ServerFailure &&
      failure.code == ErrorCode.validationFailed &&
      failure.details.any((d) => d.field == 'cursor');

  /// [existing] followed by the rooms of [page] not already shown (HL-H5).
  static List<LiveRoomSummary> _dedupe(
    List<LiveRoomSummary> existing,
    List<LiveRoomSummary> page,
  ) {
    final seen = {for (final room in existing) room.id};
    return List.unmodifiable([
      ...existing,
      for (final room in page)
        if (seen.add(room.id)) room,
    ]);
  }
}

/// Live rooms for one Live hub tab, from the real v1.3 API (D37): never
/// sample rooms. Tests supply data through `liveRepositoryProvider`.
final AsyncNotifierProviderFamily<LiveRoomsController, LiveHubState, FeedTab>
liveRoomsProvider = AsyncNotifierProvider.family(LiveRoomsController.new);

/// Refreshes every Live hub tab that is currently loaded, ignoring
/// failures (the shown state is kept). Used on app resume.
Future<void> refreshLoadedLiveTabs(ProviderContainer container) async {
  await Future.wait([
    for (final tab in FeedTab.values)
      if (container.exists(liveRoomsProvider(tab)))
        container
            .read(liveRoomsProvider(tab).notifier)
            .refresh()
            .catchError((Object _) {}),
  ]);
}
