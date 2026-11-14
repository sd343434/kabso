import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/core/ids/install_id.dart';
import 'package:kabso_live/core/ids/install_source.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/network/token_manager.dart';
import 'package:kabso_live/features/auth/data/auth_remote_data_source.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/auth_repository.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';

class AuthRepositoryImpl implements AuthRepository {
  new({
    required this._remote,
    required this._tokens,
    required this._device,
    this._deviceKey,
    this._installSource,
  });

  final AuthRemoteDataSource _remote;
  final TokenManager _tokens;
  final DeviceInfoDto _device;

  /// v1.78-social (D223): the stable device key, sent with a sign-up
  /// (`register`, `registerVerify`) and, v1.60-live (D250), with a sign-in
  /// (`login`: the session keeps it, so a device the team banned is refused);
  /// null sends none.
  final DeviceKeySource? _deviceKey;

  /// v1.112-social (int21, §10.143.3): where the app was installed from,
  /// sent with every sign-in; null sends none.
  final InstallSourceReader? _installSource;

  Future<DeviceInfoDto> _signupDevice() async => _device
      .withDeviceKey(await _deviceKey?.read())
      .withInstallSource(await _installSource?.read());

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
        device: await _signupDevice(),
      ),
    );
    await _tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required Gender gender,
    required String locale,
    Map<String, dynamic>? legal,
    String? referralCode,
  }) async {
    final code = referralCode?.trim();
    await _remote.register(
      RegisterRequestDto(
        email: AuthValidators.normalizeEmail(email),
        password: password,
        username: AuthValidators.normalizeUsername(username),
        displayName: displayName.trim(),
        gender: gender.wire,
        locale: locale,
        device: await _signupDevice(),
        legal: legal,
        referralCode: code == null || code.isEmpty ? null : code,
      ),
    );
  }

  @override
  Future<User> verifyRegistration({
    required String email,
    required String code,
  }) async {
    final res = await _remote.verifyRegistration(
      RegisterVerifyRequestDto(
        email: AuthValidators.normalizeEmail(email),
        code: code,
        device: await _signupDevice(),
      ),
    );
    await _tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  }

  @override
  Future<void> resendRegistrationCode(String email) async {
    await _remote.resendRegistrationCode(AuthValidators.normalizeEmail(email));
  }

  @override
  Future<User> updateLocale(String locale) async =>
      (await _remote.updateMe(locale: locale)).toEntity();

  @override
  Future<User> updateCountry(String? country) async =>
      (await _remote.updateCountry(country)).toEntity();

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
  Future<List<Session>> listSessions() async {
    final dto = await _remote.listSessions();
    return dto.data.map((s) => s.toEntity()).toList(growable: false);
  }

  @override
  Future<void> revokeSession(String sessionId) =>
      _remote.revokeSession(sessionId);

  @override
  Future<int> revokeOtherSessions(String password) =>
      _remote.revokeOtherSessions(password);
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
      // v1.74-social (D217): the referral device check.
      installId: ref.watch(installIdProvider),
    ),
    // v1.78-social (D223): at most 2 accounts created per device.
    deviceKey: ref.watch(deviceKeySourceProvider),
    // v1.112-social (int21): the wallet's website link follows it.
    installSource: ref.watch(installSourceReaderProvider),
  );
});
