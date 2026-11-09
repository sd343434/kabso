import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// v1.112-social (int21, CONVENTIONS §10.143.3; owner «موافق على
/// الاقتراحات», D345 #7 + D344): where this copy of the app was installed
/// from — `DeviceInfo.installSource` at sign-in and `installSource` in the
/// refresh body. The server keeps it on the session and offers the wallet's
/// «الشحن من الموقع» only to the sources it allows (default: the direct APK).
///
/// - Android: the installer package from the system (`installerPackage` on
///   the `com.kabso/device_id` channel): Google Play (`com.android.vending`)
///   ⇒ [installSourcePlay]; any other installer or none ⇒
///   [installSourceSideload].
/// - iOS: always [installSourceAppStore] (TestFlight counts as the App Store).
/// - The web and other platforms, or a failed platform call: null (nothing is
///   reported, never a guess).
abstract interface class InstallSourceReader {
  Future<String?> read();
}

const installSourcePlay = 'PLAY';
const installSourceAppStore = 'APP_STORE';
const installSourceSideload = 'SIDELOAD';

/// Google Play's installer package.
const playStoreInstaller = 'com.android.vending';

/// The install source of an Android build installed by [installer].
String androidInstallSourceOf(String? installer) =>
    installer?.trim() == playStoreInstaller
    ? installSourcePlay
    : installSourceSideload;

class PlatformInstallSourceReader implements InstallSourceReader {
  new({this._platform, this._isWeb});

  static const channel = MethodChannel('com.kabso/device_id');

  /// False in widget tests (`flutter_test_config.dart`): no platform call,
  /// nothing reported (a test that needs a source passes its own reader).
  static bool enabled = true;

  final TargetPlatform? _platform;
  final bool? _isWeb;
  Future<String?>? _once;

  @override
  Future<String?> read() => _once ??= _read();

  Future<String?> _read() async {
    if (!enabled || (_isWeb ?? kIsWeb)) return null;
    switch (_platform ?? defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return installSourceAppStore;
      case TargetPlatform.android:
        try {
          final installer = await channel
              .invokeMethod<String>('installerPackage')
              .timeout(const Duration(seconds: 3));
          return androidInstallSourceOf(installer);
        } on Object catch (error) {
          debugPrint('Install source unavailable: $error');
          // Not cached: the next sign-in or refresh asks again.
          _once = null;
          return null;
        }
      case _:
        return null;
    }
  }
}

final installSourceReaderProvider = Provider<InstallSourceReader>(
  (ref) => PlatformInstallSourceReader(),
);
