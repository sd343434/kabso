import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';

/// A segment the host wants: its start and its title.
typedef LiveProgramDraft = ({DateTime startsAt, String title});

/// A live's program (v1.36-live, D154e, CONVENTIONS §10.37):
/// `GET /live/rooms/{roomId}/program` (anyone in the room) and
/// `PUT …/program` (the host, the whole program). Throws an `AppFailure`.
abstract interface class LiveProgramRepository {
  Future<LiveProgram> get(String roomId);

  Future<LiveProgram> set(String roomId, List<LiveProgramDraft> items);
}

class LiveProgramRepositoryImpl implements LiveProgramRepository {
  new(this._dio);

  final Dio _dio;

  String _path(String roomId) => '/live/rooms/${pathSegment(roomId)}/program';

  @override
  Future<LiveProgram> get(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path(roomId));
    return LiveProgram.fromJson(res.data!);
  });

  @override
  Future<LiveProgram> set(String roomId, List<LiveProgramDraft> items) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          _path(roomId),
          data: {
            'items': [
              for (final i in items)
                {
                  'startsAt': i.startsAt.toUtc().toIso8601String(),
                  'title': i.title,
                },
            ],
          },
        );
        return LiveProgram.fromJson(res.data!);
      });
}

final liveProgramRepositoryProvider = Provider<LiveProgramRepository>(
  (ref) => LiveProgramRepositoryImpl(ref.watch(apiDioProvider)),
);
