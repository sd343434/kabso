import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

/// The bag (docs/contracts/openapi.yaml v1.22-live DRAFT, tag `bag`,
/// CP-019; CONVENTIONS §10.22). Items are granted by the server; the app
/// lists them and chooses the one worn per category. Items of categories
/// the app does not know are dropped here.
///
/// Every method throws an `AppFailure`.
abstract interface class BagRepository {
  /// `GET /bag/catalogue[?category=]`: every item, by category then sort
  /// order.
  Future<List<BagCatalogueItem>> catalogue({BagCategory? category});

  /// `GET /me/bag[?category=]`: the caller's items in catalogue order.
  Future<List<BagItem>> myBag({BagCategory? category});

  /// `PUT /me/bag/equipped`: wear [code] in [category], or nothing when
  /// [code] is null.
  Future<BagEquipped> setEquipped(BagCategory category, String? code);
}

class BagRepositoryImpl implements BagRepository {
  new(this._dio);

  final Dio _dio;

  static Map<String, dynamic>? _query(BagCategory? category) =>
      category == null ? null : {'category': category.wire};

  static Iterable<Map<String, dynamic>> _known(Map<String, dynamic> body) => [
    for (final item in body['data']! as List<dynamic>)
      if (BagCategory.fromWire(
            (item as Map<String, dynamic>)['category'] as String?,
          ) !=
          null)
        item,
  ];

  @override
  Future<List<BagCatalogueItem>> catalogue({BagCategory? category}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/bag/catalogue',
          queryParameters: _query(category),
        );
        return [
          for (final i in _known(res.data!)) BagCatalogueItem.fromJson(i),
        ];
      });

  @override
  Future<List<BagItem>> myBag({BagCategory? category}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/me/bag',
          queryParameters: _query(category),
        );
        return [for (final i in _known(res.data!)) BagItem.fromJson(i)];
      });

  @override
  Future<BagEquipped> setEquipped(BagCategory category, String? code) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/bag/equipped',
          data: {'category': category.wire, 'code': code},
        );
        return BagEquipped.fromJson(res.data!);
      });
}

final bagRepositoryProvider = Provider<BagRepository>(
  (ref) => BagRepositoryImpl(ref.watch(apiDioProvider)),
);
