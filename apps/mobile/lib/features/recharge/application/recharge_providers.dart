import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';

/// D185: the caller as a recharge agent, applicant or employee
/// (`GET /me/recharge-agent`). Null while signed out.
final FutureProvider<RechargeAgentMe?> myRechargeAgentProvider =
    FutureProvider.autoDispose((ref) {
      final id = ref.watch(currentUserProvider.select((u) => u?.id));
      if (id == null) return null;
      return ref.watch(rechargeRepositoryProvider).me();
    });

/// D185: the agent's employees with their statistics.
final FutureProvider<List<RechargeEmployee>> rechargeEmployeesProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(rechargeRepositoryProvider).employees(),
    );

/// D185: the directory of one country (ISO alpha-2).
class RechargeDirectoryController
    extends PagedListController<RechargeAgentListing> {
  new(this.country);

  final String country;

  @override
  Future<PageResult<RechargeAgentListing>> fetch(String? cursor) =>
      ref.read(rechargeRepositoryProvider).directory(country, cursor: cursor);

  @override
  String idOf(RechargeAgentListing item) => item.code;
}

final AsyncNotifierProviderFamily<
  RechargeDirectoryController,
  FeedItems<RechargeAgentListing>,
  String
>
rechargeDirectoryProvider = AsyncNotifierProvider.autoDispose.family(
  RechargeDirectoryController.new,
);

/// D185: the caller's cherry sales with agents (as host or agent).
class RechargeCherryRequestsController
    extends PagedListController<RechargeCherryRequest> {
  @override
  Future<PageResult<RechargeCherryRequest>> fetch(String? cursor) =>
      ref.read(rechargeRepositoryProvider).cherryRequests(cursor: cursor);

  @override
  String idOf(RechargeCherryRequest item) => item.id;
}

final AsyncNotifierProvider<
  RechargeCherryRequestsController,
  FeedItems<RechargeCherryRequest>
>
rechargeCherryRequestsProvider = AsyncNotifierProvider.autoDispose(
  RechargeCherryRequestsController.new,
);
