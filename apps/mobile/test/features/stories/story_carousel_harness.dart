// D375: pumps the story viewer opened from the tray, for the carousel's
// widget tests and goldens (393 × 852, optionally with the status bar 59
// and the home indicator 34, real fonts and served photos).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/stories/story_carousel_d375_fixtures.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fake_support_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Serves each D375 photo's PNG to `Image.network` in a widget test.
class _Client implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(d375Photo(url.toString()).bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  new(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  HttpHeaders get headers => _Headers();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  new(this.data);
  final Uint8List data;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => data.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([data]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Runs [body] with the D375 photos served to `Image.network` (reset
/// before the test ends: the binding checks the painting debug variables).
Future<void> withD375Photos(Future<void> Function() body) async {
  debugNetworkImageHttpClientProvider = _Client.new;
  try {
    await body();
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

const ValueKey<String> carouselBoundaryKey = ValueKey('d375-boundary');

/// Opens `/stories/[open]` over the D375 tray. [reduceMotion] sets
/// `disableAnimations`; [device] adds the 59 / 34 insets and real fonts
/// and decodes the photos (inside [withD375Photos]).
Future<FakeStoriesRepository> pumpCarousel(
  WidgetTester tester, {
  String open = 'sara',
  AppLanguage language = AppLanguage.en,
  bool reduceMotion = false,
  bool device = false,
}) async {
  setViewport(tester, GoldenViewport.phone);
  if (device) {
    await loadAppFonts();
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
  }
  final ar = language == AppLanguage.ar;
  final repo = FakeStoriesRepository();
  repo.stories.addAll(d375Stories(ar: ar));
  final router = GoRouter(
    initialLocation: AppRoutes.stories(open),
    routes: [
      GoRoute(
        path: AppRoutes.storiesPattern,
        builder: (_, s) =>
            StoryViewerScreen(username: s.pathParameters['username']!),
      ),
      GoRoute(
        path: AppRoutes.reels,
        builder: (_, _) => const Scaffold(body: Text('posts tab')),
      ),
    ],
  );
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    RepaintBoundary(
      key: carouselBoundaryKey,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storiesRepositoryProvider.overrideWithValue(repo),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
          dmRepositoryProvider.overrideWithValue(FakeDmRepository()),
          supportRepositoryProvider.overrideWithValue(FakeSupportRepository()),
          dmPinsRepositoryProvider.overrideWithValue(FakeDmPinsRepository()),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
          homeStoriesProvider.overrideWith(
            (_) async => FeedItems(d375Tray(ar: ar)),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          locale: language.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(
            brightness: Brightness.dark,
            locale: language.locale,
          ),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: app!,
          ),
        ),
      ),
    ),
  );
  // The viewer runs timers: bounded pumps only (never settle).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  if (device) await decodeImages(tester);
  return repo;
}

/// Decodes every image on screen outside the fake clock, then repaints
/// (no settle: the story's bar would run out).
Future<void> decodeImages(WidgetTester tester) async {
  final done = <ImageProvider>{};
  for (var pass = 0; pass < 3; pass++) {
    final pending = [
      for (final e in find.byType(Image).evaluate())
        if (done.add((e.widget as Image).image)) e,
    ];
    if (pending.isEmpty) break;
    await tester.runAsync(() async {
      for (final e in pending) {
        await precacheImage((e.widget as Image).image, e, onError: (_, _) {});
      }
    });
    await tester.pump();
  }
}
