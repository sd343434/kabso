// D146: the premium usernames store — tier prices from the server (none
// hard-coded; "not on sale" while a tier has none), the live check as the
// person types, the rent sheet (price, balance, end date, one idempotency
// key per sheet, not enough coins, a changed price), the person's own
// premium username with its countdown, renew and give back; Arabic RTL and
// English.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/components/k_special_username.dart';
import 'package:kabso_live/design_system/design_system.dart' show KButton;
import 'package:kabso_live/features/premium/application/premium_providers.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/premium/presentation/premium_rent_sheet.dart';
import 'package:kabso_live/features/premium/presentation/premium_store_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_premium_repository.dart';
import '../../helpers/pump_app.dart' show l10nFor;
import 'premium_harness.dart';

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(PremiumStoreScreen.searchKey), text);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('tiers with server prices, a tier not on sale, suggestions', (
    tester,
  ) async {
    final premium = FakePremiumRepository();
    await pumpPremium(tester, const PremiumStoreScreen(), premium: premium);
    expect(find.text(en.premiumTitle), findsOneWidget);
    expect(find.text(en.premiumPricePerPeriod('50,000', 30)), findsOneWidget);
    expect(find.text(en.premiumPricePerPeriod('20,000', 30)), findsOneWidget);
    expect(find.text(en.premiumPricePerPeriod('12,000', 30)), findsOneWidget);
    expect(find.text(en.premiumTierNotOnSale), findsOneWidget);
    expect(find.byKey(PremiumStoreScreen.suggestionKey('777')), findsOneWidget);
    expect(find.byType(KSpecialUsername), findsWidgets);
    // A tier tab asks the server for that tier only.
    await tester.tap(
      find.byKey(PremiumStoreScreen.tierTabKey(PremiumTier.gold)),
    );
    await tester.pumpAndSettle();
    expect(premium.calls, contains('store:GOLD'));
    expect(find.byKey(PremiumStoreScreen.suggestionKey('777')), findsNothing);
    expect(
      find.byKey(PremiumStoreScreen.suggestionKey('1221')),
      findsOneWidget,
    );
  });

  testWidgets('nothing priced: says so honestly, no names', (tester) async {
    final premium = FakePremiumRepository(
      prices: {for (final t in PremiumTier.values) t: null},
    );
    await pumpPremium(tester, const PremiumStoreScreen(), premium: premium);
    expect(find.byKey(PremiumStoreScreen.notOnSaleKey), findsOneWidget);
    expect(find.text(en.premiumNotOnSaleTitle), findsOneWidget);
    expect(find.byKey(PremiumStoreScreen.suggestionKey('777')), findsNothing);
  });

  testWidgets('live check: available, taken, regular; rent from the result', (
    tester,
  ) async {
    final premium = FakePremiumRepository();
    await pumpPremium(tester, const PremiumStoreScreen(), premium: premium);
    await _type(tester, '1234');
    expect(find.text(en.premiumStateTaken), findsOneWidget);
    expect(find.byKey(PremiumStoreScreen.resultRentKey), findsNothing);
    await _type(tester, 'sara22');
    expect(find.text(en.premiumStateRegular), findsOneWidget);
    await _type(tester, '@5432');
    expect(premium.calls.last, 'status:5432');
    expect(find.text(en.premiumStateAvailable), findsOneWidget);
    await tester.tap(find.byKey(PremiumStoreScreen.resultRentKey));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumRentSheet), findsOneWidget);
    expect(find.text(en.premiumRentFor('12,000')), findsOneWidget);
    await tester.tap(find.byKey(PremiumRentSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(premium.lastRent?.username, '5432');
    expect(premium.lastRent?.priceCoins, 12000);
    expect(premium.lastRent?.key, hasLength(36));
    expect(find.byType(PremiumRentSheet), findsNothing);
    // The store now shows the person's own premium username.
    expect(find.byKey(PremiumStoreScreen.myCardKey), findsOneWidget);
  });

  testWidgets('not enough coins: the button is off and says why', (
    tester,
  ) async {
    final premium = FakePremiumRepository();
    await pumpPremium(
      tester,
      const PremiumStoreScreen(),
      premium: premium,
      coins: 100,
    );
    await tester.scrollUntilVisible(
      find.byKey(PremiumStoreScreen.suggestionKey('777')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PremiumStoreScreen.suggestionKey('777')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumRentSheet), findsOneWidget);
    expect(find.byKey(PremiumRentSheet.balanceKey), findsOneWidget);
    expect(find.text(en.premiumCoins('100')), findsOneWidget);
    expect(find.byKey(PremiumRentSheet.shortKey), findsOneWidget);
    final button = tester.widget<KButton>(
      find.byKey(PremiumRentSheet.confirmKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a changed price: the sheet shows the new one', (tester) async {
    final premium = FakePremiumRepository();
    await pumpPremium(tester, const PremiumStoreScreen(), premium: premium);
    await tester.scrollUntilVisible(
      find.byKey(PremiumStoreScreen.suggestionKey('1221')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PremiumStoreScreen.suggestionKey('1221')));
    await tester.pumpAndSettle();
    premium
      ..prices = {...premium.prices, PremiumTier.gold: 15000}
      ..failNext['rent'] = premiumFailure(
        ErrorCode.premiumUsernamePriceChanged,
      );
    await tester.tap(find.byKey(PremiumRentSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PremiumRentSheet.errorKey), findsOneWidget);
    expect(find.text(en.premiumRentFor('15,000')), findsOneWidget);
  });

  testWidgets('my premium username: countdown, renew, give back (Arabic)', (
    tester,
  ) async {
    final now = DateTime.now();
    final premium = FakePremiumRepository(
      mineValue: MyPremiumUsername(
        username: '7777',
        tier: PremiumTier.ruby,
        grace: false,
        granted: false,
        startedAt: now.subtract(const Duration(days: 20)),
        expiresAt: now.add(const Duration(days: 10, hours: 5, minutes: 1)),
        graceUntil: null,
        regularUsername: 'sara_2026',
        renewPriceCoins: 12000,
        canRenew: true,
      ),
    );
    await pumpPremium(
      tester,
      const PremiumStoreScreen(),
      premium: premium,
      language: AppLanguage.ar,
    );
    expect(find.byKey(PremiumStoreScreen.myCardKey), findsOneWidget);
    expect(
      find.text(ar.premiumMineLeft(ar.premiumLeftDays(10, 5))),
      findsOneWidget,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(PremiumStoreScreen.myCardKey)),
      ),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(PremiumStoreScreen.renewKey));
    await tester.pumpAndSettle();
    expect(find.text(ar.premiumRenewTitle), findsOneWidget);
    await tester.tap(find.byKey(PremiumRentSheet.confirmKey));
    await tester.pumpAndSettle();
    expect(premium.lastRent?.username, '7777');
    // Give back asks first.
    await tester.tap(find.byKey(PremiumStoreScreen.releaseKey));
    await tester.pumpAndSettle();
    expect(find.text(ar.premiumReleaseTitle), findsOneWidget);
    await tester.tap(find.text(ar.premiumRelease).last);
    await tester.pumpAndSettle();
    expect(premium.calls, contains('release'));
    expect(find.byKey(PremiumStoreScreen.myCardKey), findsNothing);
  });

  test('state wire values; unknown is not purchasable', () {
    expect(
      PremiumNameState.fromWire('YOURS_GRACE'),
      PremiumNameState.yoursGrace,
    );
    expect(PremiumNameState.fromWire('SOMETHING'), PremiumNameState.unknown);
    expect(PremiumNameState.unknown.purchasable, isFalse);
    expect(PremiumTier.fromWire('PLATINUM'), isNull);
  });

  test('the check provider type is exported', () {
    expect(premiumCheckProvider, isNotNull);
  });
}
