// D370 (owner 2026-11-11, CONVENTIONS §10.163) «نقاط الشحن»: the VIP page's
// second way to pay «استبدل بالنقاط» beside «ادفع بالعملات الذهبية» — only for
// a tier priced in points; the points price (the renewal's when quoted), the
// balance, «نقاط غير كافية» when short; the confirm card in points; the
// purchase sent with `payWith: POINTS`; INSUFFICIENT_RECHARGE_POINTS and
// `no_points_price` messages. The wallet row «نقاط الشحن» opens the history
// with every reason named, ar / en. The repository reads the contract shape.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/features/wallet/data/recharge_points_repository.dart';
import 'package:kabso_live/features/wallet/presentation/recharge_points_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/vip/vip_points_d370_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/pump_app.dart';
import 'vip_points_harness.dart';

final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);

Finder _cta(String label) => find.descendant(
  of: find.byKey(VipScreen.ctaKey),
  matching: find.text(label),
);

void main() {
  group('the VIP page «استبدل بالنقاط»', () {
    testWidgets('both ways to pay; points shows the price and the balance', (
      tester,
    ) async {
      await pumpPoints(tester);
      expect(find.byKey(VipScreen.payCoinsKey), findsOneWidget);
      expect(find.byKey(VipScreen.payPointsKey), findsOneWidget);
      // Coins first (as before): the coin price and «ادفع بالعملات الذهبية».
      expect(find.byKey(VipScreen.pointsPriceKey), findsNothing);
      expect(_cta(_ar.vipPayCoins), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.pointsPriceKey), findsOneWidget);
      expect(find.text('2,000,000'), findsWidgets);
      expect(
        find.textContaining(_ar.vipPointsBalance('2,500,000')),
        findsOneWidget,
      );
      expect(_cta(_ar.vipPayPoints), findsOneWidget);
    });

    testWidgets('a tier without a points price offers coins only', (
      tester,
    ) async {
      await pumpPoints(
        tester,
        vip: FakePointsVip(
          list: VipTierList(tiers: [d370Tier(3)], maxAheadDays: 400),
        ),
        language: AppLanguage.en,
      );
      expect(find.byKey(VipScreen.payPointsKey), findsNothing);
      expect(_cta(_en.vipPayCoins), findsOneWidget);
    });

    testWidgets('confirm in points and send payWith POINTS; coins untouched', (
      tester,
    ) async {
      final vip = FakePointsVip();
      final points = FakeRechargePoints();
      await pumpPoints(
        tester,
        vip: vip,
        points: points,
        language: AppLanguage.en,
      );
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmPointsKey), findsOneWidget);
      expect(find.text(_en.vipPoints('2,000,000')), findsOneWidget);
      expect(find.text(_en.vipPoints('2,500,000')), findsOneWidget);
      expect(find.byKey(VipScreen.rechargeKey), findsNothing);
      final reads = points.reads;
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(vip.redeems, hasLength(1));
      expect(vip.redeems.single.tierId, 'p1');
      expect(vip.redeems.single.pricePoints, 2000000);
      expect(vip.buys, isEmpty);
      // The balance is read again after the redemption.
      expect(points.reads, greaterThan(reads));
    });

    testWidgets('the renewal quote gives the discounted points price', (
      tester,
    ) async {
      final vip = FakePointsVip(
        renewalQuote: (
          tierId: 'p1',
          priceCoins: 850000,
          discountPercent: 15,
          until: d370Now.add(const Duration(days: 27)),
          pricePoints: 1700000,
        ),
      );
      await pumpPoints(tester, vip: vip, language: AppLanguage.en);
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      expect(find.text('1,700,000'), findsOneWidget);
      // The list points price struck through.
      expect(find.byKey(VipScreen.listPriceKey), findsOneWidget);
    });

    testWidgets('short of points: «نقاط غير كافية» and the button is off', (
      tester,
    ) async {
      final vip = FakePointsVip();
      await pumpPoints(
        tester,
        vip: vip,
        points: FakeRechargePoints(balance: 1999999),
      );
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      expect(_cta(_ar.vipPointsShort), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmKey), findsNothing);
      expect(vip.redeems, isEmpty);
    });

    testWidgets('INSUFFICIENT_RECHARGE_POINTS from the server says so', (
      tester,
    ) async {
      final vip = FakePointsVip(
        failRedeemWith: const ServerFailure(
          code: ErrorCode.insufficientRechargePoints,
          rawCode: 'INSUFFICIENT_RECHARGE_POINTS',
          debugMessage: 'Not enough recharge points.',
          statusCode: 409,
        ),
      );
      await pumpPoints(tester, vip: vip, language: AppLanguage.en);
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.errorInsufficientRechargePoints), findsOneWidget);
    });

    testWidgets('VIP_UNAVAILABLE no_points_price says the tier is not '
        'redeemable', (tester) async {
      final vip = FakePointsVip(
        failRedeemWith: const ServerFailure(
          code: ErrorCode.vipUnavailable,
          rawCode: 'VIP_UNAVAILABLE',
          debugMessage: 'x',
          statusCode: 409,
          details: [FieldIssue(field: 'tier', issue: 'no_points_price')],
        ),
      );
      await pumpPoints(tester, vip: vip);
      await tester.tap(find.byKey(VipScreen.payPointsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(find.text(_ar.vipErrorNoPointsPrice), findsOneWidget);
    });
  });

  group('the wallet «نقاط الشحن»', () {
    testWidgets('the row shows the balance and opens the history (ar)', (
      tester,
    ) async {
      await pumpPoints(
        tester,
        initial: '/wallet',
        brightness: Brightness.light,
        points: FakeRechargePoints(history: d370History),
      );
      final row = find.byKey(WalletScreen.rechargePointsKey);
      expect(row, findsOneWidget);
      expect(find.text(_ar.rechargePointsTitle), findsOneWidget);
      expect(find.text(_ar.rechargePointsRowHint('2,500,000')), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(RechargePointsScreen), findsOneWidget);
      expect(find.byKey(RechargePointsScreen.balanceKey), findsOneWidget);
      for (final e in d370History) {
        expect(find.byKey(RechargePointsScreen.entryKey(e.id)), findsOneWidget);
      }
    });

    testWidgets('every reason is named in both languages; unknown is generic', (
      tester,
    ) async {
      for (final l10n in [_ar, _en]) {
        final labels = {
          for (final r in RechargePointsReason.values)
            rechargePointsReasonLabel(l10n, r),
        };
        expect(labels, hasLength(RechargePointsReason.values.length));
      }
      expect(
        RechargePointsReason.fromWire('SOMETHING_NEW'),
        RechargePointsReason.other,
      );
    });

    testWidgets('an empty history', (tester) async {
      await pumpPoints(
        tester,
        initial: '/wallet/recharge-points',
        language: AppLanguage.en,
        brightness: Brightness.light,
        points: FakeRechargePoints(balance: 0),
      );
      expect(find.byKey(RechargePointsScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.rechargePointsEmpty), findsOneWidget);
    });
  });

  group('the repositories read the contract shape', () {
    test('GET /me/recharge-points', () async {
      final adapter = FakeHttpAdapter()
        ..on(
          'GET',
          '/api/v1/me/recharge-points',
          (_) => const FakeResponse(
            200,
            body: {
              'balance': -50000,
              'data': [
                {
                  'id': '0192f1c2-0000-7000-8000-000000000001',
                  'reason': 'REVERSAL',
                  'delta': -2000000,
                  'balanceAfter': -50000,
                  'createdAt': '2026-11-11T09:30:00.000Z',
                },
              ],
              'page': {'nextCursor': 'c2', 'hasMore': true},
            },
          ),
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      final page = await RechargePointsRepositoryImpl(dio).page();
      expect(page.balance, -50000);
      expect(page.next, 'c2');
      expect(page.items.single.reason, RechargePointsReason.reversal);
      expect(page.items.single.delta, -2000000);
    });

    test('VipTier.pricePoints / renewPricePoints (null: not redeemable)', () {
      final base = {
        'id': 't',
        'code': 'VIP_1',
        'name': 'VIP 1',
        'level': 1,
        'color': '#2E8B3D',
        'priceCoins': 1000000,
        'durationDays': 30,
        'perks': <Object>[],
      };
      final priced = VipTier.fromJson({
        ...base,
        'pricePoints': 2000000,
        'renewPricePoints': 1700000,
      });
      expect(priced.pricePoints, 2000000);
      expect(priced.renewPricePoints, 1700000);
      final none = VipTier.fromJson({
        ...base,
        'pricePoints': null,
        'renewPricePoints': null,
      });
      expect(none.pricePoints, isNull);
      // An older server without the fields.
      expect(VipTier.fromJson(base).pricePoints, isNull);
    });
  });
}
