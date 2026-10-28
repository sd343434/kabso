import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';

import '../helpers/fake_http_adapter.dart';

/// HTTP status for each server code (CONVENTIONS.md §4).
const Map<ErrorCode, int> _statusFor = {
  ErrorCode.validationFailed: 400,
  ErrorCode.authUnauthenticated: 401,
  ErrorCode.authInvalidCredentials: 401,
  ErrorCode.authRefreshInvalid: 401,
  ErrorCode.authForbidden: 403,
  ErrorCode.accountSuspended: 403,
  ErrorCode.notFound: 404,
  ErrorCode.emailTaken: 409,
  ErrorCode.usernameTaken: 409,
  ErrorCode.idempotencyConflict: 409,
  ErrorCode.tokenExpired: 410,
  ErrorCode.tokenInvalid: 422,
  ErrorCode.rateLimited: 429,
  ErrorCode.internalError: 500,
  ErrorCode.serviceUnavailable: 503,
  ErrorCode.liveHostingUnavailable: 503,
  ErrorCode.liveRoomAlreadyActive: 409,
  ErrorCode.liveRoomEnded: 409,
  ErrorCode.liveHostingNotAllowed: 403,
  ErrorCode.liveGuestsNotAllowed: 403,
  ErrorCode.liveChatNotInRoom: 403,
  ErrorCode.liveChatMuted: 403,
  ErrorCode.liveChatClosed: 409,
  // v1.5-social
  ErrorCode.mediaUploadsUnavailable: 503,
  ErrorCode.mediaInvalid: 422,
  ErrorCode.pinLimitReached: 409,
  ErrorCode.reportAlreadyResolved: 409,
  // v1.14-live (CP-016 C)
  ErrorCode.liveScheduleFull: 409,
  // v1.19-live (CP-017)
  ErrorCode.insufficientCoins: 409,
  // v1.20-live (D105)
  ErrorCode.liveKicked: 403,
  // v1.21-live (CP-018)
  ErrorCode.alreadyInFamily: 409,
  ErrorCode.familyFull: 409,
  ErrorCode.familyNameTaken: 409,
  ErrorCode.familyRequestPending: 409,
  ErrorCode.familyRequestNotPending: 409,
  ErrorCode.familyNotEmpty: 409,
  ErrorCode.familyLeaderCannotLeave: 409,
  ErrorCode.cpAlreadyPaired: 409,
  ErrorCode.cpRequestPending: 409,
  ErrorCode.cpRequestNotPending: 409,
  ErrorCode.cpNotPaired: 409,
  ErrorCode.medalNotUnlocked: 409,
  ErrorCode.bagItemNotOwned: 409,
  ErrorCode.giftUnavailable: 409,
  ErrorCode.giftBagInsufficient: 409,
  ErrorCode.liveGiftRecipientUnavailable: 409,
  ErrorCode.luckyGiftAgeUnconfirmed: 403,
  ErrorCode.luckyGiftRegionUnavailable: 403,
  ErrorCode.cpTaskNotCompleted: 409,
  ErrorCode.cpPrivilegeLocked: 403,
  ErrorCode.familyChatMuted: 403,
  ErrorCode.premiumUsernameUnavailable: 409,
  ErrorCode.premiumUsernamePriceChanged: 409,
  ErrorCode.premiumUsernameActive: 409,
  ErrorCode.quipFreeUsed: 409,
  ErrorCode.quipQueueFull: 409,
  ErrorCode.boostQueueFull: 409,
  ErrorCode.boostCardInsufficient: 409,
  ErrorCode.boostRoomBusy: 409,
  ErrorCode.youtubeVideoUnavailable: 422,
  ErrorCode.youtubeSearchUnavailable: 503,
};

DioException _badResponse(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/x');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers),
    ),
  );
}

void main() {
  group('ErrorCode', () {
    test('covers every code of CONVENTIONS.md §4', () {
      expect(
        ErrorCode.serverCodes.map((c) => c.wire),
        unorderedEquals([
          'VALIDATION_FAILED',
          'AUTH_UNAUTHENTICATED',
          'AUTH_INVALID_CREDENTIALS',
          'AUTH_REFRESH_INVALID',
          'AUTH_FORBIDDEN',
          'ACCOUNT_SUSPENDED',
          'NOT_FOUND',
          'LIVE_HOSTING_NOT_ALLOWED',
          'LIVE_GUESTS_NOT_ALLOWED',
          'EMAIL_TAKEN',
          'USERNAME_TAKEN',
          'IDEMPOTENCY_CONFLICT',
          'TOKEN_EXPIRED',
          'TOKEN_INVALID',
          'RATE_LIMITED',
          'INTERNAL_ERROR',
          'SERVICE_UNAVAILABLE',
          // v1.3
          'LIVE_HOSTING_UNAVAILABLE',
          'LIVE_ROOM_ALREADY_ACTIVE',
          'LIVE_ROOM_ENDED',
          // v1.9-live (CP-013)
          'LIVE_CHAT_NOT_IN_ROOM',
          'LIVE_CHAT_MUTED',
          'LIVE_CHAT_CLOSED',
          // v1.5-social
          'MEDIA_UPLOADS_UNAVAILABLE',
          'MEDIA_INVALID',
          'PIN_LIMIT_REACHED',
          'REPORT_ALREADY_RESOLVED',
          // v1.14-live (CP-016 C)
          'LIVE_SCHEDULE_FULL',
          // v1.19-live (CP-017)
          'INSUFFICIENT_COINS',
          // v1.20-live (D105)
          'LIVE_KICKED',
          // v1.21-live (CP-018)
          'ALREADY_IN_FAMILY',
          'FAMILY_FULL',
          'FAMILY_NAME_TAKEN',
          'FAMILY_REQUEST_PENDING',
          'FAMILY_REQUEST_NOT_PENDING',
          'FAMILY_NOT_EMPTY',
          'FAMILY_LEADER_CANNOT_LEAVE',
          'CP_ALREADY_PAIRED',
          'CP_REQUEST_PENDING',
          'CP_REQUEST_NOT_PENDING',
          'CP_NOT_PAIRED',
          'MEDAL_NOT_UNLOCKED',
          // v1.22-live (CP-019)
          'BAG_ITEM_NOT_OWNED',
          // v1.23-live (CP-020)
          'GIFT_UNAVAILABLE',
          'GIFT_BAG_INSUFFICIENT',
          'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
          // v1.27-live (D132)
          'LUCKY_GIFT_AGE_UNCONFIRMED',
          'LUCKY_GIFT_REGION_UNAVAILABLE',
          // v1.24-live (CP-021)
          'CP_TASK_NOT_COMPLETED',
          'CP_PRIVILEGE_LOCKED',
          'FAMILY_CHAT_MUTED',
          // v1.28-live (D146)
          'PREMIUM_USERNAME_UNAVAILABLE',
          'PREMIUM_USERNAME_PRICE_CHANGED',
          'PREMIUM_USERNAME_ACTIVE',
          'QUIP_FREE_USED',
          'QUIP_QUEUE_FULL',
          'BOOST_QUEUE_FULL',
          'BOOST_CARD_INSUFFICIENT',
          'BOOST_ROOM_BUSY',
          'YOUTUBE_VIDEO_UNAVAILABLE',
          'YOUTUBE_SEARCH_UNAVAILABLE',
        ]),
      );
      expect(ErrorCode.networkOffline.wire, 'NETWORK_OFFLINE');
      expect(ErrorCode.networkTimeout.wire, 'NETWORK_TIMEOUT');
    });
  });

  group('mapDioException with the error envelope', () {
    for (final code in ErrorCode.serverCodes) {
      test('maps ${code.wire}', () {
        final failure = mapDioException(
          _badResponse(
            _statusFor[code]!,
            errorEnvelope(code.wire, 'dev text', requestId: 'rid-1'),
          ),
        );
        expect(failure, isA<ServerFailure>());
        failure as ServerFailure;
        expect(failure.code, code);
        expect(failure.rawCode, code.wire);
        expect(failure.statusCode, _statusFor[code]);
        expect(failure.requestId, 'rid-1');
        expect(failure.debugMessage, 'dev text');
      });
    }

    test('keeps validation details', () {
      final failure = mapDioException(
        _badResponse(
          400,
          errorEnvelope(
            'VALIDATION_FAILED',
            'bad',
            details: [
              {'field': 'password', 'issue': 'too_short'},
              {'field': 'device.name', 'issue': 'too_long'},
            ],
          ),
        ),
      ) as ServerFailure;
      expect(failure.details, const [
        FieldIssue(field: 'password', issue: 'too_short'),
        FieldIssue(field: 'device.name', issue: 'too_long'),
      ]);
    });

    test('parses Retry-After on RATE_LIMITED', () {
      final failure = mapDioException(
        _badResponse(
          429,
          errorEnvelope('RATE_LIMITED', 'slow down'),
          headers: {
            'retry-after': ['42'],
          },
        ),
      ) as ServerFailure;
      expect(failure.code, ErrorCode.rateLimited);
      expect(failure.retryAfter, const Duration(seconds: 42));
    });

    test('unknown codes map to ErrorCode.unknown and keep the raw code', () {
      final failure = mapDioException(
        _badResponse(418, errorEnvelope('TEAPOT_MODE', 'brew')),
      ) as ServerFailure;
      expect(failure.code, ErrorCode.unknown);
      expect(failure.rawCode, 'TEAPOT_MODE');
    });
  });

  group('mapDioException without an envelope', () {
    test('503 → SERVICE_UNAVAILABLE', () {
      expect(
        mapDioException(_badResponse(503, '<html>')).code,
        ErrorCode.serviceUnavailable,
      );
    });

    test('502 → INTERNAL_ERROR', () {
      expect(
        mapDioException(_badResponse(502, null)).code,
        ErrorCode.internalError,
      );
    });

    test('404 without body → unknown', () {
      expect(mapDioException(_badResponse(404, null)).code, ErrorCode.unknown);
    });
  });

  group('network failures (client-only codes)', () {
    final options = RequestOptions(path: '/x');

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
    ]) {
      test('$type → NETWORK_TIMEOUT', () {
        final f = mapDioException(
          DioException(requestOptions: options, type: type),
        );
        expect(f, isA<NetworkFailure>());
        expect(f.code, ErrorCode.networkTimeout);
      });
    }

    test('connectionError → NETWORK_OFFLINE', () {
      final f = mapDioException(
        DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      expect(f.code, ErrorCode.networkOffline);
    });

    test('SocketException → NETWORK_OFFLINE', () {
      final f = mapDioException(
        DioException(
          requestOptions: options,
          error: const SocketException('Failed host lookup'),
        ),
      );
      expect(f.code, ErrorCode.networkOffline);
    });

    test('a SocketException thrown by the adapter reaches the caller '
        'as NETWORK_OFFLINE', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _ThrowingAdapter();
      try {
        await dio.get<void>('/me');
        fail('expected an error');
      } on DioException catch (e) {
        expect(mapDioException(e).code, ErrorCode.networkOffline);
      }
    });

    test('cancel → unknown (UnexpectedFailure)', () {
      final f = mapDioException(
        DioException.requestCancelled(requestOptions: options, reason: null),
      );
      expect(f, isA<UnexpectedFailure>());
      expect(f.code, ErrorCode.unknown);
    });

    test('an AppFailure carried by the exception is returned as is', () {
      const inner = NetworkFailure.timeout();
      expect(
        mapDioException(DioException(requestOptions: options, error: inner)),
        same(inner),
      );
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw const SocketException('Network is unreachable');

  @override
  void close({bool force = false}) {}
}
