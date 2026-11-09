import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/store_iap/data/store_billing.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';

/// D345: the store's packages for this phone with the store's prices.
@immutable
final class StoreOffer {
  const new({required this.catalog, required this.prices});

  final StoreCatalog catalog;

  /// The store's localized price per product id (a product the store does
  /// not know is not offered).
  final Map<String, String> prices;

  List<StoreCoinProduct> get products => [
    for (final p in catalog.products)
      if (prices.containsKey(p.productId)) p,
  ];
}

/// D345: the store offer, or null when the option is hidden — no store on
/// this phone, the server's store is off, no package the store knows. The
/// catalogue's `unavailable` (a banned device, the once rule) is kept so the
/// wallet can say why.
final FutureProvider<StoreOffer?> storeOfferProvider =
    FutureProvider.autoDispose<StoreOffer?>((ref) async {
      ref.watch(currentUserProvider.select((u) => u?.id));
      final billing = ref.watch(storeBillingProvider);
      final platform = billing.platform;
      if (platform == null) return null;
      final catalog = await ref
          .watch(storeIapRepositoryProvider)
          .catalog(platform);
      if (!catalog.available) {
        return catalog.unavailable == StoreUnavailable.off
            ? null
            : StoreOffer(catalog: catalog, prices: const {});
      }
      if (!await billing.isAvailable()) return null;
      final prices = await billing.prices({
        for (final p in catalog.products) p.productId,
      });
      final offer = StoreOffer(catalog: catalog, prices: prices);
      return offer.products.isEmpty ? null : offer;
    });

/// Where a store purchase is.
enum StorePhase {
  idle,

  /// The store's sheet is open.
  buying,

  /// The store charged; the server is verifying and crediting.
  verifying,

  /// The store has not completed the payment (a slow card, Ask to Buy…).
  pending,

  /// Credited (or already credited before).
  success,

  /// Verified but not credited («شراء واحد لكل حساب وجهاز»).
  rejected,

  /// The store or the server refused; [StorePurchaseState.failure] says why.
  failed,
}

@immutable
final class StorePurchaseState {
  const new({
    this.phase = StorePhase.idle,
    this.productId,
    this.coins,
    this.failure,
    this.storeError = false,
  });

  final StorePhase phase;
  final String? productId;

  /// The coins credited (success).
  final int? coins;
  final AppFailure? failure;

  /// The store itself reported an error (no server failure).
  final bool storeError;

  bool get busy => phase == StorePhase.buying || phase == StorePhase.verifying;
}

/// D345: the purchase flow. It listens to the store's updates for as long as
/// the wallet is open (a purchase the store delivers again — unfinished on a
/// previous run — is verified then: «استعادة»), sends each charged
/// transaction to the server and finishes it once the server answered for
/// good. Android: a purchase the server did not credit is never acknowledged,
/// so Google refunds it by itself; iOS: a definitive refusal is finished so
/// it is not delivered again forever.
class StorePurchaseController extends Notifier<StorePurchaseState> {
  StreamSubscription<List<StoreTx>>? _sub;
  StoreConsent? _consent;
  StorePlatform? _platform;

  @override
  StorePurchaseState build() {
    final billing = ref.watch(storeBillingProvider);
    _platform = billing.platform;
    _sub = billing.updates.listen(_onUpdates);
    ref.onDispose(() => unawaited(_sub?.cancel()));
    return const StorePurchaseState();
  }

  /// Starts a purchase after the consent sheet. [consent] is the box the
  /// buyer ticked (the no-refund policy, sharing consumption data on a
  /// refund request).
  Future<void> buy(
    StoreCoinProduct product,
    StoreCatalog catalog,
    StoreConsent consent,
  ) async {
    if (state.busy) return;
    _consent = consent;
    state = StorePurchaseState(
      phase: StorePhase.buying,
      productId: product.productId,
    );
    try {
      final opened = await ref
          .read(storeBillingProvider)
          .buy(product.productId, catalog.accountToken);
      if (!opened) {
        state = StorePurchaseState(
          phase: StorePhase.failed,
          productId: product.productId,
          storeError: true,
        );
      }
    } on Object {
      state = StorePurchaseState(
        phase: StorePhase.failed,
        productId: product.productId,
        storeError: true,
      );
    }
  }

  void dismiss() => state = const StorePurchaseState();

  Future<void> _onUpdates(List<StoreTx> txs) async {
    for (final tx in txs) {
      switch (tx.status) {
        case StoreTxStatus.pending:
          state = StorePurchaseState(
            phase: StorePhase.pending,
            productId: tx.productId,
          );
        case StoreTxStatus.canceled:
          state = const StorePurchaseState();
          if (tx.needsCompletion) {
            await ref.read(storeBillingProvider).complete(tx);
          }
        case StoreTxStatus.error:
          state = StorePurchaseState(
            phase: StorePhase.failed,
            productId: tx.productId,
            storeError: true,
          );
        case StoreTxStatus.purchased || StoreTxStatus.restored:
          await _verify(tx);
      }
    }
  }

  Future<void> _verify(StoreTx tx) async {
    final platform = _platform;
    if (platform == null || tx.verificationData.isEmpty) return;
    state = StorePurchaseState(
      phase: StorePhase.verifying,
      productId: tx.productId,
    );
    final billing = ref.read(storeBillingProvider);
    // A transaction delivered again (an earlier run) was bought through the
    // consent sheet too: the sheet is the only way to start a purchase, and
    // its one box covers the policy and the sharing.
    final consent =
        _consent ??
        StoreConsent(
          version:
              ref.read(storeOfferProvider).value?.catalog.consentVersion ??
              (await ref.read(storeIapRepositoryProvider).catalog(platform))
                  .consentVersion,
          shareConsumptionData: true,
        );
    try {
      final result = await ref
          .read(storeIapRepositoryProvider)
          .verify(
            platform: platform,
            productId: tx.productId,
            verificationData: tx.verificationData,
            consent: consent,
            deviceKey: await ref.read(deviceKeySourceProvider).read(),
          );
      if (result.credited || result.status == 'REFUNDED') {
        await billing.complete(tx);
      } else if (platform == StorePlatform.ios) {
        await billing.complete(tx);
      }
      ref.read(liveCoinsProvider.notifier).set(result.balance);
      state = StorePurchaseState(
        phase: result.credited ? StorePhase.success : StorePhase.rejected,
        productId: tx.productId,
        coins: result.coins,
      );
      ref.invalidate(storeOfferProvider);
    } on AppFailure catch (failure) {
      if (failure.code == ErrorCode.storeIapPending) {
        state = StorePurchaseState(
          phase: StorePhase.pending,
          productId: tx.productId,
        );
        return;
      }
      final definitive =
          failure.code == ErrorCode.storeIapVerificationFailed ||
          failure.code == ErrorCode.storeIapPurchaseConflict;
      if (definitive && platform == StorePlatform.ios) {
        await billing.complete(tx);
      }
      state = StorePurchaseState(
        phase: StorePhase.failed,
        productId: tx.productId,
        failure: failure,
      );
    }
  }
}

final NotifierProvider<StorePurchaseController, StorePurchaseState>
storePurchaseProvider = NotifierProvider.autoDispose(
  StorePurchaseController.new,
);
