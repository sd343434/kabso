// D379 (v1.132-social, CONVENTIONS §10.169): the VIP perks inside live
// rooms in the app — the data messages and shapes it reads, the room's VIP
// state (pin, greeting, rain), the strip's hold, and the widgets: the pin
// bar, the greeting card, the crown, the rain (never under reduced motion or
// «إخفاء المؤثرات»), the lock badge and sheet, the VIP room picker, the VIP
// seat-emoji row and the host's «احجز لصديق».

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/application/live_vip_room.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_vip_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_global_strip_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_vip_perks.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../fixtures/vip/vip_live_d379_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      currentUserProvider.overrideWithValue(testUser()),
      liveVipRepositoryProvider.overrideWithValue(_NoPinRepository()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

class _NoPinRepository implements LiveVipRepository {
  final List<String> pinned = [];
  int unpinned = 0;

  @override
  Future<LiveChatPin?> currentPin(String roomId) async => null;

  @override
  Future<LiveChatPin> pin(String roomId, String messageId) async {
    pinned.add(messageId);
    return LiveChatPin.fromJson(d379PinJson(message: messageId));
  }

  @override
  Future<void> unpin(String roomId) async => unpinned++;

  @override
  Future<LiveSeats> reserveSeat(String roomId, int index, String username) =>
      throw UnimplementedError();

  @override
  Future<LiveSeats> releaseSeat(String roomId, int index) =>
      throw UnimplementedError();
}

/// [child] in a localized app with the D379 VIP catalogue and the caller's
/// perks.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.en,
  bool reduced = false,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        vipCatalogProvider.overrideWith((ref) async => d379Catalog),
        if (overrides.isEmpty)
          myVipLivePerksProvider.overrideWith((ref) async => d379MyPerks),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
        locale: language.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: app!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => vipImageFor = (src) => MemoryImage(d379ArtFor(src)));
  tearDown(() => vipImageFor = NetworkImage.new);

  group('data messages and shapes (v1.132-social)', () {
    test('chat-pin, chat-unpin, vip-rain and the join hostGreeting', () {
      final pin = LiveChatEvent.parse({
        'type': 'chat-pin',
        'pin': d379PinJson(),
      });
      expect(pin, isA<LiveChatPinned>());
      final p = (pin! as LiveChatPinned).pin;
      expect(p.text, 'أهلاً بالجميع');
      expect(p.length, const Duration(seconds: 30));
      expect(
        (LiveChatEvent.parse({'type': 'chat-unpin', 'id': 'pin-1'})!
                as LiveChatUnpinned)
            .id,
        'pin-1',
      );
      final rain =
          LiveChatEvent.parse({'type': 'vip-rain', 'rain': d379RainJson()})!
              as VipGiftRainReceived;
      expect(rain.rain.totalCoins, 5000);
      expect(rain.rain.duration, const Duration(seconds: 4));
      final join =
          LiveChatEvent.parse({
                'type': 'join',
                'user': d379UserJson('u-a', 'A'),
                'cp': null,
                'gender': null,
                'hostGreeting': true,
              })!
              as LiveChatJoined;
      expect(join.hostGreeting, isTrue);
      // An older server sends no hostGreeting.
      final old =
          LiveChatEvent.parse({'type': 'join', 'user': d379UserJson('u', 'U')})!
              as LiveChatJoined;
      expect(old.hostGreeting, isFalse);
    });

    test(
      'the strip hold, the seat emoji file, the room lock and a kept seat',
      () {
        final tick = LiveChatEvent.parse({
          'type': 'gift-ticker',
          'kind': 'GIFT',
          'holdSeconds': 5,
          'gift': liveGiftJson(id: 'g-1', roomId: 'room-a'),
          'room': {
            'id': 'room-a',
            'title': 'Party',
            'host': d379UserJson('u-h', 'H'),
          },
        }) as GiftTickerReceived?;
        expect(tick, isNotNull);
        expect(tick!.ticker.holdSeconds, 5);
        expect(GiftStrip(tick.ticker).hold, const Duration(seconds: 5));
        final emoji =
            LiveChatEvent.parse({
                  'type': 'seat-emoji',
                  'id': 'e-1',
                  'seat': 2,
                  'user': d379UserJson('u-a', 'A'),
                  'token': ':vip_1:',
                  'vipArt': d379EmojiUrl,
                  'createdAt': '2026-11-12T09:30:00.000Z',
                })!
                as LiveSeatEmojiReceived;
        expect(emoji.emoji.vipArt, d379EmojiUrl);
        final seat = LiveSeat.fromJson({
          'index': 2,
          'state': 'LOCKED',
          'user': null,
          'mutedByHost': false,
          'reservation': {
            'user': d379UserJson('u-f', 'Friend'),
            'until': '2026-11-12T09:40:00.000Z',
          },
        });
        expect(seat.reservation?.user.displayName, 'Friend');
        expect(
          LiveVipMinTier.tryParse({
            'code': 'VIP_2',
            'name': 'VIP 2',
            'color': '#1E6FD9',
          })?.code,
          'VIP_2',
        );
        expect(VipLivePerks.seatEmojiToken(3), ':vip_3:');
        expect(VipLivePerks.artPack([d379EmojiUrl, 'http://x', 4]), [
          d379EmojiUrl,
        ]);
      },
    );

    test('a held strip stays longer in the middle', () {
      final plain = LiveGlobalStripBar.at(
        const Duration(milliseconds: 3000),
        rtl: false,
        still: false,
      );
      final held = LiveGlobalStripBar.at(
        const Duration(milliseconds: 3000),
        rtl: false,
        still: false,
        hold: const Duration(seconds: 5),
      );
      expect(plain.shift, isNot(0));
      expect(held.shift, 0);
      expect(held.opacity, 1);
    });

    test('the new error codes map to their messages', () {
      expect(ErrorCode.fromWire('LIVE_VIP_ONLY'), ErrorCode.liveVipOnly);
      expect(ErrorCode.fromWire('LIVE_PIN_BUSY'), ErrorCode.livePinBusy);
    });
  });

  group('LiveVipRoom (pin, greeting, rain)', () {
    testWidgets(
      'a pin shows, then goes on chat-unpin, its chat-delete or its time',
      (tester) async {
        {
          final c = _container();
          final vip = c.read(liveVipRoomProvider('room-a').notifier);
          c.listen(liveVipRoomProvider('room-a'), (_, _) {});
          LiveChatPin pinOf(String id, String message) =>
              LiveChatPin.fromJson(d379PinJson(id: id, message: message));
          vip.onEvent(LiveChatPinned(pinOf('p1', 'm1')));
          expect(c.read(liveVipRoomProvider('room-a')).pin?.id, 'p1');
          vip.onEvent(const LiveChatUnpinned('other'));
          expect(c.read(liveVipRoomProvider('room-a')).pin?.id, 'p1');
          vip.onEvent(const LiveChatUnpinned('p1'));
          expect(c.read(liveVipRoomProvider('room-a')).pin, isNull);
          vip
            ..onEvent(LiveChatPinned(pinOf('p2', 'm2')))
            ..onEvent(const LiveChatDeleted('m2'));
          expect(c.read(liveVipRoomProvider('room-a')).pin, isNull);
          vip.onEvent(LiveChatPinned(pinOf('p3', 'm3')));
          await tester.pump(const Duration(seconds: 29));
          expect(c.read(liveVipRoomProvider('room-a')).pin?.id, 'p3');
          await tester.pump(const Duration(seconds: 2));
          expect(c.read(liveVipRoomProvider('room-a')).pin, isNull);
          // Another room's pin is not this room's.
          vip.onEvent(
            LiveChatPinned(
              LiveChatPin.fromJson(d379PinJson(id: 'x', room: 'room-b')),
            ),
          );
          expect(c.read(liveVipRoomProvider('room-a')).pin, isNull);
        }
      },
    );

    testWidgets(
      'the greeting card comes only for a holder, then goes by itself',
      (tester) async {
        {
          final c = _container();
          final vip = c.read(liveVipRoomProvider('room-a').notifier);
          c.listen(liveVipRoomProvider('room-a'), (_, _) {});
          vip.onEvent(LiveChatJoined(d379User('u-plain', 'Plain')));
          expect(c.read(liveVipRoomProvider('room-a')).greeting, isNull);
          vip.onEvent(
            LiveChatJoined(
              d379User('u-vip', 'Vip', vip: d379Vip2),
              hostGreeting: true,
            ),
          );
          expect(c.read(liveVipRoomProvider('room-a')).greeting?.id, 'u-vip');
          await tester.pump(LiveVipRoom.greetingTime);
          expect(c.read(liveVipRoomProvider('room-a')).greeting, isNull);
        }
      },
    );

    testWidgets('a rain plays once per gift for its duration', (tester) async {
      {
        final c = _container();
        final vip = c.read(liveVipRoomProvider('room-a').notifier);
        c.listen(liveVipRoomProvider('room-a'), (_, _) {});
        final rain = VipGiftRain.fromJson(d379RainJson());
        vip.onEvent(VipGiftRainReceived(rain));
        expect(c.read(liveVipRoomProvider('room-a')).rain?.giftId, 'g-1');
        await tester.pump(const Duration(seconds: 4));
        expect(c.read(liveVipRoomProvider('room-a')).rain, isNull);
        vip.onEvent(VipGiftRainReceived(rain));
        expect(c.read(liveVipRoomProvider('room-a')).rain, isNull);
      }
    });

    test("pinning one's own message calls the API and shows the pin", () async {
      final repo = _NoPinRepository();
      final c = ProviderContainer(
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
          currentUserProvider.overrideWithValue(testUser()),
          liveVipRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      c.listen(liveVipRoomProvider('room-a'), (_, _) {});
      final entry = LiveChatEntry(
        id: 'm-9',
        roomId: 'room-a',
        author: d379User('u-me', 'Me'),
        authorRole: LiveChatRole.viewer,
        text: 'hi',
        createdAt: d379Now,
      );
      final vip = c.read(liveVipRoomProvider('room-a').notifier);
      expect(await vip.pin(entry), isNull);
      expect(repo.pinned, ['m-9']);
      expect(c.read(liveVipRoomProvider('room-a')).pin?.messageId, 'm-9');
      expect(await vip.unpin(), isNull);
      expect(repo.unpinned, 1);
      expect(c.read(liveVipRoomProvider('room-a')).pin, isNull);
    });
  });

  group('LiveVipRepositoryImpl', () {
    test('paths and bodies of the four operations', () async {
      final http = FakeHttpAdapter()
        ..on(
          'POST',
          '/live/rooms/room-a/chat-pin',
          (_) => FakeResponse(201, body: d379PinJson()),
        )
        ..on(
          'DELETE',
          '/live/rooms/room-a/chat-pin',
          (_) => const FakeResponse.noContent(),
        )
        ..on(
          'GET',
          '/live/rooms/room-a/chat',
          (_) => FakeResponse(
            200,
            body: {'data': <Object>[], 'pin': d379PinJson()},
          ),
        );
      final repo = LiveVipRepositoryImpl(Dio()..httpClientAdapter = http);
      expect((await repo.currentPin('room-a'))?.id, 'pin-1');
      expect((await repo.pin('room-a', 'm-1')).messageId, 'm-1');
      expect(
        http.requestsTo('POST', '/live/rooms/room-a/chat-pin').single.data,
        {'messageId': 'm-1'},
      );
      await repo.unpin('room-a');
      expect(
        http.requestsTo('DELETE', '/live/rooms/room-a/chat-pin'),
        hasLength(1),
      );
    });

    test('LIVE_PIN_BUSY reaches the caller with its Retry-After', () async {
      final http = FakeHttpAdapter()
        ..on(
          'POST',
          '/live/rooms/room-a/chat-pin',
          (_) => FakeResponse(
            409,
            body: errorEnvelope('LIVE_PIN_BUSY', 'busy'),
            headers: {
              'retry-after': ['20'],
            },
          ),
        );
      final repo = LiveVipRepositoryImpl(Dio()..httpClientAdapter = http);
      await expectLater(
        repo.pin('room-a', 'm-1'),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.code, 'code', ErrorCode.livePinBusy)
              .having(
                (f) => f.retryAfter,
                'retryAfter',
                const Duration(seconds: 20),
              ),
        ),
      );
    });
  });

  group('widgets', () {
    testWidgets('the pin bar: author, text, «إزالة» only with onRemove', (
      tester,
    ) async {
      var removed = 0;
      final pin = LiveChatPin.fromJson(d379PinJson());
      await _pump(
        tester,
        LiveVipPinBar(
          pin: pin,
          left: const Duration(seconds: 30),
          onRemove: () => removed++,
        ),
        language: AppLanguage.ar,
      );
      expect(find.text('مثبتة · Sara'), findsOneWidget);
      expect(find.text('أهلاً بالجميع'), findsOneWidget);
      await tester.tap(find.byKey(LiveVipPinBar.removeKey));
      expect(removed, 1);
      await _pump(
        tester,
        LiveVipPinBar(pin: pin, left: const Duration(seconds: 30)),
      );
      expect(find.byKey(LiveVipPinBar.removeKey), findsNothing);
    });

    testWidgets('the greeting card names the level and greets in one tap', (
      tester,
    ) async {
      var greeted = 0;
      await _pump(
        tester,
        LiveVipGreetingCard(
          user: d379User('u-vip', 'Layan', vip: d379Vip2),
          onGreet: () => greeted++,
          onClose: () {},
        ),
        language: AppLanguage.ar,
      );
      expect(find.text('VIP 2 دخل البث'), findsOneWidget);
      await tester.tap(find.byKey(LiveVipGreetingCard.greetKey));
      expect(greeted, 1);
    });

    testWidgets('the crown shows for a holder only', (tester) async {
      await _pump(
        tester,
        const Row(
          children: [
            LiveVipSeatCrown(key: Key('a'), vip: d379Vip2, picture: 50),
            LiveVipSeatCrown(key: Key('b'), vip: null, picture: 50),
          ],
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('a')),
          matching: find.byType(VipAnimatedArt),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('b')),
          matching: find.byType(VipAnimatedArt),
        ),
        findsNothing,
      );
    });

    for (final (name, reduced, hidden, shows) in [
      ('plays', false, false, true),
      ('not under reduced motion', true, false, false),
      ('not with the effects hidden', false, true, false),
    ]) {
      testWidgets('the rain: $name', (tester) async {
        final prefs = await testPrefs();
        final room = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
            safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
            currentUserProvider.overrideWithValue(testUser()),
            liveVipRepositoryProvider.overrideWithValue(_NoPinRepository()),
            liveViewerPrefsProvider.overrideWith(() => _Prefs(hidden: hidden)),
          ],
        );
        addTearDown(room.dispose);
        room
          ..listen(liveVipRoomProvider('room-a'), (_, _) {})
          ..read(
            liveVipRoomProvider('room-a').notifier,
          ).onEvent(VipGiftRainReceived(VipGiftRain.fromJson(d379RainJson())));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: room,
            child: MaterialApp(
              builder: (context, app) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: app!,
              ),
              home: const LiveVipGiftRainLayer(roomId: 'room-a'),
            ),
          ),
        );
        expect(
          find.byType(LiveVipCoinRain),
          shows ? findsOneWidget : findsNothing,
        );
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(LiveVipCoinRain), findsNothing);
      });
    }

    testWidgets('the lock badge and sheet name the tier', (tester) async {
      const tier = LiveVipMinTier(
        code: 'VIP_2',
        name: 'VIP 2',
        color: '#1E6FD9',
      );
      await _pump(
        tester,
        const LiveVipRoomBadge(tier: tier),
        language: AppLanguage.ar,
      );
      expect(find.text('VIP 2'), findsOneWidget);
      await _pump(
        tester,
        const LiveVipLockSheet(tierName: 'VIP 2'),
        language: AppLanguage.ar,
      );
      expect(find.text('هذه الغرفة لأعضاء VIP 2 فما فوق'), findsOneWidget);
      expect(find.text('غرفة VIP خاصة'), findsOneWidget);
    });

    testWidgets("the VIP room picker: tiers up to the perk's cap", (
      tester,
    ) async {
      String? chosen = 'none';
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: LiveVipRoomPicker(value: null, onChanged: (c) => chosen = c),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(LiveVipRoomPicker.switchKey));
      expect(chosen, 'VIP_1');
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: LiveVipRoomPicker(
            value: 'VIP_1',
            onChanged: (c) => chosen = c,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('vipRoom.tier.VIP_2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vipRoom.tier.VIP_2')));
      expect(chosen, 'VIP_2');
    });

    testWidgets('no VIP_ROOM perk: no picker', (tester) async {
      await _pump(
        tester,
        LiveVipRoomPicker(value: null, onChanged: (_) {}),
        overrides: [myVipLivePerksProvider.overrideWith((ref) async => {})],
      );
      await tester.pump();
      expect(find.byKey(LiveVipRoomPicker.switchKey), findsNothing);
    });

    testWidgets("the VIP seat-emoji row: the holder's pack, n from 1", (
      tester,
    ) async {
      final picks = <int>[];
      await _pump(tester, LiveVipSeatEmojiRow(onPick: (n, _) => picks.add(n)));
      await tester.pump();
      await tester.tap(find.byKey(LiveVipSeatEmojiRow.keyFor(2)));
      expect(picks, [2]);
    });

    testWidgets(
      "the host's empty seat offers «احجز لصديق»; a kept one «إلغاء الحجز»",
      (tester) async {
        var reserved = 0;
        var released = 0;
        Future<void> open(LiveSeat seat) async {
          await _pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  showSeatActions(
                    context,
                    seat: seat,
                    isHost: true,
                    moderators: const [],
                    onMute: ({required muted}) async {},
                    onRemove: () async {},
                    onLock: ({required locked}) async {},
                    onModerator: (_, {required moderator}) async {},
                    onReserve: () async => reserved++,
                    onRelease: () async => released++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
            language: AppLanguage.ar,
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
        }

        await open(
          const LiveSeat(index: 2, state: LiveSeatState.empty, user: null),
        );
        expect(find.text('احجز لصديق'), findsOneWidget);
        await tester.tap(find.byKey(SeatControlKeys.reserve));
        await tester.pumpAndSettle();
        expect(reserved, 1);
        await open(
          LiveSeat(
            index: 2,
            state: LiveSeatState.locked,
            user: null,
            reservation: LiveSeatReservation(
              user: d379User('u-f', 'Friend'),
              until: d379Now,
            ),
          ),
        );
        expect(find.text('إلغاء الحجز'), findsOneWidget);
        await tester.tap(find.byKey(SeatControlKeys.release));
        await tester.pumpAndSettle();
        expect(released, 1);
      },
    );

    testWidgets('the failure messages of the new codes', (tester) async {
      late AppLocalizations l10n;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            l10n = context.l10n;
            return const SizedBox();
          },
        ),
        language: AppLanguage.ar,
      );
      expect(
        failureMessage(
          l10n,
          const ServerFailure(
            statusCode: 403,
            code: ErrorCode.liveVipOnly,
            rawCode: 'LIVE_VIP_ONLY',
            debugMessage: 'vip',
          ),
        ),
        l10n.errorLiveVipOnly,
      );
      expect(
        failureMessage(
          l10n,
          const ServerFailure(
            statusCode: 409,
            code: ErrorCode.livePinBusy,
            rawCode: 'LIVE_PIN_BUSY',
            debugMessage: 'busy',
          ),
        ),
        l10n.errorLivePinBusy,
      );
    });
  });
}

class _Prefs extends LiveViewerPrefsController {
  new({required this.hidden});

  final bool hidden;

  @override
  LiveViewerPrefs build() => super.build().copyWith(giftEffectsHidden: hidden);
}
