// D345 (CONVENTIONS §10.144): «الشراء من المتجر».
//
//   store_iap.consent.<light|dark>  the no-refund consent sheet, the box
//                                   ticked (the button enabled)
//   store_iap.section.<light|dark>  the store packages at the store's price
//                                   and «أُضيفت … عملة» after a purchase
//   store_iap.banned                a banned device: the message, no packages
//
// Kabso's own coin art only; the price string is the store's (fake here).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/store_iap_d345_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/store_iap/data/store_billing.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';
import 'package:kabso_live/features/store_iap/presentation/store_iap_section.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_store_iap.dart';
import '../helpers/golden.dart';

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 0;
}

Widget _scope(FakeStoreBilling billing, FakeStoreIapRepository repo) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storeBillingProvider.overrideWithValue(billing),
        storeIapRepositoryProvider.overrideWithValue(repo),
        deviceKeySourceProvider.overrideWithValue(FakeDeviceKeySource()),
        currentUserProvider.overrideWithValue(null),
        liveCoinsProvider.overrideWith(_Coins.new),
      ],
      child: ListView(children: const [StoreIapSection()]),
    );

const _products = [
  StoreCoinProduct(productId: 'coins_100k', coins: 100000),
  StoreCoinProduct(productId: 'coins_1m', coins: 1000000),
  StoreCoinProduct(productId: 'coins_5m', coins: 5000000),
];
const _prices = {
  'coins_100k': r'$1.49',
  'coins_1m': r'$12.99',
  'coins_5m': r'$64.99',
};

void main() {
  forEachLanguage((language) {
    for (final brightness in Brightness.values) {
      testWidgets('store_iap.consent.${brightness.name} ${language.name}', (
        tester,
      ) async {
        await pumpGolden(
          tester,
          ColoredBox(
            color: const Color(0x99000000),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: (context) => Material(
                  color: context.palette.surfaceRaised,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KRadius.xl),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(top: KSpacing.xl),
                    child: StoreConsentSheet(
                      platform: StorePlatform.android,
                      coins: 1000000,
                      storePrice: r'$12.99',
                      consentVersion: '2026-11-09',
                    ),
                  ),
                ),
              ),
            ),
          ),
          language: language,
          brightness: brightness,
          bare: true,
        );
        await tester.tap(find.byKey(StoreConsentSheet.checkKey));
        await tester.pumpAndSettle();
        await expectScreenGolden(
          'store_iap.consent.${brightness.name}',
          language: language,
        );
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('store_iap.section.${brightness.name} ${language.name}', (
        tester,
      ) async {
        final billing = FakeStoreBilling(prices: _prices);
        await pumpGolden(
          tester,
          _scope(
            billing,
            FakeStoreIapRepository(catalog: storeCatalog(products: _products)),
          ),
          language: language,
          brightness: brightness,
        );
        billing.emit([
          const StoreTx(
            productId: 'coins_1m',
            status: StoreTxStatus.purchased,
            verificationData: 'gp-token',
            needsCompletion: true,
          ),
        ]);
        await tester.pumpAndSettle();
        await expectScreenGolden(
          'store_iap.section.${brightness.name}',
          language: language,
        );
      });
    }

    testWidgets('store_iap.banned ${language.name}', (tester) async {
      await pumpGolden(
        tester,
        _scope(
          FakeStoreBilling(),
          FakeStoreIapRepository(
            catalog: storeCatalog(
              available: false,
              unavailable: StoreUnavailable.deviceBanned,
            ),
          ),
        ),
        language: language,
      );
      await expectScreenGolden('store_iap.banned', language: language);
    });
  });
}
