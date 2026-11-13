import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// D201 (v1.45-live, CONVENTIONS §10.63) `LiveSecondCamera.status`.
enum SecondCameraStatus { none, code, paired, connected }

/// Which feed is full screen (the other is the small picture).
enum SecondCameraFeed { host, second }

/// Why no pairing code can be created now.
enum SecondCameraUnavailable { notLive, notSolo, pk }

SecondCameraFeed _feed(Object? value) =>
    value == 'SECOND' ? SecondCameraFeed.second : SecondCameraFeed.host;

/// `LiveSecondCamera`.
@immutable
class SecondCameraState {
  const new({
    required this.status,
    required this.main,
    required this.available,
    this.codeExpiresAt,
    this.unavailableReason,
  });

  factory fromJson(Map<String, dynamic> json) => SecondCameraState(
    status: switch (json['status']) {
      'CODE' => SecondCameraStatus.code,
      'PAIRED' => SecondCameraStatus.paired,
      'CONNECTED' => SecondCameraStatus.connected,
      _ => SecondCameraStatus.none,
    },
    codeExpiresAt: DateTime.tryParse('${json['codeExpiresAt']}'),
    main: _feed(json['main']),
    available: json['available'] == true,
    unavailableReason: switch (json['unavailableReason']) {
      'NOT_LIVE' => SecondCameraUnavailable.notLive,
      'NOT_SOLO' => SecondCameraUnavailable.notSolo,
      'PK' => SecondCameraUnavailable.pk,
      _ => null,
    },
  );

  static const none = SecondCameraState(
    status: SecondCameraStatus.none,
    main: SecondCameraFeed.host,
    available: true,
  );

  final SecondCameraStatus status;
  final DateTime? codeExpiresAt;
  final SecondCameraFeed main;
  final bool available;
  final SecondCameraUnavailable? unavailableReason;

  bool get paired =>
      status == SecondCameraStatus.paired ||
      status == SecondCameraStatus.connected;
}

/// `LiveSecondCameraCode`.
@immutable
class SecondCameraCode {
  const new({required this.code, required this.expiresAt});

  factory fromJson(Map<String, dynamic> json) => SecondCameraCode(
    code: json['code']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
  );

  final String code;
  final DateTime expiresAt;
}

/// `LiveSecondCameraAccess`: what the second device joins the media room with.
@immutable
class SecondCameraAccess {
  const new({
    required this.roomId,
    required this.hostUserId,
    required this.url,
    required this.token,
    required this.expiresAt,
    required this.identity,
  });

  factory fromJson(Map<String, dynamic> json) => SecondCameraAccess(
    roomId: json['roomId']! as String,
    hostUserId: json['hostUserId']! as String,
    url: json['url']! as String,
    token: json['token']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    identity: json['identity']! as String,
  );

  final String roomId;
  final String hostUserId;
  final String url;
  final String token;
  final DateTime expiresAt;
  final String identity;
}

/// D201: the host's live tools on the server — the second camera, the
/// recording indicator and the music-rights notice. Every method throws an
/// `AppFailure`.
abstract interface class LiveToolsRepository {
  /// `GET /live/rooms/{roomId}/second-camera`.
  Future<SecondCameraState> secondCamera(String roomId);

  /// `POST /live/rooms/{roomId}/second-camera/codes`.
  Future<SecondCameraCode> createCode(String roomId);

  /// `DELETE /live/rooms/{roomId}/second-camera` (either device).
  Future<void> endSecondCamera(String roomId);

  /// `PUT /live/rooms/{roomId}/second-camera/main`.
  Future<SecondCameraState> setMain(String roomId, SecondCameraFeed main);

  /// `POST /live/second-camera/redeem` (the second device).
  Future<SecondCameraAccess> redeem(String code);

  /// `PUT /live/rooms/{roomId}/recording`.
  Future<void> setRecording(String roomId, {required bool active});

  /// `GET /me/live-music-rights`: whether the notice was accepted.
  Future<bool> musicRightsAccepted();

  /// `PUT /me/live-music-rights` (`noticeVersion` 1).
  Future<void> acceptMusicRights();
}

class LiveToolsRepositoryImpl implements LiveToolsRepository {
  new(this._dio);

  final Dio _dio;

  String _cam(String roomId) =>
      '/live/rooms/${pathSegment(roomId)}/second-camera';

  @override
  Future<SecondCameraState> secondCamera(String roomId) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(_cam(roomId));
        return SecondCameraState.fromJson(res.data!);
      });

  @override
  Future<SecondCameraCode> createCode(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_cam(roomId)}/codes',
      data: const <String, Object>{},
    );
    return SecondCameraCode.fromJson(res.data!);
  });

  @override
  Future<void> endSecondCamera(String roomId) => guardApiCall(() async {
    await _dio.delete<void>(_cam(roomId));
  });

  @override
  Future<SecondCameraState> setMain(String roomId, SecondCameraFeed main) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '${_cam(roomId)}/main',
          data: {'main': main == SecondCameraFeed.second ? 'SECOND' : 'HOST'},
        );
        return SecondCameraState.fromJson(res.data!);
      });

  @override
  Future<SecondCameraAccess> redeem(String code) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/live/second-camera/redeem',
      data: {'code': code},
    );
    return SecondCameraAccess.fromJson(res.data!);
  });

  @override
  Future<void> setRecording(String roomId, {required bool active}) =>
      guardApiCall(() async {
        await _dio.put<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}/recording',
          data: {'active': active},
        );
      });

  @override
  Future<bool> musicRightsAccepted() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/live-music-rights');
    return res.data!['accepted'] == true;
  });

  @override
  Future<void> acceptMusicRights() => guardApiCall(() async {
    await _dio.put<Map<String, dynamic>>(
      '/me/live-music-rights',
      data: const {'noticeVersion': 1},
    );
  });
}

final liveToolsRepositoryProvider = Provider<LiveToolsRepository>(
  (ref) => LiveToolsRepositoryImpl(ref.watch(apiDioProvider)),
);
