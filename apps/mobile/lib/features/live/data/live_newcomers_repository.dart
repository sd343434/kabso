import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `LiveNewcomers` (v1.34-live, D154c, §10.35): the newcomers in a live now
/// and the window that makes one (days); never a signup date.
typedef LiveNewcomers = ({int newcomerDays, List<UserSummary> people});

/// `GET /live/rooms/{roomId}/newcomers` (host and moderators). Throws an
/// `AppFailure`.
abstract interface class LiveNewcomersRepository {
  Future<LiveNewcomers> list(String roomId);
}

class LiveNewcomersRepositoryImpl implements LiveNewcomersRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<LiveNewcomers> list(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}/newcomers',
    );
    final body = res.data!;
    return (
      newcomerDays: (body['newcomerDays']! as num).toInt(),
      people: [
        for (final u in body['data']! as List<dynamic>)
          UserSummary.fromJson(u as Map<String, dynamic>),
      ],
    );
  });
}

final liveNewcomersRepositoryProvider = Provider<LiveNewcomersRepository>(
  (ref) => LiveNewcomersRepositoryImpl(ref.watch(apiDioProvider)),
);
