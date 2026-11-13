// D261 (owner's device: «في بث البودكاست رسائل المشاهد لا تظهر عند
// المضيف»): a listener's chat message reaches the podcast host's screen —
// as a data message, and, when that never arrives, from the server's last
// messages at the next heartbeat. Fakes stand in for the API and the media
// engine (tests only).
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
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

const _listener = UserSummary(
  id: 'v1',
  username: 'noor',
  displayName: 'نور',
  avatarUrl: null,
);

LiveChatEntry _message(String id, String text, {int minute = 0}) =>
    LiveChatEntry(
      id: id,
      roomId: 'room-0',
      author: _listener,
      text: text,
      createdAt: DateTime.utc(2026, 11, 4, 18, minute),
      authorRole: LiveChatRole.viewer,
    );

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _podcastOnAir(
  WidgetTester tester,
) async {
  final repo = FakeLiveRepository(
    categories: const [LiveCategory(slug: 'chat', name: 'Chat')],
  );
  final engine = FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.android);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: AppLanguage.ar,
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

Finder _text(String t) => find.textContaining(t, findRichText: true);

/// The line is laid out on the screen (not scrolled away or clipped off).
void _onScreen(WidgetTester tester, Finder line) {
  final rect = tester.getRect(line.first);
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(screen.contains(rect.center), isTrue, reason: '$rect');
  final list = tester.getRect(find.byKey(LiveRoomChatLines.listKey));
  expect(list.contains(rect.center), isTrue, reason: '$rect in $list');
}

void main() {
  testWidgets("a listener's message shows on the podcast host's screen", (
    tester,
  ) async {
    final (_, engine) = await _podcastOnAir(tester);
    engine.chat.add(LiveChatReceived(_message('m1', 'سؤال من مستمع')));
    await tester.pump();
    await tester.pump();
    expect(_text('سؤال من مستمع'), findsOneWidget);
    _onScreen(tester, _text('سؤال من مستمع'));
    await _leave(tester);
  });

  testWidgets('a message whose data message never arrived shows at the next '
      'heartbeat, once and in order; a deleted one never comes back', (
    tester,
  ) async {
    final (repo, engine) = await _podcastOnAir(tester);
    // Arrived as a data message: the catch-up does not add it again.
    engine.chat.add(LiveChatReceived(_message('m1', 'وصلت', minute: 1)));
    await tester.pump();
    // Stored by the server, never delivered to this phone.
    repo.chat = [
      _message('m1', 'وصلت', minute: 1),
      _message('m2', 'لم تصل', minute: 2),
      _message('m3', 'ولا هذه', minute: 3),
    ];
    expect(_text('لم تصل'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    await tester.pump();
    expect(repo.heartbeats, isNotEmpty);
    expect(_text('وصلت'), findsOneWidget);
    expect(_text('لم تصل'), findsOneWidget);
    expect(_text('ولا هذه'), findsOneWidget);
    _onScreen(tester, _text('ولا هذه'));
    expect(
      tester.getRect(_text('لم تصل')).top,
      lessThan(tester.getRect(_text('ولا هذه')).top),
    );
    // A deleted line is never brought back.
    engine.chat.add(const LiveChatDeleted('m2'));
    await tester.pump();
    expect(_text('لم تصل'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    await tester.pump();
    expect(_text('لم تصل'), findsNothing);
    expect(_text('ولا هذه'), findsOneWidget);
    await _leave(tester);
  });
}
