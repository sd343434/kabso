// TEMPORARY (removed before merge): renders the reworked «شراء VIP» screen
// (D252b, the owner's reference layout) with the real VIP 1 art to PNGs under
// build/shots/, for the owner to review. All VIP art is hosted (https) in
// production; here the still PNGs under test/fixtures/vip/ are served to
// Image.network through an HttpOverrides, so the real peacock badge and perk
// art show (SVGA animation stays off in tests — the still carries the art).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
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
  _Coins(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

const _base = 'https://cdn.kabso.test/vip';
const _colors = [0xFF2E8B3D, 0xFF9B59D0, 0xFFE50914];
const _prices = [1000000, 3000000, 9000000];
const _perkFile = {
  'BADGE': 'vip1_badge.png',
  'AVATAR_FRAME': 'vip1_frame.png',
  'PROFILE_CARD': 'vip1_card.png',
  'ENTRY_BANNER': 'vip1_entrance.png',
  'CHAT_BUBBLE': 'vip1_bubble.png',
  'ENTRY_EFFECT': 'vip1_entry_effect.png',
};

VipPerk _perk(String code, String title) =>
    VipPerk(code: code, title: title, available: false, still: '$_base/${_perkFile[code]}');

VipTier _tier(int level) => VipTier(
  id: 't$level',
  code: 'VIP_$level',
  name: 'VIP $level',
  level: level,
  color: _colors[level - 1],
  priceCoins: _prices[level - 1],
  durationDays: 30,
  badgeStill: level == 1 ? '$_base/vip1_badge.png' : null,
  badgeAnimation: level == 1 ? '$_base/vip1_badge.svga' : null,
  perks: level == 1
      ? [
          _perk('BADGE', 'Badge'),
          _perk('AVATAR_FRAME', 'Avatar frame'),
          _perk('PROFILE_CARD', 'Profile card'),
          _perk('ENTRY_BANNER', 'Entry banner'),
          _perk('CHAT_BUBBLE', 'Message frame'),
          _perk('ENTRY_EFFECT', 'Entry effect'),
        ]
      : const [
          VipPerk(code: 'BADGE', title: 'Badge', available: false),
          VipPerk(code: 'ENTRY_BANNER', title: 'Entry banner', available: false),
        ],
);

VipTierList _list() =>
    VipTierList(tiers: [_tier(1), _tier(2), _tier(3)], maxAheadDays: 400);

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
  _FakeVip({this.membership});

  VipMembership? membership;

  @override
  Future<VipTierList> tiers() async => _list();

  @override
  Future<VipMembership?> mine() async => membership;

  @override
  Future<VipPurchase> buy({
    required String tierId,
    required int priceCoins,
    required String idempotencyKey,
  }) async {
    final tier = _list().tiers.firstWhere((t) => t.id == tierId);
    final m = _membership(tier, days: tier.durationDays);
    membership = m;
    return (kind: VipPurchaseKind.bought, membership: m, coins: 100);
  }
}

// ---- Serve the fixture PNGs to Image.network ---------------------------------

final Map<String, Uint8List> _fixtures = {
  for (final name in {..._perkFile.values, 'vip1_badge.png'})
    name: File('test/fixtures/vip/$name').readAsBytesSync(),
};
late final Uint8List _blank = () {
  // A 1×1 transparent PNG for any unexpected request.
  const b64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  return base64Decode(b64);
}();

class _FixtureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final name = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    return _FakeRequest(_fixtures[name] ?? _blank);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.bytes);

  final Uint8List bytes;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(bytes);

  @override
  void add(List<int> data) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse implements HttpClientResponse {
  _FakeResponse(this.bytes);

  final Uint8List bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;

  @override
  String? value(String name) => null;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  int get contentLength => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _shotKey = Key('shot');

Future<void> _pump(
  WidgetTester tester, {
  required _FakeVip vip,
  int coins = 20000000,
  AppLanguage language = AppLanguage.ar,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const VipScreen()),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const Text('wallet')),
    ],
  );
  await loadAppFonts();
  tester.view
    ..physicalSize = const Size(393, 852) * 3
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
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          locale: language.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(brightness: Brightness.light, locale: language.locale),
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
  setUpAll(() => HttpOverrides.global = _FixtureHttpOverrides());

  // Top priority: the VIP 1 review (Arabic, phone) with the real peacock badge.
  testWidgets('shot vip1 review (ar)', (tester) async {
    await _pump(tester, vip: _FakeVip());
    await _shot(tester, 'vip1_review');
  });

  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    final l = language.name;
    testWidgets('shot not VIP ($l)', (tester) async {
      await _pump(tester, vip: _FakeVip(), language: language);
      await _shot(tester, 'vip_ref_match_not_member_$l');
      await tester.tap(find.byKey(VipScreen.ctaKey));
      await tester.pumpAndSettle();
      await _shot(tester, 'vip_ref_match_confirm_buy_$l');
    });
    testWidgets('shot holder upgrade ($l)', (tester) async {
      await _pump(
        tester,
        vip: _FakeVip(membership: _membership(_tier(1))),
        language: language,
      );
      await _tapTab(tester, 'VIP_3');
      await _shot(tester, 'vip_ref_match_vip3_$l');
    });
  }
}
