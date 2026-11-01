// D225 (urgent, owner 2026-11-01): the podcast host could not mute their
// microphone while live — their speaker tile opened a card without the mic
// button, the bar had none and the voice Room Tools have no mic tile. Also
// «المقاعد» errored in a podcast (4 fixed seats) and «إيموجي على مقعدي» was
// not drawn on the speaker seats. Fakes stand in for the API and the media
// engine (tests only).
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
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

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _podcastOnAir(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.ar,
}) async {
  final repo = FakeLiveRepository(
    categories: const [LiveCategory(slug: 'chat', name: 'Chat')],
  );
  final engine = FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: engine,
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
  await tester.ensureVisible(find.byKey(GoLiveKeys.mode(LiveRoomMode.podcast)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.podcast)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'حلقة');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
  expect(repo.startRequests.single.mode, LiveRoomMode.podcast);
  expect(find.byType(PodcastStage), findsOneWidget);
  return (repo, engine);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('the bar mic mutes and unmutes the podcast host', (tester) async {
    final (_, engine) = await _podcastOnAir(tester);
    expect(engine.micEnabled, isTrue);
    await tester.tap(find.byKey(GoLiveScreen.barMicKey));
    await tester.pumpAndSettle();
    expect(engine.micEnabled, isFalse);
    // The host's speaker tile shows the muted badge.
    expect(
      find.descendant(
        of: find.byKey(PodcastSpeakers.seatKey(0)),
        matching: find.byIcon(Icons.mic_off_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(GoLiveScreen.barMicKey));
    await tester.pumpAndSettle();
    expect(engine.micEnabled, isTrue);
    await _leave(tester);
  });

  testWidgets("the host's own speaker tile opens the card with the mic", (
    tester,
  ) async {
    final (_, engine) = await _podcastOnAir(tester);
    await tester.tap(find.byKey(PodcastSpeakers.seatKey(0)));
    await tester.pumpAndSettle();
    expect(find.byKey(LivePersonToolKeys.selfMic), findsOneWidget);
    await tester.tap(find.byKey(LivePersonToolKeys.selfMic));
    await tester.pumpAndSettle();
    expect(engine.micEnabled, isFalse);
    await _leave(tester);
  });

  testWidgets('no «المقاعد» in a podcast; «إيموجي على مقعدي» plays on the '
      "host's speaker seat", (tester) async {
    final (repo, _) = await _podcastOnAir(tester);
    await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GoLiveKeys.tool('seats')), findsNothing);
    await tester.tap(find.byKey(GoLiveKeys.tool('seatEmoji')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(
      find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.lulu))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(EmojiPanel.packKey(KabsoEmoji.byKey('lulu_rainbow')!)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(repo.seatEmojiCalls, [':lulu_rainbow:']);
    expect(
      find.descendant(
        of: find.byKey(PodcastSpeakers.seatKey(0)),
        matching: find.byType(SeatEmojiBurst),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    await _leave(tester);
  });
}
