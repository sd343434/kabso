import 'package:kabso_live/core/error/app_failure.dart';

/// Form fields of the auth screens, named like the request properties.
enum AuthField { email, username, password, displayName, identifier }

/// `VALIDATION_FAILED` `details[].issue` vocabulary (CONVENTIONS.md §4,
/// contract v1.0.3). Anything else maps to [unknown].
enum ValidationIssueCode {
  required('required'),
  invalidType('invalid_type'),
  tooShort('too_short'),
  tooLong('too_long'),
  tooSmall('too_small'),
  tooBig('too_big'),
  invalidEmail('invalid_email'),
  invalidFormat('invalid_format'),
  invalidValue('invalid_value'),
  unknownField('unknown_field'),
  malformedJson('malformed_json'),
  payloadTooLarge('payload_too_large'),

  /// v1.2: displayName contains a reserved term (list is server-side only).
  reservedTerm('reserved_term'),
  unknown('');

  new(this.wire);

  final String wire;

  static ValidationIssueCode fromWire(String issue) => values.firstWhere(
    (v) => v != unknown && v.wire == issue,
    orElse: () => unknown,
  );
}

/// Interprets an [AppFailure] in the context of an auth form.
extension AuthFailureFields on AppFailure {
  /// Fields the failure points at, with the validation issue when known.
  ///
  /// `USERNAME_TAKEN` maps to the username (issue `null`); `EMAIL_TAKEN`
  /// is deliberately **not** mapped (v1.2, D24: never reveal email use);
  /// `VALIDATION_FAILED` maps `details[].field` entries that name a form
  /// field. Body-level details (`field: ""`) and unknown fields are not
  /// mapped, so the caller shows a form-level message instead.
  Map<AuthField, ValidationIssueCode?> get authFieldIssues {
    final self = this;
    if (code == ErrorCode.usernameTaken) return {AuthField.username: null};
    if (code == ErrorCode.validationFailed && self is ServerFailure) {
      return {
        for (final d in self.details)
          for (final f in AuthField.values.where((f) => f.name == d.field))
            f: ValidationIssueCode.fromWire(d.issue),
      };
    }
    return const {};
  }

  Set<AuthField> get authFields => authFieldIssues.keys.toSet();

  /// `true` when the failure means the user must sign in again.
  bool get endsSession =>
      code == ErrorCode.authRefreshInvalid ||
      code == ErrorCode.accountSuspended;
}
