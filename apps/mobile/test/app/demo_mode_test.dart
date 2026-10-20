// D86: "Demo data" — test builds can walk the whole app with labelled test
// data and no server; release builds never can, and production sources
// stay honest while it is off.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

Future<ProviderContainer> _container({required bool demo}) async {
  final prefs = await testPrefs(extra: {if (demo) 'pref.demoData': true});
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('production reaches demo data only behind the switch', () {
    // Files outside lib/features/debug/ that use the demo fixtures must
    // gate them on Demo data (a compile-time false in release builds).
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.replaceAll(r'\', '/').contains('features/debug/'),
            )) {
      final s = file.readAsStringSync();
      if (!s.contains('features/debug/demo_data.dart')) continue;
      if (!RegExp(r'watchDemo\(|kDemoAvailable').hasMatch(s)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('off: every source stays honest', () async {
    final c = await _container(demo: false);
    expect(c.read(demoModeProvider), isFalse);
    // KL-060: posts come from the real posts API (no network here).
    expect(c.read(postsRepositoryProvider), isA<PostsRepositoryImpl>());
    expect(
      await c.read(homeStoriesProvider.future),
      isA<FeedUnavailable<Object?>>(),
    );
    expect(c.read(liveRepositoryProvider), isA<LiveRepositoryImpl>());
    expect(c.read(profileRepositoryProvider), isA<ProfileRepositoryImpl>());
  });

  test('on: labelled test data in the real sources', () async {
    final c = await _container(demo: true);
    expect(c.read(demoModeProvider), isTrue);
    final posts = await c.read(homePostsProvider(HomeFeed.trending).future);
    expect(posts, isA<FeedItems<Object?>>());
    expect(c.read(liveRepositoryProvider), isA<DemoLiveRepository>());
    expect(c.read(profileRepositoryProvider), isA<DemoProfileRepository>());
    final me = await c.read(meProvider.future);
    expect(me.displayName, contains('(test)'));
    final rooms = await c
        .read(liveRepositoryProvider)
        .listRooms(tab: LiveRoomsTab.popular);
    expect(rooms.data, isNotEmpty);
    for (final r in rooms.data) {
      expect(r.host.displayName, contains('(test)'));
      expect(DemoData.roomMode(r.id), isNotNull);
    }
  });

  test('demo room ids map to the designed live room', () {
    expect(DemoData.roomMode('demo-pk2-1'), LivePreviewMode.pk2);
    expect(DemoData.roomMode('demo-solo-0'), LivePreviewMode.solo);
    expect(DemoData.roomMode('0193-real-room'), isNull);
  });

  test('enter and exit: the demo account signs in and out', () async {
    final c = await _container(demo: false);
    final session = c.read(sessionControllerProvider.notifier);
    await session.restore();
    expect(c.read(sessionControllerProvider), isA<Unauthenticated>());
    await session.enterDemo();
    expect(c.read(demoModeProvider), isTrue);
    final state = c.read(sessionControllerProvider);
    expect(state, isA<Authenticated>());
    expect((state as Authenticated).user.id, 'demo-user');
    // Restoring with Demo data on signs the demo account in again.
    await session.restore();
    expect(c.read(sessionControllerProvider), isA<Authenticated>());
    await session.exitDemo();
    expect(c.read(demoModeProvider), isFalse);
    expect(c.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  testWidgets('a test build walks the app on demo data, no server', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393 * 3, 852 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await testPrefs(extra: {'pref.welcomeSeen': true});
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
        child: const KabsoApp(),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Signed out: login offers "Try with demo data".
    expect(find.byKey(DemoEntryButton.buttonKey), findsOneWidget);
    await tapVisible(tester, find.byKey(DemoEntryButton.buttonKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The live hub with demo rooms.
    expect(find.byType(LiveScreen), findsOneWidget);
    expect(find.textContaining('(test)'), findsWidgets);
    // Messages: the designed list.
    await tester.tap(find.byKey(const Key('nav.messages')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MessagesTab), findsOneWidget);
    expect(find.byType(ConversationsPreviewScreen), findsOneWidget);
    // Back to Live: a demo room opens the designed live room.
    await tester.tap(find.byKey(const Key('nav.home')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tapVisible(tester, find.text(l10nFor(AppLanguage.en).liveHubJoin));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LivePreviewScreen), findsOneWidget);
  });
}
