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
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_pages.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
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
    testWidgets('1v1 is selected and works; Team and Multi say «قريباً»', (
      tester,
    ) async {
      final repo = await _sheet(tester);
      final l10n = _l10n(tester);
      final one = tester.widget<PkModeCard>(
        find.byKey(LivePkSheet.modeKey(PkSheetMode.oneVsOne)),
      );
      expect((one.selected, one.soon), (true, false));
      for (final m in [PkSheetMode.team, PkSheetMode.multi]) {
        final card = tester.widget<PkModeCard>(
          find.byKey(LivePkSheet.modeKey(m)),
        );
        expect((card.selected, card.soon), (false, true), reason: m.name);
      }
      expect(find.text(l10n.liveSoon), findsNWidgets(2));
      await tester.tap(find.byKey(LivePkSheet.modeKey(PkSheetMode.team)));
      await tester.pump();
      expect(find.text(l10n.pkModeSoon(l10n.pkModeTeam)), findsOneWidget);
      // Still 1v1: nothing was asked of the server.
      expect(
        repo.calls.where((c) => c.startsWith('invite') || c == 'random'),
        isEmpty,
      );
    });

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
      double? burst,
      double? gain,
      PkAnnouncement? announcement,
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
                roomId: 'room-0',
                ownVideo: null,
                opponentVideo: null,
                now: DateTime.now,
                onStart: onStart,
                announcement: announcement,
                burstProgress: burst,
                gainProgress: gain,
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

    for (final kind in PkBoosterKind.values) {
      for (final (phase, t) in [('start', 0.06), ('mid', 0.3), ('fly', 0.9)]) {
        testWidgets('${kind.name} activation — $phase', (tester) async {
          final now = DateTime.now();
          await stage(
            tester,
            pkMatchFixture(now: now, ownBoost: kind),
            burst: t,
            announcement: PkAnnouncement(
              roomId: 'room-0',
              teamName: 'سارة',
              kind: kind,
              multiplier: {
                PkBoosterKind.double: 2,
                PkBoosterKind.doubleTurbo: 3,
                PkBoosterKind.triple: 5,
                PkBoosterKind.tripleTurbo: 10,
              }[kind]!,
              serial: 1,
            ),
          );
          final burst = find.byKey(LivePkStage.announcementKey);
          expect(burst, findsOneWidget);
          // Only over this side's box (the reading start: the right in
          // Arabic), never the other host.
          final box = tester.getRect(burst);
          expect(box.left, greaterThanOrEqualTo(393 / 2 - 1));
          final line = tester.widget<Text>(find.byKey(PkBoostBurst.lineKey));
          expect(line.data, startsWith('فعّل فريق'));
          expect(line.style?.fontFamily, PkBoostText.family);
          final painter = tester
              .widgetList<CustomPaint>(
                find.descendant(of: burst, matching: find.byType(CustomPaint)),
              )
              .map((p) => p.painter)
              .whereType<PkBoostFxPainter>()
              .single;
          final tier = PkBoostTier.of(kind);
          expect(painter.tier, tier);
          expect(
            tier.streaks,
            kind == PkBoosterKind.doubleTurbo ||
                kind == PkBoosterKind.tripleTurbo,
          );
          expect(
            tier.sparks,
            kind == PkBoosterKind.triple || kind == PkBoosterKind.tripleTurbo,
          );
          expect(tier.edgePulse, kind == PkBoosterKind.tripleTurbo);
          // The active chip sits on this side with the art, ×N and a ring.
          final chip = tester.widget<PkBoostChip>(
            find.byKey(LivePkStage.boostChipKey('room-0')),
          );
          expect(chip.kind, kind);
          expect(chip.left.inSeconds, inInclusiveRange(13, 14));
          expect(chip.total, isNot(Duration.zero));
          expect(find.byKey(LivePkStage.glowKey('room-0')), findsOneWidget);
          expect(
            tester
                .widget<PkBarGlow>(find.byKey(LivePkStage.glowKey('room-0')))
                .active,
            isTrue,
          );
          expect(
            tester
                .widget<PkBarGlow>(find.byKey(LivePkStage.glowKey('room-b')))
                .active,
            isFalse,
          );
        });
      }
    }

    testWidgets('reduced motion: the activation only fades', (tester) async {
      await stage(
        tester,
        pkMatchFixture(now: DateTime.now(), ownBoost: PkBoosterKind.triple),
        burst: 0.5,
        reduceMotion: true,
        announcement: const PkAnnouncement(
          roomId: 'room-0',
          teamName: 'سارة',
          kind: PkBoosterKind.triple,
          multiplier: 5,
          serial: 1,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(LivePkStage.announcementKey),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.byKey(PkBoostBurst.lineKey), findsOneWidget);
    });

    testWidgets('each gift on the boosted side shows «+N ×5»; the glow fades '
        'when the booster ends', (tester) async {
      final now = DateTime.now();
      await stage(
        tester,
        pkMatchFixture(now: now, ownBoost: PkBoosterKind.triple),
        gain: 0.4,
      );
      await stage(
        tester,
        pkMatchFixture(
          now: now,
          ownBoost: PkBoosterKind.triple,
          ownScore: 12500 + 5000,
          seq: 6,
        ),
        gain: 0.4,
      );
      expect(find.byKey(LivePkStage.gainKey('room-0')), findsOneWidget);
      expect(find.text('+5,000 ×5'), findsOneWidget);
      expect(find.byKey(LivePkStage.gainKey('room-b')), findsNothing);
      await tester.pump(PkGainFloat.duration);
      expect(find.byKey(LivePkStage.gainKey('room-0')), findsNothing);
      // The booster ends: the glow stays (fading), no longer active.
      await stage(tester, pkMatchFixture(now: now, seq: 7));
      final glow = tester.widget<PkBarGlow>(
        find.byKey(LivePkStage.glowKey('room-0')),
      );
      expect((glow.kind, glow.active), (PkBoosterKind.triple, false));
      expect(find.byKey(LivePkStage.boostChipKey('room-0')), findsNothing);
    });
  });
}
