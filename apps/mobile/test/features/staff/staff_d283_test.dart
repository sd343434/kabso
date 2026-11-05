// D283 (owner 2026-11-05): the Kabso Team's accounts are limited — no live,
// no levels, announcements only — and wear one fixed look: the team badge,
// the locked team frame (its photo window measured from the art), the fixed
// team picture and the region's team cover; the profile line «مشرف للوطن
// العربي» / "Moderator — Arab World"; a staff-only Me tab.
//
// Checked here: the profile line (ar / en, one, two, many regions, FINANCE,
// none); a staff profile (team cover by region, frame, badge, line, no
// levels); the staff-only Me tab (only the header, «فريق كابسو», the
// announcement composer and settings); the ➕ menu without story or live;
// the route guard; the team picture wherever KAvatar gets the team URL; the
// frame window measured from the bundled art matches its constants.
//
// The goldens are in test/goldens/staff_d283_golden_test.dart.

import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/posts/presentation/announcement_label.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/staff/presentation/staff_covers.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show pumpOther;

/// The API's team picture (any origin: the path decides).
const teamAvatarUrl = 'https://api.k.test/api/v1/staff/team-avatar.png';

/// A fixed clock for every staff test and golden.
final DateTime d283Now = DateTime.utc(2026, 11, 5, 12);

const arabModerator = KabsoStaffIdentity(
  role: StaffLineRole.moderation,
  regions: [StaffRegion.arabWorld],
);
const europeSupport = KabsoStaffIdentity(
  role: StaffLineRole.support,
  regions: [StaffRegion.europe],
);

/// Someone else's staff profile: the team picture, no cover or frame of
/// its own (the server sends none), the D273 `kabsoTeam` and D283 `staff`.
PublicProfile staffProfile({
  required bool ar,
  KabsoStaffIdentity staff = arabModerator,
}) => apiProfile(ar: ar).copyWith(
  displayName: ar ? 'مشرف كابسو' : 'Kabso Moderator',
  avatarUrl: teamAvatarUrl,
  followerCount: 3120,
  followingCount: 12,
  kabsoTeam: true,
  staff: staff,
);

User staffUser({
  required bool ar,
  KabsoStaffIdentity staff = arabModerator,
  String? staffId,
}) =>
    testUser(
      displayName: ar ? 'مشرف كابسو' : 'Kabso Moderator',
      username: 'kabso.mod',
    ).copyWith(
      avatarUrl: teamAvatarUrl,
      kabsoTeam: true,
      staff: staff,
      staffId: staffId,
    );

/// D283d: the official bio card's header — the only place of the region
/// line «مشرف للوطن العربي».
String staffBioTitle(WidgetTester tester) => tester
    .widget<Text>(find.byKey(StaffOfficialBio.titleKey))
    .textSpan!
    .toPlainText();

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 0;
}

/// The Me tab of a staff account, phone size with the status bar / home
/// indicator insets, a fixed clock.
Future<void> pumpStaffHub(
  WidgetTester tester, {
  required AppLanguage language,
  KabsoStaffIdentity staff = arabModerator,
  // D283c: the official staff ID «Kabso01» (none in the D283 goldens).
  String? staffId,
}) async {
  final ar = language == AppLanguage.ar;
  final user = staffUser(ar: ar, staff: staff, staffId: staffId);
  final router = GoRouter(
    initialLocation: AppRoutes.profile,
    routes: [
      GoRoute(path: AppRoutes.profile, builder: (_, _) => const MeHubScreen()),
      for (final path in [
        AppRoutes.myProfile,
        AppRoutes.settings,
        AppRoutes.notifications,
        AppRoutes.staff,
        AppRoutes.newReel,
        AppRoutes.create,
      ])
        GoRoute(path: path, builder: (_, s) => Text('page ${s.uri}')),
    ],
  );
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final prefs = await testPrefs(language: language.name);
  await withClock(Clock.fixed(d283Now), () async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(user),
          meProvider.overrideWith((ref) => user),
          profileStatsProvider.overrideWith(
            (ref, _) => staffProfile(
              ar: ar,
              staff: staff,
            ).copyWith(isSelf: true, staffId: staffId),
          ),
          profileLevelsProvider.overrideWith((ref, _) => const []),
          liveCoinsProvider.overrideWith(_Coins.new),
          profileGridProvider.overrideWith(
            (ref, _) => const FeedItems<ProfileGridItem>([]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: language.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(
            brightness: Brightness.light,
            locale: language.locale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  final ar = l10nFor(AppLanguage.ar);
  final en = l10nFor(AppLanguage.en);

  group('the profile line', () {
    test('a moderator: «مشرف للوطن العربي» / "Moderator — Arab World"', () {
      expect(arabModerator.line(ar), 'مشرف للوطن العربي');
      expect(arabModerator.line(en), 'Moderator — Arab World');
      const turkey = KabsoStaffIdentity(
        role: StaffLineRole.moderation,
        regions: [StaffRegion.turkey],
      );
      expect(turkey.line(ar), 'مشرف لتركيا');
    });

    test('support, two regions, many regions, none, finance', () {
      expect(europeSupport.line(ar), 'دعم — أوروبا');
      expect(europeSupport.line(en), 'Support — Europe');
      const two = KabsoStaffIdentity(
        role: StaffLineRole.moderation,
        regions: [StaffRegion.arabWorld, StaffRegion.turkey],
      );
      expect(two.line(ar), 'مشرف للوطن العربي وتركيا');
      expect(two.line(en), 'Moderator — Arab World & Türkiye');
      const many = KabsoStaffIdentity(
        role: StaffLineRole.support,
        regions: [
          StaffRegion.greaterChina,
          StaffRegion.eastAsia,
          StaffRegion.oceania,
        ],
      );
      expect(many.line(ar), 'دعم — الصين الكبرى وشرق آسيا وأكثر');
      expect(many.line(en), 'Support — Greater China, East Asia and more');
      const none = KabsoStaffIdentity(role: StaffLineRole.moderation);
      expect(none.line(ar), 'مشرف');
      const finance = KabsoStaffIdentity(role: StaffLineRole.finance);
      expect(finance.line(ar), 'المالية');
      expect(finance.line(en), 'Finance');
    });

    test('reads the wire (unknown regions skipped) and writes it back', () {
      final s = staffIdentityFromJson({
        'role': 'SUPPORT',
        'regions': ['GREATER_CHINA', 'ATLANTIS'],
      });
      expect(s, isNotNull);
      expect(s!.role, StaffLineRole.support);
      expect(s.regions, [StaffRegion.greaterChina]);
      expect(staffIdentityToJson(s), {
        'role': 'SUPPORT',
        'regions': ['GREATER_CHINA'],
      });
      expect(staffIdentityFromJson(null), isNull);
      expect(staffIdentityFromJson({'role': 'OWNER'}), isNull);
    });
  });

  test('the region covers: the Arab World its own, every other one and none '
      'the international cover', () {
    expect(
      StaffCovers.assetFor(StaffRegion.arabWorld),
      'assets/staff/covers/arab_world.webp',
    );
    for (final r in [null, ...StaffRegion.values.skip(1)]) {
      expect(StaffCovers.assetFor(r), 'assets/staff/covers/international.webp');
    }
  });

  test('the team picture URL is recognised by its path', () {
    expect(isTeamAvatarUrl(teamAvatarUrl), isTrue);
    expect(
      isTeamAvatarUrl('https://api.kabsolive.com/api/v1/staff/team-avatar.png'),
      isTrue,
    );
    expect(isTeamAvatarUrl('https://cdn.k.test/a.jpg'), isFalse);
    expect(isTeamAvatarUrl(null), isFalse);
  });

  testWidgets('the frame window measured from the bundled art matches its '
      'constants (a new art needs no code change)', (tester) async {
    final window = await tester.runAsync(() async {
      final data = await rootBundle.load(KabsoTeamLook.frameAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData();
      return KabsoTeamFrameWindow.windowOf(bytes!, image.width, image.height);
    });
    expect(window, isNotNull);
    expect(
      window!.diameter,
      moreOrLessEquals(KabsoTeamLook.frameWindow, epsilon: 0.01),
    );
    expect(
      window.centre.dx,
      moreOrLessEquals(KabsoTeamLook.frameCentre.dx, epsilon: 0.01),
    );
    expect(
      window.centre.dy,
      moreOrLessEquals(KabsoTeamLook.frameCentre.dy, epsilon: 0.01),
    );
  });

  testWidgets('KAvatar draws the team picture in the locked frame for the '
      'team URL (as a URL or a NetworkImage), and a photo otherwise', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: KabsoApp.supportedLocales,
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: const Locale('en'),
        ),
        home: const Scaffold(
          body: Column(
            children: [
              KAvatar(name: 'a', imageUrl: teamAvatarUrl, size: 40),
              KAvatar(name: 'b', image: NetworkImage(teamAvatarUrl), size: 24),
              KAvatar(name: 'c', size: 40),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(KabsoTeamAvatar), findsNWidgets(2));
    expect(find.byKey(KabsoTeamAvatar.frameKey), findsNWidgets(2));
    expect(find.byKey(KabsoTeamPicture.pictureKey), findsNWidgets(2));
  });

  testWidgets('a staff profile: the region cover, the team frame and badge, '
      'the region line and no levels', (tester) async {
    await withClock(Clock.fixed(d283Now), () async {
      await pumpOther(tester, staffProfile(ar: true), language: AppLanguage.ar);
    });
    expect(tester.takeException(), isNull);
    final cover = tester.widget<Image>(
      find.byKey(ProfileCoverHeader.staffCoverKey),
    );
    expect(
      (cover.image as AssetImage).assetName,
      'assets/staff/covers/arab_world.webp',
    );
    expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
    expect(find.byKey(ProfileCoverHeader.levelsKey), findsNothing);
    expect(find.byKey(KabsoTeamAvatar.frameKey), findsOneWidget);
    expect(find.byType(KabsoTeamBadge), findsWidgets);
    // D283d: the region line only in the official bio card's header.
    expect(staffBioTitle(tester), contains('مشرف للوطن العربي'));
    expect(find.text('مشرف للوطن العربي'), findsNothing);
    // The photo sits at the cover's bottom-start, under the title.
    final photo = tester.getRect(find.byKey(KabsoTeamAvatar.frameKey));
    final area = tester.getRect(find.byKey(ProfileCoverHeader.coverAreaKey));
    expect(photo.top, greaterThan(area.top + area.height * 0.4));
  });

  testWidgets('a staff profile of another region: the international cover', (
    tester,
  ) async {
    await pumpOther(
      tester,
      staffProfile(ar: false, staff: europeSupport),
      language: AppLanguage.en,
    );
    final cover = tester.widget<Image>(
      find.byKey(ProfileCoverHeader.staffCoverKey),
    );
    expect(
      (cover.image as AssetImage).assetName,
      'assets/staff/covers/international.webp',
    );
    expect(staffBioTitle(tester), contains('Support — Europe'));
    expect(find.text('Support — Europe'), findsNothing);
  });

  testWidgets('the staff-only Me tab: the header (team picture, badge, line), '
      '«فريق كابسو», the announcement composer and settings — nothing else', (
    tester,
  ) async {
    await pumpStaffHub(tester, language: AppLanguage.ar);
    expect(tester.takeException(), isNull);
    expect(find.byKey(KabsoTeamAvatar.frameKey), findsOneWidget);
    expect(find.byType(KabsoTeamBadge), findsWidgets);
    // D283d: the region line only in the official bio card's header.
    expect(staffBioTitle(tester), contains('مشرف للوطن العربي'));
    expect(find.text('مشرف للوطن العربي'), findsNothing);
    expect(find.byKey(MeHubScreen.kabsoTeamKey), findsOneWidget);
    expect(find.byKey(MeHubScreen.staffAnnouncementKey), findsOneWidget);
    expect(find.byKey(MeHubScreen.staffAnnouncementReelKey), findsOneWidget);
    expect(find.byKey(MeHubScreen.staffSettingsKey), findsOneWidget);
    expect(find.byKey(MeHubScreen.cardsKey), findsNothing);
    for (final item in MeHubItem.values) {
      expect(find.byKey(item.key), findsNothing, reason: item.name);
    }
    await tester.tap(find.byKey(MeHubScreen.staffAnnouncementReelKey));
    await tester.pumpAndSettle();
    expect(find.text('page ${AppRoutes.newReel}'), findsOneWidget);
  });

  testWidgets('FINANCE: no «فريق كابسو» tools row (no watch role)', (
    tester,
  ) async {
    await pumpStaffHub(
      tester,
      language: AppLanguage.en,
      staff: const KabsoStaffIdentity(role: StaffLineRole.finance),
    );
    // The user is kabsoTeam in this fixture; a FINANCE account is not (D273).
    expect(staffBioTitle(tester), contains('Finance'));
    expect(find.text('Finance'), findsNothing);
  });

  testWidgets('the ➕ menu of a staff account: announcement post and reel, no '
      'story and no go live', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: KabsoApp.supportedLocales,
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: const Locale('ar'),
        ),
        home: const Scaffold(
          body: Column(
            children: [
              CreateMenuSheet(staff: true),
              AnnouncementComposerNote(),
            ],
          ),
        ),
      ),
    );
    expect(
      find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
      findsOneWidget,
    );
    expect(
      find.byKey(CreateMenuSheet.choiceKey(CreateChoice.reel)),
      findsOneWidget,
    );
    expect(
      find.byKey(CreateMenuSheet.choiceKey(CreateChoice.story)),
      findsNothing,
    );
    expect(
      find.byKey(CreateMenuSheet.choiceKey(CreateChoice.live)),
      findsNothing,
    );
    expect(find.text('نشر إعلان'), findsOneWidget);
    expect(find.byKey(AnnouncementLabel.labelKey), findsOneWidget);
    expect(find.text('إعلان رسمي — فريق كابسو'), findsOneWidget);
  });

  test('the route guard: a staff account cannot open go live, levels, VIP, '
      'family, store, wallet …; a user can', () {
    final staff = Authenticated(staffUser(ar: true));
    final user = Authenticated(testUser());
    for (final route in [
      AppRoutes.goLive,
      AppRoutes.levels,
      '/levels/charm',
      AppRoutes.vip,
      AppRoutes.families,
      AppRoutes.store,
      AppRoutes.wallet,
      AppRoutes.walletCherries,
      AppRoutes.bag,
      AppRoutes.agency,
      AppRoutes.recharge,
      AppRoutes.taskCenter,
      AppRoutes.newStory,
    ]) {
      expect(
        authRedirect(staff, route),
        AppRoutes.staffUnavailable,
        reason: route,
      );
      expect(authRedirect(user, route), isNull, reason: route);
    }
    for (final route in [
      AppRoutes.settings,
      AppRoutes.staff,
      AppRoutes.myProfile,
      AppRoutes.newReel,
    ]) {
      expect(authRedirect(staff, route), isNull, reason: route);
    }
  });
}
