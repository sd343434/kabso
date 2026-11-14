// CP-021 (§10.24, D112): the CP space — your couple (check-in on open,
// level from the server's ladder, claiming tasks and the 409, privileges,
// named gifts and the gift wall, confessions with a clientId retry, delete
// and report, the ranking's two periods), someone else's couple read-only
// (and 404), Arabic and English at 360×800 with text scale 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_screen.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bonds/bonds_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'bonds_harness.dart';

const _coupleId = '0192f1d0-9999-7000-8000-000000000003';
const _otherId = '0192f1d0-9999-7000-8000-000000000033';

BondFakes _paired({Map<String, Object?>? tasks}) {
  final f = BondFakes();
  f.cp
    ..couple = CpCouple.fromJson(cpCoupleJson())
    ..tasksValue = CpTasks.fromJson(tasks ?? cpTasksJson());
  return f;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);

  group('your CP space', () {
    testWidgets('checks in on open; hero, days, level from the ladder', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(
        tester,
        const CpSpaceScreen(),
        fakes: _paired(),
      );
      expect(f.cp.calls.where((c) => c == 'checkIn'), hasLength(1));
      expect(find.byKey(CpSpaceScreen.viewKey), findsOneWidget);
      expect(find.byType(CpHero), findsOneWidget);
      expect(find.text(en.cpSpaceDays(7)), findsOneWidget);
      expect(find.text(KFormat.bidiIsolate('ليلى')), findsOneWidget);
      expect(find.text(KFormat.bidiIsolate('Layla')), findsOneWidget);
      expect(find.text(en.cpSpaceLevel(2)), findsOneWidget);
      // 620 of the next tier at 1314 (620 + pointsToNext 694).
      expect(
        find.text('\u2066${en.cpSpaceProgress('620', '1,314')}'),
        findsOneWidget,
      );
      expect(
        find.text(en.cpSpaceToNext('694', KFormat.bidiIsolate('Gold couple'))),
        findsOneWidget,
      );
      // The animation is off in tests; the hearts draw nothing.
      expect(CpRisingHearts.animate, isFalse);
    });

    testWidgets('a sixth tier from the server is listed (no fixed ladder)', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final f = _paired();
      final json = cpConfigJson();
      // D113 adds a sixth tier; the page lists whatever the server sends.
      (json['tiers']! as List<Object?>)
        ..removeWhere((t) => (t! as Map)['level'] == 6)
        ..add({'level': 6, 'minPoints': 52000, 'name': 'Eternal couple'});
      f.cp.configValue = CpConfig.fromJson(json);
      await pumpBonds(tester, const CpSpaceScreen(), fakes: f);
      await tester.tap(find.text(en.cpSpaceLevel(2)));
      await tester.pumpAndSettle();
      expect(find.byKey(CpSpaceScreen.tiersKey), findsOneWidget);
      expect(find.text('Eternal couple'), findsOneWidget);
      expect(find.text(en.cpSpaceLevel(6)), findsOneWidget);
    });

    testWidgets('a done task is claimed once; the answer is shown', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(
        tester,
        const CpSpaceScreen(),
        fakes: _paired(tasks: cpTasksJson(giftClaimed: false)),
      );
      final claim = find.byKey(CpSpaceScreen.claimKey('SEND_GIFT'));
      await _show(tester, claim);
      // Not done: progress, no button.
      expect(find.byKey(CpSpaceScreen.claimKey('CHAT_TOGETHER')), findsNothing);
      expect(find.text(en.cpSpaceTaskProgress(1, 2)), findsOneWidget);
      await tester.tap(claim);
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('claim:SEND_GIFT'));
      expect(find.text(en.cpSpaceClaimedToast('20')), findsOneWidget);
      expect(claim, findsNothing);
      expect(
        find.descendant(
          of: find.byKey(CpSpaceScreen.taskKey('SEND_GIFT')),
          matching: find.text(en.cpSpaceClaimed),
        ),
        findsOneWidget,
      );
      // The couple (points) and the profile reload.
      expect(f.cp.calls.where((c) => c == 'mine').length, greaterThan(1));
    });

    testWidgets('the partner claimed it already: says nothing was added', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired(tasks: cpTasksJson(giftClaimed: false));
      fakes.cp.claimAlready = true;
      await pumpBonds(tester, const CpSpaceScreen(), fakes: fakes);
      final claim = find.byKey(CpSpaceScreen.claimKey('SEND_GIFT'));
      await _show(tester, claim);
      await tester.tap(claim);
      await tester.pumpAndSettle();
      expect(find.text(en.cpSpaceClaimedBefore), findsOneWidget);
    });

    testWidgets('409 CP_TASK_NOT_COMPLETED: said, and the tasks reload', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired(tasks: cpTasksJson(giftClaimed: false));
      final f = await pumpBonds(tester, const CpSpaceScreen(), fakes: fakes);
      f.cp.failNext['claim'] = bondFailure(ErrorCode.cpTaskNotCompleted);
      final claim = find.byKey(CpSpaceScreen.claimKey('SEND_GIFT'));
      await _show(tester, claim);
      await tester.tap(claim);
      await tester.pumpAndSettle();
      expect(find.text(en.errorCpTaskNotCompleted), findsOneWidget);
      expect(f.cp.calls.where((c) => c == 'checkIn'), hasLength(2));
    });

    testWidgets('privileges: locked ones say their level; the frame preview', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpBonds(tester, const CpSpaceScreen(), fakes: _paired());
      final frame = find.byKey(
        CpSpaceScreen.privilegeKey(CpPrivilegeCode.specialFrame),
      );
      await _show(tester, frame);
      expect(find.text(en.cpSpaceLevel(3)), findsOneWidget);
      expect(find.text(en.cpSpaceLevel(5)), findsOneWidget);
      await tester.tap(frame);
      await tester.pumpAndSettle();
      expect(find.byType(CpFramedAvatar), findsOneWidget);
      expect(find.text(en.cpSpaceUnlocked), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(CpSpaceScreen.privilegeKey(CpPrivilegeCode.giftWall)),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.cpSpaceUnlocksAt(5)), findsOneWidget);
    });

    testWidgets('a named gift is sent by its amount after confirming', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(
        tester,
        const CpSpaceScreen(),
        fakes: _paired(),
      );
      final gift = find.byKey(CpSpaceScreen.giftKey(52));
      await _show(tester, gift);
      expect(find.text('Angel Heart'), findsOneWidget);
      await tester.tap(gift);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(f.cp.calls.where((c) => c.startsWith('gift:52:')), hasLength(1));
      expect(find.text(en.cpGiftSent('52')), findsOneWidget);
    });

    testWidgets('the gift wall: totals and entries', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(
        tester,
        const CpSpaceScreen(),
        fakes: _paired(),
      );
      final wall = find.byKey(CpSpaceScreen.giftWallKey);
      await _show(tester, wall);
      await tester.tap(wall);
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('giftWall:$_coupleId'));
      expect(find.text(en.cpSpaceGiftWallTotals('2', '104')), findsOneWidget);
    });

    testWidgets('write a confession; a lost answer is retried with its id', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(
        tester,
        const CpSpaceScreen(),
        fakes: _paired(),
      );
      final field = find.byKey(CpSpaceScreen.confessionFieldKey);
      await _show(tester, field);
      expect(find.text(en.cpSpaceConfessionsEmpty), findsOneWidget);
      await tester.enterText(field, 'You make every day better');
      await tester.pump();
      f.cp.failNext['confess'] = const NetworkFailure.offline();
      await tester.tap(find.byKey(CpSpaceScreen.confessionSendKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CpSpaceScreen.confessionSendKey));
      await tester.pumpAndSettle();
      final sends = f.cp.calls.where((c) => c.startsWith('confess:')).toList();
      expect(sends, hasLength(2));
      expect(sends.first, sends.last);
      expect(find.text('You make every day better'), findsOneWidget);
      expect(find.text(en.cpSpaceConfessionSent), findsOneWidget);
    });

    testWidgets('the field keeps 200 code points and one line', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpBonds(tester, const CpSpaceScreen(), fakes: _paired());
      final field = find.byKey(CpSpaceScreen.confessionFieldKey);
      await _show(tester, field);
      await tester.enterText(field, '${'😀' * 250}\nx');
      await tester.pump();
      final text = tester.widget<TextField>(field).controller!.text;
      expect(text.runes.length, lessThanOrEqualTo(200));
      expect(text, isNot(contains('\n')));
      expect(text.runes.every((r) => r == 0x1F600), isTrue);
    });

    testWidgets("delete a confession; report the partner's", (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired();
      fakes.cp.confessions = [
        CpConfession.fromJson(cpConfessionJson(id: 'c-1')),
        CpConfession.fromJson(
          cpConfessionJson(
            id: 'c-2',
            author: cpMeJson(),
            recipient: cpPartnerJson(),
            text: 'mine',
          ),
        ),
      ];
      final f = await pumpBonds(tester, const CpSpaceScreen(), fakes: fakes);
      // Your own: delete only.
      final mineMenu = find.byKey(CpSpaceScreen.confessionMenuKey('c-2'));
      await _show(tester, mineMenu);
      await tester.tap(mineMenu);
      await tester.pumpAndSettle();
      expect(find.text(en.cpSpaceConfessionReport), findsNothing);
      await tester.tap(find.text(en.cpSpaceConfessionDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('deleteConfession:c-2'));
      expect(find.byKey(CpSpaceScreen.confessionKey('c-2')), findsNothing);
      // The partner's: report (CP_CONFESSION).
      final theirs = find.byKey(CpSpaceScreen.confessionMenuKey('c-1'));
      await _show(tester, theirs);
      await tester.tap(theirs);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.cpSpaceConfessionReport));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('reportConfession:c-1:SPAM'));
    });

    testWidgets('ranking: this week, all time, your couple; opens a couple', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired();
      fakes.cp.rankingsValue[CpRankingPeriod.week] = CpRankings.fromJson(
        cpRankingsJson(
          'WEEK',
          me: {'coupleId': _coupleId, 'rank': null, 'points': 0},
        ),
      );
      fakes.cp.rankingsValue[CpRankingPeriod.all] = CpRankings.fromJson(
        cpRankingsJson(
          'ALL',
          count: 5,
          me: {'coupleId': _coupleId, 'rank': 12, 'points': 620},
        ),
      );
      final f = await pumpBonds(tester, const CpSpaceScreen(), fakes: fakes);
      await tester.tap(find.byKey(CpSpaceScreen.actionKey('ranking')));
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('rankings:WEEK'));
      expect(find.byKey(CpSpaceScreen.rankingKey('couple-3')), findsOneWidget);
      expect(find.text(en.cpSpaceRankingMeUnranked), findsOneWidget);
      await tester.tap(find.byKey(CpSpaceScreen.rankingAllKey));
      await tester.pumpAndSettle();
      expect(f.cp.calls, contains('rankings:ALL'));
      expect(find.text(en.cpSpaceRankingMe('12')), findsOneWidget);
      await tester.tap(find.byKey(CpSpaceScreen.rankingKey('couple-1')));
      await tester.pumpAndSettle();
      expect(f.visited, ['/cp/couples/couple-1']);
    });

    testWidgets('quick actions scroll to the tasks', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpBonds(tester, const CpSpaceScreen(), fakes: _paired());
      final tasks = find.byKey(CpSpaceScreen.tasksKey);
      final before = tester.getTopLeft(tasks).dy;
      await tester.tap(find.byKey(CpSpaceScreen.actionKey('tasks')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(tasks).dy, lessThan(before));
    });

    testWidgets('no partner: says so and offers the CP page', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final f = await pumpBonds(tester, const CpSpaceScreen());
      expect(find.byKey(CpSpaceScreen.noneKey), findsOneWidget);
      expect(f.cp.calls, isNot(contains('checkIn')));
    });

    testWidgets('a failure to load says so with a retry', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired();
      fakes.cp.failNext['mine'] = const NetworkFailure.offline();
      await pumpBonds(tester, const CpSpaceScreen(), fakes: fakes);
      expect(find.text(en.cpSpaceLoadError), findsOneWidget);
    });
  });

  group("someone else's couple", () {
    testWidgets('read-only: no tasks, no writing, privileges by its level', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = BondFakes();
      fakes.cp.couples[_otherId] = CpCouplePublic.fromJson(
        cpCouplePublicJson(),
      );
      final f = await pumpBonds(
        tester,
        const CpCoupleScreen(coupleId: _otherId),
        fakes: fakes,
      );
      expect(find.byKey(CpSpaceScreen.viewKey), findsOneWidget);
      expect(find.text(KFormat.bidiIsolate('Omar')), findsOneWidget);
      expect(find.text(en.cpSpaceDays(56)), findsOneWidget);
      expect(find.byKey(CpSpaceScreen.tasksKey), findsNothing);
      expect(find.byKey(CpSpaceScreen.actionKey('tasks')), findsNothing);
      expect(f.cp.calls, isNot(contains('checkIn')));
      final gift = find.byKey(
        CpSpaceScreen.privilegeKey(CpPrivilegeCode.giftWall),
      );
      await _show(tester, gift);
      expect(find.text(en.cpSpaceLevel(4)), findsOneWidget);
      await _show(tester, find.byKey(CpSpaceScreen.confessionsKey));
      expect(find.byKey(CpSpaceScreen.confessionFieldKey), findsNothing);
      expect(f.cp.calls, contains('coupleConfessions:$_otherId'));
      expect(find.text(en.cpSpaceConfessionsEmptyPublic), findsOneWidget);
    });

    testWidgets('its gift wall before Lv.5: 403 says it is locked', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = BondFakes();
      fakes.cp
        ..couples[_otherId] = CpCouplePublic.fromJson(cpCouplePublicJson())
        ..failNext['giftWall'] = bondFailure(
          ErrorCode.cpPrivilegeLocked,
          status: 403,
        );
      await pumpBonds(
        tester,
        const CpCoupleScreen(coupleId: _otherId),
        fakes: fakes,
      );
      final wall = find.byKey(CpSpaceScreen.giftWallKey);
      await _show(tester, wall);
      await tester.tap(wall);
      await tester.pumpAndSettle();
      expect(find.text(en.cpSpaceGiftWallLocked(5)), findsOneWidget);
    });

    testWidgets('404: the couple is not available', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpBonds(tester, const CpCoupleScreen(coupleId: 'gone'));
      expect(find.byKey(CpSpaceScreen.goneKey), findsOneWidget);
      expect(find.text(en.cpSpaceGoneTitle), findsOneWidget);
    });

    testWidgets('your own couple by id opens the full space', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final fakes = _paired();
      fakes.cp.couples[_coupleId] = CpCouplePublic.fromJson(
        cpCouplePublicJson(id: _coupleId, mine: true),
      );
      final f = await pumpBonds(
        tester,
        const CpCoupleScreen(coupleId: _coupleId),
        fakes: fakes,
      );
      expect(f.cp.calls, contains('checkIn'));
      expect(find.byKey(CpSpaceScreen.tasksKey), findsOneWidget);
    });
  });

  group('Arabic and English at 360×800, text scale 2', () {
    for (final (name, screen, setUp) in <(String, Widget, BondFakes)>[
      ('your space', const CpSpaceScreen(), _paired()),
      (
        "someone's couple",
        const CpCoupleScreen(coupleId: _otherId),
        BondFakes()
          ..cp.couples[_otherId] = CpCouplePublic.fromJson(
            cpCouplePublicJson(),
          ),
      ),
    ]) {
      testWidgets(name, (tester) async {
        setViewport(tester, GoldenViewport.android);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final language in AppLanguage.values) {
          final fakes = BondFakes();
          fakes.cp
            ..couple = setUp.cp.couple
            ..couples.addAll(setUp.cp.couples)
            ..confessions = [
              CpConfession.fromJson(
                cpConfessionJson(
                  text:
                      'A long confession that wraps over a few lines '
                      'to check nothing overflows at a large text size',
                ),
              ),
            ];
          await pumpBonds(tester, screen, language: language, fakes: fakes);
          expect(tester.takeException(), isNull, reason: language.name);
          expect(
            Directionality.of(tester.element(find.byType(CpHero))),
            language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
          );
          // Scroll to the end: every section lays out without overflow.
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -6000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: language.name);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  });
}
