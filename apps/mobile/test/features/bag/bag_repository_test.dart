// CP-019: BagRepository and PublicProfile.profileCard against a mocked Dio
// adapter, with JSON shaped like docs/contracts/openapi.yaml v1.22-live
// (v1.48-social, D171: expiry, giver, sending).

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

    test(
      'my bag: every category (D171), worn, sources, expiry, giver',
      () async {
        http.on(
          'GET',
          '$_base/me/bag',
          (_) => FakeResponse(
            200,
            body: {
              'data': [
                bagItemJson(
                  'bunny_royal',
                  equipped: true,
                  source: 'FREE_SIGNUP',
                ),
                bagItemJson(
                  'emerald_wings',
                  source: 'STORE',
                  expiresAt: DateTime.utc(2026, 11, 5, 13),
                  giftedBy: {
                    'id': '0192e4a0-7c1d-7000-8000-000000000002',
                    'username': 'sara_22',
                    'displayName': 'Sara',
                    'avatarUrl': null,
                  },
                ),
                bagItemJson('x', category: 'CHAT_BUBBLE'),
              ],
            },
          ),
        );
        final items = await repo().myBag(category: BagCategory.profileCard);
        // D171: a category this app does not know is kept (it just appears).
        expect(items.map((i) => i.code), ['bunny_royal', 'emerald_wings', 'x']);
        expect(items.last.category, 'CHAT_BUBBLE');
        expect(items.first.expiresAt, isNull);
        expect(items.first.transferable, isFalse);
        expect(items[1].expiresAt, DateTime.utc(2026, 11, 5, 13));
        expect(items[1].giftedBy?.username, 'sara_22');
        expect(items[1].transferable, isTrue);
        expect(items.first.equipped, isTrue);
        expect(items.first.source, 'FREE_SIGNUP');
        expect(items[1].source, 'STORE');
        expect(items.first.acquiredAt, DateTime.utc(2026, 10, 26, 18, 30));
        expect(
          http.requestsTo('GET', '$_base/me/bag').single.uri.queryParameters,
          {'category': 'PROFILE_CARD'},
        );
      },
    );

    test(
      'wear and take off send the category and the code (or null)',
      () async {
        String? sent;
        http.on('PUT', '$_base/me/bag/equipped', (o) {
          final body = o.data as Map<String, dynamic>;
          sent = body['code'] as String?;
          return FakeResponse(200, body: bagEquippedJson(sent));
        });
        final worn = await repo().setEquipped('PROFILE_CARD', 'emerald_wings');
        expect(worn.category, 'PROFILE_CARD');
        expect(worn.equipped?.code, 'emerald_wings');
        expect(worn.equipped?.name, 'الأجنحة الزمردية');
        expect(worn.equipped?.assetKey, 'header_emerald_wings');

        final off = await repo().setEquipped('PROFILE_CARD', null);
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

    test('send (D171): whole omits days, a part sends them', () async {
      final bodies = <Object?>[];
      http.on('POST', '$_base/me/bag/transfers', (o) {
        bodies.add(o.data);
        final days = (o.data as Map<String, dynamic>)['days'] as int?;
        return FakeResponse(
          201,
          body: bagTransferJson(
            'emerald_wings',
            days: days,
            recipient: {
              'id': '0192e4a0-7c1d-7000-8000-000000000002',
              'username': 'sara_22',
              'displayName': 'Sara',
              'avatarUrl': null,
            },
            remaining: days == null
                ? null
                : bagItemJson(
                    'emerald_wings',
                    expiresAt: DateTime.utc(2026, 11, 2, 9),
                  ),
          ),
        );
      });
      final whole = await repo().send(
        code: 'emerald_wings',
        username: 'sara_22',
      );
      expect(whole.whole, isTrue);
      expect(whole.durationSeconds, isNull);
      expect(whole.recipient.username, 'sara_22');
      expect(whole.remaining, isNull);
      final part = await repo().send(
        code: 'emerald_wings',
        username: 'sara_22',
        days: 3,
      );
      expect(part.whole, isFalse);
      expect(part.durationSeconds, 3 * 86400);
      expect(part.remaining?.expiresAt, DateTime.utc(2026, 11, 2, 9));
      expect(bodies, [
        {'code': 'emerald_wings', 'username': 'sara_22'},
        {'code': 'emerald_wings', 'username': 'sara_22', 'days': 3},
      ]);
    });

    test('409 send codes become their failures', () async {
      for (final code in ErrorCode.values.where(
        (c) =>
            c.wire.startsWith('BAG_SEND') ||
            c.wire.startsWith('BAG_RECIPIENT') ||
            c.wire == 'BAG_ITEM_NOT_TRANSFERABLE',
      )) {
        http.on(
          'POST',
          '$_base/me/bag/transfers',
          (_) => FakeResponse(409, body: errorEnvelope(code.wire, 'x')),
        );
        await expectLater(
          repo().send(code: 'kabi_royal', username: 'sara_22'),
          throwsA(isA<ServerFailure>().having((f) => f.code, 'code', code)),
        );
      }
    });

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
        repo().setEquipped('PROFILE_CARD', 'kabi_royal'),
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
