// CP-020: LiveGiftRepository and the `gift` data message against a mocked
// Dio adapter, with JSON shaped like docs/contracts/openapi.yaml v1.23-live.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
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

  LiveGiftRepository repo() => container.read(liveGiftRepositoryProvider);

  group('catalogue', () {
    test('the contract example: tabs, quantities, limits, gifts', () async {
      http.on(
        'GET',
        '$_base/gifts/catalogue',
        (_) => FakeResponse(
          200,
          body: giftCatalogueJson(codes: const ['rose', 'sports_car']),
        ),
      );
      final c = await repo().catalogue();
      expect(c.version, '3f2a9c0d81b4e6a7');
      expect(c.categories, [
        GiftCategory.popular,
        GiftCategory.event,
        GiftCategory.fun,
      ]);
      expect(c.quantities, [1, 10, 66, 99, 188, 520, 1314]);
      expect(c.maxRecipients, 25);
      expect(c.comboWindowSeconds, 5);
      final rose = c.byCode('rose')!;
      expect(rose.name, 'وردة');
      expect(rose.priceCoins, 1);
      expect(rose.assetKey, 'gift_rose');
      expect(rose.animationKey, isNull);
      expect(rose.badge, GiftBadge.none);
      final car = c.byCode('sports_car')!;
      expect(car.animationKey, 'fx_sports_car');
      expect(car.badge, GiftBadge.isNew);
      expect(c.of(GiftCategory.popular).map((g) => g.code), [
        'rose',
        'sports_car',
      ]);
      expect(c.of(GiftCategory.fun), isEmpty);
    });

    test('empty (production today) is valid', () async {
      http.on(
        'GET',
        '$_base/gifts/catalogue',
        (_) => FakeResponse(200, body: giftCatalogueJson(codes: const [])),
      );
      final c = await repo().catalogue();
      expect(c.data, isEmpty);
      expect(c.categories, hasLength(3));
    });

    test('unknown categories and badges: dropped / NONE', () async {
      http.on(
        'GET',
        '$_base/gifts/catalogue',
        (_) => FakeResponse(
          200,
          body: giftCatalogueJson(
            codes: const ['rose'],
            categories: const ['POPULAR', 'LUCKY', 'EVENT', 'FUN'],
            extra: [
              {...giftJson('crown'), 'code': 'lucky_cat', 'category': 'LUCKY'},
              {...giftJson('crown'), 'badge': 'HOT'},
            ],
          ),
        ),
      );
      final c = await repo().catalogue();
      expect(c.categories, hasLength(3));
      expect(c.data.map((g) => g.code), ['rose', 'crown']);
      expect(c.byCode('crown')!.badge, GiftBadge.none);
    });
  });

  test('bag: items with quantities, unknown categories dropped', () async {
    http.on(
      'GET',
      '$_base/me/gifts/bag',
      (_) => FakeResponse(
        200,
        body: {
          'data': [
            giftBagItemJson('rose', 99),
            {...giftBagItemJson('crown', 2), 'category': 'LUCKY'},
          ],
        },
      ),
    );
    final bag = await repo().bag();
    expect(bag, hasLength(1));
    expect(bag.single.gift.code, 'rose');
    expect(bag.single.gift.name, 'وردة');
    expect(bag.single.quantity, 99);
  });

  group('send', () {
    test('body as the contract; the answer: gift, coins, bag', () async {
      Map<String, dynamic>? sent;
      http.on('POST', '$_base/live/rooms/room-7/gifts', (o) {
        sent = o.data as Map<String, dynamic>;
        return FakeResponse(
          201,
          body: liveGiftResultJson(
            gift: liveGiftJson(roomId: 'room-7'),
            bagQuantity: 3,
          ),
        );
      });
      final result = await repo().send(
        'room-7',
        giftCode: 'rose',
        quantity: 10,
        recipients: const ['sara', 'omar'],
        source: LiveGiftSource.coins,
        clientId: '0192f1d0-3333-7000-8000-000000000014',
      );
      expect(sent, {
        'giftCode': 'rose',
        'quantity': 10,
        'recipients': ['sara', 'omar'],
        'source': 'COINS',
        'clientId': '0192f1d0-3333-7000-8000-000000000014',
      });
      expect(result.coins, 80);
      expect(result.bagQuantity, 3);
      final g = result.gift;
      expect(g.giftCode, 'rose');
      expect(g.unitPrice, 1);
      expect(g.quantity, 10);
      expect(g.totalCoins, 20);
      expect(g.source, LiveGiftSource.coins);
      expect(g.sender.username, 'lina');
      expect(g.recipients.map((u) => u.username), ['sara', 'omar']);
      expect(g.combo.count, 1);
      expect(g.combo.id, g.id);
      expect(g.createdAt, DateTime.utc(2026, 10, 26, 18, 30));
    });

    test('BAG source on the wire', () async {
      Map<String, dynamic>? sent;
      http.on('POST', '$_base/live/rooms/room-7/gifts', (o) {
        sent = o.data as Map<String, dynamic>;
        return FakeResponse(
          201,
          body: liveGiftResultJson(gift: liveGiftJson(source: 'BAG')),
        );
      });
      final r = await repo().send(
        'room-7',
        giftCode: 'rose',
        quantity: 1,
        recipients: const ['sara'],
        source: LiveGiftSource.bag,
        clientId: 'c',
      );
      expect(sent!['source'], 'BAG');
      expect(r.gift.source, LiveGiftSource.bag);
    });

    for (final (wire, code) in [
      ('GIFT_UNAVAILABLE', ErrorCode.giftUnavailable),
      ('GIFT_BAG_INSUFFICIENT', ErrorCode.giftBagInsufficient),
      (
        'LIVE_GIFT_RECIPIENT_UNAVAILABLE',
        ErrorCode.liveGiftRecipientUnavailable,
      ),
      ('INSUFFICIENT_COINS', ErrorCode.insufficientCoins),
    ]) {
      test('409 $wire becomes its failure', () async {
        http.on(
          'POST',
          '$_base/live/rooms/room-7/gifts',
          (_) => FakeResponse(409, body: errorEnvelope(wire, 'No')),
        );
        await expectLater(
          repo().send(
            'room-7',
            giftCode: 'rose',
            quantity: 1,
            recipients: const ['sara'],
            source: LiveGiftSource.coins,
            clientId: 'c',
          ),
          throwsA(isA<ServerFailure>().having((f) => f.code, 'code', code)),
        );
      });
    }
  });

  group('data message (topic gift)', () {
    test('parses {"type":"gift","gift":LiveGift}', () {
      final event = LiveChatEvent.parse({
        'type': 'gift',
        'gift': liveGiftJson(comboCount: 3, comboId: 'combo-1'),
      });
      expect(event, isA<LiveGiftReceived>());
      final gift = (event! as LiveGiftReceived).gift;
      expect(gift.combo.id, 'combo-1');
      expect(gift.combo.count, 3);
      expect(gift.combo.quantity, 30);
    });

    test('a malformed gift message is ignored', () {
      expect(LiveChatEvent.parse({'type': 'gift', 'gift': 'x'}), isNull);
      expect(LiveChatEvent.parse({'type': 'gift'}), isNull);
    });
  });
}
