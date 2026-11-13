import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/features/store_iap/data/store_billing.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';

/// D345: a store on the phone, driven by the test (no plugin channel).
class FakeStoreBilling implements StoreBilling {
  new({
    this.platform = StorePlatform.android,
    Map<String, String>? prices,
    this.available = true,
  }) : storePrices = prices ?? const {'coins_1m': r'$12.99'};

  @override
  final StorePlatform? platform;
  final Map<String, String> storePrices;
  bool available;
  final bought = <(String, String)>[];
  final completed = <StoreTx>[];
  final _updates = StreamController<List<StoreTx>>.broadcast();

  void emit(List<StoreTx> txs) => _updates.add(txs);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, String>> prices(Set<String> productIds) async => {
    for (final id in productIds) id: ?storePrices[id],
  };

  @override
  Stream<List<StoreTx>> get updates => _updates.stream;

  @override
  Future<bool> buy(String productId, String accountToken) async {
    bought.add((productId, accountToken));
    return true;
  }

  @override
  Future<void> complete(StoreTx tx) async => completed.add(tx);
}

/// D345: the server's catalogue and verification, as the test sets them.
class FakeStoreIapRepository implements StoreIapRepository {
  new({StoreCatalog? catalog}) : current = catalog ?? storeCatalog();

  StoreCatalog current;
  final verified = <Map<String, Object?>>[];
  StorePurchaseResult Function(String verificationData)? answer;
  AppFailure? failure;

  @override
  Future<StoreCatalog> catalog(StorePlatform platform) async => current;

  @override
  Future<StorePurchaseResult> verify({
    required StorePlatform platform,
    required String productId,
    required String verificationData,
    required StoreConsent consent,
    String? deviceKey,
  }) async {
    verified.add({
      'platform': platform,
      'productId': productId,
      'verificationData': verificationData,
      'version': consent.version,
      'share': consent.shareConsumptionData,
      'deviceKey': deviceKey,
    });
    if (failure case final f?) throw f;
    return answer?.call(verificationData) ??
        const StorePurchaseResult(
          purchaseId: '0192f1c2-0000-7000-8000-00000000d345',
          coins: 1000000,
          status: 'CREDITED',
          balance: 1000000,
          alreadyProcessed: false,
        );
  }
}

StoreCatalog storeCatalog({
  bool available = true,
  StoreUnavailable? unavailable,
  List<StoreCoinProduct> products = const [
    StoreCoinProduct(productId: 'coins_1m', coins: 1000000),
  ],
}) => StoreCatalog(
  available: available,
  unavailable: unavailable,
  products: available ? products : const [],
  consentVersion: '2026-11-09',
  accountToken: 'a' * 64,
);

class FakeDeviceKeySource implements DeviceKeySource {
  @override
  Future<String?> read() async => 'd' * 64;
}
