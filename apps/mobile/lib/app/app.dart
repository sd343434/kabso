import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

class KabsoApp extends ConsumerWidget {
  const new({super.key});

  static const supportedLocales = [Locale('ar'), Locale('en')];

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
    );
  }
}
