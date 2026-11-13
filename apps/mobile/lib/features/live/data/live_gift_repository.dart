import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// Live gifts (docs/contracts/openapi.yaml v1.23-live DRAFT, tag `gifts`
/// and `sendLiveGift`, CP-020; CONVENTIONS §10.23). The catalogue is managed
/// on the server and starts empty; the gift bag is filled by an admin.
/// Gifts and tabs of a malformed category code are dropped here (v1.46-live,
/// D207: the categories are managed in the admin panel, so any code is a
/// tab; its name comes in `tabs`).
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
  /// first send and is never charged again. v1.133-social (D380,
  /// §10.170.5): [anonymous] «إهداء مجهول» (ANONYMOUS_GIFT holders only).
  Future<LiveGiftResult> send(
    String roomId, {
    required String giftCode,
    required int quantity,
    required List<String> recipients,
    required LiveGiftSource source,
    required String clientId,
    bool anonymous = false,
  });

  /// `POST /live/gifts/{giftId}/reports` (v1.133-social, D380): a recipient
  /// reports the sender of a live gift (an anonymous one included) without
  /// learning who it is.
  Future<void> reportGift(String giftId, {required String reason});

  /// `PUT` / `DELETE /live/gifts/{giftId}/anonymous-block` (D380): refuse
  /// (or allow again) every further anonymous gift from the sender of this
  /// anonymous send. Returns whether it is refused now.
  Future<bool> setAnonymousSenderRefused(
    String giftId, {
    required bool refused,
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
    // v1.46-live (D207): the tabs with their names, when the API sends them
    // (an older API: the codes only, named by the app).
    final tabs = switch (body['tabs']) {
      final List<dynamic> list => [
        for (final t in list)
          if (t is Map<String, dynamic> &&
              GiftCategory.fromWire(t['code']) != null)
            t,
      ],
      _ => null,
    };
    return GiftCatalogue.fromJson({
      ...body,
      'categories': tabs != null
          ? [for (final t in tabs) t['code']]
          : [
              for (final c in body['categories']! as List<dynamic>)
                if (GiftCategory.fromWire(c) != null) c,
            ],
      'tabs': tabs ?? const <Object>[],
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
    bool anonymous = false,
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
        if (anonymous) 'anonymous': true,
      },
    );
    return LiveGiftResult.fromJson(res.data!);
  });

  @override
  Future<void> reportGift(String giftId, {required String reason}) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/live/gifts/${pathSegment(giftId)}/reports',
          data: {'reason': reason},
        );
      });

  @override
  Future<bool> setAnonymousSenderRefused(
    String giftId, {
    required bool refused,
  }) => guardApiCall(() async {
    final path = '/live/gifts/${pathSegment(giftId)}/anonymous-block';
    final res = refused
        ? await _dio.put<Map<String, dynamic>>(path)
        : await _dio.delete<Map<String, dynamic>>(path);
    return res.data?['blocked'] == true;
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
