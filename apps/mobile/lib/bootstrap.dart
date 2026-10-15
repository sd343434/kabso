import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes bindings, global error handlers and async dependencies, then
/// runs [builder]'s widget inside a [ProviderScope].
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error('Flutter error', details.exception, details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Uncaught error', error, stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Failures are surfaced to the user with an explicit retry instead of
      // Riverpod's automatic background retries.
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: builder(),
    ),
  );
}
