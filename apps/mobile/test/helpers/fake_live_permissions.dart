import 'package:kabso_live/features/live/data/live_permissions.dart';

/// D144a: in-memory [LivePermissions]. [state] is what the device says;
/// [afterRequest] what it says once the system prompt was answered (null:
/// [state] unchanged). Records every call with its `camera` flag.
class FakeLivePermissions implements LivePermissions {
  new({this.state = LivePermission.granted, this.afterRequest});

  LivePermission state;
  LivePermission? afterRequest;

  /// `camera` of each [check] and [request].
  final List<bool> checks = [];
  final List<bool> requests = [];
  int settingsOpened = 0;

  @override
  Future<LivePermission> check({required bool camera}) async {
    checks.add(camera);
    return state;
  }

  @override
  Future<LivePermission> request({required bool camera}) async {
    requests.add(camera);
    if (afterRequest case final next?) state = next;
    return state;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
