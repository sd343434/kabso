// D291 (owner: «ما رأيك ان نصمم صفحة التي تعرض الميداليات بحيث يمكن ان يكون
// للميدالية ايضاً ليفيلات»; v1.81-live, CONVENTIONS §10.104): the medals page
// — the stage (worn medals or the empty pedestal), the tabs, the grid's
// statuses and progress, the detail sheet with every level and wear / take
// off under the showcase rules, other people's medals with their level,
// the profile row's numeral and the level-up notification; Arabic RTL and
// English LTR, 360 × 800 at × 1.3.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/medals/presentation/medal_stage.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bonds/bonds_api_fixtures.dart';
import '../../fixtures/medals/medals_d291_fixtures.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';

final en = AppLocalizationsEn();
final ar = AppLocalizationsAr();

void main() {
  group('the stage: exactly one earned medal', () {
    Finder stageMedal(String code) => find.byKey(MedalStage.stagedKey(code));

    testWidgets('nothing earned: the dashed place, «Not worn» and the line', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291NothingEarned(ar: false);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      expect(find.byKey(MedalStage.emptyKey), findsOneWidget);
      expect(find.byKey(MedalStage.notWornKey), findsOneWidget);
      expect(find.text(en.medalsNotWorn), findsOneWidget);
      expect(find.text(en.medalsNoneWorn), findsOneWidget);
      expect(find.text(en.medalsStageTitle), findsOneWidget);
    });

    testWidgets('default: the first worn medal, alone, with its chip, name '
        'and level; the line counts the profile', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      expect(find.byKey(MedalStage.emptyKey), findsNothing);
      expect(stageMedal(d291WealthCode), findsOneWidget);
      // No number on the art (owner: «لا تضع رقم تحت الميداليات»); the
      // level is the text under the stage.
      expect(find.byKey(MedalLevelNumeral.numeralKey), findsNothing);
      expect(find.text('Wealth Kings · ${en.medalsLevel(1)}'), findsOneWidget);
      expect(find.text(en.medalsProfileWornCount(3, 5)), findsOneWidget);
    });

    testWidgets('none worn: the highest-level earned medal', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false, worn: const []);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      // BULLET_FIRST is at level 3, the highest earned.
      expect(stageMedal('BULLET_FIRST'), findsOneWidget);
      expect(find.text(en.medalsNoneWorn), findsOneWidget);
    });

    testWidgets('a tap on an earned card stages it; a locked card never; '
        'the stage medal and a long press open the sheet', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      Future<void> tapCard(String code, {bool long = false}) async {
        final card = find.byKey(MedalsScreen.medalKey(code));
        await tester.scrollUntilVisible(card, 200);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        long ? await tester.longPress(card) : await tester.tap(card);
        await tester.pumpAndSettle();
      }

      await tapCard('FIRST_CP');
      expect(find.byType(MedalDetailSheet), findsNothing);
      expect(stageMedal('FIRST_CP'), findsOneWidget);
      expect(stageMedal(d291WealthCode), findsNothing);
      // The page scrolled back to the stage.
      expect(tester.getTopLeft(stageMedal('FIRST_CP')).dy, lessThan(600));
      // The same card again opens its sheet.
      await tapCard('FIRST_CP');
      expect(find.byType(MedalDetailSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // A locked card: its sheet only, the stage unchanged.
      await tapCard('FIRST_FAMILY');
      expect(find.byType(MedalDetailSheet), findsOneWidget);
      expect(find.byKey(MedalDetailSheet.wearKey), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(stageMedal('FIRST_CP'), findsOneWidget);
      // A long press opens the sheet without staging.
      await tapCard(d291WealthCode, long: true);
      expect(find.byType(MedalDetailSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(stageMedal('FIRST_CP'), findsOneWidget);
      // The stage medal opens its sheet.
      await tester.tap(stageMedal('FIRST_CP'));
      await tester.pumpAndSettle();
      expect(find.byType(MedalDetailSheet), findsOneWidget);
      // No API: the choice is local.
      expect(
        fakes.medals.calls.where((c) => c.startsWith('setShowcase')),
        isEmpty,
      );
    });

    testWidgets('Arabic: the stage, its line and the Wealth Kings level art', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: true);
      await pumpBonds(
        tester,
        const MedalsScreen(),
        fakes: fakes,
        language: AppLanguage.ar,
      );
      expect(stageMedal(d291WealthCode), findsOneWidget);
      expect(find.text(ar.medalsStageTitle), findsOneWidget);
      expect(find.text(ar.medalsProfileWornCount(3, 5)), findsOneWidget);
      final art = tester.widget<Image>(
        find.descendant(
          of: stageMedal(d291WealthCode),
          matching: find.byType(Image),
        ),
      );
      expect(
        (art.image as AssetImage).assetName,
        'assets/medals/medal_wealth_l1.webp',
      );
    });
  });

  group("the owner's art (2026-11-06)", () {
    String assetOf(WidgetTester tester, Key key) =>
        (tester.widget<Image>(find.byKey(key).first).image as AssetImage)
            .assetName;

    for (final brightness in Brightness.values) {
      testWidgets('the ${brightness.name} theme: its background, the pedestal '
          'and the card frames', (tester) async {
        final fakes = BondFakes();
        fakes.medals.medals = d291Medals(ar: false);
        await pumpBonds(
          tester,
          const MedalsScreen(),
          fakes: fakes,
          brightness: brightness,
        );
        expect(
          assetOf(tester, MedalsScaffold.backgroundKey),
          brightness == Brightness.dark
              ? 'assets/medals/medals_bg_dark.webp'
              : 'assets/medals/medals_bg_light.webp',
        );
        expect(
          assetOf(tester, MedalStage.pedestalKey),
          brightness == Brightness.dark
              ? 'assets/medals/medals_stage_pedestal.webp'
              : 'assets/medals/medals_stage_pedestal_light.webp',
        );
        expect(
          assetOf(tester, MedalCard.frameKey),
          'assets/medals/medal_card_frame.webp',
        );
        // The staged medal stands centred on the pedestal's top disc.
        final pedestal = tester.getRect(find.byKey(MedalStage.pedestalKey));
        final medal = tester.getRect(
          find.byKey(MedalStage.stagedKey(d291WealthCode)),
        );
        expect(
          medal.bottom,
          moreOrLessEquals(
            pedestal.top + pedestal.height * MedalStage.standAt,
            epsilon: 1,
          ),
        );
        expect(medal.center.dx, moreOrLessEquals(pedestal.center.dx));
        // The title's colour: gold shader (dark) or deep gold (light).
        final title = tester.widget<Text>(find.text(en.medalsStageTitle));
        expect(
          title.style!.color,
          brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF7A4E00),
        );
      });
    }

    test('text colours keep ≥ 4.5:1 on both backgrounds', () {
      // WCAG 2 relative luminance.
      double lum(Color c) {
        double lin(double v) => v <= 0.03928
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
      }

      double ratio(Color a, Color b) {
        final (x, y) = (lum(a), lum(b));
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
      }

      Color over(Color top, Color under) => Color.alphaBlend(top, under);
      // Measured page colours of the owner's backgrounds (the stage area and
      // the grid area).
      const darkBg = [Color(0xFF280C43), Color(0xFF150425), Color(0xFF170629)];
      const lightBg = [Color(0xFFFEFEFE), Color(0xFFFAF5F9), Color(0xFFF3EAE8)];
      for (final (dark, bgs) in [(true, darkBg), (false, lightBg)]) {
        final look = MedalsLook.test(dark: dark);
        for (final bg in bgs) {
          final panel = over(look.panel, bg);
          final card = over(look.cardFill, bg);
          expect(ratio(look.text, bg), greaterThan(4.5));
          expect(ratio(look.textSecondary, panel), greaterThan(4.5));
          expect(ratio(look.text, card), greaterThan(4.5));
          expect(ratio(look.textSecondary, card), greaterThan(4.5));
          expect(
            ratio(look.textSecondary, over(look.mutedPill, card)),
            greaterThan(4.5),
          );
          if (!dark) expect(ratio(look.titleSolid, bg), greaterThan(4.5));
          expect(ratio(look.bar, card), greaterThan(3));
        }
      }
      expect(
        ratio(KStatusColors.onStatus, KBrandColors.gold),
        greaterThan(4.5),
      );
    });
  });

  group('the tabs and the grid', () {
    testWidgets('Achievements first, Activity on tap; the statuses; only '
        'wearable medals (the charm and live-hours icons are retired)', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      // Achievements: Wealth Kings, family and couple.
      expect(find.byKey(MedalsScreen.medalKey(d291WealthCode)), findsOneWidget);
      expect(find.byKey(MedalsScreen.medalKey('FIRST_LIVE')), findsNothing);
      for (final retired in [
        'CHARM_10',
        'CHARM_50',
        'CHARM_100',
        'LIVE_HOURS_10',
        'LIVE_HOURS_100',
      ]) {
        expect(find.byKey(MedalsScreen.medalKey(retired)), findsNothing);
      }
      expect(
        find.bySemanticsLabel(
          en.medalsCardLabel(
            'Wealth Kings',
            '${en.medalsLevel(1)}، ${en.medalsWorn}',
          ),
        ),
        findsOneWidget,
      );
      final locked = find.byKey(MedalsScreen.medalKey('FIRST_FAMILY'));
      await tester.scrollUntilVisible(locked, 200);
      expect(
        find.bySemanticsLabel(
          en.medalsCardLabel('First family', en.medalsNotObtained),
        ),
        findsOneWidget,
      );
      // A locked medal: its art greyed inside the owner's frame desaturated
      // (two greyscale filters), and no number on the art.
      expect(
        find.descendant(of: locked, matching: find.byType(ColorFiltered)),
        findsNWidgets(2),
      );
      expect(find.byKey(MedalLevelNumeral.numeralKey), findsNothing);
      await tester.scrollUntilVisible(find.byKey(MedalsScreen.tabsKey), -200);
      await tester.tap(find.byKey(MedalsScreen.tabKey(MedalCategory.activity)));
      await tester.pumpAndSettle();
      expect(find.byKey(MedalsScreen.medalKey(d291WealthCode)), findsNothing);
      final lives = find.byKey(MedalsScreen.medalKey('FIRST_LIVE'));
      await tester.scrollUntilVisible(lives, 200);
      // Level 2 of 1 / 10 / 50 / 100 / 500 lives at 12: 12 / 50 toward 3.
      expect(
        find.descendant(of: lives, matching: find.text(en.medalsLevel(2))),
        findsOneWidget,
      );
      expect(
        // The card's short numbers (compactLatin); the sheet shows them in
        // full.
        find.descendant(
          of: lives,
          matching: find.text(
            en.medalsProgress(
              KFormat.compactLatin(12),
              KFormat.compactLatin(50),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lives, matching: find.text(en.medalsWorn)),
        findsOneWidget,
      );
    });

    testWidgets('the top level says so instead of a bar', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      final charm = find.byKey(MedalsScreen.medalKey('FIRST_CP'));
      await tester.scrollUntilVisible(charm, 200);
      expect(
        find.descendant(of: charm, matching: find.text(en.medalsTopLevel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: charm, matching: find.byKey(MedalCard.progressKey)),
        findsNothing,
      );
    });
  });

  group('the detail sheet', () {
    Future<BondFakes> open(
      WidgetTester tester,
      String code, {
      List<String> worn = const [d291WealthCode, 'FIRST_LIVE', 'FIRST_CP'],
      MedalCategory tab = MedalCategory.activity,
      AppLanguage language = AppLanguage.en,
    }) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(
        ar: language == AppLanguage.ar,
        worn: worn,
      );
      await pumpBonds(
        tester,
        const MedalsScreen(),
        fakes: fakes,
        language: language,
      );
      if (tab == MedalCategory.activity) {
        await tester.tap(find.byKey(MedalsScreen.tabKey(tab)));
        await tester.pumpAndSettle();
      }
      final card = find.byKey(MedalsScreen.medalKey(code));
      await tester.scrollUntilVisible(card, 200);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      // A long press opens the sheet (a tap stages an earned medal).
      await tester.longPress(card);
      await tester.pumpAndSettle();
      return fakes;
    }

    testWidgets('every level with its threshold, the reached ones ticked', (
      tester,
    ) async {
      await open(tester, 'FIRST_LIVE');
      expect(find.byType(MedalDetailSheet), findsOneWidget);
      expect(find.text(en.medalsLevelsTitle), findsOneWidget);
      for (final l in [1, 2, 3]) {
        expect(find.byKey(MedalDetailSheet.levelKey(l)), findsOneWidget);
      }
      expect(find.text(en.medalsThresholdLives(10)), findsOneWidget);
      expect(find.text('10 lives'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(MedalDetailSheet.levelKey(2)),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(MedalDetailSheet.levelKey(3)),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(MedalDetailSheet),
          matching: find.text('12 / 50'),
        ),
        findsOneWidget,
      );
      expect(find.text(en.medalsTakeOff), findsOneWidget);
    });

    testWidgets('take off removes it from the showcase, in order', (
      tester,
    ) async {
      final fakes = await open(tester, 'FIRST_LIVE');
      await tester.tap(find.byKey(MedalDetailSheet.wearKey));
      await tester.pumpAndSettle();
      expect(
        fakes.medals.calls,
        contains('setShowcase:$d291WealthCode,FIRST_CP'),
      );
      expect(find.byType(MedalDetailSheet), findsNothing);
      // The page reads the catalogue again: the profile shows two.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text(en.medalsProfileWornCount(2, 5)), findsOneWidget);
    });

    testWidgets('wear adds it at the end', (tester) async {
      final fakes = await open(tester, 'BULLET_FIRST');
      expect(find.text(en.medalsWear), findsOneWidget);
      expect(find.text(en.medalsThresholdBullets(1000)), findsOneWidget);
      await tester.tap(find.byKey(MedalDetailSheet.wearKey));
      await tester.pumpAndSettle();
      expect(
        fakes.medals.calls,
        contains(
          'setShowcase:$d291WealthCode,FIRST_LIVE,FIRST_CP,BULLET_FIRST',
        ),
      );
    });

    testWidgets('a sixth medal asks to take one off first (D269: ≤ 5)', (
      tester,
    ) async {
      final fakes = BondFakes();
      final bullets = d291Medals(ar: false)
          .firstWhere((m) => m.code == 'BULLET_FIRST');
      await pumpBonds(
        tester,
        Scaffold(
          body: MedalDetailSheet(
            card: MedalCardData.fromMedal(bullets),
            wornCodes: const ['A', 'B', 'C', 'D', 'E'],
            mine: true,
          ),
        ),
        fakes: fakes,
      );
      await tester.ensureVisible(find.byKey(MedalDetailSheet.wearKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MedalDetailSheet.wearKey));
      await tester.pump();
      expect(find.text(en.medalsShowcaseLimit(5)), findsOneWidget);
      expect(
        fakes.medals.calls.where((c) => c.startsWith('setShowcase')),
        isEmpty,
      );
    });

    testWidgets('a locked medal: no wear button, progress toward level 1', (
      tester,
    ) async {
      await open(tester, 'FIRST_FAMILY', tab: MedalCategory.achievement);
      expect(find.byKey(MedalDetailSheet.wearKey), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MedalDetailSheet),
          matching: find.text('0 / 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Arabic: thresholds in Arabic plurals, the level names', (
      tester,
    ) async {
      await open(tester, 'BULLET_FIRST', language: AppLanguage.ar);
      expect(find.text(ar.medalsThresholdBullets(100)), findsOneWidget);
      expect(ar.medalsThresholdBullets(100), '100 رسالة عامة');
      expect(find.text('نجم الرسائل'), findsWidgets);
      expect(ar.medalsThresholdHours(25), '25 ساعة بث');
      expect(ar.medalsThresholdHours(3), '3 ساعات بث');
      expect(ar.medalsThresholdLives(2), 'بثّان');
    });
  });

  testWidgets("another user's medals show their levels", (tester) async {
    final fakes = BondFakes();
    fakes.medals.userList = UserMedalList.fromJson({
      'data': [
        {
          ...medalJson('BULLET_FIRST', name: 'First bullet message'),
          'category': 'ACTIVITY',
          'level': 3,
          'maxLevel': 4,
          'iconUrl': null,
        },
        // An older server: no level fields → level 1.
        medalJson('FIRST_CP', name: 'First couple'),
      ],
      'owned': 2,
      'total': 9,
    });
    await pumpBonds(tester, const MedalsScreen(username: 'sara'), fakes: fakes);
    expect(fakes.medals.calls, contains('user:sara'));
    expect(
      find.bySemanticsLabel(
        en.medalsCardLabel('First bullet message', en.medalsLevel(3)),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        en.medalsCardLabel('First couple', en.medalsLevel(1)),
      ),
      findsOneWidget,
    );
    expect(find.byKey(MedalStage.stageKey), findsNothing);
  });

  testWidgets('the profile row: no number on the art, the level in the '
      'label', (tester) async {
    await pumpBonds(
      tester,
      const Scaffold(
        body: Center(
          child: MedalShowcaseRow(
            medals: [
              ProfileMedal(
                code: 'BULLET_FIRST',
                name: 'First bullet message',
                iconKey: 'medal_bullet_first',
                level: 3,
              ),
              ProfileMedal(
                code: 'FIRST_CP',
                name: 'First couple',
                iconKey: 'medal_first_cp',
              ),
            ],
          ),
        ),
      ),
    );
    final row = find.byKey(MedalShowcaseRow.rowKey);
    expect(
      find.descendant(of: row, matching: find.byType(MedalIcon)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(MedalLevelNumeral.numeralKey),
      ),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        en.medalsRowLabel(
          'First bullet message ${en.medalsLevel(3)}، First couple '
          '${en.medalsLevel(1)}',
        ),
      ),
      findsOneWidget,
    );
  });

  test('older payloads read as level 1; level-up notifications', () {
    final old = Medal.fromJson(medalJson('FIRST_CP'));
    expect(old.currentLevel, 1);
    expect(old.levels, isEmpty);
    expect(old.category, MedalCategory.achievement);
    final unknown = Medal.fromJson({
      ...medalJson('X'),
      'category': 'SOMETHING_NEW',
    });
    expect(unknown.category, MedalCategory.achievement);
    expect(const ProfileMedal(code: 'a', name: 'a', iconKey: 'k').level, 1);

    final up = AppNotification.fromJson(const {
      'id': 'n1',
      'type': 'MEDAL_AWARDED',
      'actors': <Object?>[],
      'actorCount': 0,
      'target': {
        'type': 'MEDAL',
        'id': 'BULLET_FIRST',
        'postId': null,
        'thumbUrl': null,
        'text': null,
        'medalLevel': 3,
      },
      'createdAt': '2026-11-06T10:00:00.000Z',
      'read': false,
    });
    expect(up.target!.medalLevel, 3);
    expect(
      en.notifMedalLevelUp('First bullet message', 3),
      'Your medal First bullet message reached level 3',
    );
    expect(ar.notifMedalLevelUpUnnamed(3), 'ارتقت ميداليتك إلى المستوى 3');
    expect(NotificationRow(item: up).routeTo(), '/medals');
  });

  group('«ملوك الثروة»: the art of the current level everywhere', () {
    String artOf(WidgetTester tester, Finder within) =>
        (tester
                    .widget<Image>(
                      find.descendant(of: within, matching: find.byType(Image)),
                    )
                    .image
                as AssetImage)
            .assetName;

    testWidgets('level 5: the eagle on the stage and the card; the sheet '
        'shows all six levels with their own art, unreached ones dimmed', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals.medals = d291Medals(ar: false, wealthLevel: 5);
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      expect(
        artOf(tester, find.byKey(MedalStage.stagedKey(d291WealthCode))),
        'assets/medals/medal_wealth_l5.webp',
      );
      final card = find.byKey(MedalsScreen.medalKey(d291WealthCode));
      await tester.scrollUntilVisible(card, 200);
      expect(
        artOf(
          tester,
          find.descendant(of: card, matching: find.byType(MedalIcon)),
        ),
        'assets/medals/medal_wealth_l5.webp',
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.longPress(card);
      await tester.pumpAndSettle();
      for (var l = 1; l <= 6; l++) {
        final row = find.byKey(MedalDetailSheet.levelKey(l));
        await tester.scrollUntilVisible(
          row,
          100,
          scrollable: find
              .descendant(
                of: find.byType(MedalDetailSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(artOf(tester, row), 'assets/medals/medal_wealth_l$l.webp');
        // Level 6 (3 B) is not reached: greyed.
        expect(
          find.descendant(of: row, matching: find.byType(ColorFiltered)),
          l == 6 ? findsOneWidget : findsNothing,
          reason: 'level $l',
        );
      }
      expect(find.text(en.medalsLevel(5)), findsWidgets);
    });

    testWidgets('one category, one item: a single card and stage medal at '
        'the current level; a level-up while worn replaces it in place', (
      tester,
    ) async {
      for (final level in [1, 2]) {
        final fakes = BondFakes();
        fakes.medals.medals = d291Medals(ar: false, wealthLevel: level);
        await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
        final staged = find.byKey(MedalStage.stagedKey(d291WealthCode));
        expect(staged, findsOneWidget);
        expect(
          artOf(tester, staged),
          'assets/medals/medal_wealth_l$level.webp',
        );
        expect(
          find.text('Wealth Kings · ${en.medalsLevel(level)}'),
          findsOneWidget,
        );
        final card = find.byKey(MedalsScreen.medalKey(d291WealthCode));
        await tester.scrollUntilVisible(card, 200);
        expect(card, findsOneWidget);
        // No other card shows any of its levels' art.
        final arts = [
          for (final e in find.byType(MedalIcon).evaluate())
            (e.widget as MedalIcon).iconAsset,
        ].where((a) => a != null && a.startsWith('medal_wealth_'));
        expect(arts.toSet(), {'medal_wealth_l$level'}, reason: 'level $level');
        // Still one worn slot (the profile count is unchanged).
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
        await tester.pumpAndSettle();
        expect(find.text(en.medalsProfileWornCount(3, 5)), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('the profile row shows the current level art', (tester) async {
      await pumpBonds(
        tester,
        const Scaffold(
          body: Center(
            child: MedalShowcaseRow(
              medals: [
                ProfileMedal(
                  code: d291WealthCode,
                  name: 'Wealth Kings',
                  iconKey: 'medal_wealth_kings',
                  level: 3,
                  iconAsset: 'medal_wealth_l3',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        artOf(tester, find.byKey(MedalShowcaseRow.rowKey)),
        'assets/medals/medal_wealth_l3.webp',
      );
    });

    testWidgets('«سيد الحظ» at L4 (10 B, above 2^32): its card, its art and '
        'a sheet with the four levels', (tester) async {
      final medals = d291Medals(ar: false, luckyLevel: 4);
      final lucky = medals.firstWhere((m) => m.code == d291LuckyCode);
      // Parsed exactly (a JSON number above 2^32).
      expect(lucky.progress.value, 10000000000);
      expect(lucky.levels.last.threshold, 10000000000);
      final fakes = BondFakes();
      fakes.medals.medals = medals;
      await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
      final card = find.byKey(MedalsScreen.medalKey(d291LuckyCode));
      await tester.scrollUntilVisible(card, 200);
      expect(card, findsOneWidget);
      expect(
        artOf(
          tester,
          find.descendant(of: card, matching: find.byType(MedalIcon)),
        ),
        'assets/medals/medal_lucky_l4.webp',
      );
      expect(
        find.descendant(of: card, matching: find.text(en.medalsTopLevel)),
        findsOneWidget,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(
        find.text(en.medalsThresholdLuckyCoins('10,000,000,000')),
        findsOneWidget,
      );
      for (var l = 1; l <= 4; l++) {
        final row = find.byKey(MedalDetailSheet.levelKey(l));
        expect(artOf(tester, row), 'assets/medals/medal_lucky_l$l.webp');
        expect(
          find.descendant(of: row, matching: find.byType(ColorFiltered)),
          findsNothing,
        );
      }
    });

    test('an unknown bundled key falls back to the medal art', () {
      expect(MedalArt.asset('medal_wealth_l9'), isNull);
      expect(
        MedalArt.asset('medal_wealth_kings'),
        'assets/medals/medal_wealth_l1.webp',
      );
    });
  });

  group('360 × 800 at × 1.3 and × 2, both languages: no overflow', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('the page and the sheet at × $scale', (tester) async {
        setViewport(tester, GoldenViewport.android);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final language in AppLanguage.values) {
          for (final worn in [
            const <String>[],
            const [d291WealthCode, 'FIRST_LIVE', 'FIRST_CP', 'BULLET_FIRST'],
          ]) {
            final fakes = BondFakes();
            fakes.medals.medals = d291Medals(
              ar: language == AppLanguage.ar,
              worn: worn,
            );
            await pumpBonds(
              tester,
              const MedalsScreen(),
              fakes: fakes,
              language: language,
            );
            expect(tester.takeException(), isNull, reason: language.name);
            for (final tab in MedalCategory.values) {
              await tester.tap(find.byKey(MedalsScreen.tabKey(tab)));
              await tester.pumpAndSettle();
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -2000),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: '$language $tab');
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, 2000),
              );
              await tester.pumpAndSettle();
            }
            final card = find.byKey(MedalsScreen.medalKey('BULLET_FIRST'));
            await tester.scrollUntilVisible(card, 200);
            await tester.ensureVisible(card);
            await tester.pumpAndSettle();
            await tester.longPress(card);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'sheet $language');
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      });
    }
  });
}
