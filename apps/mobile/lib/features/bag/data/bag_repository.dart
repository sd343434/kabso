import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

/// The bag (docs/contracts/openapi.yaml v1.22-live DRAFT, tag `bag`,
/// CP-019; CONVENTIONS §10.22; v1.48-social, D171, §10.43). Items are
/// granted by the server; the app lists the ones the caller owns, chooses
/// the one worn per category and sends items to other people. The caller's
/// items of a category the app does not know are kept (D171: a new
/// category just appears in the bag); the catalogue drops them.
///
/// Every method throws an `AppFailure`.
abstract interface class BagRepository {
  /// `GET /bag/catalogue[?category=]`: every item, by category then sort
  /// order.
  Future<List<BagCatalogueItem>> catalogue({BagCategory? category});

  /// `GET /me/bag[?category=]`: the caller's items owned now, in
  /// catalogue order (every category, known or not).
  Future<List<BagItem>> myBag({BagCategory? category});

  /// `POST /me/bag/transfers` (D171): sends [code] to [username] — the
  /// whole item when [days] is null, else that many days of its time.
  Future<BagTransfer> send({
    required String code,
    required String username,
    int? days,
  });

  /// `PUT /me/bag/equipped`: wear [code] in [category] (its wire value, so
  /// a category this app does not know yet works too), or nothing when
  /// [code] is null.
  Future<BagEquipped> setEquipped(String category, String? code);
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
        return [
          for (final i in res.data!['data']! as List<dynamic>)
            BagItem.fromJson(i as Map<String, dynamic>),
        ];
      });

  @override
  Future<BagTransfer> send({
    required String code,
    required String username,
    int? days,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/bag/transfers',
      data: {'code': code, 'username': username, 'days': ?days},
    );
    return BagTransfer.fromJson(res.data!);
  });

  @override
  Future<BagEquipped> setEquipped(String category, String? code) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/bag/equipped',
          data: {'category': category, 'code': code},
        );
        return BagEquipped.fromJson(res.data!);
      });
}

final bagRepositoryProvider = Provider<BagRepository>(
  (ref) => BagRepositoryImpl(ref.watch(apiDioProvider)),
);
