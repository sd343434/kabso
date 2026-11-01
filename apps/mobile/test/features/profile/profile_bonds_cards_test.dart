// D218 (owner: «اجعلها بهذه الطريقة بشكل مطابق ١٠٠٪», then «مستطيل بحواف
// مستديرة قليلاً»): the three bond tiles on the public and the own profile
// are equal rounded rectangles (12 dp) in the owner's sampled colours with
// the owner's medallion art at the reading start (never mirrored), 8 dp
// apart, 60 dp tall; titles never cut (also at 360×800 ×1.3 in Arabic and
// English), the same in light and dark, and a tap opens the same place.

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
  const medals = [
    'assets/profile/bonds/family_medal.webp',
    'assets/profile/bonds/couple_medal.webp',
    'assets/profile/bonds/medals_medal.webp',
  ];
  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      for (final (viewport, scale) in [
        (GoldenViewport.phone, 1.0),
        (GoldenViewport.android, 1.3),
      ]) {
        testWidgets('${language.name} ${brightness.name} '
            '${viewport.name}×$scale: three equal rounded rectangles 8 dp '
            'apart, the medallion at the reading start, titles whole, '
            '≥ 48 dp', (tester) async {
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
            expect(r.height, KBondTile.height);
            expect(r.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
            expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
          }
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
            final box = tester.getRect(find.byKey(tile));
            // The body: a 12 dp rounded rectangle in the art's colours.
            final body =
                tester
                        .widget<DecoratedBox>(
                          find.descendant(
                            of: find.byKey(tile),
                            matching: find.byKey(ProfileBondsRow.bodyKey),
                          ),
                        )
                        .decoration
                    as BoxDecoration;
            expect(body.borderRadius, BorderRadius.circular(12));
            final art = BondArt.values[i];
            expect((body.gradient! as LinearGradient).colors, [
              art.top,
              art.middle,
              art.middle,
              art.bottom,
            ]);
            // The owner's medallion, unmirrored, at the reading start.
            final medal = find.descendant(
              of: find.byKey(tile),
              matching: find.byKey(ProfileBondsRow.medalKey),
            );
            expect(
              (tester.widget<Image>(medal).image as AssetImage).assetName,
              medals[i],
            );
            expect(
              find.ancestor(of: medal, matching: find.byType(Transform)),
              findsNothing,
            );
            final m = tester.getRect(medal);
            expect(m.width, moreOrLessEquals(m.height));
            if (rtl) {
              expect(box.right - m.right, lessThan(8));
            } else {
              expect(m.left - box.left, lessThan(8));
            }
            final title = find.descendant(
              of: find.byKey(tile),
              matching: find.byKey(ProfileBondsRow.titleKey),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: title, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final shown = tester.getRect(title);
            expect(box.contains(shown.center), isTrue);
            if (rtl) {
              expect(shown.right, lessThanOrEqualTo(m.left));
            } else {
              expect(shown.left, greaterThanOrEqualTo(m.right));
            }
          }
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
