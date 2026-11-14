// int21 (owner «موافق على الاقتراحات», D345 #7 + D344; contract
// v1.112-social, CONVENTIONS §10.143.3): the app reports where it was
// installed from — Android's installer package (Google Play ⇒ PLAY, anything
// else or none ⇒ SIDELOAD), iOS always APP_STORE — with every sign-in
// (`DeviceInfo.installSource`) and every token refresh, so the server offers
// «الشحن من الموقع» only to the direct APK.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/ids/install_id.dart';
import 'package:kabso_live/core/ids/install_source.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';

import '../helpers/contract_fixtures.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _base = '/api/v1';

class _Fixed implements InstallSourceReader {
  new(this.value);

  final String? value;

  @override
  Future<String?> read() async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the install source', () {
    const channel = PlatformInstallSourceReader.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(() => PlatformInstallSourceReader.enabled = true);
    tearDown(() {
      PlatformInstallSourceReader.enabled = false;
      messenger.setMockMethodCallHandler(channel, null);
    });

    void installer(String? package) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'installerPackage');
        return package;
      });
    }

    test('Android: Google Play is PLAY; another installer or none is '
        'SIDELOAD', () async {
      expect(androidInstallSourceOf('com.android.vending'), 'PLAY');
      expect(androidInstallSourceOf(' com.android.vending '), 'PLAY');
      expect(androidInstallSourceOf(null), 'SIDELOAD');
      expect(
        androidInstallSourceOf('com.google.android.packageinstaller'),
        'SIDELOAD',
      );
      expect(androidInstallSourceOf('com.android.chrome'), 'SIDELOAD');

      installer('com.android.vending');
      expect(
        await PlatformInstallSourceReader(
          platform: TargetPlatform.android,
          isWeb: false,
        ).read(),
        installSourcePlay,
      );
      installer(null);
      expect(
        await PlatformInstallSourceReader(
          platform: TargetPlatform.android,
          isWeb: false,
        ).read(),
        installSourceSideload,
      );
    });

    test('Android: asked once per run; a failed call reports nothing and is '
        'asked again', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        if (calls == 1) throw PlatformException(code: 'boom');
        return 'com.android.vending';
      });
      final reader = PlatformInstallSourceReader(
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(await reader.read(), isNull);
      expect(await reader.read(), installSourcePlay);
      expect(await reader.read(), installSourcePlay);
      expect(calls, 2);
    });

    test('iOS is always APP_STORE (TestFlight included); the web and other '
        'platforms report nothing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        fail('no platform call outside Android');
      });
      expect(
        await PlatformInstallSourceReader(
          platform: TargetPlatform.iOS,
          isWeb: false,
        ).read(),
        installSourceAppStore,
      );
      expect(
        await PlatformInstallSourceReader(
          platform: TargetPlatform.android,
          isWeb: true,
        ).read(),
        isNull,
      );
      expect(
        await PlatformInstallSourceReader(
          platform: TargetPlatform.linux,
          isWeb: false,
        ).read(),
        isNull,
      );
    });
  });

  group('sent to the server', () {
    late FakeHttpAdapter http;
    late ProviderContainer container;

    Future<void> build(String? source, {String? storedRefreshToken}) async {
      http = FakeHttpAdapter();
      final prefs = await testPrefs();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(
            InMemoryTokenStore(storedRefreshToken),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          installIdProvider.overrideWithValue('install-0001-test'),
          installSourceReaderProvider.overrideWithValue(_Fixed(source)),
        ],
      );
    }

    test('with the sign-in, in DeviceInfo', () async {
      await build('SIDELOAD');
      http.on(
        'POST',
        '$_base/auth/login',
        (_) => FakeResponse(
          200,
          body: authResponseJson(
            user: meJson(emailVerified: true),
            tokens: tokenPairJson(accessToken: 'acc', refreshToken: 'sid.s'),
          ),
        ),
      );
      await container
          .read(authRepositoryProvider)
          .login(identifier: 'layla.k', password: 'pa55word!');
      final req = http.requestsTo('POST', '$_base/auth/login').single;
      expect((req.data as Map)['device'], {
        'platform': 'android',
        'appVersion': '1.2.3',
        'installId': 'install-0001-test',
        'installSource': 'SIDELOAD',
      });
    });

    for (final source in <String?>['PLAY', 'APP_STORE', 'SIDELOAD', null]) {
      test('with every refresh (${source ?? 'unknown: omitted'})', () async {
        await build(source, storedRefreshToken: 'sid.old');
        http
          ..on(
            'POST',
            '$_base/auth/refresh',
            (_) => FakeResponse(200, body: tokenPairJson(accessToken: 'acc')),
          )
          ..on('GET', '$_base/me', (_) => FakeResponse(200, body: meJson()));
        await container.read(authRepositoryProvider).restoreSession();
        final req = http.requestsTo('POST', '$_base/auth/refresh').single;
        expect(req.data, {'refreshToken': 'sid.old', 'installSource': ?source});
      });
    }
  });
}
