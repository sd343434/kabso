// D212b (owner 2026-11-01: «البودكاست تظهر له ثيمات البث الصوتي وهذا خطأ
// ازلها»): a podcast offers only its three backgrounds — in the go-live
// setup and in the live (≡ and «إعدادات البث» use the same list) — and the
// audio room and the multi-guest live never offer them. Client only (the
// server accepts any theme in any mode). Fakes stand in for the API.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const List<String> _roomThemes = [
  LiveThemes.classic,
  'ice-palace',
  'desert-night',
  'rose-garden',
  'sunset-sky',
  'moon-palace',
  'ocean-depths',
  'golden-hall',
  'game-arena',
  'heart-garden',
  'galaxy',
];

/// The server's list (v1.47-live): the room themes, then the podcast ones.
const List<String> _all = [..._roomThemes, ...LiveThemeArt.podcastThemes];

LiveConfig _config(List<String> themes) => LiveConfig(
  hostingEnabled: true,
  heartbeatIntervalSeconds: 15,
  heartbeatStaleAfterSeconds: 45,
  themes: themes,
);

/// The theme slugs in the open theme sheet, in order.
List<String> _sheetThemes(WidgetTester tester) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('goLive.theme.'),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('goLive.theme.'.length),
];

Future<void> _openSetupThemes(WidgetTester tester, LiveRoomMode mode) async {
  final repo = FakeLiveRepository(
    categories: const [LiveCategory(slug: 'chat', name: 'Chat')],
  )..themes = _all;
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    liveMediaEngine: FakeLiveMediaEngine(),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
  // D224: the type row scrolls sideways (the podcast may be off screen).
  await tester.ensureVisible(find.byKey(GoLiveKeys.mode(mode)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.mode(mode)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveAudioSetup.themeKey));
  await tester.pumpAndSettle();
}

void main() {
  group('the themes offered per mode', () {
    test('PODCAST: exactly the three podcast backgrounds, studio first', () {
      expect(GoLiveScreen.themesFor(LiveRoomMode.podcast, _config(_all)), [
        'podcast-studio',
        'podcast-majlis',
        'podcast-library',
      ]);
    });

    test('PODCAST on a config without them: still only the podcast three', () {
      expect(
        GoLiveScreen.themesFor(LiveRoomMode.podcast, _config(_roomThemes)),
        LiveThemeArt.podcastThemes,
      );
      expect(
        GoLiveScreen.themesFor(LiveRoomMode.podcast, null),
        LiveThemeArt.podcastThemes,
      );
    });

    for (final mode in [
      LiveRoomMode.audio,
      LiveRoomMode.multi,
      LiveRoomMode.solo,
    ]) {
      test('${mode.name}: the room themes, no podcast background', () {
        final themes = GoLiveScreen.themesFor(mode, _config(_all));
        expect(themes, _roomThemes);
        for (final p in LiveThemeArt.podcastThemes) {
          expect(themes, isNot(contains(p)), reason: p);
        }
      });
    }
  });

  testWidgets("the podcast setup's theme sheet lists the three podcast "
      'backgrounds only', (tester) async {
    await _openSetupThemes(tester, LiveRoomMode.podcast);
    expect(_sheetThemes(tester), LiveThemeArt.podcastThemes);
    for (final t in _roomThemes) {
      expect(find.byKey(GoLiveKeys.theme(t)), findsNothing, reason: t);
    }
  });

  testWidgets("the audio room setup's theme sheet has no podcast "
      'background', (tester) async {
    await _openSetupThemes(tester, LiveRoomMode.audio);
    final themes = _sheetThemes(tester);
    expect(themes, isNotEmpty);
    for (final p in LiveThemeArt.podcastThemes) {
      expect(themes, isNot(contains(p)), reason: p);
    }
    expect(themes, contains(LiveThemes.classic));
  });
}
