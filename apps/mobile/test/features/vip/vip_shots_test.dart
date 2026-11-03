// TEMPORARY (removed before merge): renders the D252 screen to PNGs for the
// owner. D252: «شراء VIP» — the tiers the owner manages in the admin panel, in its
// order, each with its own price, length and perks (every perk «قريباً»
// until it is built); the status; buy, renew and upgrade with the confirm
// card (price, balance, the new end; the recharge when short); a lower tier
// refused; empty and error states; Arabic RTL and 360 × 800 at text scale
// 1.3. Server data only (fakes here).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _Coins extends LiveCoinsController {
  new(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

const _colors = [0xFFC9A227, 0xFF9B59D0, 0xFFE50914];
const _prices = [1000000, 3000000, 9000000];

VipTier _tier(int level) => VipTier(
  id: 't$level',
  code: 'VIP_$level',
  name: 'VIP $level',
  level: level,
  color: _colors[level - 1],
  priceCoins: _prices[level - 1],
  durationDays: 30,
  perks: [
    const VipPerk(
      code: 'BADGE',
      title: 'VIP badge',
      description: 'Next to your name',
      available: false,
    ),
    if (level >= 2)
      const VipPerk(code: 'ENTRY_BANNER', title: 'Entry banner', available: false),
    if (level >= 3)
      const VipPerk(code: 'DAILY_BULLET', title: 'Daily bullet', available: false),
  ],
);

VipTierList _list() => VipTierList(
  tiers: [_tier(1), _tier(2), _tier(3)],
  maxAheadDays: 400,
);

VipMembership _membership(VipTier tier, {int days = 20}) => VipMembership(
  tierId: tier.id,
  tierCode: tier.code,
  tierName: tier.name,
  tierColor: tier.color,
  onSale: true,
  startedAt: DateTime.now().subtract(const Duration(days: 10)),
  expiresAt: DateTime.now().add(Duration(days: days)),
  daysLeft: days,
);

class _FakeVip implements VipRepository {
  new({this.list, this.membership, this.fail = false, this.failBuyWith});

  final VipTierList? list;
  VipMembership? membership;
  final bool fail;
  final AppFailure? failBuyWith;
  final List<({String tierId, int priceCoins, String key})> buys = [];

  @override
  Future<VipTierList> tiers() async {
    if (fail) throw const NetworkFailure.offline();
    return list ?? _list();
  }

  @override
  Future<VipMembership?> mine() async {
    if (fail) throw const NetworkFailure.offline();
    return membership;
  }

  @override
  Future<VipPurchase> buy({
    required String tierId,
    required int priceCoins,
    required String idempotencyKey,
  }) async {
    buys.add((tierId: tierId, priceCoins: priceCoins, key: idempotencyKey));
    final failure = failBuyWith;
    if (failure != null) throw failure;
    final tier = (list ?? _list()).tiers.firstWhere((t) => t.id == tierId);
    final m = _membership(tier, days: tier.durationDays);
    membership = m;
    return (kind: VipPurchaseKind.bought, membership: m, coins: 100);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeVip vip,
  int coins = 5000000,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const VipScreen()),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, _) => const Text('page ${AppRoutes.wallet}'),
      ),
    ],
  );
  await loadAppFonts();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(() => _Coins(coins)),
        vipRepositoryProvider.overrideWithValue(vip),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String code) async {
  await tester.ensureVisible(find.byKey(VipScreen.tabKey(code)));
  await tester.tap(find.byKey(VipScreen.tabKey(code)));
  await tester.pumpAndSettle();
}



const _shotKey = Key('shot');

Future<void> _shot(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_shotKey)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/shots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    final l = language.name;
    testWidgets('shot not VIP ($l)', (tester) async {
      await _pump(tester, vip: _FakeVip(), language: language);
      await _shot(tester, 'vip_not_member_$l');
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await _shot(tester, 'vip_confirm_buy_$l');
    });
    testWidgets('shot holder upgrade ($l)', (tester) async {
      await _pump(
        tester,
        vip: _FakeVip(membership: _membership(_tier(1))),
        language: language,
      );
      await _tapTab(tester, 'VIP_3');
      await _shot(tester, 'vip_holder_vip3_$l');
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await _shot(tester, 'vip_confirm_upgrade_$l');
    });
    testWidgets('shot short balance ($l)', (tester) async {
      await _pump(tester, vip: _FakeVip(), language: language, coins: 1250);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await _shot(tester, 'vip_confirm_short_$l');
    });
  }
}
