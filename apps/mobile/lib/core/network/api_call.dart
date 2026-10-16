import 'package:dio/dio.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';

/// Runs one API [call] and converts every failure to an [AppFailure]:
/// transport and HTTP errors through [mapDioException], and a body that does
/// not match the contract to an [UnexpectedFailure] (never a crash).
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw mapDioException(e);
  } on FormatException {
    throw const UnexpectedFailure('Malformed response');
    // A body that does not match the contract surfaces as a TypeError from
    // the generated fromJson.
    // ignore: avoid_catching_errors
  } on TypeError {
    throw const UnexpectedFailure('Response does not match the contract');
  }
}

/// Encodes one path segment (usernames, room ids) for a request path.
String pathSegment(String value) => Uri.encodeComponent(value);
