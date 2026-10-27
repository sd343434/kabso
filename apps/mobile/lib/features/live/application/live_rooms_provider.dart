import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
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

/// D133: the person's own country (`Me.country`); Nearby reloads when
/// it changes.
final liveCountryProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.country)),
);

extension FeedTabLiveRooms on FeedTab {
  /// The `tab` query value of `GET /live/rooms` for this hub tab.
  LiveRoomsTab get liveRoomsTab => switch (this) {
    FeedTab.following => LiveRoomsTab.following,
    FeedTab.popular => LiveRoomsTab.popular,
    FeedTab.latest => LiveRoomsTab.latest,
  };
}

/// One room list of live discovery (D131): which tab of `GET /live/rooms`,
/// which kind, and the filters. Two equal queries share one list.
@immutable
class LiveRoomsQuery {
  const new({
    required this.tab,
    this.kind = LiveRoomsKind.video,
    this.category,
    this.nearby = false,
    this.featured = false,
  });

  final FeedTab tab;

  /// The server's `kind` filter: the hub lists `video`, the Voice rooms
  /// screen `audio`.
  final LiveRoomsKind kind;

  /// A category slug (`null`: every category).
  final String? category;

  /// D133 `scope=nearby`: hosts of the caller's country.
  final bool nearby;

  /// D133 `featured=true`: featured hosts, by feature rank.
  final bool featured;

  LiveRoomsQuery copyWith({FeedTab? tab, String? Function()? category}) =>
      LiveRoomsQuery(
        tab: tab ?? this.tab,
        kind: kind,
        category: category == null ? this.category : category(),
        nearby: nearby,
        featured: featured,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveRoomsQuery &&
      other.tab == tab &&
      other.kind == kind &&
      other.category == category &&
      other.nearby == nearby &&
      other.featured == featured;

  @override
  int get hashCode => Object.hash(tab, kind, category, nearby, featured);

  @override
  String toString() =>
      'LiveRoomsQuery(${tab.name}, ${kind.wire}, $category, '
      'nearby: $nearby, featured: $featured)';
}

/// One room list: the config switch and the cursor-paginated rooms
/// (HL-H3–H6).
@freezed
abstract class LiveHubState with _$LiveHubState {
  const factory({
    /// `GET /live/config` `hostingEnabled`. While `false` nobody can go live,
    /// so the list shows the honest unavailable state and lists nothing.
    required bool hostingEnabled,

    /// When this state was loaded from the first page.
    required DateTime fetchedAt,

    /// Rooms in server order, deduplicated by id across pages.
    @Default(<LiveRoomSummary>[]) List<LiveRoomSummary> rooms,
    String? nextCursor,
    @Default(false) bool hasMore,

    /// A next page is loading (footer skeletons).
    @Default(false) bool loadingMore,

    /// The last next-page request failed (inline footer error + retry).
    AppFailure? loadMoreError,

    /// D133: Nearby answered `COUNTRY_NOT_SET` (the person has no country:
    /// the list asks them to set it).
    @Default(false) bool countryNotSet,
  }) = _LiveHubState;

  const new _();

  /// A next page may be requested now (prefetch).
  bool get canLoadMore =>
      hostingEnabled &&
      hasMore &&
      nextCursor != null &&
      !loadingMore &&
      loadMoreError == null;
}

/// Loads and paginates one room list ([LiveRoomsQuery]) against the API.
///
/// - `GET /live/config` first: `hostingEnabled == false` → unavailable
///   (no list calls). Re-checked on every [refresh].
/// - `GET /live/rooms` with the query's tab, kind, category and the D133
///   filters, from the first cursor, then [loadMore] page by page; rooms
///   are deduplicated by id (ranking drift, §10.4).
/// - A rejected cursor (400 `VALIDATION_FAILED`, field `cursor`) restarts
///   from the first page once; a second consecutive rejection shows the
///   footer error.
class LiveRoomsController extends AsyncNotifier<LiveHubState> {
  new(this.query);

  final LiveRoomsQuery query;

  /// Bumped by every first-page load; late responses of older loads are
  /// dropped.
  int _generation = 0;

  bool _restartedForBadCursor = false;

  LiveRepository get _repo => ref.read(liveRepositoryProvider);

  Future<LiveRoomPage> _page({String? cursor}) => _repo.listRooms(
    tab: query.tab.liveRoomsTab,
    category: query.category,
    kind: query.kind,
    nearby: query.nearby,
    featured: query.featured,
    cursor: cursor,
  );

  @override
  Future<LiveHubState> build() {
    ref
      ..watch(liveScopeProvider)
      ..watch(liveRepositoryProvider);
    // D133: Nearby depends on the person's country.
    if (query.nearby) ref.watch(liveCountryProvider);
    _generation++;
    _restartedForBadCursor = false;
    return _loadAll();
  }

  Future<LiveHubState> _loadAll() async {
    final config = await _repo.getConfig();
    final now = clock.now();
    if (!config.hostingEnabled) {
      return LiveHubState(hostingEnabled: false, fetchedAt: now);
    }
    final page = await _page();
    return LiveHubState(
      hostingEnabled: true,
      fetchedAt: now,
      rooms: _dedupe(const [], page.data),
      nextCursor: page.page.nextCursor,
      hasMore: _hasMore(page),
      countryNotSet: page.emptyReason == LiveRoomsEmptyReason.countryNotSet,
    );
  }

  /// Pull-to-refresh, tab re-select and resume: reloads config and the
  /// first page. On failure the current state is kept and the `AppFailure`
  /// is rethrown (the caller decides whether to show it).
  Future<void> refresh() async {
    final generation = ++_generation;
    _restartedForBadCursor = false;
    final next = await _loadAll();
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData(next);
  }

  /// "Try again" on the list's error state.
  void retry() => ref.invalidateSelf();

  /// Loads the next page if one exists and nothing is in flight or failed
  /// (prefetch calls this freely).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || !current.canLoadMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _page(cursor: current.nextCursor);
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
      final page = await _page();
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

/// One room list of live discovery, from the real API (D37): never sample
/// rooms. Tests supply data through `liveRepositoryProvider`.
final AsyncNotifierProviderFamily<
  LiveRoomsController,
  LiveHubState,
  LiveRoomsQuery
>
liveRoomsProvider = AsyncNotifierProvider.family(LiveRoomsController.new);

/// The active live categories (`GET /live/categories`, localized by the
/// server), for the hub's Popular menu and the Voice rooms' second row.
final FutureProvider<List<LiveCategory>> liveDiscoveryCategoriesProvider =
    FutureProvider<List<LiveCategory>>((ref) {
      ref.watch(liveScopeProvider);
      return ref
          .watch(liveRepositoryProvider)
          .listCategories()
          .then(List<LiveCategory>.unmodifiable);
    });

/// Refreshes each of [queries] that is loaded, ignoring failures (the shown
/// state is kept). Used on app resume.
Future<void> refreshLoadedLiveTabs(
  ProviderContainer container,
  Iterable<LiveRoomsQuery> queries,
) async {
  await Future.wait([
    for (final query in queries)
      if (container.exists(liveRoomsProvider(query)))
        container
            .read(liveRoomsProvider(query).notifier)
            .refresh()
            .catchError((Object _) {}),
  ]);
}
