// D94: the go-live screen in its three modes (owner references, Kabso's
// own look and themes), Arabic and English, phone and 360 dp.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  required LiveRoomMode mode,
  bool minimized = false,
  String theme = LiveThemes.classic,
  int? seats,
  GoldenViewport viewport = GoldenViewport.phone,
  List<LiveSeat>? onAir,
  int? roomLevel,
  bool filters = true,
}) async {
  final ar = language == AppLanguage.ar;
  final repo = FakeLiveRepository(
    categories: [
      LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat'),
      LiveCategory(slug: 'music', name: ar ? 'موسيقى' : 'Music'),
      LiveCategory(slug: 'games', name: ar ? 'ألعاب' : 'Games'),
      LiveCategory(slug: 'friends', name: ar ? 'تعارف' : 'Friends'),
    ],
  )..startRoomLevel = roomLevel;
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(repo),
        liveMediaEngineProvider.overrideWithValue(
          filters
              ? FakeLiveMediaEngine.new
              : () => FakeLiveMediaEngine()..supportsFilters = false,
        ),
        currentUserProvider.overrideWithValue(
          testUser(displayName: ar ? 'ليلى' : 'Layla').copyWith(canHost: true),
        ),
      ],
      child: Stack(
        children: [
          if (minimized)
            ColoredBox(
              color: const Color(0xFF16161A),
              child: Center(
                child: Text(ar ? 'تصفح التطبيق' : 'Browsing the app'),
              ),
            )
          else
            const GoLiveScreen(),
          LiveMiniWindow(router: GoRouter(routes: [])),
        ],
      ),
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveMiniWindow)),
  );
  // Kept alive while set up: minimized, no screen watches the controller.
  final keep = container.listen(liveHostControllerProvider, (_, _) {});
  addTearDown(keep.close);
  final host = container.read(liveHostControllerProvider.notifier);
  await host.setMode(mode);
  await host.setTheme(theme);
  if (seats != null) await host.setSeatCount(seats);
  if (onAir != null) {
    // Fixture viewers (tests only) for the avatars and count.
    repo.viewerList = [
      for (final (id, name) in [
        ('v1', ar ? 'هدى' : 'Huda'),
        ('v2', ar ? 'كريم' : 'Karim'),
        ('v3', ar ? 'منى' : 'Mona'),
      ])
        LiveViewer(
          kind: LiveViewerKind.user,
          user: UserSummary(
            id: id,
            username: id,
            displayName: name,
            avatarUrl: null,
          ),
          guestNumber: null,
          joinedAt: DateTime.utc(2026, 10, 23),
        ),
    ];
    await host.goLive(title: ar ? 'سهرة أصوات' : 'Voices night');
  }
  if (onAir != null && repo.seatState != null) {
    repo.seatState = repo.seatState!.copyWith(
      seats: [
        for (final seat in repo.seatState!.seats)
          onAir.firstWhere((s) => s.index == seat.index, orElse: () => seat),
      ],
    );
    container.invalidate(liveSeatsProvider('room-host'));
    await tester.pump();
    await tester.pump();
  }
  if (minimized) {
    await host.startPreview();
    await host.goLive(title: ar ? 'سهرة' : 'Evening');
    container.read(liveMinimizedProvider.notifier).minimize();
  }
  await tester.pump();
  await precacheImages(tester);
}

void main() {
  forEachLanguage((language) {
    for (final viewport in GoldenViewport.values) {
      testWidgets('go live: multi-guest ($language, $viewport)', (
        tester,
      ) async {
        await _pump(
          tester,
          language: language,
          viewport: viewport,
          mode: LiveRoomMode.multi,
          theme: 'ice-palace',
        );
        await expectScreenGolden(
          'go_live.multi',
          language: language,
          viewport: viewport,
        );
      });

      testWidgets('go live: audio ($language, $viewport)', (tester) async {
        await _pump(
          tester,
          language: language,
          viewport: viewport,
          mode: LiveRoomMode.audio,
        );
        await expectScreenGolden(
          'go_live.audio',
          language: language,
          viewport: viewport,
        );
      });

      testWidgets('go live: LIVE ($language, $viewport)', (tester) async {
        await _pump(
          tester,
          language: language,
          viewport: viewport,
          mode: LiveRoomMode.solo,
        );
        await expectScreenGolden(
          'go_live.solo',
          language: language,
          viewport: viewport,
        );
      });
    }

    testWidgets('go live: multi-guest 12, classic ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.multi,
        seats: 12,
      );
      await expectScreenGolden('go_live.multi12', language: language);
    });

    testWidgets('go live: audio on air, waves ($language)', (tester) async {
      final ar = language == AppLanguage.ar;
      UserSummary guest(String id, String ar1, String en1) => UserSummary(
        id: id,
        username: id,
        displayName: ar ? ar1 : en1,
        avatarUrl: null,
      );
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.audio,
        onAir: [
          LiveSeat(
            index: 1,
            state: LiveSeatState.taken,
            user: guest('u1', 'لينا', 'Lina'),
          ),
          LiveSeat(
            index: 2,
            state: LiveSeatState.taken,
            user: guest('u2', 'عمر', 'Omar'),
            mutedByHost: true,
          ),
          LiveSeat(
            index: 4,
            state: LiveSeatState.taken,
            user: guest('u3', 'سارة', 'Sara'),
          ),
          const LiveSeat(index: 6, state: LiveSeatState.locked, user: null),
        ],
      );
      await expectScreenGolden('go_live.audio_live', language: language);
      // The chat box, opened from 💬, in place of the buttons.
      await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
      await tester.pump();
      await tester.enterText(
        find.byType(EditableText),
        ar ? 'مساء الخير' : 'Good evening',
      );
      await tester.pump();
      await expectScreenGolden('go_live.audio_chat', language: language);
    });

    testWidgets('go live: audio on air, 20 seats in rows ($language)', (
      tester,
    ) async {
      final ar = language == AppLanguage.ar;
      // Owner D100: above 11 tiles the seats sit in rows of 5, the host the
      // first tile; D123: 20 is the largest room, every seat at full size.
      // D101: the room level (25, the kitty tier) after the name.
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.audio,
        seats: 20,
        roomLevel: 25,
        onAir: [
          LiveSeat(
            index: 1,
            state: LiveSeatState.taken,
            user: UserSummary(
              id: 'u1',
              username: 'u1',
              displayName: ar ? 'لينا' : 'Lina',
              avatarUrl: null,
            ),
          ),
          const LiveSeat(index: 7, state: LiveSeatState.locked, user: null),
        ],
      );
      await expectScreenGolden('go_live.audio_rows20', language: language);
    });

    testWidgets('go live: audio on air at 360 dp ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.audio,
        viewport: GoldenViewport.android,
        onAir: const [],
      );
      await expectScreenGolden(
        'go_live.audio_live',
        language: language,
        viewport: GoldenViewport.android,
      );
    });

    testWidgets('go live: LIVE on air ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.solo,
        onAir: const [],
      );
      await expectScreenGolden('go_live.solo_live', language: language);
    });

    testWidgets('go live: minimized window ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.solo,
        minimized: true,
      );
      await expectScreenGolden('go_live.minimized', language: language);
    });

    testWidgets('go live: audio 13, rose garden ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.audio,
        theme: 'rose-garden',
        seats: 13,
      );
      await expectScreenGolden('go_live.audio13', language: language);
    });

    // D157: the fill light's level sheet over the setup (front camera).
    testWidgets('go live: fill light sheet ($language)', (tester) async {
      await _pump(tester, language: language, mode: LiveRoomMode.solo);
      final tool = find.byKey(GoLiveKeys.tool('fillLight'));
      await tester.ensureVisible(tool);
      await tester.tap(tool);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(GoLiveKeys.fillLightLevel(LiveFillLight.medium)),
      );
      await tester.pumpAndSettle();
      await expectScreenGolden('go_live.fill_light_sheet', language: language);
    });

    // D157: a device without a camera pipeline — the thin edge glow at its
    // strongest level (no frame, the controls untouched).
    testWidgets('go live: fill light edge glow ($language)', (tester) async {
      await _pump(
        tester,
        language: language,
        mode: LiveRoomMode.solo,
        filters: false,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveMiniWindow)),
      );
      await container
          .read(liveHostControllerProvider.notifier)
          .setFillLight(on: true, level: LiveFillLight.high);
      await tester.pumpAndSettle();
      await expectScreenGolden('go_live.fill_light_glow', language: language);
    });
  });
}
