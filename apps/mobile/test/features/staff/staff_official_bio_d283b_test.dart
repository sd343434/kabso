// D283b (owner: «اجعل بايو ملفت واجمل لانه هذه شركة بالعربي والانجليزي»):
// a Kabso Team account's bio is the company's fixed official text in the
// viewer's language, on a red-and-gold card — never the typed bio, never on
// a normal account; 360 wide at ×1.3 and ×2.0 without overflow.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show pumpOther;
import 'staff_d283_test.dart';

void main() {
  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    final ar = language == AppLanguage.ar;

    testWidgets('a staff profile shows the official bio, not the typed one '
        '(${language.name})', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(tester, staffProfile(ar: ar), language: language);
      });
      expect(tester.takeException(), isNull);
      expect(find.byKey(StaffOfficialBio.cardKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(StaffOfficialBio.textKey)).data,
        l10n.staffOfficialBio,
      );
      expect(
        tester
            .widget<Text>(find.byKey(StaffOfficialBio.titleKey))
            .textSpan!
            .toPlainText(),
        '${l10n.staffOfficialBioTitle}  ·  ${arabModerator.line(l10n)}',
      );
      expect(find.text(staffProfile(ar: ar).bio!), findsNothing);
      // The card sits under the stats and buttons.
      expect(
        tester.getRect(find.byKey(StaffOfficialBio.cardKey)).top,
        greaterThan(
          tester.getRect(find.byKey(ProfileCoverHeader.actionsKey)).bottom,
        ),
      );
    });

    testWidgets('a normal profile keeps its own bio, no official card '
        '(${language.name})', (tester) async {
      await pumpOther(tester, apiProfile(ar: ar), language: language);
      expect(find.byKey(StaffOfficialBio.cardKey), findsNothing);
      expect(find.text(l10n.staffOfficialBio), findsNothing);
      expect(find.text(apiProfile(ar: ar).bio!), findsOneWidget);
    });

    testWidgets('the staff Me tab shows the official bio '
        '(${language.name})', (tester) async {
      await pumpStaffHub(tester, language: language);
      expect(tester.takeException(), isNull);
      expect(find.byKey(StaffOfficialBio.cardKey), findsOneWidget);
      expect(find.text(l10n.staffOfficialBio), findsOneWidget);
    });
  }

  test('the copy: the brand in Latin script, no exclamation mark', () {
    final ar = l10nFor(AppLanguage.ar);
    final en = l10nFor(AppLanguage.en);
    expect(ar.staffOfficialBio, contains('Kabso Live'));
    expect(en.staffOfficialBio, contains('Kabso Live'));
    expect(ar.staffOfficialBioTitle, 'الحساب الرسمي');
    expect(en.staffOfficialBioTitle, 'Official account');
  });

  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('360 wide at ×$scale, ${brightness.name}: no overflow '
            '(${language.name})', (tester) async {
          await loadAppFonts();
          tester.view
            ..physicalSize = const Size(360, 800)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              locale: language.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: KabsoApp.supportedLocales,
              theme: buildAppTheme(
                brightness: brightness,
                locale: language.locale,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: StaffOfficialBio(
                    staff: KabsoStaffIdentity(
                      role: StaffLineRole.moderation,
                      regions: [StaffRegion.arabWorld, StaffRegion.europe],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(StaffOfficialBio.cardKey), findsOneWidget);
        });
      }
    }
  }
}
