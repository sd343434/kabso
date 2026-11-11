// D370 «نقاط الشحن»: the VIP page and the wallet with fake repositories, for
// the widget tests and the goldens (393 × 852, status bar 59, home indicator
// 34, real fonts).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/store_iap/application/store_iap_controller.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/features/wallet/data/recharge_points_repository.dart';
import 'package:kabso_live/features/wallet/presentation/recharge_points_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/vip/vip_points_d370_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class PointsCoins extends LiveCoinsController {
  new(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

/// The VIP API: tiers and membership from the fixtures; a points purchase
/// recorded (or refused with [failRedeemWith]).
class FakePointsVip implements VipRepository {
  new({this.list, this.membership, this.failRedeemWith, this.renewalQuote});

  final VipTierList? list;
  VipMembership? membership;
  final AppFailure? failRedeemWith;
  VipRenewal? renewalQuote;
  final List<({String tierId, int pricePoints, String key})> redeems = [];
  final List<({String tierId, int priceCoins})> buys = [];

  @override
  Future<VipTierList> tiers() async => list ?? d370Tiers;

  @override
  Future<VipMembership?> mine() async => membership;

  @override
  Future<VipRenewal?> renewal() async => renewalQuote;

  @override
  Future<VipPurchase> buy({
    required String tierId,
    required int priceCoins,
    required String idempotencyKey,
  }) async {
    buys.add((tierId: tierId, priceCoins: priceCoins));
    final m = _membershipOf(tierId);
    return (kind: VipPurchaseKind.bought, membership: m, coins: 0);
  }

  @override
  Future<VipRedemption> redeemWithPoints({
    required String tierId,
    required int pricePoints,
    required String idempotencyKey,
  }) async {
    redeems.add((
      tierId: tierId,
      pricePoints: pricePoints,
      key: idempotencyKey,
    ));
    final failure = failRedeemWith;
    if (failure != null) throw failure;
    final m = _membershipOf(tierId);
    membership = m;
    return (
      kind: VipPurchaseKind.bought,
      membership: m,
      rechargePoints: 500000,
    );
  }

  VipMembership _membershipOf(String tierId) {
    final tier = (list ?? d370Tiers).tiers.firstWhere((t) => t.id == tierId);
    return VipMembership(
      tierId: tier.id,
      tierCode: tier.code,
      tierName: tier.name,
      tierColor: tier.color,
      onSale: true,
      startedAt: d370Now,
      expiresAt: d370Now.add(Duration(days: tier.durationDays)),
      daysLeft: tier.durationDays,
    );
  }

  @override
  Future<VipDailyCoinsClaim> claimDailyCoins() => throw UnimplementedError();

  @override
  Future<ProfileVisitorList> profileVisitors() => throw UnimplementedError();
}

/// `GET /me/recharge-points`: [balance] and [history] (one page).
class FakeRechargePoints implements RechargePointsRepository {
  new({this.balance = 2500000, this.history = const []});

  int balance;
  final List<RechargePointsEntry> history;
  int reads = 0;

  @override
  Future<RechargePointsPage> page({String? cursor, int? limit}) async {
    reads++;
    return (
      balance: balance,
      items: limit == null ? history : history.take(limit).toList(),
      next: null,
    );
  }
}

/// The wallet's recharge packages (none: the row is what matters here).
class FakePointsPrograms implements ProgramsRepository {
  @override
  Future<RechargeOffer> rechargePackages() async => const RechargeOffer(
    currency: 'USD',
    purchasesEnabled: false,
    packages: [
      RechargePackage(
        id: 'p1',
        coins: 1000000,
        bonusCoins: 0,
        priceMinor: 1250,
      ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _device(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.reset);
}

/// Pumps [initial] (the VIP page by default) with the fakes.
Future<void> pumpPoints(
  WidgetTester tester, {
  FakePointsVip? vip,
  FakeRechargePoints? points,
  String initial = '/',
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.dark,
  int coins = 1200000,
}) async {
  await _device(tester);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const VipScreen()),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletScreen()),
      GoRoute(
        path: AppRoutes.rechargePoints,
        builder: (_, _) => const RechargePointsScreen(),
      ),
    ],
  );
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(() => PointsCoins(coins)),
        vipRepositoryProvider.overrideWithValue(vip ?? FakePointsVip()),
        rechargePointsRepositoryProvider.overrideWithValue(
          points ?? FakeRechargePoints(),
        ),
        programsRepositoryProvider.overrideWithValue(FakePointsPrograms()),
        homeBannersRepositoryProvider.overrideWithValue(
          FakeHomeBannersRepository(),
        ),
        storeOfferProvider.overrideWith((ref) async => null),
        rechargeOrdersVisibleProvider.overrideWith((ref) async => false),
        storeBuildProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
