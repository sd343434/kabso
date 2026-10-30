import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';

/// The live hub's promo banners (openapi v1.26-live draft, D124, tag
/// `home`). Every method throws an `AppFailure`.
abstract interface class HomeBannersRepository {
  /// `GET /home/banners`: the active banners in server order (possibly
  /// empty; at most 10). D137: [room] lists the in-room promo box's
  /// (`placement=room`, 3:4 pictures) instead of the hub's. D177: [wallet]
  /// lists the wallet page's (`placement=wallet`, 3:1, openapi
  /// v1.51-social).
  Future<List<HomeBanner>> listBanners({
    bool room = false,
    bool wallet = false,
  });
}

class HomeBannersRepositoryImpl implements HomeBannersRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<HomeBanner>> listBanners({
    bool room = false,
    bool wallet = false,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/home/banners',
      queryParameters: room
          ? const {'placement': 'room'}
          : wallet
          ? const {'placement': 'wallet'}
          : null,
    );
    final data = res.data!['data']! as List<dynamic>;
    return [
      for (final item in data)
        HomeBanner.fromJson(item as Map<String, dynamic>),
    ];
  });
}

/// Demo mode (test builds) has no banners: nothing is invented (D39).
class _NoBanners implements HomeBannersRepository {
  const new();

  @override
  Future<List<HomeBanner>> listBanners({
    bool room = false,
    bool wallet = false,
  }) async => const [];
}

final homeBannersRepositoryProvider = Provider<HomeBannersRepository>(
  (ref) => watchDemo(ref)
      ? const _NoBanners()
      : HomeBannersRepositoryImpl(ref.watch(apiDioProvider)),
);
