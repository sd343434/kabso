import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/core/ids/install_source.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/network/token_manager.dart';
import 'package:kabso_live/features/auth/data/auth_remote_data_source.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

/// `AccountDeletionBlocker` (v1.62-social, D193, CONVENTIONS §10.56): what
/// must be settled before the account can be deleted. Unknown values (a newer
/// server) are kept as [other] so the screen still blocks.
enum DeletionBlocker {
  rechargeAgent('recharge_agent'),
  hostAgency('host_agency'),
  pendingWithdrawal('pending_withdrawal'),
  pendingCherrySale('pending_cherry_sale'),
  negativeBalance('negative_balance'),
  other('');

  new(this.wire);

  final String wire;

  static DeletionBlocker fromWire(String value) => values.firstWhere(
    (b) => b.wire == value && b != other,
    orElse: () => other,
  );
}

/// `AccountDeletionInfo`: the explanation screen's data.
@immutable
final class AccountDeletionInfo {
  const new({
    required this.graceDays,
    required this.blockers,
    required this.supportEmail,
  });

  factory fromJson(Map<String, dynamic> json) => AccountDeletionInfo(
    graceDays: (json['graceDays']! as num).toInt(),
    blockers: [
      for (final b in json['blockers']! as List<dynamic>)
        DeletionBlocker.fromWire(b as String),
    ],
    supportEmail: json['supportEmail']! as String,
  );

  final int graceDays;
  final List<DeletionBlocker> blockers;
  final String supportEmail;
}

/// `AccountDeletionRequest`: the scheduled deletion.
@immutable
final class AccountDeletionRequest {
  const new({required this.requestedAt, required this.purgeAfter});

  factory fromJson(Map<String, dynamic> json) => AccountDeletionRequest(
    requestedAt: DateTime.parse(json['requestedAt']! as String),
    purgeAfter: DateTime.parse(json['purgeAfter']! as String),
  );

  final DateTime requestedAt;
  final DateTime purgeAfter;
}

/// In-app account deletion «حذف الحساب» (openapi v1.62-social DRAFT, D193).
///
/// Every method throws an `AppFailure`.
abstract interface class AccountDeletionRepository {
  /// `GET /me/account-deletion`.
  Future<AccountDeletionInfo> info();

  /// `POST /me/account-deletion` → 202. 403 `REAUTH_FAILED` for a wrong
  /// password, 409 `ACCOUNT_DELETION_BLOCKED` with the blockers. On success
  /// the server has already revoked every session (this one too).
  Future<AccountDeletionRequest> request({
    required String password,
    required String confirmation,
  });

  /// `POST /auth/login` with `cancelDeletion: true`: the deletion is
  /// cancelled, the account is back as it was and the session is stored
  /// (like a sign-in).
  Future<User> cancelAndSignIn({
    required String identifier,
    required String password,
  });
}

class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  new(
    this._dio, {
    required this._remote,
    required this._tokens,
    required this._device,
    this._deviceKey,
    this._installSource,
  });

  final Dio _dio;
  final AuthRemoteDataSource _remote;
  final TokenManager _tokens;
  final DeviceInfoDto _device;

  /// v1.60-live (D250): the device key sent with a sign-in (null: none).
  final DeviceKeySource? _deviceKey;

  /// v1.112-social (int21, §10.143.3): the install source sent with a sign-in.
  final InstallSourceReader? _installSource;

  @override
  Future<User> cancelAndSignIn({
    required String identifier,
    required String password,
  }) async {
    final res = await _remote.login(
      LoginRequestDto(
        identifier: identifier.trim(),
        password: password,
        device: _device
            .withDeviceKey(await _deviceKey?.read())
            .withInstallSource(await _installSource?.read()),
      ),
      cancelDeletion: true,
    );
    await _tokens.saveTokens(res.tokens);
    return res.user.toEntity();
  }

  @override
  Future<AccountDeletionInfo> info() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/account-deletion');
    return AccountDeletionInfo.fromJson(res.data!);
  });

  @override
  Future<AccountDeletionRequest> request({
    required String password,
    required String confirmation,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/account-deletion',
      data: {'password': password, 'confirmation': confirmation},
    );
    return AccountDeletionRequest.fromJson(res.data!);
  });
}

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  return AccountDeletionRepositoryImpl(
    ref.watch(apiDioProvider),
    remote: ref.watch(authRemoteDataSourceProvider),
    tokens: ref.watch(tokenManagerProvider),
    device: DeviceInfoDto(
      platform: clientPlatform(),
      appVersion: config.appVersion,
    ),
    deviceKey: ref.watch(deviceKeySourceProvider),
    installSource: ref.watch(installSourceReaderProvider),
  );
});

/// The caller's deletion information (the explanation step).
final FutureProvider<AccountDeletionInfo> accountDeletionInfoProvider =
    FutureProvider.autoDispose<AccountDeletionInfo>(
      (ref) => ref.watch(accountDeletionRepositoryProvider).info(),
    );

/// D193: what the deletion-pending screen needs after a sign-in answered 409
/// `ACCOUNT_DELETION_PENDING` — the credentials just typed (kept in memory
/// only, to cancel with one tap) and the purge date.
@immutable
final class PendingDeletionSignIn {
  const new({
    required this.identifier,
    required this.password,
    required this.purgeAfter,
  });

  final String identifier;
  final String password;

  /// Null when the server did not say (shown without a date).
  final DateTime? purgeAfter;
}

class PendingDeletionSignInController extends Notifier<PendingDeletionSignIn?> {
  @override
  PendingDeletionSignIn? build() => null;

  PendingDeletionSignIn? get value => state;

  set value(PendingDeletionSignIn? next) => state = next;
}

final NotifierProvider<PendingDeletionSignInController, PendingDeletionSignIn?>
pendingDeletionSignInProvider =
    NotifierProvider<PendingDeletionSignInController, PendingDeletionSignIn?>(
      PendingDeletionSignInController.new,
    );
