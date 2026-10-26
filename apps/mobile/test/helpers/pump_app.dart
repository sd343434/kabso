import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/join_screen.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_home_banners_repository.dart';
import 'fake_live_blocked_words_repository.dart';
import 'fake_live_gift_repository.dart';
import 'fake_live_media_engine.dart';
import 'fake_live_rankings_repository.dart';
import 'fake_live_repository.dart';
import 'fake_live_schedule_repository.dart';
import 'fake_notifications_repository.dart';
import 'fake_posts_repository.dart';
import 'fake_stories_repository.dart';

/// Shared preferences with an explicit language.
Future<SharedPreferences> testPrefs({
  String language = 'en',
  Map<String, Object> extra = const {},
}) {
  SharedPreferences.setMockInitialValues({
    PreferenceKeys.languageCode: language,
    ...extra,
  });
  return SharedPreferences.getInstance();
}

/// Pumps the whole app (router, theme, l10n) with [overrides].
///
/// Live discovery talks to [liveRepository] (default: hosting switched
/// off, the production state today) and the posts feeds to
/// [postsRepository] (default: the API with no posts yet), never to the
/// network. Create's media step never calls the device library plugin.
Future<void> pumpKabsoApp(
  WidgetTester tester, {
  required List<Override> overrides,
  String language = 'en',
  LiveRepository? liveRepository,
  PostsRepository? postsRepository,
  FakeLiveMediaEngine? liveMediaEngine,
  LiveGiftRepository? liveGiftRepository,
  Map<String, Object> prefs = const {},
}) async {
  final preferences = await testPrefs(language: language, extra: prefs);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        liveRepositoryProvider.overrideWithValue(
          liveRepository ?? FakeLiveRepository(hostingEnabled: false),
        ),
        postsRepositoryProvider.overrideWithValue(
          postsRepository ?? FakePostsRepository(),
        ),
        // Never the device plugin: Create offers the system picker.
        mediaLibraryProvider.overrideWithValue(const UnsupportedMediaLibrary()),
        // Never a camera or a media server: an in-memory engine.
        liveMediaEngineProvider.overrideWithValue(
          liveMediaEngine == null
              ? FakeLiveMediaEngine.new
              : () => liveMediaEngine,
        ),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        notificationsRepositoryProvider.overrideWithValue(
          FakeNotificationsRepository(),
        ),
        // D124: no promo banners unless a test adds them.
        homeBannersRepositoryProvider.overrideWithValue(
          FakeHomeBannersRepository(),
        ),
        // CP-016 B: never the network.
        liveBlockedWordsRepositoryProvider.overrideWithValue(
          FakeLiveBlockedWordsRepository(),
        ),
        liveRankingsRepositoryProvider.overrideWithValue(
          FakeLiveRankingsRepository(),
        ),
        // CP-016 C: never the network.
        liveScheduleRepositoryProvider.overrideWithValue(
          FakeLiveScheduleRepository(),
        ),
        // CP-020: never the network (an empty catalogue, as production).
        liveGiftRepositoryProvider.overrideWithValue(
          liveGiftRepository ?? FakeLiveGiftRepository(),
        ),
        ...overrides,
      ],
      child: const KabsoApp(),
    ),
  );
}

/// Signed out, the app opens on the welcome screen (D64): taps "Log in".
Future<void> openLogin(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(WelcomeScreen.logInKey));
  await tester.pumpAndSettle();
}

/// Signed out, the first launch opens on the welcome screen (D64/D65):
/// "Let's start" opens the join screen, whose "Create account" opens
/// register.
Future<void> openRegister(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(WelcomeScreen.signUpKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(JoinScreen.createKey));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view, then taps it (D65: the login form sits
/// under Kabi's face and may start below a small test view).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

/// Pumps a single screen inside a themed, localized [MaterialApp]. Posts
/// feeds read [postsRepository] (default: an empty [FakePostsRepository]).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  AppLanguage language = AppLanguage.en,
  PostsRepository? postsRepository,
  FakeLiveMediaEngine? liveMediaEngine,
  LiveGiftRepository? liveGiftRepository,
  HomeBannersRepository? homeBannersRepository,
}) async {
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Never the network: the posts API with no posts yet.
        postsRepositoryProvider.overrideWithValue(
          postsRepository ?? FakePostsRepository(),
        ),
        mediaLibraryProvider.overrideWithValue(const UnsupportedMediaLibrary()),
        // Never a camera or a media server: an in-memory engine.
        liveMediaEngineProvider.overrideWithValue(
          liveMediaEngine == null
              ? FakeLiveMediaEngine.new
              : () => liveMediaEngine,
        ),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        notificationsRepositoryProvider.overrideWithValue(
          FakeNotificationsRepository(),
        ),
        // D124: no promo banners unless a test adds them.
        homeBannersRepositoryProvider.overrideWithValue(
          homeBannersRepository ?? FakeHomeBannersRepository(),
        ),
        // CP-020: never the network (an empty catalogue, as production).
        liveGiftRepositoryProvider.overrideWithValue(
          liveGiftRepository ?? FakeLiveGiftRepository(),
        ),
        ...overrides,
      ],
      child: MaterialApp(
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
        home: screen,
      ),
    ),
  );
}

AppLocalizations l10nFor(AppLanguage language) =>
    lookupAppLocalizations(language.locale);
