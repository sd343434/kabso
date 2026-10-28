import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// Live gifts (docs/contracts/openapi.yaml v1.23-live DRAFT, tag `gifts`
/// and `sendLiveGift`, CP-020; CONVENTIONS §10.23). The catalogue is managed
/// on the server and starts empty; the gift bag is filled by an admin.
/// Gifts and tabs of a category the app does not know are dropped here.
///
/// Every method throws an `AppFailure`.
abstract interface class LiveGiftRepository {
  /// `GET /gifts/catalogue`: the enabled gifts by tab, the quantities, the
  /// recipient limit and the combo window.
  Future<GiftCatalogue> catalogue();

  /// `GET /me/gifts/bag`: the gifts the caller holds, in catalogue order.
  Future<List<GiftBagItem>> bag();

  /// `POST /live/rooms/{roomId}/gifts`: [quantity] of [giftCode] to each of
  /// [recipients] (usernames). A retry with the same [clientId] returns the
  /// first send and is never charged again.
  Future<LiveGiftResult> send(
    String roomId, {
    required String giftCode,
    required int quantity,
    required List<String> recipients,
    required LiveGiftSource source,
    required String clientId,
  });

  /// `GET /live/gifts/lucky/odds` (v1.27-live, D132): the published odds and
  /// whether the caller may send lucky gifts now. Never cached.
  Future<LuckyGiftOdds> luckyOdds();

  /// `PUT /me/lucky-gifts/age-confirmation` `{adult: true}` (v1.27-live,
  /// D132): the caller states once that they are 18 or older.
  Future<void> confirmLuckyAge();

  /// `POST /live/rooms/{roomId}/sounds` `{soundCode}` (v1.32-live, D154):
  /// the host or a moderator plays the free quip [soundCode] for the whole
  /// room (one every 2 s); the answer is its slot in the room's queue.
  Future<LiveQuip> playSound(String roomId, {required String soundCode});
}

class LiveGiftRepositoryImpl implements LiveGiftRepository {
  new(this._dio);

  final Dio _dio;

  static bool _known(Object? item) =>
      item is Map<String, dynamic> &&
      GiftCategory.fromWire(item['category']) != null;

  @override
  Future<GiftCatalogue> catalogue() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/gifts/catalogue');
    final body = res.data!;
    return GiftCatalogue.fromJson({
      ...body,
      'categories': [
        for (final c in body['categories']! as List<dynamic>)
          if (GiftCategory.fromWire(c) != null) c,
      ],
      'data': [
        for (final item in body['data']! as List<dynamic>)
          if (_known(item)) item,
      ],
    });
  });

  @override
  Future<List<GiftBagItem>> bag() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/gifts/bag');
    return [
      for (final item in res.data!['data']! as List<dynamic>)
        if (_known(item)) GiftBagItem.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<LiveGiftResult> send(
    String roomId, {
    required String giftCode,
    required int quantity,
    required List<String> recipients,
    required LiveGiftSource source,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}/gifts',
      data: {
        'giftCode': giftCode,
        'quantity': quantity,
        'recipients': recipients,
        'source': switch (source) {
          LiveGiftSource.coins => 'COINS',
          LiveGiftSource.bag => 'BAG',
        },
        'clientId': clientId,
      },
    );
    return LiveGiftResult.fromJson(res.data!);
  });

  @override
  Future<LuckyGiftOdds> luckyOdds() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/live/gifts/lucky/odds');
    return LuckyGiftOdds.fromJson(res.data!);
  });

  @override
  Future<LiveQuip> playSound(String roomId, {required String soundCode}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}/sounds',
          data: {'soundCode': soundCode},
        );
        return LiveQuip.fromJson(res.data!['quip']! as Map<String, dynamic>);
      });

  @override
  Future<void> confirmLuckyAge() => guardApiCall(() async {
    await _dio.put<Map<String, dynamic>>(
      '/me/lucky-gifts/age-confirmation',
      data: {'adult': true},
    );
  });
}

final liveGiftRepositoryProvider = Provider<LiveGiftRepository>(
  (ref) => LiveGiftRepositoryImpl(ref.watch(apiDioProvider)),
);
