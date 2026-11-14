import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// v1.109-social (D344): opens a page in an in-app browser tab — Android
/// Custom Tabs, iOS `SFSafariViewController` (url_launcher's
/// `LaunchMode.inAppBrowserView`). It looks part of the app and has its own
/// close button back to the screen that opened it, while the payment pages
/// keep a real browser: Stripe's 3-D Secure, Google Pay and Apple Pay are not
/// reliably supported in a WebView. Where no in-app tab exists (no Custom
/// Tabs provider), the system browser. A fake in tests.
abstract interface class InAppBrowserOpener {
  /// Whether a browser opened [url].
  Future<bool> open(Uri url);
}

class UrlLauncherInAppBrowser implements InAppBrowserOpener {
  const new();

  @override
  Future<bool> open(Uri url) async {
    try {
      if (await launcher.supportsLaunchMode(
        launcher.LaunchMode.inAppBrowserView,
      )) {
        return await launcher.launchUrl(
          url,
          mode: launcher.LaunchMode.inAppBrowserView,
        );
      }
      return await launcher.launchUrl(
        url,
        mode: launcher.LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }
}

final inAppBrowserOpenerProvider = Provider<InAppBrowserOpener>(
  (ref) => const UrlLauncherInAppBrowser(),
);
