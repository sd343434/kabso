// D160 («يوتيوب» in a VIDEO live): the watch window floats over the host's
// picture in a corner of the band under the header and above the chat,
// MAX X and the bottom bar; dragged by its bar it settles in the nearest
// corner (start = right in Arabic); it collapses to a pill on this phone;
// the host closes the show for everyone, a viewer suggests from it —
// Arabic RTL and English LTR at 360×800 with a status bar and a home
// indicator. The YouTube player is a fake.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_watch_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_watch_repository.dart';
import '../../helpers/fake_youtube_player.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _room = 'room-0';
const _vid = 'aaaaaaaaaaa';

/// 360×800 with a 24 pt status bar and a 24 pt navigation bar.
const _padding = EdgeInsets.only(top: 24, bottom: 24);
const _size = Size(360, 800);

var _underTaps = 0;

class _VideoRoom extends ConsumerStatefulWidget {
  const new(this.engine, {required this.host});

  final FakeLiveMediaEngine engine;
  final bool host;

  @override
  ConsumerState<_VideoRoom> createState() => _VideoRoomState();
}

class _VideoRoomState extends ConsumerState<_VideoRoom> {
  @override
  void initState() {
    super.initState();
    ref
        .read(liveWatchProvider(_room).notifier)
        .attach(widget.engine, host: widget.host);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF333344),
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Something under the window keeps its taps outside it.
        Positioned(
          bottom: 8,
          left: 8,
          child: TextButton(
            key: const Key('test.under'),
            onPressed: () => _underTaps++,
            child: const SizedBox.square(dimension: 24),
          ),
        ),
        LiveWatchLayer(roomId: _room, host: widget.host, pip: true),
      ],
    ),
  );
}

Future<(FakeLiveWatchRepository, FakeYoutubePlayers)> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  bool host = false,
}) async {
  setViewport(tester, GoldenViewport.android);
  tester.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 24 * 3);
  addTearDown(tester.view.resetPadding);
  final repo = FakeLiveWatchRepository(now: clock.now);
  final now = clock.now();
  repo.watches[_room] = LiveWatch(
    roomId: _room,
    video: FakeLiveWatchRepository.videoOf(_vid),
    playing: true,
    positionMs: 1000,
    updatedAt: now,
    serverTime: now,
  );
  final engine = FakeLiveMediaEngine();
  final players = FakeYoutubePlayers();
  await pumpScreen(
    tester,
    _VideoRoom(engine, host: host),
    language: language,
    liveMediaEngine: engine,
    liveWatchRepository: repo,
    youtubePlayers: players,
  );
  await tester.pumpAndSettle();
  return (repo, players);
}

/// The lowest the window may reach: above the chat's 30 % cap, the quick
/// replies, MAX X and the bar.
double get _floor =>
    _size.height -
    _padding.bottom -
    LiveWatchPipGeometry.bottomChrome -
    _size.height * KMetrics.chatMaxHeightFactor;

void main() {
  group('geometry at 360×800', () {
    test('the window keeps to the band in every corner, both directions', () {
      final w = LiveWatchPipGeometry.width(_size.width);
      final h = LiveWatchPipGeometry.height(w);
      expect(w, 180);
      for (final direction in TextDirection.values) {
        for (final c in LiveWatchCorner.values) {
          final at = LiveWatchPipGeometry.offsetOf(
            c,
            size: _size,
            padding: _padding,
            direction: direction,
          );
          final rect = at & Size(w, h);
          expect(rect.left, greaterThanOrEqualTo(8), reason: '$c');
          expect(rect.right, lessThanOrEqualTo(352), reason: '$c');
          expect(
            rect.top,
            greaterThanOrEqualTo(_padding.top + LiveWatchLayer.top),
            reason: '$c',
          );
          expect(rect.bottom, lessThanOrEqualTo(_floor), reason: '$c');
          expect(
            LiveWatchPipGeometry.nearest(
              at,
              size: _size,
              padding: _padding,
              direction: direction,
            ),
            c,
          );
        }
      }
      // Start is the right in Arabic.
      final rtl = LiveWatchPipGeometry.offsetOf(
        LiveWatchCorner.topStart,
        size: _size,
        padding: _padding,
        direction: TextDirection.rtl,
      );
      expect(rtl.dx, 360 - 8 - 180);
    });

    test('the keyboard up: the bottom corners take the top row', () {
      final top = LiveWatchPipGeometry.offsetOf(
        LiveWatchCorner.topEnd,
        size: _size,
        padding: _padding,
        direction: TextDirection.ltr,
        keyboard: 300,
      );
      final bottom = LiveWatchPipGeometry.offsetOf(
        LiveWatchCorner.bottomEnd,
        size: _size,
        padding: _padding,
        direction: TextDirection.ltr,
        keyboard: 300,
      );
      expect(bottom.dy, top.dy);
    });
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;

    testWidgets('a viewer: the window at the top end, dragged to the bottom '
        'start corner, collapsed and shown again (${language.name})', (
      tester,
    ) async {
      final (_, players) = await _pump(tester, language: language);
      expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
      final pip = find.byKey(LiveWatchLayer.pipKey);
      expect(pip, findsOneWidget);
      var rect = tester.getRect(pip);
      expect(rect.width, 180);
      // The end: the left in Arabic, the right in English.
      expect(rect.center.dx < 180, ar);
      expect(rect.top, greaterThanOrEqualTo(24 + LiveWatchLayer.top));
      expect(rect.bottom, lessThanOrEqualTo(_floor));
      expect(players.made.single.controls, isFalse);
      expect(find.byKey(LiveWatchLayer.suggestKey), findsOneWidget);
      expect(find.byKey(LiveWatchLayer.closeKey), findsNothing);
      expect(find.byKey(LiveWatchLayer.manageKey), findsNothing);

      // Dragged across and down: the bottom start corner.
      await tester.drag(
        find.byKey(LiveWatchLayer.pipBarKey),
        Offset(ar ? 200 : -200, 200),
      );
      await tester.pumpAndSettle();
      rect = tester.getRect(pip);
      expect(rect.center.dx > 180, ar);
      expect(rect.bottom, closeTo(_floor - 8, 0.5));
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(352));
      // Taps beside the window reach what is under it.
      final before = _underTaps;
      await tester.tap(find.byKey(const Key('test.under')));
      expect(_underTaps, before + 1);

      // Collapsed on this phone, in the same corner; shown again.
      await tester.tap(find.byKey(LiveWatchLayer.hideKey));
      await tester.pumpAndSettle();
      expect(pip, findsNothing);
      final pill = tester.getRect(find.byKey(LiveWatchLayer.showKey));
      expect(pill.center.dx > 180, ar);
      expect(pill.bottom, lessThanOrEqualTo(_floor));
      await tester.tap(find.byKey(LiveWatchLayer.showKey));
      await tester.pumpAndSettle();
      expect(pip, findsOneWidget);

      // The suggestion entry is on the window.
      await tester.tap(find.byKey(LiveWatchLayer.suggestKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveWatchSheet.linkKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the host: YouTube controls, the suggestions, and ✕ stops '
        'the show for everyone (${language.name})', (tester) async {
      final (repo, players) = await _pump(
        tester,
        language: language,
        host: true,
      );
      expect(players.made.single.controls, isTrue);
      expect(find.byKey(LiveWatchLayer.manageKey), findsOneWidget);
      final rect = tester.getRect(find.byKey(LiveWatchLayer.pipKey));
      expect(rect.bottom, lessThanOrEqualTo(_floor));
      await tester.tap(find.byKey(LiveWatchLayer.closeKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, startsWith('set:stop'));
      expect(find.byKey(LiveWatchLayer.pipKey), findsNothing);
      expect(find.byKey(LiveWatchLayer.showKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
