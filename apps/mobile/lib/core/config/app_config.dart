import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown at startup when the build-time configuration is unusable.
class AppConfigError extends Error {
  new(this.message);

  final String message;

  @override
  String toString() => 'AppConfigError: $message';
}

/// Build-time configuration supplied through `--dart-define`.
///
/// The app ships no secrets. Only public, non-sensitive values live here.
class AppConfig {
  const new({
    required this.apiBaseUrl,
    required this.appVersion,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  /// Reads values from `--dart-define` and validates them for the current
  /// build mode (see `AppConfig.resolve`).
  ///
  /// `API_BASE_URL` defaults to `http://10.0.2.2:3000`, which is the host
  /// machine as seen from the Android emulator; this default is only usable
  /// in debug/profile builds. Release builds must pass an `https://` URL.
  factory fromEnvironment({bool releaseMode = kReleaseMode}) {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    );
    const version = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0',
    );
    return AppConfig.resolve(
      apiBaseUrl: baseUrl,
      appVersion: version,
      releaseMode: releaseMode,
    );
  }

  /// Validates raw values (SEC-007).
  ///
  /// - The URL must be absolute `http`/`https` with a host, and carry no
  ///   query, fragment or credentials.
  /// - In [releaseMode] only `https` is accepted.
  ///
  /// Throws [AppConfigError] otherwise, so a misconfigured release build fails
  /// at startup instead of talking cleartext HTTP.
  factory resolve({
    required String apiBaseUrl,
    required String appVersion,
    required bool releaseMode,
  }) {
    final trimmed = _trimTrailingSlash(apiBaseUrl.trim());
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw AppConfigError(
        'API_BASE_URL "$apiBaseUrl" is not a valid http(s) origin.',
      );
    }
    if (releaseMode && uri.scheme != 'https') {
      throw AppConfigError(
        'Release builds require an https:// API_BASE_URL '
        '(got "$apiBaseUrl"). Build with '
        '--dart-define=API_BASE_URL=https://<api-host>.',
      );
    }
    return AppConfig(apiBaseUrl: trimmed, appVersion: appVersion);
  }

  /// Server origin without the version prefix, e.g. `http://10.0.2.2:3000`.
  final String apiBaseUrl;

  /// Reported in the informational `X-Client` header.
  final String appVersion;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Base URL for all versioned endpoints (`/api/v1`).
  String get apiV1BaseUrl => '$apiBaseUrl/api/v1';

  static String _trimTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

/// Overridden in `bootstrap` with the value validated at startup.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
