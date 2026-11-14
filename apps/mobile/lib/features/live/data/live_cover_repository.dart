import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// The host's live cover (CP-015, CONVENTIONS §10.13): one square picture
/// reused by every live. The photo itself is uploaded first as a
/// `LIVE_COVER` asset (`MediaRepository.uploadPhoto(forLiveCover: true)`).
///
/// Every method throws an `AppFailure`.
abstract interface class LiveCoverRepository {
  /// `PUT /me/live-cover`: the cover is now [mediaId]; returns its URL.
  Future<String> setCover(String mediaId);

  /// `DELETE /me/live-cover`: back to the avatar (idempotent).
  Future<void> removeCover();
}

class LiveCoverRepositoryImpl implements LiveCoverRepository {
  new(this._api);

  final Dio _api;

  @override
  Future<String> setCover(String mediaId) => guardApiCall(() async {
    final res = await _api.put<Map<String, dynamic>>(
      '/me/live-cover',
      data: {'mediaId': mediaId},
    );
    return res.data!['coverUrl']! as String;
  });

  @override
  Future<void> removeCover() =>
      guardApiCall(() => _api.delete<void>('/me/live-cover'));
}

final liveCoverRepositoryProvider = Provider<LiveCoverRepository>(
  (ref) => LiveCoverRepositoryImpl(ref.watch(apiDioProvider)),
);
