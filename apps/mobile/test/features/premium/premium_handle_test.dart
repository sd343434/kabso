// D158 (owner: «عدل يوزر مميز ولا تضع قبله @»): a premium username (D146)
// shows without «@» wherever a handle shows; a regular username keeps it.
// Arabic and English; inside Arabic the handle stays left to right.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/premium/presentation/change_username_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/component_harness.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_premium_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart' show l10nFor, testPrefs;
import 'premium_harness.dart';

const _lri = '\u2066';
const _pdi = '\u2069';

final _regular = User(
  id: '0192f1c2-0000-7000-8000-000000000001',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'sara_2026',
  displayName: 'Sara',
  locale: 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
);

/// The owner, granted the premium username «1» (D146).
final User _premium = _regular.copyWith(
  username: '1',
  premiumTier: PremiumTier.legend,
);

const _gold = UserSummary(
  id: 'u-7777',
  username: '7777',
  displayName: 'Gold',
  avatarUrl: null,
  premiumTier: PremiumTier.gold,
);

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('KHandle', () {
    test('plain: a premium username has no @, a regular one keeps it', () {
      expect(KHandle.plain('1', premiumTier: PremiumTier.legend), '1');
      expect(KHandle.plain('7777', premiumTier: PremiumTier.gold), '7777');
      expect(KHandle.plain('sara_2026'), '@sara_2026');
    });

    test('isolated: both left to right inside Arabic', () {
      expect(
        KHandle.isolated('1', premiumTier: PremiumTier.legend),
        '${_lri}1$_pdi',
      );
      expect(KHandle.isolated('sara_2026'), '$_lri@sara_2026$_pdi');
    });

    for (final l10n in [ar, en]) {
      test('text in ${l10n.localeName}', () {
        expect(
          KHandle.text(l10n, '1', premiumTier: PremiumTier.legend),
          '${_lri}1$_pdi',
        );
        expect(KHandle.text(l10n, 'sara_2026'), contains('@sara_2026'));
        expect(
          KHandle.text(l10n, 'sara_2026'),
          l10n.profileUsername('sara_2026'),
        );
      });
    }
  });

  test('comments and stories: a premium mention shows without @', () {
    const mentions = [_gold, _omar];
    expect(
      isolateHandles('شكراً @7777 و @omar', mentions: mentions),
      'شكراً ${_lri}7777$_pdi و $_lri@omar$_pdi',
    );
    // A sentence's full stop stays outside the handle.
    expect(isolateHandles('@7777.', mentions: mentions), '${_lri}7777$_pdi.');
    // Without the mention's data nothing is guessed: «@» stays.
    expect(isolateHandles('@7777'), '$_lri@7777$_pdi');
  });

  test('the premium strings: no @ before the premium name, @ before the '
      'regular one (Arabic and English)', () {
    for (final l10n in [ar, en]) {
      for (final s in [
        l10n.premiumRented('1'),
        l10n.premiumRenewed('1'),
        l10n.premiumBadgeLabel('Legend', '1'),
        l10n.changeUsernameRentInstead('7777'),
        l10n.notificationPremiumExpiring('1', '3'),
        l10n.notificationPremiumExpired('1'),
      ]) {
        expect(s, isNot(contains('@')), reason: s);
      }
      for (final s in [
        l10n.premiumReleaseBody('1', 'sara_2026'),
        l10n.changeUsernamePremiumActive('1', 'sara_2026'),
      ]) {
        expect(s, isNot(contains('@1')), reason: s);
        expect(s, contains('@sara_2026'), reason: s);
      }
      expect(
        l10n.goLiveShareText(
          'Hi',
          KHandle.plain('1', premiumTier: _gold.premiumTier),
        ),
        isNot(contains('@')),
      );
      expect(
        l10n.goLiveShareText('Hi', KHandle.plain('sara_2026')),
        contains('@sara_2026'),
      );
    }
    // In Arabic the premium name sits in a left-to-right isolate.
    expect(ar.premiumRented('1'), contains('${_lri}1$_pdi'));
  });

  test('follow rows read the premium tier (for the chat they open)', () {
    final item = FollowListItem.fromJson(const {
      'id': 'u-1',
      'username': '1',
      'displayName': 'Owner',
      'avatarUrl': null,
      'premiumTier': 'LEGEND',
    });
    expect(item.premiumTier, PremiumTier.legend);
    expect(
      item.withFollowedByMe(followedByMe: true).premiumTier,
      PremiumTier.legend,
    );
  });

  for (final lang in AppLanguage.values) {
    final l10n = l10nFor(lang);

    testWidgets('Settings › Username (${lang.name}): premium without @', (
      tester,
    ) async {
      final premium = FakePremiumRepository(user: _premium);
      await pumpPremium(
        tester,
        const SettingsScreen(),
        premium: premium,
        language: lang,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await testPrefs(language: lang.name),
          ),
          sessionControllerProvider.overrideWith(() => FixedSession(_premium)),
        ],
      );
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.usernameKey),
        200,
      );
      final row = find.byKey(SettingsScreen.usernameKey);
      expect(
        find.descendant(of: row, matching: find.text('${_lri}1$_pdi')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('@')),
        findsNothing,
      );
    });

    testWidgets('Settings › Username (${lang.name}): regular keeps @', (
      tester,
    ) async {
      final premium = FakePremiumRepository(user: _regular);
      await pumpPremium(
        tester,
        const SettingsScreen(),
        premium: premium,
        language: lang,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await testPrefs(language: lang.name),
          ),
          sessionControllerProvider.overrideWith(() => FixedSession(_regular)),
        ],
      );
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.usernameKey),
        200,
      );
      expect(
        find.descendant(
          of: find.byKey(SettingsScreen.usernameKey),
          matching: find.text('$_lri@sara_2026$_pdi'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Change username (${lang.name}): the premium badge is read '
        'without @', (tester) async {
      final handle = tester.ensureSemantics();
      final premium = FakePremiumRepository(user: _premium);
      await pumpPremium(
        tester,
        const ChangeUsernameScreen(),
        premium: premium,
        language: lang,
        overrides: [
          sessionControllerProvider.overrideWith(() => FixedSession(_premium)),
        ],
      );
      expect(find.byType(KSpecialUsername), findsOneWidget);
      expect(find.bySemanticsLabel('1'), findsOneWidget);
      expect(find.bySemanticsLabel('@1'), findsNothing);
      handle.dispose();
    });

    testWidgets('Chat header (${lang.name}): premium without @, regular '
        'with @', (tester) async {
      await pumpPremium(
        tester,
        const ChatScreen(
          username: '1',
          displayName: 'Owner',
          premiumTier: PremiumTier.legend,
        ),
        premium: FakePremiumRepository(user: _regular),
        language: lang,
        // D155: the conversation reads the DM API (a fake here).
        overrides: [
          dmRepositoryProvider.overrideWithValue(FakeDmRepository()),
          sharedPreferencesProvider.overrideWithValue(await testPrefs()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('${_lri}1$_pdi'), findsNWidgets(2));
      expect(find.textContaining('@1'), findsNothing);

      await pumpPremium(
        tester,
        const ChatScreen(username: 'sara_2026', displayName: 'Sara'),
        premium: FakePremiumRepository(user: _regular),
        language: lang,
        overrides: [
          dmRepositoryProvider.overrideWithValue(FakeDmRepository()),
          sharedPreferencesProvider.overrideWithValue(await testPrefs()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.profileUsername('sara_2026')), findsNWidgets(2));
    });

    testWidgets('Live username tag (${lang.name}): shown, read and copied '
        'without @ for a premium username', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const Center(
          child: KLiveUsernameTag(
            username: '1',
            premiumTier: PremiumTier.legend,
          ),
        ),
        language: lang,
      );
      expect(
        find.bySemanticsLabel('1. ${l10n.liveRoomIdCopyHint}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(KLiveUsernameTag.tagKey));
      await tester.pump();
      expect(copied, '1');
      await tester.pump(const Duration(seconds: 5));

      await pumpComponent(
        tester,
        const Center(child: KLiveUsernameTag(username: 'sara_2026')),
        language: lang,
      );
      expect(find.textContaining('@sara_2026'), findsOneWidget);
      await tester.tap(find.byKey(KLiveUsernameTag.tagKey));
      await tester.pump();
      expect(copied, '@sara_2026');
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    });

    testWidgets('Post caption (${lang.name}): a premium mention without @, '
        'a regular one with @', (tester) async {
      final post = feedPostOf(
        testPost('p1', text: 'Hi @7777 and @omar', mentions: [_gold, _omar]),
      );
      expect(post.premiumMentions, {'7777'});
      final prefs = await testPrefs(language: lang.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(_regular),
          ],
          child: MaterialApp(
            locale: lang.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.light,
              locale: lang.locale,
            ),
            home: Scaffold(
              body: ListView(children: [FeedPostTile(post: post)]),
            ),
          ),
        ),
      );
      await tester.pump();
      final caption = find.textContaining(
        '${_lri}7777$_pdi and $_lri@omar$_pdi',
        findRichText: true,
      );
      expect(caption, findsOneWidget);
      expect(find.textContaining('@7777', findRichText: true), findsNothing);
    });
  }
}
