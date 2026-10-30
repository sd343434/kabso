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
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
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

  testWidgets('header: @username title, photo with the counts beside it, '
      'then the name, the bio and "Edit profile"', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile.title'))).data,
      '@layla.k',
    );
    final avatar = tester.getRect(find.byType(KAvatar).first);
    final stats = tester.getRect(find.byKey(ProfileScreen.statsKey));
    expect(stats.left, greaterThan(avatar.right));
    expect(stats.center.dy, moreOrLessEquals(avatar.center.dy, epsilon: 8));
    expect(find.text('5,600'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text(_en.profileFollowers), findsOneWidget);
    expect(find.text(_en.profileFollowingCount), findsOneWidget);
    final name = tester.getRect(find.text('Layla'));
    expect(name.top, greaterThan(avatar.bottom));
    expect(find.text('Music every evening'), findsOneWidget);
    expect(find.byKey(ProfileScreen.editButtonKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ProfileScreen.editButtonKey),
        matching: find.text(_en.profileEditTitle),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(ProfileScreen.editButtonKey)).width,
      393 - 2 * KProfile.inset,
    );
  });

  testWidgets('a failed count shows a dash, not a skeleton', (tester) async {
    await _pump(tester, overrides: _overrides(statsFail: true));
    expect(find.text('–'), findsNWidgets(2));
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
      'Saved (bookmark), equal widths; Saved is square', (tester) async {
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
    expect(rects[3].width, moreOrLessEquals(393 / 4, epsilon: 0.5));
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
    expect(cell.height, moreOrLessEquals(cell.width, epsilon: 0.5));
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

  testWidgets('3-column grid: square posts, portrait reels; the tabs stay '
      'pinned', (tester) async {
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
    expect(post.width, moreOrLessEquals((393 - 2) / 3, epsilon: 0.5));
    expect(post.height, moreOrLessEquals(post.width, epsilon: 0.5));
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

  testWidgets('RTL: the photo at the right, the counts to its left', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    final avatar = tester.getRect(find.byType(KAvatar).first);
    final stats = tester.getRect(find.byKey(ProfileScreen.statsKey));
    expect(avatar.right, moreOrLessEquals(393 - KProfile.inset, epsilon: 1));
    expect(stats.right, lessThan(avatar.left));
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
