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
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_ref_parts.dart';
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
      expect(find.textContaining(_en.vipForDays('30')), findsWidgets);
      expect(_cta(_en.vipPayCoins), findsOneWidget);
      // D252c: «الامتياز الحصري VIPn x/y» (this tier's perks / the most a
      // tier has) and the tier's perks (one not yet built is dimmed).
      expect(find.text('Exclusive privileges VIP1 1/7'), findsOneWidget);
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
          of: find.byKey(VipShowcaseCard.tileKey('BADGE')),
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
          // D252c: no page title (the reference has none); «الخاص بي VIP».
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
    testWidgets('twelve tabs scroll; the selected one comes into view; each '
        'tier its own perks and count', (tester) async {
      await _pump(tester, vip: _FakeVip());
      for (var l = 1; l <= 12; l++) {
        expect(find.byKey(VipScreen.tabKey('VIP_$l')), findsOneWidget);
      }
      await _tapTab(tester, 'VIP_12');
      final tab = tester.getRect(find.byKey(VipScreen.tabKey('VIP_12')));
      expect(tab.left, greaterThanOrEqualTo(0));
      expect(tab.right, lessThanOrEqualTo(393));
      expect(find.byKey(VipScreen.perkKey('MONTHLY_GIFT')), findsOneWidget);
      expect(find.text('Exclusive privileges VIP12 7/7'), findsOneWidget);
      await _tapTab(tester, 'VIP_4');
      expect(find.byKey(VipScreen.perkKey('MONTHLY_GIFT')), findsNothing);
      expect(find.text('Exclusive privileges VIP4 4/7'), findsOneWidget);
    });

    testWidgets('the page is white in light mode and black in dark mode', (
      tester,
    ) async {
      await _pump(tester, vip: _FakeVip());
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFFFFFFFF),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, vip: _FakeVip(), brightness: Brightness.dark);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFF000000),
      );
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
  });
}
