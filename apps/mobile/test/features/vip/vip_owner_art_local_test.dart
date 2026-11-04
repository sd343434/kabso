// D258: the owner's real VIP 1 SVGA files drawn by the app's SVGA engine —
// a LOCAL check only. The files (0.8–3.7 MB each) stay out of git: set
// VIP_ART_DIR to their folder and VIP_SHOTS_DIR to where the PNGs go; without
// them every test here is skipped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

import '../../goldens/live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;
import '../../helpers/golden.dart';

final String? _art = Platform.environment['VIP_ART_DIR'];
final String? _shots = Platform.environment['VIP_SHOTS_DIR'];
bool get _skip => _art == null || !Directory(_art!).existsSync();

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

String _url(String name) => 'https://cdn.test/owner/vip1_$name.svga';

VipPerk _perk(String code, String? file) => VipPerk(
  code: code,
  title: code,
  available: true,
  animation: file == null ? null : _url(file),
);

final _catalog = VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        _perk(VipPerks.badge, 'badge'),
        _perk(VipPerks.avatarFrame, 'frame'),
        _perk(VipPerks.nameColor, null),
        _perk(VipPerks.bubble, 'chat_bubble'),
        _perk(VipPerks.profileCard, 'profile_card'),
        _perk(VipPerks.entryBanner, 'entry_banner'),
      ],
    ),
  ],
  maxAheadDays: 400,
);

/// Lets the real decoding (outside fake time) finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _save(WidgetTester tester, Finder finder, String name) async {
  var render = tester.renderObject(finder);
  while (!render.isRepaintBoundary) {
    render = render.parent!;
  }
  final boundary = render;
  await tester.runAsync(() async {
    final layer = boundary.debugLayer! as OffsetLayer;
    final image = await layer.toImage(boundary.paintBounds, pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shots/$name').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUp(() {
    VipSvga.enabled = true;
    VipAnimatedArt.animationsEnabled = true;
    VipSvgaCache.fetch = (url) async {
      final file = url.split('/').last;
      return await File('$_art/$file').readAsBytes();
    };
  });
  tearDown(() {
    VipSvga.enabled = false;
    VipAnimatedArt.animationsEnabled = false;
    VipSvgaCache.clear();
  });

  testWidgets('owner art: the chat line (badge + bubble)', skip: _skip, (
    tester,
  ) async {
    await pumpGolden(
      tester,
      ProviderScope(
        overrides: [vipCatalogProvider.overrideWith((ref) async => _catalog)],
        child: const ColoredBox(
          color: Color(0xFF3A4150),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveChatFlatLine(
                    name: 'ليلى',
                    text: 'مرحباً بالجميع',
                    label: 'line',
                    role: LiveChatRole.viewer,
                    vip: _vip1,
                  ),
                  SizedBox(height: 14),
                  LiveChatFlatLine(
                    name: 'ليلى',
                    text: 'أهلاً وسهلاً بكل الحاضرين في البث الليلة',
                    label: 'line',
                    role: LiveChatRole.viewer,
                    vip: _vip1,
                  ),
                  SizedBox(height: 14),
                  LiveChatFlatLine(
                    name: 'منى',
                    text: 'بدون VIP',
                    label: 'line',
                    role: LiveChatRole.viewer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      language: AppLanguage.ar,
      bare: true,
    );
    await _settle(tester);
    await _save(tester, find.byType(ProviderScope).first, 'chat_owner_ar.png');
  });

  for (final language in AppLanguage.values) {
    testWidgets('owner art: the entry banner (${language.name})', skip: _skip, (
      tester,
    ) async {
      final look = vipLookOf(_vip1, _catalog)!;
      final ar = language == AppLanguage.ar;
      await pumpGolden(
        tester,
        ProviderScope(
          child: ColoredBox(
            color: const Color(0xFF3A4150),
            child: Center(
              child: VipEntranceBanner(
                name: ar ? 'ابو الهول الكبير' : 'Layla',
                look: look,
                perk: look.perk(VipPerks.entryBanner)!,
              ),
            ),
          ),
        ),
        language: language,
        bare: true,
      );
      await _settle(tester);
      await _save(
        tester,
        find.byType(ProviderScope).first,
        'entrance_owner_${language.name}.png',
      );
    });
  }

  testWidgets(
    'owner art: the person card (card + frame + badge)',
    skip: _skip,
    (tester) async {
      await pumpPersonCardRoom(
        tester,
        language: AppLanguage.ar,
        profile: personCardProfile(ar: true).copyWith(vip: _vip1),
        extraOverrides: [
          vipCatalogProvider.overrideWith((ref) async => _catalog),
        ],
      );
      await _settle(tester);
      await _save(tester, find.byType(MaterialApp), 'card_owner_ar.png');
    },
  );
}
