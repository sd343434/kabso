// D252 / D252b: «شراء VIP» in the owner's reference layout — the hanging crest
// banner (the tier BADGE art), the curved tier track, the status and upgrade
// bar, and the crown-topped perks grid (each perk a still art thumbnail + title
// + «قريباً»); buy / renew / upgrade with the confirm card; a lower tier
// refused; empty and error states; Arabic RTL and 360 × 800 at text scale 1.3.
// Server data only (fakes here); SVGA animation is off in tests (the still
// shows), set by flutter_test_config.

import 'package:flutter/widgets.dart' show Image;
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
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

class _Coins extends LiveCoinsController {
  _Coins(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

const _colors = [0xFF2E8B3D, 0xFF9B59D0, 0xFFE50914];
const _prices = [1000000, 3000000, 9000000];

VipTier _tier(int level, {bool art = false}) => VipTier(
  id: 't$level',
  code: 'VIP_$level',
  name: 'VIP $level',
  level: level,
  color: _colors[level - 1],
  priceCoins: _prices[level - 1],
  durationDays: 30,
  badgeStill: art ? 'https://cdn.k.test/vip1_badge.png' : null,
  badgeAnimation: art ? 'https://cdn.k.test/vip1_badge.svga' : null,
  perks: [
    VipPerk(
      code: 'BADGE',
      title: 'VIP badge',
      available: false,
      still: art ? 'https://cdn.k.test/vip1_badge.png' : null,
      artWidth: art ? 500 : null,
      artHeight: art ? 500 : null,
    ),
    if (level >= 2)
      const VipPerk(code: 'ENTRY_BANNER', title: 'Entry banner', available: false),
    if (level >= 3)
      const VipPerk(code: 'DAILY_BULLET', title: 'Daily bullet', available: false),
  ],
);

VipTierList _list({bool art = false}) => VipTierList(
  tiers: [_tier(1, art: art), _tier(2), _tier(3)],
  maxAheadDays: 400,
);

VipMembership _membership(VipTier tier, {int days = 20, bool onSale = true}) =>
    VipMembership(
      tierId: tier.id,
      tierCode: tier.code,
      tierName: tier.name,
      tierColor: tier.color,
      onSale: onSale,
      startedAt: DateTime.now().subtract(const Duration(days: 10)),
      expiresAt: DateTime.now().add(Duration(days: days)),
      daysLeft: days,
    );

class _FakeVip implements VipRepository {
  _FakeVip({this.list, this.membership, this.fail = false, this.failBuyWith});

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

final Finder _page = find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapTab(WidgetTester tester, String code) async {
  await tester.ensureVisible(find.byKey(VipScreen.tabKey(code)));
  await tester.tap(find.byKey(VipScreen.tabKey(code)));
  await tester.pumpAndSettle();
}

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
    testWidgets('not VIP yet: the crest, the tier track in order, the status '
        'and upgrade bar, perks «Soon», buy with the confirm card', (
      tester,
    ) async {
      final vip = _FakeVip();
      await _pump(tester, vip: vip);
      // Status line: non-VIP.
      expect(
        find.text(_en.vipCurrently(_en.vipStatusNone)),
        findsOneWidget,
      );
      // The crest badge and the tier track in the panel order.
      expect(find.byKey(VipScreen.emblemKey), findsOneWidget);
      expect(find.byKey(VipScreen.bannerKey), findsOneWidget);
      final first = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_1')));
      final second = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_2')));
      expect(first.dx, lessThan(second.dx));
      // The upgrade bar aims at the lowest tier for a non-member.
      expect(find.text(_en.vipUpgradeTo('VIP 1')), findsOneWidget);
      // Price and length in the sticky bar; the buy button.
      expect(find.text('1,000,000'), findsWidgets);
      expect(find.text(_en.vipForDays('30')), findsWidgets);
      expect(_cta(_en.vipBuy), findsOneWidget);
      // The perks grid: the section header and «Soon».
      expect(find.text(_en.vipPerksTitle('VIP 1')), findsOneWidget);
      expect(find.byKey(VipScreen.perkKey('BADGE')), findsOneWidget);
      expect(find.text(_en.liveSoon), findsOneWidget);

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

    testWidgets('the real badge and perk art render as the still image', (
      tester,
    ) async {
      await _pump(tester, vip: _FakeVip(list: _list(art: true)));
      // The badge slot shows an Image (the bundled still), not the placeholder.
      expect(
        find.descendant(
          of: find.byKey(VipScreen.emblemKey),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      // The perk thumbnail shows the still too.
      expect(
        find.descendant(
          of: find.byKey(VipScreen.perkKey('BADGE')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
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

    testWidgets('holding VIP 2: status with the end, renew it, upgrade to '
        'VIP 3 (days not carried), VIP 1 is below', (tester) async {
      final held = _membership(_tier(2));
      await _pump(tester, vip: _FakeVip(membership: held));
      expect(
        find.text(_en.vipCurrently('VIP 2')),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en.vipDaysLeft('20')),
        findsOneWidget,
      );
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

    testWidgets('an off-sale tier shows a note', (tester) async {
      final held = _membership(_tier(2), onSale: false);
      await _pump(tester, vip: _FakeVip(membership: held));
      expect(find.byKey(VipScreen.offSaleKey), findsOneWidget);
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
        vip: _FakeVip(list: const VipTierList(tiers: [], maxAheadDays: 400)),
      );
      expect(find.byKey(VipScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.vipEmpty), findsOneWidget);
      expect(find.byKey(VipScreen.ctaKey), findsNothing);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(tester, vip: _FakeVip(fail: true));
      expect(find.text(_en.vipLoadError), findsOneWidget);
    });

    testWidgets('the store entry opens the rules / coming-soon sheet', (
      tester,
    ) async {
      await _pump(tester, vip: _FakeVip());
      await tester.tap(find.byKey(VipScreen.storeKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.vipStoreSoon), findsOneWidget);
      expect(find.text(_en.vipRules), findsOneWidget);
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
          final first = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_1')));
          final second = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_2')));
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
