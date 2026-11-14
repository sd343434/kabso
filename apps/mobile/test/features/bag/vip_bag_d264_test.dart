// D264 (owner: «عند تفعيل VIP تظهر العناصر في الحقيبة … المدة تنقضي وتعد»;
// contract v1.65-live, CONVENTIONS §10.97): a VIP member's tier items in the
// bag — each in its category with the VIP token, «من عضوية VIP 1», the
// membership's time left, never sent; worn by default, taken off and worn
// again like any item; the VIP-only slots only while owned. `UserVip.off`
// leaves the taken-off perks out of the look. Goldens ar / en at 393×852.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/bag_screen.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';

/// "Now" in these tests: 09:00 local.
final DateTime _now = DateTime(2026, 11, 4, 9);

/// The membership: bought 3 days ago, 27 days and 5 hours left.
final DateTime _start = _now.subtract(const Duration(days: 3));
final DateTime _end = _now.add(const Duration(days: 27, hours: 5));

const _perks = <(String, String, String, String)>[
  // (perk, category, ar, en)
  ('AVATAR_FRAME', 'AVATAR_FRAME', 'إطار الصورة', 'Avatar frame'),
  ('PROFILE_CARD', 'PROFILE_CARD', 'إطار البطاقة', 'Profile card'),
  ('CHAT_BUBBLE', 'CHAT_BUBBLE', 'إطار الرسائل', 'Message frame'),
  ('ENTRY_BANNER', 'ENTRY_BANNER', 'لافتة الدخول', 'Entry banner'),
  ('ENTRY_EFFECT', 'ENTRY_EFFECT', 'مؤثر الدخول', 'Entry effect'),
  ('MIC_WAVE', 'MIC_WAVE', 'موجة المايك', 'Mic wave'),
];

/// The owner's uploaded stills, faked with bundled pictures (tests draw
/// the still; the SVGA engine is off).
const _fakeArt = {
  'AVATAR_FRAME': 'assets/host_frames/host_frame_pink.webp',
  'PROFILE_CARD': 'assets/card_boxes/family.webp',
  'CHAT_BUBBLE': 'assets/live_bar/chat.png',
  'ENTRY_BANNER': 'assets/win_frames/win_frame_ruby.png',
  'ENTRY_EFFECT': 'assets/live_top_frames/top_1.webp',
  'MIC_WAVE': 'assets/win_frames/win_frame_sapphire.png',
};

String _stillUrl(String perk) => 'https://media.example.test/vip/$perk.png';

ImageProvider _fakeImage(String url) {
  final perk = url.split('/').last.replaceAll('.png', '');
  return AssetImage(_fakeArt[perk] ?? 'assets/live_bar/gift.png');
}

/// A VIP item shaped like `GET /me/bag` (v1.65-live), with the perk's art
/// (an SVGA and its still) unless [art] is false.
Map<String, Object?> _vipItem(
  (String, String, String, String) p, {
  required bool ar,
  bool equipped = true,
  bool art = true,
  bool still = true,
}) => {
  'code': 'vip:${p.$1}',
  'category': p.$2,
  'name': ar ? p.$3 : p.$4,
  'assetKey': 'vip_${p.$1.toLowerCase()}',
  'acquiredAt': _start.toUtc().toIso8601String(),
  'source': 'VIP',
  'equipped': equipped,
  'expiresAt': _end.toUtc().toIso8601String(),
  'giftedBy': null,
  'transferable': false,
  'vip': {
    'tier': 'VIP_1',
    'tierName': ar ? 'في آي بي 1' : 'VIP 1',
    'color': '#2E8B3D',
    'perk': p.$1,
    'animation': art
        ? 'https://media.example.test/vip/${p.$1.toLowerCase()}.svga'
        : null,
    'still': art && still ? _stillUrl(p.$1) : null,
  },
};

/// The bag as the server lists it: the VIP card (worn) before the free card
/// it replaced, the VIP frame (worn) before a support frame, then the
/// VIP-only categories — one worn item per kind.
List<Map<String, Object?>> _items({
  required bool ar,
  Set<String> off = const {},
}) => [
  _vipItem(_perks[1], ar: ar, equipped: !off.contains('PROFILE_CARD')),
  bagItemJson('bunny_royal', ar: ar, source: 'FREE_SIGNUP'),
  _vipItem(_perks[0], ar: ar, equipped: !off.contains('AVATAR_FRAME')),
  bagItemJson(
    'support_frame_03',
    ar: ar,
    category: 'AVATAR_FRAME',
    source: 'LEVEL_REWARD',
    assetKey: 'support_frame_03',
    transferable: false,
  )..['name'] = ar ? 'إطار الدعم 3' : 'Support frame 3',
  for (final p in _perks.skip(2))
    _vipItem(p, ar: ar, equipped: !off.contains(p.$1)),
];

/// A bag whose worn item is kept per category (as the server does).
class _VipBag implements BagRepository {
  new(this.items);

  final List<Map<String, Object?>> items;
  final List<String> calls = [];

  @override
  Future<List<BagItem>> myBag({BagCategory? category}) async {
    calls.add('myBag');
    return [for (final i in items) BagItem.fromJson(i)];
  }

  @override
  Future<BagEquipped> setEquipped(String category, String? code) async {
    calls.add('setEquipped:$category:${code ?? 'null'}');
    Map<String, Object?>? worn;
    for (var n = 0; n < items.length; n++) {
      final i = items[n];
      if (i['category'] != category) continue;
      final on = i['code'] == code;
      items[n] = {...i, 'equipped': on};
      if (on) worn = items[n];
    }
    return BagEquipped.fromJson({
      'category': category,
      'equipped': worn == null
          ? null
          : {
              'code': worn['code'],
              'name': worn['name'],
              'assetKey': worn['assetKey'],
            },
    });
  }

  @override
  Future<HostFrame> hostFrame() async => HostFrame.fromJson(const {
    'agencyHost': false,
    'active': false,
    'liveDays': 0,
    'liveSeconds': 0,
    'style': null,
    'styleFrom': null,
    'canChoose': false,
    'frame': null,
  });

  @override
  Future<List<BagCatalogueItem>> catalogue({BagCategory? category}) =>
      throw UnimplementedError();

  @override
  Future<BagTransfer> send({
    required String code,
    required String username,
    int? days,
  }) => throw UnimplementedError();

  @override
  Future<HostFrame> setHostFrameStyle(HostFrameStyle style) =>
      throw UnimplementedError();
}

Future<_VipBag> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<Map<String, Object?>>? items,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  final bag = _VipBag(items ?? _items(ar: language == AppLanguage.ar));
  await pumpBonds(
    tester,
    const BagScreen(),
    language: language,
    brightness: Brightness.light,
    overrides: [
      bagRepositoryProvider.overrideWithValue(bag),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(isSelf: true)),
      ),
    ],
  );
  return bag;
}

Future<void> _tab(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String code) async {
  final list = find
      .descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(Scrollable),
      )
      .first;
  // From the top each time (the list scrolls one way).
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(BagScreen.itemKey(code)),
    200,
    scrollable: list,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(BagScreen.itemKey(code)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  // D383: the header ornaments are hidden pending the owner's decision; these
  // tests cover the dormant feature, shown again.
  setUp(() => kabsoProfileHeadersHidden = false);
  tearDown(() => kabsoProfileHeadersHidden = true);
  setUp(() => vipImageFor = _fakeImage);
  tearDown(() => vipImageFor = NetworkImage.new);

  group('UserVip.off (v1.65-live)', () {
    test('read and written; absent = nothing taken off', () {
      final vip = userVipFromJson({
        'tier': 'VIP_1',
        'rank': 1,
        'color': '#2E8B3D',
        'off': ['CHAT_BUBBLE', 'MIC_WAVE'],
      })!;
      expect(vip.off, {'CHAT_BUBBLE', 'MIC_WAVE'});
      expect(
        userVipToJson(vip)!['off'],
        unorderedEquals(['CHAT_BUBBLE', 'MIC_WAVE']),
      );
      final plain = userVipFromJson({
        'tier': 'VIP_1',
        'rank': 1,
        'color': '#2E8B3D',
      })!;
      expect(plain.off, isEmpty);
      expect(userVipToJson(plain)!.containsKey('off'), isFalse);
      expect(vip == plain, isFalse);
    });

    test('the look leaves the taken-off perks out', () {
      VipPerk perk(String code) =>
          VipPerk(code: code, title: code, available: true);
      final catalog = VipTierList(
        tiers: [
          VipTier(
            id: 't1',
            code: 'VIP_1',
            name: 'VIP 1',
            level: 1,
            color: 0xFF2E8B3D,
            priceCoins: 1000000,
            durationDays: 30,
            perks: [
              for (final c in [
                'BADGE',
                'AVATAR_FRAME',
                'PROFILE_CARD',
                'CHAT_BUBBLE',
                'MIC_WAVE',
              ])
                perk(c),
            ],
          ),
        ],
        maxAheadDays: 400,
      );
      const off = UserVip(
        tier: 'VIP_1',
        rank: 1,
        color: 0xFF2E8B3D,
        off: {'CHAT_BUBBLE', 'MIC_WAVE'},
      );
      final look = vipLookOf(off, catalog)!;
      expect(look.has(VipPerks.badge), isTrue);
      expect(look.has(VipPerks.avatarFrame), isTrue);
      expect(look.has(VipPerks.bubble), isFalse);
      expect(look.has(VipPerks.micWave), isFalse);
      final all = vipLookOf(
        const UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D),
        catalog,
      )!;
      expect(all.has(VipPerks.bubble), isTrue);
      expect(all.has(VipPerks.profileCard), isTrue);
      // A card worn from the bag: the server lists the VIP card in `off`,
      // so the person card draws one card, never both.
      final card = vipLookOf(
        const UserVip(
          tier: 'VIP_1',
          rank: 1,
          color: 0xFF2E8B3D,
          off: {'PROFILE_CARD', 'AVATAR_FRAME'},
        ),
        catalog,
      )!;
      expect(card.has(VipPerks.profileCard), isFalse);
      expect(card.has(VipPerks.avatarFrame), isFalse);
      expect(card.has(VipPerks.bubble), isTrue);
    });
  });

  testWidgets('the VIP items: their categories, the time left, worn', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester, viewport: GoldenViewport.android);
      // «قيد الاستخدام»: a slot for each VIP category the member has, the
      // VIP frame in the frame slot.
      for (final c in ['PROFILE_CARD', 'AVATAR_FRAME', 'CHAT_BUBBLE']) {
        expect(find.byKey(BagScreen.slotKey(c)), findsOneWidget, reason: c);
      }
      await _tab(tester, BagScreen.itemsTabKey);
      for (final p in _perks) {
        await _select(tester, 'vip:${p.$1}');
        expect(find.byKey(BagScreen.wornKey('vip:${p.$1}')), findsOneWidget);
        expect(
          find.byKey(VipBagItemPreview.keyOf('vip:${p.$1}')),
          findsWidgets,
        );
        // The membership's time, counting down.
        expect(_text(tester, BagScreen.timeKey('vip:${p.$1}')), '27 days');
        expect(
          _text(tester, BagScreen.selectedSourceKey),
          'From your VIP 1 membership',
        );
        // Never sent: no «إرسال» at all, only wear / take off.
        expect(find.byKey(BagScreen.sendKey), findsNothing);
        expect(find.byKey(BagScreen.noSendKey), findsNothing);
        expect(find.byKey(BagScreen.takeOffKey), findsOneWidget);
        // The bottom bar shows the item itself (its art, not the token).
        final bar = find.byKey(BagScreen.selectedPreviewKey);
        expect(
          find.descendant(
            of: bar,
            matching: find.byKey(VipBagItemPreview.keyOf('vip:${p.$1}')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.byType(Image)),
          findsOneWidget,
        );
      }
      // Every tile draws the uploaded art, never the «VIP» token.
      expect(find.text('VIP'), findsNothing);
      // Owner: «تميز عنصر في اي بي» — each VIP tile (and the bar's picture)
      // carries the tier's «VIP1» badge and its tier-coloured edge; the
      // stored items do not.
      for (final p in _perks) {
        final tile = find.byKey(BagScreen.itemKey('vip:${p.$1}'));
        if (tile.evaluate().isEmpty) continue;
        expect(
          find.descendant(
            of: tile,
            matching: find.byKey(VipBagItemPreview.markKey('vip:${p.$1}')),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(BagScreen.selectedPreviewKey),
          matching: find.text('VIP1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(BagScreen.itemKey('support_frame_03')),
          matching: find.text('VIP1'),
        ),
        findsNothing,
      );
      expect(vipTierBadgeLabel('VIP_12'), 'VIP12');
      expect(find.text('Entry effects'), findsWidgets);
      // One worn item per kind: the free card and the support frame are not
      // worn while the VIP card and frame are.
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsNothing);
      expect(find.byKey(BagScreen.wornKey('support_frame_03')), findsNothing);
    });
    // A day later: one day less.
    await withClock(Clock.fixed(_now.add(const Duration(days: 1))), () async {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, viewport: GoldenViewport.android);
      await _tab(tester, BagScreen.itemsTabKey);
      await _select(tester, 'vip:MIC_WAVE');
      expect(_text(tester, BagScreen.timeKey('vip:MIC_WAVE')), '26 days');
    });
  });

  testWidgets('take off and wear again; send stays off', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      final bag = await _pump(tester, viewport: GoldenViewport.android);
      await _tab(tester, BagScreen.itemsTabKey);
      await _select(tester, 'vip:CHAT_BUBBLE');
      expect(find.byKey(BagScreen.sendKey), findsNothing);
      await tester.tap(find.byKey(BagScreen.takeOffKey));
      await tester.pumpAndSettle();
      expect(bag.calls, contains('setEquipped:CHAT_BUBBLE:null'));
      expect(find.byKey(BagScreen.wornKey('vip:CHAT_BUBBLE')), findsNothing);
      // Still listed, still counting down.
      expect(_text(tester, BagScreen.timeKey('vip:CHAT_BUBBLE')), '27 days');
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(bag.calls, contains('setEquipped:CHAT_BUBBLE:vip:CHAT_BUBBLE'));
      expect(find.byKey(BagScreen.wornKey('vip:CHAT_BUBBLE')), findsOneWidget);

      // The frame: wearing the support frame takes the VIP frame off.
      await _select(tester, 'support_frame_03');
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(bag.calls, contains('setEquipped:AVATAR_FRAME:support_frame_03'));
      expect(find.byKey(BagScreen.wornKey('support_frame_03')), findsOneWidget);
      expect(find.byKey(BagScreen.wornKey('vip:AVATAR_FRAME')), findsNothing);

      // The card: wearing the free card takes the VIP card off, and back.
      await _select(tester, 'bunny_royal');
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(bag.calls, contains('setEquipped:PROFILE_CARD:bunny_royal'));
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsOneWidget);
      expect(find.byKey(BagScreen.wornKey('vip:PROFILE_CARD')), findsNothing);
      await _select(tester, 'vip:PROFILE_CARD');
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(find.byKey(BagScreen.wornKey('vip:PROFILE_CARD')), findsOneWidget);
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsNothing);
    });
  });

  testWidgets('no VIP: no VIP slots (only the profile card and the frame)', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(
        tester,
        viewport: GoldenViewport.android,
        items: [bagItemJson('bunny_royal', ar: false, source: 'FREE_SIGNUP')],
      );
      expect(find.byKey(BagScreen.slotKey('PROFILE_CARD')), findsOneWidget);
      expect(find.byKey(BagScreen.slotKey('AVATAR_FRAME')), findsOneWidget);
      for (final c in [
        'CHAT_BUBBLE',
        'ENTRY_BANNER',
        'ENTRY_EFFECT',
        'MIC_WAVE',
      ]) {
        expect(find.byKey(BagScreen.slotKey(c)), findsNothing, reason: c);
      }
    });
  });

  testWidgets('only the animation uploaded: the SVGA plays (its first '
      'frame with reduced motion), never the token; no art: the token', (
    tester,
  ) async {
    VipSvga.enabled = true;
    VipAnimatedArt.animationsEnabled = true;
    final fetch = VipSvgaCache.fetch;
    VipSvgaCache.fetch = (_) async => throw StateError('offline in tests');
    addTearDown(() {
      VipSvga.enabled = false;
      VipAnimatedArt.animationsEnabled = false;
      VipSvgaCache.fetch = fetch;
    });
    await withClock(Clock.fixed(_now), () async {
      await _pump(
        tester,
        viewport: GoldenViewport.android,
        items: [
          _vipItem(_perks[0], ar: false, still: false),
          _vipItem(_perks[2], ar: false, art: false),
        ],
      );
      await _tab(tester, BagScreen.itemsTabKey);
      final svga = find.byKey(VipBagItemPreview.svgaKey('vip:AVATAR_FRAME'));
      expect(svga, findsOneWidget);
      // No still to fall back on: the clip's own frames (not the token).
      expect(tester.widget<VipSvga>(svga).still, isNull);
      expect(
        find.descendant(
          of: find.byKey(BagScreen.itemKey('vip:AVATAR_FRAME')),
          matching: find.text('VIP'),
        ),
        findsNothing,
      );
      // An item with no art at all keeps the token.
      expect(
        find.descendant(
          of: find.byKey(BagScreen.itemKey('vip:CHAT_BUBBLE')),
          matching: find.text('VIP'),
        ),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('bag_vip_items (${language.name})', (tester) async {
        await loadAppFonts();
        WidgetsApp.debugAllowBannerOverride = false;
        addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
        await withClock(Clock.fixed(_now), () async {
          await _pump(
            tester,
            language: language,
            items: _items(
              ar: language == AppLanguage.ar,
              off: const {'MIC_WAVE'},
            ),
          );
          await _tab(tester, BagScreen.itemsTabKey);
          await tester.tap(find.byKey(BagScreen.itemKey('vip:PROFILE_CARD')));
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/png/bag_vip_items.${language.name}.phone.png',
            ),
          );
        });
      }, tags: goldenTag);
    }
  });
}
