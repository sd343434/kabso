import 'package:dio/dio.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/network/interceptors.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';

/// Raw HTTP calls for the auth endpoints of openapi.yaml.
///
/// Paths are relative to `/api/v1`. Every method throws an `AppFailure`.
class AuthRemoteDataSource {
  new(this._dio);

  final Dio _dio;

  Future<AuthResponseDto> login(LoginRequestDto body) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: body.toJson(),
      options: publicEndpoint(),
    );
    return AuthResponseDto.fromJson(res.data!);
  });

  Future<AuthResponseDto> register(RegisterRequestDto body) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: body.toJson(),
      options: publicEndpoint(),
    );
    return AuthResponseDto.fromJson(res.data!);
  });

  Future<void> logout() => _guard(() => _dio.post<void>('/auth/logout'));

  Future<MeDto> getMe() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return MeDto.fromJson(res.data!);
  });

  Future<UsernameAvailabilityDto> usernameAvailability(String username) =>
      _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/users/username-availability',
          queryParameters: {'username': username},
          options: publicEndpoint(),
        );
        return UsernameAvailabilityDto.fromJson(res.data!);
      });

  Future<void> forgotPassword(String email) => _guard(
    () => _dio.post<void>(
      '/auth/password/forgot',
      data: {'email': email},
      options: publicEndpoint(),
    ),
  );

  Future<void> resendVerificationEmail() =>
      _guard(() => _dio.post<void>('/auth/email/resend'));

  Future<SessionListDto> listSessions() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/sessions');
    return SessionListDto.fromJson(res.data!);
  });

  Future<void> revokeSession(String sessionId) => _guard(
    () => _dio.delete<void>('/auth/sessions/${Uri.encodeComponent(sessionId)}'),
  );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    } on FormatException {
      throw const UnexpectedFailure('Malformed response');
      // A body that does not match the contract surfaces as a TypeError from
      // the generated fromJson; report it as a failure instead of crashing.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const UnexpectedFailure('Response does not match the contract');
    }
  }
}
