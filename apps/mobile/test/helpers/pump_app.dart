import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared preferences with an explicit language.
Future<SharedPreferences> testPrefs({String language = 'en'}) {
  SharedPreferences.setMockInitialValues({
    PreferenceKeys.languageCode: language,
  });
  return SharedPreferences.getInstance();
}

/// Pumps the whole app (router, theme, l10n) with [overrides].
Future<void> pumpKabsoApp(
  WidgetTester tester, {
  required List<Override> overrides,
  String language = 'en',
}) async {
  final prefs = await testPrefs(language: language);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: const KabsoApp(),
    ),
  );
}

/// Pumps a single screen inside a themed, localized [MaterialApp].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  AppLanguage language = AppLanguage.en,
}) async {
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
        home: screen,
      ),
    ),
  );
}

AppLocalizations l10nFor(AppLanguage language) =>
    lookupAppLocalizations(language.locale);
