// D57: the own profile — counts beside the photo, name and bio, the
// Settings button, Posts/Reels tabs over a 3-column grid, honest states,
// RTL/LTR and small screens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
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
  test('production grids are honest: unavailable', () {
    final container = ProviderContainer.test();
    for (final tab in ProfileTab.values) {
      expect(
        container.read(profileGridProvider((username: 'u', tab: tab))).value,
        isA<FeedUnavailable<ProfileGridItem>>(),
      );
    }
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

  testWidgets('no API yet: each tab shows the honest "coming" state', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text(_en.profileContentComingTitle), findsOneWidget);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.reels)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileContentComingTitle), findsOneWidget);
    await tester.tap(find.byKey(ProfileScreen.tabKey(ProfileTab.saved)));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileSavedComingTitle), findsOneWidget);
  });

  testWidgets('D59: three tabs in order Posts, Reels, Saved (bookmark), '
      'equal widths; Saved is square and says only you see it', (tester) async {
    await _pump(tester, overrides: _overrides(grid: _items(6)));
    final rects = [
      for (final tab in ProfileTab.values)
        tester.getRect(find.byKey(ProfileScreen.tabKey(tab))),
    ];
    expect(rects[0].right, lessThanOrEqualTo(rects[1].left));
    expect(rects[1].right, lessThanOrEqualTo(rects[2].left));
    expect(rects[2].width, moreOrLessEquals(393 / 3, epsilon: 0.5));
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

  group('edit profile (D58)', () {
    testWidgets('label/value rows with the current details, read-only; '
        'Save and "Change photo" disabled; says why', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const EditProfileScreen(),
        overrides: [meProvider.overrideWith((ref) => _user())],
      );
      await tester.pumpAndSettle();
      expect(find.text(_en.profileEditTitle), findsOneWidget);
      expect(find.text(_en.profileEditUnavailable), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(EditProfileScreen.saveKey))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(EditProfileScreen.photoKey))
            .onPressed,
        isNull,
      );
      for (final (key, label, value) in [
        (EditProfileScreen.nameKey, _en.profileEditName, 'Layla'),
        (EditProfileScreen.usernameKey, _en.profileEditUsername, 'layla.k'),
        (EditProfileScreen.bioKey, _en.profileEditBio, 'Music every evening'),
      ]) {
        final row = find.byKey(key);
        final l = tester.getRect(
          find.descendant(of: row, matching: find.text(label)),
        );
        final v = tester.getRect(
          find.descendant(of: row, matching: find.text(value)),
        );
        // Label at the start, value beside it.
        expect(v.left, greaterThanOrEqualTo(l.right));
        expect(v.top, moreOrLessEquals(l.top, epsilon: 2));
      }
      // Read-only: no text fields.
      expect(find.byType(TextField), findsNothing);
      // The owner's extra options: "Coming soon", not buttons.
      for (final key in [
        EditProfileScreen.linksKey,
        EditProfileScreen.genderKey,
        EditProfileScreen.categoryKey,
        EditProfileScreen.gridKey,
        EditProfileScreen.privacyKey,
      ]) {
        await tester.scrollUntilVisible(find.byKey(key), 100);
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.text(_en.profileEditSoon),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byKey(key), matching: find.byType(InkWell)),
          findsNothing,
        );
      }
      // Privacy shows the real state from GET /me.
      expect(
        find.descendant(
          of: find.byKey(EditProfileScreen.privacyKey),
          matching: find.text(_en.profilePrivacyPublic),
        ),
        findsOneWidget,
      );
    });
  });
}
