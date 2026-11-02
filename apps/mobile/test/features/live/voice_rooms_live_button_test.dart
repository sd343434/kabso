// D139: the Live button in the voice rooms' top bar (the mirror of the
// hub's party button) returns to the live hub.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
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
      testWidgets("D240: the party page's corner switch, 48 pt, the Live "
          "icon (the size of the hub's party icon), labelled", (tester) async {
        await _pumpApp(tester, language);
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
        expect(rect.size, const Size.square(KSizes.minTouchTarget));
        // D240 (owner: «فقط احفظ زر تبديل بين الحفلة وبث حي على زاوية»):
        // the page's only button, in the corner at the reading end (no bell
        // beside it any more).
        expect(find.byKey(_bell), findsNothing);
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        // D246: at the edge, in the reference's bell slot.
        if (language == AppLanguage.ar) {
          expect(rect.left, closeTo(0, 0.5));
        } else {
          expect(rect.right, closeTo(width, 0.5));
        }
        // D240: no search on the party page; the back arrow stays.
        expect(
          find.descendant(
            of: find.byType(VoiceRoomsScreen),
            matching: find.byTooltip(l10n.feedSearch),
          ),
          findsNothing,
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
          'button on screen, the four filters whole beside it, the kinds '
          'under them', (tester) async {
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
        final live = tester.getRect(find.byKey(VoiceRoomsLiveButton.buttonKey));
        // D246: the filters sit whole between the back arrow and the Live
        // switch (no search, no bell; they shrink to fit); the kinds are
        // the row under them, on screen.
        expect(
          find.descendant(
            of: find.byType(VoiceRoomsScreen),
            matching: find.byTooltip(l10n.feedSearch),
          ),
          findsNothing,
        );
        for (final k in LiveHubCategory.partyPage) {
          final tab = tester.getRect(find.byKey(VoiceRoomsScreen.kindKey(k)));
          expect(tab.left, greaterThanOrEqualTo(0));
          expect(tab.right, lessThanOrEqualTo(360));
          expect(tab.top, greaterThanOrEqualTo(live.bottom));
        }
        for (final f in VoiceRoomsScreen.filters) {
          final tab = tester.getRect(find.byKey(VoiceRoomsScreen.filterKey(f)));
          if (language == AppLanguage.ar) {
            expect(tab.right, lessThanOrEqualTo(back.left));
            expect(tab.left, greaterThanOrEqualTo(live.right));
          } else {
            expect(tab.left, greaterThanOrEqualTo(back.right));
            expect(tab.right, lessThanOrEqualTo(live.left));
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
