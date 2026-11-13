// D305 (owner: «هذا شريط الهدايا والآخر شريط الألعاب، يظهر في جميع الغرف من
// الجانب الى المنتصف ويخرج من الجهة الأخرى، ويبقى في المنتصف ثانيتين»; then
// «يمكن للمستخدم الغاء شريط الهدايا من اعدادات اي غرفة وايضاً الغاء شريط
// الألعاب»): the global strips on the owner's art — the `gift-ticker` /
// `game-win-ticker` messages (v1.85-live) parsed; one strip at a time, the
// newest first, at most 3 waiting, none older than 30 s, this live's own too;
// the timeline (in from the reading start → 2 s in the middle → out by the
// other side; fades with reduced motion); long names; a tap; the per-account
// switches in the live's settings sheet; goldens of both strips mid-hold over
// the viewer's live (393 × 852, ar / en) and of the settings rows.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_settings_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_global_strip_bar.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_notifications_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _userJson(String id, String name) => {
  'id': id,
  'username': id,
  'displayName': name,
  'avatarUrl': null,
};

UserSummary _user(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

GiftTicker _gift({
  String id = 'g1',
  String room = 'room-b',
  String sender = 'Nour',
  String receiver = 'Sara',
  int quantity = 1,
  String senderId = 'u-nour',
}) => GiftTicker(
  gift: LiveGift.fromJson({
    ...liveGiftJson(
      id: id,
      roomId: room,
      quantity: quantity,
      sender: _userJson(senderId, sender),
      recipients: [_userJson('u-sara', receiver)],
    ),
  }),
  room: LuckyTickerRoom(id: room, title: 'Party', host: _user('u-h', 'Host')),
);

GameWinTicker _game({
  String id = 'w1',
  String? room = 'room-b',
  String winner = 'Omar',
  int tickets = 1500000,
}) => GameWinTicker(
  id: id,
  game: const StripGame(code: 'wheel', name: 'Wheel'),
  winner: _user('u-omar', winner),
  tickets: tickets,
  createdAt: DateTime.utc(2026, 11, 7, 12),
  room: room == null
      ? null
      : LuckyTickerRoom(id: room, title: 'Party', host: _user('u-h', 'Host')),
);

Map<String, Object?> _gameJson({Object? room = 'room-b'}) => {
  'type': 'game-win-ticker',
  'kind': 'GAME_WIN',
  'win': {
    'id': 'w9',
    'game': {'code': 'wheel', 'name': 'Wheel', 'imageUrl': null},
    'winner': _userJson('u-omar', 'Omar'),
    'tickets': 1000000,
    'roomId': room,
    'createdAt': '2026-11-07T12:00:00.000Z',
  },
  'room': room == null
      ? null
      : {'id': room, 'title': 'Party', 'host': _userJson('u-h', 'Host')},
};

ProviderContainer _container({
  List<UserSummary> blocked = const [],
  FakeNotificationsRepository? notifications,
}) {
  final c = ProviderContainer(
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      safetyRepositoryProvider.overrideWithValue(
        FakeSafetyRepository(blockedUsers: [...blocked]),
      ),
      notificationsRepositoryProvider.overrideWithValue(
        notifications ?? FakeNotificationsRepository(),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// The strip of live `room-a` alone, centred 160 pt down a dark screen.
Future<ProviderContainer> _pumpBar(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  ValueChanged<String>? onOpenRoom,
  ValueChanged<UserSummary>? onPerson,
  bool reduced = false,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: LiveGlobalStripLanes(
              roomId: 'room-a',
              onOpenRoom: onOpenRoom,
              onPerson: onPerson,
            ),
          ),
        ],
      ),
    ),
    language: language,
    disableAnimations: reduced,
    liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(LiveGlobalStripLanes)),
  );
}

Finder _lane(StripLane lane) => find.byKey(LiveGlobalStripBar.laneKey(lane));

/// The strip on screen (either lane; the tests show one at a time unless
/// they name a lane).
Finder get _strip => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('global.strip.'),
);

GlobalStrip? _on(ProviderContainer c, StripLane lane) =>
    LiveGlobalStrips.of(c.read(liveGlobalStripsProvider('room-a')), lane);

double _x(WidgetTester tester) => tester.getCenter(_strip).dx;

double _opacity(WidgetTester tester, [Finder? strip]) => tester
    .widget<Opacity>(
      find.ancestor(of: strip ?? _strip, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// Decodes the strip's pictures (the art, the gift, the ticket) without
/// letting its time run (no pumpAndSettle).
Future<void> _precacheStrip(WidgetTester tester) async {
  // Twice: a picture that fails brings its fallback (the gift box).
  for (var pass = 0; pass < 2; pass++) {
    final images = find
        .descendant(of: _strip, matching: find.byType(Image))
        .evaluate()
        .toList();
    await tester.runAsync(() async {
      for (final e in images) {
        await precacheImage((e.widget as Image).image, e, onError: (_, _) {});
      }
    });
    await tester.pump();
  }
}

/// Lets every timer run out.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(LiveGlobalStrips.showTime * 5);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() => LiveGlobalStrips.now = DateTime.now);

  test(
    'the messages parse: `gift-ticker` (kind GIFT) and `game-win-ticker` '
    '(kind GAME_WIN, with or without a live); malformed ones are ignored',
    () {
      final gift = LiveChatEvent.parse({
        'type': 'gift-ticker',
        'kind': 'GIFT',
        'gift': liveGiftJson(id: 'g7', roomId: 'room-b'),
        'room': {'id': 'room-b', 'title': 'Party', 'host': _userJson('h', 'H')},
      });
      expect(gift, isA<GiftTickerReceived>());
      expect((gift! as GiftTickerReceived).ticker.gift.id, 'g7');
      final game = LiveChatEvent.parse(_gameJson());
      expect(game, isA<GameWinTickerReceived>());
      final t = (game! as GameWinTickerReceived).ticker;
      expect(t.id, 'w9');
      expect(t.game.name, 'Wheel');
      expect(t.game.imageUrl, isNull);
      expect(t.winner.displayName, 'Omar');
      expect(t.tickets, 1000000);
      expect(t.room?.id, 'room-b');
      final outside = LiveChatEvent.parse(_gameJson(room: null));
      expect((outside! as GameWinTickerReceived).ticker.room, isNull);
      expect(LiveChatEvent.parse({'type': 'game-win-ticker'}), isNull);
      expect(
        LiveChatEvent.parse({
          ..._gameJson(),
          'win': {'id': 'x'},
        }),
        isNull,
      );
    },
  );

  test('two lanes (D305b): each one at a time, the newest first, at most 3 '
      'waiting, none older than 30 s; its own live too; repeats and blocked '
      'people skipped', () async {
    final c = _container(blocked: [_user('u-bad', 'Bad')]);
    final engine = FakeLiveMediaEngine();
    c.listen(liveChatProvider('room-a'), (_, _) {});
    await c
        .read(liveChatProvider('room-a').notifier)
        .attach(engine, enabled: true, muted: false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final strips = c.read(liveGlobalStripsProvider('room-a').notifier);
    c.listen(liveGlobalStripsProvider('room-a'), (_, _) {});
    var clock = DateTime(2026, 11, 7, 12);
    LiveGlobalStrips.now = () => clock;
    strips
      ..attach(engine)
      ..show(GiftStrip(_gift(id: 'bad', senderId: 'u-bad', sender: 'Bad')));
    expect(_on(c, StripLane.gifts), isNull);
    // This very live: shown too (owner «في جميع الغرف»).
    engine.chat.add(GiftTickerReceived(_gift(id: 'own', room: 'room-a')));
    await Future<void>.delayed(Duration.zero);
    expect(_on(c, StripLane.gifts)?.key, 'gift.own');
    // A game win at the same time: its own lane, at once.
    engine.chat.add(GameWinTickerReceived(_game()));
    await Future<void>.delayed(Duration.zero);
    expect(_on(c, StripLane.games)?.key, 'game.w1');
    expect(_on(c, StripLane.gifts)?.key, 'gift.own');
    strips
      ..show(GiftStrip(_gift(id: 'own', room: 'room-a'))) // a repeat
      ..show(GiftStrip(_gift(id: 'g2')))
      ..show(GameWinStrip(_game(id: 'w2')))
      ..show(GiftStrip(_gift(id: 'g3')))
      ..show(GiftStrip(_gift(id: 'g4')))
      ..show(GiftStrip(_gift(id: 'g5')));
    String? next(StripLane lane) {
      strips.dismiss(lane);
      return _on(c, lane)?.key;
    }

    // The gifts lane: newest first; it holds three (g2, the oldest, was
    // dropped); the games lane is not touched.
    expect(next(StripLane.gifts), 'gift.g5');
    expect(_on(c, StripLane.games)?.key, 'game.w1');
    expect(next(StripLane.gifts), 'gift.g4');
    expect(next(StripLane.gifts), 'gift.g3');
    expect(next(StripLane.gifts), isNull);
    expect(next(StripLane.games), 'game.w2');
    expect(next(StripLane.games), isNull);
    // A strip that waited more than 30 s is dropped.
    strips
      ..show(GiftStrip(_gift(id: 'g6')))
      ..show(GiftStrip(_gift(id: 'g7')));
    clock = clock.add(const Duration(seconds: 31));
    strips.show(GiftStrip(_gift(id: 'g8')));
    expect(next(StripLane.gifts), 'gift.g8');
    expect(next(StripLane.gifts), isNull);
    expect(LiveGlobalStrips.showTime, const Duration(milliseconds: 2900));
    expect(
      LiveGlobalStrips.enterTime +
          LiveGlobalStrips.holdTime +
          LiveGlobalStrips.exitTime,
      LiveGlobalStrips.showTime,
    );
    expect(LiveGlobalStrips.holdTime, const Duration(seconds: 2));
  });

  test('the account switches hide each kind on its own (and a shown strip '
      'of a kind switched off goes)', () async {
    final notifications = FakeNotificationsRepository();
    final c = _container(notifications: notifications)
      ..listen(liveGlobalStripsProvider('room-a'), (_, _) {});
    await c.read(notificationSettingsProvider.future);
    final strips = c.read(liveGlobalStripsProvider('room-a').notifier);
    final settings = c.read(notificationSettingsProvider.notifier);
    await settings.change(NotificationSetting.giftStrip, on: false);
    expect(c.read(globalStripPrefsProvider), (
      gifts: false,
      games: true,
      lucky: true,
    ));
    strips.show(GiftStrip(_gift()));
    expect(_on(c, StripLane.gifts), isNull);
    strips.show(GameWinStrip(_game()));
    expect(_on(c, StripLane.games)?.key, 'game.w1');
    await settings.change(NotificationSetting.gameStrip, on: false);
    await Future<void>.delayed(Duration.zero);
    expect(_on(c, StripLane.games), isNull);
    strips.show(GameWinStrip(_game(id: 'w2')));
    expect(_on(c, StripLane.games), isNull);
    await settings.change(NotificationSetting.giftStrip, on: true);
    strips.show(GiftStrip(_gift(id: 'g3')));
    expect(_on(c, StripLane.gifts)?.key, 'gift.g3');
    expect(notifications.calls, [
      'settings',
      'setting:giftStrip:false',
      'setting:gameStrip:false',
      'setting:giftStrip:true',
    ]);
    expect(notifications.current, const NotificationSettings(gameStrip: false));
  });

  test('a guest sees both strips (no settings asked)', () {
    final notifications = FakeNotificationsRepository();
    final c = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(notifications),
        currentUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(globalStripPrefsProvider), (
      gifts: true,
      games: true,
      lucky: true,
    ));
    expect(notifications.calls, isEmpty);
  });

  test('the timeline: in from the reading start, 2 s in the middle, out by '
      'the other side; reduced motion fades', () {
    ({double shift, double opacity}) at(int ms, {bool rtl = true}) =>
        LiveGlobalStripBar.at(
          Duration(milliseconds: ms),
          rtl: rtl,
          still: false,
        );
    expect(at(0).shift, 1); // Arabic: from the right
    expect(at(0, rtl: false).shift, -1); // English: from the left
    expect(at(200).shift, inExclusiveRange(0, 1));
    for (final ms in [450, 1000, 2450]) {
      expect(at(ms), (shift: 0.0, opacity: 1.0), reason: '$ms');
    }
    expect(at(2700).shift, inExclusiveRange(-1, 0)); // leaving to the left
    expect(at(2900).shift, -1);
    expect(at(2900, rtl: false).shift, 1);
    ({double shift, double opacity}) still(int ms) => LiveGlobalStripBar.at(
      Duration(milliseconds: ms),
      rtl: true,
      still: true,
    );
    expect(still(0), (shift: 0.0, opacity: 0.0));
    expect(still(450), (shift: 0.0, opacity: 1.0));
    expect(still(2450), (shift: 0.0, opacity: 1.0));
    expect(still(2900), (shift: 0.0, opacity: 0.0));
    expect(LiveGlobalStripBar.shortName('Nour'), 'Nour');
    expect(
      LiveGlobalStripBar.shortName('عبدالرحمن بن عبدالعزيز الكبير'),
      'عبدالرحمن بن …',
    );
  });

  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    testWidgets('the strip slides in to the middle, stays 2 s, slides out '
        '(${language.name})', (tester) async {
      final c = await _pumpBar(tester, language: language);
      final rtl = language == AppLanguage.ar;
      c
          .read(liveGlobalStripsProvider('room-a').notifier)
          .show(GiftStrip(_gift()));
      await tester.pump();
      // At its start: off-screen on the reading-start side.
      final start = _x(tester);
      expect(rtl ? start > 393 : start < 0, isTrue, reason: '$start');
      await tester.pump(const Duration(milliseconds: 200));
      final moving = _x(tester);
      expect(rtl ? moving < start : moving > start, isTrue);
      await tester.pump(const Duration(milliseconds: 260));
      expect(_x(tester), moreOrLessEquals(393 / 2, epsilon: 0.5));
      expect(
        tester.getSize(_strip),
        const Size(270, 270 * LiveGlobalStripBar.aspect),
      );
      await tester.pump(const Duration(milliseconds: 1980));
      expect(_x(tester), moreOrLessEquals(393 / 2, epsilon: 0.5));
      await tester.pump(const Duration(milliseconds: 250));
      final out = _x(tester);
      expect(rtl ? out < 393 / 2 : out > 393 / 2, isTrue, reason: '$out');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_strip, findsNothing);
      await _drain(tester);
    });
  }

  testWidgets('D305b: both lanes at once, each on its own timeline; the '
      'gifts lane keeps its place when alone', (tester) async {
    final c = await _pumpBar(tester);
    final strips = c.read(liveGlobalStripsProvider('room-a').notifier)
      ..show(GiftStrip(_gift()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    const h = 270 * LiveGlobalStripBar.aspect;
    // The gifts lane alone: under the (empty) games lane, not moved up.
    expect(_lane(StripLane.games), findsNothing);
    expect(
      tester.getRect(_lane(StripLane.gifts)).top,
      moreOrLessEquals(160 + h + LiveGlobalStripLanes.gap),
    );
    strips.show(GameWinStrip(_game()));
    await tester.pump();
    // The game strip enters while the gift strip holds in the middle.
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getCenter(_lane(StripLane.gifts)).dx,
      moreOrLessEquals(196.5),
    );
    expect(tester.getCenter(_lane(StripLane.games)).dx, lessThan(196.5));
    expect(tester.getRect(_lane(StripLane.games)).top, moreOrLessEquals(160));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getCenter(_lane(StripLane.games)).dx,
      moreOrLessEquals(196.5),
    );
    // The gift strip leaves at its own time (2.9 s after it came) …
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_lane(StripLane.gifts), findsNothing);
    expect(
      tester.getCenter(_lane(StripLane.games)).dx,
      moreOrLessEquals(196.5),
    );
    // … the game strip at its own.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_lane(StripLane.games), findsNothing);
    expect(LiveGlobalStripBar.maxWidth, 270);
    expect(LiveGlobalStripBar.fontSize, greaterThanOrEqualTo(11));
    await _drain(tester);
  });

  testWidgets('reduced motion: it fades in and out in the middle, 2 s in '
      'full', (tester) async {
    final c = await _pumpBar(tester, reduced: true);
    c
        .read(liveGlobalStripsProvider('room-a').notifier)
        .show(GameWinStrip(_game()));
    await tester.pump();
    expect(_x(tester), moreOrLessEquals(393 / 2));
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 460));
    expect(_opacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 1980));
    expect(_opacity(tester), 1);
    expect(_x(tester), moreOrLessEquals(393 / 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_x(tester), moreOrLessEquals(393 / 2));
    await _drain(tester);
  });

  testWidgets('the words: gift and game texts, gold names, the ticket after '
      'the amount; long names cut; no overflow at 360 × 800 × 1.3', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await _pumpBar(
      tester,
      viewport: GoldenViewport.android,
      reduced: true,
    );
    final strips = c.read(liveGlobalStripsProvider('room-a').notifier)
      ..show(
        GiftStrip(
          _gift(
            sender: 'Alexandria Montgomery-Smith',
            receiver: 'Bartholomew the Magnificent',
          ),
        ),
      );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_strip).width, 270);
    final en = l10nFor(AppLanguage.en);
    final label = en.liveStripGift(
      '\u2068Alexandria Mo…\u2069',
      '\u2068Bartholomew t…\u2069',
      '\u2068Rose\u2069',
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('globalStrip.gift.g1'))),
      isSemantics(label: label),
    );
    strips
      ..dismiss(StripLane.gifts)
      ..show(GameWinStrip(_game()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('globalStrip.game.w1'))),
      isSemantics(
        label: en.liveStripGameWin('\u2068Omar\u2069', '\u20681,500,000\u2069'),
      ),
    );
    final ticket = find.descendant(
      of: _strip,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.contains('kabso_ticket'),
      ),
    );
    expect(ticket, findsOneWidget);
    await _drain(tester);
  });

  testWidgets('a tap: another live opens it; its own live (or none) opens the '
      "person's card; only the strip takes taps", (tester) async {
    final opened = <String>[];
    final people = <String>[];
    final c = await _pumpBar(
      tester,
      onOpenRoom: opened.add,
      onPerson: (u) => people.add(u.id),
      reduced: true,
    );
    final strips = c.read(liveGlobalStripsProvider('room-a').notifier)
      ..show(GiftStrip(_gift()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // Beside the strip: not taken.
    await tester.tapAt(const Offset(196, 400));
    await tester.tap(_strip);
    await tester.pump();
    expect(opened, ['room-b']);
    expect(_strip, findsNothing);
    strips.show(GiftStrip(_gift(id: 'g2', room: 'room-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(_strip);
    expect(people, ['u-nour']);
    strips
      ..dismiss(StripLane.gifts)
      ..show(GameWinStrip(_game(room: null)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(_strip);
    expect(people, ['u-nour', 'u-omar']);
    expect(opened, ['room-b']);
    await _drain(tester);
  });

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    // D305b: the games lane under the header (the slot of the D178 strip,
    // 96 pt under the status bar), the gifts lane 4 pt under it; each kind
    // stays in its lane when alone.
    const h = 270 * LiveGlobalStripBar.aspect;
    const gamesTop = 59 + 96.0;
    const giftsTop = gamesTop + h + LiveGlobalStripLanes.gap;
    for (final kind in ['gift', 'game', 'both']) {
      testWidgets("golden: $kind mid-hold over the viewer's live, in its "
          'lane ($language)', (tester) async {
        final engine = await _pumpViewer(tester, language: language);
        if (kind != 'game') {
          engine.chat.add(
            GiftTickerReceived(
              _gift(
                sender: ar ? 'نور' : 'Nour',
                receiver: ar ? 'سارة' : 'Sara',
              ),
            ),
          );
        }
        if (kind != 'gift') {
          engine.chat.add(
            GameWinTickerReceived(
              _game(winner: ar ? 'عمر' : 'Omar', tickets: 1250000),
            ),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await _precacheStrip(tester);
        await tester.pump(const Duration(milliseconds: 1300));
        final gifts = _lane(StripLane.gifts);
        final games = _lane(StripLane.games);
        expect(gifts, kind == 'game' ? findsNothing : findsOneWidget);
        expect(games, kind == 'gift' ? findsNothing : findsOneWidget);
        if (kind != 'game') {
          final r = tester.getRect(gifts);
          expect(r.top, moreOrLessEquals(giftsTop, epsilon: 0.01));
          expect(r.center.dx, moreOrLessEquals(393 / 2));
          expect(r.width, 270);
          expect(_opacity(tester, gifts), 1);
        }
        if (kind != 'gift') {
          final r = tester.getRect(games);
          expect(r.top, moreOrLessEquals(gamesTop, epsilon: 0.01));
          expect(r.center.dx, moreOrLessEquals(393 / 2));
          expect(_opacity(tester, games), 1);
        }
        if (kind == 'both') {
          // No overlap.
          expect(
            tester.getRect(games).bottom,
            lessThanOrEqualTo(tester.getRect(gifts).top),
          );
        }
        await expectScreenGolden(
          'live_room.global_strip_$kind',
          language: language,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 10));
      }, tags: goldenTag);
    }

    testWidgets('the switches «إظهار شريط الهدايا» / «إظهار شريط الألعاب» and '
        "(D347) «إخفاء أشرطة الفوز» in the viewer's settings sheet: saved to "
        'the account ($language)', (tester) async {
      final notifications = FakeNotificationsRepository();
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        language: language,
        liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
        liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
        notificationsRepository: notifications,
        disableAnimations: true,
        overrides: [
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(
              room: (id) => apiRoom(id: id, ar: ar),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile(ar: ar)),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveRoomScreen.menuKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('goLive.tool.viewerSettings')),
      );
      await tester.pumpAndSettle();
      final l10n = l10nFor(language);
      final gifts = find.byKey(LiveSettingsSheet.itemKey('giftStrip'));
      final games = find.byKey(LiveSettingsSheet.itemKey('gameStrip'));
      await tester.scrollUntilVisible(
        games,
        60,
        scrollable: find.descendant(
          of: find.byKey(LiveSettingsSheet.sheetKey),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(gifts);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: gifts,
          matching: find.text(l10n.liveStripShowGifts),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: games,
          matching: find.text(l10n.liveStripShowGames),
        ),
        findsOneWidget,
      );
      bool on(Finder row) => tester
          .widget<Switch>(
            find.descendant(of: row, matching: find.byType(Switch)),
          )
          .value;
      expect(on(gifts), isTrue);
      expect(on(games), isTrue);
      await precacheImages(tester);
      await expectLater(
        find.byKey(LiveSettingsSheet.sheetKey),
        matchesGoldenFile(
          'png/live_settings.strip_switches.${language.name}.png',
        ),
      );
      await tester.tap(gifts);
      await tester.pumpAndSettle();
      expect(on(gifts), isFalse);
      expect(on(games), isTrue);
      expect(notifications.calls, contains('setting:giftStrip:false'));
      expect(notifications.current.giftStrip, isFalse);
      expect(notifications.current.gameStrip, isTrue);
      await tester.tap(games);
      await tester.pumpAndSettle();
      expect(notifications.current.gameStrip, isFalse);
      // D347 (owner «نعم موافق»): «إخفاء أشرطة الفوز» — off (shown) by
      // default; on hides the global lucky banner (luckyStrip false).
      final wins = find.byKey(LiveSettingsSheet.itemKey('luckyStrip'));
      await tester.ensureVisible(wins);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: wins, matching: find.text(l10n.liveStripHideWins)),
        findsOneWidget,
      );
      expect(on(wins), isFalse);
      await tester.tap(wins);
      await tester.pumpAndSettle();
      expect(on(wins), isTrue);
      expect(notifications.calls, contains('setting:luckyStrip:false'));
      expect(notifications.current.luckyStrip, isFalse);
      await expectLater(
        find.byKey(LiveSettingsSheet.sheetKey),
        matchesGoldenFile(
          'png/live_settings.hide_win_banners.${language.name}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    }, tags: goldenTag);
  });
}

/// The viewer's video live at the reference's size (393 × 852, 59 / 34
/// insets), as in D254's harness.
Future<FakeLiveMediaEngine> _pumpViewer(
  WidgetTester tester, {
  required AppLanguage language,
}) async {
  final ar = language == AppLanguage.ar;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final prefs = await testPrefs(language: language.name);
  late FakeLiveMediaEngine engine;
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            room: (id) => apiRoom(id: id, ar: ar),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(apiProfile(ar: ar)),
        ),
        liveGiftRepositoryProvider.overrideWithValue(
          FakeLiveGiftRepository(codes: giftFixtureCodes),
        ),
        notificationsRepositoryProvider.overrideWithValue(
          FakeNotificationsRepository(),
        ),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine()..present.add('user-0'),
        ),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: const LiveRoomScreen(roomId: 'room-0'),
    ),
    language: language,
    bare: true,
  );
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return engine;
}
