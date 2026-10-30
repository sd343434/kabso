// D174 (owner «نعم بالطبع»: viewers join a solo live as guests, at most 3):
// the solo viewer's ∞ (ask, pending → cancel, seated → leave, full) and the
// guests' tiles at the end over the chat, through the real viewer screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_guest_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _u(String id) =>
    UserSummary(id: id, username: id, displayName: id, avatarUrl: null);

LiveSeats _solo({
  List<String?> people = const [null, null, null],
  int? mine,
  LiveSeatRequest? request,
  int version = 1,
}) => LiveSeats(
  roomId: 'room-0',
  mode: LiveRoomMode.solo,
  version: version,
  seatCount: 4,
  seats: [
    for (final (i, p) in people.indexed)
      LiveSeat(
        index: i + 1,
        state: p == null ? LiveSeatState.empty : LiveSeatState.taken,
        user: p == null ? null : _u(p),
        mutedByHost: p == 'muted',
      ),
  ],
  moderators: const [],
  mine: LiveSeatsMine(
    role: mine == null ? LiveSeatRole.viewer : LiveSeatRole.seated,
    seatIndex: mine,
    request: request,
    invite: null,
  ),
);

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  required LiveSeats seats,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  setViewport(tester, viewport);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final repo = FakeLiveRepository(room: (id) => apiRoom(id: id))
    ..seatState = seats;
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return (repo, engine);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('∞ asks to join as a guest (a real seat request)', (
    tester,
  ) async {
    final (repo, _) = await _pump(tester, seats: _solo());
    await tester.tap(find.byKey(LiveRoomScreen.guestKey));
    await tester.pumpAndSettle();
    expect(repo.seatCalls, contains('requestSeat:'));
    await _leave(tester);
  });

  testWidgets('pending: ∞ cancels; seated: ∞ leaves', (tester) async {
    final me = testUser();
    final (repo, _) = await _pump(
      tester,
      seats: _solo(
        request: LiveSeatRequest(
          id: 'r1',
          user: _u(me.id),
          seatIndex: null,
          createdAt: DateTime.utc(2026, 10, 30),
        ),
      ),
    );
    expect(find.byKey(LiveRoomScreen.guestKey), findsNothing);
    await tester.tap(find.byKey(LiveRoomScreen.guestCancelKey));
    await tester.pumpAndSettle();
    expect(repo.seatCalls, contains('cancelSeatRequest'));
    await _leave(tester);
    final (seated, _) = await _pump(
      tester,
      seats: _solo(people: [me.id, null, null], mine: 1),
    );
    await tester.tap(find.byKey(LiveRoomScreen.guestLeaveKey));
    await tester.pumpAndSettle();
    expect(seated.seatCalls.any((c) => c.startsWith('leaveSeat')), isTrue);
    await _leave(tester);
  });

  testWidgets('3 guests: ∞ says the seats are full, no request', (
    tester,
  ) async {
    final (repo, _) = await _pump(
      tester,
      seats: _solo(people: ['a', 'b', 'c']),
    );
    await tester.tap(find.byKey(LiveRoomScreen.guestKey));
    await tester.pump();
    expect(find.text(l10nFor(AppLanguage.en).liveGuestsFull), findsOneWidget);
    expect(repo.seatCalls.where((c) => c.startsWith('requestSeat')), isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await _leave(tester);
  });

  for (final language in AppLanguage.values) {
    for (final viewport in GoldenViewport.values) {
      testWidgets('2 guests: tiles at the reading end over the bar, beside '
          'the chat, the muted one marked; a tap opens the card '
          '(${language.name}, ${viewport.name}, text 1.3)', (tester) async {
        await _pump(
          tester,
          seats: _solo(people: ['huda', null, 'muted']),
          language: language,
          viewport: viewport,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final one = find.byKey(LiveGuestTiles.tileKey(1));
        final three = find.byKey(LiveGuestTiles.tileKey(3));
        expect(one, findsOneWidget);
        expect(three, findsOneWidget);
        expect(find.byKey(LiveGuestTiles.tileKey(2)), findsNothing);
        expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
        final a = tester.getRect(one);
        final b = tester.getRect(three);
        expect(a.bottom, lessThanOrEqualTo(b.top));
        final width = viewport.logicalSize.width;
        final ar = language == AppLanguage.ar;
        expect(ar ? a.left < 16 : a.right > width - 16, isTrue);
        final gift = tester.getRect(find.byKey(LiveRoomScreen.giftKey));
        expect(b.bottom, lessThanOrEqualTo(gift.top));
        final chat = tester.getRect(find.byType(LiveRoomChatLines));
        expect(chat.overlaps(a) || chat.overlaps(b), isFalse);
        await tester.tap(one);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await _leave(tester);
      });
    }
  }
}
