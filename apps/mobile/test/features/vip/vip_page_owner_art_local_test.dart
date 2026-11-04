// D258: the «شراء VIP» page with the owner's real VIP 1 SVGA files — a LOCAL
// check only (the files stay out of git). Set VIP_ART_DIR and VIP_SHOTS_DIR;
// without them the tests are skipped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final String? _art = Platform.environment['VIP_ART_DIR'];
final String? _shots = Platform.environment['VIP_SHOTS_DIR'];
bool get _skip => _art == null || !Directory(_art!).existsSync();

String _url(String name) => 'https://cdn.test/owner/vip1_$name.svga';

VipPerk _perk(String code, String title, [String? file]) => VipPerk(
  code: code,
  title: title,
  available: true,
  animation: file == null ? null : _url(file),
);

/// VIP 1 as the owner set it up: the badge and every visual perk's art.
final _list = VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      nameColor: 0xFFFFC928,
      priceCoins: 1000000,
      durationDays: 30,
      renewalDiscountPercent: 15,
      renewPriceCoins: 850000,
      badgeAnimation: _url('badge'),
      perks: [
        _perk('BADGE', 'شارة VIP', 'badge'),
        _perk('AVATAR_FRAME', 'إطار متحرك', 'frame'),
        _perk('CHAT_NAME_COLOR', 'لون الاسم'),
        _perk('ENTRY_BANNER', 'بطاقة الدخول', 'entry_banner'),
        _perk('ENTRY_EFFECT', 'سيارة الدخول', 'car_entry'),
        _perk('MIC_WAVE', 'موجة المايك', 'mic_wave'),
        _perk('CHAT_BUBBLE', 'فقاعة الدردشة', 'chat_bubble'),
        _perk('DAILY_BULLET', '٣ رسائل عامة مجانية'),
        _perk('PROFILE_VISITORS', 'من زار ملفي'),
        const VipPerk(
          code: 'DAILY_COINS',
          title: 'كوينز يومية',
          available: true,
          amount: 500,
        ),
        const VipPerk(
          code: 'LEVEL_SPEEDUP',
          title: 'تسريع المستوى',
          available: true,
          amount: 1,
        ),
        _perk('PROFILE_CARD', 'بطاقة الملف', 'profile_card'),
      ],
    ),
  ],
  maxAheadDays: 400,
);

class _Repo implements VipRepository {
  @override
  Future<VipTierList> tiers() async => _list;

  @override
  Future<VipMembership?> mine() async => null;

  @override
  Future<VipRenewal?> renewal() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 5000000;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    VipSvga.enabled = true;
    VipAnimatedArt.animationsEnabled = true;
    VipSvgaCache.fetch = (url) async =>
        await File('$_art/${url.split('/').last}').readAsBytes();
  });
  tearDown(() {
    VipSvga.enabled = false;
    VipAnimatedArt.animationsEnabled = false;
    VipSvgaCache.clear();
  });

  for (final brightness in Brightness.values) {
    testWidgets('owner art: the VIP page (${brightness.name})', skip: _skip, (
      tester,
    ) async {
      await loadAppFonts();
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final prefs = await testPrefs(language: 'ar');
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const VipScreen())],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
            liveCoinsProvider.overrideWith(_Coins.new),
            vipRepositoryProvider.overrideWithValue(_Repo()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.ar.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: brightness,
              locale: AppLanguage.ar.locale,
            ),
          ),
        ),
      );
      await _settle(tester);
      var render = tester.renderObject(find.byType(VipScreen));
      while (!render.isRepaintBoundary) {
        render = render.parent!;
      }
      final boundary = render;
      await tester.runAsync(() async {
        final layer = boundary.debugLayer! as OffsetLayer;
        final image = await layer.toImage(boundary.paintBounds, pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_shots/vip_page3_ar_${brightness.name}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
