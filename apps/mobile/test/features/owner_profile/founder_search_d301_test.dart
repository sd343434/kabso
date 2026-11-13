// D301 (owner: «في البحث تظهر صفحة مؤسس البرنامج دائماً», §10.112.9): the
// founder always in search, from `GET /search/featured`:
//
// - before anything is typed: the card (photo, name and seal, «مؤسس Kabso
//   Live», the handle, Follow) above the search home;
// - while typing: the compact row pinned above the results, and the founder
//   never twice (an account result for him is dropped);
// - no founder (none ACTIVE, or a block either way): nothing at all;
// - on his own search: no Follow.
//
// With D301_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_search.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_owner_profile_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show insets;

/// The founder as `GET /search/featured` sends him.
UserSummary founderSummary({required bool ar}) => UserSummary(
  id: 'owner-0',
  username: 'kabso',
  displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
  avatarUrl: null,
  staffId: 'Kabso',
  verification: VerificationBadge.owner,
);

const _kamal = UserSummary(
  id: 'u-kamal',
  username: 'kamal',
  displayName: 'Kamal',
  avatarUrl: null,
);

/// The search screen with [featured] as the server's founder (null: none).
Future<(FakeProfileRepository, GoRouter)> pumpFounderSearch(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  FeaturedFounder? featured,
  bool noFounder = false,
  List<UserSummary>? people,
}) async {
  final ar = language == AppLanguage.ar;
  final founder =
      featured ??
      (noFounder ? null : FeaturedFounder(user: founderSummary(ar: ar)));
  final profiles = FakeProfileRepository(ownerProfile(ar: ar));
  final router = GoRouter(
    initialLocation: '/discover',
    routes: [
      GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
      GoRoute(
        path: AppRoutes.userProfilePattern,
        builder: (_, s) =>
            Scaffold(body: Text('profile ${s.pathParameters['username']}')),
      ),
    ],
  );
  setViewport(tester, GoldenViewport.phone);
  insets(tester);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        postsRepositoryProvider.overrideWithValue(
          FakePostsRepository()
            ..people = people ?? [founderSummary(ar: ar), _kamal],
        ),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        ownerProfileRepositoryProvider.overrideWithValue(
          FakeOwnerProfileRepository(featured: founder),
        ),
        profileRepositoryProvider.overrideWithValue(profiles),
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
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (profiles, router);
}

/// Types [text] into the search field and waits for the results.
Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(DiscoverScreen.fieldKey), text);
  await tester.pump(DiscoverScreen.debounce);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  test('SearchFeatured: the owner, or null', () {
    final f = FeaturedFounder.fromSearchFeatured({
      'owner': {
        'id': 'owner-0',
        'username': 'kabso',
        'displayName': 'Kabso',
        'avatarUrl': null,
        'isFollowing': true,
        'isSelf': false,
      },
    });
    expect(f?.user.username, 'kabso');
    expect(f?.isFollowing, isTrue);
    expect(f?.isSelf, isFalse);
    expect(FeaturedFounder.fromSearchFeatured({'owner': null}), isNull);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    final l10n = lookupAppLocalizations(language.locale);
    group('the founder in search (${language.name})', () {
      testWidgets('before typing: the card; it opens his page', (tester) async {
        final (_, router) = await pumpFounderSearch(tester, language: language);
        expect(find.byKey(FounderSearchEntry.cardKey), findsOneWidget);
        expect(find.byKey(FounderSearchEntry.rowKey), findsNothing);
        expect(find.byKey(DiscoverScreen.promptKey), findsOneWidget);
        final card = find.byKey(FounderSearchEntry.cardKey);
        expect(
          find.descendant(of: card, matching: find.text(l10n.ownerSearchRole)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(ar ? 'مؤسس كابسو' : 'Kabso Founder'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(l10n.ownerSearchFollow),
          ),
          findsOneWidget,
        );
        // Above the search home.
        expect(
          tester.getRect(card).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(DiscoverScreen.promptKey)).top,
          ),
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.userProfile('kabso'));
      });

      testWidgets('while typing: pinned above the results, never twice', (
        tester,
      ) async {
        await pumpFounderSearch(tester, language: language);
        await typeSearch(tester, '@k');
        final row = find.byKey(FounderSearchEntry.rowKey);
        expect(row, findsOneWidget);
        expect(find.byKey(FounderSearchEntry.cardKey), findsNothing);
        // He matches the query too, but shows once: the pinned row.
        expect(find.byKey(DiscoverScreen.userKey('kabso')), findsNothing);
        final kamal = find.byKey(DiscoverScreen.userKey('kamal'));
        expect(kamal, findsOneWidget);
        expect(
          tester.getRect(row).bottom,
          lessThanOrEqualTo(tester.getRect(kamal).top),
        );
        // Cleared: the card again.
        await typeSearch(tester, '');
        expect(find.byKey(FounderSearchEntry.cardKey), findsOneWidget);
      });

      testWidgets('no founder (none ACTIVE, or a block): nothing', (
        tester,
      ) async {
        await pumpFounderSearch(tester, language: language, noFounder: true);
        expect(find.byKey(FounderSearchEntry.cardKey), findsNothing);
        expect(find.text(l10n.ownerSearchRole), findsNothing);
        await typeSearch(tester, '@k');
        expect(find.byKey(FounderSearchEntry.rowKey), findsNothing);
        // Not hidden from the results either: the ordinary row.
        expect(find.byKey(DiscoverScreen.userKey('kabso')), findsOneWidget);
      });

      testWidgets('Follow, then Following; back again', (tester) async {
        final (profiles, _) = await pumpFounderSearch(
          tester,
          language: language,
        );
        await tester.tap(find.byKey(FounderSearchEntry.followKey));
        await tester.pumpAndSettle();
        expect(profiles.calls, ['PUT kabso']);
        expect(
          find.descendant(
            of: find.byKey(FounderSearchEntry.followKey),
            matching: find.text(l10n.ownerSearchFollowing),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(FounderSearchEntry.followKey));
        await tester.pumpAndSettle();
        expect(profiles.calls, ['PUT kabso', 'DELETE kabso']);
        expect(find.text(l10n.ownerSearchFollow), findsOneWidget);
      });

      testWidgets('a failed follow goes back', (tester) async {
        final (profiles, _) = await pumpFounderSearch(
          tester,
          language: language,
        );
        profiles.followFailure = const NetworkFailure.offline();
        await tester.tap(find.byKey(FounderSearchEntry.followKey));
        await tester.pumpAndSettle();
        expect(find.text(l10n.ownerSearchFollow), findsOneWidget);
        expect(find.text(l10n.ownerSearchFollowing), findsNothing);
      });

      testWidgets('his own search: no Follow', (tester) async {
        await pumpFounderSearch(
          tester,
          language: language,
          featured: FeaturedFounder(user: founderSummary(ar: ar), isSelf: true),
        );
        expect(find.byKey(FounderSearchEntry.cardKey), findsOneWidget);
        expect(find.byKey(FounderSearchEntry.followKey), findsNothing);
      });

      testWidgets('already following: «Following»', (tester) async {
        await pumpFounderSearch(
          tester,
          language: language,
          featured: FeaturedFounder(
            user: founderSummary(ar: ar),
            isFollowing: true,
          ),
        );
        expect(find.text(l10n.ownerSearchFollowing), findsOneWidget);
      });
    });
  }

  final captureDir = Platform.environment['D301_CAPTURE_DIR'];
  group('D301 search captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        final tag = '${language.name}.${brightness.name}';
        testWidgets('search $tag', (tester) async {
          await pumpFounderSearch(
            tester,
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'search.card.$tag');
          await typeSearch(tester, '@k');
          await capture(tester, 'search.typing.$tag');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });
}
