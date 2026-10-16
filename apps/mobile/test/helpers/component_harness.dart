import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps a single component in a themed, localized app (Ahem font, default
/// test view). Golden tests use `golden.dart` instead.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.en,
  bool disableAnimations = true,
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: language.locale,
      supportedLocales: KabsoApp.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: buildAppTheme(brightness: brightness, locale: language.locale),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}
