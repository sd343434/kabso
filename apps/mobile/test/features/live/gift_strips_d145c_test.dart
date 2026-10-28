// D145c (owner device report, 2026-10-28; host @nabulsi300 in his audio
// room sent the SVGA gift angel_warrior to himself): «no strip at all», the
// gift's still picture floating mid-screen while the SVGA downloaded, then
// the SVGA far larger than the screen with the wings and legs cut off; the
// combo button's label; the public message's room-role chips.
//
// Root causes reproduced here: (1) the sender's own strip sat between the
// seats and the chat — under the gift panel, which normal gifts keep open
// (strip 482–518 pt, panel 441–852 pt at 393×852), and under the
// full-screen effect (the audio strips were drawn in the room's layout, the
// effect layer above it); (3) a full-screen SVGA whose frames are drawn
// past its view box (angel_warrior: 750 × 1624 box, 916 × 1628 frames from
// x = −83) was clipped to the view box.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_public_message.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _svgaUrl = 'https://media.example.test/media/gifts/sports_car/fx.svga';

/// The test catalogue, with the sports car's SVGA hosted (16.8 MB: too big
/// for the panel's opening prefetch).
class _HostedArt extends FakeLiveGiftRepository {
  new() : super(codes: const ['confetti', 'sports_car']);

  @override
  Future<GiftCatalogue> catalogue() async {
    final json = giftCatalogueJson(
      codes: const ['confetti'],
      extra: [
        {
          ...giftJson('sports_car'),
          'animationUrl': _svgaUrl,
          'animationBytes': 16830815,
        },
      ],
    );
    calls.add('catalogue');
    return GiftCatalogue.fromJson(json);
  }
}

class _CountingCache extends GiftArtCache {
  final loads = <String>[];

  @override
  Future<Uint8List> load(String url) async {
    loads.add(url);
    throw StateError('offline');
  }
}

/// The host's own audio room on a 393 × 852 phone, live; returns the gifts.
Future<FakeLiveGiftRepository> _hostAudioRoom(
  WidgetTester tester, {
  FakeLiveGiftRepository? gifts,
  AppLanguage language = AppLanguage.en,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3
    ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3)
    ..viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
  final repo =
      gifts ?? FakeLiveGiftRepository(codes: const ['confetti', 'sports_car']);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveGiftRepository: repo,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
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
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _openPanelAndPick(
  WidgetTester tester,
  String tab,
  String code,
) async {
  await tester.tap(find.byKey(GoLiveScreen.audioGiftKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(KLiveGiftSheet.tabKey(tab)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(KLiveGiftSheet.cellKey(code)));
  await tester.pump();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 8));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// An SVGA 2.x file shaped like angel_warrior: a 750 × 1624 view box whose
/// one full-frame bitmap (400 × 711, solid red) is drawn ×2.29 from
/// (−83, −2.095) — 916 × 1628, past the view box on both sides.
Future<Uint8List> _angelShapedSvga(WidgetTester tester) async {
  final png = (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 400, 711),
      Paint()..color = const Color(0xFFFF0000),
    );
    final image = await recorder.endRecording().toImage(400, 711);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  final movie = MovieEntity()
    ..mergeFromProto3Json({
      'version': '2.0.0',
      'params': {
        'viewBoxWidth': 750,
        'viewBoxHeight': 1624,
        'fps': 30,
        'frames': 1,
      },
      'images': {'frame': base64Encode(png)},
      'sprites': [
        {
          'imageKey': 'frame',
          'frames': [
            {
              'alpha': 1,
              'layout': {'width': 400, 'height': 711},
              'transform': {'a': 2.29, 'd': 2.29, 'tx': -83, 'ty': -2.095},
            },
          ],
        },
      ],
    });
  return Uint8List.fromList(ZLibCodec().encode(movie.writeToBuffer()));
}

void main() {
  group("1. a strip for every gift, on the sender's own device", () {
    testWidgets('the host gifts himself in his audio room with the panel '
        'open: his strip shows above the panel, at the reading start', (
      tester,
    ) async {
      final gifts = await _hostAudioRoom(tester);
      await _openPanelAndPick(tester, 'FUN', 'confetti');
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(gifts.sends.single.recipients, ['host0']);
      // The panel stays open (a normal gift) and the strip is above it.
      final sheet = tester.getRect(find.byKey(KLiveGiftSheet.sheetKey));
      final strip = tester.getRect(find.byType(LiveGiftBanner));
      expect(strip.bottom, lessThanOrEqualTo(sheet.top - 4));
      expect(strip.left, lessThan(20));
      // Nothing on top of it but the panel's barrier: a hit at its centre
      // does not land in the panel.
      expect(sheet.contains(strip.center), isFalse);
      // Panel closed: the strip goes back to the middle of the screen.
      Navigator.of(tester.element(find.byType(KLiveGiftSheet))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(KLiveGiftSheet), findsNothing);
      final after = tester.getRect(find.byType(LiveGiftBanner));
      expect(after.center.dy, closeTo(852 / 2, 1));
      await _end(tester);
    });

    testWidgets('an animated self-gift: the strip first and drawn over the '
        'full-screen effect (both in the effects layer, the strips last)', (
      tester,
    ) async {
      await _hostAudioRoom(
        tester,
        gifts: FakeLiveGiftRepository(
          codes: const ['confetti', 'sports_car'],
          coins: 100000,
        ),
      );
      await _openPanelAndPick(tester, 'POPULAR', 'sports_car');
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(LiveGiftEffectsLayer.effectKey), findsOneWidget);
      final layer = find.byType(LiveGiftEffectsLayer);
      expect(
        find.descendant(of: layer, matching: find.byType(LiveGiftBanner)),
        findsOneWidget,
      );
      // Paint order: the strips' slot comes after the effect in the layer.
      final order = <String>[];
      tester.element(layer).visitChildElements((e) {
        void walk(Element el) {
          if (el.widget.key == LiveGiftEffectsLayer.effectKey) {
            order.add('effect');
          }
          if (el.widget is LiveGiftStripsSlot) order.add('strips');
          el.visitChildElements(walk);
        }

        walk(e);
      });
      expect(order, ['effect', 'strips']);
      // Never the gift's still picture blown up mid-screen.
      expect(
        find.descendant(
          of: find.byKey(LiveGiftEffectsLayer.effectKey),
          matching: find.byType(KGiftImage),
        ),
        findsNothing,
      );
      await _end(tester);
    });

    testWidgets("everyone else's device: the room's message of a self-gift "
        '(sender = recipient = host) shows a strip too', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final engine = FakeLiveMediaEngine();
      await pumpScreen(
        tester,
        const Scaffold(body: LiveGiftEffectsLayer(roomId: 'room-0')),
        liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      ).read(liveGiftEffectsProvider('room-0').notifier).attach(engine);
      final host = giftUserJson('host0', 'Oz Nabulsi');
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(id: 'self', sender: host, recipients: [host]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(LiveGiftEffectsLayer.bannerKey('self')),
        findsOneWidget,
      );
      await tester.pump(LiveGiftEffects.bannerTime);
      await tester.pumpAndSettle();
    });
  });

  group('2. the effect is fetched when the gift is picked', () {
    testWidgets('picking a gift with a big hosted SVGA starts its download '
        '(the panel only prefetched small ones)', (tester) async {
      final previous = GiftArtCache.instance;
      final cache = GiftArtCache.instance = _CountingCache();
      addTearDown(() => GiftArtCache.instance = previous);
      await _hostAudioRoom(tester, gifts: _HostedArt());
      await tester.tap(find.byKey(GoLiveScreen.audioGiftKey));
      await tester.pumpAndSettle();
      expect(cache.loads, isEmpty);
      await tester.tap(find.byKey(KLiveGiftSheet.tabKey('POPULAR')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLiveGiftSheet.cellKey('sports_car')));
      await tester.pump();
      expect(cache.loads, [_svgaUrl]);
      await _end(tester);
    });
  });

  group('3. a full-screen SVGA fits the screen whole', () {
    testWidgets('the angel-shaped movie: its drawn area is the frame '
        '(−83, −2.095, 833, 1626.095), not the view box', (tester) async {
      final bytes = await _angelShapedSvga(tester);
      final movie = (await tester.runAsync(
        () => SVGAParser.shared.decodeFromBuffer(bytes),
      ))!;
      addTearDown(movie.dispose);
      final b = KGiftMovieFrame.movieBounds(movie);
      expect(b.left, closeTo(-83, 0.01));
      expect(b.top, closeTo(-2.095, 0.01));
      expect(b.right, closeTo(833, 0.01));
      expect(b.bottom, closeTo(1626.095, 0.01));
    });

    for (final phone in const [
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets('${phone.width.toInt()}×${phone.height.toInt()}: the whole '
          'painted width shows (D145c) and, D145d, the movie stands on the '
          "screen's bottom edge — through the bottom safe area", (
        tester,
      ) async {
        tester.view
          ..physicalSize = phone
          ..devicePixelRatio = 1
          ..padding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.reset);
        final bytes = await _angelShapedSvga(tester);
        final movie = (await tester.runAsync(
          () => SVGAParser.shared.decodeFromBuffer(bytes),
        ))!;
        final controller = SVGAAnimationController(vsync: tester)
          ..videoItem = movie;
        addTearDown(controller.dispose);
        final bounds = KGiftMovieFrame.movieBounds(movie);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: KGiftMovieFrame(
                  viewBox: const Size(750, 1624),
                  bounds: bounds,
                  child: SVGAImage(controller),
                ),
              ),
            ),
          ),
        );
        final pixels = (await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!;
        }))!;
        final w = phone.width.toInt();
        final h = phone.height.toInt();
        var minX = w;
        var minY = h;
        var maxX = -1;
        var maxY = -1;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final i = (y * w + x) * 4;
            if (pixels.getUint8(i) > 200 && pixels.getUint8(i + 1) < 60) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        final red = Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          maxX + 1.0,
          maxY + 1.0,
        );
        final screen = Offset.zero & phone;
        final (outer, inner) = KGiftMovieFrame.layout(
          const Size(750, 1624),
          bounds,
          screen,
        );
        // D145d: the bottom edge of the painted movie is the screen's
        // bottom (no band under it, the 34 pt inset included); full width,
        // centred; the top lands where the height puts it.
        expect(red.bottom, closeTo(phone.height, 1));
        expect(red.left, closeTo(0, 1));
        expect(red.right, closeTo(phone.width, 1));
        expect((red.center.dx - phone.width / 2).abs(), lessThan(1.5));
        expect(outer.bottom, phone.height);
        // The whole 916-unit frame is painted (D145 cut it at 750: the
        // wings at the edges).
        expect(red.width, closeTo(outer.width, 2));
        expect(red.height, closeTo(outer.height, 2));
        expect(red.width / inner.width, closeTo(916 / 750, 0.01));
        // Nothing drawn outside the frame.
        expect(red.top, greaterThanOrEqualTo(outer.top - 1));
      });
    }

    test('a movie drawn inside its view box keeps the view box; full width, '
        'on the bottom edge', () {
      final (outer, inner) = KGiftMovieFrame.layout(
        const Size(750, 1334),
        const Rect.fromLTWH(0, 0, 750, 1334),
        const Rect.fromLTWH(0, 0, 393, 852),
      );
      expect(outer, inner);
      expect(outer.width, 393);
      expect(outer.bottom, 852);
      expect(outer.height, closeTo(393 * 1334 / 750, 0.001));
    });
  });

  test("MAX X: D145d, the owner's label «ماكس x12» / «MAX x12» (the word "
      'here, the number on the button); screen readers say "Max X" / '
      '«ماكس إكس»', () {
    final en = l10nFor(AppLanguage.en);
    final ar = l10nFor(AppLanguage.ar);
    expect(en.liveComboLabel, 'MAX');
    expect(ar.liveComboLabel, 'ماكس');
    expect(en.liveComboSemantics('Rose', 3), startsWith('Max X'));
    expect(ar.liveComboSemantics('وردة', 3), startsWith('ماكس إكس'));
    expect(ar.liveComboSemantics('وردة', 3), contains('\u2066×3\u2069'));
  });

  group('4. the public message is not about this room', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: no host / moderator chip, the personal '
          'badges stay', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          Scaffold(
            body: Center(
              child: LivePublicMessage(
                bullet: LiveBullet(
                  id: 'b1',
                  text: 'jo',
                  sender: const UserSummary(
                    id: 'user-host0',
                    username: 'host0',
                    displayName: 'Oz Nabulsi',
                    avatarUrl: null,
                  ),
                  roomId: 'room-0',
                  createdAt: DateTime(2026, 10, 28, 10, 12),
                ),
                badges: const LiveChatAuthorBadges(charmLevel: 12),
              ),
            ),
          ),
          language: language,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(LiveChatBadgeRow.roleKey), findsNothing);
        expect(find.byKey(LiveChatBadgeRow.charmKey), findsOneWidget);
        final l10n = l10nFor(language);
        expect(find.text(l10n.liveChatHostBadge), findsNothing);
      });
    }
  });
}
