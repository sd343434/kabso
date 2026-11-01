// D218 (owner: «العائلة / العلاقة / الميداليات ضعها في صناديق واعد تصميمها
// بشكل احترافي»): the three bond cards on the public and the own profile —
// equal cards 8 dp apart in both themes, titles never cut (also at 360×800
// ×1.3 in Arabic and English), values may be cut, whole-card targets of at
// least 48 dp, and the partner's photo instead of the generic art.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
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
  const cards = [
    ProfileBondsRow.familyKey,
    ProfileBondsRow.cpKey,
    ProfileBondsRow.medalsKey,
  ];
  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      for (final (viewport, scale) in [
        (GoldenViewport.phone, 1.0),
        (GoldenViewport.android, 1.3),
      ]) {
        testWidgets('${language.name} ${brightness.name} '
            '${viewport.name}×$scale: three equal cards 8 dp apart, titles '
            'whole, targets ≥ 48 dp', (tester) async {
          await _pump(
            tester,
            language: language,
            brightness: brightness,
            viewport: viewport,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          final rects = [for (final k in cards) tester.getRect(find.byKey(k))];
          for (final r in rects) {
            expect(r.height, greaterThanOrEqualTo(48));
            expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
          }
          final sorted = [...rects]..sort((a, b) => a.left.compareTo(b.left));
          expect(sorted[1].left - sorted[0].right, moreOrLessEquals(8));
          expect(sorted[2].left - sorted[1].right, moreOrLessEquals(8));
          for (final card in cards) {
            final title = find.descendant(
              of: find.byKey(card),
              matching: find.byKey(ProfileBondsRow.titleKey),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: title, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final box = tester.getRect(find.byKey(card));
            final shown = tester.getRect(title);
            expect(box.contains(shown.topLeft), isTrue);
            expect(shown.right, lessThanOrEqualTo(box.right + 0.5));
          }
          // A card, not bare text: rounded, bordered; light adds a shadow.
          final deco =
              tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byKey(ProfileBondsRow.familyKey),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          final palette = brightness == Brightness.dark
              ? KPalette.dark
              : KPalette.light;
          expect(deco.border, isNotNull);
          expect(
            deco.color,
            brightness == Brightness.dark
                ? palette.surfaceOverlay
                : palette.surface,
          );
          expect(
            deco.boxShadow,
            brightness == Brightness.dark ? isNull : isNotEmpty,
          );
        });
      }
    }
  }

  testWidgets("the partner's photo replaces the generic art", (tester) async {
    await _pump(
      tester,
      language: AppLanguage.en,
      brightness: Brightness.light,
      viewport: GoldenViewport.phone,
      scale: 1,
      partnerPhoto: 'https://media.example.test/media/p/640.webp',
    );
    expect(
      find.descendant(
        of: find.byKey(ProfileBondsRow.cpKey),
        matching: find.byType(KAvatar),
      ),
      findsOneWidget,
    );
    // The family has no emblem: its art in the tinted circle.
    expect(
      find.descendant(
        of: find.byKey(ProfileBondsRow.familyKey),
        matching: find.byType(KAvatar),
      ),
      findsNothing,
    );
  });
}
