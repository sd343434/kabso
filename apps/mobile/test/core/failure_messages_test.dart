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

  group('Retry-After on 429 / 503 (CONVENTIONS v1.1)', () {
    ServerFailure failure(ErrorCode code, int? seconds) => ServerFailure(
      code: code,
      rawCode: code.wire,
      debugMessage: 'x',
      statusCode: code == ErrorCode.rateLimited ? 429 : 503,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );

    test('503 without Retry-After uses the generic busy message', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, null)),
        "We're busy right now. Please try again in a moment.",
      );
    });

    test('503 with Retry-After names the wait (en)', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, 30)),
        "We're busy right now. Please try again in 30 seconds.",
      );
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, 1)),
        "We're busy right now. Please try again in 1 second.",
      );
      expect(
        failureMessage(en, failure(ErrorCode.serviceUnavailable, 61)),
        "We're busy right now. Please try again in 2 minutes.",
      );
    });

    test('429 with Retry-After names the wait (en)', () {
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(en, failure(ErrorCode.rateLimited, 900)),
        'Too many attempts. Try again in 15 minutes.',
      );
    });

    test('Arabic plural forms', () {
      final ar = l10nFor(AppLanguage.ar);
      expect(
        failureMessage(ar, failure(ErrorCode.serviceUnavailable, 2)),
        'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد ثانيتين.',
      );
      expect(
        failureMessage(ar, failure(ErrorCode.serviceUnavailable, 5)),
        'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد 5 ثوانٍ.',
      );
      expect(
        failureMessage(ar, failure(ErrorCode.rateLimited, 60)),
        'محاولات كثيرة جدًا. حاول مرة أخرى بعد دقيقة واحدة.',
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
    });
  });
}
