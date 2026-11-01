import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/data/hosting_application.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// D179: the caller's agencies — as a host and as an agent
/// (`GET /me/agency`).
final FutureProvider<MyAgency> myAgencyProvider = FutureProvider.autoDispose((
  ref,
) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(agencyRepositoryProvider).mine();
});

/// v1.73-social (D209): «كن مضيفاً مع الإدارة» — the caller's hosting
/// permission, latest application and whether they may apply
/// (`GET /me/hosting-application`); null from an older server.
final FutureProvider<MyHostingApplication?> myHostingProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(agencyRepositoryProvider).hosting();
    });

/// D179: the agent's hosts, newest first (`GET /me/agency/hosts`).
class AgencyHostsController extends PagedListController<AgencyHostRow> {
  @override
  Future<PageResult<AgencyHostRow>> fetch(String? cursor) =>
      ref.read(agencyRepositoryProvider).hosts(cursor: cursor);

  @override
  String idOf(AgencyHostRow item) => item.user.id;
}

final AsyncNotifierProvider<AgencyHostsController, FeedItems<AgencyHostRow>>
agencyHostsProvider = AsyncNotifierProvider.autoDispose(
  AgencyHostsController.new,
);
