import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// What the YouTube player says (D154i).
sealed class YoutubePlayerEvent {
  const new();
}

/// The player can take commands.
final class YoutubePlayerReady extends YoutubePlayerEvent {
  const new();
}

/// The player started, paused or ended at [positionMs].
final class YoutubePlayerStateChanged extends YoutubePlayerEvent {
  const new({
    required this.playing,
    required this.ended,
    required this.positionMs,
  });

  final bool playing;
  final bool ended;
  final int positionMs;
}

/// The player could not play the video (YouTube's error [code], see
/// [YoutubePlayerFailure]).
final class YoutubePlayerFailed extends YoutubePlayerEvent {
  const new(this.code);

  final int code;

  YoutubePlayerFailure get failure => YoutubePlayerFailure.of(code);
}

/// What a YouTube player error means (D154k). The viewer sees the same
/// honest «تعذّر تشغيل الفيديو على هذا الهاتف» for all of them; the log
/// tells a video that cannot be shown here from a player we set up wrong.
enum YoutubePlayerFailure {
  /// 2: the id or a parameter is malformed.
  invalidRequest,

  /// 5: the HTML5 player failed on this phone.
  html5,

  /// 100 / 105: removed, private or not found.
  notFound,

  /// 101 / 150: the owner does not allow embedded playback (the server's
  /// oEmbed check catches most of these first, D154i).
  notEmbeddable,

  /// 152 / 153 (shown as e.g. «152 - 4»): YouTube refused the embedder's
  /// identity — no or a wrong Referer / origin (an app page claiming to be
  /// youtube.com gets 152-4). Our configuration, not the video.
  embedderRejected,

  /// Any other code.
  unknown;

  static YoutubePlayerFailure of(int code) => switch (code) {
    2 => invalidRequest,
    5 => html5,
    100 || 105 => notFound,
    101 || 150 => notEmbeddable,
    152 || 153 => embedderRejected,
    _ => unknown,
  };

  /// The player's setup is at fault, not the video.
  bool get isConfiguration => this == embedderRejected;
}

/// The https origin the embed page runs at, sent to YouTube as the
/// Referer and as the `origin` / `widget_referrer` player parameters
/// (D154k). YouTube identifies an app's embedded player by it and refuses
/// a page with no Referer (153) or one that claims to be youtube.com
/// itself (152-4, D154i's mistake), so a web-view app identifies itself
/// with its own application id as `https://<app id>` — what
/// android-youtube-player 13 does on Android. Lower case: it must equal
/// the page's serialized origin, or the player's messages to the page are
/// dropped. These must follow the Android `applicationId` and the iOS
/// `PRODUCT_BUNDLE_IDENTIFIER` (a test checks them; the final id is B7).
String youtubeEmbedOrigin([TargetPlatform? platform]) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => youtubeEmbedOriginIos,
      _ => youtubeEmbedOriginAndroid,
    };

const youtubeEmbedOriginAndroid = 'https://com.kabso.kabso_live';
const youtubeEmbedOriginIos = 'https://com.kabso.kabsolive';

/// One official YouTube embedded player (D154i, CONVENTIONS §10.39: the
/// YouTube IFrame player only, per YouTube's terms; the video streams
/// from YouTube to this phone).
abstract interface class YoutubePlayer {
  /// The player itself.
  Widget view();

  Stream<YoutubePlayerEvent> get events;

  /// Shows [videoId] from [startMs], playing or not.
  Future<void> load(String videoId, {required int startMs, required bool play});

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(int ms);

  /// Where the video is now; null before it is ready.
  Future<int?> positionMs();

  void dispose();
}

/// Makes a player: with YouTube's own controls ([controls], the host) or
/// none (viewers follow the host).
typedef YoutubePlayerFactory = YoutubePlayer Function({required bool controls});

final Provider<YoutubePlayerFactory> youtubePlayerFactoryProvider =
    Provider<YoutubePlayerFactory>(
      (ref) =>
          ({required controls}) => WebViewYoutubePlayer(controls: controls),
    );

/// [YoutubePlayer] on the YouTube IFrame Player API in a web view: the page
/// is YouTube's own embed script, loaded at [origin] (D154k); the app talks
/// to it through a JavaScript channel (`Kabso`). Autoplay is allowed
/// without a tap (the room follows the host): JavaScript on, Android's
/// media without a user gesture, iOS inline with no media needing a tap.
/// The web view's own user agent is kept (YouTube serves its mobile
/// player to it). Not run in widget tests (no web view there).
class WebViewYoutubePlayer implements YoutubePlayer {
  new({required this.controls, String? origin})
    : origin = origin ?? youtubeEmbedOrigin() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params);
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_controller.setBackgroundColor(const Color(0xFF000000)));
    unawaited(
      _controller.addJavaScriptChannel('Kabso', onMessageReceived: _onMessage),
    );
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
  }

  final bool controls;

  /// Where the embed page runs (its base URL), see [youtubeEmbedOrigin].
  final String origin;
  late final WebViewController _controller;
  final _events = StreamController<YoutubePlayerEvent>.broadcast();

  @override
  Stream<YoutubePlayerEvent> get events => _events.stream;

  void _onMessage(JavaScriptMessage message) {
    try {
      final m = jsonDecode(message.message) as Map<String, dynamic>;
      final ms = ((m['t'] as num?) ?? 0) * 1000;
      switch (m['e']) {
        case 'ready':
          _events.add(const YoutubePlayerReady());
        case 'state':
          final s = (m['s'] as num?)?.toInt();
          if (s == 1 || s == 2 || s == 0) {
            _events.add(
              YoutubePlayerStateChanged(
                playing: s == 1,
                ended: s == 0,
                positionMs: ms.round(),
              ),
            );
          }
        case 'error':
          _events.add(YoutubePlayerFailed((m['c'] as num?)?.toInt() ?? 0));
      }
    } on Object {
      // Not ours.
    }
  }

  @override
  Widget view() => WebViewWidget(controller: _controller);

  /// The embed page (the official IFrame API), to be loaded at [origin]:
  /// the player's `origin` and `widget_referrer` name the page's own
  /// origin, and the Referer sent with the player's request carries it.
  static String page({
    required String videoId,
    required int startSeconds,
    required bool autoplay,
    required bool controls,
    required String origin,
  }) =>
      '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
</head><body><div id="p"></div>
<script>
var player;
function post(o){try{Kabso.postMessage(JSON.stringify(o));}catch(e){}}
function onYouTubeIframeAPIReady(){
  player=new YT.Player('p',{width:'100%',height:'100%',videoId:'$videoId',
    playerVars:{playsinline:1,controls:${controls ? 1 : 0},disablekb:${controls ? 0 : 1},rel:0,fs:0,
      iv_load_policy:3,start:$startSeconds,autoplay:${autoplay ? 1 : 0},enablejsapi:1,
      origin:'$origin',widget_referrer:'$origin'},
    events:{
      onReady:function(){post({e:'ready'});${autoplay ? 'player.playVideo();' : ''}},
      onStateChange:function(ev){post({e:'state',s:ev.data,t:player.getCurrentTime()});},
      onError:function(ev){post({e:'error',c:ev.data});}
    }});
}
function k(fn){if(player&&player[fn]){return true;}return false;}
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body></html>''';

  static final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  @override
  Future<void> load(
    String videoId, {
    required int startMs,
    required bool play,
  }) async {
    if (!_id.hasMatch(videoId)) return;
    await _controller.loadHtmlString(
      page(
        videoId: videoId,
        startSeconds: startMs ~/ 1000,
        autoplay: play,
        controls: controls,
        origin: origin,
      ),
      baseUrl: origin,
    );
  }

  Future<void> _run(String js) async {
    try {
      await _controller.runJavaScript(js);
    } on Object {
      // The page is not ready yet.
    }
  }

  @override
  Future<void> play() => _run("if(k('playVideo'))player.playVideo();");

  @override
  Future<void> pause() => _run("if(k('pauseVideo'))player.pauseVideo();");

  @override
  Future<void> seekTo(int ms) =>
      _run("if(k('seekTo'))player.seekTo(${ms / 1000},true);");

  @override
  Future<int?> positionMs() async {
    try {
      final r = await _controller.runJavaScriptReturningResult(
        '(player&&player.getCurrentTime)?player.getCurrentTime():-1',
      );
      final v = r is num ? r : num.tryParse('$r');
      if (v == null || v < 0) return null;
      return (v * 1000).round();
    } on Object {
      return null;
    }
  }

  @override
  void dispose() => unawaited(_events.close());
}
