import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// D345 (openapi v1.110-social, CONVENTIONS §10.144): the platform a store
/// purchase is made on.
enum StorePlatform {
  android('ANDROID'),
  ios('IOS');

  new(this.wire);

  final String wire;
}

/// Why the store option is not shown (`StoreIapCatalog.unavailableReason`).
enum StoreUnavailable {
  /// The store is not configured on the server, or has no package.
  off('OFF'),

  /// This device is banned (a refund, or the team's ban).
  deviceBanned('DEVICE_BANNED'),

  /// «شراء واحد لكل حساب وجهاز» is on and this account or device bought.
  limitReached('LIMIT_REACHED');

  new(this.wire);

  final String wire;

  static StoreUnavailable? fromWire(Object? wire) =>
      values.where((v) => v.wire == wire).firstOrNull;
}

/// One store package: the store's product id and the coins it gives. The
/// price is the store's own (read from the store, never from Kabso).
@immutable
final class StoreCoinProduct {
  const new({required this.productId, required this.coins});

  final String productId;
  final int coins;
}

/// `StoreIapCatalog`.
@immutable
final class StoreCatalog {
  const new({
    required this.available,
    required this.unavailable,
    required this.products,
    required this.consentVersion,
    required this.accountToken,
    this.oncePerAccountDevice = false,
  });

  factory fromJson(Map<String, dynamic> json) => StoreCatalog(
    available: json['available'] == true,
    unavailable: StoreUnavailable.fromWire(json['unavailableReason']),
    products: [
      for (final p in (json['products'] as List<dynamic>? ?? const []))
        StoreCoinProduct(
          productId: (p as Map<String, dynamic>)['productId']! as String,
          coins: (p['coins']! as num).toInt(),
        ),
    ],
    consentVersion: json['consentVersion']! as String,
    accountToken: json['accountToken']! as String,
    oncePerAccountDevice: json['oncePerAccountDevice'] == true,
  );

  final bool available;
  final StoreUnavailable? unavailable;
  final List<StoreCoinProduct> products;
  final String consentVersion;

  /// iOS `appAccountToken`, Android `obfuscatedAccountId`.
  final String accountToken;
  final bool oncePerAccountDevice;
}

/// `StoreIapPurchaseResult`.
@immutable
final class StorePurchaseResult {
  const new({
    required this.purchaseId,
    required this.coins,
    required this.status,
    required this.balance,
    required this.alreadyProcessed,
    this.rejectReason,
    this.sandbox = false,
  });

  factory fromJson(Map<String, dynamic> json) => StorePurchaseResult(
    purchaseId: json['purchaseId']! as String,
    coins: (json['coins']! as num).toInt(),
    status: json['status']! as String,
    balance: (json['balance']! as num).toInt(),
    alreadyProcessed: json['alreadyProcessed'] == true,
    rejectReason: json['rejectReason'] as String?,
    sandbox: json['environment'] == 'SANDBOX',
  );

  final String purchaseId;
  final int coins;

  /// `CREDITED`, `REJECTED` or `REFUNDED`.
  final String status;
  final int balance;
  final bool alreadyProcessed;
  final String? rejectReason;
  final bool sandbox;

  bool get credited => status == 'CREDITED';
}

/// The no-refund consent given on the sheet (`consent` of the request).
@immutable
final class StoreConsent {
  const new({required this.version, required this.shareConsumptionData});

  final String version;
  final bool shareConsumptionData;

  Map<String, dynamic> toJson() => {
    'accepted': true,
    'version': version,
    'shareConsumptionData': shareConsumptionData,
  };
}

/// D345: the server side of store purchases. Every method throws an
/// `AppFailure`.
abstract interface class StoreIapRepository {
  /// `GET /store/iap/catalog?platform=`.
  Future<StoreCatalog> catalog(StorePlatform platform);

  /// `POST /store/iap/purchases`: the server verifies the purchase with the
  /// store and credits it once. [verificationData] is Android's purchase
  /// token or iOS's StoreKit 2 signed transaction.
  Future<StorePurchaseResult> verify({
    required StorePlatform platform,
    required String productId,
    required String verificationData,
    required StoreConsent consent,
    String? deviceKey,
  });
}

class StoreIapRepositoryImpl implements StoreIapRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<StoreCatalog> catalog(StorePlatform platform) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/store/iap/catalog',
          queryParameters: {'platform': platform.wire},
        );
        return StoreCatalog.fromJson(res.data!);
      });

  @override
  Future<StorePurchaseResult> verify({
    required StorePlatform platform,
    required String productId,
    required String verificationData,
    required StoreConsent consent,
    String? deviceKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/store/iap/purchases',
      data: {
        'platform': platform.wire,
        'productId': productId,
        if (platform == StorePlatform.android)
          'purchaseToken': verificationData
        else
          'signedTransaction': verificationData,
        'consent': consent.toJson(),
        if (deviceKey != null) 'device': {'deviceKey': deviceKey},
      },
    );
    return StorePurchaseResult.fromJson(res.data!);
  });
}

final storeIapRepositoryProvider = Provider<StoreIapRepository>(
  (ref) => StoreIapRepositoryImpl(ref.watch(apiDioProvider)),
);
