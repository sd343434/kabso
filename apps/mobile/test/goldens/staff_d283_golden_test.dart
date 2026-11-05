// D283: the Kabso Team's limited accounts and their fixed look.
//
//   staff.profile.arab      a moderator of الوطن العربي: the Arabic team
//                           cover, the team picture in the locked frame,
//                           the badge, «مشرف للوطن العربي», no levels
//   staff.profile.intl      a support member of Europe: the international
//                           cover, «دعم — أوروبا» / "Support — Europe"
//   staff.me                the staff-only Me tab (header, «فريق كابسو»,
//                           announcement composer, settings)
//   staff.create            the ➕ menu (announcements only) and the
//                           composer's announcement note
//   staff.avatars           the team picture at chat (24), list (40) and
//                           card (72) sizes, and a feed post's label
//
// 393 × 852 with the status bar 59 and the home indicator 34; a fixed
// clock. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_d283_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/posts/presentation/announcement_label.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart' show pumpOther;
import '../features/staff/staff_d283_test.dart';
import '../helpers/golden.dart';

Future<void> _pumpPlain(
  WidgetTester tester,
  AppLanguage language,
  Widget body,
) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: KabsoApp.supportedLocales,
      theme: buildAppTheme(
        brightness: Brightness.light,
        locale: language.locale,
      ),
      home: Scaffold(body: SafeArea(child: body)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;

    testWidgets('staff.profile.arab $name', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(tester, staffProfile(ar: ar), language: language);
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.profile.arab.$name.phone.png'),
      );
    });

    testWidgets('staff.profile.intl $name', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(
          tester,
          staffProfile(ar: ar, staff: europeSupport),
          language: language,
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.profile.intl.$name.phone.png'),
      );
    });

    testWidgets('staff.me $name', (tester) async {
      await pumpStaffHub(tester, language: language);
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.me.$name.phone.png'),
      );
    });

    testWidgets('staff.create $name', (tester) async {
      await _pumpPlain(
        tester,
        language,
        const Column(
          children: [
            CreateMenuSheet(staff: true),
            Divider(),
            AnnouncementComposerNote(),
          ],
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.create.$name.phone.png'),
      );
    });

    testWidgets('staff.avatars $name', (tester) async {
      await _pumpPlain(
        tester,
        language,
        Padding(
          padding: const EdgeInsets.all(KSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  KAvatar(name: 'a', imageUrl: teamAvatarUrl, size: 24),
                  SizedBox(width: KSpacing.xl),
                  KAvatar(name: 'b', imageUrl: teamAvatarUrl, size: 40),
                  SizedBox(width: KSpacing.xxl),
                  KAvatar(name: 'c', imageUrl: teamAvatarUrl, size: 72),
                ],
              ),
              const SizedBox(height: KSpacing.xxl),
              const KabsoTeamAvatar.boxed(box: 160),
              const SizedBox(height: KSpacing.xl),
              Text(ar ? 'منشور في الخلاصة:' : 'A feed post:'),
              const SizedBox(height: KSpacing.sm),
              const AnnouncementLabel(),
            ],
          ),
        ),
      );
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.avatars.$name.phone.png'),
      );
    });
  });
}
