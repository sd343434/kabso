import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';

/// D150 / D204: store builds (Play / App Store) are built with
/// `--dart-define=KABSO_STORE_BUILD=true` and never show the agent order
/// flow (selling digital coins for an outside payment) until legal confirms.
const bool kStoreBuild = bool.fromEnvironment('KABSO_STORE_BUILD');

/// Whether this build may show the store-build-gated agent flow.
final storeBuildProvider = Provider<bool>((ref) => kStoreBuild);

/// D204: whether «اطلب شحن» is offered — the server's switch
/// (`RechargeRules.orders.enabled`) and not a store build.
final FutureProvider<bool> rechargeOrdersVisibleProvider =
    FutureProvider.autoDispose((ref) async {
      if (ref.watch(storeBuildProvider)) return false;
      final me = await ref.watch(myRechargeAgentProvider.future);
      return me?.rules.ordersEnabled ?? false;
    });

/// One order (`GET /recharge-orders/{id}`).
final FutureProviderFamily<RechargeOrder, String> rechargeOrderProvider =
    FutureProvider.autoDispose.family(
      (ref, id) => ref.watch(rechargeOrdersRepositoryProvider).get(id),
    );

/// The order's chat, oldest first.
final FutureProviderFamily<List<RechargeOrderMessage>, String>
rechargeOrderMessagesProvider = FutureProvider.autoDispose.family(
  (ref, id) => ref.watch(rechargeOrdersRepositoryProvider).messages(id),
);

/// A private picture of the chat (bytes through the API; never a URL).
final FutureProviderFamily<Uint8List, ({String order, String message})>
rechargeOrderImageProvider = FutureProvider.family(
  (ref, k) =>
      ref.watch(rechargeOrdersRepositoryProvider).image(k.order, k.message),
);

/// The server's price for an order (debounced by the screen).
final FutureProviderFamily<
  RechargeOrderQuote,
  ({String agentCode, String country, int coins})
>
rechargeOrderQuoteProvider = FutureProvider.autoDispose.family(
  (ref, q) => ref
      .watch(rechargeOrdersRepositoryProvider)
      .quote(agentCode: q.agentCode, country: q.country, coins: q.coins),
);

/// The caller's orders as buyer (`false`) or for their agent (`true`).
class RechargeOrdersController extends PagedListController<RechargeOrder> {
  // The family's argument (Riverpod passes it positionally).
  // ignore: avoid_positional_boolean_parameters
  new(this.asAgent);

  final bool asAgent;

  @override
  Future<PageResult<RechargeOrder>> fetch(String? cursor) => ref
      .read(rechargeOrdersRepositoryProvider)
      .list(asAgent: asAgent, cursor: cursor);

  @override
  String idOf(RechargeOrder item) => item.id;
}

final AsyncNotifierProviderFamily<
  RechargeOrdersController,
  FeedItems<RechargeOrder>,
  bool
>
rechargeOrdersProvider = AsyncNotifierProvider.autoDispose.family(
  RechargeOrdersController.new,
);
