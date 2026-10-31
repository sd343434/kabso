import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/consent_required.dart';
import 'package:kabso_live/features/privacy/privacy_repository.dart';

/// D198: asks the server after a sign-in or a session restore whether a new
/// version of the terms or the privacy policy waits to be accepted. A failure
/// (offline, an older server) leaves the flag as it is: a later 428 sets it.
Future<void> checkConsent(Ref ref) async {
  try {
    final status = await ref.read(privacyRepositoryProvider).consentStatus();
    ref.read(consentRequiredProvider.notifier).value =
        status.required.isNotEmpty;
  } on Object {
    // Nothing to enforce from here.
  }
}
