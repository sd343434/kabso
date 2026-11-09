import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// v1.99-social (D311, CONVENTIONS §10.117): the founder's moderation actions
/// «إجراءات المؤسس» (owner: «يمكنه حذف او حظر او تحذير اي شخص»).
enum FounderAction {
  /// «تحذير»: the person is told; the account stays as it is.
  warn('WARN'),

  /// «حظر مؤقت»: a ban for a number of days ([founderSuspendDays]).
  suspend('SUSPEND'),

  /// «حظر دائم»: the panel's ban.
  ban('BAN'),

  /// «حذف الحساب»: the D193 deletion with its grace period.
  deleteAccount('DELETE_ACCOUNT');

  new(this.wire);

  final String wire;

  /// Banning or deleting is destructive (red, a confirmation).
  bool get destructive => this != FounderAction.warn;
}

/// The durations the app offers for «حظر مؤقت» (the server accepts 1–365).
const founderSuspendDays = <int>[1, 3, 7, 30, 90];

/// `OwnerModerationResult`: what was done.
class FounderActionResult {
  const new({
    required this.id,
    required this.action,
    required this.replayed,
    this.endsAt,
    this.purgeAfter,
  });

  factory fromJson(Map<String, dynamic> json) => FounderActionResult(
    id: json['id'] as String,
    action: FounderAction.values.firstWhere(
      (a) => a.wire == json['action'],
      orElse: () => FounderAction.warn,
    ),
    replayed: json['replayed'] == true,
    endsAt: switch (json['endsAt']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    purgeAfter: switch (json['purgeAfter']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );

  final String id;
  final FounderAction action;
  final bool replayed;
  final DateTime? endsAt;
  final DateTime? purgeAfter;
}

/// The founder's actions on an account. Every method throws an `AppFailure`
/// (403 `OWNER_ONLY` for anyone but the app owner; 409 `ADMIN_ACTION_REFUSED`
/// on himself, another owner or an account that is not active; 409
/// `ACCOUNT_DELETION_BLOCKED`).
abstract interface class FounderModerationRepository {
  /// `POST /owner/users/{userId}/actions`; a retry with the same [clientId]
  /// returns the first result (nothing is done twice).
  Future<FounderActionResult> act({
    required String userId,
    required FounderAction action,
    required String reason,
    required String clientId,
    int? days,
  });
}

class FounderModerationRepositoryImpl implements FounderModerationRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<FounderActionResult> act({
    required String userId,
    required FounderAction action,
    required String reason,
    required String clientId,
    int? days,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/owner/users/${Uri.encodeComponent(userId)}/actions',
      data: {
        'action': action.wire,
        'reason': reason,
        'clientId': clientId,
        if (action == FounderAction.suspend && days != null) 'days': days,
      },
    );
    return FounderActionResult.fromJson(res.data!);
  });
}

final founderModerationRepositoryProvider =
    Provider<FounderModerationRepository>(
      (ref) => FounderModerationRepositoryImpl(ref.watch(apiDioProvider)),
    );
