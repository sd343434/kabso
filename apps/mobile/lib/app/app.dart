import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class KabsoApp extends ConsumerWidget {
  const new({super.key});

  static const supportedLocales = [Locale('ar'), Locale('en')];

  /// Debug builds only: `--dart-define=KABSO_EMULATE_PHONE_INSETS=true`
  /// gives a web build iPhone-class safe-area insets (47 top, 34 bottom) so
  /// captures show the room real phones leave for the status bar.
  static const bool _emulatePhoneInsets =
      !kReleaseMode && bool.fromEnvironment('KABSO_EMULATE_PHONE_INSETS');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(languageControllerProvider).locale;
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      themeMode: themeMode,
      theme: buildAppTheme(brightness: Brightness.light, locale: locale),
      darkTheme: buildAppTheme(brightness: Brightness.dark, locale: locale),
      themeAnimationDuration: KMotion.base,
      themeAnimationCurve: KMotion.standard,
      builder: (context, child) {
        // D94: a minimized live floats over every screen.
        Widget app = Stack(
          children: [
            child!,
            LiveMiniWindow(router: router),
          ],
        );
        if (_emulatePhoneInsets) {
          const insets = EdgeInsets.only(top: 47, bottom: 34);
          app = MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: insets, viewPadding: insets),
            child: app,
          );
        }
        return app;
      },
    );
  }
}
