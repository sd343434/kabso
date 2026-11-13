// D361 (owner: «المؤسس ليس له ليفيل»; CONVENTIONS §10.156): the founder shows
// no level anywhere — the server leaves his levels out of every public
// payload, and the app guards each place as well (the D357 pattern):
//
//  - his page (visitors and his own view): no level badges beside his name;
//  - the live person card: no charm or wealth badge for him;
//  - his own levels (`myLevelsProvider`, the Me tab, the gift sheet's wealth
//    strip, the live data page): none — never read;
//  - his levels page: decision, the neutral state «المؤسس ليس له مستوى»;
//  - a chat line of his: the server sends no level, so none is drawn.
//
// Captures (393 × 852 @3x): D361_CAPTURE_DIR=<dir> flutter test <this file>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/owner/owner_fixtures.dart';
import '../../goldens/live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../levels/levels_test.dart' show FakeLevelsRepository;
import '../profile/profile_cover_d278_test.dart' show coverBytes, pumpOther;
import '../profile/profile_d335_test.dart' show d335Rich;
import 'owner_profile_d301_test.dart'
    show d301Poster, pumpOwnerOwn, pumpOwnerVisitor;

Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// The founder's levels page (or anyone's, [founder] false).
Future<FakeLevelsRepository> _pumpLevels(
  WidgetTester tester, {
  required bool founder,
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.light,
}) async {
  final repo = FakeLevelsRepository();
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LevelsScreen(),
    language: language,
    brightness: brightness,
    overrides: [
      levelsRepositoryProvider.overrideWithValue(repo),
      isKabsoOwnerProvider.overrideWithValue(founder),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

UserSummary _founderSummary({required bool ar}) => UserSummary(
  id: 'user-0',
  username: 'kabso',
  displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
  avatarUrl: null,
);

/// His own live (audio) with a line of his — the server sends no level for
/// him (D361) — and a viewer's line with her levels.
Future<void> _pumpFounderChat(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
}) async {
  final ar = language == AppLanguage.ar;
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final host = _founderSummary(ar: ar);
  final repo =
      FakeLiveRepository(
          room: (id) => apiRoom(id: id, ar: ar).copyWith(
            mode: LiveRoomMode.audio,
            seatCount: 10,
            host: host,
            // D361: the server sends no room level in his lives.
            roomLevel: null,
          ),
        )
        ..chat = [
          LiveChatEntry(
            id: 'm1',
            roomId: 'room-0',
            author: host,
            authorRole: LiveChatRole.host,
            text: ar ? 'أهلاً بكم في كابسو لايف' : 'Welcome to Kabso Live',
            createdAt: DateTime.utc(2026, 11, 10, 16, 29),
            // As the server answers for the founder: no charm, no wealth.
            authorBadges: const LiveChatAuthorBadges(),
          ),
          LiveChatEntry(
            id: 'm2',
            roomId: 'room-0',
            author: const UserSummary(
              id: 'user-2',
              username: 'muna',
              displayName: 'منى',
              avatarUrl: null,
            ),
            authorRole: LiveChatRole.viewer,
            text: ar ? 'مساء الخير' : 'Good evening',
            createdAt: DateTime.utc(2026, 11, 10, 16, 30),
            authorBadges: const LiveChatAuthorBadges(
              charmLevel: 7,
              supportLevel: 12,
            ),
          ),
        ];
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    liveMediaEngine: FakeLiveMediaEngine()..present.add('owner-0'),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(ownerProfile(ar: ar)),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    d301Poster = await paintOwnerPoster();
  });
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
    ownerPosterImageFor = (_) => MemoryImage(d301Poster);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
    ownerPosterImageFor = NetworkImage.new;
  });

  test('his own levels are never read: none for the founder', () async {
    final repo = FakeLevelsRepository();
    final prefs = await testPrefs(language: 'ar');
    ProviderContainer container({required bool founder}) => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        levelsRepositoryProvider.overrideWithValue(repo),
        isKabsoOwnerProvider.overrideWithValue(founder),
      ],
    );
    final f = container(founder: true);
    addTearDown(f.dispose);
    expect(await f.read(myLevelsProvider.future), isEmpty);
    expect(await f.read(profileLevelsProvider(null).future), isEmpty);
    expect(repo.calls, 0);
    final other = container(founder: false);
    addTearDown(other.dispose);
    expect(await other.read(myLevelsProvider.future), isNotEmpty);
    expect(repo.calls, 1);
  });

  for (final language in AppLanguage.values) {
    testWidgets('his levels page: the neutral state, no level '
        '(${language.name})', (tester) async {
      final repo = await _pumpLevels(tester, founder: true, language: language);
      expect(find.byKey(LevelsScreen.founderKey), findsOneWidget);
      expect(
        find.text(
          language == AppLanguage.ar
              ? 'المؤسس ليس له مستوى'
              : 'The founder has no level',
        ),
        findsOneWidget,
      );
      expect(find.byType(KLevelBadge), findsNothing);
      expect(repo.calls, 0);
      await _end(tester);
    });
  }

  testWidgets('anyone else keeps their levels page', (tester) async {
    await _pumpLevels(tester, founder: false);
    expect(find.byKey(LevelsScreen.founderKey), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    await _end(tester);
  });

  testWidgets('his own «ProfileLevels» draws nothing', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: ProfileLevels()),
      overrides: [
        levelsRepositoryProvider.overrideWithValue(FakeLevelsRepository()),
        isKabsoOwnerProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileLevels.rowKey), findsNothing);
    await _end(tester);
  });

  testWidgets('his page has no level badges (visitor and own); a regular '
      'page keeps them', (tester) async {
    await pumpOwnerVisitor(tester, language: AppLanguage.ar);
    expect(find.byKey(ProfileCoverHeader.levelsKey), findsNothing);
    expect(find.byType(ProfileLevels), findsNothing);
    await _end(tester);
    await pumpOwnerOwn(tester, language: AppLanguage.en);
    expect(find.byKey(ProfileCoverHeader.levelsKey), findsNothing);
    await _end(tester);
    await pumpOther(tester, d335Rich(ar: true), language: AppLanguage.ar);
    expect(find.byKey(ProfileCoverHeader.levelsKey), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the live person card: no level for him, levels for others', (
    tester,
  ) async {
    Finder inCard(Type t) => find.descendant(
      of: find.byType(LivePersonSheet),
      matching: find.byType(t),
    );
    await pumpPersonCardRoom(
      tester,
      language: AppLanguage.ar,
      profile: personCardProfile(ar: true).copyWith(kabsoOwner: true),
    );
    expect(find.byType(LivePersonSheet), findsOneWidget);
    expect(inCard(CharmLevelBadge), findsNothing);
    expect(inCard(KLevelBadge), findsNothing);
    await _end(tester);
    await pumpPersonCardRoom(
      tester,
      language: AppLanguage.ar,
      profile: personCardProfile(ar: true),
    );
    expect(inCard(CharmLevelBadge), findsOneWidget);
    await _end(tester);
  });

  testWidgets(
    'his chat line in his live: no level badge; a viewer keeps hers',
    (tester) async {
      await _pumpFounderChat(tester, language: AppLanguage.ar);
      expect(
        find.textContaining('أهلاً بكم في كابسو لايف', findRichText: true),
        findsWidgets,
      );
      // Only the viewer's charm badge (and no room level after his title).
      expect(find.byType(CharmLevelBadge), findsOneWidget);
      await _end(tester);
    },
  );

  final captureDir = Platform.environment['D361_CAPTURE_DIR'];
  group('D361 captures', skip: captureDir == null, () {
    Future<void> save(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await captureImage(
          find.byType(MaterialApp).evaluate().first,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        final tag = '${language.name}.${brightness.name}';
        testWidgets('founder profile $tag', (tester) async {
          await pumpOwnerVisitor(
            tester,
            language: language,
            brightness: brightness,
          );
          await save(tester, 'founder.profile.$tag');
          await _end(tester);
        });
        testWidgets('founder levels page $tag', (tester) async {
          await _pumpLevels(
            tester,
            founder: true,
            language: language,
            brightness: brightness,
          );
          await save(tester, 'founder.levels.$tag');
          await _end(tester);
        });
        testWidgets('founder chat line $tag', (tester) async {
          await withClock(Clock.fixed(DateTime.utc(2026, 11, 10, 16, 31)), () {
            return _pumpFounderChat(
              tester,
              language: language,
              brightness: brightness,
            );
          });
          await save(tester, 'founder.live_chat.$tag');
          await _end(tester);
        });
      }
    }
  });
}
