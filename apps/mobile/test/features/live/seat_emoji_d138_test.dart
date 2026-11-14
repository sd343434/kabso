// D138 (owner: «في البث الصوتي المستخدم يستخدمها على الكرسي بحيث تظهر داخل
// إطار الكرسي فوق صورته لحركة مرة واحدة وتختفي دون تكرار تلقائي»): someone
// seated in an audio room plays one of the owner's pack emojis on their own
// seat — once, over their picture, for everyone (`seat-emoji`, v1.27.5-live).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/emoji/unicode_emoji.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_seat_emojis.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_seat_emoji.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _omar = UserSummary(
  id: 'user-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

/// An audio room of 10 seats: me on seat 2 (unless [seated] is false),
/// Omar on seat 3.
FakeLiveRepository _room({bool seated = true}) {
  final me = testUser();
  return FakeLiveRepository(
      room: (id) =>
          apiRoom(id: id).copyWith(mode: LiveRoomMode.audio, seatCount: 10),
    )
    ..seatState = LiveSeats(
      roomId: 'room-0',
      mode: LiveRoomMode.audio,
      version: 1,
      seatCount: 10,
      seats: [
        for (var i = 1; i < 10; i++)
          switch (i) {
            2 when seated => LiveSeat(
              index: 2,
              state: LiveSeatState.taken,
              user: UserSummary(
                id: me.id,
                username: me.username,
                displayName: me.displayName,
                avatarUrl: null,
              ),
            ),
            3 => const LiveSeat(
              index: 3,
              state: LiveSeatState.taken,
              user: _omar,
            ),
            _ => LiveSeat(index: i, state: LiveSeatState.empty, user: null),
          },
      ],
      moderators: const [],
      mine: LiveSeatsMine(
        role: seated ? LiveSeatRole.seated : LiveSeatRole.viewer,
        seatIndex: seated ? 2 : null,
        request: null,
        invite: null,
      ),
    );
}

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester,
  FakeLiveRepository repo, {
  AppLanguage language = AppLanguage.en,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.phone);
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
  return engine;
}

/// The pack emojis loop in the sheet: pump, never settle.
Future<void> _frames(WidgetTester tester, {int n = 4}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _burstOn(int seat) => find.descendant(
  of: find.byKey(AudioSeatRing.seatKey(seat)),
  matching: find.byType(SeatEmojiBurst),
);

Future<void> _pick(WidgetTester tester, KabsoEmoji emoji) async {
  await tester.tap(find.byKey(AudioRoomViewKeys.seatEmoji));
  await _frames(tester);
  expect(find.byKey(SeatEmojiSheet.panelKey), findsOneWidget);
  await tester.tap(find.byKey(EmojiPanel.packKey(emoji)));
  await _frames(tester, n: 5);
}

void main() {
  testWidgets('not seated: no seat emoji button', (tester) async {
    await _pump(tester, _room(seated: false));
    expect(find.byKey(AudioRoomViewKeys.seatEmoji), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('seated: the button opens the packs only; a tap closes the '
      'sheet, plays the emoji once over my picture at once (≈ 85 % of it), '
      'sends it, drops the echo, then it is gone', (tester) async {
    final repo = _room();
    final engine = await _pump(tester, repo);
    await tester.tap(find.byKey(AudioRoomViewKeys.seatEmoji));
    await _frames(tester);
    final sheet = find.byKey(SeatEmojiSheet.panelKey);
    expect(sheet, findsOneWidget);
    for (final p in EmojiPack.values.take(3)) {
      expect(find.byKey(EmojiPanel.tabKey(EmojiPackTab(p))), findsOneWidget);
    }
    for (final g in UnicodeEmojiGroup.values) {
      expect(find.byKey(EmojiPanel.tabKey(UnicodeEmojiTab(g))), findsNothing);
    }
    await tester.tap(find.byKey(EmojiPanel.packKey(KabsoEmoji.kabi('love'))));
    await _frames(tester, n: 5);
    expect(sheet, findsNothing);
    expect(repo.seatEmojiCalls, [':kabi_love:']);

    final burst = _burstOn(2);
    expect(burst, findsOneWidget);
    expect(tester.widget<SeatEmojiBurst>(burst).emoji, KabsoEmoji.kabi('love'));
    // Centred over the picture, about 85 % of it (the Lottie canvas holds
    // the character at ~77 %), under the name.
    final lottie = find.descendant(of: burst, matching: find.byType(Lottie));
    final canvas = tester.getRect(lottie);
    expect(
      canvas.width,
      moreOrLessEquals(SeatEmojiBurst.canvasFor(AudioSeatRing.picture)),
    );
    expect(canvas.width * 0.77 / AudioSeatRing.picture, closeTo(0.85, 0.01));
    final avatar = tester.getRect(
      find
          .descendant(
            of: find.byKey(AudioSeatRing.seatKey(2)),
            matching: find.byType(KAvatar),
          )
          .first,
    );
    expect(canvas.center.dx, moreOrLessEquals(avatar.center.dx, epsilon: 0.5));
    expect(canvas.center.dy, moreOrLessEquals(avatar.center.dy, epsilon: 0.5));
    // Not a loop: its controller, not Lottie's repeat.
    expect(tester.widget<Lottie>(lottie).controller, isNotNull);

    // The server's echo of my own emoji is dropped (no restart).
    final before = tester.widget<SeatEmojiBurst>(burst).key;
    engine.chat.add(
      LiveSeatEmojiReceived(
        LiveSeatEmoji(
          id: 'seat-emoji-1',
          seat: 2,
          user: UserSummary(
            id: testUser().id,
            username: testUser().username,
            displayName: testUser().displayName,
            avatarUrl: null,
          ),
          token: ':kabi_love:',
          createdAt: DateTime.utc(2026, 10, 27, 20),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<SeatEmojiBurst>(burst).key, before);

    // One cycle (2 s) and the fade, then nothing is left on the seat.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(burst, findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(burst, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("someone else's emoji plays on their seat for me; a new one "
      'replaces it; unknown tokens are ignored', (tester) async {
    final engine = await _pump(tester, _room());
    LiveSeatEmojiReceived message(String id, String token, {int seat = 3}) =>
        LiveSeatEmojiReceived(
          LiveSeatEmoji(
            id: id,
            seat: seat,
            user: _omar,
            token: token,
            createdAt: DateTime.utc(2026, 10, 27, 20),
          ),
        );
    engine.chat.add(message('a', ':flags_ps:'));
    await tester.pump();
    await tester.pump();
    expect(_burstOn(3), findsOneWidget);
    expect(
      tester.widget<SeatEmojiBurst>(_burstOn(3)).emoji,
      KabsoEmoji.byKey('flags_ps'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    engine.chat.add(message('b', ':gogo_roar:'));
    await tester.pump();
    await tester.pump();
    expect(_burstOn(3), findsOneWidget);
    expect(
      tester.widget<SeatEmojiBurst>(_burstOn(3)).emoji,
      KabsoEmoji.byKey('gogo_roar'),
    );
    engine.chat.add(message('c', ':kabi_nope:', seat: 4));
    engine.chat.add(message('d', '😀', seat: 4));
    await tester.pump();
    expect(find.byType(SeatEmojiBurst), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SeatEmojiBurst), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion: the first frame for 1.5 s, then gone', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, _room());
    await tester.tap(find.byKey(AudioRoomViewKeys.seatEmoji));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EmojiPanel.packKey(KabsoEmoji.kabi('wow'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final burst = _burstOn(2);
    expect(burst, findsOneWidget);
    final lottie = tester.widget<Lottie>(
      find.descendant(of: burst, matching: find.byType(Lottie)),
    );
    expect(lottie.controller!.value, 0);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(burst, findsOneWidget);
    expect(lottie.controller!.value, 0);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(burst, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a refused send takes the emoji off and says why', (
    tester,
  ) async {
    final repo = _room()
      ..seatEmojiFailure = const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'x',
        statusCode: 429,
      );
    await _pump(tester, repo);
    await _pick(tester, KabsoEmoji.kabi('hi'));
    expect(repo.seatEmojiCalls, [':kabi_hi:']);
    expect(_burstOn(2), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Arabic RTL: the button and the sheet fit, the emoji on my '
      'seat', (tester) async {
    final repo = _room();
    await _pump(tester, repo, language: AppLanguage.ar);
    await _pick(tester, KabsoEmoji.kabi('love'));
    expect(_burstOn(2), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a token is a pack emoji or nothing', () {
    expect(LiveSeatEmojis.emojiOfToken(':kabi_love:'), KabsoEmoji.kabi('love'));
    expect(LiveSeatEmojis.emojiOfToken(':kabi_love: '), isNull);
    expect(LiveSeatEmojis.emojiOfToken('x:kabi_love:'), isNull);
    expect(LiveSeatEmojis.emojiOfToken(':kabi_nope:'), isNull);
  });
}
