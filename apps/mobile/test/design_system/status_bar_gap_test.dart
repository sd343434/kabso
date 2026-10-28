// D142 (owner: "put a gap between the top bar and the phone's status
// info"): every top bar starts KMetrics.statusBarGap under the status bar.
// The main screens are pumped with a simulated 44 pt status bar; each
// header row starts at padding.top + gap and nothing interactive sits in
// the gap. Also 360 × 800 at text × 1.3 (ar + en) without overflow.

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

/// The simulated status bar (a tall punch-hole phone).
const double _statusBar = 44;

User _me() => User(
  id: 'user-me',
  email: 'me@example.invalid',
  emailVerified: true,
  username: 'layla.k',
  displayName: 'Layla',
  locale: 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026),
);

List<Override> _overrides(AppLanguage language) => [
  ...liveOverrides(
    FakeLiveRepository(categories: apiCategories()),
    language: language,
  ),
  currentUserProvider.overrideWithValue(testUser()),
  meProvider.overrideWith((ref) => _me()),
  profileStatsProvider.overrideWith(
    (ref, username) => apiProfile(followerCount: 12, isSelf: true),
  ),
];

/// The main top bars: the screen and how its header row is found.
final Map<String, Widget> _screens = {
  'posts (home feed)': const FeedScreen(),
  'live hub': const LiveScreen(),
  'voice rooms': const VoiceRoomsScreen(),
  'search': const DiscoverScreen(),
  'notifications': const NotificationsScreen(),
  'profile': const ProfileScreen(),
  'messages': const MessagesTab(),
  'settings': const SettingsScreen(),
};

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  const pad = FakeViewPadding(top: _statusBar * GoldenViewport.pixelRatio);
  tester.view
    ..padding = pad
    ..viewPadding = pad;
  await pumpScreen(
    tester,
    screen,
    language: language,
    overrides: _overrides(language),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Where the header row starts: the app bar's toolbar, or the first child
/// of the custom header's [KTopSafeArea].
double _rowTop(WidgetTester tester) {
  final toolbar = find.byType(NavigationToolbar);
  if (toolbar.evaluate().isNotEmpty) return tester.getRect(toolbar.first).top;
  final area = tester.widget<KTopSafeArea>(find.byType(KTopSafeArea).first);
  return tester.getRect(find.byWidget(area.child)).top;
}

bool _interactive(Widget w) =>
    w is IconButton ||
    w is TextField ||
    w is InkWell ||
    w is InkResponse ||
    w is GestureDetector && w.onTap != null;

/// The top of the highest interactive element in the header (the first
/// 64 pt under the gap), or null when the bar has none (a tab root such as
/// Messages, or a page opened with nothing to go back to).
double? _firstInteractiveTop(WidgetTester tester, double rowTop) {
  final tops = [
    for (final e in find.byWidgetPredicate(_interactive).evaluate())
      if (e.renderObject case final RenderBox box when box.hasSize)
        box.localToGlobal(Offset.zero).dy,
  ].where((top) => top < rowTop + 64).toList()..sort();
  return tops.firstOrNull;
}

void main() {
  test('one gap: the live rooms use the same value', () {
    expect(KMetrics.statusBarGap, 10);
    expect(KMetrics.liveHeaderGap, KMetrics.statusBarGap);
  });

  testWidgets('KAppBar: toolbar under the status bar and the gap', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        appBar: KAppBar(
          title: const Text('Title'),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
        ),
        body: const SizedBox.expand(key: Key('body')),
      ),
    );
    expect(_rowTop(tester), _statusBar + KMetrics.statusBarGap);
    // The bar's background still covers the status bar and the gap.
    expect(tester.getRect(find.byType(AppBar)).top, 0);
    expect(
      tester.getRect(find.byKey(const Key('body'))).top,
      _statusBar + KMetrics.statusBarGap + kToolbarHeight,
    );
  });

  for (final language in AppLanguage.values) {
    for (final MapEntry(key: name, value: screen) in _screens.entries) {
      testWidgets('$name (${language.name}): header row at status bar + gap', (
        tester,
      ) async {
        await _pump(tester, screen, language: language);
        expect(tester.takeException(), isNull);
        const expected = _statusBar + KMetrics.statusBarGap;
        expect(_rowTop(tester), expected, reason: name);
        // Nothing interactive in the status bar or the gap; the first
        // control is in the header row (a 48 pt target, centred in a
        // 56 pt app bar at most 4 pt lower). Without one, the title.
        final first =
            _firstInteractiveTop(tester, expected) ??
            tester
                .getRect(
                  find
                      .descendant(
                        of: find.byType(NavigationToolbar),
                        matching: find.byType(Text),
                      )
                      .first,
                )
                .top;
        expect(first, greaterThanOrEqualTo(expected), reason: name);
        expect(
          first,
          lessThanOrEqualTo(expected + kToolbarHeight / 2),
          reason: name,
        );
        // Nothing interactive above the header row.
        for (final e in find.byWidgetPredicate(_interactive).evaluate()) {
          if (e.renderObject case final RenderBox box when box.hasSize) {
            expect(
              box.localToGlobal(Offset.zero).dy,
              greaterThanOrEqualTo(expected),
              reason: '$name: ${e.widget.runtimeType}',
            );
          }
        }
      });

      testWidgets('$name (${language.name}): 360 × 800 at text × 1.3', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          screen,
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull, reason: name);
        expect(_rowTop(tester), _statusBar + KMetrics.statusBarGap);
      });
    }
  }
}
