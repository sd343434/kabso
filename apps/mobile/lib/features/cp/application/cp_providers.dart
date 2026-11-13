import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';

// Tier names are localized by the server, so a language change reloads
// them.

/// `GET /cp/config` (request price, gift amounts, tiers).
final FutureProvider<CpConfig> cpConfigProvider = FutureProvider.autoDispose((
  ref,
) {
  ref.watch(languageControllerProvider);
  return ref.watch(cpRepositoryProvider).config();
});

/// The caller's couple (`GET /cp/me`), or null.
final FutureProvider<CpCouple?> myCpProvider = FutureProvider.autoDispose((
  ref,
) {
  ref
    ..watch(languageControllerProvider)
    ..watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(cpRepositoryProvider).mine();
});

/// The caller's pending CP requests in one direction, newest first.
class CpRequestsController extends PagedListController<CpRequest> {
  new(this.direction);

  final CpDirection direction;

  @override
  Future<PageResult<CpRequest>> fetch(String? cursor) async {
    final page = await ref
        .read(cpRepositoryProvider)
        .requests(direction, cursor: cursor);
    return (items: page.data, next: page.page.nextCursor);
  }

  @override
  String idOf(CpRequest item) => item.id;
}

final AsyncNotifierProviderFamily<
  CpRequestsController,
  FeedItems<CpRequest>,
  CpDirection
>
cpRequestsProvider = AsyncNotifierProvider.autoDispose
    .family<CpRequestsController, FeedItems<CpRequest>, CpDirection>(
      CpRequestsController.new,
    );

/// After a CP change: the couple, both request lists and the profiles
/// (their `cp`).
void refreshCp(WidgetRef ref) => ref
  ..invalidate(myCpProvider)
  ..invalidate(cpRequestsProvider)
  ..invalidate(profileStatsProvider)
  ..invalidate(publicProfileProvider);
