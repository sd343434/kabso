// D199 (v1.44-live): the PK sheet in the owner's layout (refs 276 / 277),
// the PK Setting page, the PK history, the connected (auto-start off) and
// best-of-three stage, and the booster's activation per tier with its
// chip, bar glow and «+N ×5».
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_pages.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLivePkRepository> _sheet(
  WidgetTester tester, {
  List<PkCandidate>? friends,
  AppLanguage language = AppLanguage.ar,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final repo = FakeLivePkRepository(
    list: [
      PkCandidate(
        roomId: 'room-b',
        title: 'سهرة',
        viewerCount: 120,
        host: pkUser('host-b', 'كريم'),
      ),
      PkCandidate(
        roomId: 'room-c',
        title: 'غناء',
        viewerCount: 80,
        host: pkUser('host-c', 'ليلى'),
      ),
    ],
  )..friendList = friends;
  await pumpScreen(
    tester,
    const Scaffold(body: LivePkSheet(roomId: 'room-0')),
    language: language,
    livePkRepository: repo,
    overrides: [currentUserProvider.overrideWithValue(testUser())],
  );
  await tester.pumpAndSettle();
  return repo;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(LivePkSheet)));

void main() {
  group('PK sheet (refs 276 / 277)', () {
    // D391 (v1.118-live): «PK رباعي» (the former «PK الفرق» card) opens the
    // 4-way lobby — D393: in place, as a segment of this sheet. D393 (owner
    // «ازل المتعدد»): «PK متعدد» («قريباً») is gone; two cards.
    testWidgets('1v1 is selected and works; 4-way switches to its lobby in '
        'place; no Multi card', (tester) async {
      final repo = await _sheet(tester);
      final l10n = _l10n(tester);
      final one = tester.widget<PkModeCard>(
        find.byKey(LivePkSheet.modeKey(PkSheetMode.oneVsOne)),
      );
      expect(one.selected, isTrue);
      final four = tester.widget<PkModeCard>(
        find.byKey(LivePkSheet.modeKey(PkSheetMode.team)),
      );
      expect(four.selected, isFalse);
      expect(find.byType(PkModeCard), findsNWidgets(2));
      expect(find.text(l10n.pkModeMulti), findsNothing);
      expect(find.text(l10n.liveSoon), findsNothing);
      await tester.tap(find.byKey(LivePkSheet.modeKey(PkSheetMode.team)));
      await tester.pumpAndSettle();
      // D393: the 4-way panel inside this same sheet, «PK رباعي» selected.
      expect(
        find.descendant(
          of: find.byType(LivePkSheet),
          matching: find.byType(LivePk4Panel),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PkModeCard>(
              find.byKey(LivePkSheet.modeKey(PkSheetMode.team)),
            )
            .selected,
        isTrue,
      );
      // Still 1v1 for this sheet: nothing was asked of its server.
      expect(
        repo.calls.where((c) => c.startsWith('invite') || c == 'random'),
        isEmpty,
      );
    });

    // D393 (owner «ازل المتعدد»): the two cards share the row equally, on the
    // sheet's margins, «PK ثنائي» on the reading start (right in Arabic).
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('two mode cards share the width (${language.name})', (
        tester,
      ) async {
        await _sheet(tester, language: language);
        final sheet = tester.getRect(find.byKey(LivePkSheet.sheetKey));
        final one = tester.getRect(
          find.byKey(LivePkSheet.modeKey(PkSheetMode.oneVsOne)),
        );
        final four = tester.getRect(
          find.byKey(LivePkSheet.modeKey(PkSheetMode.team)),
        );
        expect(one.width, moreOrLessEquals(four.width, epsilon: 0.01));
        expect(one.top, four.top);
        // ar: 1v1 on the right; en: 1v1 on the left.
        final left = language == AppLanguage.ar ? four : one;
        final right = language == AppLanguage.ar ? one : four;
        expect(
          left.left - sheet.left,
          moreOrLessEquals(PkSheetMetrics.cardSide, epsilon: 0.01),
        );
        expect(
          sheet.right - right.right,
          moreOrLessEquals(PkSheetMetrics.cardSide, epsilon: 0.01),
        );
        expect(
          right.left - left.right,
          moreOrLessEquals(PkSheetMetrics.cardGap, epsilon: 0.01),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Friends: mutual follows live now, invite one', (tester) async {
      final repo = await _sheet(
        tester,
        friends: [
          PkCandidate(
            roomId: 'room-f',
            title: 'صديق',
            viewerCount: 9,
            host: pkUser('host-f', 'هند'),
          ),
        ],
      );
      expect(repo.calls, contains('candidates:friends:'));
      expect(find.byKey(LivePkSheet.candidateKey('room-f')), findsOneWidget);
      expect(find.byKey(LivePkSheet.candidateKey('room-b')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(LivePkSheet.candidateKey('room-f')),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LivePkSheet.cancelInviteKey), findsOneWidget);
    });

    testWidgets('no friends: Kabi and «لا يوجد أصدقاء لدعوتهم حالياً»; a '
        'search reaches any live host', (tester) async {
      final repo = await _sheet(tester, friends: const []);
      final l10n = _l10n(tester);
      expect(find.byKey(LivePkSheet.emptyKey), findsOneWidget);
      expect(find.text(l10n.pkNoFriends), findsOneWidget);
      final kabi = tester.widget<KabiEmoji>(find.byType(KabiEmoji));
      expect(kabi.emoji.asset, contains('kabi'));
      await tester.enterText(find.byKey(LivePkSheet.searchKey), 'ليلى');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('candidates:ليلى'));
      expect(find.byKey(LivePkSheet.candidateKey('room-c')), findsOneWidget);
    });

    testWidgets('random match (D195) from the sheet: waiting, then stop', (
      tester,
    ) async {
      final repo = await _sheet(tester);
      await tester.tap(find.byKey(LivePkSheet.randomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('random'));
      await tester.tap(find.byKey(LivePkSheet.stopRandomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('leaveRandom'));
    });

    testWidgets('the clock opens the PK history', (tester) async {
      final repo = await _sheet(tester);
      repo.pkHistory = PkHistory(
        record: const PkRecord(wins: 3, losses: 1),
        recent: [
          PkHistoryItem(
            id: 'm1',
            result: 'WIN',
            score: 11000,
            opponentScore: 6000,
            opponent: pkUser('host-b', 'كريم'),
            startedAt: DateTime(2026, 10, 30),
            bestOfThree: true,
            roundsWon: 2,
            opponentRoundsWon: 1,
          ),
          PkHistoryItem(
            id: 'm2',
            result: 'LOSS',
            score: 100,
            opponentScore: 900,
            opponent: pkUser('host-c', 'ليلى'),
            startedAt: DateTime(2026, 10, 29),
            effective: false,
          ),
        ],
      );
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(LivePkSheet.historyKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('history:${testUser().username}'));
      expect(find.byType(PkHistoryPage), findsOneWidget);
      expect(find.text(l10n.pkRecord('3', '1', '0')), findsOneWidget);
      expect(
        find.textContaining(l10n.pkHistoryRounds('2', '1')),
        findsOneWidget,
      );
      expect(find.textContaining(l10n.pkHistoryNotCounted), findsOneWidget);
      await tester.tap(find.byKey(PkHistoryPage.backKey));
      await tester.pumpAndSettle();
      expect(find.byType(PkHistoryPage), findsNothing);
    });
  });

  group('PK Setting', () {
    Future<(FakeLivePkRepository, AppLocalizations)> open(
      WidgetTester tester,
    ) async {
      final repo = await _sheet(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(LivePkSheet.settingsKey));
      await tester.pumpAndSettle();
      expect(find.byType(PkSettingsPage), findsOneWidget);
      return (repo, l10n);
    }

    testWidgets('every 1v1 row saves on the server', (tester) async {
      final (repo, l10n) = await open(tester);
      await tester.tap(find.byKey(PkSettingsPage.bestOfThreeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.timeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.optionKey('10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.autoStartKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.genderKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.optionKey('FEMALE')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.regionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.optionKey('SAME_COUNTRY')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(PkSettingsPage.invitesKey),
        100,
        scrollable: find.descendant(
          of: find.byType(PkSettingsPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(PkSettingsPage.autoMatchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.recommendKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PkSettingsPage.invitesKey));
      await tester.pumpAndSettle();
      expect(repo.saved, [
        {'mode': 'BEST_OF_THREE'},
        {'roundMinutes': 10},
        {'autoStart': false},
        {'randomGender': 'FEMALE'},
        {'randomRegion': 'SAME_COUNTRY'},
        {'autoMatch': true},
        {'recommendable': false},
        {'invitesEnabled': false},
      ]);
      expect(find.text(l10n.pkMinutes('10')), findsOneWidget);
      expect(
        find.textContaining(l10n.pkSettingsNoteEffective('3,000')),
        findsOneWidget,
      );
      expect(find.text(l10n.pkSettingsNoteRandom), findsOneWidget);
    });

    testWidgets('Multi PK and Team PK tabs are «قريباً» and store nothing', (
      tester,
    ) async {
      final (repo, l10n) = await open(tester);
      for (final i in [1, 2]) {
        await tester.tap(find.byKey(PkSettingsPage.tabKey(i)));
        await tester.pump();
        expect(find.text(l10n.pkSettingsSoonTab), findsWidgets);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      expect(repo.saved, isEmpty);
      // Still the 1v1 rows.
      expect(find.byKey(PkSettingsPage.timeKey), findsOneWidget);
    });
  });

  group('stage (D199)', () {
    Future<void> stage(
      WidgetTester tester,
      PkMatch match, {
      VoidCallback? onStart,
      PkAnnouncement? announcement,
      String roomId = 'room-0',
      bool reduceMotion = false,
    }) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: SingleChildScrollView(
              child: LivePkStage(
                match: match,
                roomId: roomId,
                ownVideo: null,
                opponentVideo: null,
                now: DateTime.now,
                onStart: onStart,
                announcement: announcement,
              ),
            ),
          ),
        ),
        language: AppLanguage.ar,
      );
      await tester.pump();
    }

    testWidgets('connected: no timer, no result; the host starts it', (
      tester,
    ) async {
      var started = 0;
      final now = DateTime.now();
      final base = pkMatchFixture(now: now);
      final connected = PkMatch(
        id: base.id,
        status: PkMatchStatus.connected,
        startedAt: now,
        battleEndsAt: now.add(const Duration(minutes: 5)),
        sides: base.sides,
        seq: 1,
        serverTime: now,
        boosters: base.boosters,
      );
      await stage(tester, connected, onStart: () => started++);
      expect(find.byKey(LivePkStage.connectedKey), findsOneWidget);
      expect(find.byKey(LivePkStage.timerKey), findsNothing);
      expect(find.byKey(LivePkStage.resultKey), findsNothing);
      await tester.tap(find.byKey(LivePkStage.startKey));
      expect(started, 1);
      // A viewer only reads that it starts soon.
      await stage(tester, connected);
      expect(find.byKey(LivePkStage.startKey), findsNothing);
    });

    testWidgets('best of three: the timer says the round', (tester) async {
      await stage(
        tester,
        pkMatchFixture(
          now: DateTime.now(),
          bestOfThree: true,
          round: 2,
          ownRounds: 1,
        ),
      );
      expect(find.textContaining('الجولة 2/3'), findsOneWidget);
    });

    Set<String> assets(WidgetTester tester, Finder within) => {
      for (final i in tester.widgetList<Image>(
        find.descendant(of: within, matching: find.byType(Image)),
      ))
        if (i.image case final AssetImage a) a.assetName,
    };

    const mult = {
      PkBoosterKind.double: 2,
      PkBoosterKind.doubleTurbo: 3,
      PkBoosterKind.triple: 5,
      PkBoosterKind.tripleTurbo: 10,
    };

    /// D231b: one half's width and centre on the 393 lp stage (ar: the own
    /// side on the right).
    const half = (393 - KLivePk.seam) / 2;
    double centreOf(PkPowerSide side) =>
        side == PkPowerSide.left ? half / 2 : half + KLivePk.seam + half / 2;
    bool isFrame(String a) => a.contains('/parts/frame');

    testWidgets("no booster: the owner's bar, edge to edge, without end "
        'frames (D231b)', (tester) async {
      await stage(tester, pkMatchFixture(now: DateTime.now()));
      final bar = find.byKey(LivePkStage.barKey);
      expect(assets(tester, bar).where(isFrame), isEmpty);
      final box = tester.getRect(bar);
      expect(box.left, closeTo(0, 0.5));
      expect(box.right, closeTo(393, 0.5));
      expect(find.byKey(LivePkStage.bannersKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LivePkStage.bannersKey),
          matching: find.byType(PkPowerBanner),
        ),
        findsNothing,
      );
    });

    for (final kind in PkBoosterKind.values) {
      final t = pkPowerTier(kind).index + 1;
      testWidgets('${kind.name}: tier t$t emblem, no end frame; the '
          "owner's banner over the boosted side's own half, both rooms", (
        tester,
      ) async {
        final now = DateTime.now();
        for (final room in ['room-0', 'room-b']) {
          await tester.pumpWidget(const SizedBox.shrink());
          await stage(
            tester,
            pkMatchFixture(now: now, ownBoost: kind),
            roomId: room,
            announcement: PkAnnouncement(
              roomId: 'room-0',
              teamName: 'سارة',
              kind: kind,
              multiplier: mult[kind]!,
              serial: 1,
            ),
          );
          final bar = find.byKey(LivePkStage.barKey);
          final art = assets(tester, bar);
          expect(art.where(isFrame), isEmpty);
          expect(art, contains('assets/pk/score_bar/parts/emblem_t$t.png'));
          final banner = find.byType(PkPowerBanner);
          expect(banner, findsOneWidget, reason: room);
          final rect = tester.getRect(banner);
          // room-0 boosted: in Arabic its half is the right one in its own
          // room, the left one in the opponent's (their own is on the right).
          final side = room == 'room-0' ? PkPowerSide.right : PkPowerSide.left;
          expect(rect.center.dx, closeTo(centreOf(side), 1), reason: room);
          expect(rect.width, closeTo(half * PkStageBanner.halfFactor, 1));
          expect(rect.width, lessThanOrEqualTo(half));
          expect(
            find.descendant(of: banner, matching: find.text('x${mult[kind]}')),
            findsWidgets,
          );
          expect(
            assets(tester, banner),
            contains(PkPowerTheme.of(pkPowerTier(kind)).asset),
          );
          final line = tester.widget<Text>(find.byKey(PkBoostText.lineKey));
          expect(line.data, startsWith('فعّل فريق'));
          expect(line.style?.fontFamily, PkBoostText.family);
          // Screen readers hear the running booster.
          expect(
            find.byKey(LivePkStage.boostChipKey('room-0')),
            findsOneWidget,
          );
        }
      });
    }

    testWidgets('own side on the right in Arabic: its tier on the right of '
        'the bar, the banner over the right half', (tester) async {
      await stage(
        tester,
        pkMatchFixture(now: DateTime.now(), ownBoost: PkBoosterKind.triple),
      );
      final layer = tester.widget<PkPowerLayer>(
        find.byKey(LivePkStage.bannersKey),
      );
      expect(layer.right?.tier, PkPowerTier.triple);
      expect(layer.left, isNull);
      final bar = tester.widget<PkBattleBar>(find.byType(PkBattleBar));
      expect((bar.leftTier, bar.rightTier), (null, PkPowerTier.triple));
      expect(bar.rightScore, 12500);
    });

    testWidgets('both teams boosted: two banners side by side, each over '
        'its own half, never stacked (D231b)', (tester) async {
      await stage(
        tester,
        pkMatchFixture(
          now: DateTime.now(),
          ownBoost: PkBoosterKind.double,
          otherBoost: PkBoosterKind.tripleTurbo,
        ),
      );
      final banners = find.byType(PkPowerBanner);
      expect(banners, findsNWidgets(2));
      final rects = [
        for (final e in banners.evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ]..sort((x, y) => x.left.compareTo(y.left));
      final (a, b) = (rects.first, rects.last);
      expect(a.center.dx, closeTo(centreOf(PkPowerSide.left), 1));
      expect(b.center.dx, closeTo(centreOf(PkPowerSide.right), 1));
      expect(a.top, closeTo(b.top, 0.5));
      expect(a.right, lessThanOrEqualTo(half + 0.5));
      expect(b.left, greaterThanOrEqualTo(half + KLivePk.seam - 0.5));
      // Ar: the own side (double) on the right, the opponent's on the left.
      final layer = tester.widget<PkPowerLayer>(
        find.byKey(LivePkStage.bannersKey),
      );
      expect(layer.right?.tier, PkPowerTier.doublePower);
      expect(layer.left?.tier, PkPowerTier.tripleTurbo);
    });

    testWidgets("the result: the winner's Kabi celebrates", (tester) async {
      await stage(
        tester,
        pkMatchFixture(
          now: DateTime.now(),
          status: PkMatchStatus.result,
          winner: 'room-0',
        ),
      );
      final bar = tester.widget<PkBattleBar>(find.byType(PkBattleBar));
      expect(bar.winner, PkPowerSide.right);
      expect(
        assets(tester, find.byKey(LivePkStage.barKey)),
        contains('assets/pk/score_bar/kabi/kabi_win.png'),
      );
    });

    testWidgets('reduced motion: the banner and bar still show', (
      tester,
    ) async {
      await stage(
        tester,
        pkMatchFixture(now: DateTime.now(), ownBoost: PkBoosterKind.triple),
        reduceMotion: true,
      );
      expect(find.byType(PkPowerBanner), findsOneWidget);
      expect(find.byType(PkBattleBar), findsOneWidget);
    });
  });
}
