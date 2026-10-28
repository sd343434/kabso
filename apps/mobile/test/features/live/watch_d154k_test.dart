// D154k: the YouTube player failed on a real phone with YouTube's
// «هذا الفيديو غير متوفر · رمز الخطأ: 152 - 4» for every video. D154i's
// embed page claimed to be youtube.com itself (base URL and `origin`
// https://www.youtube.com), which YouTube now refuses. The page now runs at
// the app's own `https://<app id>` origin, sends it as the Referer and names
// it in `origin` / `widget_referrer`; the app ids are read from the Android
// and iOS projects so they cannot drift. Player errors are classified (the
// video's fault vs our setup) and the overlay stays honest for all.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/youtube_player.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_watch_repository.dart';
import '../../helpers/fake_youtube_player.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _room = 'room-0';
const _vid = 'aaaaaaaaaaa';

class _Room extends ConsumerStatefulWidget {
  const new(this.engine);

  final FakeLiveMediaEngine engine;

  @override
  ConsumerState<_Room> createState() => _RoomState();
}

class _RoomState extends ConsumerState<_Room> {
  @override
  void initState() {
    super.initState();
    ref
        .read(liveWatchProvider(_room).notifier)
        .attach(widget.engine, host: false);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF333344),
    body: Stack(
      fit: StackFit.expand,
      children: [LiveWatchLayer(roomId: _room, host: false)],
    ),
  );
}

String _page(String origin) => WebViewYoutubePlayer.page(
  videoId: _vid,
  startSeconds: 12,
  autoplay: true,
  controls: false,
  origin: origin,
);

void main() {
  group('the embed identity', () {
    test('the page names its own origin, never youtube.com', () {
      for (final origin in [youtubeEmbedOriginAndroid, youtubeEmbedOriginIos]) {
        final html = _page(origin);
        expect(html, contains("origin:'$origin'"));
        expect(html, contains("widget_referrer:'$origin'"));
        expect(html, contains('enablejsapi:1'));
        expect(
          html,
          contains(
            '<meta name="referrer" content="strict-origin-when-cross-origin">',
          ),
        );
        expect(html, isNot(contains("origin:'https://www.youtube.com'")));
        expect(
          html,
          contains('<script src="https://www.youtube.com/iframe_api">'),
        );
      }
    });

    test('each platform gets its own app id; the origins are canonical', () {
      expect(
        youtubeEmbedOrigin(TargetPlatform.android),
        youtubeEmbedOriginAndroid,
      );
      expect(youtubeEmbedOrigin(TargetPlatform.iOS), youtubeEmbedOriginIos);
      for (final origin in [youtubeEmbedOriginAndroid, youtubeEmbedOriginIos]) {
        final uri = Uri.parse(origin);
        expect(uri.scheme, 'https');
        expect(uri.host, isNot(contains('youtube')));
        // The page's serialized origin, or the player's messages are lost.
        expect(uri.origin, origin);
      }
    });

    test('the origins follow the Android and iOS application ids', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final appId = RegExp(r'applicationId\s*=\s*"([^"]+)"')
          .firstMatch(gradle)![1]!;
      expect(youtubeEmbedOriginAndroid, 'https://${appId.toLowerCase()}');

      final pbx = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      final bundles = RegExp('PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbx)
          .map((m) => m[1]!)
          .where((id) => !id.endsWith('Tests'))
          .toSet();
      expect(bundles, hasLength(1));
      expect(youtubeEmbedOriginIos, 'https://${bundles.single.toLowerCase()}');
    });
  });

  test('player errors: the video’s fault vs our setup', () {
    expect(YoutubePlayerFailure.of(2), YoutubePlayerFailure.invalidRequest);
    expect(YoutubePlayerFailure.of(5), YoutubePlayerFailure.html5);
    expect(YoutubePlayerFailure.of(100), YoutubePlayerFailure.notFound);
    expect(YoutubePlayerFailure.of(105), YoutubePlayerFailure.notFound);
    for (final c in [101, 150]) {
      expect(YoutubePlayerFailure.of(c), YoutubePlayerFailure.notEmbeddable);
      expect(YoutubePlayerFailure.of(c).isConfiguration, isFalse);
    }
    for (final c in [152, 153]) {
      expect(const YoutubePlayerFailed(152).failure.isConfiguration, isTrue);
      expect(YoutubePlayerFailure.of(c), YoutubePlayerFailure.embedderRejected);
    }
    expect(YoutubePlayerFailure.of(999), YoutubePlayerFailure.unknown);
  });

  for (final language in AppLanguage.values) {
    for (final code in [150, 152]) {
      testWidgets('error $code: the honest overlay, no reload loop '
          '(${language.name})', (tester) async {
        setViewport(tester, GoldenViewport.android);
        final now = clock.now();
        final repo = FakeLiveWatchRepository(now: clock.now);
        repo.watches[_room] = LiveWatch(
          roomId: _room,
          video: FakeLiveWatchRepository.videoOf(_vid),
          playing: true,
          positionMs: 0,
          updatedAt: now,
          serverTime: now,
        );
        final engine = FakeLiveMediaEngine();
        final players = FakeYoutubePlayers();
        await pumpScreen(
          tester,
          _Room(engine),
          language: language,
          liveMediaEngine: engine,
          liveWatchRepository: repo,
          youtubePlayers: players,
        );
        await tester.pumpAndSettle();
        final player = players.made.single;
        expect(player.calls.where((c) => c.startsWith('load:')), hasLength(1));

        player.events$.add(YoutubePlayerFailed(code));
        await tester.pump(); // the event
        await tester.pump(); // the frame
        final l10n = lookupAppLocalizations(Locale(language.name));
        expect(find.text(l10n.liveWatchPlayerError), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        expect(player.calls.where((c) => c.startsWith('load:')), hasLength(1));
      });
    }
  }
}
