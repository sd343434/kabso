import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kabso_live/core/error/app_failure.dart';

/// Parses the error envelope
/// `{ "error": { code, message, details?, requestId } }`.
///
/// Returns `null` when [data] is not an envelope.
ServerFailure? parseErrorEnvelope(
  Object? data, {
  int? statusCode,
  Headers? headers,
}) {
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  final rawCode = error['code'];
  if (rawCode is! String || rawCode.isEmpty) return null;

  final details = <FieldIssue>[];
  final rawDetails = error['details'];
  if (rawDetails is List) {
    for (final item in rawDetails) {
      if (item is Map) {
        final field = item['field'];
        final issue = item['issue'];
        if (field is String && issue is String) {
          details.add(FieldIssue(field: field, issue: issue));
        }
      }
    }
  }

  final message = error['message'];
  final requestId =
      error['requestId'] as Object? ?? headers?.value('x-request-id');

  return ServerFailure(
    code: ErrorCode.fromWire(rawCode),
    rawCode: rawCode,
    debugMessage: message is String ? message : rawCode,
    statusCode: statusCode,
    details: List.unmodifiable(details),
    requestId: requestId is String ? requestId : null,
    retryAfter: _parseRetryAfter(headers?.value('retry-after')),
  );
}

Duration? _parseRetryAfter(String? value) {
  if (value == null) return null;
  final seconds = int.tryParse(value.trim());
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}

/// Maps any error thrown by Dio (or by our interceptors) to an [AppFailure].
AppFailure mapDioException(DioException e) {
  final inner = e.error;
  if (inner is AppFailure) return inner;

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure.timeout();
    case DioExceptionType.connectionError:
      return const NetworkFailure.offline();
    case DioExceptionType.badCertificate:
      return const UnexpectedFailure('Bad certificate');
    case DioExceptionType.cancel:
      return const UnexpectedFailure('Request cancelled');
    case DioExceptionType.badResponse:
      return _mapBadResponse(e.response);
    case DioExceptionType.unknown:
      if (inner is SocketException || inner is HttpException) {
        return const NetworkFailure.offline();
      }
      if (e.response != null) return _mapBadResponse(e.response);
      return UnexpectedFailure(e.message ?? 'Unknown network error');
  }
}

AppFailure _mapBadResponse(Response<Object?>? response) {
  final status = response?.statusCode;
  final parsed = parseErrorEnvelope(
    response?.data,
    statusCode: status,
    headers: response?.headers,
  );
  if (parsed != null) return parsed;

  // No envelope (proxy error page, empty body, ...): derive from status.
  final code = switch (status) {
    503 => ErrorCode.serviceUnavailable,
    429 => ErrorCode.rateLimited,
    final int s when s >= 500 => ErrorCode.internalError,
    _ => ErrorCode.unknown,
  };
  return ServerFailure(
    code: code,
    rawCode: code.wire,
    debugMessage: 'HTTP $status without error envelope',
    statusCode: status,
    requestId: response?.headers.value('x-request-id'),
    retryAfter: _parseRetryAfter(response?.headers.value('retry-after')),
  );
}

/// Maps any thrown object to an [AppFailure].
AppFailure toAppFailure(Object error) => switch (error) {
  final AppFailure f => f,
  final DioException e => mapDioException(e),
  final SocketException _ => const NetworkFailure.offline(),
  _ => UnexpectedFailure(error.runtimeType.toString()),
};
