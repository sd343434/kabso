// v1.80-kyc (D227): an in-memory «تأكيد الهوية» for widget tests — Didit off
// by default (the manual ID pictures), or on with a state per purpose; starts,
// syncs and the hosted flow are recorded, never a network call.

import 'package:flutter/widgets.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/features/kyc/data/kyc_repository.dart';
import 'package:kabso_live/features/kyc/presentation/kyc_flow.dart';

class FakeKycRepository implements KycRepository {
  new({MyKyc? state}) : state = state ?? MyKyc.off;

  MyKyc state;
  final starts = <(KycPurpose, String?)>[];
  final syncs = <String>[];

  /// What a sync turns the started purpose into (null: unchanged).
  KycPurposeState? afterSync;
  Object? startError;

  @override
  Future<MyKyc> mine() async => state;

  @override
  Future<KycSessionStart> start(KycPurpose purpose, {String? language}) async {
    starts.add((purpose, language));
    final error = startError;
    // The repositories throw `AppFailure`s (guardApiCall).
    // ignore: only_throw_errors
    if (error != null) throw error;
    return KycSessionStart(
      check: KycCheck(
        id: 'check-${starts.length}',
        purpose: purpose,
        status: KycStatus.notStarted,
        reasons: const [],
        createdAt: DateTime.utc(2026, 11),
      ),
      url: 'https://verify.didit.me/session/test',
      callbackUrl: 'kabsolive://kyc/done',
    );
  }

  @override
  Future<KycCheck> sync(String checkId) async {
    syncs.add(checkId);
    final next = afterSync;
    if (next != null) {
      state = MyKyc(
        enabled: state.enabled,
        maxSessionsPerDay: state.maxSessionsPerDay,
        startedLast24h: state.startedLast24h + 1,
        purposes: [
          for (final p in state.purposes)
            if (p.purpose != next.purpose) p,
          next,
        ],
      );
    }
    return next?.check ??
        KycCheck(
          id: checkId,
          purpose: KycPurpose.hostApplication,
          status: KycStatus.inProgress,
          reasons: const [],
          createdAt: DateTime.utc(2026, 11),
        );
  }
}

/// The hosted flow, faked: records the sessions and finishes (or not).
class FakeKycFlow implements KycFlowLauncher {
  new({this.finishes = true});

  final bool finishes;
  final opened = <KycSessionStart>[];

  @override
  Future<bool> open(BuildContext context, KycSessionStart session) async {
    opened.add(session);
    return finishes;
  }
}

/// Didit on, with [purposes] (the others not started).
MyKyc kycOn(List<KycPurposeState> purposes, {int started = 0}) => MyKyc(
  enabled: true,
  maxSessionsPerDay: 3,
  startedLast24h: started,
  purposes: purposes,
);

KycPurposeState kycState(
  KycPurpose purpose,
  KycStatus status, {
  List<String> reasons = const [],
  bool? canStart,
  KycRefusal? refusal,
}) => KycPurposeState(
  purpose: purpose,
  approved: status == KycStatus.approved,
  canStart:
      canStart ??
      (status != KycStatus.approved && status != KycStatus.inReview),
  refusal: refusal,
  check: status == KycStatus.notStarted
      ? null
      : KycCheck(
          id: 'check-${purpose.wire}',
          purpose: purpose,
          status: status,
          reasons: reasons,
          createdAt: DateTime.utc(2026, 11),
          decidedAt: DateTime.utc(2026, 11),
        ),
);
