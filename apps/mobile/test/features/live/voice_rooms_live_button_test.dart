// D139: the Live button in the voice rooms' top bar (the mirror of the
// hub's party button) returns to the live hub.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _bell = Key('notifications.bell');

Future<void> _pumpApp(WidgetTester tester, AppLanguage language) async {
  await pumpKabsoApp(
    tester,
    language: language.name,
    liveRepository: FakeLiveRepository(
      rooms: (r) => apiPage([
        for (final room in apiRooms(4))
          if (r.kind == LiveRoomsKind.audio)
            room.copyWith(mode: LiveRoomMode.audio)
          else
            room,
      ]),
    ),
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

/// Opens the voice rooms the way the owner does: the hub's party button.
Future<void> _openFromHub(WidgetTester tester) async {
  await tester.tap(find.byKey(LiveHubPartyButton.buttonKey));
  await tester.pumpAndSettle();
  expect(find.byType(VoiceRoomsScreen), findsOneWidget);
}

void main() {
  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    group('${language.name}: voice rooms Live button (D139)', () {
      testWidgets("in the party button's place: between search and the "
          'bell, 48 pt, the Live icon, labelled', (tester) async {
        await _pumpApp(tester, language);
        final hubParty = tester.getRect(
          find.byKey(LiveHubPartyButton.buttonKey),
        );
        final hubBell = tester.getRect(find.byKey(_bell));
        final partySize = tester
            .widget<KPartyIcon>(find.byType(KPartyIcon))
            .size;
        await _openFromHub(tester);

        final button = find.byKey(VoiceRoomsLiveButton.buttonKey);
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.byType(KLiveIcon)),
          findsOneWidget,
        );
        expect(
          tester.widget<KLiveIcon>(find.byType(KLiveIcon)).size,
          partySize,
        );
        final rect = tester.getRect(button);
        final bell = tester.getRect(find.byKey(_bell).last);
        expect(rect.size, const Size.square(KSizes.minTouchTarget));
        expect(rect.size, bell.size);
        expect(rect.center.dy, bell.center.dy);
        // Beside the bell on its reading-start side, like the party
        // button on the hub (mirrored in Arabic).
        expect(
          rect.center.dx - bell.center.dx,
          hubParty.center.dx - hubBell.center.dx,
        );
        if (language == AppLanguage.ar) {
          expect(rect.center.dx, greaterThan(bell.center.dx));
        } else {
          expect(rect.center.dx, lessThan(bell.center.dx));
        }
        // Search is on its other side; the back arrow stays.
        final search = tester.getRect(
          find.descendant(
            of: find.byType(VoiceRoomsScreen),
            matching: find.byTooltip(l10n.feedSearch),
          ),
        );
        expect((search.center.dx - rect.center.dx).abs(), 48);
        expect(
          (search.center.dx - bell.center.dx).abs(),
          greaterThan((rect.center.dx - bell.center.dx).abs()),
        );
        expect(find.byKey(VoiceRoomsScreen.backKey), findsOneWidget);

        expect(
          find.bySemanticsLabel(l10n.liveVoiceRoomsToLive),
          findsOneWidget,
        );
        expect(find.byTooltip(l10n.liveVoiceRoomsToLive), findsOneWidget);
      });

      testWidgets('opened from the hub: a tap plays the house, then pops '
          'back to the hub', (tester) async {
        await _pumpApp(tester, language);
        await _openFromHub(tester);
        expect(_router(tester).canPop(), isTrue);

        await tester.tap(find.byKey(VoiceRoomsLiveButton.buttonKey));
        await tester.pump();
        // The house plays first; the hub comes back after the lead.
        expect(
          tester.state<KLiveIconState>(find.byType(KLiveIcon)).playing,
          isTrue,
        );
        // Still on the voice rooms: nothing popped yet.
        expect(_router(tester).canPop(), isTrue);
        expect(find.byType(VoiceRoomsScreen), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsNothing);
        expect(find.byType(LiveScreen), findsOneWidget);
        expect(_location(tester), AppRoutes.home);
        // A pop: nothing left above the hub.
        expect(_router(tester).canPop(), isFalse);
      });

      testWidgets('opened with nothing under it: goes to the hub', (
        tester,
      ) async {
        await _pumpApp(tester, language);
        _router(tester).go(AppRoutes.voiceRooms);
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsOneWidget);
        expect(_router(tester).canPop(), isFalse);

        await tester.tap(find.byKey(VoiceRoomsLiveButton.buttonKey));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsNothing);
        expect(find.byType(LiveScreen), findsOneWidget);
        expect(_location(tester), AppRoutes.home);
      });

      testWidgets('opened over another page (not the hub): goes to the hub, '
          'not to that page', (tester) async {
        await _pumpApp(tester, language);
        await _openFromHub(tester);
        // push() completes when the page pops: not awaited.
        unawaited(_router(tester).push<void>(AppRoutes.voiceRooms));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsOneWidget);

        await tester.tap(find.byKey(VoiceRoomsLiveButton.buttonKey));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsNothing);
        expect(find.byType(LiveScreen), findsOneWidget);
        expect(_location(tester), AppRoutes.home);
        expect(_router(tester).canPop(), isFalse);
      });

      testWidgets('reduced motion: no animation, the hub comes back at once', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _pumpApp(tester, language);
        await _openFromHub(tester);

        await tester.tap(find.byKey(VoiceRoomsLiveButton.buttonKey));
        // No lead: the pop happens with the tap.
        expect(_router(tester).canPop(), isFalse);
        expect(
          tester.state<KLiveIconState>(find.byType(KLiveIcon)).playing,
          isFalse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiveScreen), findsOneWidget);
      });

      testWidgets('360×800 at text ×1.3 (real fonts): no overflow, the '
          'button on screen, the three tabs whole beside it', (tester) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await loadAppFonts();
        await _pumpApp(tester, language);
        await _openFromHub(tester);
        expect(tester.takeException(), isNull);
        final back = tester.getRect(find.byKey(VoiceRoomsScreen.backKey));
        final search = tester.getRect(
          find.descendant(
            of: find.byType(VoiceRoomsScreen),
            matching: find.byTooltip(l10n.feedSearch),
          ),
        );
        // The tabs sit whole between the back arrow and search (they
        // shrink to fit rather than scroll out of sight).
        for (final t in FeedTab.values) {
          final tab = tester.getRect(find.byKey(VoiceRoomsScreen.tabKey(t)));
          if (language == AppLanguage.ar) {
            expect(tab.right, lessThanOrEqualTo(back.left));
            expect(tab.left, greaterThanOrEqualTo(search.right));
          } else {
            expect(tab.left, greaterThanOrEqualTo(back.right));
            expect(tab.right, lessThanOrEqualTo(search.left));
          }
        }
        final rect = tester.getRect(find.byKey(VoiceRoomsLiveButton.buttonKey));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.size, const Size.square(KSizes.minTouchTarget));
      });
    });
  }
}
