import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v1.108-social (D343, CONVENTIONS §10.142): the sign-up field «رمز الدعوة
/// أو رمز المشرف» — a friend's invite code (D217) or a supervisor's staff ID
/// («Kabso07», D285) — and where it can come from without typing:
///
/// - **Android, Google Play**: the personal link
///   `https://kabsolive.com/i/<code>` opens Play with
///   `&referrer=kabso_code%3D<code>`; the app reads it once per install with
///   the Play Install Referrer API (Google's `installreferrer` library over
///   the `com.kabso/install_referrer` channel in `MainActivity.kt`).
/// - **Anywhere else** (the direct APK, iOS): the landing page offers «نسخ
///   الرمز» and the sign-up screen offers «لصق» — the clipboard is read only
///   when the person taps it, never silently.
///
/// No fingerprinting: no IP or user-agent matching.
enum SignupCodeKind { invite, supervisor }

/// What `checkSignupCode` said about a code.
sealed class SignupCodeCheck {
  const new();
}

/// Someone can use it now: [kind], and the stored form [code].
final class SignupCodeValid extends SignupCodeCheck {
  const new(this.kind, this.code);
  final SignupCodeKind kind;
  final String code;
}

/// Nobody can use it now (unknown, a closed account, someone who cannot
/// recruit), or it can be neither kind — never told apart.
final class SignupCodeNotFound extends SignupCodeCheck {
  const new();
}

abstract interface class SignupCodeRepository {
  /// `POST /auth/signup-code/check`. Throws on a network or server failure
  /// (the field then shows nothing and the server decides at sign-up).
  Future<SignupCodeCheck> check(String code);
}

class ApiSignupCodeRepository implements SignupCodeRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<SignupCodeCheck> check(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/signup-code/check',
        data: {'code': code},
      );
      final body = res.data ?? const {};
      final kind = body['kind'] == 'SUPERVISOR'
          ? SignupCodeKind.supervisor
          : SignupCodeKind.invite;
      return SignupCodeValid(kind, body['code'] as String? ?? code);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return const SignupCodeNotFound();
      rethrow;
    }
  }
}

final signupCodeRepositoryProvider = Provider<SignupCodeRepository>(
  (ref) => ApiSignupCodeRepository(ref.watch(apiDioProvider)),
);

/// How long the field waits after typing before it asks the server.
final signupCodeDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 500),
);

final _inviteLink = RegExp(r'/i/([A-Za-z0-9@-]{2,32})/?(?:[?#]\S*)?$');
final _staffId = RegExp(r'^@?kabso[0-9]{0,9}$', caseSensitive: false);

/// D217's invite codes: 8 characters without 0/O, 1/I/L and U.
final _inviteCode = RegExp(
  r'^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$',
  caseSensitive: false,
);

/// The code in [text] — a bare code or staff ID, or the last part of an
/// invite link `…/i/<code>` (as pasted from the website or a message) — or
/// null when there is none. The server reads the same forms.
String? extractSignupCode(String text) {
  var v = text.trim();
  if (v.isEmpty || v.length > 200) return null;
  final link = _inviteLink.firstMatch(v);
  if (link != null) v = link.group(1)!;
  v = v.replaceAll(RegExp(r'[\s-]+'), '');
  if (_staffId.hasMatch(v)) return v.replaceFirst('@', '');
  if (_inviteCode.hasMatch(v)) return v.toUpperCase();
  return null;
}

/// The Play Install Referrer of this install (Android, Google Play only):
/// the raw referrer string, or null (another store, the APK, iOS, an error).
abstract interface class InstallReferrerSource {
  Future<String?> read();
}

class PlatformInstallReferrer implements InstallReferrerSource {
  static const channel = MethodChannel('com.kabso/install_referrer');

  @override
  Future<String?> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      // MainActivity answers every call exactly once (null when the Play
      // service is unavailable), so no timer is needed.
      return await channel.invokeMethod<String>('read');
    } on Object catch (error) {
      debugPrint('Install referrer unavailable: $error');
      return null;
    }
  }
}

final installReferrerSourceProvider = Provider<InstallReferrerSource>(
  (ref) => PlatformInstallReferrer(),
);

/// The code a referrer string carries (`kabso_code=<code>`; the Play Store
/// passes the link's `referrer` parameter decoded once), or null.
String? signupCodeFromReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;
  try {
    final params = Uri.splitQueryString(referrer);
    final raw = params['kabso_code'];
    return raw == null ? null : extractSignupCode(raw);
  } on FormatException {
    return null;
  }
}

abstract final class SignupCodePrefs {
  /// Set once the install referrer was read (it is read once per install).
  static const referrerRead = 'signup.referrerRead';

  /// The code it carried, until a sign-up is sent with it.
  static const referrerCode = 'signup.referrerCode';
}

/// The code to pre-fill on the sign-up screen: the install referrer's, read
/// once per install and kept until a sign-up is sent (null: none).
final pendingSignupCodeProvider = FutureProvider<String?>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs.getBool(SignupCodePrefs.referrerRead) ?? false) {
    return prefs.getString(SignupCodePrefs.referrerCode);
  }
  final code = signupCodeFromReferrer(
    await ref.watch(installReferrerSourceProvider).read(),
  );
  await prefs.setBool(SignupCodePrefs.referrerRead, true);
  if (code != null) await prefs.setString(SignupCodePrefs.referrerCode, code);
  return code;
});

/// A sign-up was sent with the referrer's code (or the person removed it):
/// it is not offered again.
Future<void> forgetPendingSignupCode(SharedPreferences prefs) =>
    prefs.remove(SignupCodePrefs.referrerCode);
