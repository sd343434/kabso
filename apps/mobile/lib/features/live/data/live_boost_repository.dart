import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';

/// Traffic cards «بطاقة الزيارات» (docs/contracts/openapi.yaml v1.33-live
/// DRAFT; CONVENTIONS §10.34, D154b). Every method throws an `AppFailure`.
abstract interface class LiveBoostRepository {
  /// `GET /live/boosts/offers[?roomId=]`: lengths, prices, the caller's
  /// cards, when a new card would start, and [roomId]'s own card.
  Future<LiveBoostOffers> offers({String? roomId});

  /// `GET /live/boosts/active`: the lives in a paid slot now.
  Future<List<LiveBoostedRoom>> active();

  /// `POST /live/rooms/{roomId}/boosts`: a card for that live (the host,
  /// or a viewer for the host). A retry with the same [clientId] returns
  /// the first card and is never charged again.
  Future<LiveBoostResult> buy(
    String roomId, {
    required int minutes,
    required LiveBoostSource source,
    required String clientId,
  });
}

class LiveBoostRepositoryImpl implements LiveBoostRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<LiveBoostOffers> offers({String? roomId}) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/boosts/offers',
      queryParameters: {'roomId': ?roomId},
    );
    return LiveBoostOffers.fromJson(res.data!);
  });

  @override
  Future<List<LiveBoostedRoom>> active() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/live/boosts/active');
    return [
      for (final item in res.data!['data']! as List<dynamic>)
        LiveBoostedRoom.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<LiveBoostResult> buy(
    String roomId, {
    required int minutes,
    required LiveBoostSource source,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}/boosts',
      data: {'minutes': minutes, 'source': source.wire, 'clientId': clientId},
    );
    return LiveBoostResult.fromJson(res.data!);
  });
}

final liveBoostRepositoryProvider = Provider<LiveBoostRepository>(
  (ref) => LiveBoostRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The lives in a paid «مميز» slot now (the hub pins them first). A failure
/// shows none (the list under it is unchanged).
final FutureProvider<List<LiveBoostedRoom>> liveBoostedRoomsProvider =
    FutureProvider.autoDispose<List<LiveBoostedRoom>>((ref) async {
      try {
        return await ref.watch(liveBoostRepositoryProvider).active();
      } on Object {
        return const [];
      }
    });
