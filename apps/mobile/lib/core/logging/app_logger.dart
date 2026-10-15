import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal logger. Every message passes through [redact] so that tokens,
/// passwords and authorization headers never reach the log.
abstract final class AppLogger {
  static bool enabled = kDebugMode;

  static void debug(String message) => _log(message, level: 500);

  static void info(String message) => _log(message, level: 800);

  static void warning(String message) => _log(message, level: 900);

  static void error(String message, [Object? error, StackTrace? stack]) {
    _log(
      error == null ? message : '$message: ${redact(error.toString())}',
      level: 1000,
      stack: stack,
    );
  }

  static void _log(String message, {required int level, StackTrace? stack}) {
    if (!enabled) return;
    developer.log(
      redact(message),
      name: 'kabso',
      level: level,
      stackTrace: stack,
    );
  }

  static final List<RegExp> _patterns = [
    // Authorization: Bearer <jwt>
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    // JSON / query style secrets: "refreshToken":"...", password=...
    RegExp(
      '((?:access|refresh)Token|password|newPassword|token)'
      r'''(["']?\s*[:=]\s*["']?)[^"'&,}\s]+''',
      caseSensitive: false,
    ),
    // Bare JWTs.
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
  ];

  /// Replaces secrets in [input] with `***`.
  static String redact(String input) {
    var out = input;
    out = out.replaceAllMapped(_patterns[0], (m) => '${m[1]}***');
    out = out.replaceAllMapped(_patterns[1], (m) => '${m[1]}${m[2]}***');
    out = out.replaceAll(_patterns[2], '***');
    return out;
  }
}
