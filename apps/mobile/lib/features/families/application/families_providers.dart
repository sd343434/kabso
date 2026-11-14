import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';

/// `GET /families/config` (price, capacity, ladder).
final FutureProvider<FamilyConfig> familyConfigProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(familiesRepositoryProvider).config(),
    );

/// The caller's family (`GET /families/me`), or null.
final FutureProvider<Family?> myFamilyProvider = FutureProvider.autoDispose((
  ref,
) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(familiesRepositoryProvider).mine();
});

/// The caller's pending join request (`GET /me/family-join-request`).
final FutureProvider<FamilyJoinRequest?> myFamilyRequestProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(familiesRepositoryProvider).myRequest();
    });

/// One family (`GET /families/{familyId}`).
final FutureProviderFamily<Family, String> familyProvider = FutureProvider
    .autoDispose
    .family(
      (ref, familyId) => ref.watch(familiesRepositoryProvider).get(familyId),
    );

/// Families by points, or matching a name or number ([query]; empty = the
/// top families).
class FamilySearchController extends PagedListController<FamilyCard> {
  new(this.query);

  final String query;

  @override
  Future<PageResult<FamilyCard>> fetch(String? cursor) async {
    final page = await ref
        .read(familiesRepositoryProvider)
        .search(query: query.trim(), cursor: cursor);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(FamilyCard item) => item.id;
}

final AsyncNotifierProviderFamily<
  FamilySearchController,
  FeedItems<FamilyCard>,
  String
>
familySearchProvider = AsyncNotifierProvider.autoDispose
    .family<FamilySearchController, FeedItems<FamilyCard>, String>(
      FamilySearchController.new,
    );

/// A family's members by points (v1.25-live `sort=POINTS`, with `rank`,
/// §10.25); the argument is the family id, or `id?q=text` for a search
/// (see [familyMembersKey]).
class FamilyMembersController extends PagedListController<FamilyMember> {
  new(this.key);

  final String key;

  @override
  Future<PageResult<FamilyMember>> fetch(String? cursor) async {
    final (familyId, query) = splitFamilyMembersKey(key);
    final page = await ref
        .read(familiesRepositoryProvider)
        .members(familyId, cursor: cursor, byPoints: true, query: query);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(FamilyMember item) => item.user.id;
}

final AsyncNotifierProviderFamily<
  FamilyMembersController,
  FeedItems<FamilyMember>,
  String
>
familyMembersProvider = AsyncNotifierProvider.autoDispose
    .family<FamilyMembersController, FeedItems<FamilyMember>, String>(
      FamilyMembersController.new,
    );

/// The [familyMembersProvider] argument for [familyId] and a search.
String familyMembersKey(String familyId, [String query = '']) =>
    query.trim().isEmpty ? familyId : '$familyId?q=${query.trim()}';

/// The family id and the search of a [familyMembersKey].
(String, String?) splitFamilyMembersKey(String key) {
  final i = key.indexOf('?q=');
  return i < 0 ? (key, null) : (key.substring(0, i), key.substring(i + 3));
}

/// One family board (v1.25-live, top 100, paged). [me] is the caller's
/// family on it, from the first page.
class FamilyRankingsController extends PagedListController<FamilyRankingEntry> {
  new(this.board);

  final FamilyRankingBoard board;

  /// The caller's family on this board (null without one).
  FamilyRankingMe? me;

  @override
  Future<PageResult<FamilyRankingEntry>> fetch(String? cursor) async {
    final page = await ref
        .read(familiesRepositoryProvider)
        .rankings(board, cursor: cursor);
    if (cursor == null) me = page.me;
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(FamilyRankingEntry item) => item.family.id;
}

final AsyncNotifierProviderFamily<
  FamilyRankingsController,
  FeedItems<FamilyRankingEntry>,
  FamilyRankingBoard
>
familyRankingsProvider = AsyncNotifierProvider.autoDispose
    .family<
      FamilyRankingsController,
      FeedItems<FamilyRankingEntry>,
      FamilyRankingBoard
    >(FamilyRankingsController.new);

/// A family's place on both boards (`GET /families/{familyId}/rankings`).
final FutureProviderFamily<FamilyStanding, String> familyStandingProvider =
    FutureProvider.autoDispose.family(
      (ref, familyId) =>
          ref.watch(familiesRepositoryProvider).standing(familyId),
    );

/// This month's contributions of a family, most first.
class FamilyContributionsController
    extends PagedListController<FamilyContribution> {
  new(this.familyId);

  final String familyId;

  @override
  Future<PageResult<FamilyContribution>> fetch(String? cursor) async {
    final page = await ref
        .read(familiesRepositoryProvider)
        .contributions(familyId, cursor: cursor);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(FamilyContribution item) => item.user.id;
}

final AsyncNotifierProviderFamily<
  FamilyContributionsController,
  FeedItems<FamilyContribution>,
  String
>
familyContributionsProvider = AsyncNotifierProvider.autoDispose
    .family<
      FamilyContributionsController,
      FeedItems<FamilyContribution>,
      String
    >(FamilyContributionsController.new);

/// Pending join requests of a family (leader and deputies), oldest first.
class FamilyJoinRequestsController
    extends PagedListController<FamilyJoinRequest> {
  new(this.familyId);

  final String familyId;

  @override
  Future<PageResult<FamilyJoinRequest>> fetch(String? cursor) async {
    final page = await ref
        .read(familiesRepositoryProvider)
        .joinRequests(familyId, cursor: cursor);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(FamilyJoinRequest item) => item.id;
}

final AsyncNotifierProviderFamily<
  FamilyJoinRequestsController,
  FeedItems<FamilyJoinRequest>,
  String
>
familyJoinRequestsProvider = AsyncNotifierProvider.autoDispose
    .family<FamilyJoinRequestsController, FeedItems<FamilyJoinRequest>, String>(
      FamilyJoinRequestsController.new,
    );

/// After a family change: reload what shows it (the family, its members
/// and requests, the caller's family and request, and profiles, whose
/// `family` may have changed).
void refreshFamilies(WidgetRef ref, {String? familyId}) {
  if (familyId != null) {
    ref
      ..invalidate(familyProvider(familyId))
      ..invalidate(familyMembersProvider)
      ..invalidate(familyJoinRequestsProvider(familyId))
      ..invalidate(familyContributionsProvider(familyId))
      ..invalidate(familyStandingProvider(familyId));
  }
  ref
    ..invalidate(myFamilyProvider)
    ..invalidate(myFamilyRequestProvider)
    ..invalidate(familySearchProvider)
    ..invalidate(familyRankingsProvider)
    ..invalidate(profileStatsProvider)
    ..invalidate(publicProfileProvider);
}

/// The balance an answer carried (`coins`); a wallet on screen shows it at
/// once (the next one to open reads `GET /wallet/me` anyway).
void showCoins(WidgetRef ref, int coins) {
  if (ref.exists(liveCoinsProvider)) {
    ref.read(liveCoinsProvider.notifier).set(coins);
  }
}

/// A refund or a failed spend: read the balance again.
void reloadCoins(WidgetRef ref) {
  if (ref.exists(liveCoinsProvider)) ref.invalidate(liveCoinsProvider);
}
