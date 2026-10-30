// D175 (owner, contract v1.47-social, CONVENTIONS §10.43): profile fields,
// private accounts and follow requests in the app —
// 1. Register asks the gender (required, «أفضّل عدم الذكر» offered);
// 2. Edit profile: gender (+ show on profile), category, links (https,
//    up to 3) are real editors; the grid row is the pin hint;
// 3. profiles show the category under the name, a shown gender and the
//    links; a known platform opens directly, any other link after
//    «أنت تغادر Kabso» with the full URL; links can be reported;
// 4. privacy: the private switch (asks before going public) and the
//    follow-requests screen (accept / decline / empty);
// 5. notifications FOLLOW_REQUEST, FOLLOW_REQUEST_ACCEPTED, AVATAR_REMOVED;
// 6. a follow list row says "Requested";
// RTL / LTR and 360×800 at ×1.3.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_requests_repository.dart';
import 'package:kabso_live/features/follows/presentation/follow_requests_screen.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_fields_edit.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../premium/premium_harness.dart' show FixedSession;

const _insta = ProfileLink(
  id: '0192f1d0-7777-7000-8000-000000000001',
  url: 'https://www.instagram.com/sara',
  label: 'Instagram',
  platform: ProfileLinkPlatform.instagram,
);
const _other = ProfileLink(
  id: '0192f1d0-7777-7000-8000-000000000002',
  url: 'https://shop.example.com/sara?ref=profile',
  platform: ProfileLinkPlatform.other,
);

/// Answers `PATCH /me` like the server for the profile fields.
class _FakeEdit implements ProfileEditRepository {
  new(this.user);

  User user;
  final List<Map<String, Object?>> changes = [];
  AppFailure? failWith;

  @override
  Future<User> updateProfileFields(ProfileFieldsChange change) async {
    changes.add(change.toJson());
    if (failWith case final f?) {
      failWith = null;
      throw f;
    }
    var next = user;
    if (change.gender case final g?) next = next.copyWith(gender: g);
    if (change.showGender case final s?) next = next.copyWith(showGender: s);
    if (change.clearCategory) next = next.copyWith(category: null);
    if (change.category case final c?) next = next.copyWith(category: c);
    if (change.links case final links?) {
      next = next.copyWith(
        links: [
          for (final (i, l) in links.indexed)
            ProfileLink(
              id: 'link-$i',
              url: l.url,
              label: (l.label?.isEmpty ?? true) ? null : l.label,
              platform: l.url.contains('instagram.com')
                  ? ProfileLinkPlatform.instagram
                  : ProfileLinkPlatform.other,
            ),
        ],
      );
    }
    return user = next;
  }

  @override
  Future<User> updateDisplayName(String displayName) async => user;

  @override
  Future<User> updateBio(String? bio) async => user;

  @override
  Future<String> setAvatar(String mediaId) async => '';

  @override
  Future<void> removeAvatar() async {}
}

class _FakeOpener implements ExternalLinkOpener {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

class _FakeRequests implements FollowRequestsRepository {
  new(this.users);

  final List<UserSummary> users;
  final List<String> calls = [];

  @override
  Future<FollowRequestPage> list({String? cursor}) async {
    calls.add('list');
    return FollowRequestPage(
      [
        for (final u in users)
          FollowRequest(user: u, requestedAt: DateTime.utc(2026, 10, 30, 9)),
      ],
      const PageInfo(nextCursor: null, hasMore: false),
      users.length,
    );
  }

  @override
  Future<int> accept(String username) async {
    calls.add('accept:$username');
    users.removeWhere((u) => u.username == username);
    return 42;
  }

  @override
  Future<void> decline(String username) async {
    calls.add('decline:$username');
    users.removeWhere((u) => u.username == username);
  }
}

User _me() => testUser().copyWith(
  gender: Gender.female,
  category: AccountCategory.poet,
  links: const [_insta],
);

Future<_FakeEdit> _pumpEdit(
  WidgetTester tester, {
  User? user,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  FakeSafetyRepository? safety,
}) async {
  final start = user ?? _me();
  final repo = _FakeEdit(start);
  final router = GoRouter(
    initialLocation: AppRoutes.editProfile,
    routes: [
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, _) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.followRequests,
        builder: (_, _) => const Text('page requests'),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        sessionControllerProvider.overrideWith(() => FixedSession(start)),
        meProvider.overrideWith((ref) => start),
        profileStatsProvider.overrideWith((ref, _) => apiProfile(isSelf: true)),
        profileEditRepositoryProvider.overrideWithValue(repo),
        safetyRepositoryProvider.overrideWithValue(
          safety ?? FakeSafetyRepository(),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _inRow(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

Future<(FakeProfileRepository, FakeSafetyRepository, _FakeOpener)> _pumpPublic(
  WidgetTester tester,
  PublicProfile profile, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final repo = FakeProfileRepository(profile);
  final safety = FakeSafetyRepository();
  final opener = _FakeOpener();
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const PublicProfileScreen(username: 'host0'),
    language: language,
    overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(repo),
      safetyRepositoryProvider.overrideWithValue(safety),
      externalLinkOpenerProvider.overrideWithValue(opener),
      profileGridProvider.overrideWith(
        (ref, _) =>
            FeedItems([for (var i = 0; i < 6; i++) const ProfileGridItem()]),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return (repo, safety, opener);
}

void main() {
  group('1. Register asks the gender', () {
    for (final language in AppLanguage.values) {
      testWidgets('required, three choices, sent with register '
          '(${language.name})', (tester) async {
        final l10n = l10nFor(language);
        final repo = FakeAuthRepository();
        await pumpScreen(
          tester,
          const RegisterScreen(),
          language: language,
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
        );
        for (final g in Gender.values) {
          expect(find.byKey(RegisterScreen.genderOptionKey(g)), findsOneWidget);
        }
        expect(find.text(l10n.genderUndisclosed), findsOneWidget);
        await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
        await tester.enterText(
          find.byKey(RegisterScreen.usernameKey),
          'layla_22',
        );
        await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
        await tester.enterText(
          find.byKey(RegisterScreen.passwordKey),
          'pa55word!',
        );
        await tester.pump();
        await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
        await tester.tap(find.byKey(RegisterScreen.submitKey));
        await tester.pumpAndSettle();
        expect(repo.registerCalls, 0);
        expect(find.text(l10n.registerGenderRequired), findsOneWidget);
        await chooseGender(tester, Gender.male);
        expect(find.text(l10n.registerGenderRequired), findsNothing);
        await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
        await tester.tap(find.byKey(RegisterScreen.submitKey));
        await tester.pumpAndSettle();
        expect(repo.registerCalls, 1);
        expect(repo.registerGenders, [Gender.male]);
      });
    }
  });

  group('2. Edit profile', () {
    for (final language in AppLanguage.values) {
      testWidgets('rows show the values; gender hidden by default; the pin '
          'hint; Privacy opens the settings (${language.name})', (
        tester,
      ) async {
        final l10n = l10nFor(language);
        await _pumpEdit(tester, language: language);
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.categoryKey),
          100,
        );
        expect(
          _inRow(EditProfileScreen.linksKey, l10n.profileEditLinksValue(1)),
          findsOneWidget,
        );
        expect(
          _inRow(
            EditProfileScreen.genderKey,
            l10n.profileEditGenderHidden(l10n.genderFemale),
          ),
          findsOneWidget,
        );
        expect(
          _inRow(EditProfileScreen.categoryKey, l10n.categoryPoet),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.privacyKey),
          100,
        );
        expect(find.text(l10n.profileEditPinHint), findsOneWidget);
        await tester.tap(find.byKey(EditProfileScreen.privacyKey));
        await tester.pumpAndSettle();
        expect(find.byKey(PrivacyScreen.privateKey), findsOneWidget);
      });
    }

    testWidgets('gender: choose and show on the profile → one PATCH', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      final repo = await _pumpEdit(tester, user: testUser());
      expect(
        _inRow(EditProfileScreen.genderKey, l10n.profileEditNotSet),
        findsOneWidget,
      );
      await tester.tap(find.byKey(EditProfileScreen.genderKey));
      await tester.pumpAndSettle();
      // Nothing chosen yet: Save waits for a choice.
      expect(
        tester
            .widget<KButton>(find.byKey(EditProfileFieldsKeys.genderSave))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(EditProfileFieldsKeys.gender(Gender.male)));
      await tester.tap(find.byKey(EditProfileFieldsKeys.genderShow));
      await tester.pump();
      await tester.tap(find.byKey(EditProfileFieldsKeys.genderSave));
      await tester.pumpAndSettle();
      expect(repo.changes, [
        {'gender': 'MALE', 'showGender': true},
      ]);
      expect(
        _inRow(EditProfileScreen.genderKey, l10n.genderMale),
        findsOneWidget,
      );
    });

    testWidgets('category: a choice saves at once; "No category" clears', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.ar);
      final repo = await _pumpEdit(tester, language: AppLanguage.ar);
      await tester.tap(find.byKey(EditProfileScreen.categoryKey));
      await tester.pumpAndSettle();
      for (final c in AccountCategory.values.take(4)) {
        expect(find.byKey(EditProfileFieldsKeys.category(c)), findsOneWidget);
      }
      await tester.tap(
        find.byKey(EditProfileFieldsKeys.category(AccountCategory.singer)),
      );
      await tester.pumpAndSettle();
      expect(repo.changes.last, {'category': 'SINGER'});
      expect(
        _inRow(EditProfileScreen.categoryKey, l10n.categorySinger),
        findsOneWidget,
      );
      await tester.tap(find.byKey(EditProfileScreen.categoryKey));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(EditProfileFieldsKeys.categoryNone),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(EditProfileFieldsKeys.categoryNone));
      await tester.pumpAndSettle();
      expect(repo.changes.last, {'category': null});
      expect(
        _inRow(EditProfileScreen.categoryKey, l10n.profileEditNotSet),
        findsOneWidget,
      );
    });

    testWidgets('links: checks before saving (https, duplicates, label), '
        'sends the whole set, shows server field errors', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final repo = await _pumpEdit(tester);
      await tester.tap(find.byKey(EditProfileScreen.linksKey));
      await tester.pumpAndSettle();
      expect(find.text('https://www.instagram.com/sara'), findsOneWidget);
      await tester.tap(find.byKey(EditProfileFieldsKeys.linkAdd));
      await tester.pump();
      await tester.enterText(
        find.byKey(EditProfileFieldsKeys.linkUrl(1)),
        'http://example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pump();
      expect(find.text(l10n.profileEditLinkInvalid), findsOneWidget);
      expect(repo.changes, isEmpty);
      for (final bad in [
        'https://127.0.0.1/a',
        'https://user:pw@example.com',
        'https://example.com:8080',
      ]) {
        await tester.enterText(
          find.byKey(EditProfileFieldsKeys.linkUrl(1)),
          bad,
        );
        await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
        await tester.pump();
        expect(find.text(l10n.profileEditLinkInvalid), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(EditProfileFieldsKeys.linkUrl(1)),
        'https://www.instagram.com/sara',
      );
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pump();
      expect(find.text(l10n.profileEditLinkDuplicate), findsOneWidget);
      await tester.enterText(
        find.byKey(EditProfileFieldsKeys.linkUrl(1)),
        'https://shop.example.com/sara',
      );
      await tester.enterText(
        find.byKey(EditProfileFieldsKeys.linkLabel(1)),
        'x' * 31,
      );
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pump();
      expect(find.text(l10n.profileEditLinkLabelTooLong(30)), findsOneWidget);
      await tester.enterText(
        find.byKey(EditProfileFieldsKeys.linkLabel(1)),
        'Shop',
      );
      // The server refuses the second link: its error shows under it.
      repo.failWith = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'bad link',
        statusCode: 400,
        details: [FieldIssue(field: 'links.1.url', issue: 'too_long')],
      );
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.profileEditLinkTooLong), findsOneWidget);
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pumpAndSettle();
      expect(repo.changes.last, {
        'links': [
          {'url': 'https://www.instagram.com/sara', 'label': 'Instagram'},
          {'url': 'https://shop.example.com/sara', 'label': 'Shop'},
        ],
      });
      // Back on Edit profile with the new count.
      expect(
        _inRow(EditProfileScreen.linksKey, l10n.profileEditLinksValue(2)),
        findsOneWidget,
      );
      // Removing every link sends an empty set.
      await tester.tap(find.byKey(EditProfileScreen.linksKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditProfileFieldsKeys.linkRemove(1)));
      await tester.pump();
      await tester.tap(find.byKey(EditProfileFieldsKeys.linkRemove(0)));
      await tester.pump();
      await tester.tap(find.byKey(EditProfileFieldsKeys.linksSave));
      await tester.pumpAndSettle();
      expect(repo.changes.last, {'links': <Object>[]});
    });

    for (final language in AppLanguage.values) {
      testWidgets('360×800 at ×1.3: no overflow (${language.name})', (
        tester,
      ) async {
        await _pumpEdit(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.privacyKey),
          100,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(EditProfileScreen.genderKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('3. profiles show the fields; links open safely', () {
    PublicProfile withFields({bool private = false}) =>
        apiProfile(isPrivate: private).copyWith(
          category: AccountCategory.singer,
          gender: Gender.female,
          links: const [_insta, _other],
        );

    for (final language in AppLanguage.values) {
      testWidgets('category and gender under the name, links after the bio '
          '(${language.name})', (tester) async {
        final l10n = l10nFor(language);
        await _pumpPublic(tester, withFields(), language: language);
        expect(
          find.text('${l10n.categorySinger} · ${l10n.genderFemale}'),
          findsOneWidget,
        );
        expect(find.byKey(ProfileLinkKeys.chip(0)), findsOneWidget);
        expect(find.text('Instagram'), findsOneWidget);
        expect(find.text('shop.example.com/sara'), findsOneWidget);
        // A web address reads left to right in Arabic too.
        final address = tester.widget<Text>(find.text('shop.example.com/sara'));
        expect(address.textDirection, TextDirection.ltr);
      });
    }

    testWidgets('a known platform opens directly; another link only after '
        '«You are leaving Kabso» with the full URL', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final (_, _, opener) = await _pumpPublic(tester, withFields());
      await tester.tap(find.byKey(ProfileLinkKeys.chip(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileLinkKeys.leavingSheet), findsNothing);
      expect(opener.opened, [Uri.parse('https://www.instagram.com/sara')]);
      await tester.tap(find.byKey(ProfileLinkKeys.chip(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileLinkKeys.leavingSheet), findsOneWidget);
      expect(find.text(l10n.linkLeavingTitle), findsOneWidget);
      expect(
        find.text('https://shop.example.com/sara?ref=profile'),
        findsOneWidget,
      );
      expect(opener.opened, hasLength(1));
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));
      await tester.tap(find.byKey(ProfileLinkKeys.chip(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileLinkKeys.leavingOpen));
      await tester.pumpAndSettle();
      expect(opener.opened.last.toString(), _other.url);
    });

    testWidgets('a link is reported from the warning or a long press', (
      tester,
    ) async {
      final (_, safety, _) = await _pumpPublic(tester, withFields());
      await tester.tap(find.byKey(ProfileLinkKeys.chip(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileLinkKeys.report));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(safety.calls, ['reportLink:${_other.id}:SPAM']);
      await tester.longPress(find.byKey(ProfileLinkKeys.chip(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileLinkKeys.copy), findsOneWidget);
      await tester.tap(find.byKey(ProfileLinkKeys.report));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.other')));
      await tester.pumpAndSettle();
      expect(safety.calls.last, 'reportLink:${_insta.id}:OTHER');
    });

    for (final language in AppLanguage.values) {
      testWidgets('a private profile a non-follower sees: header, fields and '
          'links, «هذا الحساب خاص», no grid; 360×800 ×1.3 '
          '(${language.name})', (tester) async {
        final l10n = l10nFor(language);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpPublic(
          tester,
          withFields(private: true),
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(find.text(l10n.profilePrivateTitle), findsOneWidget);
        expect(find.byType(SliverGrid), findsNothing);
        expect(find.byKey(ProfileLinkKeys.chip(0)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('4. privacy and follow requests', () {
    testWidgets('the private switch: on at once; off asks first', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      final safety = FakeSafetyRepository();
      await _pumpEdit(tester, safety: safety);
      await tester.scrollUntilVisible(
        find.byKey(EditProfileScreen.privacyKey),
        100,
      );
      await tester.tap(find.byKey(EditProfileScreen.privacyKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PrivacyScreen.privateKey));
      await tester.pumpAndSettle();
      expect(safety.calls.last, 'updatePrivacy:::private=true');
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(PrivacyScreen.privateKey))
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(PrivacyScreen.privateKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.privacyMakePublicTitle), findsOneWidget);
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(safety.calls.last, 'updatePrivacy:::private=true');
      await tester.tap(find.byKey(PrivacyScreen.privateKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PrivacyScreen.makePublicKey));
      await tester.pumpAndSettle();
      expect(safety.calls.last, 'updatePrivacy:::private=false');
      await tester.tap(find.byKey(PrivacyScreen.followRequestsKey));
      await tester.pumpAndSettle();
      expect(find.text('page requests'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('follow requests: accept and decline take the row away; '
          'then the empty state (${language.name})', (tester) async {
        final l10n = l10nFor(language);
        final repo = _FakeRequests([
          const UserSummary(
            id: 'u1',
            username: 'omar_7',
            displayName: 'عمر',
            avatarUrl: null,
          ),
          const UserSummary(
            id: 'u2',
            username: 'nour_8',
            displayName: 'Nour',
            avatarUrl: null,
          ),
        ]);
        await pumpScreen(
          tester,
          const FollowRequestsScreen(),
          language: language,
          overrides: [followRequestsRepositoryProvider.overrideWithValue(repo)],
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.followRequestsTitle), findsOneWidget);
        expect(find.text('عمر'), findsOneWidget);
        await tester.tap(find.byKey(FollowRequestsScreen.acceptKey('omar_7')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('accept:omar_7'));
        expect(find.text('عمر'), findsNothing);
        await tester.tap(find.byKey(FollowRequestsScreen.declineKey('nour_8')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('decline:nour_8'));
        expect(find.byKey(FollowRequestsScreen.emptyKey), findsOneWidget);
        expect(find.text(l10n.followRequestsEmptyTitle), findsOneWidget);
      });
    }
  });

  group('5. notifications', () {
    const omar = UserSummary(
      id: 'u1',
      username: 'omar_7',
      displayName: 'Omar',
      avatarUrl: null,
    );
    AppNotification note(NotificationType type, {bool actor = true}) =>
        AppNotification(
          id: 'n-${type.wire}',
          type: type,
          actors: actor ? const [omar] : const [],
          actorCount: actor ? 1 : 0,
          target: actor
              ? const NotificationTarget(
                  type: NotificationTargetType.user,
                  id: 'omar_7',
                )
              : null,
          createdAt: DateTime.now(),
          read: false,
        );

    test('wire values', () {
      expect(
        NotificationType.fromWire('FOLLOW_REQUEST'),
        NotificationType.followRequest,
      );
      expect(
        NotificationType.fromWire('FOLLOW_REQUEST_ACCEPTED'),
        NotificationType.followRequestAccepted,
      );
      expect(
        NotificationType.fromWire('AVATAR_REMOVED'),
        NotificationType.avatarRemoved,
      );
      expect(NotificationType.avatarRemoved.isSystem, isTrue);
      expect(NotificationType.followRequest.isSystem, isFalse);
    });

    for (final language in AppLanguage.values) {
      testWidgets('texts and where they lead (${language.name})', (
        tester,
      ) async {
        final l10n = l10nFor(language);
        final items = [
          note(NotificationType.followRequest),
          note(NotificationType.followRequestAccepted),
          note(NotificationType.avatarRemoved, actor: false),
        ];
        await pumpScreen(
          tester,
          Scaffold(
            body: ListView(
              children: [for (final n in items) NotificationRow(item: n)],
            ),
          ),
          language: language,
        );
        await tester.pumpAndSettle();
        String plain(String s) => s.replaceAll(RegExp('[\u2068\u2069]'), '');
        final texts = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((r) => plain(r.text.toPlainText()))
            .join('\n');
        expect(texts, contains(plain(l10n.notifFollowRequest('Omar'))));
        expect(texts, contains(plain(l10n.notifFollowRequestAccepted('Omar'))));
        expect(texts, contains(l10n.notifAvatarRemoved));
        expect(
          NotificationRow(item: items[0]).routeTo(),
          AppRoutes.followRequests,
        );
        expect(
          NotificationRow(item: items[1]).routeTo(),
          AppRoutes.userProfile('omar_7'),
        );
        expect(
          NotificationRow(item: items[2]).routeTo(),
          AppRoutes.editProfile,
        );
      });
    }
  });

  group('6. links model', () {
    test('wire: unknown platform reads as OTHER; display and host', () {
      final link = ProfileLink.fromJson(const {
        'id': 'x',
        'url': 'https://www.example.com/a/b',
        'label': null,
        'platform': 'MYSPACE',
      });
      expect(link.platform, ProfileLinkPlatform.other);
      expect(link.platform.known, isFalse);
      expect(link.display, 'example.com/a/b');
      expect(ProfileLinkPlatform.fromWire('TIKTOK').known, isTrue);
      expect(Gender.fromWire('NOPE'), isNull);
      expect(AccountCategory.fromWire('POET'), AccountCategory.poet);
    });

    test('the app-side link checks mirror the server', () {
      for (final ok in [
        'https://example.com',
        'https://www.instagram.com/a?b=1',
        'https://example.com:443/a',
      ]) {
        expect(ProfileLinkRules.issue(ok), isNull, reason: ok);
      }
      for (final bad in [
        'http://example.com',
        'javascript:alert(1)',
        'https://a:b@example.com',
        'https://example.com:8080',
        'https://10.0.0.1',
        'https://[::1]',
        'https://localhost',
        'https://exa mple.com',
        'https://example.com/\u202e',
        'https://example.123',
      ]) {
        expect(ProfileLinkRules.issue(bad), 'invalid_format', reason: bad);
      }
      expect(
        ProfileLinkRules.issue('https://example.com/${'a' * 500}'),
        'too_long',
      );
    });
  });
}
