// D300 (owner 2026-11-07; v1.83-live, CONVENTIONS §10.111): «مدرسة المحتوى»
// / Content School — a level needs a content creator's followers, likes and
// views together: the card's bar is the lowest of the three, the sheet shows
// three bars and every level's three thresholds, a non-creator sees «لصنّاع
// المحتوى فقط»; and «لاعب الأحكام» / Dares Player (PK points). The current
// level's art everywhere; Arabic RTL and English LTR; 360 × 800 at × 1.3 / 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/medals/presentation/medal_stage.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/medals/medals_d300_fixtures.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';

final en = AppLocalizationsEn();
final ar = AppLocalizationsAr();

String artOf(WidgetTester tester, Finder within) =>
    (tester
                .widget<Image>(
                  find.descendant(of: within, matching: find.byType(Image)),
                )
                .image
            as AssetImage)
        .assetName;

Future<void> pumpMedals(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  int schoolLevel = 2,
  bool creator = true,
  int daresLevel = 3,
  List<String> worn = const [d300SchoolCode],
}) async {
  final fakes = BondFakes();
  fakes.medals.medals = d300Medals(
    ar: language == AppLanguage.ar,
    schoolLevel: schoolLevel,
    creator: creator,
    daresLevel: daresLevel,
    worn: worn,
  );
  await pumpBonds(
    tester,
    const MedalsScreen(),
    fakes: fakes,
    language: language,
  );
}

Future<void> openSheet(
  WidgetTester tester,
  String code, {
  MedalCategory tab = MedalCategory.achievement,
}) async {
  if (tab != MedalCategory.achievement) {
    await tester.tap(find.byKey(MedalsScreen.tabKey(tab)));
    await tester.pumpAndSettle();
  }
  final card = find.byKey(MedalsScreen.medalKey(code));
  await tester.scrollUntilVisible(card, 200);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.longPress(card);
  await tester.pumpAndSettle();
}

Finder inSheet(Finder f) =>
    find.descendant(of: find.byType(MedalDetailSheet), matching: f);

void main() {
  group('the wire', () {
    test('requirements and eligible parse; older payloads read as none / '
        'eligible', () {
      final m = d300Medals(ar: false).first;
      expect(m.code, d300SchoolCode);
      expect(m.eligible, isTrue);
      expect(m.levels.first.requirements.map((r) => r.threshold), [
        2000,
        10000,
        20000,
      ]);
      expect(m.progress.requirements.map((r) => (r.metric, r.value, r.next)), [
        ('CREATOR_FOLLOWERS', 48000, 100000),
        ('CREATOR_LIKES', 190000, 200000),
        ('CREATOR_VIEWS', 230000, 500000),
      ]);
      final old = Medal.fromJson({
        'code': 'X',
        'name': 'X',
        'description': '',
        'iconKey': 'x',
        'sortOrder': 1,
        'awardedAt': null,
        'levels': [
          {'level': 1, 'threshold': 5},
        ],
        'progress': {'value': 1, 'next': 5},
      });
      expect(old.eligible, isTrue);
      expect(old.levels.single.requirements, isEmpty);
      expect(old.progress.requirements, isEmpty);
    });

    test('the card data: the weakest requirement is the lowest ratio; none '
        'at the top', () {
      final at2 = MedalCardData.fromMedal(d300Medals(ar: false).first);
      expect(at2.multiRequirement, isTrue);
      // Followers 0.48, likes 0.95, views 0.46: views are the furthest.
      expect(at2.weakestRequirement!.metric, 'CREATOR_VIEWS');
      final top = MedalCardData.fromMedal(
        d300Medals(ar: false, schoolLevel: 4).first,
      );
      expect(top.weakestRequirement, isNull);
      final dares = MedalCardData.fromMedal(d300Medals(ar: false)[1]);
      expect(dares.multiRequirement, isFalse);
    });
  });

  group('«مدرسة المحتوى»', () {
    testWidgets('the card: level 2 art, the lowest-of-three bar (views '
        '230K / 500K)', (tester) async {
      await pumpMedals(tester);
      final card = find.byKey(MedalsScreen.medalKey(d300SchoolCode));
      await tester.scrollUntilVisible(card, 200);
      expect(
        artOf(
          tester,
          find.descendant(of: card, matching: find.byType(MedalIcon)),
        ),
        'assets/medals/medal_content_school_l2.webp',
      );
      expect(
        find.descendant(of: card, matching: find.byKey(MedalCard.progressKey)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('\u2066230K\u2069 / \u2066500K\u2069'),
        ),
        findsOneWidget,
      );
      // Worn first: on the stage with level 2's art, no number on it.
      expect(
        artOf(tester, find.byKey(MedalStage.stagedKey(d300SchoolCode))),
        'assets/medals/medal_content_school_l2.webp',
      );
      expect(find.byKey(MedalLevelNumeral.numeralKey), findsNothing);
    });

    testWidgets('the sheet: three bars toward level 3 and four levels with '
        'their three thresholds and art', (tester) async {
      await pumpMedals(tester);
      await openSheet(tester, d300SchoolCode);
      expect(inSheet(find.text(en.medalsReqAllTogether)), findsOneWidget);
      for (final (metric, name, text) in [
        ('CREATOR_FOLLOWERS', en.medalsReqFollowers, '48,000 / 100,000'),
        ('CREATOR_LIKES', en.medalsReqLikes, '190,000 / 200,000'),
        ('CREATOR_VIEWS', en.medalsReqViews, '230,000 / 500,000'),
      ]) {
        final row = find.byKey(MedalDetailSheet.requirementKey(metric));
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(text)),
          findsOneWidget,
        );
      }
      final scrollable = inSheet(find.byType(Scrollable)).first;
      for (var l = 1; l <= 4; l++) {
        final row = find.byKey(MedalDetailSheet.levelKey(l));
        await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
        expect(
          artOf(tester, row),
          'assets/medals/medal_content_school_l$l.webp',
        );
        final t = d300SchoolThresholds[l - 1];
        String g(int n) => n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(
              'Followers\u00A0${g(t[0])} · '
              'Likes\u00A0${g(t[1])} · '
              'Views\u00A0${g(t[2])}',
            ),
          ),
          findsOneWidget,
          reason: 'level $l',
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.check_circle_rounded),
          ),
          l <= 2 ? findsOneWidget : findsNothing,
        );
      }
      expect(find.text(en.medalsTakeOff), findsOneWidget);
    });

    testWidgets('Arabic: the requirement names and thresholds', (tester) async {
      await pumpMedals(tester, language: AppLanguage.ar);
      await openSheet(tester, d300SchoolCode);
      expect(inSheet(find.text(ar.medalsReqAllTogether)), findsOneWidget);
      expect(inSheet(find.text(ar.medalsReqFollowers)), findsOneWidget);
      expect(inSheet(find.text(ar.medalsReqLikes)), findsOneWidget);
      expect(inSheet(find.text(ar.medalsReqViews)), findsOneWidget);
      expect(
        inSheet(
          find.text(
            'المتابعون\u00A02,000 · '
            'الإعجابات\u00A010,000 · '
            'المشاهدات\u00A020,000',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('level 4: its art; the top level instead of bars', (
      tester,
    ) async {
      await pumpMedals(tester, schoolLevel: 4);
      expect(
        artOf(tester, find.byKey(MedalStage.stagedKey(d300SchoolCode))),
        'assets/medals/medal_content_school_l4.webp',
      );
      final card = find.byKey(MedalsScreen.medalKey(d300SchoolCode));
      await tester.scrollUntilVisible(card, 200);
      expect(
        find.descendant(of: card, matching: find.text(en.medalsTopLevel)),
        findsOneWidget,
      );
      await openSheet(tester, d300SchoolCode);
      expect(inSheet(find.text(en.medalsReqAllTogether)), findsNothing);
      expect(
        find.byKey(MedalDetailSheet.requirementKey('CREATOR_FOLLOWERS')),
        findsNothing,
      );
    });

    testWidgets('a non-creator: «Content creators only» on the card and in '
        'the sheet, no bars, no wear', (tester) async {
      await pumpMedals(tester, schoolLevel: 0, creator: false, worn: const []);
      final card = find.byKey(MedalsScreen.medalKey(d300SchoolCode));
      await tester.scrollUntilVisible(card, 200);
      expect(
        find.descendant(of: card, matching: find.text(en.medalsCreatorsOnly)),
        findsOneWidget,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      // A locked card opens its sheet on a tap.
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(MedalDetailSheet.creatorsOnlyKey), findsOneWidget);
      expect(inSheet(find.text(en.medalsCreatorsOnlyBody)), findsOneWidget);
      expect(
        find.byKey(MedalDetailSheet.requirementKey('CREATOR_LIKES')),
        findsNothing,
      );
      expect(find.byKey(MedalDetailSheet.wearKey), findsNothing);
    });

    testWidgets('a former creator keeps level 1 (art, level) without '
        'progress', (tester) async {
      await pumpMedals(tester, schoolLevel: 1, creator: false);
      expect(
        artOf(tester, find.byKey(MedalStage.stagedKey(d300SchoolCode))),
        'assets/medals/medal_content_school_l1.webp',
      );
      final card = find.byKey(MedalsScreen.medalKey(d300SchoolCode));
      await tester.scrollUntilVisible(card, 200);
      expect(
        find.descendant(of: card, matching: find.text(en.medalsLevel(1))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(en.medalsCreatorsOnly)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byKey(MedalCard.progressKey)),
        findsNothing,
      );
    });
  });

  group('«لاعب الأحكام»', () {
    testWidgets('level 3: its art and «12,400 / 20,000» PK points; four '
        'levels with their art and thresholds', (tester) async {
      await pumpMedals(tester);
      await openSheet(tester, d300DaresCode);
      expect(inSheet(find.text('12,400 / 20,000')), findsOneWidget);
      expect(inSheet(find.text(en.medalsReqAllTogether)), findsNothing);
      final scrollable = inSheet(find.byType(Scrollable)).first;
      for (final (l, t) in [
        (1, '1,500'),
        (2, '3,000'),
        (3, '5,000'),
        (4, '20,000'),
      ]) {
        final row = find.byKey(MedalDetailSheet.levelKey(l));
        await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
        expect(artOf(tester, row), 'assets/medals/medal_dares_player_l$l.webp');
        expect(
          find.descendant(
            of: row,
            matching: find.text(en.medalsThresholdPkPoints(t)),
          ),
          findsOneWidget,
        );
      }
      expect(en.medalsThresholdPkPoints('1,500'), '1,500 PK points');
      expect(ar.medalsThresholdPkPoints('1,500'), '1,500 نقطة PK');
    });
  });

  testWidgets('both D300 medals sit with the other medals in «الإنجازات» '
      '(owner: «هذه ميداليات»); none in «النشاط»', (tester) async {
    await pumpMedals(tester);
    for (final code in [d300SchoolCode, d300DaresCode, 'WEALTH_KINGS']) {
      await tester.scrollUntilVisible(
        find.byKey(MedalsScreen.medalKey(code)),
        200,
      );
      expect(find.byKey(MedalsScreen.medalKey(code)), findsOneWidget);
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MedalsScreen.tabKey(MedalCategory.activity)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    // The Activity tab is showing (its own medal is there).
    expect(find.byKey(MedalsScreen.medalKey('FIRST_LIVE')), findsOneWidget);
    expect(find.byKey(MedalsScreen.medalKey(d300DaresCode)), findsNothing);
    expect(find.byKey(MedalsScreen.medalKey(d300SchoolCode)), findsNothing);
  });

  group('360 × 800 at × 1.3 and × 2, both languages: no overflow', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('the page and both sheets at × $scale', (tester) async {
        setViewport(tester, GoldenViewport.android);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final language in AppLanguage.values) {
          await pumpMedals(tester, language: language);
          expect(tester.takeException(), isNull);
          await openSheet(tester, d300SchoolCode);
          expect(tester.takeException(), isNull, reason: 'school $language');
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpMedals(tester, language: language);
          await openSheet(tester, d300DaresCode);
          expect(tester.takeException(), isNull, reason: 'dares $language');
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  });
}
