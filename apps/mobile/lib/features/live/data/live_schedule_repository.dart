import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:material_ui/material_ui.dart';

/// The most upcoming lives a host may schedule (CONVENTIONS §10.16).
const int maxLiveScheduleSlots = 10;

/// The longest title of a scheduled live, in characters.
const int maxLiveScheduleTitleLength = 60;

/// A slot starts at least this far ahead…
const Duration liveScheduleMinLead = Duration(minutes: 15);

/// …and at most this far ahead.
const Duration liveScheduleMaxLead = Duration(days: 30);

/// `LiveScheduleSlot`: a live the host announced.
@immutable
class LiveScheduleSlot {
  const new({required this.id, required this.title, required this.startsAt});

  factory fromJson(Map<String, dynamic> json) => LiveScheduleSlot(
    id: json['id']! as String,
    title: json['title']! as String,
    startsAt: DateTime.parse(json['startsAt']! as String),
  );

  final String id;
  final String title;
  final DateTime startsAt;
}

/// The host's live schedule (CP-016 C, CONVENTIONS §10.16): followers are
/// reminded 15 minutes before each start. Every method throws an
/// `AppFailure`.
abstract interface class LiveScheduleRepository {
  /// `GET /me/live-schedule`: the upcoming slots, soonest first.
  Future<List<LiveScheduleSlot>> list();

  /// `POST /me/live-schedule`.
  Future<LiveScheduleSlot> create({
    required String title,
    required DateTime startsAt,
  });

  /// `DELETE /me/live-schedule/{slotId}`.
  Future<void> remove(String slotId);
}

class LiveScheduleRepositoryImpl implements LiveScheduleRepository {
  new(this._api);

  final Dio _api;

  @override
  Future<List<LiveScheduleSlot>> list() => guardApiCall(() async {
    final res = await _api.get<Map<String, dynamic>>('/me/live-schedule');
    return [
      for (final s in res.data!['data']! as List<dynamic>)
        LiveScheduleSlot.fromJson(s as Map<String, dynamic>),
    ];
  });

  @override
  Future<LiveScheduleSlot> create({
    required String title,
    required DateTime startsAt,
  }) => guardApiCall(() async {
    final res = await _api.post<Map<String, dynamic>>(
      '/me/live-schedule',
      data: {'title': title, 'startsAt': startsAt.toUtc().toIso8601String()},
    );
    return LiveScheduleSlot.fromJson(res.data!);
  });

  @override
  Future<void> remove(String slotId) => guardApiCall(() async {
    await _api.delete<void>('/me/live-schedule/$slotId');
  });
}

final liveScheduleRepositoryProvider = Provider<LiveScheduleRepository>(
  (ref) => LiveScheduleRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The host's upcoming scheduled lives (refreshed after every change).
final FutureProvider<List<LiveScheduleSlot>> liveScheduleProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(liveScheduleRepositoryProvider).list(),
    );
