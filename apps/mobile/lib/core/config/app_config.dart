import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Reads values from `--dart-define`.
  ///
  /// `API_BASE_URL` defaults to `http://10.0.2.2:3000`, which is the host
  /// machine as seen from the Android emulator. Use `http://localhost:3000`
  /// for the iOS simulator.
  factory fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000',
    );
    const version = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0',
    );
    return AppConfig(
      apiBaseUrl: _trimTrailingSlash(baseUrl),
      appVersion: version,
    );
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

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
