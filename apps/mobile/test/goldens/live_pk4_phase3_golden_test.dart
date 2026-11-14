// D395 (v1.119-live, CONVENTIONS §10.181, CP-041 phases 3–4; owner «أ و ب»)
// «PK رباعي» for two to four hosts: the stage's layouts — TEAMS and
// FREE_FOR_ALL with two (half the screen each), three (two stacked, the third
// alone in a tile the size of two) and four (the 2 × 2 grid), the
// FREE_FOR_ALL result with its places — the result badge under the scores line
// (win with the crown, loss, draw), the smaller friends list of both tabs of
// the PK sheet, «ابدأ الآن», the TEAMS / FREE_FOR_ALL choice and the 4-way
// random queue. Arabic (RTL) and English (LTR) where the layout differs.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk4_phase3_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/application/live_pk4_controller.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_pk4.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 11, 13, 10);

/// The stage on the room's black, as the host of room-0 sees it.
Future<void> _pumpStage(
  WidgetTester tester, {
  required AppLanguage language,
  required Pk4Match match,
}) async {
  KabsoPkBar.enabled = true;
  addTearDown(() => KabsoPkBar.enabled = false);
  await pumpGolden(
    tester,
    ColoredBox(
      color: const Color(0xFF0B0A0F),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 96),
            LivePk4Stage(
              match: match,
              roomId: 'room-0',
              now: () => match.serverTime,
              video: (_) => null,
              isHost: true,
              onMute: (_, {required muted}) {},
            ),
          ],
        ),
      ),
    ),
    language: language,
    viewport: GoldenViewport.phone,
    brightness: Brightness.dark,
    bare: true,
  );
  // Kabi's Lottie loads in real time.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
}

/// The PK sheet on the room's black (the «PK ثنائي» or «PK رباعي» segment).
Future<LivePk4Controller> _pumpSheet(
  WidgetTester tester, {
  required AppLanguage language,
  required PkSheetMode mode,
  Pk4Lobby? lobby,
  Pk4Queue? queue,
  int? place,
}) async {
  LivePkStage.debugNow = () => _now;
  addTearDown(() => LivePkStage.debugNow = null);
  final ar = language == AppLanguage.ar;
  final prefs = await testPrefs(language: language.name);
  final friends = [
    for (final (i, (a, e)) in [
      ('ليلى', 'Layla'),
      ('كريم', 'Karim'),
      ('نور', 'Nour'),
      ('زياد', 'Ziad'),
    ].indexed)
      PkCandidate(
        roomId: 'friend-$i',
        title: ar ? 'بث مسائي' : 'Evening live',
        viewerCount: 120 - i * 10,
        host: pk4User('friend-user-$i', ar ? a : e),
      ),
  ];
  final repo = FakeLivePk4Repository(
    snapshot: Pk4State(lobby: lobby, queue: queue),
    list: friends,
  );
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        livePk4RepositoryProvider.overrideWithValue(repo),
        livePkRepositoryProvider.overrideWithValue(
          FakeLivePkRepository(list: friends),
        ),
      ],
      child: ColoredBox(
        color: const Color(0xFF0B0A0F),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: LivePkSheet(roomId: 'room-0', initialMode: mode),
        ),
      ),
    ),
    language: language,
    viewport: GoldenViewport.phone,
    brightness: Brightness.light,
    bare: true,
  );
  final element = tester.element(find.byType(LivePkSheet));
  final controller = ProviderScope.containerOf(element)
      .read(livePk4Provider('room-0').notifier);
  if (lobby != null) controller.debugSetLobby(lobby);
  if (queue != null) controller.debugSetQueue(queue);
  await tester.pumpAndSettle();
  if (place != null) {
    await tester.tap(find.byKey(LivePk4Panel.placeKey(place)));
    await tester.pumpAndSettle();
  }
  return controller;
}

void main() {
  setUpAll(loadAppFonts);

  // ---- The stage's layouts ---------------------------------------------------------------------
  for (final ffa in [false, true]) {
    final format = ffa ? 'ffa' : 'teams';
    for (final players in [2, 3, 4]) {
      testWidgets('room.pk4p3.$format.$players ar', (tester) async {
        await _pumpStage(
          tester,
          language: AppLanguage.ar,
          match: pk4PlayersFixture(
            now: _now,
            players: players,
            ffa: ffa,
            scores: const [53200, 12400, 50300, 13000],
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/room.pk4p3.$format.$players.ar.png'),
        );
      });
    }
  }

  testWidgets('room.pk4p3.ffa.3 en (LTR)', (tester) async {
    await _pumpStage(
      tester,
      language: AppLanguage.en,
      match: pk4PlayersFixture(now: _now, players: 3, ffa: true, ar: false),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/room.pk4p3.ffa.3.en.png'),
    );
  });

  testWidgets('room.pk4p3.ffa.4.result ar (places)', (tester) async {
    await _pumpStage(
      tester,
      language: AppLanguage.ar,
      match: pk4PlayersFixture(
        now: _now,
        players: 4,
        ffa: true,
        status: PkMatchStatus.result,
        places: const [1, 3, 2, 4],
        results: const [
          Pk4Result.win,
          Pk4Result.loss,
          Pk4Result.loss,
          Pk4Result.loss,
        ],
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/room.pk4p3.ffa.4.result.ar.png'),
    );
  });

  // ---- The result badge (win, loss, draw) -------------------------------------------------------
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    final ar = language == AppLanguage.ar;
    for (final (name, winner) in [
      ('win', Pk4Team.a),
      ('loss', Pk4Team.b),
      ('draw', null),
    ]) {
      testWidgets('room.pk4p3.badge.$name ${language.name}', (tester) async {
        await _pumpStage(
          tester,
          language: language,
          match: pk4PlayersFixture(
            now: _now,
            players: 4,
            ar: ar,
            status: PkMatchStatus.result,
            winner: winner,
            scores: winner == null
                ? const [30000, 20000, 25000, 25000]
                : const [53200, 12400, 50300, 13000],
          ),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/room.pk4p3.badge.$name.${language.name}.png'),
        );
      });
    }
  }

  // ---- The PK sheet ------------------------------------------------------------------------------
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    testWidgets('go_live.pk4p3.friends.one ${language.name}', (tester) async {
      await _pumpSheet(tester, language: language, mode: PkSheetMode.oneVsOne);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/go_live.pk4p3.friends.one.${language.name}.png'),
      );
    });

    testWidgets('go_live.pk4p3.friends.four ${language.name}', (tester) async {
      await _pumpSheet(
        tester,
        language: language,
        mode: PkSheetMode.team,
        lobby: pk4LobbyFormatFixture(now: _now, ar: language == AppLanguage.ar),
        place: 4,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/go_live.pk4p3.friends.four.${language.name}.png',
        ),
      );
    });
  }

  testWidgets('go_live.pk4p3.choice ar', (tester) async {
    await _pumpSheet(tester, language: AppLanguage.ar, mode: PkSheetMode.team);
    await tester.tap(find.byKey(LivePk4Panel.formatKey(Pk4Format.freeForAll)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/go_live.pk4p3.choice.ar.png'),
    );
  });

  testWidgets('go_live.pk4p3.start ar (FREE_FOR_ALL lobby, «ابدأ الآن»)', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      language: AppLanguage.ar,
      mode: PkSheetMode.team,
      lobby: pk4LobbyFormatFixture(
        now: _now,
        format: Pk4Format.freeForAll,
        states: const [
          Pk4SeatState.accepted,
          Pk4SeatState.accepted,
          Pk4SeatState.invited,
        ],
      ),
    );
    expect(find.byKey(LivePk4Panel.startNowKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/go_live.pk4p3.start.ar.png'),
    );
  });

  testWidgets('go_live.pk4p3.random ar', (tester) async {
    await _pumpSheet(
      tester,
      language: AppLanguage.ar,
      mode: PkSheetMode.team,
      queue: Pk4Queue(
        format: Pk4Format.teams,
        expiresAt: _now.add(const Duration(minutes: 1, seconds: 34)),
      ),
    );
    expect(find.byKey(LivePk4Panel.searchingKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/go_live.pk4p3.random.ar.png'),
    );
  });
}
