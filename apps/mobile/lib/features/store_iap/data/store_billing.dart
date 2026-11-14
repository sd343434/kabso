import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';

/// D345: what the store says about one transaction.
enum StoreTxStatus { pending, purchased, restored, canceled, error }

/// D345: one store transaction, independent of the plugin (tests fake it).
@immutable
final class StoreTx {
  const new({
    required this.productId,
    required this.status,
    required this.verificationData,
    this.needsCompletion = false,
    this.raw,
  });

  final String productId;
  final StoreTxStatus status;

  /// Android: the purchase token; iOS: StoreKit 2's signed transaction (JWS).
  final String verificationData;

  /// The store waits for `complete` (finish / acknowledge).
  final bool needsCompletion;

  /// The plugin's object (`PurchaseDetails`), for [StoreBilling.complete].
  final Object? raw;
}

/// D345: the store's billing on this phone — Google Play Billing on Android,
/// StoreKit 2 on iOS — behind a small port so widget tests run without a
/// store. The price shown is the store's localized price.
abstract interface class StoreBilling {
  /// The platform of this phone's store, or null (no store: web, desktop).
  StorePlatform? get platform;

  Future<bool> isAvailable();

  /// The store's localized prices of [productIds] (unknown ids are absent).
  Future<Map<String, String>> prices(Set<String> productIds);

  /// Every transaction update: new purchases, pending ones and the
  /// unfinished ones the store delivers again at start («استعادة»).
  Stream<List<StoreTx>> get updates;

  /// Opens the store's purchase sheet. [accountToken] binds the purchase to
  /// the account (iOS `appAccountToken`, Android `obfuscatedAccountId`).
  Future<bool> buy(String productId, String accountToken);

  /// Finishes the transaction once the server credited (or refused) it.
  Future<void> complete(StoreTx tx);
}

/// The real billing (`in_app_purchase`, the official Flutter plugin).
class InAppPurchaseBilling implements StoreBilling {
  new([InAppPurchase? iap]) : _iap = iap;

  InAppPurchase get _iapOrInstance => _iap ?? InAppPurchase.instance;

  /// Widget tests switch the real store off (test/flutter_test_config.dart):
  /// no plugin channel exists there.
  static bool enabled = true;

  final InAppPurchase? _iap;
  final Map<String, ProductDetails> _details = {};

  @override
  StorePlatform? get platform => kIsWeb || !enabled
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => StorePlatform.android,
          TargetPlatform.iOS => StorePlatform.ios,
          _ => null,
        };

  @override
  Future<bool> isAvailable() async {
    if (platform == null) return false;
    try {
      return await _iapOrInstance.isAvailable();
    } on Object catch (error) {
      debugPrint('Store billing unavailable: $error');
      return false;
    }
  }

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async {
    final res = await _iapOrInstance.queryProductDetails(productIds);
    for (final d in res.productDetails) {
      _details[d.id] = d;
    }
    return {for (final d in res.productDetails) d.id: d.price};
  }

  @override
  Stream<List<StoreTx>> get updates => platform == null
      ? const Stream.empty()
      : _iapOrInstance.purchaseStream.map(
          (list) => [
            for (final p in list)
              StoreTx(
                productId: p.productID,
                status: switch (p.status) {
                  PurchaseStatus.pending => StoreTxStatus.pending,
                  PurchaseStatus.purchased => StoreTxStatus.purchased,
                  PurchaseStatus.restored => StoreTxStatus.restored,
                  PurchaseStatus.canceled => StoreTxStatus.canceled,
                  PurchaseStatus.error => StoreTxStatus.error,
                },
                verificationData: p.verificationData.serverVerificationData,
                needsCompletion: p.pendingCompletePurchase,
                raw: p,
              ),
          ],
        );

  @override
  Future<bool> buy(String productId, String accountToken) async {
    final details =
        _details[productId] ??
        (await _iapOrInstance.queryProductDetails({productId})).productDetails
            .where((d) => d.id == productId)
            .firstOrNull;
    if (details == null) return false;
    // Android: the server consumes the purchase after crediting it (a
    // consumable); iOS consumes on finish.
    return await _iapOrInstance.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: accountToken,
      ),
      autoConsume: platform == StorePlatform.ios,
    );
  }

  @override
  Future<void> complete(StoreTx tx) async {
    final raw = tx.raw;
    if (raw is! PurchaseDetails || !raw.pendingCompletePurchase) return;
    try {
      await _iapOrInstance.completePurchase(raw);
    } on Object catch (error) {
      // Already consumed by the server (Android) — nothing left to finish.
      debugPrint('Store completePurchase: $error');
    }
  }
}

final storeBillingProvider = Provider<StoreBilling>(
  (ref) => InAppPurchaseBilling(),
);
