// D377 (owner 2026-11-12): one top bar on the Live hub and the party page —
// no title, the party page's four tabs (المتابَعة · الرائج · استكشاف ·
// القريبة), «+» and search; no bell (the Moments tab keeps it). Each tab
// keeps its page's query (the hub: kind=solo; the party page: party_all).
// The tabs keep their text size: on narrow screens and large text the strip
// scrolls, the selected tab whole in view.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveRepository> _pump(
  WidgetTester tester, {
  required Widget screen,
  required AppLanguage language,
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  await loadAppFonts();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (scale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(4)));
  await pumpScreen(
    tester,
    screen,
    language: language,
    overrides: liveOverrides(live, language: language, country: 'JO'),
  );
  await tester.pumpAndSettle();
  return live;
}

Finder _tab(LiveHubFilter f) => find.byKey(LiveHubTopBar.tabKey(f));

void main() {
  const pages = [
    (name: 'hub', screen: LiveScreen(), kind: LiveRoomsKind.solo),
    (name: 'party', screen: VoiceRoomsScreen(), kind: LiveRoomsKind.partyAll),
  ];

  for (final page in pages) {
    group('${page.name} (D377)', () {
      testWidgets('each tab sends its query (${page.kind.name}); no '
          'category, no featured; no bell, no title', (tester) async {
        final live = await _pump(
          tester,
          screen: page.screen,
          language: AppLanguage.en,
        );
        expect(find.byKey(NotificationsBell.bellKey), findsNothing);
        expect(find.text('Kabso Live'), findsNothing);
        expect(find.byKey(LiveHubTopBar.searchKey), findsOneWidget);
        expect(find.byKey(LiveHubGoLiveButton.buttonKey), findsOneWidget);
        expect(_tab(LiveHubFilter.featured), findsNothing);
        final expected = {
          LiveHubFilter.following: (LiveRoomsTab.following, false),
          LiveHubFilter.explore: (LiveRoomsTab.latest, false),
          LiveHubFilter.nearby: (LiveRoomsTab.popular, true),
        };
        // Popular first (selected on open).
        expect(live.requests.last.kind, page.kind);
        expect(live.requests.last.tab, LiveRoomsTab.popular);
        expect(live.requests.last.nearby, isFalse);
        expect(live.requests.last.category, isNull);
        for (final MapEntry(key: f, value: (tab, nearby)) in expected.entries) {
          await tester.ensureVisible(_tab(f));
          await tester.pumpAndSettle();
          await tester.tap(_tab(f));
          await tester.pumpAndSettle();
          final r = live.requests.last;
          expect(r.kind, page.kind, reason: f.name);
          expect(r.tab, tab, reason: f.name);
          expect(r.nearby, nearby, reason: f.name);
          expect(r.featured, isFalse, reason: f.name);
          expect(r.category, isNull, reason: f.name);
        }
      });

      for (final language in AppLanguage.values) {
        for (final size in const [
          Size(360, 800),
          Size(393, 852),
          Size(430, 932),
        ]) {
          for (final scale in const [1.0, 1.3]) {
            testWidgets(
              '${language.name} ${size.width.toInt()}×${size.height.toInt()} '
              'text ×$scale: no overflow; the tabs at 18 / 15 sp; each '
              'whole in the strip once selected; the strip ends before «+»',
              (tester) async {
                await _pump(
                  tester,
                  screen: page.screen,
                  language: language,
                  size: size,
                  scale: scale,
                );
                expect(tester.takeException(), isNull);
                final strip = tester.getRect(find.byKey(LiveHubTopBar.tabsKey));
                final plus = tester.getRect(
                  find.byKey(LiveHubGoLiveButton.buttonKey),
                );
                if (language == AppLanguage.ar) {
                  expect(strip.left, greaterThanOrEqualTo(plus.right - 0.5));
                } else {
                  expect(strip.right, lessThanOrEqualTo(plus.left + 0.5));
                }
                for (final f in [
                  // Popular is selected first; then each in turn.
                  LiveHubFilter.popular,
                  LiveHubFilter.nearby,
                  LiveHubFilter.following,
                  LiveHubFilter.explore,
                ]) {
                  if (f != LiveHubFilter.popular) {
                    await tester.ensureVisible(_tab(f));
                    await tester.pumpAndSettle();
                    await tester.tap(_tab(f));
                    await tester.pumpAndSettle();
                  }
                  final tab = tester.getRect(_tab(f));
                  expect(
                    tab.left,
                    greaterThanOrEqualTo(strip.left - 0.5),
                    reason: f.name,
                  );
                  expect(
                    tab.right,
                    lessThanOrEqualTo(strip.right + 0.5),
                    reason: f.name,
                  );
                  for (final g in LiveHubTopBar.filters) {
                    expect(
                      tester
                          .widget<Text>(
                            find.descendant(
                              of: _tab(g),
                              matching: find.byType(Text),
                            ),
                          )
                          .style!
                          .fontSize,
                      g == f ? KLiveTopBar.tabSelected : KLiveTopBar.tab,
                    );
                  }
                  expect(tester.takeException(), isNull);
                }
              },
            );
          }
        }
      }
    });
  }
}
