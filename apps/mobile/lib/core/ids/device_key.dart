import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// v1.78-social (D223, CONVENTIONS §10.75): the phone's stable device id
/// for the «at most 2 accounts created per device» rule
/// (`DeviceInfo.deviceKey`), sent with a sign-up (`register` and
/// `registerVerify`) and, v1.60-live (D250, §10.91.6), with a sign-in
/// (`login`), so a device the team banned «حظر جهاز» is refused.
///
/// The platform gives the raw id over the `com.kabso/device_id` channel:
/// Android `Settings.Secure.ANDROID_ID` (per app-signing key and device; it
/// survives a reinstall, not a factory reset), iOS a UUID kept in the
/// Keychain (seeded from `identifierForVendor`; the Keychain survives a
/// reinstall). The raw id never leaves the phone: the app sends
/// SHA-256(`salt|platform|id`) and the server keeps only an HMAC of that.
///
/// Null on the web, on other platforms, or when the platform gives no id:
/// then the sign-up is sent without one (as from an older app).
abstract interface class DeviceKeySource {
  Future<String?> read();
}

/// The app's salt for the device key (not a secret: it only keeps the sent
/// value from equalling a hash of the raw id that another app could compute).
const deviceKeySalt = 'kabso-live/device-key/v1';

/// SHA-256 hex of the raw [id] with the salt and the [platform].
String deviceKeyOf(String platform, String id) => sha256
    .convert(utf8.encode('$deviceKeySalt|$platform|${id.trim()}'))
    .toString();

class PlatformDeviceKeySource implements DeviceKeySource {
  static const channel = MethodChannel('com.kabso/device_id');

  String? _cached;

  @override
  Future<String?> read() async {
    final cached = _cached;
    if (cached != null) return cached;
    if (kIsWeb) return null;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) return null;
    try {
      final raw = await channel
          .invokeMethod<String>('stableId')
          .timeout(const Duration(seconds: 3));
      if (raw == null || raw.trim().isEmpty) return null;
      // Old Android emulators give the same well-known value to everyone.
      if (raw.trim().toLowerCase() == '9774d56d682e549c') return null;
      return _cached = deviceKeyOf(platform, raw);
    } on Object catch (error) {
      debugPrint('Device id unavailable: $error');
      return null;
    }
  }
}

final deviceKeySourceProvider = Provider<DeviceKeySource>(
  (ref) => PlatformDeviceKeySource(),
);
