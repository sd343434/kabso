import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/profile_fields.dart';

/// Register form values kept in memory **only while the verify-first flow is
/// open** (PHASE1_1_SCREENS §1.1), so "Change email" returns to a filled
/// form. Never persisted; gone on app termination.
@immutable
class RegistrationDraft {
  const new({
    required this.email,
    required this.username,
    required this.displayName,
    required this.password,
    required this.codeSentAt,
    this.gender,
    this.usernameLost = false,
  });

  /// Normalized (trimmed, lowercased) email the code was sent to.
  final String email;
  final String username;
  final String displayName;
  final String password;

  /// v1.47-social (D175): the gender chosen on Register (required there).
  final Gender? gender;

  /// Time of the last 202 from `register` / `register/resend`: starts the
  /// 60 s resend cooldown and the local 30 min expiry hint.
  final DateTime codeSentAt;

  /// `USERNAME_TAKEN` arrived during verify: Register shows the username as
  /// taken plus `errUsernameTakenDuringVerify`.
  final bool usernameLost;

  RegistrationDraft copyWith({DateTime? codeSentAt, bool? usernameLost}) =>
      RegistrationDraft(
        email: email,
        username: username,
        displayName: displayName,
        password: password,
        gender: gender,
        codeSentAt: codeSentAt ?? this.codeSentAt,
        usernameLost: usernameLost ?? this.usernameLost,
      );
}

class RegistrationFlowController extends Notifier<RegistrationDraft?> {
  @override
  RegistrationDraft? build() => null;

  RegistrationDraft? get draft => state;

  /// The register 202 arrived: the flow is open.
  set draft(RegistrationDraft? draft) => state = draft;

  void codeResent(DateTime at) => state = state?.copyWith(codeSentAt: at);

  void usernameLost() => state = state?.copyWith(usernameLost: true);

  /// Back on Register after a lost username: the banner was shown.
  void acknowledgeUsernameLost() =>
      state = state?.copyWith(usernameLost: false);

  /// Success, or leaving the flow to Login.
  void clear() => state = null;
}

final registrationFlowProvider =
    NotifierProvider<RegistrationFlowController, RegistrationDraft?>(
      RegistrationFlowController.new,
    );

/// Identifier to prefill on Login (e.g. "Log in" from the code screen).
class LoginPrefillController extends Notifier<String?> {
  @override
  String? build() => null;

  String? get identifier => state;

  set identifier(String? value) => state = value;
}

final loginPrefillProvider = NotifierProvider<LoginPrefillController, String?>(
  LoginPrefillController.new,
);
