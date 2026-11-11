// D252 / D252b v2: «شراء VIP» in the owner's new reference layout — a
// horizontal tier tab row (the selected one gold with an underline), the
// selected tier's centred BADGE, a crown divider, category section headers
// («التعريف» / «امتياز حصري») and a 3-column perks grid (each perk a thumbnail
// + title + subtitle, a lock for «قريباً»), and a sticky bar with the
// price/length and the activate button; buy / renew / upgrade with the confirm
// card; a lower tier refused; empty and error states; Arabic RTL and 360 × 800
// at text scale 1.3. Server data only (fakes here); SVGA animation is off in
// tests (the still shows), set by flutter_test_config.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_carousel.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
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

// D252c (owner: «لدينا ١٢ في اي بي وكل في اي بي له امتيازات»): twelve
// tiers, each its own colour, price and perks.
const _colors = [
  0xFF2E8B3D,
  0xFF2AA7B8,
  0xFFE50914,
  0xFF9B59D0,
  0xFF3D6AE0,
  0xFFE08A1E,
  0xFFC2185B,
  0xFF00897B,
  0xFF6D4C41,
  0xFF5E35B1,
  0xFFD4AF37,
  0xFF111111,
];
final List<int> _prices = [for (var i = 1; i <= 12; i++) i * i * 1000000];

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
      const VipPerk(
        code: 'ENTRY_BANNER',
        title: 'Entry banner',
        available: false,
      ),
    if (level >= 3)
      const VipPerk(
        code: 'DAILY_BULLET',
        title: 'Daily bullet',
        available: false,
      ),
    if (level >= 4)
      const VipPerk(
        code: 'CHAT_BUBBLE',
        title: 'Chat bubble',
        available: false,
      ),
    if (level >= 6)
      const VipPerk(code: 'MIC_WAVE', title: 'Mic wave', available: false),
    if (level >= 8)
      const VipPerk(code: 'ROOM_CARD', title: 'Room card', available: false),
    if (level >= 10)
      const VipPerk(
        code: 'MONTHLY_GIFT',
        title: 'Monthly gift',
        available: false,
      ),
  ],
);

VipTierList _list({bool art = false}) => VipTierList(
  tiers: [for (var l = 1; l <= 12; l++) _tier(l, art: art && l == 1)],
  maxAheadDays: 400,
);

VipMembership _membership(
  VipTier tier, {
  int days = 20,
  bool onSale = true,
  VipDailyCoins? dailyCoins,
  // Goldens fix the date: the page shows «حتى <expiresAt>».
  DateTime? now,
}) => VipMembership(
  dailyCoins: dailyCoins,
  tierId: tier.id,
  tierCode: tier.code,
  tierName: tier.name,
  tierColor: tier.color,
  onSale: onSale,
  startedAt: (now ?? DateTime.now()).subtract(const Duration(days: 10)),
  expiresAt: (now ?? DateTime.now()).add(Duration(days: days)),
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

  /// D370: redemptions with recharge points (none in these tests).
  @override
  Future<VipRedemption> redeemWithPoints({
    required String tierId,
    required int pricePoints,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  /// D258: the caller's renewal quote (null: none).
  VipRenewal? renewalQuote;

  @override
  Future<VipRenewal?> renewal() async => renewalQuote;

  /// D258: «من زار ملفي».
  ProfileVisitorList visitors = (data: const <ProfileVisitor>[], total: 0);

  @override
  Future<ProfileVisitorList> profileVisitors() async => visitors;

  /// D258: daily coins claims (each answers [dailyAmount] once a day).
  int claims = 0;
  int dailyAmount = 500;

  @override
  Future<VipDailyCoinsClaim> claimDailyCoins() async {
    claims++;
    return (
      coins: claims == 1 ? dailyAmount : 0,
      balance: 1000,
      daily: VipDailyCoins(
        amount: dailyAmount,
        claimedToday: true,
        nextAt: DateTime.now().add(const Duration(hours: 5)),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeVip vip,
  int coins = 5000000,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  Brightness brightness = Brightness.light,
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
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
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

/// D304: brings [code]'s card to the middle of the carousel — swiping toward
/// it until it is built, then tapping it (a tap on a neighbour selects it).
Future<void> _tapTab(WidgetTester tester, String code) async {
  final card = find.byKey(VipScreen.tabKey(code));
  final carousel = find.byKey(VipTierCarousel.carouselKey);
  final rtl = Directionality.of(tester.element(carousel)) == TextDirection.rtl;
  final want = int.parse(code.split('_').last);
  for (var i = 0; i < 30; i++) {
    final area = tester.getRect(carousel);
    if (card.evaluate().isNotEmpty) {
      final c = tester.getCenter(card);
      if ((c.dx - area.center.dx).abs() < 1) return;
      if (c.dx > area.left && c.dx < area.right) {
        await tester.tapAt(
          Offset(c.dx.clamp(area.left + 6, area.right - 6), c.dy),
        );
        await tester.pumpAndSettle();
        continue;
      }
    }
    // Swipe one page toward it (forward = the higher tiers).
    final selected = tester
        .widget<VipTierCarousel>(find.byType(VipTierCarousel))
        .selectedId;
    final at = int.parse(selected.substring(1));
    final forward = want > at;
    await tester.drag(
      carousel,
      Offset((rtl ? 1 : -1) * (forward ? 1 : -1) * area.width * 0.6, 0),
    );
    await tester.pumpAndSettle();
  }
  fail('could not bring $code to the middle');
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
    testWidgets('not VIP yet: the tier tabs in order, the badge, the section '
        'headers and perks, buy with the confirm card', (tester) async {
      final vip = _FakeVip();
      await _pump(tester, vip: vip);
      // No membership: no status line.
      expect(find.byKey(VipScreen.statusKey), findsNothing);
      // The centred badge and the tier tabs in the panel order.
      expect(find.byKey(VipScreen.emblemKey), findsOneWidget);
      final first = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_1')));
      final second = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_2')));
      expect(first.dx, lessThan(second.dx));
      // Price and length in the sticky bar; the buy button.
      expect(find.text('1,000,000'), findsWidgets);
      expect(find.text(_en.vipPricePer('30')), findsWidgets);
      expect(_cta(_en.vipPayCoins), findsOneWidget);
      // D252c: «الامتياز الحصري VIPn x/y» (this tier's perks / the most a
      // tier has) and the tier's perks (one not yet built is dimmed).
      // D258 (owner, reference 38): «التعريف» and a tile per perk.
      // D304: «VIP Privileges» and the count (this tier's perks / the most
      // a tier has).
      expect(find.text(_en.vipPrivilegesHeader), findsOneWidget);
      expect(find.text('(1/7)'), findsOneWidget);
      expect(find.byKey(VipScreen.perkKey('BADGE')), findsOneWidget);

      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmKey), findsOneWidget);
      expect(find.text(_en.vipConfirmBuy('VIP 1')), findsOneWidget);
      // The balance shows in the confirm card.
      expect(
        find.descendant(
          of: find.byKey(VipScreen.confirmKey),
          matching: find.text('5,000,000'),
        ),
        findsOneWidget,
      );
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
      // VIP 3 has a privilege perk, so the privilege section has a grid.
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
      // D252c: the perk's art shows in its showcase tile.
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
      // D252c: «My VIP» at the end edge opens the member's status.
      expect(find.byKey(VipScreen.statusKey), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.statusKey));
      await tester.pumpAndSettle();
      expect(find.textContaining(_en.vipDaysLeft('20')), findsOneWidget);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
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

    testWidgets('D258: «My VIP» claims the daily coins once a day', (
      tester,
    ) async {
      final held = _membership(
        _tier(1),
        dailyCoins: VipDailyCoins(
          amount: 500,
          claimedToday: false,
          nextAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      final vip = _FakeVip(membership: held);
      await _pump(tester, vip: vip);
      await tester.tap(find.byKey(VipScreen.statusKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.vipDailyCoins('500')), findsOneWidget);
      expect(find.text(_en.vipDailyCoinsClaim), findsOneWidget);
      await tester.tap(find.byKey(VipDailyCoinsRow.claimKey));
      await tester.pumpAndSettle();
      expect(vip.claims, 1);
      expect(find.text(_en.vipDailyCoinsAdded('500')), findsOneWidget);
      expect(find.text(_en.vipDailyCoinsClaimed), findsOneWidget);
      // Claimed: the button is off.
      await tester.tap(find.byKey(VipDailyCoinsRow.claimKey));
      await tester.pumpAndSettle();
      expect(vip.claims, 1);
    });

    testWidgets('D258: without the perk, no daily coins row', (tester) async {
      await _pump(tester, vip: _FakeVip(membership: _membership(_tier(2))));
      await tester.tap(find.byKey(VipScreen.statusKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipDailyCoinsRow.rowKey), findsNothing);
    });

    test('D258: MyVip.dailyCoins and the wallet reason are read', () {
      final daily = VipDailyCoins.fromJson(const {
        'amount': 500,
        'claimedToday': true,
        'nextAt': '2026-11-05T21:00:00.000Z',
      });
      expect(daily.amount, 500);
      expect(daily.claimedToday, isTrue);
      expect(
        WalletLedgerReason.fromWire('VIP_DAILY_COINS'),
        WalletLedgerReason.vipDailyCoins,
      );
    });

    testWidgets('D258: the bottom bar totals the daily coins over the length '
        '(only a real amount)', (tester) async {
      const tier = VipTier(
        id: 'id-D',
        code: 'VIP_1',
        name: 'VIP 1',
        level: 1,
        color: 0xFF2E8B3D,
        priceCoins: 1000000,
        durationDays: 30,
        perks: [
          VipPerk(
            code: 'DAILY_COINS',
            title: 'Daily coins',
            available: true,
            amount: 500,
          ),
        ],
      );
      await _pump(
        tester,
        vip: _FakeVip(
          list: const VipTierList(tiers: [tier], maxAheadDays: 400),
        ),
      );
      expect(find.text(_en.vipCashback('15,000', '500')), findsOneWidget);
      // The tile shows its value.
      expect(find.text(_en.vipPerkPerDay('500')), findsOneWidget);
    });

    testWidgets('D258: a renewal is charged its discounted price, the list '
        'price struck through; the discount line shows the real value', (
      tester,
    ) async {
      const tier = VipTier(
        id: 'id-R',
        code: 'VIP_1',
        name: 'VIP 1',
        level: 1,
        color: 0xFF2E8B3D,
        priceCoins: 1000000,
        durationDays: 30,
        renewalDiscountPercent: 15,
        renewPriceCoins: 850000,
        perks: [],
      );
      final vip =
          _FakeVip(
              list: const VipTierList(tiers: [tier], maxAheadDays: 400),
              membership: _membership(tier),
            )
            ..renewalQuote = (
              tierId: 'id-R',
              priceCoins: 850000,
              discountPercent: 15,
              until: DateTime.now().add(const Duration(days: 27)),
              pricePoints: null,
            );
      await _pump(tester, vip: vip);
      expect(find.text(_en.vipRenewalDiscountLine('15')), findsOneWidget);
      expect(find.byKey(VipScreen.listPriceKey), findsOneWidget);
      expect(find.text('850,000'), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.vipPay('850,000')), findsOneWidget);
      await tester.tap(find.byKey(VipScreen.payKey));
      await tester.pumpAndSettle();
      expect(vip.buys.single.priceCoins, 850000);
    });

    testWidgets('D258: no discount set — no discount line, the list price', (
      tester,
    ) async {
      await _pump(tester, vip: _FakeVip());
      expect(find.byKey(VipScreen.renewalLineKey), findsNothing);
      expect(find.byKey(VipScreen.listPriceKey), findsNothing);
    });

    testWidgets('D258: no daily coins amount, no total line', (tester) async {
      await _pump(tester, vip: _FakeVip());
      expect(find.byKey(VipScreen.dailyTotalKey), findsNothing);
    });

    testWidgets('an off-sale tier shows a note', (tester) async {
      final held = _membership(_tier(2), onSale: false);
      await _pump(tester, vip: _FakeVip(membership: held));
      await tester.tap(find.byKey(VipScreen.statusKey));
      await tester.pumpAndSettle();
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
      expect(_cta(_en.vipPayCoins), findsOneWidget);
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
          // D304: the top bar's title «في آي بي»; «الخاص بي VIP».
          expect(find.text(_ar.vipPageTitle), findsOneWidget);
          expect(find.text(_ar.vipMine), findsOneWidget);
          expect(find.text(_ar.vipRenew), findsOneWidget);
          // RTL: the first tier is at the reading start (the right).
          final first = tester.getCenter(find.byKey(VipScreen.tabKey('VIP_1')));
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

  group('D252c the new reference (white / black, 12 tiers)', () {
    testWidgets('D304: twelve cards swipe; each tier its own perks and '
        'count', (tester) async {
      await _pump(tester, vip: _FakeVip());
      await _tapTab(tester, 'VIP_12');
      final card = tester.getRect(find.byKey(VipScreen.tabKey('VIP_12')));
      expect(card.center.dx, moreOrLessEquals(393 / 2, epsilon: 1));
      expect(find.byKey(VipScreen.perkKey('MONTHLY_GIFT')), findsOneWidget);
      expect(find.text('(7/7)'), findsOneWidget);
      await _tapTab(tester, 'VIP_4');
      expect(find.byKey(VipScreen.perkKey('MONTHLY_GIFT')), findsNothing);
      expect(find.text('(4/7)'), findsOneWidget);
    });

    testWidgets("D304: the page is the reference's navy in both modes, "
        'whatever the tier (supersedes D258)', (tester) async {
      List<Color> colors() =>
          ((tester
                              .widget<DecoratedBox>(
                                find.byKey(VipScreen.backdropKey),
                              )
                              .decoration
                          as BoxDecoration)
                      .gradient!
                  as LinearGradient)
              .colors;
      await _pump(tester, vip: _FakeVip());
      expect(colors(), VipScreen.backdrop);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, vip: _FakeVip(), brightness: Brightness.dark);
      await _tapTab(tester, 'VIP_3');
      expect(colors(), VipScreen.backdrop);
    });

    // The reference's VIP2: six art perks in the showcase, ten perks.
    VipTierList showcase() {
      const art = [
        ('FRAME', 'Frame', 'top_1'),
        ('ENTRY_BANNER', 'Entry banner', 'win_frame_amethyst'),
        ('NAME_PLATE', 'Name plate', 'win_frame_onyx'),
        ('CHAT_BUBBLE', 'Chat bubble', 'host_frame_blue'),
        ('BADGE', 'VIP badge', 'top_2'),
        ('ROOM_CARD', 'Room card', 'host_frame_pink'),
      ];
      const plain = [
        ('DAILY_BULLET', 'Daily bullet'),
        ('VIEWER_LIST_PRIORITY', 'Top of the viewers'),
        ('MONTHLY_GIFT', 'Monthly gift'),
        ('VISITORS', 'Visitors checking'),
      ];
      final base = _list();
      final vip2 = VipTier(
        id: 't2',
        code: 'VIP_2',
        name: 'VIP 2',
        level: 2,
        color: _colors[1],
        priceCoins: 42000,
        durationDays: 30,
        badgeStill: 'https://cdn.k.test/top_2.png',
        perks: [
          for (final (code, title, img) in art)
            VipPerk(
              code: code,
              title: title,
              available: true,
              still: 'https://cdn.k.test/$img.png',
            ),
          for (final (code, title) in plain)
            VipPerk(code: code, title: title, available: true),
        ],
      );
      return VipTierList(
        tiers: [
          for (final t in base.tiers)
            if (t.level == 2) vip2 else t,
        ],
        maxAheadDays: base.maxAheadDays,
      );
    }

    String assetFor(String url) {
      final name = url.split('/').last.replaceAll('.png', '');
      if (name.startsWith('top_')) return 'assets/live_top_frames/$name.webp';
      if (name.startsWith('win_')) return 'assets/win_frames/$name.png';
      return 'assets/host_frames/$name.webp';
    }

    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets('golden ${language.name} ${brightness.name}', (
          tester,
        ) async {
          vipImageFor = (url) => AssetImage(assetFor(url));
          addTearDown(() => vipImageFor = NetworkImage.new);
          await _pump(
            tester,
            vip: _FakeVip(list: showcase()),
            language: language,
            brightness: brightness,
          );
          await _tapTab(tester, 'VIP_2');
          await precacheImages(tester);
          await expectLater(
            find.byType(VipScreen),
            matchesGoldenFile(
              'png/vip.ref.${language.name}.${brightness.name}.phone.png',
            ),
          );
        });
      }
    }
    testWidgets('D258 golden: «My VIP» with the daily coins (ar)', (
      tester,
    ) async {
      final held = _membership(
        _tier(1),
        // The day the golden was made: «حتى 24 نوفمبر 2026» whatever today is.
        now: DateTime(2026, 11, 4, 12),
        dailyCoins: VipDailyCoins(
          amount: 500,
          claimedToday: false,
          nextAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      );
      await _pump(
        tester,
        vip: _FakeVip(membership: held),
        language: AppLanguage.ar,
      );
      await tester.tap(find.byKey(VipScreen.statusKey));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/vip.daily_coins.ar.phone.png'),
      );
    });
  });

  group('D304 the reference layout: top bar, tier cards, hexagon perks', () {
    Rect cardOf(WidgetTester tester, String code) =>
        tester.getRect(find.byKey(VipScreen.tabKey(code)));

    double opacityOf(WidgetTester tester, String code) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(VipScreen.tabKey(code)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    for (final language in AppLanguage.values) {
      testWidgets('the top bar, then the cards in reading order with the '
          "reference's measures (${language.name})", (tester) async {
        await _pump(tester, vip: _FakeVip(), language: language);
        final l10n = language == AppLanguage.ar ? _ar : _en;
        final title = find.byKey(VipScreen.titleKey);
        expect(find.text(l10n.vipPageTitle), findsOneWidget);
        expect(
          tester.getCenter(title).dx,
          moreOrLessEquals(393 / 2, epsilon: 1),
        );
        final back = tester.getRect(find.byType(IconButton).first);
        // Back at the reading start.
        if (language == AppLanguage.ar) {
          expect(back.center.dx, greaterThan(393 / 2));
        } else {
          expect(back.center.dx, lessThan(393 / 2));
        }
        // VIP 1 centred, 300 × 147.4 pt; VIP 2 peeks at the reading end.
        final first = cardOf(tester, 'VIP_1');
        expect(first.top, greaterThan(back.bottom));
        expect(first.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
        expect(first.width, moreOrLessEquals(KVipRef.cardWidth, epsilon: 0.5));
        expect(
          first.height,
          moreOrLessEquals(KVipRef.cardHeight, epsilon: 0.5),
        );
        final second = cardOf(tester, 'VIP_2');
        if (language == AppLanguage.ar) {
          expect(second.right, moreOrLessEquals(first.left - 31.5, epsilon: 1));
          expect(second.right, greaterThan(0));
        } else {
          expect(second.left, moreOrLessEquals(first.right + 31.5, epsilon: 1));
          expect(second.left, lessThan(393));
        }
        // The header 37 pt under the cards; the first hexagon 41 × 48.6.
        final header = tester.getRect(find.text(l10n.vipPrivilegesHeader));
        expect(header.top - first.bottom, moreOrLessEquals(37, epsilon: 1));
        final hex = tester.getRect(
          find
              .descendant(
                of: find.byKey(VipScreen.perkKey('BADGE')),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(hex.width, KVipRef.hexWidth);
        expect(hex.height, moreOrLessEquals(KVipRef.hexHeight, epsilon: 0.01));
        // Its column is the reading-start quarter of the screen.
        expect(
          hex.center.dx,
          moreOrLessEquals(
            language == AppLanguage.ar ? 393 * 3 / 4 : 393 / 4,
            epsilon: 1,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a swipe selects the next tier: badge, price, perks follow', (
      tester,
    ) async {
      await _pump(tester, vip: _FakeVip(), language: AppLanguage.ar);
      // RTL: the next tier is to the left; swipe right to bring it in.
      await tester.drag(
        find.byKey(VipTierCarousel.carouselKey),
        const Offset(250, 0),
      );
      await tester.pumpAndSettle();
      expect(
        cardOf(tester, 'VIP_2').center.dx,
        moreOrLessEquals(393 / 2, epsilon: 1),
      );
      expect(find.text('4,000,000'), findsWidgets);
      expect(find.byKey(VipScreen.perkKey('ENTRY_BANNER')), findsOneWidget);
      // The emblem is the selected card's badge only.
      expect(find.byKey(VipScreen.emblemKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(VipScreen.tabKey('VIP_2')),
          matching: find.byKey(VipScreen.emblemKey),
        ),
        findsOneWidget,
      );
      // A tap on the neighbour back at the reading start selects VIP 1.
      await tester.tapAt(Offset(cardOf(tester, 'VIP_1').left + 8, 150));
      await tester.pumpAndSettle();
      expect(find.text('1,000,000'), findsWidgets);
      expect(find.byKey(VipScreen.perkKey('ENTRY_BANNER')), findsNothing);
    });

    testWidgets('a member opens on their tier, the card says until when; '
        'the tiers below are dimmed and not sold', (tester) async {
      final held = _membership(_tier(10));
      await _pump(tester, vip: _FakeVip(membership: held));
      expect(
        cardOf(tester, 'VIP_10').center.dx,
        moreOrLessEquals(393 / 2, epsilon: 1),
      );
      expect(
        find.descendant(
          of: find.byKey(VipScreen.tabKey('VIP_10')),
          matching: find.textContaining('VIP 10 until'),
        ),
        findsOneWidget,
      );
      // «My VIP» sits in the top bar.
      expect(find.byKey(VipScreen.statusKey), findsOneWidget);
      expect(opacityOf(tester, 'VIP_9'), lessThan(1));
      expect(opacityOf(tester, 'VIP_11'), 1);
      await _tapTab(tester, 'VIP_9');
      expect(_cta(_en.vipLowerTier), findsOneWidget);
      expect(opacityOf(tester, 'VIP_9'), 1);
    });

    testWidgets('semantics: each card a button with the tier name and its '
        'line; the selected one marked; the owned one says so', (tester) async {
      final handle = tester.ensureSemantics();
      final held = _membership(_tier(2));
      await _pump(tester, vip: _FakeVip(membership: held));
      final date = KFormat.date(held.expiresAt, 'en');
      expect(
        tester.getSemantics(find.byKey(VipScreen.tabKey('VIP_2'))),
        matchesSemantics(
          label: 'VIP 2',
          value: '${_en.vipCurrent}، ${_en.vipUntil('VIP 2', date)}',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(VipScreen.tabKey('VIP_3'))),
        matchesSemantics(
          label: 'VIP 3',
          value: '9,000,000 ${_en.vipPricePer('30')}',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel(_en.vipPageTitle), findsOneWidget);
      expect(find.bySemanticsLabel(_en.vipPrivilegesHeader), findsOneWidget);
      handle.dispose();
    });

    testWidgets("D304b the bar: the coin by the price; a lower tier's button "
        'is disabled (muted, not tappable)', (tester) async {
      final handle = tester.ensureSemantics();
      final vip = _FakeVip(membership: _membership(_tier(3)));
      await _pump(tester, vip: vip);
      expect(
        find.descendant(
          of: find.byKey(VipScreen.barKey),
          matching: find.byWidgetPredicate(
            (w) => w is KabsoArtIcon && w.art == KabsoArt.coin,
          ),
        ),
        findsOneWidget,
      );
      expect(_cta(_en.vipRenew), findsOneWidget);
      await _tapTab(tester, 'VIP_1');
      expect(_cta(_en.vipLowerTier), findsOneWidget);
      expect(
        tester.getSemantics(
          find
              .ancestor(
                of: find.byKey(VipScreen.ctaKey),
                matching: find.byType(Semantics),
              )
              .first,
        ),
        matchesSemantics(
          label: _en.vipLowerTier,
          isButton: true,
          hasEnabledState: true,
        ),
      );
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScreen.confirmKey), findsNothing);
      handle.dispose();
    });

    testWidgets('one tier: one card, centred, nothing peeking', (tester) async {
      await _pump(
        tester,
        vip: _FakeVip(list: VipTierList(tiers: [_tier(1)], maxAheadDays: 400)),
      );
      expect(find.byType(VipTierCard), findsOneWidget);
      expect(
        cardOf(tester, 'VIP_1').center.dx,
        moreOrLessEquals(393 / 2, epsilon: 0.5),
      );
      expect(find.text('(1/1)'), findsOneWidget);
      expect(_cta(_en.vipPayCoins), findsOneWidget);
      // A swipe has nowhere to go.
      await tester.drag(
        find.byKey(VipTierCarousel.carouselKey),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(
        cardOf(tester, 'VIP_1').center.dx,
        moreOrLessEquals(393 / 2, epsilon: 0.5),
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('12 tiers at 360 × 800, text scale 1.3 (${language.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          vip: _FakeVip(membership: _membership(_tier(12))),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final twelve = cardOf(tester, 'VIP_12');
        expect(twelve.center.dx, moreOrLessEquals(180, epsilon: 1));
        // The card keeps the reference's proportion at 360.
        expect(
          twelve.width / twelve.height,
          moreOrLessEquals(
            KVipRef.cardWidth / KVipRef.cardHeight,
            epsilon: 0.01,
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(VipScreen.perkKey('MONTHLY_GIFT')),
          100,
          scrollable: _page,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
