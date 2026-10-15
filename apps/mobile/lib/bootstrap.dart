import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/storage/fresh_install.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes bindings, global error handlers and async dependencies, then
/// runs [builder]'s widget inside a [ProviderScope].
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast (SEC-007): validated before the global error handlers are
  // installed, so an AppConfigError (e.g. a release build with a non-https
  // API_BASE_URL) surfaces as an uncaught startup error instead of being
  // swallowed, and the app never talks to a misconfigured backend.
  final config = AppConfig.fromEnvironment();

  FlutterError.onError = (details) {
    AppLogger.error('Flutter error', details.exception, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Uncaught error', error, stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  // SEC-019: drop Keychain tokens that survived an uninstall (iOS).
  await clearSecureStorageOnFreshInstall(
    prefs: prefs,
    store: FlutterSecureTokenStore(),
  );

  runApp(
    ProviderScope(
      // Failures are surfaced to the user with an explicit retry instead of
      // Riverpod's automatic background retries.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: builder(),
    ),
  );
}
