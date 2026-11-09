// D344 (contract v1.109-social, CONVENTIONS §10.143): the app asks the
// server for the website top-up page's one-time sign-in address
// (`POST /wallet/topup-session`) against a mocked Dio adapter, with JSON
// shaped like docs/contracts/openapi.yaml `TopupWebsiteSession`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/wallet/data/topup_website_repository.dart';

import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _path = '/api/v1/wallet/topup-session';
final String _code = 'Ab0_-' * 8 + 'xyz';

void main() {
  late FakeHttpAdapter http;
  late ProviderContainer container;

  setUp(() async {
    http = FakeHttpAdapter();
    final prefs = await testPrefs(language: 'ar');
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
        ),
        httpClientAdapterProvider.overrideWithValue(http),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await container
        .read(tokenManagerProvider)
        .saveTokens(AuthTokens.fromJson(tokenPairJson(accessToken: 'acc')));
  });

  TopupWebsiteRepository repo() =>
      container.read(topupWebsiteRepositoryProvider);

  test('POSTs signed in and returns the address with the code', () async {
    final url = 'https://api.kabso.live/topup?lang=ar#h=$_code';
    http.on(
      'POST',
      _path,
      (_) => FakeResponse(
        201,
        body: {'websiteUrl': url, 'expiresAt': '2026-11-09T12:01:00.000Z'},
      ),
    );
    final uri = await repo().websiteSession();
    expect(uri, Uri.parse(url));
    expect(uri.fragment, 'h=$_code');
    final sent = http.requestsTo('POST', _path).single;
    expect(sent.headers['Authorization'], 'Bearer acc');
    // Nothing but the access token goes out: no password, no body.
    expect(sent.data, isNull);
  });

  test('a non-https address or one without the code is refused', () async {
    for (final bad in [
      'http://api.kabso.live/topup#h=$_code',
      'https://api.kabso.live/topup',
      'javascript:alert(1)',
    ]) {
      http.on(
        'POST',
        _path,
        (_) => FakeResponse(
          201,
          body: {'websiteUrl': bad, 'expiresAt': '2026-11-09T12:01:00.000Z'},
        ),
      );
      await expectLater(
        repo().websiteSession(),
        throwsA(isA<UnexpectedFailure>()),
        reason: bad,
      );
    }
  });

  test('503 (the link is off for this platform) is a failure', () async {
    http.on(
      'POST',
      _path,
      (_) => FakeResponse(
        503,
        body: errorEnvelope('TOPUP_UNAVAILABLE', 'Card top-up is not enabled'),
      ),
    );
    await expectLater(repo().websiteSession(), throwsA(isA<AppFailure>()));
  });
}
