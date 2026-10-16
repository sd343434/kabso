import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/domain/auth_failures.dart';

ServerFailure _validation(List<FieldIssue> details) => ServerFailure(
  code: ErrorCode.validationFailed,
  rawCode: 'VALIDATION_FAILED',
  debugMessage: 'invalid',
  statusCode: 400,
  details: details,
);

void main() {
  test('issue vocabulary of CONVENTIONS.md §4 (v1.0.3) is recognized', () {
    const wire = [
      'required',
      'invalid_type',
      'too_short',
      'too_long',
      'too_small',
      'too_big',
      'invalid_email',
      'invalid_format',
      'invalid_value',
      'unknown_field',
      'malformed_json',
      'payload_too_large',
    ];
    for (final w in wire) {
      final code = ValidationIssueCode.fromWire(w);
      expect(code, isNot(ValidationIssueCode.unknown), reason: w);
      expect(code.wire, w);
    }
    expect(
      ValidationIssueCode.fromWire('brand_new'),
      ValidationIssueCode.unknown,
    );
    expect(ValidationIssueCode.fromWire(''), ValidationIssueCode.unknown);
  });

  test('field details map to form fields with their issue', () {
    final failure = _validation(const [
      FieldIssue(field: 'username', issue: 'invalid_format'),
      FieldIssue(field: 'password', issue: 'too_short'),
      FieldIssue(field: 'email', issue: 'something_new'),
      FieldIssue(field: 'device.name', issue: 'too_long'),
    ]);
    expect(failure.authFieldIssues, {
      AuthField.username: ValidationIssueCode.invalidFormat,
      AuthField.password: ValidationIssueCode.tooShort,
      AuthField.email: ValidationIssueCode.unknown,
    });
  });

  test('body-level errors (field "") are not mapped to a field', () {
    final failure = _validation(const [
      FieldIssue(field: '', issue: 'malformed_json'),
    ]);
    expect(failure.authFieldIssues, isEmpty);
  });

  test('USERNAME_TAKEN maps to the username; EMAIL_TAKEN maps to no field '
      '(v1.2, D24: registration never reveals email use)', () {
    const email = ServerFailure(
      code: ErrorCode.emailTaken,
      rawCode: 'EMAIL_TAKEN',
      debugMessage: 'taken',
    );
    const username = ServerFailure(
      code: ErrorCode.usernameTaken,
      rawCode: 'USERNAME_TAKEN',
      debugMessage: 'taken',
    );
    expect(email.authFields, isEmpty);
    expect(username.authFields, {AuthField.username});
    expect(const NetworkFailure.offline().authFields, isEmpty);
  });
}
