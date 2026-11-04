// D270 (owner: «المتجر»; contract v1.84-social, CONVENTIONS §10.98): the
// store — tabs by kind, a grid with the preview, «جديد», «تملكه» and the
// lowest price; the item's sheet with only the durations and currencies
// priced, the price and the balance, «شراء» / «إهداء», short coins → «شحن»,
// short cherries explained, «ارتدِ الآن» after buying; a store item worn
// shows in every renderer (the look takes it over the VIP one; no VIP badge
// for a store-only look). Goldens of the grid and the sheet, ar / en at
// 393 × 852 with the iPhone insets (59 / 34).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/follows/data/follow_lists_repository.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/store/data/store_repository.dart';
import 'package:kabso_live/features/store/presentation/store_gift_picker.dart';
import 'package:kabso_live/features/store/presentation/store_item_sheet.dart';
import 'package:kabso_live/features/store/presentation/store_screen.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_bag_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _Coins extends LiveCoinsController {
  new(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

/// The owner's uploaded stills, faked with bundled pictures (tests draw the
/// still; the SVGA / MP4 players are off).
const _art = {
  'frame': 'assets/host_frames/host_frame_pink.webp',
  'frame_blue': 'assets/host_frames/host_frame_blue.webp',
  'frame_gold': 'assets/levels/support_frames/support_frame_12.webp',
  'card': 'assets/card_boxes/family.webp',
  'bubble': 'assets/win_frames/win_frame_sapphire.png',
  'banner': 'assets/win_frames/win_frame_ruby.png',
  'car': 'assets/live_top_frames/top_1.webp',
};

String _still(String name) => 'https://media.example.test/store/$name.png';

ImageProvider _image(String url) {
  final name = url.split('/').last.replaceAll('.png', '');
  return AssetImage(_art[name] ?? 'assets/live_bar/gift.png');
}

StoreItem _item(
  String code,
  StoreKind kind,
  String name, {
  required String art,
  List<StorePrice> prices = const [
    StorePrice(currency: StoreCurrency.coins, days: 7, amount: 50000),
    StorePrice(currency: StoreCurrency.coins, days: 30, amount: 150000),
    StorePrice(currency: StoreCurrency.cherries, days: 7, amount: 400000),
  ],
  bool isNew = false,
  DateTime? ownedUntil,
  ArtVideo? video,
}) => StoreItem(
  id: 'id-$code',
  code: code,
  kind: kind,
  name: name,
  art: StoreArt(
    still: _still(art),
    animation:
        'https://media.example.test/store/$art.${video == null ? 'svga' : 'mp4'}',
    video: video,
  ),
  prices: prices,
  isNew: isNew,
  ownedUntil: ownedUntil,
);

StoreItemList _list({
  required bool ar,
  int coins = 120000,
  int cherries = 0,
  int locked = 0,
}) => StoreItemList(
  kinds: StoreKind.values,
  balances: StoreBalances(
    coins: coins,
    cherries: cherries,
    lockedCherries: locked,
  ),
  items: [
    _item(
      'store_000000000001',
      StoreKind.avatarFrame,
      ar ? 'إطار الوردة' : 'Rose frame',
      art: 'frame',
      isNew: true,
    ),
    _item(
      'store_000000000002',
      StoreKind.avatarFrame,
      ar ? 'إطار الملكة' : 'Queen frame',
      art: 'frame_blue',
      ownedUntil: DateTime.utc(2026, 11, 20),
      prices: const [
        StorePrice(currency: StoreCurrency.coins, days: 14, amount: 90000),
      ],
    ),
    _item(
      'store_000000000003',
      StoreKind.avatarFrame,
      ar ? 'إطار الكرز' : 'Cherry frame',
      art: 'frame_gold',
      prices: const [
        StorePrice(currency: StoreCurrency.cherries, days: 30, amount: 2000000),
      ],
    ),
    _item(
      'store_000000000004',
      StoreKind.profileCard,
      ar ? 'بطاقة العائلة' : 'Family card',
      art: 'card',
    ),
    _item(
      'store_000000000005',
      StoreKind.chatBubble,
      ar ? 'فقاعة الياقوت' : 'Sapphire bubble',
      art: 'bubble',
      video: ArtVideo.sideBySide,
    ),
    _item(
      'store_000000000006',
      StoreKind.entryBanner,
      ar ? 'لافتة الياقوت' : 'Ruby banner',
      art: 'banner',
    ),
    _item(
      'store_000000000007',
      StoreKind.entryEffect,
      ar ? 'سيارة التاج' : 'Crown car',
      art: 'car',
      isNew: true,
    ),
  ],
);

class _FakeStore implements StoreRepository {
  new(this.list);

  StoreItemList list;
  final List<Map<String, Object?>> buys = [];
  Object? fail;

  @override
  Future<StoreItemList> items() async => list;

  @override
  Future<StorePurchase> buy({
    required String itemId,
    required StoreCurrency currency,
    required int days,
    required int amount,
    required String idempotencyKey,
    String? recipient,
  }) async {
    buys.add({
      'itemId': itemId,
      'currency': currency.wire,
      'days': days,
      'price': amount,
      'key': idempotencyKey,
      'recipient': recipient,
    });
    if (fail case final f?) return await Future.error(f);
    final item = list.items.firstWhere((i) => i.id == itemId);
    return StorePurchase(
      id: 'p1',
      itemId: itemId,
      code: item.code,
      kind: item.kind,
      name: item.name,
      currency: currency,
      days: days,
      cost: amount,
      expiresAt: DateTime.utc(2026, 11, 11),
      extended: false,
      balances: StoreBalances(
        coins: currency == StoreCurrency.coins
            ? list.balances.coins - amount
            : list.balances.coins,
        cherries: list.balances.cherries,
      ),
      recipient: recipient == null
          ? null
          : UserSummary(
              id: 'u-$recipient',
              username: recipient,
              displayName: recipient,
              avatarUrl: null,
            ),
    );
  }
}

class _FakeFollows implements FollowListsRepository {
  @override
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
    String? query,
    FollowListOrder order = FollowListOrder.newest,
  }) async => const PageOf([
    FollowListItem(
      id: 'u-sara',
      username: 'sara',
      displayName: 'Sara',
      avatarUrl: null,
      isSelf: false,
      isPrivate: false,
      followedByMe: true,
      followsMe: true,
    ),
  ], PageInfo(nextCursor: null, hasMore: false));

  @override
  Future<int> removeFollower(String username) async => 0;
}

Future<(_FakeStore, FakeBagRepository)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  int coins = 120000,
  int cherries = 0,
  int locked = 0,
  Brightness brightness = Brightness.dark,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  final store = _FakeStore(
    _list(
      ar: language == AppLanguage.ar,
      coins: coins,
      cherries: cherries,
      locked: locked,
    ),
  );
  final bag = FakeBagRepository();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const StoreScreen()),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, _) => const Text('page ${AppRoutes.wallet}'),
      ),
      GoRoute(
        path: AppRoutes.bag,
        builder: (_, _) => const Text('page ${AppRoutes.bag}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(() => _Coins(coins)),
        storeRepositoryProvider.overrideWithValue(store),
        bagRepositoryProvider.overrideWithValue(bag),
        followListsRepositoryProvider.overrideWithValue(_FakeFollows()),
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
        // The iPhone's insets (59 top, 34 bottom); animations off.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return (store, bag);
}

Future<void> _open(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(StoreScreen.itemKey(code)));
  await tester.pumpAndSettle();
  await precacheImages(tester);
}

Future<void> _tapButton(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => vipImageFor = _image);
  tearDown(() => vipImageFor = NetworkImage.new);

  testWidgets('the grid: tabs by kind, «New», «Owned», the lowest price '
      '(coins first), the balances', (tester) async {
    await _pump(tester);
    expect(find.text('Avatar frames'), findsOneWidget);
    expect(find.text('Entry cars'), findsOneWidget);
    expect(find.text('Rose frame'), findsOneWidget);
    expect(
      find.byKey(StoreScreen.newKey('store_000000000001')),
      findsOneWidget,
    );
    expect(
      find.byKey(StoreScreen.ownedKey('store_000000000002')),
      findsOneWidget,
    );
    // One tile per item (never one per price or currency).
    for (final code in [
      'store_000000000001',
      'store_000000000002',
      'store_000000000003',
    ]) {
      expect(find.byKey(StoreScreen.itemKey(code)), findsOneWidget);
    }
    // Priced in both: the lowest coin price AND the lowest cherry price.
    Finder price(String code, StoreCurrency c, String text) => find.descendant(
      of: find.byKey(StoreScreen.priceKey(code, c)),
      matching: find.text(text),
    );
    expect(
      price('store_000000000001', StoreCurrency.coins, '50,000'),
      findsOneWidget,
    );
    expect(
      price('store_000000000001', StoreCurrency.cherries, '400,000'),
      findsOneWidget,
    );
    // Priced in one currency: only that one.
    expect(
      find.byKey(
        StoreScreen.priceKey('store_000000000002', StoreCurrency.cherries),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        StoreScreen.priceKey('store_000000000003', StoreCurrency.coins),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(StoreScreen.itemKey('store_000000000003')),
        matching: find.byType(KCherryIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(StoreScreen.coinsKey),
        matching: find.text('120,000'),
      ),
      findsOneWidget,
    );
    // Another tab: only its items.
    await tester.tap(find.text('Chat bubbles'));
    await tester.pumpAndSettle();
    expect(find.text('Sapphire bubble'), findsOneWidget);
    expect(find.text('Rose frame'), findsNothing);
  });

  testWidgets('the sheet: only the durations and currencies priced; buying '
      'for oneself, then «Wear now»', (tester) async {
    final (store, bag) = await _pump(tester);
    await _open(tester, 'store_000000000001');
    expect(find.byKey(StoreItemSheet.daysKey(7)), findsOneWidget);
    expect(find.byKey(StoreItemSheet.daysKey(14)), findsNothing);
    expect(find.byKey(StoreItemSheet.daysKey(30)), findsOneWidget);
    expect(
      find.byKey(StoreItemSheet.currencyKey(StoreCurrency.cherries)),
      findsOneWidget,
    );
    await _tapButton(tester, StoreItemSheet.daysKey(30));
    expect(
      find.descendant(
        of: find.byKey(StoreItemSheet.priceKey),
        matching: find.text('150,000'),
      ),
      findsOneWidget,
    );
    // Cherries: only 7 days is priced there.
    await _tapButton(
      tester,
      StoreItemSheet.currencyKey(StoreCurrency.cherries),
    );
    expect(find.byKey(StoreItemSheet.daysKey(30)), findsNothing);
    expect(find.byKey(StoreItemSheet.shortKey), findsOneWidget);
    expect(find.byKey(StoreItemSheet.rechargeKey), findsNothing);
    expect(
      find.textContaining('earned from gifts'),
      findsOneWidget,
      reason: 'short cherries are explained, never recharged',
    );
    await _tapButton(tester, StoreItemSheet.currencyKey(StoreCurrency.coins));
    await _tapButton(tester, StoreItemSheet.daysKey(7));
    await _tapButton(tester, StoreItemSheet.buyKey);
    await _tapButton(tester, StoreItemSheet.confirmKey);
    expect(store.buys, hasLength(1));
    expect(store.buys.single, containsPair('currency', 'COINS'));
    expect(store.buys.single, containsPair('days', 7));
    expect(store.buys.single, containsPair('price', 50000));
    expect(store.buys.single, containsPair('recipient', null));
    expect(store.buys.single['key'], isA<String>());
    expect(find.byKey(StoreItemSheet.doneKey), findsOneWidget);
    await _tapButton(tester, StoreItemSheet.wearKey);
    expect(bag.calls, contains('setEquipped:store_000000000001'));
    expect(find.text("You're wearing it now"), findsOneWidget);
  });

  testWidgets('short coins: «Recharge» opens the wallet; buying is off', (
    tester,
  ) async {
    final (store, _) = await _pump(tester, coins: 10);
    await _open(tester, 'store_000000000001');
    expect(find.byKey(StoreItemSheet.shortKey), findsOneWidget);
    final buy = tester.widget<KButton>(find.byKey(StoreItemSheet.buyKey));
    expect(buy.onPressed, isNull);
    await _tapButton(tester, StoreItemSheet.rechargeKey);
    expect(find.text('page ${AppRoutes.wallet}'), findsOneWidget);
    expect(store.buys, isEmpty);
  });

  testWidgets('locked task cherries: only the unlocked ones count, and the '
      'sheet says the locked ones are not spent', (tester) async {
    final (store, _) = await _pump(tester, cherries: 100000, locked: 900000);
    await _open(tester, 'store_000000000001');
    await _tapButton(
      tester,
      StoreItemSheet.currencyKey(StoreCurrency.cherries),
    );
    expect(find.byKey(StoreItemSheet.lockedKey), findsOneWidget);
    expect(find.textContaining('900,000 locked'), findsOneWidget);
    // 100,000 spendable < 400,000: short, buying off.
    expect(find.byKey(StoreItemSheet.shortKey), findsOneWidget);
    expect(
      tester.widget<KButton>(find.byKey(StoreItemSheet.buyKey)).onPressed,
      isNull,
    );
    // Not shown when paying with coins.
    await _tapButton(tester, StoreItemSheet.currencyKey(StoreCurrency.coins));
    expect(find.byKey(StoreItemSheet.lockedKey), findsNothing);
    expect(store.buys, isEmpty);
  });

  testWidgets('a gift: picked from the people followed, confirmed, sent', (
    tester,
  ) async {
    final (store, _) = await _pump(tester);
    await tester.ensureVisible(find.text('Entry cars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entry cars'));
    await tester.pumpAndSettle();
    await _open(tester, 'store_000000000007');
    await _tapButton(tester, StoreItemSheet.giftKey);
    expect(find.text('People you follow'), findsOneWidget);
    await tester.tap(find.byKey(StoreGiftPicker.personKey('sara')));
    await tester.pumpAndSettle();
    await _tapButton(tester, StoreItemSheet.confirmKey);
    expect(store.buys.single, containsPair('recipient', 'sara'));
    expect(find.byType(StoreItemSheet), findsNothing);
    expect(find.textContaining('Your gift was sent'), findsOneWidget);
  });

  testWidgets('a changed price is said, nothing bought', (tester) async {
    final (store, _) = await _pump(tester);
    store.fail = const ServerFailure(
      code: ErrorCode.storePriceChanged,
      rawCode: 'STORE_PRICE_CHANGED',
      debugMessage: 'changed',
      statusCode: 409,
    );
    await _open(tester, 'store_000000000001');
    await _tapButton(tester, StoreItemSheet.buyKey);
    await _tapButton(tester, StoreItemSheet.confirmKey);
    expect(
      find.text('The price of this item changed. Check the new price.'),
      findsOneWidget,
    );
    expect(find.byKey(StoreItemSheet.doneKey), findsNothing);
  });

  group('worn store items in every renderer', () {
    test('UserSummary.wear rides in `vip`: a store-only look, or over the '
        'VIP perk of its kind', () {
      final plain = UserSummary.fromJson({
        'id': 'u1',
        'username': 'sara',
        'displayName': 'Sara',
        'avatarUrl': null,
        'wear': {
          'chatBubble': {
            'code': 'store_000000000005',
            'still': 'https://m.test/b.png',
            'animation': 'https://m.test/b.mp4',
            'format': 'MP4',
            'alpha': 'SIDE_BY_SIDE',
            'width': 300,
            'height': 120,
          },
        },
      });
      final vip = plain.vip!;
      expect(vip.member, isFalse);
      expect(vip.store['CHAT_BUBBLE']!.video, ArtVideo.sideBySide);
      final look = vipLookOf(vip, null)!;
      expect(look.perk(VipPerks.bubble)!.video, ArtVideo.sideBySide);
      expect(look.has(VipPerks.badge), isFalse);
      expect(look.has(VipPerks.nameColor), isFalse);
      // The round trip keeps it.
      expect(UserSummary.fromJson(plain.toJson()).vip, vip);

      final member = UserSummary.fromJson({
        'id': 'u2',
        'username': 'omar',
        'displayName': 'Omar',
        'avatarUrl': null,
        'vip': {
          'tier': 'VIP_1',
          'rank': 1,
          'color': '#2E8B3D',
          'off': ['ENTRY_EFFECT'],
        },
        'wear': {
          'entryEffect': {
            'code': 'store_000000000007',
            'still': 'https://m.test/car.png',
            'animation': 'https://m.test/car.svga',
            'format': 'SVGA',
            'alpha': null,
            'width': null,
            'height': null,
          },
        },
      }).vip!;
      expect(member.member, isTrue);
      const catalog = VipTierList(
        tiers: [
          VipTier(
            id: 't1',
            code: 'VIP_1',
            name: 'VIP 1',
            level: 1,
            color: 0xFF2E8B3D,
            priceCoins: 1,
            durationDays: 30,
            perks: [
              VipPerk(code: VipPerks.badge, title: 'b', available: true),
              VipPerk(
                code: VipPerks.entryEffect,
                title: 'car',
                available: true,
                still: 'https://m.test/vip_car.png',
              ),
            ],
          ),
        ],
        maxAheadDays: 400,
      );
      final both = vipLookOf(member, catalog)!;
      expect(both.perk(VipPerks.entryEffect)!.still, 'https://m.test/car.png');
      expect(both.has(VipPerks.badge), isTrue);
      expect(
        UserSummary.fromJson({
          'id': 'u3',
          'username': 'x',
          'displayName': 'x',
          'avatarUrl': null,
        }).vip,
        isNull,
      );
    });

    testWidgets('a store-only look draws no VIP badge', (tester) async {
      const vip = UserVip.storeOnly({
        'AVATAR_FRAME': StoreArt(still: 'https://m.test/f.png'),
      });
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: VipNameBadge(vip: vip, height: 18),
          ),
        ),
      );
      expect(find.byKey(VipNameBadge.badgeKey), findsNothing);
      expect(find.text('VIP0'), findsNothing);
    });
  });

  testWidgets('two prices fit 3 columns at 360 × 800 (no overflow)', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    setViewport(tester, GoldenViewport.android);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(
        StoreScreen.priceKey('store_000000000001', StoreCurrency.cherries),
      ),
      findsOneWidget,
    );
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('store_grid (${language.name})', (tester) async {
        await _pump(tester, language: language);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/store_grid.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);

      testWidgets('store_item_sheet (${language.name})', (tester) async {
        await _pump(tester, language: language, cherries: 500000);
        await _open(tester, 'store_000000000001');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/store_item_sheet.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}
