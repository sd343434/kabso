import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';

import '../helpers/pump_app.dart';

void main() {
  for (final language in AppLanguage.values) {
    group('localized error messages (${language.name})', () {
      final l10n = l10nFor(language);
      final generic = errorCodeMessage(l10n, ErrorCode.unknown);

      test('generic fallback exists', () {
        expect(generic, isNotEmpty);
      });

      for (final code in ErrorCode.values.where(
        (c) => c != ErrorCode.unknown,
      )) {
        test('${code.wire} has its own message', () {
          final message = errorCodeMessage(l10n, code);
          expect(message, isNotEmpty);
          expect(message, isNot(generic));
        });
      }

      test('messages are distinct per code', () {
        final messages = {
          for (final c in ErrorCode.values) c: errorCodeMessage(l10n, c),
        };
        final unique = messages.values.toSet();
        expect(unique.length, ErrorCode.values.length);
      });

      test('failureMessage uses the failure code', () {
        expect(
          failureMessage(l10n, const NetworkFailure.offline()),
          errorCodeMessage(l10n, ErrorCode.networkOffline),
        );
        expect(
          failureMessage(
            l10n,
            const ServerFailure(
              code: ErrorCode.unknown,
              rawCode: 'SOMETHING_NEW',
              debugMessage: 'x',
            ),
          ),
          generic,
        );
      });
    });
  }
}
