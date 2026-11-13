import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';

/// D144a: where the camera and microphone permissions stand for a live
/// (all that a capture needs, taken together).
enum LivePermission {
  granted,

  /// Never asked: explain first, then the system asks once.
  notAsked,

  /// Refused, but the system can still ask.
  denied,

  /// Refused for good: only the app's settings can change it (the screen's
  /// «فتح الإعدادات» button).
  blocked,

  /// This platform cannot tell (iOS, the web): the capture asks by itself,
  /// as before.
  unknown;

  /// The capture may start (the system will not show a prompt we did not
  /// explain, except where we cannot tell).
  bool get canStart => this == granted || this == unknown;
}

/// D144a: camera and microphone permissions for going live and for seats.
/// An audio room (or an audio seat) needs the **microphone only** — never
/// the camera (`camera: false`).
abstract interface class LivePermissions {
  /// Where the permissions stand, without asking.
  Future<LivePermission> check({required bool camera});

  /// Asks the system (once) for those not granted; where they stand after.
  Future<LivePermission> request({required bool camera});

  /// Opens this app's page in the system settings; false when it could not.
  Future<bool> openSettings();
}

/// [LivePermissions] on the camera plugin's permission channel (Android);
/// [LivePermission.unknown] elsewhere.
class DeviceLivePermissions implements LivePermissions {
  new([KabsoPermissions? plugin]) : _plugin = plugin ?? KabsoPermissions();

  final KabsoPermissions _plugin;

  /// Off in widget tests (test/flutter_test_config.dart): a platform channel
  /// with no handler never answers inside fake time. Tests of the flow
  /// override [livePermissionsProvider].
  static bool enabled = true;

  static Set<KabsoPermission> _needed({required bool camera}) => {
    if (camera) KabsoPermission.camera,
    KabsoPermission.microphone,
  };

  @override
  Future<LivePermission> check({required bool camera}) async =>
      combine((await _plugin.status(_needed(camera: camera))).values);

  @override
  Future<LivePermission> request({required bool camera}) async =>
      combine((await _plugin.request(_needed(camera: camera))).values);

  @override
  Future<bool> openSettings() => _plugin.openSettings();

  /// The state of a capture that needs all of [statuses]: the worst one.
  static LivePermission combine(Iterable<KabsoPermissionStatus> statuses) {
    LivePermission one(KabsoPermissionStatus s) => switch (s) {
      KabsoPermissionStatus.granted => LivePermission.granted,
      KabsoPermissionStatus.notAsked => LivePermission.notAsked,
      KabsoPermissionStatus.denied => LivePermission.denied,
      KabsoPermissionStatus.blocked => LivePermission.blocked,
      KabsoPermissionStatus.unknown => LivePermission.unknown,
    };
    const order = [
      LivePermission.blocked,
      LivePermission.denied,
      LivePermission.notAsked,
      LivePermission.unknown,
      LivePermission.granted,
    ];
    final all = statuses.map(one).toSet();
    if (all.isEmpty) return LivePermission.unknown;
    return order.firstWhere(all.contains);
  }
}

/// [LivePermissions] where the platform cannot tell: everything is
/// [LivePermission.unknown] and the capture asks by itself.
class UnknownLivePermissions implements LivePermissions {
  const new();

  @override
  Future<LivePermission> check({required bool camera}) async =>
      LivePermission.unknown;

  @override
  Future<LivePermission> request({required bool camera}) async =>
      LivePermission.unknown;

  @override
  Future<bool> openSettings() async => false;
}

/// The device's [LivePermissions] (tests override it).
final livePermissionsProvider = Provider<LivePermissions>(
  (ref) => DeviceLivePermissions.enabled
      ? DeviceLivePermissions()
      : const UnknownLivePermissions(),
);
