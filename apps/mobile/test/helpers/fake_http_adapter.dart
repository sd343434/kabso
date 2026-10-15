import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP response.
class FakeResponse {
  const new(
    this.status, {
    this.body,
    this.headers = const {},
    this.delay = Duration.zero,
  });

  const new noContent([int status = 204]) : this(status);

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
  final Duration delay;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(RequestOptions options);

/// Dio adapter that answers from registered handlers, keyed by
/// `METHOD /path` (path includes the `/api/v1` prefix). Unregistered routes
/// answer 404 `NOT_FOUND` with the contract's error envelope.
class FakeHttpAdapter implements HttpClientAdapter {
  final Map<String, FakeHandler> _routes = {};

  /// Every request that reached the adapter, in order.
  final List<RequestOptions> requests = [];

  void on(String method, String path, FakeHandler handler) {
    _routes['${method.toUpperCase()} $path'] = handler;
  }

  /// Requests made to `METHOD /path`.
  List<RequestOptions> requestsTo(String method, String path) => requests
      .where((r) => r.method == method.toUpperCase() && r.uri.path == path)
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = _routes['${options.method} ${options.uri.path}'];
    final response = handler == null
        ? FakeResponse(404, body: errorEnvelope('NOT_FOUND', 'No fake route'))
        : await handler(options);
    if (response.delay > Duration.zero) {
      await Future<void>.delayed(response.delay);
    }
    final body = response.body == null ? '' : jsonEncode(response.body);
    return ResponseBody.fromString(
      body,
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        'x-request-id': ['req-test'],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// CONVENTIONS.md §4 error envelope.
Map<String, Object?> errorEnvelope(
  String code,
  String message, {
  List<Map<String, String>>? details,
  String requestId = 'req-test',
}) => {
  'error': {
    'code': code,
    'message': message,
    'details': ?details,
    'requestId': requestId,
  },
};
