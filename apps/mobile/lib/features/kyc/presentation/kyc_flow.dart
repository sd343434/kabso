import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// v1.80-kyc (D227): opens Didit's hosted flow for a session. True when the
/// flow reached its end (the callback address), false when the person closed
/// it. Tests replace it ([kycFlowLauncherProvider]).
abstract interface class KycFlowLauncher {
  Future<bool> open(BuildContext context, KycSessionStart session);
}

/// Didit's documented app integration: the hosted flow in an in-app WebView
/// (JavaScript on, inline media, the page granted the camera) that closes when
/// it navigates to [KycSessionStart.callbackUrl].
class WebViewKycFlowLauncher implements KycFlowLauncher {
  const new();

  @override
  Future<bool> open(BuildContext context, KycSessionStart session) async {
    await _askCamera();
    if (!context.mounted) return false;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KycWebViewScreen(session: session),
      ),
    );
    return done ?? false;
  }

  /// The page asks for the camera through the WebView, which can only pass
  /// on a permission the app holds: ask for it first (the same system prompt
  /// a live uses), then release the camera at once.
  static Future<void> _askCamera() async {
    if (kIsWeb) return;
    try {
      final stream = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': true,
      });
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } on Object {
      // Refused or unavailable: the page explains what it needs.
    }
  }
}

final kycFlowLauncherProvider = Provider<KycFlowLauncher>(
  (ref) => const WebViewKycFlowLauncher(),
);

/// The hosted flow, full screen, with «إغلاق» and «فتح في المتصفح».
class KycWebViewScreen extends StatefulWidget {
  const new({required this.session, super.key});

  final KycSessionStart session;

  @override
  State<KycWebViewScreen> createState() => _KycWebViewScreenState();
}

class _KycWebViewScreenState extends State<KycWebViewScreen> {
  late final WebViewController _controller;
  var _progress = 0;

  bool _isCallback(String url) => url.startsWith(widget.session.callbackUrl);

  @override
  void initState() {
    super.initState();
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const {},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params);
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (request) {
            if (_isCallback(request.url)) {
              if (mounted) Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      ),
    );
    final platform = _controller.platform;
    unawaited(
      platform.setOnPlatformPermissionRequest(
        (request) => unawaited(request.grant()),
      ),
    );
    if (platform is AndroidWebViewController) {
      unawaited(platform.setMediaPlaybackRequiresUserGesture(false));
    }
    unawaited(_controller.loadRequest(Uri.parse(widget.session.url)));
  }

  Future<void> _openOutside() async {
    final uri = Uri.parse(widget.session.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.kycStepTitle),
        leading: IconButton(
          tooltip: l10n.kycClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            tooltip: l10n.kycOpenInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () => unawaited(_openOutside()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(value: _progress / 100, minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
