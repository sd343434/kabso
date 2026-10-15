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

  group('Retry-After countdown on 429 / 503 (PHASE1_SCREENS §10)', () {
    ServerFailure failure(ErrorCode code, int? seconds, {String? id}) =>
        ServerFailure(
          code: code,
          rawCode: code.wire,
          debugMessage: 'x',
          statusCode: code == ErrorCode.rateLimited ? 429 : 503,
          requestId: id,
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );

    test('503 without Retry-After uses the generic busy message', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, null)),
        "We're busy right now. Please try again in a moment.",
      );
    });

    test('the full Retry-After is shown as m:ss without a live countdown', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(en, failure(ErrorCode.rateLimited, 900)),
        'Too many attempts. Try again in 15:00.',
      );
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, 5)),
        "We're busy right now. Please try again in 0:05.",
      );
    });

    test('the live remaining time wins and rounds up to whole seconds', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(
          en,
          failure(ErrorCode.rateLimited, 900),
          remaining: const Duration(minutes: 4, seconds: 4, milliseconds: 1),
        ),
        'Too many attempts. Try again in 4:05.',
      );
    });

    test('when the countdown has ended the plain message is shown', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(
          en,
          failure(ErrorCode.rateLimited, 900),
          remaining: Duration.zero,
        ),
        en.errorRateLimited,
      );
    });

    test('Arabic uses Latin digits', () {
      final ar = l10nFor(AppLanguage.ar);
      expect(
        failureMessage(ar, failure(ErrorCode.rateLimited, 65)),
        'محاولات كثيرة. حاول مرة أخرى بعد 1:05.',
      );
      expect(
        failureMessage(ar, failure(ErrorCode.serviceUnavailable, 2)),
        'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد 0:02.',
      );
    });

    test('Retry-After is ignored for other codes', () {
      final en = l10nFor(AppLanguage.en);
      const f = ServerFailure(
        code: ErrorCode.internalError,
        rawCode: 'INTERNAL_ERROR',
        debugMessage: 'x',
        retryAfter: Duration(seconds: 10),
      );
      expect(failureMessage(en, f), en.errorInternal);
      expect(hasRetryCountdown(f), isFalse);
    });

    test('Error ID only for INTERNAL_ERROR, SERVICE_UNAVAILABLE, unknown', () {
      ServerFailure withId(ErrorCode code) => ServerFailure(
        code: code,
        rawCode: code.wire,
        debugMessage: 'x',
        requestId: 'req-42',
      );
      expect(failureErrorId(withId(ErrorCode.internalError)), 'req-42');
      expect(failureErrorId(withId(ErrorCode.serviceUnavailable)), 'req-42');
      expect(failureErrorId(withId(ErrorCode.unknown)), 'req-42');
      for (final code in [
        ErrorCode.rateLimited,
        ErrorCode.authInvalidCredentials,
        ErrorCode.validationFailed,
        ErrorCode.notFound,
      ]) {
        expect(failureErrorId(withId(code)), isNull, reason: code.wire);
      }
      expect(failureErrorId(const NetworkFailure.offline()), isNull);
      expect(
        failureErrorId(failure(ErrorCode.internalError, null)),
        isNull,
        reason: 'no requestId',
      );
    });
  });
}
