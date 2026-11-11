import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/features/wallet/data/recharge_points_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

/// The caller's coin history, newest first (`GET /wallet/me/ledger`, D164).
class WalletLedgerController extends PagedListController<WalletLedgerEntry> {
  @override
  Future<PageResult<WalletLedgerEntry>> fetch(String? cursor) =>
      ref.read(walletRepositoryProvider).ledger(cursor: cursor);

  @override
  String idOf(WalletLedgerEntry item) => item.id;
}

final AsyncNotifierProvider<
  WalletLedgerController,
  FeedItems<WalletLedgerEntry>
>
walletLedgerProvider = AsyncNotifierProvider.autoDispose(
  WalletLedgerController.new,
);

/// The caller's gift earnings totals (`GET /wallet/me/earnings`, D164).
final FutureProvider<MyEarnings> myEarningsProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(walletRepositoryProvider).earnings();
    });

/// The sends the caller earned from, newest first
/// (`GET /wallet/me/earnings/history`, D164).
class EarningHistoryController extends PagedListController<Earning> {
  @override
  Future<PageResult<Earning>> fetch(String? cursor) =>
      ref.read(walletRepositoryProvider).earningHistory(cursor: cursor);

  @override
  String idOf(Earning item) => item.id;
}

final AsyncNotifierProvider<EarningHistoryController, FeedItems<Earning>>
earningHistoryProvider = AsyncNotifierProvider.autoDispose(
  EarningHistoryController.new,
);

/// D177: the wallet page's promo banners (`GET /home/banners?placement=
/// wallet`, openapi v1.51-social). A failure shows no banner slot.
final FutureProvider<List<HomeBanner>> walletBannersProvider =
    FutureProvider.autoDispose<List<HomeBanner>>((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      try {
        return await ref
            .watch(homeBannersRepositoryProvider)
            .listBanners(wallet: true);
      } on Object {
        return const [];
      }
    });

/// D179: the caller's cherry balance (`GET /wallet/me/cherries`).
final FutureProvider<CherryWallet> myCherriesProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(cherryRepositoryProvider).wallet();
    });

/// D179: every change of the caller's cherries, newest first
/// (`GET /wallet/me/cherries/ledger`).
class CherryLedgerController extends PagedListController<CherryLedgerEntry> {
  @override
  Future<PageResult<CherryLedgerEntry>> fetch(String? cursor) =>
      ref.read(cherryRepositoryProvider).ledger(cursor: cursor);

  @override
  String idOf(CherryLedgerEntry item) => item.id;
}

final AsyncNotifierProvider<
  CherryLedgerController,
  FeedItems<CherryLedgerEntry>
>
cherryLedgerProvider = AsyncNotifierProvider.autoDispose(
  CherryLedgerController.new,
);

/// D179: the caller's latest withdrawal requests (the first page).
final FutureProvider<List<CherryWithdrawal>> myWithdrawalsProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return (await ref.watch(cherryRepositoryProvider).withdrawals()).items;
    });

/// D370 (§10.162): the caller's recharge points «نقاط الشحن» now (the
/// wallet row and the VIP page's «استبدل بالنقاط»).
final FutureProvider<int> rechargePointsBalanceProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      final page = await ref
          .watch(rechargePointsRepositoryProvider)
          .page(limit: 1);
      return page.balance;
    });

/// D370: every change of the caller's recharge points, newest first
/// (`GET /me/recharge-points`).
class RechargePointsLedgerController
    extends PagedListController<RechargePointsEntry> {
  @override
  Future<PageResult<RechargePointsEntry>> fetch(String? cursor) async {
    final page = await ref
        .read(rechargePointsRepositoryProvider)
        .page(cursor: cursor);
    return (items: page.items, next: page.next);
  }

  @override
  String idOf(RechargePointsEntry item) => item.id;
}

final AsyncNotifierProvider<
  RechargePointsLedgerController,
  FeedItems<RechargePointsEntry>
>
rechargePointsLedgerProvider = AsyncNotifierProvider.autoDispose(
  RechargePointsLedgerController.new,
);
