// D377 (owner 2026-11-12): the Live hub («البث») and the party page
// («الحفلة») side by side, each a 393×852 phone with the 59 / 34 insets
// and the shell's bar, so the shared top bar can be compared at a glance:
// no title, the party page's four tabs, «+» and search, no bell. In ar and
// en, dark and light, the clock pinned to the fixtures' now.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_top_bar_d377_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/live/live_fixtures.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

/// One phone of the pair: [screen] over the shell's bar at [navIndex].
class _Phone extends StatelessWidget {
  const new({required this.screen, required this.navIndex});

  final Widget screen;
  final int navIndex;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: GoldenViewport.phone.logicalSize,
    child: Scaffold(
      body: screen,
      bottomNavigationBar: shellNavBar(
        context.l10n,
        currentIndex: navIndex,
        onTap: (_) {},
      ),
    ),
  );
}

void main() {
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    // Rooms 0–5 party (audio, podcast), 6–11 video lives (solo, PK).
    List<LiveRoomSummary> rooms() => [
      for (final (i, room) in apiRooms(
        12,
        ar: ar,
        categories: apiCategories(ar: ar),
      ).indexed)
        room.copyWith(
          mode: i < 6
              ? (i.isOdd ? LiveRoomMode.podcast : LiveRoomMode.audio)
              : (i.isEven ? LiveRoomMode.solo : LiveRoomMode.pk),
          seatCount: i < 6 ? 8 : null,
          occupiedSeats: i < 6 ? i + 1 : 0,
          podcast: i < 6 && i.isOdd
              ? LivePodcast(episodeNumber: i + 2, topic: PodcastTopic.tech)
              : null,
          hostCountry: const ['JO', 'SA', null, 'EG'][i % 4],
          viewerCount: 40 + i * 37,
        ),
    ];

    for (final brightness in Brightness.values) {
      final suffix = brightness == Brightness.light ? '.light' : '';
      testWidgets('live_top_bar.side_by_side$suffix (${language.name})', (
        tester,
      ) async {
        await withClock(Clock.fixed(fixtureNow), () async {
          tester.view.padding = const FakeViewPadding(
            top: 59 * GoldenViewport.pixelRatio,
            bottom: 34 * GoldenViewport.pixelRatio,
          );
          addTearDown(tester.view.resetPadding);
          await pumpGolden(
            tester,
            ProviderScope(
              retry: (_, _) => null,
              overrides: [
                secureTokenStoreProvider.overrideWithValue(
                  InMemoryTokenStore(),
                ),
                ...liveOverrides(
                  FakeLiveRepository(
                    categories: apiCategories(ar: ar),
                    rooms: (request) => apiPage([
                      for (final room in rooms())
                        if (request.kind == null ||
                            request.kind!.includes(room.mode))
                          room,
                    ]),
                  ),
                  language: language,
                ),
              ],
              // Two phones wide (the view is widened below; pumpGolden pins
              // one phone first).
              child: const OverflowBox(
                alignment: AlignmentDirectional.topStart,
                maxWidth: 393.0 * 2,
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    // The hub first (left), then the party page.
                    _Phone(screen: LiveScreen(), navIndex: 0),
                    _Phone(screen: VoiceRoomsScreen(), navIndex: 1),
                  ],
                ),
              ),
            ),
            language: language,
            brightness: brightness,
            bare: true,
          );
          // Two phones wide.
          final phone = GoldenViewport.phone.logicalSize;
          tester.view.physicalSize =
              Size(phone.width * 2, phone.height) * GoldenViewport.pixelRatio;
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await expectScreenGolden(
            'live_top_bar.side_by_side$suffix',
            language: language,
          );
        });
      });
    }
  });
}
