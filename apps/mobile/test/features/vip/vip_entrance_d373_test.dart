// D373 (owner 2026-11-11: «سيارات الدخول ستكون اما بشاشة كاملة او نصف
// الشاشة … من لوحة الادمن انت تحدد كيف ستكون الدخلة اما بشاشة كاملة او نصف
// شاشة»; v1.128-social, CONVENTIONS §10.165): an entry car plays as the
// panel set it — FULL_SCREEN over the whole live screen (D331, every car
// before D373 and every car an older server sends) or HALF_SCREEN in a
// full-width band about half the screen high, under the room's header and
// above the chat, the entrant's banner over it. Never takes taps; reduced
// motion and «إخفاء تأثيرات الدخول» as before.
//
// The cars are test-only stand-in art drawn here (no third-party art): an
// MP4 car whose file never arrives shows its still for the whole wait, so
// the layout is measured and captured without a video decoder.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/viewer_live_ref_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_rankings_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

UserSummary _member(String id, String name, {UserVip vip = _vip1}) =>
    UserSummary(
      id: id,
      username: id,
      displayName: name,
      avatarUrl: null,
      vip: vip,
    );

const _carMp4 = 'https://cdn.test/vip/car.mp4';
const _fullStill = 'https://cdn.test/vip/car_full.png';
const _halfStill = 'https://cdn.test/vip/car_half.png';
const _bannerStill = 'https://cdn.test/vip/banner.png';

/// The stand-in cars' sizes: a portrait full-screen car and a wide one made
/// for the half-screen band.
const _fullArt = Size(750, 1334);
const _halfArt = Size(750, 560);

/// VIP 1 with an entry banner and an entry car shown as [display] (null: an
/// older server, no field).
VipTierList _catalog(EntryDisplay? display, {bool banner = true}) {
  final half = display == EntryDisplay.halfScreen;
  final art = half ? _halfArt : _fullArt;
  return VipTierList(
    tiers: [
      VipTier(
        id: 'id-VIP_1',
        code: 'VIP_1',
        name: 'VIP 1',
        level: 1,
        color: 0xFF2E8B3D,
        nameColor: 0xFFFFC928,
        priceCoins: 1000000,
        durationDays: 30,
        perks: [
          if (banner)
            const VipPerk(
              code: VipPerks.entryBanner,
              title: 'banner',
              available: true,
              still: _bannerStill,
              artWidth: 2000,
              artHeight: 667,
            ),
          VipPerk(
            code: VipPerks.entryEffect,
            title: 'car',
            available: true,
            animation: _carMp4,
            video: ArtVideo.plain,
            still: half ? _halfStill : _fullStill,
            artWidth: art.width.toInt(),
            artHeight: art.height.toInt(),
            entryDisplay: display,
          ),
        ],
      ),
    ],
    maxAheadDays: 400,
  );
}

/// A test-only stand-in car (Kabso's own drawing, no third-party art): a
/// violet glow over the whole canvas and a gold car body with two wheels
/// in its lower part.
Future<Uint8List> _standInCar(Size size) async {
  final w = size.width;
  final h = size.height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w / 2, h * 0.7), h * 0.8, const [
          Color(0xCC7A3CFF),
          Color(0x662A0A66),
        ]),
    );
  final body = Rect.fromLTWH(w * 0.12, h - w * 0.42, w * 0.76, w * 0.2);
  canvas
    ..drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.06)),
      Paint()
        ..shader = ui.Gradient.linear(body.topLeft, body.bottomRight, const [
          Color(0xFFFFE08A),
          Color(0xFFC9A227),
        ]),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, body.top - w * 0.1, w * 0.4, w * 0.12),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0xFF9FD8FF),
    );
  for (final x in [0.28, 0.72]) {
    canvas.drawCircle(
      Offset(w * x, body.bottom),
      w * 0.07,
      Paint()..color = const Color(0xFF1B1B24),
    );
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The device's cache: the MP4 never arrives (no timer), so the car's still
/// shows until the layer gives up on it ([LiveVipEntranceLayer.carWait]).
class _NeverCache extends GiftArtCache {
  @override
  Future<Uint8List> load(String url) => Completer<Uint8List>().future;

  @override
  Future<String> path(String url) => Completer<String>().future;
}

/// The stand-in stills, drawn once per test isolate.
final Map<String, Uint8List> _stills = {};

Future<void> _drawStills(WidgetTester tester) async {
  if (_stills.isNotEmpty) return;
  await tester.runAsync(() async {
    _stills[_fullStill] = await _standInCar(_fullArt);
    _stills[_halfStill] = await _standInCar(_halfArt);
  });
}

ImageProvider _imageFor(String url) {
  final bytes = _stills[url];
  if (bytes != null) return MemoryImage(bytes);
  // The entry banner: the app's own agent bar art as its stand-in.
  return const AssetImage('assets/recharge_agent/entrance_bar.webp');
}

/// The layer alone over the screen (as in the live room's stack).
class _Live extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(
    child: LiveVipEntranceLayer(
      key: LiveVipEntranceLayer.layerKey,
      roomId: 'room-0',
    ),
  );
}

final Finder _car = find.byKey(LiveVipEntranceLayer.carKey);
final Finder _banner = find.byKey(LiveVipEntranceLayer.bannerKey);

void _view(
  WidgetTester tester,
  Size size, {
  double top = 0,
  double bottom = 0,
}) {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3
    ..padding = FakeViewPadding(top: top * 3, bottom: bottom * 3)
    ..viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  addTearDown(tester.view.reset);
}

Future<FakeLiveMediaEngine> _pumpLayer(
  WidgetTester tester, {
  required VipTierList catalog,
  bool disableAnimations = false,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  await pumpScreen(
    tester,
    const _Live(),
    liveMediaEngine: engine,
    disableAnimations: disableAnimations,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      currentUserProvider.overrideWithValue(testUser()),
      vipCatalogProvider.overrideWith((ref) async => catalog),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_Live)),
  );
  final keep = container.listen(liveChatProvider('room-0'), (_, _) {});
  addTearDown(keep.close);
  await container
      .read(liveChatProvider('room-0').notifier)
      .attach(engine, enabled: true, muted: false);
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return engine;
}

Future<void> _frames(WidgetTester tester, [int n = 3]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump();
  }
}

/// The band the test expects, worked out apart from the layer: under the
/// header row (inset + 10 dp gap + 48 dp), over the chat's space (bottom
/// inset + 48 dp bar + 30 % of the screen), at most half the screen.
Rect _expectedBand(Size s, double top, double bottom) {
  final chatTop = s.height - bottom - 48 - s.height * 0.30;
  final bandTop = [
    top + 58,
    chatTop - s.height / 2,
  ].reduce((a, b) => a > b ? a : b);
  return Rect.fromLTRB(0, bandTop, s.width, chatTop);
}

void main() {
  final cache = GiftArtCache.instance;
  final controller = giftVideoController;
  final videos = <String>[];
  setUp(() {
    vipImageFor = _imageFor;
    LiveVipEntranceLayer.animate = false;
    VipAnimatedArt.animationsEnabled = true;
    GiftArtCache.instance = _NeverCache();
    videos.clear();
    giftVideoController = (path) {
      videos.add(path);
      return VideoPlayerController.networkUrl(Uri.parse('file:///none'));
    };
  });
  tearDown(() {
    vipImageFor = NetworkImage.new;
    LiveVipEntranceLayer.animate = true;
    VipAnimatedArt.animationsEnabled = false;
    GiftArtCache.instance = cache;
    giftVideoController = controller;
  });

  group('the wire', () {
    test('StoreWornItem.entryDisplay is read, kept and written; anything '
        'else is none (full screen)', () {
      final half = StoreArt.fromJson({
        'still': null,
        'animation': 'https://cdn.test/c.svga',
        'format': 'SVGA',
        'alpha': null,
        'width': 750,
        'height': 560,
        'entryDisplay': 'HALF_SCREEN',
      })!;
      expect(half.entryDisplay, EntryDisplay.halfScreen);
      expect(half.toJson()['entryDisplay'], 'HALF_SCREEN');
      expect(StoreArt.fromJson(half.toJson()), half);
      expect(
        StoreArt.fromJson({
          'animation': 'https://cdn.test/c.svga',
          'entryDisplay': 'FULL_SCREEN',
        })!.entryDisplay,
        EntryDisplay.fullScreen,
      );
      // An older server (no field) and an unknown value: none.
      final old = StoreArt.fromJson({'animation': 'https://cdn.test/c.svga'})!;
      expect(old.entryDisplay, isNull);
      expect(old.toJson().containsKey('entryDisplay'), isFalse);
      expect(
        StoreArt.fromJson({
          'animation': 'https://cdn.test/c.svga',
          'entryDisplay': 'QUARTER_SCREEN',
        })!.entryDisplay,
        isNull,
      );
      expect(old == half, isFalse);
    });

    test('a join message: the worn store car carries its display to the '
        "look's ENTRY_EFFECT; the VIP catalogue's perk too", () {
      final user = UserSummary.fromJson({
        'id': 'u-1',
        'username': 'layla',
        'displayName': 'Layla',
        'avatarUrl': null,
        'wear': {
          'entryEffect': {
            'code': 'store_0123456789ab',
            'still': null,
            'animation': 'https://cdn.test/c.svga',
            'format': 'SVGA',
            'alpha': null,
            'width': 750,
            'height': 560,
            'entryDisplay': 'HALF_SCREEN',
          },
        },
      });
      final look = vipLookOf(user.vip, null)!;
      final car = look.perk(VipPerks.entryEffect)!;
      expect(car.entryDisplay, EntryDisplay.halfScreen);
      expect(LiveVipEntranceLayer.displayOf(car), EntryDisplay.halfScreen);
      // The summary's JSON keeps it (the chat's cached copies).
      expect(
        UserSummary.fromJson(user.toJson())
            .vip!
            .store['ENTRY_EFFECT']!
            .entryDisplay,
        EntryDisplay.halfScreen,
      );

      final perk = VipPerk.fromJson(const {
        'code': 'ENTRY_EFFECT',
        'title': 'مؤثر الدخول',
        'available': true,
        'entryDisplay': 'HALF_SCREEN',
      });
      expect(perk.entryDisplay, EntryDisplay.halfScreen);
      final older = VipPerk.fromJson(const {
        'code': 'ENTRY_EFFECT',
        'title': 'x',
        'available': true,
      });
      expect(older.entryDisplay, isNull);
      expect(LiveVipEntranceLayer.displayOf(older), EntryDisplay.fullScreen);
    });

    test('the half band: about half the screen, under the header, over the '
        'chat', () {
      for (final (size, top, bottom) in [
        (const Size(360, 800), 24.0, 0.0),
        (const Size(393, 852), 59.0, 34.0),
        (const Size(430, 932), 59.0, 34.0),
      ]) {
        final band = LiveVipEntranceLayer.halfBand(
          size,
          EdgeInsets.only(top: top, bottom: bottom),
        );
        expect(band, _expectedBand(size, top, bottom), reason: '$size');
        expect(band.width, size.width);
        expect(band.height / size.height, inInclusiveRange(0.44, 0.5));
      }
      expect(
        LiveVipEntranceLayer.halfBand(
          const Size(393, 852),
          const EdgeInsets.only(top: 59, bottom: 34),
        ).height.round(),
        397,
      );
    });
  });

  group('the layout', () {
    for (final (size, top, bottom) in [
      (const Size(360, 800), 24.0, 0.0),
      (const Size(393, 852), 59.0, 34.0),
      (const Size(430, 932), 59.0, 34.0),
    ]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      for (final display in [null, ...EntryDisplay.values]) {
        testWidgets('$name: a ${display?.wire ?? 'no-field'} car', (
          tester,
        ) async {
          await _drawStills(tester);
          _view(tester, size, top: top, bottom: bottom);
          final engine = await _pumpLayer(tester, catalog: _catalog(display));
          engine.chat.add(LiveChatJoined(_member('u-layla', 'Layla')));
          await _frames(tester);
          await tester.pump(const Duration(milliseconds: 300));
          expect(_car, findsOneWidget);
          final rect = tester.getRect(_car);
          if (display == EntryDisplay.halfScreen) {
            final band = _expectedBand(size, top, bottom);
            expect(rect, band);
            // Under the header row, over the chat, full width.
            expect(rect.top, greaterThanOrEqualTo(top + 58));
            expect(
              rect.bottom,
              lessThanOrEqualTo(size.height - bottom - 48 - size.height * 0.3),
            );
            expect(rect.left, 0);
            expect(rect.right, size.width);
            // The car is drawn whole in it: a wide car fills its width.
            final still = tester.getRect(
              find.descendant(of: _car, matching: find.byType(RawImage)),
            );
            expect(still.left, closeTo(0, 0.01));
            expect(still.right, closeTo(size.width, 0.01));
            expect(still.top, greaterThanOrEqualTo(rect.top - 0.01));
            expect(still.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
            // The entrant's banner is over the car, inside its band.
            final banner = tester.getRect(_banner);
            expect(banner.top, greaterThanOrEqualTo(rect.top));
            expect(banner.bottom, lessThanOrEqualTo(rect.bottom));
          } else {
            // Full screen (an older server's car too): the whole screen.
            expect(rect, Offset.zero & size);
            expect(_banner, findsOneWidget);
          }
          // Never takes taps.
          expect(
            find.ancestor(of: _car, matching: find.byType(IgnorePointer)),
            findsWidgets,
          );
          expect(
            tester
                .widget<IgnorePointer>(
                  find
                      .ancestor(of: _car, matching: find.byType(IgnorePointer))
                      .first,
                )
                .ignoring,
            isTrue,
          );
          // The file never came: the car leaves after its wait.
          await tester.pump(LiveVipEntranceLayer.carWait);
          await _frames(tester);
          expect(_car, findsNothing);
          await tester.pump(const Duration(seconds: 10));
        });
      }
    }

    testWidgets('a worn store car set HALF_SCREEN plays in the band (the '
        "server's value; no VIP needed)", (tester) async {
      await _drawStills(tester);
      _view(tester, const Size(393, 852), top: 59, bottom: 34);
      final engine = await _pumpLayer(tester, catalog: _catalog(null));
      const store = UserVip.storeOnly({
        'ENTRY_EFFECT': StoreArt(
          animation: _carMp4,
          video: ArtVideo.plain,
          still: _halfStill,
          width: 750,
          height: 560,
          entryDisplay: EntryDisplay.halfScreen,
        ),
      });
      engine.chat.add(LiveChatJoined(_member('u-store', 'Store', vip: store)));
      await _frames(tester);
      expect(tester.getRect(_car), _expectedBand(const Size(393, 852), 59, 34));
      await tester.pump(LiveVipEntranceLayer.carWait);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('reduced motion: as before, no half-screen car plays', (
      tester,
    ) async {
      await _drawStills(tester);
      _view(tester, const Size(393, 852), top: 59, bottom: 34);
      final engine = await _pumpLayer(
        tester,
        catalog: _catalog(EntryDisplay.halfScreen, banner: false),
        disableAnimations: true,
      );
      engine.chat.add(LiveChatJoined(_member('u-layla', 'Layla')));
      await _frames(tester, 6);
      expect(_car, findsNothing);
      expect(videos, isEmpty);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('in the live room', () {
    Future<(FakeLiveMediaEngine, ProviderContainer)> room(
      WidgetTester tester, {
      required EntryDisplay display,
      required AppLanguage language,
      bool audio = false,
      bool golden = false,
    }) async {
      await _drawStills(tester);
      final ar = language == AppLanguage.ar;
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      // Pinned clocks: the host's daily card.
      final now = DateTime(2026, 11, 11, 21, 10);
      HostDailyRankCard.now = () => now;
      addTearDown(() => HostDailyRankCard.now = DateTime.now);
      final prefs = await testPrefs(language: language.name);
      late FakeLiveMediaEngine engine;
      LiveRoom roomOf(String id) {
        final r = apiRoom(id: id, ar: ar);
        return audio ? r.copyWith(mode: LiveRoomMode.audio, seatCount: 10) : r;
      }

      await pumpGolden(
        tester,
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            liveRepositoryProvider.overrideWithValue(
              FakeLiveRepository(room: roomOf),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile(ar: ar)),
            ),
            liveGiftRepositoryProvider.overrideWithValue(
              FakeLiveGiftRepository(codes: giftFixtureCodes),
            ),
            liveHostTargetsRepositoryProvider.overrideWithValue(
              FakeLiveHostTargetsRepository(),
            ),
            // Pinned clocks: the daily board's end and the card's «now».
            liveRankingsRepositoryProvider.overrideWithValue(
              FakeLiveRankingsRepository({
                LiveRankingPeriod.day: LiveRankings(
                  period: LiveRankingPeriod.day,
                  startsAt: DateTime(2026, 11, 11),
                  endsAt: DateTime(2026, 11, 12),
                  entries: const [],
                ),
              }),
            ),
            ...pkTestOverrides(),
            liveMediaEngineProvider.overrideWithValue(
              () => engine = FakeLiveMediaEngine()..present.add('user-0'),
            ),
            currentUserProvider.overrideWithValue(testUser()),
            vipCatalogProvider.overrideWith((ref) async => _catalog(display)),
          ],
          // The golden harness turns motion off (a still screen); the car
          // plays only with motion on, as on a phone.
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: false),
              child: const LiveRoomScreen(roomId: 'room-0'),
            ),
          ),
        ),
        language: language,
        bare: true,
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveRoomScreen)),
      );
      return (engine, container);
    }

    testWidgets('«إخفاء تأثيرات الدخول» hides a half-screen car as every '
        'entrance', (tester) async {
      final (engine, container) = await room(
        tester,
        display: EntryDisplay.halfScreen,
        language: AppLanguage.en,
      );
      engine.chat.add(LiveChatJoined(_member('u-layla', 'Layla')));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_car, findsOneWidget);
      expect(tester.getRect(_car), _expectedBand(const Size(393, 852), 59, 34));
      await tester.pump(LiveVipEntranceLayer.carWait);
      await tester.pump(const Duration(seconds: 3));
      expect(_car, findsNothing);

      container
          .read(liveViewerPrefsProvider.notifier)
          .setEntrancesHidden(hidden: true);
      await _frames(tester);
      engine.chat.add(LiveChatJoined(_member('u-sara', 'Sara')));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(LiveVipEntranceLayer.layerKey), findsNothing);
      expect(_car, findsNothing);
      expect(_banner, findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    for (final audio in [false, true]) {
      for (final display in EntryDisplay.values) {
        forEachLanguage((language) {
          final where = audio ? 'audio' : 'video';
          final mode = display == EntryDisplay.halfScreen ? 'half' : 'full';
          testWidgets('golden vip.entry_car.$where.$mode ($language)', (
            tester,
          ) async {
            final (engine, _) = await room(
              tester,
              display: display,
              language: language,
              audio: audio,
              golden: true,
            );
            final ar = language == AppLanguage.ar;
            engine.chat.add(
              LiveChatJoined(_member('u-layla', ar ? 'ليلى' : 'Layla')),
            );
            await _frames(tester);
            await tester.pump(const Duration(milliseconds: 300));
            await precacheImages(tester);
            await _frames(tester);
            expect(_car, findsOneWidget);
            await expectScreenGolden(
              'vip.entry_car.$where.$mode',
              language: language,
            );
            await tester.pump(LiveVipEntranceLayer.carWait);
            await tester.pump(const Duration(seconds: 10));
          });
        });
      }
    }
  });
}
