import 'dart:math';

import 'package:dio/dio.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/network/token_manager.dart';

/// Request option `extra` keys shared by the interceptors.
abstract final class RequestExtras {
  /// Set to `true` on public endpoints (login, register, refresh, ...): no
  /// bearer token is attached and a 401 never triggers a refresh.
  static const skipAuth = 'kabso.skipAuth';

  static const retried = 'kabso.retried';
  static const sentToken = 'kabso.sentToken';
  static const startedAt = 'kabso.startedAt';
}

/// Options for a public (unauthenticated) endpoint.
Options publicEndpoint([Options? base]) =>
    (base ?? Options()).copyWith(extra: {RequestExtras.skipAuth: true});

/// Adds `X-Request-Id` (UUID v4) unless the caller already set one.
class RequestIdInterceptor extends Interceptor {
  new({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-Id', _uuidV4);
    handler.next(options);
  }

  String _uuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Adds `Accept-Language` (current app locale) and the informational
/// `X-Client` header.
class ClientHeadersInterceptor extends Interceptor {
  new({required this._languageCode, required this._clientId});

  final String Function() _languageCode;
  final String _clientId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = _languageCode();
    options.headers['X-Client'] = _clientId;
    handler.next(options);
  }
}

/// Attaches the bearer token and runs the refresh-once-and-retry protocol
/// from CONVENTIONS.md §6.
class AuthInterceptor extends Interceptor {
  new({required this._tokens, required this._dio});

  final TokenManager _tokens;
  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[RequestExtras.skipAuth] != true) {
      final token = _tokens.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
      options.extra[RequestExtras.sentToken] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final response = err.response;
    if (response == null || options.extra[RequestExtras.skipAuth] == true) {
      return handler.next(err);
    }

    final failure = parseErrorEnvelope(
      response.data,
      statusCode: response.statusCode,
      headers: response.headers,
    );

    if (failure?.code == ErrorCode.accountSuspended ||
        failure?.code == ErrorCode.authRefreshInvalid) {
      await _tokens.invalidate(failure!.code);
      return handler.next(err);
    }

    final shouldRefresh =
        response.statusCode == 401 &&
        failure?.code == ErrorCode.authUnauthenticated &&
        options.extra[RequestExtras.retried] != true;
    if (!shouldRefresh) return handler.next(err);

    try {
      final sent = options.extra[RequestExtras.sentToken];
      final current = _tokens.accessToken;
      // Another request may already have refreshed while this one was in
      // flight; reuse that token instead of refreshing again.
      if (current == null || current == sent) {
        await _tokens.refresh();
      }
      final retryOptions = options.copyWith(
        extra: {...options.extra, RequestExtras.retried: true},
      );
      final retried = await _dio.fetch<Object?>(retryOptions);
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    } on AppFailure catch (f) {
      return handler.next(err.copyWith(error: f));
    }
  }
}

/// Logs method, path, status, duration and request id. Never logs headers or
/// bodies (they may contain credentials).
class SafeLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[RequestExtras.startedAt] =
        DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(_line(response.requestOptions, response.statusCode));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = mapDioException(err);
    AppLogger.debug(
      '${_line(err.requestOptions, err.response?.statusCode)} '
      '${failure.code.wire}',
    );
    handler.next(err);
  }

  String _line(RequestOptions o, int? status) {
    final started = o.extra[RequestExtras.startedAt];
    final ms = started is int
        ? DateTime.now().millisecondsSinceEpoch - started
        : null;
    return '${o.method} ${o.path} -> ${status ?? '-'}'
        '${ms == null ? '' : ' (${ms}ms)'} rid=${o.headers['X-Request-Id']}';
  }
}
