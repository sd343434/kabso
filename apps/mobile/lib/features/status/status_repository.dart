import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;

/// `StatusPackOption` (v1.130-social, D376): the server's price for [days].
@immutable
final class StatusPackOption {
  const new({required this.days, required this.coins});

  final int days;
  final int coins;
}

/// `StatusPack`: a pack of «متجر الحالة», its prices and the caller's end.
@immutable
final class StatusPackOffer {
  const new({
    required this.id,
    required this.emojiIds,
    required this.options,
    this.expiresAt,
  });

  static StatusPackOffer? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    if (id is! String) return null;
    final until = json['expiresAt'];
    return StatusPackOffer(
      id: id,
      emojiIds: [
        for (final e in (json['emojiIds'] as List<dynamic>? ?? const []))
          if (e is String) e,
      ],
      options: [
        for (final o in (json['options'] as List<dynamic>? ?? const []))
          if (o is Map<String, dynamic>)
            StatusPackOption(days: _int(o['days']), coins: _int(o['coins'])),
      ],
      expiresAt: until is String ? DateTime.tryParse(until) : null,
    );
  }

  final String id;
  final List<String> emojiIds;
  final List<StatusPackOption> options;

  /// The end of the caller's pack while held; null when not held.
  final DateTime? expiresAt;

  /// Held now (by the server's last answer).
  bool heldAt(DateTime now) => expiresAt?.isAfter(now) ?? false;
}

/// `StatusPackList`.
@immutable
final class StatusPackList {
  const new({required this.packs, required this.coins});

  final List<StatusPackOffer> packs;
  final int coins;

  StatusPackOffer? pack(String id) =>
      packs.where((p) => p.id == id).firstOrNull;
}

/// `StatusPackPurchaseResult`.
@immutable
final class StatusPackPurchase {
  const new({
    required this.packId,
    required this.expiresAt,
    required this.extended,
    required this.coins,
  });

  final String packId;
  final DateTime expiresAt;
  final bool extended;
  final int coins;
}

/// «الحالة» (contract v1.130-social, D376, CONVENTIONS §10.167). Every
/// method throws an `AppFailure` (`VALIDATION_FAILED`, `STORE_UNAVAILABLE`
/// `pack_not_owned` / `not_priced`, `STORE_PRICE_CHANGED`,
/// `INSUFFICIENT_COINS`, `TOPUP_ACCOUNT_FROZEN`…).
abstract interface class StatusRepository {
  /// `PUT /me/status`; null clears it. The updated `Me`.
  Future<User> setStatus(String? statusEmojiId);

  /// `GET /status-packs`.
  Future<StatusPackList> packs();

  /// `POST /status-packs/{packId}/purchases` (`Idempotency-Key`); [priceCoins]
  /// is the one shown (the server charges its own).
  Future<StatusPackPurchase> buy({
    required String packId,
    required int days,
    required int priceCoins,
    required String idempotencyKey,
  });
}

class StatusRepositoryImpl implements StatusRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<User> setStatus(String? statusEmojiId) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/me/status',
      data: {'statusEmojiId': statusEmojiId},
    );
    return MeDto.fromJson(res.data!).toEntity();
  });

  @override
  Future<StatusPackList> packs() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/status-packs');
    final body = res.data!;
    return StatusPackList(
      packs: [
        for (final p in (body['data'] as List<dynamic>? ?? const []))
          ?StatusPackOffer.fromJson(p),
      ],
      coins: _int(body['coins']),
    );
  });

  @override
  Future<StatusPackPurchase> buy({
    required String packId,
    required int days,
    required int priceCoins,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/status-packs/$packId/purchases',
      data: {'days': days, 'price': priceCoins},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data!;
    return StatusPackPurchase(
      packId: body['packId'] as String? ?? packId,
      expiresAt: DateTime.parse(body['expiresAt']! as String),
      extended: body['extended'] == true,
      coins: _int(body['coins']),
    );
  });
}

final statusRepositoryProvider = Provider<StatusRepository>(
  (ref) => StatusRepositoryImpl(ref.watch(apiDioProvider)),
);

/// «متجر الحالة»: the packs on sale and the caller's ends (read again after
/// a purchase).
final FutureProvider<StatusPackList> statusPacksProvider =
    FutureProvider.autoDispose<StatusPackList>(
      (ref) => ref.watch(statusRepositoryProvider).packs(),
    );
