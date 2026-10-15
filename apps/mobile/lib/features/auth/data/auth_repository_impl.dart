import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/network/token_manager.dart';
import 'package:kabso_live/features/auth/data/auth_remote_data_source.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/auth_repository.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';

class AuthRepositoryImpl implements AuthRepository {
  new({required this._remote, required this._tokens, required this._device});

  final AuthRemoteDataSource _remote;
  final TokenManager _tokens;
  final DeviceInfoDto _device;

  @override
  Future<User?> restoreSession() async {
    if (!await _tokens.hasRefreshToken()) return null;
    await _tokens.refresh();
    return await getMe();
  }

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _remote.login(
      LoginRequestDto(
        identifier: identifier.trim(),
        password: password,
        device: _device,
      ),
    );
    await _tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String locale,
  }) async {
    final res = await _remote.register(
      RegisterRequestDto(
        email: AuthValidators.normalizeEmail(email),
        password: password,
        username: AuthValidators.normalizeUsername(username),
        displayName: displayName.trim(),
        locale: locale,
        device: _device,
      ),
    );
    await _tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  }

  @override
  Future<void> logout() async {
    try {
      if (_tokens.accessToken != null || await _tokens.hasRefreshToken()) {
        await _remote.logout();
      }
    } on AppFailure catch (f) {
      // Best effort: the local session is cleared regardless.
      AppLogger.warning('Remote logout failed: ${f.code.wire}');
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<User> getMe() async => (await _remote.getMe()).toEntity();

  @override
  Future<UsernameAvailability> checkUsernameAvailability(
    String username,
  ) async {
    final dto = await _remote.usernameAvailability(
      AuthValidators.normalizeUsername(username),
    );
    return UsernameAvailability(
      username: dto.username,
      available: dto.available,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _remote.forgotPassword(AuthValidators.normalizeEmail(email));

  @override
  Future<void> resendVerificationEmail() => _remote.resendVerificationEmail();

  @override
  Future<List<Session>> listSessions() async {
    final dto = await _remote.listSessions();
    return dto.data.map((s) => s.toEntity()).toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId) =>
      _remote.revokeSession(sessionId);
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(apiDioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokens: ref.watch(tokenManagerProvider),
    device: DeviceInfoDto(
      platform: clientPlatform(),
      appVersion: config.appVersion,
    ),
  );
});
