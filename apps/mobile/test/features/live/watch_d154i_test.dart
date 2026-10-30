// D154i («يوتيوب», CONVENTIONS §10.39): watch-together — a late joiner's
// player starts where the host is, viewers follow play / pause and seek
// when they drift, hide it on their phone, suggest a video (a bad link and
// a refused video say why); the host's player reports its state, the host
// shows a link, a search result or a suggestion and stops the show; search
// off says so — Arabic RTL and English at 360×800. The YouTube player is a
// fake (no web view in tests).

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/youtube_player.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
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
const _other = 'bbbbbbbbbbb';

class _Room extends ConsumerStatefulWidget {
  const new(this.engine, {required this.host});

  final FakeLiveMediaEngine engine;
  final bool host;

  @override
  ConsumerState<_Room> createState() => _RoomState();
}

class _RoomState extends ConsumerState<_Room> {
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
        Positioned(
          bottom: 8,
          left: 8,
          child: Builder(
            builder: (context) => TextButton(
              key: const Key('test.sheet'),
              onPressed: () => showLiveWatchSheet(context, roomId: _room),
              child: const SizedBox.square(dimension: 24),
            ),
          ),
        ),
        // D173: the audio room shows the card as its cinema screen (in the
        // room's layout) and the layer keeps the «show» pill.
        if (LiveWatchScreen.shows(ref, _room))
          Positioned(
            top: LiveWatchLayer.top,
            left: 12,
            right: 12,
            child: LiveWatchScreen(roomId: _room, host: widget.host),
          ),
        LiveWatchLayer(roomId: _room, host: widget.host),
      ],
    ),
  );
}

Future<(FakeLiveWatchRepository, FakeLiveMediaEngine, FakeYoutubePlayers)>
_pump(
  WidgetTester tester, {
  bool host = false,
  AppLanguage language = AppLanguage.en,
  LiveWatch? watch,
  bool searchEnabled = false,
  List<LiveWatchSuggestion> pending = const [],
}) async {
  setViewport(tester, GoldenViewport.android);
  final repo = FakeLiveWatchRepository(
    searchEnabled: searchEnabled,
    now: clock.now,
  );
  if (watch != null) repo.watches[_room] = watch;
  repo.pending[_room] = [...pending];
  final engine = FakeLiveMediaEngine();
  final players = FakeYoutubePlayers();
  await pumpScreen(
    tester,
    _Room(engine, host: host),
    language: language,
    liveMediaEngine: engine,
    liveWatchRepository: repo,
    youtubePlayers: players,
  );
  await tester.pumpAndSettle();
  return (repo, engine, players);
}

LiveWatch _playing({int positionMs = 30000, int lagMs = 10000}) {
  final now = clock.now();
  return LiveWatch(
    roomId: _room,
    video: FakeLiveWatchRepository.videoOf(_vid),
    playing: true,
    positionMs: positionMs,
    updatedAt: now.subtract(Duration(milliseconds: lagMs)),
    serverTime: now,
  );
}

const _fan = UserSummary(
  id: 'u-fan',
  username: 'fan',
  displayName: 'Fan',
  avatarUrl: null,
);

void main() {
  test('links and ids are read as the server reads them', () {
    for (final ref in [
      _vid,
      'https://youtu.be/$_vid',
      'youtube.com/watch?v=$_vid&t=3',
      'https://m.youtube.com/shorts/$_vid',
    ]) {
      expect(youtubeVideoId(ref), _vid, reason: ref);
    }
    expect(youtubeVideoId('https://vimeo.com/1'), isNull);
    expect(youtubeVideoId('https://evil.example/watch?v=$_vid'), isNull);
  });

  test('the position: the server lag, then this phone’s time', () {
    final w = _playing();
    expect(w.positionAfter(const Duration(seconds: 5)), 45000);
    final paused = LiveWatch(
      roomId: _room,
      video: w.video,
      playing: false,
      positionMs: 30000,
      updatedAt: w.updatedAt,
      serverTime: w.serverTime,
    );
    expect(paused.positionAfter(const Duration(seconds: 5)), 30000);
  });

  for (final language in AppLanguage.values) {
    testWidgets('a late joiner starts where the host is; follows pause and '
        'drift; hides it on their phone (${language.name})', (tester) async {
      final (_, engine, players) = await _pump(
        tester,
        language: language,
        watch: _playing(),
      );
      final ar = language == AppLanguage.ar;
      expect(find.byKey(LiveWatchLayer.cardKey), findsOneWidget);
      final card = tester.getRect(find.byKey(LiveWatchLayer.cardKey));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(360));
      final player = players.made.single;
      expect(player.controls, isFalse);
      expect(player.calls.first, 'load:$_vid@40:true');
      expect(find.textContaining('Video $_vid'), findsOneWidget);

      // Drift: the player says 10 s while the room is at ~45 s.
      player
        ..position = 10000
        ..calls.clear();
      await tester.pump(const Duration(seconds: 5));
      expect(player.calls.where((c) => c.startsWith('seek:')), isNotEmpty);

      // The host pauses.
      player.events$.add(
        const YoutubePlayerStateChanged(
          playing: true,
          ended: false,
          positionMs: 45000,
        ),
      );
      await tester.pump();
      engine.chat.add(
        LiveWatchChanged(
          LiveWatch(
            roomId: _room,
            video: FakeLiveWatchRepository.videoOf(_vid),
            playing: false,
            positionMs: 45000,
            updatedAt: clock.now(),
            serverTime: clock.now(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(player.calls, contains('pause'));

      await tester.tap(find.byKey(LiveWatchLayer.hideKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
      expect(find.text(ar ? 'عرض الفيديو' : 'Show the video'), findsOneWidget);
      await tester.tap(find.byKey(LiveWatchLayer.showKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveWatchLayer.cardKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a viewer suggests a link; a bad link and a refused video say '
      'why', (tester) async {
    final (repo, _, _) = await _pump(tester, watch: _playing());
    repo.refused.add(_other);
    await tester.tap(find.byKey(LiveWatchLayer.suggestKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveWatchSheet.searchOffKey), findsOneWidget);
    await tester.enterText(find.byKey(LiveWatchSheet.linkKey), 'hello');
    await tester.tap(find.byKey(LiveWatchSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.text("That isn't a YouTube video link"), findsOneWidget);
    await tester.enterText(
      find.byKey(LiveWatchSheet.linkKey),
      'https://youtu.be/$_other',
    );
    await tester.tap(find.byKey(LiveWatchSheet.sendKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("This video can't be played here"),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(LiveWatchSheet.linkKey),
      'https://youtu.be/$_vid',
    );
    await tester.tap(find.byKey(LiveWatchSheet.sendKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'suggest:https://youtu.be/$_vid');
    expect(find.byKey(LiveWatchSheet.linkKey), findsNothing);
    expect(find.text('Your suggestion reached the host'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("the host's player reports play, pause and seek", (tester) async {
    final (repo, _, players) = await _pump(
      tester,
      host: true,
      watch: _playing(),
    );
    final player = players.made.single;
    expect(player.controls, isTrue);
    player.events$.add(
      const YoutubePlayerStateChanged(
        playing: false,
        ended: false,
        positionMs: 12000,
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'set:-:false:12000');
    player.events$.add(
      const YoutubePlayerStateChanged(
        playing: true,
        ended: false,
        positionMs: 60000,
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'set:-:true:60000');
    // While playing, the position every 15 s.
    player.position = 75000;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'set:-:true:75000');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the host shows a link, then a suggestion, then stops', (
    tester,
  ) async {
    final (repo, _, players) = await _pump(
      tester,
      host: true,
      pending: [
        LiveWatchSuggestion(
          id: 'sg-1',
          roomId: _room,
          video: FakeLiveWatchRepository.videoOf(_other),
          suggester: _fan,
          status: 'PENDING',
        ),
      ],
    );
    expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
    await tester.tap(find.byKey(const Key('test.sheet')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fan'), findsOneWidget);
    await tester.enterText(
      find.byKey(LiveWatchSheet.linkKey),
      'https://www.youtube.com/watch?v=$_vid',
    );
    await tester.tap(find.byKey(LiveWatchSheet.sendKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, startsWith('set:https://www.youtube.com/watch'));
    expect(find.byKey(LiveWatchLayer.cardKey), findsOneWidget);
    expect(players.made.single.calls.first, 'load:$_vid@0:true');

    await tester.tap(find.byKey(LiveWatchLayer.manageKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveWatchSheet.approveKey('sg-1')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('decide:sg-1:true'));
    expect(find.textContaining('Video $_other'), findsWidgets);
    expect(players.made.single.calls.last, 'load:$_other@0:true');

    await tester.tap(find.byKey(LiveWatchSheet.stopKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with search on, a result is shown with one tap', (tester) async {
    final (repo, _, _) = await _pump(tester, host: true, searchEnabled: true);
    await tester.tap(find.byKey(const Key('test.sheet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(LiveWatchSheet.searchKey), 'cats');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('search:cats'));
    await tester.tap(find.byKey(LiveWatchSheet.resultKey('srchsrchsrc')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'set:srchsrchsrc:true:0');
    expect(find.byKey(LiveWatchLayer.cardKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("the host is told of a viewer's suggestion", (tester) async {
    final (_, engine, _) = await _pump(tester, host: true, watch: _playing());
    engine.chat.add(
      LiveWatchSuggested(
        LiveWatchSuggestion(
          id: 'sg-9',
          roomId: _room,
          video: FakeLiveWatchRepository.videoOf(_other),
          suggester: _fan,
          status: 'PENDING',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiveWatchLayer)),
    );
    expect(container.read(liveWatchProvider(_room)).suggestions, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the data messages', () {
    final w = LiveChatEvent.parse({
      'type': 'watch',
      'watch': {
        'roomId': _room,
        'video': {
          'videoId': _vid,
          'title': 'T',
          'channel': null,
          'thumbnailUrl': 'https://i.ytimg.com/vi/$_vid/hqdefault.jpg',
        },
        'playing': true,
        'positionMs': 1000,
        'updatedAt': '2026-10-28T20:00:00.000Z',
        'serverTime': '2026-10-28T20:00:02.000Z',
        'searchEnabled': false,
      },
    });
    expect((w! as LiveWatchChanged).watch.positionAfter(Duration.zero), 3000);
    expect(LiveChatEvent.parse({'type': 'watch-suggestion'}), isNull);
  });
}
