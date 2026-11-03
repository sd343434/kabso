// D252: «شراء VIP» — the tiers the owner manages in the admin panel, in its
// order, each with its own price, length and perks (every perk «قريباً»
// until it is built); the status; buy, renew and upgrade with the confirm
// card (price, balance, the new end; the recharge when short); a lower tier
// refused; empty and error states; Arabic RTL and 360 × 800 at text scale
// 1.3. Server data only (fakes here).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
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

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

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
    ProviderScope(
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
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String code) async {
  await tester.ensureVisible(find.byKey(VipScreen.tabKey(code)));
  await tester.tap(find.byKey(VipScreen.tabKey(code)));
  await tester.pumpAndSettle();
}

/// The page's vertical list (the tier switcher scrolls too).
final Finder _page = find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

Finder _cta(String label) => find.descendant(
  of: find.byKey(VipScreen.ctaKey),
  matching: find.text(label),
);

void main() {
  group('vipActionFor', () {
    final now = DateTime.now();
    final list = _list();

    test('buy without a membership or after it ended', () {
      expect(vipActionFor(_tier(2), null, list, now), VipAction.buy);
      final ended = _membership(_tier(3), days: -1);
      expect(vipActionFor(_tier(1), ended, list, now), VipAction.buy);
    });

    test('renew the same tier, up to the prepaid limit', () {
      final held = _membership(_tier(2));
      expect(vipActionFor(_tier(2), held, list, now), VipAction.renew);
      final far = _membership(_tier(2), days: 380);
      expect(vipActionFor(_tier(2), far, list, now), VipAction.renewLimit);
    });

    test('upgrade to a higher tier; a lower one is not sold', () {
      final held = _membership(_tier(2));
      expect(vipActionFor(_tier(3), held, list, now), VipAction.upgrade);
      expect(vipActionFor(_tier(1), held, list, now), VipAction.lower);
    });
  });

  group('purchase VIP', () {
    testWidgets('not VIP yet: the tiers in the panel order, the first '
        'selected, its price and perks («Soon»), buy with the confirm '
        'card', (tester) async {
      final vip = _FakeVip();
      await _pump(tester, vip: vip);
      expect(find.text(_en.vipNotYet), findsOneWidget);
      final first = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_1')));
      final second = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_2')));
      expect(first.dx, lessThan(second.dx));
      expect(find.byKey(VipScreen.emblemKey), findsOneWidget);
      expect(find.text('1,000,000'), findsWidgets);
      expect(find.text(_en.vipForDays('30')), findsWidgets);
      expect(_cta(_en.vipBuy), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(VipScreen.perkKey('BADGE')),
        100,
        scrollable: _page,
      );
      // No perk is shown as active: each says «Soon».
      expect(find.text(_en.liveSoon), findsOneWidget);
      expect(find.text('Next to your name'), findsOneWidget);

      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmKey), findsOneWidget);
      expect(find.text(_en.vipConfirmBuy('VIP 1')), findsOneWidget);
      expect(find.text('5,000,000'), findsOneWidget);
      expect(find.text(_en.vipManualRenew), findsOneWidget);
      expect(find.byKey(VipScreen.shortKey), findsNothing);
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(vip.buys.single.tierId, 't1');
      expect(vip.buys.single.priceCoins, 1000000);
      expect(vip.buys.single.key, hasLength(36));
      // The status now: VIP 1, and the button renews it.
      expect(find.byKey(VipScreen.confirmKey), findsNothing);
      expect(_cta(_en.vipRenew), findsOneWidget);
    });

    testWidgets('each tier has its own price and perks', (tester) async {
      await _pump(tester, vip: _FakeVip());
      await _tapTab(tester, 'VIP_3');
      expect(find.text('9,000,000'), findsWidgets);
      expect(find.text(_en.vipPerksTitle('VIP 3')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(VipScreen.perkKey('DAILY_BULLET')),
        100,
        scrollable: _page,
      );
      expect(find.byKey(VipScreen.perkKey('ENTRY_BANNER')), findsOneWidget);
      await _tapTab(tester, 'VIP_1');
      expect(find.byKey(VipScreen.perkKey('DAILY_BULLET')), findsNothing);
    });

    testWidgets('a short balance: the confirm card leads to the recharge', (
      tester,
    ) async {
      final vip = _FakeVip();
      await _pump(tester, vip: vip, coins: 1250);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.shortKey), findsOneWidget);
      expect(find.byKey(VipScreen.payKey), findsNothing);
      await tester.tap(find.byKey(VipScreen.rechargeKey));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.wallet}'), findsOneWidget);
      expect(vip.buys, isEmpty);
    });

    testWidgets('holding VIP 2: renew it, upgrade to VIP 3 (the days left '
        'are not carried), VIP 1 is below', (tester) async {
      final held = _membership(_tier(2));
      await _pump(tester, vip: _FakeVip(membership: held));
      expect(
        find.text(_en.vipUntil('VIP 2', KFormat.date(held.expiresAt, 'en'))),
        findsOneWidget,
      );
      expect(find.text(_en.vipDaysLeft('20')), findsOneWidget);
      // The held tier is selected first.
      expect(_cta(_en.vipRenew), findsOneWidget);

      await _tapTab(tester, 'VIP_3');
      expect(_cta(_en.vipUpgrade), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.vipConfirmUpgrade('VIP 3')), findsOneWidget);
      expect(find.text(_en.vipUpgradeNote('VIP 2')), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.cancelKey));
      await tester.pumpAndSettle();

      await _tapTab(tester, 'VIP_1');
      expect(_cta(_en.vipLowerTier), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmKey), findsNothing);
    });

    testWidgets('a refused purchase says why', (tester) async {
      final vip = _FakeVip(
        failBuyWith: const ServerFailure(
          code: ErrorCode.vipUnavailable,
          rawCode: 'VIP_UNAVAILABLE',
          debugMessage: 'refused',
          statusCode: 409,
          details: [FieldIssue(field: 'tier', issue: 'tier_off')],
        ),
      );
      await _pump(tester, vip: vip);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.vipErrorTierOff), findsOneWidget);
      expect(_cta(_en.vipBuy), findsOneWidget);
    });

    testWidgets('nothing on sale: an empty state, no button', (tester) async {
      await _pump(
        tester,
        vip: _FakeVip(
          list: const VipTierList(tiers: [], maxAheadDays: 400),
        ),
      );
      expect(find.byKey(VipScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.vipEmpty), findsOneWidget);
      expect(find.byKey(VipScreen.ctaKey), findsNothing);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(tester, vip: _FakeVip(fail: true));
      expect(find.text(_en.vipLoadError), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('360 × 800 at text scale 1.3 (${language.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          vip: _FakeVip(membership: _membership(_tier(1))),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(VipScreen.ctaKey), findsOneWidget);
        if (language == AppLanguage.ar) {
          expect(find.text(_ar.meHubVip), findsOneWidget);
          expect(find.text(_ar.vipRenew), findsOneWidget);
          // RTL: the first tier is at the reading start (the right).
          final first = tester.getCenter(
            find.byKey(VipScreen.tabKey('VIP_1')),
          );
          final second = tester.getCenter(
            find.byKey(VipScreen.tabKey('VIP_2')),
          );
          expect(first.dx, greaterThan(second.dx));
        }
        await tester.scrollUntilVisible(
          find.byKey(VipScreen.perkKey('BADGE')),
          100,
          scrollable: _page,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
