import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

/// `RechargeOrderStatus` (openapi v1.69-social, D204, CONVENTIONS §10.64). An
/// unknown value reads as [unknown] (shown generically).
enum RechargeOrderStatus {
  requested('REQUESTED'),
  awaitingPayment('AWAITING_PAYMENT'),
  paid('PAID'),
  disputed('DISPUTED'),
  completed('COMPLETED'),
  completedByAdmin('COMPLETED_BY_ADMIN'),
  refundedToAgent('REFUNDED_TO_AGENT'),
  cancelled('CANCELLED'),
  expired('EXPIRED'),
  unknown('');

  new(this.wire);

  final String wire;

  static RechargeOrderStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire && s != unknown).firstOrNull ??
      unknown;

  /// REQUESTED, AWAITING_PAYMENT, PAID or DISPUTED.
  bool get isOpen =>
      this == requested ||
      this == awaitingPayment ||
      this == paid ||
      this == disputed;
}

/// `RechargeOrderAction`: what the caller may do now (the server checks
/// again).
enum RechargeOrderAction {
  message('MESSAGE'),
  sendDetails('SEND_DETAILS'),
  ackNotice('ACK_NOTICE'),
  markPaid('MARK_PAID'),
  confirm('CONFIRM'),
  dispute('DISPUTE'),
  cancel('CANCEL');

  new(this.wire);

  final String wire;

  static RechargeOrderAction? fromWire(Object? wire) =>
      values.where((a) => a.wire == wire).firstOrNull;
}

/// `RechargePrice`: USD always; the local amount when an admin set a rate.
@immutable
final class RechargePrice {
  const new({required this.usdMinor, required this.usd, this.local});

  factory fromJson(Map<String, dynamic> json) {
    final l = json['local'] as Map<String, dynamic>?;
    return RechargePrice(
      usdMinor: _int(json['usdMinor']),
      usd: json['usd']! as String,
      local: l == null
          ? null
          : (
              currency: l['currency']! as String,
              amount: l['amount']! as String,
              rate: l['rate']! as String,
            ),
    );
  }

  final int usdMinor;

  /// `12.50`.
  final String usd;
  final ({String currency, String amount, String rate})? local;
}

/// `RechargeOrderQuote`.
@immutable
final class RechargeOrderQuote {
  const new({
    required this.coins,
    required this.price,
    required this.paymentTypes,
    required this.minCoins,
    required this.maxCoins,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeOrderQuote(
    coins: _int(json['coins']),
    price: RechargePrice.fromJson(json['price']! as Map<String, dynamic>),
    paymentTypes: [
      for (final t in json['paymentMethodTypes']! as List<dynamic>)
        RechargePaymentType.fromWire(t),
    ],
    minCoins: _int(json['minCoins']),
    maxCoins: _int(json['maxCoins']),
  );

  final int coins;
  final RechargePrice price;
  final List<RechargePaymentType> paymentTypes;
  final int minCoins;
  final int maxCoins;
}

/// `RechargeOrder`.
@immutable
final class RechargeOrder {
  const new({
    required this.id,
    required this.status,
    required this.viewerRole,
    required this.buyer,
    required this.agent,
    required this.agentCode,
    required this.country,
    required this.coins,
    required this.price,
    required this.paymentType,
    required this.heldCoins,
    required this.noticeAcknowledged,
    required this.actions,
    required this.createdAt,
    this.paidAt,
    this.disputeOpensAt,
    this.disputedBy,
    this.closeReason,
    this.expiresAt,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeOrder(
    id: json['id']! as String,
    status: RechargeOrderStatus.fromWire(json['status']),
    viewerRole: json['viewerRole']! as String,
    buyer: UserSummary.fromJson(json['buyer']! as Map<String, dynamic>),
    agent: UserSummary.fromJson(json['agent']! as Map<String, dynamic>),
    agentCode: json['agentCode']! as String,
    country: json['country']! as String,
    coins: _int(json['coins']),
    price: RechargePrice.fromJson(json['price']! as Map<String, dynamic>),
    paymentType: RechargePaymentType.fromWire(json['paymentType']),
    heldCoins: _int(json['heldCoins']),
    noticeAcknowledged: json['noticeAcknowledged'] == true,
    paidAt: _date(json['paidAt']),
    disputeOpensAt: _date(json['disputeOpensAt']),
    disputedBy: json['disputedBy'] as String?,
    closeReason: json['closeReason'] as String?,
    expiresAt: _date(json['expiresAt']),
    actions: {
      for (final a in json['actions']! as List<dynamic>)
        ?RechargeOrderAction.fromWire(a),
    },
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;
  final RechargeOrderStatus status;

  /// `BUYER`, `AGENT` or `EMPLOYEE`.
  final String viewerRole;
  final UserSummary buyer;
  final UserSummary agent;
  final String agentCode;
  final String country;
  final int coins;
  final RechargePrice price;
  final RechargePaymentType paymentType;
  final int heldCoins;
  final bool noticeAcknowledged;
  final DateTime? paidAt;

  /// From when the buyer may open a dispute (`paidAt` + 15 minutes).
  final DateTime? disputeOpensAt;
  final String? disputedBy;
  final String? closeReason;
  final DateTime? expiresAt;
  final Set<RechargeOrderAction> actions;
  final DateTime createdAt;

  bool get isBuyer => viewerRole == 'BUYER';

  /// The other side's summary (the agent for the buyer, else the buyer).
  UserSummary get other => isBuyer ? agent : buyer;

  bool can(RechargeOrderAction a) => actions.contains(a);
}

/// `RechargeOrderMessage`: a line of the order's chat.
@immutable
final class RechargeOrderMessage {
  const new({
    required this.id,
    required this.kind,
    required this.role,
    required this.hasImage,
    required this.createdAt,
    this.author,
    this.text,
    this.method,
    this.event,
  });

  factory fromJson(Map<String, dynamic> json) => RechargeOrderMessage(
    id: json['id']! as String,
    kind: json['kind']! as String,
    role: json['role']! as String,
    author: switch (json['author']) {
      final Map<String, dynamic> a => UserSummary.fromJson(a),
      _ => null,
    },
    text: json['text'] as String?,
    method: json['method'] == null
        ? null
        : RechargePaymentType.fromWire(json['method']),
    event: json['event'] as String?,
    hasImage: json['hasImage'] == true,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;

  /// TEXT, IMAGE, PAYMENT_DETAILS, TRANSFER_PROOF or SYSTEM.
  final String kind;

  /// BUYER, AGENT, EMPLOYEE, ADMIN («الإدارة») or SYSTEM.
  final String role;
  final UserSummary? author;
  final String? text;
  final RechargePaymentType? method;
  final String? event;
  final bool hasImage;
  final DateTime createdAt;

  bool get isSystem => kind == 'SYSTEM';
}

/// Recharge orders «طلبات الشحن» (openapi v1.69-social, D204). Every method
/// throws an `AppFailure`.
abstract interface class RechargeOrdersRepository {
  Future<RechargeOrderQuote> quote({
    required String agentCode,
    required String country,
    required int coins,
  });
  Future<RechargeOrder> create({
    required String agentCode,
    required String country,
    required int coins,
    required RechargePaymentType paymentType,
    required String idempotencyKey,
  });
  Future<PageResult<RechargeOrder>> list({
    required bool asAgent,
    String? cursor,
  });
  Future<RechargeOrder> get(String id);

  /// The chat, oldest first (the newest [limit] lines).
  Future<List<RechargeOrderMessage>> messages(String id, {int limit = 100});
  Future<RechargeOrderMessage> sendText(String id, String text);
  Future<RechargeOrderMessage> sendImage(String id, Uint8List bytes);
  Future<Uint8List> image(String id, String messageId);
  Future<RechargeOrder> sendDetails(
    String id,
    RechargePaymentType method,
    String details,
  );
  Future<RechargeOrder> acknowledgeNotice(String id);
  Future<RechargeOrder> markPaid(String id, Uint8List screenshot);
  Future<RechargeOrder> confirm(String id);
  Future<RechargeOrder> dispute(String id, {String? reason});
  Future<RechargeOrder> cancel(String id, {String? reason});
}

class RechargeOrdersRepositoryImpl implements RechargeOrdersRepository {
  new(this._dio, this._storage);

  final Dio _dio;

  /// A bare client for the presigned upload URL (never the bearer token).
  final Dio _storage;

  String _path(String id) => '/recharge-orders/${pathSegment(id)}';

  @override
  Future<RechargeOrderQuote> quote({
    required String agentCode,
    required String country,
    required int coins,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recharge-orders/quote',
      queryParameters: {
        'agentCode': agentCode,
        'country': country,
        'coins': coins,
      },
    );
    return RechargeOrderQuote.fromJson(res.data!);
  });

  @override
  Future<RechargeOrder> create({
    required String agentCode,
    required String country,
    required int coins,
    required RechargePaymentType paymentType,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recharge-orders',
      data: {
        'agentCode': agentCode,
        'country': country,
        'coins': coins,
        'paymentType': paymentType.wire,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return RechargeOrder.fromJson(res.data!);
  });

  @override
  Future<PageResult<RechargeOrder>> list({
    required bool asAgent,
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recharge-orders',
      queryParameters: {'role': asAgent ? 'agent' : 'buyer', 'cursor': ?cursor},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final e in body['data']! as List<dynamic>)
          RechargeOrder.fromJson(e as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<RechargeOrder> get(String id) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path(id));
    return RechargeOrder.fromJson(res.data!);
  });

  @override
  Future<List<RechargeOrderMessage>> messages(String id, {int limit = 100}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_path(id)}/messages',
          queryParameters: {'limit': limit},
        );
        return [
          for (final e in (res.data!['data']! as List<dynamic>).reversed)
            RechargeOrderMessage.fromJson(e as Map<String, dynamic>),
        ];
      });

  @override
  Future<RechargeOrderMessage> sendText(String id, String text) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_path(id)}/messages',
          data: {'text': text},
        );
        return RechargeOrderMessage.fromJson(res.data!);
      });

  /// Slot and PUT only: the order consumes the private upload (never
  /// completed, never public, §10.64.3).
  Future<String> _privateUpload(Uint8List bytes) async {
    final type = sniffImageType(bytes);
    if (type == null) {
      throw const FormatException('Not a JPEG, PNG or WebP picture');
    }
    final slot = (await _dio.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {
        'kind': 'RECHARGE_ORDER_IMAGE',
        'contentType': type,
        'byteSize': bytes.length,
      },
    )).data!;
    final headers = {
      for (final e in (slot['headers']! as Map<String, dynamic>).entries)
        e.key: e.value as String,
    };
    await _storage.put<void>(
      slot['uploadUrl']! as String,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: headers, contentType: headers['Content-Type']),
    );
    return slot['uploadId']! as String;
  }

  @override
  Future<RechargeOrderMessage> sendImage(String id, Uint8List bytes) =>
      guardApiCall(() async {
        final upload = await _privateUpload(bytes);
        final res = await _dio.post<Map<String, dynamic>>(
          '${_path(id)}/messages',
          data: {'imageUploadId': upload},
        );
        return RechargeOrderMessage.fromJson(res.data!);
      });

  @override
  Future<Uint8List> image(String id, String messageId) =>
      guardApiCall(() async {
        final res = await _dio.get<List<int>>(
          '${_path(id)}/messages/${pathSegment(messageId)}/image',
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data!);
      });

  Future<RechargeOrder> _act(String id, String action, [Object? body]) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_path(id)}/$action',
          data: body ?? const <String, Object?>{},
        );
        return RechargeOrder.fromJson(res.data!);
      });

  @override
  Future<RechargeOrder> sendDetails(
    String id,
    RechargePaymentType method,
    String details,
  ) => _act(id, 'payment-details', {'method': method.wire, 'details': details});

  @override
  Future<RechargeOrder> acknowledgeNotice(String id) => _act(id, 'notice-ack');

  @override
  Future<RechargeOrder> markPaid(String id, Uint8List screenshot) =>
      guardApiCall(() async {
        final upload = await _privateUpload(screenshot);
        final res = await _dio.post<Map<String, dynamic>>(
          '${_path(id)}/paid',
          data: {'proofUploadId': upload},
        );
        return RechargeOrder.fromJson(res.data!);
      });

  @override
  Future<RechargeOrder> confirm(String id) => _act(id, 'confirm');

  @override
  Future<RechargeOrder> dispute(String id, {String? reason}) =>
      _act(id, 'dispute', {'reason': ?reason});

  @override
  Future<RechargeOrder> cancel(String id, {String? reason}) =>
      _act(id, 'cancel', {'reason': ?reason});
}

final rechargeOrdersRepositoryProvider = Provider<RechargeOrdersRepository>(
  (ref) => RechargeOrdersRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);
