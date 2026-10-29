import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
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
