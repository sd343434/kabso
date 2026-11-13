// D230 (owner's real-device test of the staging build, screenshots kept out
// of git): «رسالة النظام لا تظهر ثم عندما احد يتحدث على التكست تظهر رسالته
// في الاعلى نصفها مختفي», «الكتابة صغيرة والميداليات والمستوى صغير، واجعل
// الميداليات أسفل الاسم وأسفلهم الرسالة» and «لا يمكن إرجاع الرسائل بإصبعي،
// اعمل سحب للأسفل لأرى الرسائل القديمة».
// 1. The rules line shows for everyone entering a live, and only a message
//    that ARRIVES during the visit hides it (never the history).
// 2. The chat is anchored at the bottom; a short chat is never faded.
// 3. A message is three lines: the name, the badges under it, the message.
// 4. A finger drags back to older lines; new ones never pull the reader
//    down («رسائل جديدة ↓»); the stage under the chat gets no taps.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);

LiveChatEntry _entry(
  String id,
  String text, {
  DateTime? at,
  LiveChatAuthorBadges? badges,
  LiveChatRole role = LiveChatRole.viewer,
  UserSummary author = _huda,
}) => LiveChatEntry(
  id: id,
  roomId: 'room-0',
  author: author,
  authorRole: role,
  text: text,
  createdAt: at ?? DateTime.utc(2026, 11, 1, 1, 30),
  authorBadges: badges,
);

/// `#` the rules line, else the message text.
List<String> _lines(LiveChatState state) => [
  for (final item in state.items)
    switch (item) {
      LiveChatNoticeLine() => '#',
      LiveChatPosted(:final entry) => entry.text,
      LiveChatPending(:final text) => '…$text',
      _ => '?',
    },
];

LiveSeats _seats(LiveRoomMode mode) => LiveSeats(
  roomId: 'room-0',
  mode: mode,
  version: 1,
  seatCount: mode == LiveRoomMode.podcast ? 4 : 10,
  seats: [
    for (var i = 1; i < (mode == LiveRoomMode.podcast ? 4 : 10); i++)
      LiveSeat(index: i, state: LiveSeatState.empty, user: null),
  ],
  moderators: const [],
  mine: const LiveSeatsMine(
    role: LiveSeatRole.viewer,
    seatIndex: null,
    request: null,
    invite: null,
  ),
);

Future<(FakeLiveMediaEngine, FakeLiveRepository)> _room(
  WidgetTester tester, {
  LiveRoomMode mode = LiveRoomMode.solo,
  List<LiveChatEntry> history = const [],
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, viewport);
  final repo = FakeLiveRepository(
    room: (id) => apiRoom(id: id).copyWith(
      mode: mode,
      seatCount: mode.hasSeats ? (mode == LiveRoomMode.podcast ? 4 : 10) : null,
    ),
  )..chat = [...history];
  if (mode.hasSeats) repo.seatState = _seats(mode);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: language == AppLanguage.ar)),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return (engine, repo);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Finder _line(String key) => find.byKey(LiveRoomChatLines.lineKey(key));
final Finder _notice = find.byKey(LiveRoomChatLines.noticeKey);
final Finder _list = find.byKey(LiveRoomChatLines.listKey);

bool _fading(WidgetTester tester) =>
    LiveChatScroll.debugFading(tester.state(find.byType(LiveChatScroll)));

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(LiveChatScroll.scrollKey),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('1. the rules line: every visit, until a message ARRIVES', () {
    late FakeLiveRepository repo;
    late FakeLiveMediaEngine engine;
    late ProviderContainer container;
    ProviderSubscription<LiveChatState>? listening;

    setUp(() {
      repo = FakeLiveRepository();
      engine = FakeLiveMediaEngine();
      container = ProviderContainer(
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(container.dispose);
    });

    LiveChatState state() => container.read(liveChatProvider('room-1'));
    Future<void> attach() async {
      listening = container.listen(liveChatProvider('room-1'), (_, _) {});
      await container
          .read(liveChatProvider('room-1').notifier)
          .attach(engine, enabled: true, muted: false);
      await pumpEventQueue();
    }

    test('entering a room with history: the rules line after it, shown; a '
        'join or a gift does not hide it; a message does', () async {
      repo.chat = [_entry('h1', 'old 1'), _entry('h2', 'old 2')];
      await attach();
      expect(_lines(state()), ['old 1', 'old 2', '#']);
      expect(state().written, isFalse);
      engine.chat.add(const LiveChatJoined(_huda));
      await pumpEventQueue();
      expect(state().written, isFalse);
      engine.chat.add(LiveChatReceived(_entry('m1', 'hi')));
      await pumpEventQueue();
      expect(state().written, isTrue);
    });

    test(
      'the device bug: the chat rebuilt mid-visit (the live minimized and '
      "reopened) after the visit's last history line went (an expired "
      'clip, a deleted line): the history must not hide the rules line',
      () async {
        final t0 = DateTime.utc(2026, 11, 1, 1);
        repo.chat = [
          _entry('h1', 'old 1', at: t0),
          _entry('h2', 'old clip', at: t0.add(const Duration(seconds: 5))),
        ];
        await attach();
        expect(_lines(state()), ['old 1', 'old clip', '#']);
        listening!.close();
        await pumpEventQueue();
        // h2 is gone from the history now; nothing was said since.
        repo.chat = [_entry('h1', 'old 1', at: t0)];
        engine = FakeLiveMediaEngine();
        await attach();
        expect(_lines(state()), ['old 1', '#']);
        expect(state().written, isFalse);
      },
    );

    test('rebuilt mid-visit after messages were written: still written, the '
        'line stays gone', () async {
      repo.chat = [_entry('h1', 'old')];
      await attach();
      engine.chat.add(LiveChatReceived(_entry('m1', 'during')));
      await pumpEventQueue();
      expect(state().written, isTrue);
      listening!.close();
      await pumpEventQueue();
      repo.chat = [_entry('h1', 'old'), _entry('m1', 'during')];
      engine = FakeLiveMediaEngine();
      await attach();
      expect(_lines(state()), ['old', '#', 'during']);
      expect(state().written, isTrue);
    });

    test('sending (a pending line) counts as writing', () async {
      await attach();
      expect(state().written, isFalse);
      unawaited(
        container.read(liveChatProvider('room-1').notifier).send('hello'),
      );
      await pumpEventQueue();
      expect(state().written, isTrue);
    });
  });

  group('1 + 2. every category, as a viewer: the rules line on entering, the '
      'lines at the bottom, never faded when short', () {
    for (final mode in [
      LiveRoomMode.solo,
      LiveRoomMode.multi,
      LiveRoomMode.audio,
      LiveRoomMode.podcast,
    ]) {
      testWidgets('${mode.name}: two messages from before the visit', (
        tester,
      ) async {
        await _room(
          tester,
          mode: mode,
          history: [_entry('h1', 'لحظة'), _entry('h2', '.')],
        );
        expect(_notice, findsOneWidget);
        final list = tester.getRect(_list);
        // The newest line (the rules line) sits at the bottom of the chat.
        expect(tester.getRect(_notice).bottom, closeTo(list.bottom, 1.5));
        expect(
          tester.getRect(_line('m:h2')).bottom,
          lessThanOrEqualTo(tester.getRect(_notice).top + 0.5),
        );
        // No fade unless there is more above the top edge (the podcast's
        // small box may overflow): never a short chat's lines.
        final more = _position(tester).maxScrollExtent > 0.5;
        expect(_fading(tester), more);
        if (mode != LiveRoomMode.podcast) expect(more, isFalse);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });
    }

    testWidgets('solo video: a message written during the visit sits at the '
        'BOTTOM (just above the quick replies), whole, not faded — the '
        "device's top-anchored half-faded line", (tester) async {
      final (engine, _) = await _room(tester);
      engine.chat
        ..add(LiveChatReceived(_entry('m1', 'لحظة')))
        ..add(LiveChatReceived(_entry('m2', '.')));
      await _frames(tester);
      // D236: the rules line stays, risen above the new lines like any line.
      expect(_notice, findsOneWidget);
      final list = tester.getRect(_list);
      expect(tester.getRect(_line('m:m2')).bottom, closeTo(list.bottom, 1));
      expect(
        tester.getRect(_line('m:m1')).bottom,
        closeTo(tester.getRect(_line('m:m2')).top, 1),
      );
      expect(
        tester.getRect(_line('n:rules')).bottom,
        closeTo(tester.getRect(_line('m:m1')).top, 1),
      );
      // The chat hugs its lines from the bottom: nothing empty above them.
      expect(tester.getRect(_line('n:rules')).top, closeTo(list.top, 1));
      expect(_fading(tester), isFalse);
      await _leave(tester);
    });
  });

  group('3. a message: the name, the badges under it, the message under '
      'them', () {
    for (final (viewport, scale) in [
      (GoldenViewport.phone, 1.0),
      (GoldenViewport.android, 1.3),
    ]) {
      testWidgets('${viewport.name} ×$scale, many badges, a long name and a '
          'long message: no overflow, one flowing boxed line (D257)', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (engine, _) = await _room(tester, viewport: viewport);
        engine.chat.add(
          LiveChatReceived(
            _entry(
              'm1',
              'أهلاً بكم جميعاً في البث، شكراً على الدعم والهدايا والمتابعة '
                  'الجميلة الليلة',
              role: LiveChatRole.host,
              author: const UserSummary(
                id: 'u-long',
                username: 'longname',
                displayName: 'عبدالرحمن الكبير Star 2026',
                avatarUrl: null,
              ),
              badges: const LiveChatAuthorBadges(
                charmLevel: 32,
                supportLevel: 27,
                family: LiveChatAuthorFamily(name: 'black', level: 7),
                newcomer: true,
              ),
            ),
          ),
        );
        await _frames(tester);
        expect(tester.takeException(), isNull);
        // D257 (the viewer's reference; supersedes D230/D234's three
        // stacked lines on the video live): one boxed line — the host's
        // orange tag, the name, the badges, «:» and the text, wrapping under
        // the start; nothing overflows.
        Rect inLine(Key key) => tester.getRect(
          find.descendant(of: _line('m:m1'), matching: find.byKey(key)),
        );
        final row = inLine(LiveChatInlineRow.rowKey);
        final tag = inLine(LiveChatFlatLine.tagKey);
        final name = inLine(LiveChatFlatLine.nameKey);
        expect(row.contains(tag.center), isTrue);
        expect(row.contains(name.center), isTrue);
        expect(
          find.descendant(
            of: _line('m:m1'),
            matching: find.byKey(LiveChatBadgeRow.charmKey),
          ),
          findsOneWidget,
        );
        // Arabic: D269 (owner) — the role tag starts the line at the right,
        // the name after it.
        expect(tag.right, closeTo(row.right - 10, 1));
        expect(name.right, lessThanOrEqualTo(tag.left));
        expect(tag.overlaps(name), isFalse);
        await _leave(tester);
      });
    }
  });

  group('4. dragging back to older lines', () {
    Future<FakeLiveMediaEngine> many(WidgetTester tester) async {
      final (engine, _) = await _room(
        tester,
        history: [for (var i = 0; i < 20; i++) _entry('h$i', 'old message $i')],
      );
      return engine;
    }

    testWidgets('many lines: the top edge fades; a drag down reveals the '
        'oldest; the stage under the chat gets no taps', (tester) async {
      await many(tester);
      // A tap on the video (outside the chat) cheers the host…
      await tester.tap(find.byKey(LiveTapLayer.tapKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LiveTapCharacter), findsWidgets);
      await tester.pumpAndSettle();
      expect(_fading(tester), isTrue);
      final list = tester.getRect(_list);
      // The oldest line is above the chat's top.
      expect(tester.getRect(_line('m:h0')).bottom, lessThan(list.top + 1));
      await tester.drag(_list, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(tester.getRect(_line('m:h0')).top, closeTo(list.top, 1));
      // At the oldest: nothing more above, no fade.
      expect(_fading(tester), isFalse);
      // …but dragging and tapping the chat never does (a line's tap opens
      // its own actions).
      expect(find.byType(LiveTapCharacter), findsNothing);
      await tester.tapAt(tester.getRect(_list).center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LiveTapCharacter), findsNothing);
      await tester.pumpAndSettle();
      await _leave(tester);
    });

    testWidgets('scrolled up: a new message keeps the reader where they are '
        'and shows «رسائل جديدة ↓»; the pill jumps back to the newest', (
      tester,
    ) async {
      final engine = await many(tester);
      await tester.drag(_list, const Offset(0, 200));
      await tester.pumpAndSettle();
      final before = tester.getRect(_line('m:h10')).top;
      expect(find.byKey(LiveChatScroll.newMessagesKey), findsNothing);
      engine.chat.add(LiveChatReceived(_entry('n1', 'new one')));
      await _frames(tester);
      expect(tester.getRect(_line('m:h10')).top, closeTo(before, 1));
      expect(find.byKey(LiveChatScroll.newMessagesKey), findsOneWidget);
      expect(find.text('رسائل جديدة ↓'), findsOneWidget);
      await tester.tap(find.byKey(LiveChatScroll.newMessagesKey));
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
      expect(
        tester.getRect(_line('m:n1')).bottom,
        closeTo(tester.getRect(_list).bottom, 1),
      );
      expect(find.byKey(LiveChatScroll.newMessagesKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('at the newest: a new message comes in at the bottom (no '
        'pill)', (tester) async {
      final engine = await many(tester);
      engine.chat.add(LiveChatReceived(_entry('n1', 'new one')));
      await _frames(tester);
      expect(
        tester.getRect(_line('m:n1')).bottom,
        closeTo(tester.getRect(_list).bottom, 1),
      );
      expect(find.byKey(LiveChatScroll.newMessagesKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('audio room: the chat drags back too', (tester) async {
      final (engine, _) = await _room(
        tester,
        mode: LiveRoomMode.audio,
        history: [for (var i = 0; i < 12; i++) _entry('h$i', 'old $i')],
      );
      expect(find.byKey(LiveChatScroll.scrollKey), findsOneWidget);
      final list = tester.getRect(_list);
      expect(tester.getRect(_line('m:h0')).bottom, lessThan(list.top + 1));
      await tester.drag(_list, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(tester.getRect(_line('m:h0')).top, greaterThan(list.top - 1));
      engine.chat.add(LiveChatReceived(_entry('n1', 'new')));
      await _frames(tester);
      expect(find.byKey(LiveChatScroll.newMessagesKey), findsOneWidget);
      await _leave(tester);
    });
  });
}
