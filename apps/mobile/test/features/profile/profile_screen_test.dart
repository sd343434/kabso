// D57: the own profile — counts beside the photo, name and bio, the
// Settings button, Posts/Reels tabs over a 3-column grid, honest states,
// RTL/LTR and small screens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_record.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

User _user({String? bio = 'Music every evening'}) => User(
  id: 'u1',
  email: 'u1@example.invalid',
  emailVerified: true,
  username: 'layla.k',
  displayName: 'Layla',
  locale: 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026),
  bio: bio,
);

List<Override> _overrides({
  bool statsFail = false,
  FeedLoad<ProfileGridItem> grid = const FeedUnavailable<ProfileGridItem>(),
}) => [
  meProvider.overrideWith((ref) => _user()),
  profileStatsProvider.overrideWith((ref, username) {
    if (statsFail) throw const NetworkFailure.offline();
    return apiProfile(followerCount: 5600, isSelf: true);
  }),
  profileGridProvider.overrideWith((ref, _) => grid),
];

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<Override>? overrides,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const ProfileScreen(),
    language: language,
    overrides: overrides ?? _overrides(),
  );
  await tester.pumpAndSettle();
}

FeedItems<ProfileGridItem> _items(int n) =>
    FeedItems([for (var i = 0; i < n; i++) const ProfileGridItem()]);

void main() {
  // KL-060: posts and saved now read the posts API
  // (test/features/profile/profile_grid_test.dart); reels have no API
  // before M2 and stay honestly unavailable.
  test('production reels grid is honest: unavailable', () async {
    final container = ProviderContainer.test(
      overrides: [
        postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    expect(
      await container.read(
        profileGridProvider((username: 'u', tab: ProfileTab.reels)).future,
      ),
      isA<FeedUnavailable<ProfileGridItem>>(),
    );
  });

  testWidgets('D335: our bar (back and the @username, drafts and settings) '
      'over the cover (the default Kabso one); the photo at the reading '
      'start, the name and the level badges under it; then the bio, the '
      'counts and «Edit profile»; no PK record', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile.title'))).data,
      '@layla.k',
    );
    expect(find.byKey(ProfileScreen.draftsButtonKey), findsOneWidget);
    expect(find.byKey(ProfileScreen.settingsButtonKey), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      Colors.transparent,
    );
    final bar = tester.getRect(find.byType(AppBar));
    // D335 (owner 1): the cover is back — none set, so the default Kabso
    // cover; a tap on it changes it.
    expect(find.byKey(ProfileCoverHeader.coverFallbackKey), findsOneWidget);
    expect(find.byKey(ProfileCoverHeader.coverButtonKey), findsOneWidget);
    final cover = tester.getRect(find.byKey(ProfileCoverHeader.coverAreaKey));
    expect(cover.top, 0);
    // D335: the photo at the reading start over the cover's edge; the name
    // and the level badges under it at the start (the @username is the
    // bar's title only); then the bio, the numbers and «Edit profile».
    final photo = tester.getRect(find.byKey(ProfileHeaderView.avatarKey));
    expect(photo.top, greaterThanOrEqualTo(bar.bottom));
    expect(
      photo.center.dx,
      moreOrLessEquals(
        KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2,
        epsilon: 0.5,
      ),
    );
    expect(
      photo.center.dy,
      moreOrLessEquals(cover.bottom - KPublicProfile.avatarLift, epsilon: 0.5),
    );
    final header = tester.getRect(find.byKey(ProfileCoverHeader.headerKey));
    final name = tester.getRect(find.byKey(const Key('profile.displayName')));
    expect(name.top, greaterThan(photo.bottom));
    expect(name.left, moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5));
    expect(find.textContaining('@layla.k'), findsOneWidget);
    final levels = tester.getRect(find.byKey(ProfileInfoBlock.levelsKey));
    expect(levels.top, greaterThanOrEqualTo(name.bottom));
    expect(levels.left, moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5));
    expect(find.text('Music every evening'), findsOneWidget);
    final bio = tester.getRect(find.text('Music every evening'));
    expect(bio.top, greaterThanOrEqualTo(levels.bottom));
    expect(bio.left, moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5));
    final stats = tester.getRect(find.byKey(ProfileScreen.statsKey));
    expect(stats.top, greaterThanOrEqualTo(bio.bottom));
    expect(stats.bottom, lessThanOrEqualTo(header.bottom));
    expect(find.textContaining('5.6K'), findsOneWidget);
    expect(find.text(_en.liveCardFollowers), findsOneWidget);
    final edit = find.byKey(ProfileScreen.editButtonKey);
    expect(
      find.descendant(of: edit, matching: find.text(_en.profileEditShort)),
      findsOneWidget,
    );
    expect(tester.getSize(edit).height, KPublicProfile.buttonHeight);
    expect(tester.getRect(edit).top, greaterThanOrEqualTo(stats.bottom));
    expect(tester.getRect(edit).bottom, lessThanOrEqualTo(header.bottom));
    expect(find.byType(LivePkRecordLine), findsNothing);
  });

  testWidgets('D335: the cover is back on the page; a tap on it (under the '
      'bar) offers «صورة الغلاف» (as D218)', (tester) async {
    await _pump(tester);
    final bar = tester.getRect(find.byType(AppBar));
    await tester.tapAt(Offset(393 - KSpacing.lg, bar.bottom + KSpacing.xs));
    await tester.pumpAndSettle();
    expect(find.byKey(EditProfileScreen.coverLibraryKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the four text tabs: Posts · Reels · Reposts · Saved', (
    tester,
  ) async {
    await _pump(tester);
    for (final word in [
      _en.profileTabPostsWord,
      _en.profileTabReelsWord,
      _en.profileTabRepostsWord,
      _en.profileTabSavedWord,
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ProfileScreen.tabsKey),
          matching: find.text(word),
        ),
        findsOneWidget,
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the edit pill is neutral (D316 / D335: '
        'the chip colour), never the brand colour', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Theme(
            data: buildAppTheme(
              brightness: brightness,
              locale: Localizations.localeOf(context),
            ),
            child: const ProfileScreen(),
          ),
        ),
        overrides: _overrides(),
      );
      await tester.pumpAndSettle();
      // D316: the chip colour (dark: the surface; light: the overlay grey)
      // and the theme's text colour, never the brand colour.
      final palette = brightness == Brightness.dark
          ? KPalette.dark
          : KPalette.light;
      final style = tester
          .widget<OutlinedButton>(find.byKey(ProfileScreen.editButtonKey))
          .style!;
      expect(
        style.backgroundColor!.resolve({}),
        brightness == Brightness.dark
            ? palette.surface
            : palette.surfaceOverlay,
      );
      expect(style.backgroundColor!.resolve({}), isNot(palette.primary));
      expect(style.foregroundColor!.resolve({}), palette.textPrimary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed count shows a dash, not a skeleton', (tester) async {
    await _pump(tester, overrides: _overrides(statsFail: true));
    expect(find.textContaining('\u2013'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(ProfileScreen.statsKey),
        matching: find.byType(KSkeleton),
      ),
      findsNothing,
    );
  });

  testWidgets('a tab without its API (reels): the normal empty state, no '
      '«coming in phase N» note (owner)', (tester) async {
    await _pump(tester);
    expect(find.text(_en.profileNoPosts), findsOneWidget);
    expect(find.text(_en.profileGridEmptyBody), findsOneWidget);
    expect(find.textContaining('Phase'), findsNothing);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.reels)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileNoReels), findsOneWidget);
    expect(find.textContaining('Phase'), findsNothing);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.saved)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileSavedComingTitle), findsOneWidget);
  });

  testWidgets('D59 + KL-060: four tabs in order Posts, Reels, Reposts, '
      "Saved (bookmark), equal widths; Saved has the posts' cells (D335: "
      'square)', (tester) async {
    await _pump(tester, overrides: _overrides(grid: _items(6)));
    expect(ProfileTab.values, [
      ProfileTab.posts,
      ProfileTab.reels,
      ProfileTab.reposts,
      ProfileTab.saved,
    ]);
    final rects = [
      for (final tab in ProfileTab.values)
        tester.getRect(find.byKey(ProfileScreen.tabKey(tab))),
    ];
    for (var i = 0; i < rects.length - 1; i++) {
      expect(rects[i].right, lessThanOrEqualTo(rects[i + 1].left));
    }
    // D335: the tabs 11 dp in from each edge.
    expect(
      rects[3].width,
      moreOrLessEquals((393 - 2 * KProfile.tabsInset) / 4, epsilon: 0.5),
    );
    expect(find.bySemanticsLabel(_en.profileReposts), findsOneWidget);
    expect(find.bySemanticsLabel(_en.profileSaved), findsOneWidget);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.saved)));
    await tester.pumpAndSettle();
    final cell = tester.getRect(
      find
          .descendant(
            of: find.byType(SliverGrid),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(
      cell.height,
      moreOrLessEquals(cell.width / KProfile.postAspect, epsilon: 0.5),
    );
  });

  testWidgets('empty Saved says so', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(grid: const FeedItems<ProfileGridItem>([])),
    );
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.saved)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileNoSaved), findsOneWidget);
    expect(find.text(_en.profileSavedEmptyBody), findsOneWidget);
  });

  testWidgets('empty grids say so', (tester) async {
    await _pump(
      tester,
      overrides: _overrides(grid: const FeedItems<ProfileGridItem>([])),
    );
    expect(find.text(_en.profileNoPosts), findsOneWidget);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.reels)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileNoReels), findsOneWidget);
  });

  testWidgets('D335: 3-column grid 13 dp in from the edges, 3 dp apart, '
      'rounded; square posts, portrait reels; the tabs stay pinned', (
    tester,
  ) async {
    await _pump(tester, overrides: _overrides(grid: _items(12)));
    Rect firstCell() => tester.getRect(
      find
          .descendant(
            of: find.byType(SliverGrid),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    final post = firstCell();
    expect(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ClipRRect &&
              w.borderRadius == BorderRadius.circular(KProfile.gridRadius),
        ),
      ),
      findsWidgets,
    );
    expect(
      post.width,
      moreOrLessEquals(
        (393 - 2 * KProfile.pageGridInset - 2 * KProfile.pageGridGap) / 3,
        epsilon: 0.5,
      ),
    );
    expect(
      post.height,
      moreOrLessEquals(post.width / KProfile.postAspect, epsilon: 0.5),
    );
    // In from the screen's edges.
    final cells = find.descendant(
      of: find.byType(SliverGrid),
      matching: find.byType(ColoredBox),
    );
    final xs = [
      for (final e in cells.evaluate()) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(
      xs.map((r) => r.left).reduce((a, b) => a < b ? a : b),
      moreOrLessEquals(KProfile.pageGridInset, epsilon: 0.5),
    );
    expect(
      xs.map((r) => r.right).reduce((a, b) => a > b ? a : b),
      moreOrLessEquals(393 - KProfile.pageGridInset, epsilon: 0.5),
    );
    final selected = tester.getSemantics(
      find.byKey(ProfileScreen.tabKey(ProfileTab.posts)),
    );
    expect(selected.flagsCollection.isSelected, isNotNull);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.reels)));
    await tester.pumpAndSettle();
    final reel = firstCell();
    expect(reel.height, greaterThan(reel.width * 1.5));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(ProfileScreen.tabsKey)).top,
      greaterThanOrEqualTo(0),
    );
  });

  testWidgets('RTL (D335): the photo at the reading start (right), the '
      'counts centred; Followers at the reading start (right)', (tester) async {
    await _pump(tester, language: AppLanguage.ar);
    final avatar = tester.getRect(find.byKey(ProfileHeaderView.avatarKey));
    final stats = tester.getRect(find.byKey(ProfileScreen.statsKey));
    expect(
      393 - avatar.center.dx,
      moreOrLessEquals(
        KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2,
        epsilon: 0.5,
      ),
    );
    expect(stats.top, greaterThan(avatar.bottom));
    expect(stats.center.dx, moreOrLessEquals(393 / 2, epsilon: 1));
    final followers = tester.getRect(
      find.byKey(ProfileHeaderView.followersKey),
    );
    final following = tester.getRect(
      find.byKey(ProfileHeaderView.followingKey),
    );
    expect(followers.left, greaterThan(following.left));
  });

  for (final language in AppLanguage.values) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('360x800 at $scale (${language.name}): no overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          overrides: _overrides(grid: _items(6)),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  // D168: the edit screen works now (name, bio, photo); its tests are in
  // edit_profile_d168_test.dart (the D58 read-only checks no longer hold).
}
