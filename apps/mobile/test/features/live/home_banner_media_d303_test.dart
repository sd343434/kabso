// D303 (owner 2026-11-07; CONVENTIONS §10.114.6): the Live home's promo
// banner may be an animated picture or a short muted video, and may open an
// event. The banner reads the new fields (older servers send none), a video
// shows its poster until it plays (the test host has no player), reduced
// motion shows only the still, and `/events/{id}` is an in-app route.
// Fixtures: Kabso-red generated pictures only.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';

const _event = '01a1b6a1-0000-7000-8000-000000000303';

const _video = HomeBanner(
  id: 'video',
  imageUrl: 'https://media.example.test/media/v/1500.webp',
  height: 300,
  link: '/events/$_event',
  kind: HomeBannerKind.video,
  posterUrl: 'https://media.example.test/media/v/1500.webp',
  videoUrl: 'https://media.example.test/media/v2/video.mp4',
  durationMs: 8000,
  eventId: _event,
);

const _animated = HomeBanner(
  id: 'anim',
  imageUrl: 'https://media.example.test/media/a/1500.webp',
  height: 300,
  link: '/families',
  kind: HomeBannerKind.animated,
  posterUrl: 'https://media.example.test/media/a/poster.webp',
  durationMs: 600,
);

/// A 10 × 2 Kabso-red PNG (a still: golden pumps settle; the animated
/// path is D248c's own test).
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAoAAAACCAIAAADuA9qHAAAAEUlEQVR4nGN4yimCBzHglwYA'
  'gYgUKZuf96EAAAAASUVORK5CYII=',
);

Future<void> _pump(
  WidgetTester tester,
  List<HomeBanner> banners, {
  AppLanguage language = AppLanguage.en,
  bool reduceMotion = false,
}) async {
  KHomeBannerCarousel.imageForTesting = (_) => MemoryImage(_png);
  KHomeBannerCarousel.playVideos = false;
  addTearDown(() {
    KHomeBannerCarousel.imageForTesting = null;
    KHomeBannerCarousel.playVideos = true;
  });
  await pumpGolden(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Align(
          alignment: Alignment.topCenter,
          child: KHomeBannerCarousel(
            banners: banners,
            overlayIndicator: true,
            aspect: KHomeBannerCarousel.homeAspect,
            onOpen: (_) {},
          ),
        ),
      ),
    ),
    language: language,
  );
}

void main() {
  test('reads the kind and media; an older server means a still', () {
    final b = HomeBanner.fromJson(const {
      'id': 'b1',
      'imageUrl': 'https://m.test/1.webp',
      'width': 1500,
      'height': 300,
      'title': null,
      'titleSide': 'RIGHT',
      'link': '/events/$_event',
      'kind': 'VIDEO',
      'posterUrl': 'https://m.test/1.webp',
      'videoUrl': 'https://m.test/v.mp4',
      'durationMs': 8000,
      'eventId': _event,
    });
    expect(b.kind, HomeBannerKind.video);
    expect(b.isVideo, isTrue);
    expect(b.durationMs, 8000);
    expect(b.eventId, _event);
    final old = HomeBanner.fromJson(const {
      'id': 'b2',
      'imageUrl': 'https://m.test/2.webp',
      'width': 1500,
      'height': 500,
      'title': null,
      'titleSide': 'LEFT',
      'link': '/families',
    });
    expect(old.kind, HomeBannerKind.image);
    expect(old.stillUrl, 'https://m.test/2.webp');
    expect(old.isVideo, isFalse);
    expect(HomeBannerKind.fromWire('HOLOGRAM'), HomeBannerKind.image);
  });

  test('an event link is an in-app route', () {
    expect(
      HomeBannerTarget.parse('/events/$_event'),
      const HomeBannerRoute('/events/$_event'),
    );
    expect(HomeBannerTarget.parse('/events/not-an-id'), isNull);
  });

  testWidgets('a video banner shows its player slot with the poster', (
    tester,
  ) async {
    await _pump(tester, const [_video]);
    expect(find.byKey(KHomeBannerCarousel.videoKey('video')), findsOneWidget);
    expect(find.byKey(KHomeBannerCarousel.stillKey('video')), findsNothing);
  });

  testWidgets('reduced motion: only the still (the poster), no video', (
    tester,
  ) async {
    await _pump(tester, const [_video, _animated], reduceMotion: true);
    expect(find.byKey(KHomeBannerCarousel.videoKey('video')), findsNothing);
    expect(find.byKey(KHomeBannerCarousel.stillKey('video')), findsOneWidget);
  });

  forEachLanguage((language) {
    testWidgets('golden home.banner.video ($language)', (tester) async {
      await _pump(tester, const [_video, _animated], language: language);
      await expectScreenGolden('home.banner.video', language: language);
    }, tags: ['golden']);
  });
}
