import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';

// The CP space (CP-021, CONVENTIONS §10.24). Names of tasks, privileges and
// tiers are localized by the server, so a language change reloads them.

/// Today's daily tasks of the caller's couple. Opening the CP space checks
/// in (`POST /cp/me/check-in`, once per partner and CP day: 201 now, 200
/// already), which answers the tasks; when the check-in itself cannot be
/// made (e.g. rate limited) the tasks are read with `GET /cp/me/tasks`.
class CpTasksController extends AsyncNotifier<CpTasks> {
  @override
  Future<CpTasks> build() async {
    ref
      ..watch(languageControllerProvider)
      ..watch(currentUserProvider.select((u) => u?.id));
    final repo = ref.watch(cpRepositoryProvider);
    try {
      return await repo.checkIn();
    } on ServerFailure catch (e) {
      if (e.code == ErrorCode.cpNotPaired) rethrow;
      return await repo.tasks();
    }
  }

  /// Claims [code]'s reward: the task as the server answers it (claimed by
  /// either partner → 200, nothing added again). Throws an `AppFailure`
  /// (409 `CP_TASK_NOT_COMPLETED` when not done today: the tasks reload).
  Future<CpTaskClaim> claim(String code) async {
    try {
      final result = await ref.read(cpRepositoryProvider).claimTask(code);
      if (ref.mounted) {
        if (state.value case final tasks?) {
          state = AsyncData(tasks.withTask(result.task));
        }
      }
      return result;
    } on ServerFailure catch (e) {
      if (e.code == ErrorCode.cpTaskNotCompleted && ref.mounted) {
        ref.invalidateSelf();
      }
      rethrow;
    }
  }
}

final AsyncNotifierProvider<CpTasksController, CpTasks> cpTasksProvider =
    AsyncNotifierProvider.autoDispose<CpTasksController, CpTasks>(
      CpTasksController.new,
    );

/// `GET /cp/me/privileges`: the five privileges and which are unlocked.
final FutureProvider<CpPrivileges> cpPrivilegesProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(cpRepositoryProvider).privileges();
    });

/// `GET /cp/couples/{coupleId}`: a couple's page, read-only.
final FutureProviderFamily<CpCouplePublic, String> cpCoupleProvider =
    FutureProvider.autoDispose.family<CpCouplePublic, String>((ref, coupleId) {
      ref.watch(languageControllerProvider);
      return ref.watch(cpRepositoryProvider).publicCouple(coupleId);
    });

/// A confession wall, newest first: the caller's couple ([coupleId] null,
/// `GET /cp/me/confessions`) or another couple's.
class CpConfessionsController extends PagedListController<CpConfession> {
  new(this.coupleId);

  final String? coupleId;

  @override
  Future<PageResult<CpConfession>> fetch(String? cursor) async {
    final repo = ref.read(cpRepositoryProvider);
    final id = coupleId;
    final page = id == null
        ? await repo.myConfessions(cursor: cursor)
        : await repo.coupleConfessions(id, cursor: cursor);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(CpConfession item) => item.id;

  /// Puts the confession just written first (no reload).
  void prepend(CpConfession confession) {
    final s = state.value;
    if (s == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(
      FeedItems(
        [
          confession,
          for (final c in s.items)
            if (c.id != confession.id) c,
        ],
        hasMore: s.hasMore,
        loadMoreError: s.loadMoreError,
      ),
    );
  }
}

final AsyncNotifierProviderFamily<
  CpConfessionsController,
  FeedItems<CpConfession>,
  String?
>
cpConfessionsProvider = AsyncNotifierProvider.autoDispose
    .family<CpConfessionsController, FeedItems<CpConfession>, String?>(
      CpConfessionsController.new,
    );

/// A couple's gift wall, newest first; [totals] come with the first page.
class CpGiftWallController extends PagedListController<CpGiftWallEntry> {
  new(this.coupleId);

  final String coupleId;

  /// The couple's totals (gifts, coins), from the latest page.
  ({int gifts, int coins})? totals;

  @override
  Future<PageResult<CpGiftWallEntry>> fetch(String? cursor) async {
    final wall = await ref
        .read(cpRepositoryProvider)
        .giftWall(coupleId, cursor: cursor);
    totals = (gifts: wall.totalGifts, coins: wall.totalCoins);
    return (items: wall.data, next: wall.page.nextCursor);
  }

  @override
  String idOf(CpGiftWallEntry item) => item.id;
}

final AsyncNotifierProviderFamily<
  CpGiftWallController,
  FeedItems<CpGiftWallEntry>,
  String
>
cpGiftWallProvider = AsyncNotifierProvider.autoDispose
    .family<CpGiftWallController, FeedItems<CpGiftWallEntry>, String>(
      CpGiftWallController.new,
    );

/// The couples ranking of [period]; [me] (the caller's couple) comes with
/// the first page.
class CpRankingsController extends PagedListController<CpRankingEntry> {
  new(this.period);

  final CpRankingPeriod period;

  /// The caller's couple in this period; null when not paired.
  CpRankingMe? me;

  @override
  Future<PageResult<CpRankingEntry>> fetch(String? cursor) async {
    // Only while building (the first page): level names follow the language.
    if (cursor == null) ref.watch(languageControllerProvider);
    final page = await ref
        .read(cpRepositoryProvider)
        .rankings(period, cursor: cursor);
    if (cursor == null) me = page.me;
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(CpRankingEntry item) => item.coupleId;
}

final AsyncNotifierProviderFamily<
  CpRankingsController,
  FeedItems<CpRankingEntry>,
  CpRankingPeriod
>
cpRankingsProvider = AsyncNotifierProvider.autoDispose
    .family<CpRankingsController, FeedItems<CpRankingEntry>, CpRankingPeriod>(
      CpRankingsController.new,
    );
