import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';

/// v1.80-kyc (D227, CONVENTIONS §10.77): «تأكيد الهوية» with Didit.
abstract interface class KycRepository {
  /// `GET /me/kyc`; [MyKyc.off] from an older server (404).
  Future<MyKyc> mine();

  /// `POST /me/kyc/sessions` — a new Didit session, or the unfinished one.
  Future<KycSessionStart> start(KycPurpose purpose, {String? language});

  /// `POST /me/kyc/checks/{id}/sync` — the decision read from Didit now.
  Future<KycCheck> sync(String checkId);
}

class KycRepositoryImpl implements KycRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<MyKyc> mine() => guardApiCall(() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/kyc');
      return MyKyc.fromJson(res.data!);
    } on DioException catch (e) {
      // An older server has no such route: the manual ID pictures stay.
      if (e.response?.statusCode == 404) return MyKyc.off;
      rethrow;
    }
  });

  @override
  Future<KycSessionStart> start(KycPurpose purpose, {String? language}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/kyc/sessions',
          data: {'purpose': purpose.wire, 'language': ?language},
        );
        return KycSessionStart.fromJson(res.data!);
      });

  @override
  Future<KycCheck> sync(String checkId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/kyc/checks/${Uri.encodeComponent(checkId)}/sync',
    );
    return KycCheck.fromJson(res.data!);
  });
}

final kycRepositoryProvider = Provider<KycRepository>(
  (ref) => KycRepositoryImpl(ref.watch(apiDioProvider)),
);
