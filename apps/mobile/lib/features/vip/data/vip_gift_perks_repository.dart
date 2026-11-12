import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

// v1.134-social (D381, CONVENTIONS §10.171): what the member's gift, CP,
// support, rocket and voice perks give now (`MyVip.perksNow`) and the
// scheduled gifts «هدية مؤجلة» (`/me/vip/scheduled-gifts`). Kept apart from
// `vip_repository.dart` so the sibling perk branches merge cleanly. Every
// rule is the server's; the app shows what it answers.

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// The voice clip limit without LONGER_VOICE (30 s, CP-017).
const Duration defaultVoiceLimit = Duration(seconds: 30);

/// The voice clip size limit for [limit]: 1 MiB per 30 s (§10.171.8).
int voiceBytesFor(Duration limit) {
  const perThirty = 1024 * 1024;
  final seconds = limit.inSeconds <= 30 ? 30 : limit.inSeconds;
  return (perThirty * seconds / 30).ceil();
}

/// `VipMonthlyRockets`: this month's MONTHLY_ROCKETS grant.
typedef VipMonthlyRockets = ({
  int stage,
  int minutes,
  int count,
  DateTime nextAt,
});

/// `VipFreeCpRequests`: FREE_CP_REQUEST this month.
typedef VipFreeCpRequests = ({int perMonth, int used, int left});

/// `VipPerksNow` (§10.171.7): each part only while its perk is held.
@immutable
final class VipPerksNow {
  const new({
    this.monthlyRockets,
    this.freeCpRequests,
    this.maxGiftQuantity,
    this.voiceSeconds,
    this.exclusiveGifts,
    this.scheduledPending,
    this.scheduledMax,
    this.prioritySupport = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    final r = json['monthlyRockets'];
    final f = json['freeCpRequests'];
    final s = json['scheduledGifts'];
    return VipPerksNow(
      monthlyRockets: r is Map<String, dynamic>
          ? (
              stage: _int(r['stage']),
              minutes: _int(r['minutes']),
              count: _int(r['count']),
              nextAt: DateTime.parse(r['nextAt']! as String),
            )
          : null,
      freeCpRequests: f is Map<String, dynamic>
          ? (
              perMonth: _int(f['perMonth']),
              used: _int(f['used']),
              left: _int(f['left']),
            )
          : null,
      maxGiftQuantity: (json['maxGiftQuantity'] as num?)?.toInt(),
      voiceSeconds: (json['voiceSeconds'] as num?)?.toInt(),
      exclusiveGifts: (json['exclusiveGifts'] as num?)?.toInt(),
      scheduledPending: s is Map<String, dynamic> ? _int(s['pending']) : null,
      scheduledMax: s is Map<String, dynamic> ? _int(s['maxPending']) : null,
      prioritySupport: json['prioritySupport'] == true,
    );
  }

  static const none = VipPerksNow();

  final VipMonthlyRockets? monthlyRockets;
  final VipFreeCpRequests? freeCpRequests;
  final int? maxGiftQuantity;
  final int? voiceSeconds;
  final int? exclusiveGifts;

  /// SCHEDULED_GIFT: held while non-null.
  final int? scheduledPending;
  final int? scheduledMax;
  final bool prioritySupport;

  bool get scheduledGifts => scheduledPending != null;

  /// LONGER_VOICE: the caller's longest voice clip (30 s without it).
  Duration get voiceLimit {
    final s = voiceSeconds;
    return s != null && s > 30 ? Duration(seconds: s) : defaultVoiceLimit;
  }

  /// Whether any part is present (the section is hidden otherwise).
  bool get isEmpty =>
      monthlyRockets == null &&
      freeCpRequests == null &&
      maxGiftQuantity == null &&
      voiceSeconds == null &&
      exclusiveGifts == null &&
      scheduledPending == null &&
      !prioritySupport;
}

/// `VipScheduledGift.status`.
enum VipScheduledGiftStatus {
  pending('PENDING'),
  delivered('DELIVERED'),
  cancelled('CANCELLED'),
  failed('FAILED');

  new(this.wire);

  final String wire;

  static VipScheduledGiftStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? failed;
}

/// `VipScheduledGift` (§10.171.5).
@immutable
final class VipScheduledGift {
  const new({
    required this.id,
    required this.to,
    required this.giftCode,
    required this.gift,
    required this.quantity,
    required this.coins,
    required this.deliverAt,
    required this.status,
    this.failure,
  });

  factory fromJson(Map<String, dynamic> json) => VipScheduledGift(
    id: json['id']! as String,
    to: json['to'] is Map<String, dynamic>
        ? UserSummary.fromJson(json['to']! as Map<String, dynamic>)
        : null,
    giftCode: json['giftCode']! as String,
    gift: json['gift'] is Map<String, dynamic>
        ? Gift.fromJson(json['gift']! as Map<String, dynamic>)
        : null,
    quantity: _int(json['quantity']),
    coins: _int(json['coins']),
    deliverAt: DateTime.parse(json['deliverAt']! as String),
    status: VipScheduledGiftStatus.fromWire(json['status']),
    failure: json['failure'] as String?,
  );

  final String id;
  final UserSummary? to;
  final String giftCode;
  final Gift? gift;
  final int quantity;
  final int coins;
  final DateTime deliverAt;
  final VipScheduledGiftStatus status;
  final String? failure;
}

/// `VipScheduledGiftList`.
typedef VipScheduledGiftList = ({
  List<VipScheduledGift> data,
  int pending,
  int maxPending,
});

/// The D381 VIP perks API. Every method throws an `AppFailure`.
abstract interface class VipGiftPerksRepository {
  /// `GET /me/vip`'s `perksNow` (none without an active membership).
  Future<VipPerksNow> perksNow();

  /// `GET /me/vip/scheduled-gifts`.
  Future<VipScheduledGiftList> scheduled();

  /// `POST /me/vip/scheduled-gifts`; [clientId] one per confirmed tap.
  /// Returns the scheduled gift and the caller's balance.
  Future<({VipScheduledGift gift, int coins})> schedule({
    required String to,
    required String giftCode,
    required int quantity,
    required DateTime deliverAt,
    required String clientId,
  });

  /// `DELETE /me/vip/scheduled-gifts/{id}`: the coins come back.
  Future<({VipScheduledGift gift, int coins})> cancel(String id);
}

class VipGiftPerksRepositoryImpl implements VipGiftPerksRepository {
  new(this._dio);

  final Dio _dio;

  ({VipScheduledGift gift, int coins}) _result(Map<String, dynamic> body) => (
    gift: VipScheduledGift.fromJson(
      body['scheduledGift']! as Map<String, dynamic>,
    ),
    coins: _int(body['coins']),
  );

  @override
  Future<VipPerksNow> perksNow() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/vip');
    final now = res.data!['perksNow'];
    return now is Map<String, dynamic>
        ? VipPerksNow.fromJson(now)
        : VipPerksNow.none;
  });

  @override
  Future<VipScheduledGiftList> scheduled() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/vip/scheduled-gifts');
    final body = res.data!;
    return (
      data: [
        for (final e in body['data']! as List<dynamic>)
          VipScheduledGift.fromJson(e as Map<String, dynamic>),
      ],
      pending: _int(body['pending']),
      maxPending: _int(body['maxPending']),
    );
  });

  @override
  Future<({VipScheduledGift gift, int coins})> schedule({
    required String to,
    required String giftCode,
    required int quantity,
    required DateTime deliverAt,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/vip/scheduled-gifts',
      data: {
        'to': to,
        'giftCode': giftCode,
        'quantity': quantity,
        'deliverAt': deliverAt.toUtc().toIso8601String(),
        'clientId': clientId,
      },
    );
    return _result(res.data!);
  });

  @override
  Future<({VipScheduledGift gift, int coins})> cancel(String id) =>
      guardApiCall(() async {
        final res = await _dio.delete<Map<String, dynamic>>(
          '/me/vip/scheduled-gifts/${Uri.encodeComponent(id)}',
        );
        return _result(res.data!);
      });
}

final vipGiftPerksRepositoryProvider = Provider<VipGiftPerksRepository>(
  (ref) => VipGiftPerksRepositoryImpl(ref.watch(apiDioProvider)),
);
