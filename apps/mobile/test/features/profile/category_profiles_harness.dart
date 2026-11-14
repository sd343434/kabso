// D386: pumps a profile page with a category look (someone else's or one's
// own) over fakes — the shared harness of the D386 tests and goldens.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/profile/category_profile_fixtures.dart';
import '../../helpers/fake_category_profile_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The status bar 59 and the home indicator 34 (the goldens' insets).
void d386Insets(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

List<Override> _common(FakeCategoryProfileRepository repo) => [
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  profileLevelsProvider.overrideWith((ref, _) async => const []),
  profileGridProvider.overrideWith(
    (ref, _) =>
        FeedItems([for (var i = 0; i < 12; i++) const ProfileGridItem()]),
  ),
  categoryProfileRepositoryProvider.overrideWithValue(repo),
];

/// Someone else's page with [profile] and its featured [section].
Future<FakeCategoryProfileRepository> pumpCategoryProfile(
  WidgetTester tester,
  PublicProfile profile, {
  required AppLanguage language,
  ProfileFeatured section = ProfileFeatured.empty,
  Brightness brightness = Brightness.dark,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * GoldenViewport.pixelRatio
    ..devicePixelRatio = GoldenViewport.pixelRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  d386Insets(tester);
  final repo = FakeCategoryProfileRepository(section: section);
  await pumpScreen(
    tester,
    PublicProfileScreen(username: profile.username),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      ..._common(repo),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

/// The person's own page as [user], with [section].
Future<FakeCategoryProfileRepository> pumpOwnCategoryProfile(
  WidgetTester tester,
  User user, {
  required AppLanguage language,
  ProfileFeatured section = ProfileFeatured.empty,
  Brightness brightness = Brightness.dark,
  List<String> pins = const [],
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * GoldenViewport.pixelRatio
    ..devicePixelRatio = GoldenViewport.pixelRatio;
  addTearDown(tester.view.reset);
  d386Insets(tester);
  final repo = FakeCategoryProfileRepository(section: section, pins: pins);
  final ar = language == AppLanguage.ar;
  await pumpScreen(
    tester,
    const ProfileScreen(),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      meProvider.overrideWith((ref) => user),
      profileStatsProvider.overrideWith(
        (ref, username) => d386Profile(
          category: user.category,
          verified: user.categoryVerified,
          ar: ar,
          self: true,
        ),
      ),
      ..._common(repo),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

/// The signed-in person with [category].
User d386Me({
  required bool ar,
  AccountCategory? category,
  bool verified = true,
  bool locked = false,
}) => User(
  id: 'user-386',
  email: 'me386@example.invalid',
  emailVerified: true,
  username: 'kabso386',
  displayName: ar ? 'نور' : 'Noor',
  locale: ar ? 'ar' : 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 3),
  category: category,
  categoryVerified: verified && category != null,
  categoryLocked: locked,
);
