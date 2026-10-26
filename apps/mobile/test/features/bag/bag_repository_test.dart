// CP-019: BagRepository and PublicProfile.profileCard against a mocked Dio
// adapter, with JSON shaped like docs/contracts/openapi.yaml v1.22-live.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';

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

  BagRepository repo() => container.read(bagRepositoryProvider);

  group('BagRepository', () {
    test('catalogue: by category, unknown categories dropped', () async {
      http.on(
        'GET',
        '$_base/bag/catalogue',
        (_) => FakeResponse(
          200,
          body: {
            'data': [
              for (final code in bagCatalogueCodes) bagCatalogueItemJson(code),
              bagCatalogueItemJson('fire_frame', category: 'AVATAR_FRAME'),
            ],
          },
        ),
      );
      final items = await repo().catalogue(category: BagCategory.profileCard);
      expect(items.map((i) => i.code), bagCatalogueCodes);
      expect(items.first.name, 'الأرنب الملكي');
      expect(items.first.free, isTrue);
      expect(items.first.assetKey, 'header_bunny_royal');
      expect(items[1].free, isFalse);
      expect(items.last.sortOrder, 40);
      final req = http.requestsTo('GET', '$_base/bag/catalogue').single;
      expect(req.uri.queryParameters, {'category': 'PROFILE_CARD'});

      await repo().catalogue();
      expect(
        http.requestsTo('GET', '$_base/bag/catalogue').last.uri.queryParameters,
        isEmpty,
      );
    });

    test('my bag: owned items, the worn one, opaque sources', () async {
      http.on(
        'GET',
        '$_base/me/bag',
        (_) => FakeResponse(
          200,
          body: {
            'data': [
              bagItemJson('bunny_royal', equipped: true, source: 'FREE_SIGNUP'),
              bagItemJson('emerald_wings', source: 'STORE'),
              bagItemJson('x', category: 'CHAT_BUBBLE'),
            ],
          },
        ),
      );
      final items = await repo().myBag(category: BagCategory.profileCard);
      expect(items.map((i) => i.code), ['bunny_royal', 'emerald_wings']);
      expect(items.first.equipped, isTrue);
      expect(items.first.source, 'FREE_SIGNUP');
      expect(items.last.source, 'STORE');
      expect(items.first.acquiredAt, DateTime.utc(2026, 10, 26, 18, 30));
      expect(
        http.requestsTo('GET', '$_base/me/bag').single.uri.queryParameters,
        {'category': 'PROFILE_CARD'},
      );
    });

    test(
      'wear and take off send the category and the code (or null)',
      () async {
        String? sent;
        http.on('PUT', '$_base/me/bag/equipped', (o) {
          final body = o.data as Map<String, dynamic>;
          sent = body['code'] as String?;
          return FakeResponse(200, body: bagEquippedJson(sent));
        });
        final worn = await repo().setEquipped(
          BagCategory.profileCard,
          'emerald_wings',
        );
        expect(worn.category, 'PROFILE_CARD');
        expect(worn.equipped?.code, 'emerald_wings');
        expect(worn.equipped?.name, 'الأجنحة الزمردية');
        expect(worn.equipped?.assetKey, 'header_emerald_wings');

        final off = await repo().setEquipped(BagCategory.profileCard, null);
        expect(off.equipped, isNull);
        final bodies = [
          for (final r in http.requestsTo('PUT', '$_base/me/bag/equipped'))
            r.data,
        ];
        expect(bodies, [
          {'category': 'PROFILE_CARD', 'code': 'emerald_wings'},
          {'category': 'PROFILE_CARD', 'code': null},
        ]);
        // `code: null` is sent, not left out (the contract requires it).
        expect((bodies.last! as Map).containsKey('code'), isTrue);
      },
    );

    test('409 BAG_ITEM_NOT_OWNED becomes its failure', () async {
      http.on(
        'PUT',
        '$_base/me/bag/equipped',
        (_) => FakeResponse(
          409,
          body: errorEnvelope('BAG_ITEM_NOT_OWNED', 'Not owned'),
        ),
      );
      await expectLater(
        repo().setEquipped(BagCategory.profileCard, 'kabi_royal'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.bagItemNotOwned,
          ),
        ),
      );
    });
  });

  group('PublicProfile v1.22-live', () {
    test('profileCard parses; null and older payloads still parse', () async {
      http
        ..on(
          'GET',
          '$_base/users/layla.k',
          (_) => FakeResponse(
            200,
            body: {
              ...publicProfileJson(),
              'profileCard': {
                'code': 'emerald_wings',
                'assetKey': 'header_emerald_wings',
              },
            },
          ),
        )
        ..on(
          'GET',
          '$_base/users/none',
          (_) => FakeResponse(
            200,
            body: {...publicProfileJson(), 'profileCard': null},
          ),
        )
        ..on(
          'GET',
          '$_base/users/old',
          (_) => FakeResponse(200, body: publicProfileJson()),
        );
      final profiles = container.read(profileRepositoryProvider);
      final p = await profiles.getProfile('layla.k');
      expect(p.profileCard?.code, 'emerald_wings');
      expect(p.profileCard?.assetKey, 'header_emerald_wings');
      expect(
        KabsoProfileHeader.byCode(p.profileCard?.code),
        KabsoProfileHeader.emeraldWings,
      );
      expect((await profiles.getProfile('none')).profileCard, isNull);
      expect((await profiles.getProfile('old')).profileCard, isNull);
    });
  });
}
