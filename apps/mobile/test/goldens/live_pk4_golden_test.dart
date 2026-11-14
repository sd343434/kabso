// D391 (v1.118-live, CONVENTIONS §10.180, CP-041 phase 2) «PK رباعي»: the
// 2 × 2 stage of D71 wired to a real match — the team bar (Kabso red for
// this room's team on the reading start, blazing orange for the opponents),
// the four panes with each host's own score, the team booster chip, a host
// who left, the top three supporters per team — at 360 × 800 with text
// × 1.3, ar and en, dark and light; the result; and the host's lobby with its
// four places — D393: on the PK sheet's «PK رباعي» segment (the mode cards
// above it), no longer a sheet of its own.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk4_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/application/live_pk4_controller.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_pk4.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

const _scale = 1.3;

/// The stage on the room's black, as a viewer of room-0 sees it.
Future<void> _pumpStage(
  WidgetTester tester, {
  required AppLanguage language,
  required Brightness brightness,
  required Pk4Match match,
}) async {
  KabsoPkBar.enabled = true;
  addTearDown(() => KabsoPkBar.enabled = false);
  await pumpGolden(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(_scale)),
        child: ColoredBox(
          color: brightness == Brightness.dark
              ? const Color(0xFF0B0A0F)
              : const Color(0xFFF4F2F7),
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
      ),
    ),
    language: language,
    viewport: GoldenViewport.android,
    brightness: brightness,
    bare: true,
  );
  // Kabi's Lottie loads in real time.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    for (final (label, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets('room.pk4.battle ${language.name} $label', (tester) async {
        final now = DateTime.utc(2026, 11, 13, 10);
        await _pumpStage(
          tester,
          language: language,
          brightness: brightness,
          match: pk4MatchFixture(
            now: now,
            ar: ar,
            boostA: PkBoosterKind.triple,
            out: const [4],
            mutedByMe: const ['room-2'],
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/room.pk4.battle.${language.name}.$label.png'),
        );
      });
    }

    testWidgets('room.pk4.result ${language.name} dark', (tester) async {
      final now = DateTime.utc(2026, 11, 13, 10);
      await _pumpStage(
        tester,
        language: language,
        brightness: Brightness.dark,
        match: pk4MatchFixture(
          now: now,
          ar: ar,
          status: PkMatchStatus.result,
          winner: Pk4Team.a,
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/room.pk4.result.${language.name}.dark.png'),
      );
    });

    testWidgets('go_live.pk4.lobby ${language.name}', (tester) async {
      final now = DateTime.utc(2026, 11, 13, 10);
      LivePkStage.debugNow = () => now;
      addTearDown(() => LivePkStage.debugNow = null);
      final prefs = await testPrefs(language: language.name);
      final lobby = pk4LobbyFixture(now: now, ar: ar);
      final repo = FakeLivePk4Repository(snapshot: Pk4State(lobby: lobby));
      await pumpGolden(
        tester,
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            livePk4RepositoryProvider.overrideWithValue(repo),
          ],
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(_scale)),
              child: const ColoredBox(
                color: Color(0xFF0B0A0F),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  // D393: the lobby is the PK sheet's «PK رباعي» segment.
                  child: LivePkSheet(
                    roomId: 'room-0',
                    initialMode: PkSheetMode.team,
                  ),
                ),
              ),
            ),
          ),
        ),
        language: language,
        viewport: GoldenViewport.android,
        brightness: Brightness.light,
        bare: true,
      );
      final element = tester.element(find.byType(LivePk4Panel));
      ProviderScope.containerOf(element)
          .read(livePk4Provider('room-0').notifier)
          .debugSetLobby(lobby);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/go_live.pk4.lobby.${language.name}.android.png'),
      );
    });
  });
}
