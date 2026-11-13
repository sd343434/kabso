// D345 (CONVENTIONS §10.144): «الشراء من المتجر» in the wallet — hidden when
// the store is off; the banned-device and once-rule messages; the consent
// sheet (the button disabled until the box is ticked); the purchase sent to
// the server with the consent and the device key, finished only once the
// server answered; pending, refused and «استعادة» (a transaction delivered
// again) states. A fake store and a fake server (no plugin, no network).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/store_iap/data/store_billing.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';
import 'package:kabso_live/features/store_iap/presentation/store_iap_section.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_store_iap.dart';

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 0;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeStoreBilling billing,
  required FakeStoreIapRepository repo,
  AppLanguage language = AppLanguage.ar,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storeBillingProvider.overrideWithValue(billing),
        storeIapRepositoryProvider.overrideWithValue(repo),
        deviceKeySourceProvider.overrideWithValue(FakeDeviceKeySource()),
        currentUserProvider.overrideWithValue(null),
        liveCoinsProvider.overrideWith(_Coins.new),
      ],
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
        home: Scaffold(body: ListView(children: const [StoreIapSection()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

StoreTx _tx(StoreTxStatus status, {String data = 'gp-token-1'}) => StoreTx(
  productId: 'coins_1m',
  status: status,
  verificationData: data,
  needsCompletion: status != StoreTxStatus.pending,
);

AppLocalizations _ar(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold)));

void main() {
  testWidgets('hidden when the server store is off or the phone has none', (
    tester,
  ) async {
    await _pump(
      tester,
      billing: FakeStoreBilling(),
      repo: FakeStoreIapRepository(
        catalog: storeCatalog(
          available: false,
          unavailable: StoreUnavailable.off,
        ),
      ),
    );
    expect(find.byKey(StoreIapSection.sectionKey), findsNothing);
    await _pump(
      tester,
      billing: FakeStoreBilling(platform: null),
      repo: FakeStoreIapRepository(),
    );
    expect(find.byKey(StoreIapSection.sectionKey), findsNothing);
    // A product the store does not know is not offered.
    await _pump(
      tester,
      billing: FakeStoreBilling(prices: const {}),
      repo: FakeStoreIapRepository(),
    );
    expect(find.byKey(StoreIapSection.sectionKey), findsNothing);
  });

  testWidgets('a banned device and the once rule show why, no packages', (
    tester,
  ) async {
    await _pump(
      tester,
      billing: FakeStoreBilling(),
      repo: FakeStoreIapRepository(
        catalog: storeCatalog(
          available: false,
          unavailable: StoreUnavailable.deviceBanned,
        ),
      ),
    );
    expect(find.byKey(StoreIapSection.bannedKey), findsOneWidget);
    expect(find.text(_ar(tester).storeIapDeviceBanned), findsOneWidget);
    expect(find.byKey(StoreIapSection.productKey('coins_1m')), findsNothing);
    await _pump(
      tester,
      billing: FakeStoreBilling(),
      repo: FakeStoreIapRepository(
        catalog: storeCatalog(
          available: false,
          unavailable: StoreUnavailable.limitReached,
        ),
      ),
    );
    expect(find.byKey(StoreIapSection.limitKey), findsOneWidget);
    expect(find.byKey(StoreIapSection.productKey('coins_1m')), findsNothing);
  });

  testWidgets(
    'consent first, then the store; the server verifies and the purchase is '
    'finished',
    (tester) async {
      final billing = FakeStoreBilling();
      final repo = FakeStoreIapRepository();
      final container = await _pump(tester, billing: billing, repo: repo);
      final coins = container.listen(liveCoinsProvider, (_, _) {});
      addTearDown(coins.close);
      final l10n = _ar(tester);
      expect(find.text(r'$12.99'), findsOneWidget);
      expect(find.text(l10n.storeIapVia('Google Play')), findsOneWidget);
      await tester.tap(find.byKey(StoreIapSection.productKey('coins_1m')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.storeIapConsentDelivery), findsOneWidget);
      expect(find.text(l10n.storeIapConsentFraud), findsOneWidget);
      final cont = find.byKey(StoreConsentSheet.continueKey);
      expect(tester.widget<FilledButton>(cont).onPressed, isNull);
      await tester.tap(find.byKey(StoreConsentSheet.checkKey));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
      await tester.tap(cont);
      await tester.pumpAndSettle();
      expect(billing.bought, [('coins_1m', 'a' * 64)]);
      expect(repo.verified, isEmpty);
      billing.emit([_tx(StoreTxStatus.purchased)]);
      await tester.pumpAndSettle();
      expect(repo.verified.single, {
        'platform': StorePlatform.android,
        'productId': 'coins_1m',
        'verificationData': 'gp-token-1',
        'version': '2026-11-09',
        'share': true,
        'deviceKey': 'd' * 64,
      });
      expect(billing.completed, hasLength(1));
      expect(find.text(l10n.storeIapSuccess('1,000,000')), findsOneWidget);
      expect(container.read(liveCoinsProvider).value, 1000000);
    },
  );

  testWidgets('closing the consent sheet buys nothing', (tester) async {
    final billing = FakeStoreBilling();
    await _pump(tester, billing: billing, repo: FakeStoreIapRepository());
    await tester.tap(find.byKey(StoreIapSection.productKey('coins_1m')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(billing.bought, isEmpty);
  });

  testWidgets('pending: the store has not completed the payment', (
    tester,
  ) async {
    final billing = FakeStoreBilling();
    final repo = FakeStoreIapRepository();
    await _pump(tester, billing: billing, repo: repo);
    billing.emit([_tx(StoreTxStatus.pending)]);
    await tester.pumpAndSettle();
    expect(find.text(_ar(tester).storeIapPending), findsOneWidget);
    expect(repo.verified, isEmpty);
    // The server also says pending (Google purchaseState 2): not finished.
    repo.failure = const ServerFailure(
      code: ErrorCode.storeIapPending,
      rawCode: 'STORE_IAP_PENDING',
      debugMessage: 'pending',
      statusCode: 409,
    );
    billing.emit([_tx(StoreTxStatus.purchased)]);
    await tester.pumpAndSettle();
    expect(find.text(_ar(tester).storeIapPending), findsOneWidget);
    expect(billing.completed, isEmpty);
  });

  testWidgets(
    'a refused purchase: Android never acknowledges (Google refunds it), iOS '
    'finishes it',
    (tester) async {
      const refused = ServerFailure(
        code: ErrorCode.storeIapVerificationFailed,
        rawCode: 'STORE_IAP_VERIFICATION_FAILED',
        debugMessage: 'no',
        statusCode: 400,
      );
      final android = FakeStoreBilling();
      final repo = FakeStoreIapRepository()..failure = refused;
      await _pump(tester, billing: android, repo: repo);
      android.emit([_tx(StoreTxStatus.purchased)]);
      await tester.pumpAndSettle();
      expect(
        find.text(_ar(tester).errorStoreIapVerificationFailed),
        findsOneWidget,
      );
      expect(android.completed, isEmpty);
      final ios = FakeStoreBilling(
        platform: StorePlatform.ios,
        prices: const {'coins_1m': r'12.99 US$'},
      );
      await _pump(tester, billing: ios, repo: repo);
      ios.emit([_tx(StoreTxStatus.purchased, data: 'jws.a.b')]);
      await tester.pumpAndSettle();
      expect(ios.completed, hasLength(1));
      // Once-per-account+device on Google: not credited, never acknowledged.
      final again = FakeStoreBilling();
      final once = FakeStoreIapRepository()
        ..answer = (_) => const StorePurchaseResult(
          purchaseId: 'p',
          coins: 1000000,
          status: 'REJECTED',
          balance: 0,
          alreadyProcessed: false,
          rejectReason: 'ONCE_LIMIT',
        );
      await _pump(tester, billing: again, repo: once);
      again.emit([_tx(StoreTxStatus.purchased)]);
      await tester.pumpAndSettle();
      expect(find.text(_ar(tester).storeIapRejected), findsOneWidget);
      expect(again.completed, isEmpty);
    },
  );

  testWidgets('a transaction delivered again («استعادة») is verified once '
      'the wallet opens', (tester) async {
    final billing = FakeStoreBilling();
    final repo = FakeStoreIapRepository()
      ..answer = (_) => const StorePurchaseResult(
        purchaseId: 'p',
        coins: 1000000,
        status: 'CREDITED',
        balance: 2000000,
        alreadyProcessed: true,
      );
    await _pump(tester, billing: billing, repo: repo, language: AppLanguage.en);
    billing.emit([_tx(StoreTxStatus.restored, data: 'gp-token-old')]);
    await tester.pumpAndSettle();
    expect(repo.verified.single['verificationData'], 'gp-token-old');
    expect(repo.verified.single['share'], isTrue);
    expect(billing.completed, hasLength(1));
  });
}
