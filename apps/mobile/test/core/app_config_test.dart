import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';

AppConfig _resolve(String url, {required bool release}) => AppConfig.resolve(
  apiBaseUrl: url,
  appVersion: '1.0.0',
  releaseMode: release,
);

void main() {
  group('release mode (SEC-007)', () {
    test('accepts https and trims a trailing slash', () {
      final config = _resolve('https://api.kabso.example/', release: true);
      expect(config.apiBaseUrl, 'https://api.kabso.example');
      expect(config.apiV1BaseUrl, 'https://api.kabso.example/api/v1');
    });

    for (final url in [
      'http://10.0.2.2:3000', // the dev default
      'http://api.kabso.example',
      'HTTP://api.kabso.example',
    ]) {
      test('refuses non-https "$url"', () {
        expect(
          () => _resolve(url, release: true),
          throwsA(
            isA<AppConfigError>().having(
              (e) => e.message,
              'message',
              contains('https://'),
            ),
          ),
        );
      });
    }

    test('the dev default is refused by fromEnvironment in release', () {
      // No --dart-define in the test run → default http://10.0.2.2:3000.
      expect(
        () => AppConfig.fromEnvironment(releaseMode: true),
        throwsA(isA<AppConfigError>()),
      );
      expect(AppConfig.fromEnvironment().apiBaseUrl, 'http://10.0.2.2:3000');
    });
  });

  group('debug/profile mode', () {
    test('allows http for local development', () {
      expect(
        _resolve('http://localhost:3000', release: false).apiBaseUrl,
        'http://localhost:3000',
      );
    });
  });

  group('malformed URLs are refused in every mode', () {
    for (final url in [
      '',
      'api.kabso.example',
      'ftp://api.kabso.example',
      'https://',
      'https://api.kabso.example?x=1',
      'https://api.kabso.example#frag',
      'https://user:pass@api.kabso.example',
    ]) {
      for (final release in [true, false]) {
        test('"$url" (release: $release)', () {
          expect(
            () => _resolve(url, release: release),
            throwsA(isA<AppConfigError>()),
          );
        });
      }
    }
  });
}
