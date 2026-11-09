// D322: the Live hub's top bar after the owner's bar — no party button;
// title · «+» · search · bell (the bell at the reading end); «+» is drawn
// like search and opens go-live directly (owner follow-ups); Moments' «+»
// keeps the create menu (post, reel, story, live).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _bell = Key('notifications.bell');

Future<void> _pumpApp(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  User? user,
  FakeLiveMediaEngine? engine,
  String? theme,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpKabsoApp(
    tester,
    language: language.name,
    liveRepository: engine == null ? null : FakeLiveRepository(),
    liveMediaEngine: engine,
    prefs: {PreferenceKeys.themeMode: ?theme},
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          storedUser: user ?? testUser().copyWith(canHost: true),
        ),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pumpAndSettle();
}

/// Owner follow-up: the hub's «+» is drawn exactly like search beside it.
void expectPlusLikeSearch(WidgetTester tester) {
  AppIcon icon(Key key) => tester.widget<AppIcon>(
    find.descendant(of: find.byKey(key), matching: find.byType(AppIcon)),
  );
  final plus = icon(LiveHubGoLiveButton.buttonKey);
  final search = icon(LiveHubTopBar.searchKey);
  expect(plus.asset, AppIcons.plusOutline);
  expect(plus.size, search.size);
  expect(plus.color, search.color);
  expect(
    plus.color,
    tester.element(find.byType(LiveScreen)).palette.textPrimary,
  );
  // No disc or fill behind it: the same widgets as search's button (an
  // IconButton's own transparent Material only).
  for (final type in [Container, DecoratedBox, Material, Ink, CustomPaint]) {
    int count(Key key) => find
        .descendant(of: find.byKey(key), matching: find.byType(type))
        .evaluate()
        .length;
    expect(
      count(LiveHubGoLiveButton.buttonKey),
      count(LiveHubTopBar.searchKey),
      reason: '$type',
    );
  }
  expect(
    find.descendant(
      of: find.byKey(LiveHubGoLiveButton.buttonKey),
      matching: find.byType(Container),
    ),
    findsNothing,
  );
  final plusButton = tester.widget<IconButton>(
    find.byKey(LiveHubGoLiveButton.buttonKey),
  );
  final searchButton = tester.widget<IconButton>(
    find.byKey(LiveHubTopBar.searchKey),
  );
  expect(plusButton.style, searchButton.style);
  expect(plusButton.constraints, searchButton.constraints);
}

void main() {
  group('Live hub top bar (D322)', () {
    for (final language in AppLanguage.values) {
      final l10n = l10nFor(language);
      testWidgets('${language.name}: no party button; title · «+» · search '
          '· bell toward the reading end; 48 pt targets', (tester) async {
        await _pumpApp(tester, language: language);
        expect(find.byKey(const Key('liveHub.party')), findsNothing);
        final title = tester.getCenter(find.byKey(LiveHubTopBar.titleKey));
        final plus = tester.getRect(find.byKey(LiveHubGoLiveButton.buttonKey));
        final search = tester.getRect(find.byKey(LiveHubTopBar.searchKey));
        final bell = tester.getRect(find.byKey(_bell));
        final xs = [title.dx, plus.center.dx, search.center.dx, bell.center.dx];
        final sorted = [...xs]..sort();
        // Arabic: the title at the right, the bell at the left.
        expect(
          xs,
          language == AppLanguage.ar ? sorted.reversed.toList() : sorted,
        );
        // Search took the party button's place, beside the bell.
        expect((search.center.dx - bell.center.dx).abs(), 48);
        expect((plus.center.dx - search.center.dx).abs(), 48);
        for (final r in [plus, search, bell]) {
          expect(r.size, const Size.square(KSizes.minTouchTarget));
        }
        // Owner follow-up: «+» is a plain outline plus like search — no
        // circle, the same size, stroke and colour.
        expectPlusLikeSearch(tester);
        expect(find.byTooltip(l10n.liveHubGoLive), findsOneWidget);
      });
    }

    for (final theme in ['light', 'dark']) {
      testWidgets("$theme: «+» has the plus of search and the bell's "
          'colour, no circle', (tester) async {
        await _pumpApp(tester, language: AppLanguage.ar, theme: theme);
        expect(
          Theme.of(tester.element(find.byType(LiveScreen))).brightness.name,
          theme,
        );
        expectPlusLikeSearch(tester);
      });
    }

    testWidgets('a Kabso Team account has no «+» (D283: no live)', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        user: testUser().copyWith(
          kabsoTeam: true,
          staff: const KabsoStaffIdentity(
            role: StaffLineRole.moderation,
            regions: [StaffRegion.arabWorld],
          ),
        ),
      );
      expect(find.byKey(LiveHubGoLiveButton.buttonKey), findsNothing);
      expect(find.byKey(LiveHubTopBar.searchKey), findsOneWidget);
    });
  });

  group('«+» opens go-live directly (D322, owner follow-up)', () {
    testWidgets('no menu: go-live opens on its default mode (LIVE); the type '
        'is chosen inside; closing returns to the hub', (tester) async {
      final engine = FakeLiveMediaEngine();
      await _pumpApp(tester, engine: engine);
      await tester.tap(find.byKey(LiveHubGoLiveButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(GoLiveScreen), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(GoLiveScreen))).uri
            .toString(),
        AppRoutes.goLive,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      expect(
        container.read(liveHostControllerProvider).mode,
        LiveRoomMode.solo,
      );
      // The modes are go-live's own, as before.
      expect(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)), findsOneWidget);
      // Full screen: no bottom bar.
      expect(find.byType(KabsoNavBar), findsNothing);
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiveScreen), findsOneWidget);
      expect(find.byType(KabsoNavBar), findsOneWidget);
    });
  });

  group('the other ways in still work (D322)', () {
    testWidgets("Moments' «+» opens the create menu: Post opens Create (full "
        'screen); Close returns to Moments; Go live opens go-live', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(find.byKey(ShellNavKeys.moments));
      await tester.pumpAndSettle();
      expect(find.byKey(FeedScreen.createKey), findsOneWidget);
      await tester.tap(find.byKey(FeedScreen.createKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreateScreen), findsOneWidget);
      expect(find.byType(KabsoNavBar), findsNothing);
      await tester.tap(find.byKey(CreateScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.byType(KabsoNavBar), findsOneWidget);

      await tester.tap(find.byKey(FeedScreen.createKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(CreateMenuSheet.choiceKey(CreateChoice.live)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoLiveScreen), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(GoLiveScreen))).uri
            .toString(),
        AppRoutes.goLive,
      );
    });

    testWidgets('/create still opens as a deep link', (tester) async {
      await _pumpApp(tester);
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .go(AppRoutes.create);
      await tester.pumpAndSettle();
      expect(find.byType(CreateScreen), findsOneWidget);
    });
  });
}
