import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';

/// Performs `POST /auth/refresh` with the given refresh token.
/// Must throw an [AppFailure] on error.
typedef RefreshTokensCall = Future<AuthTokens> Function(String refreshToken);

/// Owns the session's tokens.
///
/// - Access token: memory only.
/// - Refresh token: [SecureTokenStore] only.
/// - [refresh] is single-flight: concurrent callers share one network call.
/// - When the server rejects the refresh token (`AUTH_REFRESH_INVALID`) or the
///   account is suspended (`ACCOUNT_SUSPENDED`) the local session is cleared
///   and the reason is published on [invalidations].
class TokenManager {
  new({required this._store, required this._refreshCall});

  final SecureTokenStore _store;
  final RefreshTokensCall _refreshCall;
  final _invalidations = StreamController<ErrorCode>.broadcast();

  String? _accessToken;
  Future<String>? _inflight;

  /// Incremented whenever the session is cleared, so a refresh that was in
  /// flight during sign-out cannot resurrect the session.
  int _generation = 0;

  String? get accessToken => _accessToken;

  /// Emits the failure code each time the session is invalidated by the
  /// server (not on a user-initiated sign-out).
  Stream<ErrorCode> get invalidations => _invalidations.stream;

  Future<bool> hasRefreshToken() async {
    final token = await _store.readRefreshToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    await _store.writeRefreshToken(tokens.refreshToken);
  }

  /// Clears the local session (user sign-out).
  Future<void> clear() async {
    _generation++;
    _accessToken = null;
    await _store.clear();
  }

  /// Clears the local session because the server says it is no longer valid.
  Future<void> invalidate(ErrorCode reason) async {
    AppLogger.info('Session invalidated: ${reason.wire}');
    await clear();
    if (!_invalidations.isClosed) _invalidations.add(reason);
  }

  /// Returns a fresh access token. Concurrent calls share one request.
  Future<String> refresh() {
    return _inflight ??= _doRefresh().whenComplete(() => _inflight = null);
  }

  Future<String> _doRefresh() async {
    final generation = _generation;
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      const failure = ServerFailure(
        code: ErrorCode.authRefreshInvalid,
        rawCode: 'AUTH_REFRESH_INVALID',
        debugMessage: 'No refresh token stored',
      );
      await invalidate(failure.code);
      throw failure;
    }

    final AuthTokens tokens;
    try {
      tokens = await _refreshCall(refreshToken);
    } on AppFailure catch (failure) {
      if (failure.code == ErrorCode.authRefreshInvalid ||
          failure.code == ErrorCode.accountSuspended) {
        await invalidate(failure.code);
      }
      rethrow;
    }

    if (generation != _generation) {
      // Signed out while refreshing: drop the new tokens.
      throw const ServerFailure(
        code: ErrorCode.authRefreshInvalid,
        rawCode: 'AUTH_REFRESH_INVALID',
        debugMessage: 'Session cleared during refresh',
      );
    }
    await saveTokens(tokens);
    return tokens.accessToken;
  }

  Future<void> dispose() => _invalidations.close();
}
