import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/features/kyc/data/kyc_repository.dart';

/// v1.80-kyc (D227): whether Didit is on and the caller's checks per purpose
/// (`GET /me/kyc`).
final FutureProvider<MyKyc> myKycProvider = FutureProvider.autoDispose((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(kycRepositoryProvider).mine();
});
