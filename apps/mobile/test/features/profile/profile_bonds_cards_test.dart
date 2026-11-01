// D218 (owner: «اجعلها بهذه الطريقة بشكل مطابق ١٠٠٪»): the three bond tiles
// on the public and the own profile are the owner's pill art — equal height,
// each at its own aspect, 8 dp apart, the medallion at the reading start
// (mirrored in English), titles never cut (also at 360×800 ×1.3 in Arabic
// and English), targets of at least 48 dp, the same in light and dark, and
// a tap opens the same place as before.

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

PublicProfile _profile({String? partnerPhoto}) => apiProfile().copyWith(
  family: const ProfileFamily(
    id: 'fam-1',
    number: 48213907,
    name: 'A family with a rather long name',
    level: 3,
    emblemUrl: null,
    role: FamilyRole.deputy,
  ),
  cp: ProfileCp(
    partner: UserSummary(
      id: 'u-p',
      username: 'partner',
      displayName: 'Partner with a long name',
      avatarUrl: partnerPhoto,
    ),
    since: DateTime.utc(2026, 10, 20),
    level: 2,
    levelName: 'Silver couple',
    points: 620,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  required Brightness brightness,
  required GoldenViewport viewport,
  required double scale,
  String? partnerPhoto,
}) async {
  setViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => Theme(
        data: buildAppTheme(
          brightness: brightness,
          locale: Localizations.localeOf(context),
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: ProfileBondsRow(
              profile: _profile(partnerPhoto: partnerPhoto),
            ),
          ),
        ),
      ),
    ),
    language: language,
  );
  await tester.pumpAndSettle();
}

void main() {
  const tiles = [
    ProfileBondsRow.familyKey,
    ProfileBondsRow.cpKey,
    ProfileBondsRow.medalsKey,
  ];
  const assets = [
    'assets/profile/bonds/family.webp',
    'assets/profile/bonds/couple.webp',
    'assets/profile/bonds/medals.webp',
  ];
  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      for (final (viewport, scale) in [
        (GoldenViewport.phone, 1.0),
        (GoldenViewport.android, 1.3),
      ]) {
        testWidgets('${language.name} ${brightness.name} '
            '${viewport.name}×$scale: the owner pills, equal height, 8 dp '
            'apart, own aspect, medallion at the reading start, titles '
            'whole, targets ≥ 48 dp', (tester) async {
          await _pump(
            tester,
            language: language,
            brightness: brightness,
            viewport: viewport,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          final rtl = language == AppLanguage.ar;
          final rects = [for (final k in tiles) tester.getRect(find.byKey(k))];
          for (final r in rects) {
            expect(r.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
          }
          // Reading order: family, couple, medals.
          if (rtl) {
            expect(rects[0].left, greaterThan(rects[1].right));
            expect(rects[1].left, greaterThan(rects[2].right));
          } else {
            expect(rects[0].right, lessThan(rects[1].left));
            expect(rects[1].right, lessThan(rects[2].left));
          }
          final sorted = [...rects]..sort((a, b) => a.left.compareTo(b.left));
          expect(sorted[1].left - sorted[0].right, moreOrLessEquals(8));
          expect(sorted[2].left - sorted[1].right, moreOrLessEquals(8));
          for (final (i, tile) in tiles.indexed) {
            final art = find.descendant(
              of: find.byKey(tile),
              matching: find.image(AssetImage(assets[i])),
            );
            expect(art, findsOneWidget);
            // The art keeps its aspect (no squash) and is mirrored only in
            // English.
            final image = tester.getRect(art);
            final source = switch (i) {
              0 => 662 / 290,
              1 => 642 / 289,
              _ => 653 / 289,
            };
            expect(
              image.width / image.height,
              moreOrLessEquals(source, epsilon: 0.02),
            );
            final flip = tester.widget<Transform>(
              find.ancestor(of: art, matching: find.byType(Transform)).first,
            );
            expect(flip.transform.storage[0], rtl ? 1 : -1);
            final title = find.descendant(
              of: find.byKey(tile),
              matching: find.byKey(ProfileBondsRow.titleKey),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: title, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final shown = tester.getRect(title);
            expect(image.contains(shown.center), isTrue);
            // The words sit away from the medallion (the reading start).
            if (rtl) {
              expect(shown.right, lessThan(image.right - image.height * 0.8));
            } else {
              expect(shown.left, greaterThan(image.left + image.height * 0.8));
            }
          }
          // No card behind the art (the same in light and dark).
          expect(
            find.descendant(
              of: find.byKey(ProfileBondsRow.familyKey),
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
        });
      }
    }
  }

  testWidgets('a tap opens the same places as before (the medals page)', (
    tester,
  ) async {
    setViewport(tester, GoldenViewport.phone);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: ProfileBondsRow(profile: _profile()),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.userMedalsPattern,
          builder: (_, state) =>
              Text('medals of ${state.pathParameters['username']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await testPrefs()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: AppLanguage.en.locale,
          theme: buildAppTheme(
            brightness: Brightness.light,
            locale: AppLanguage.en.locale,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: KabsoApp.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ProfileBondsRow.medalsKey));
    await tester.pumpAndSettle();
    expect(find.text('medals of host0'), findsOneWidget);
  });
}
