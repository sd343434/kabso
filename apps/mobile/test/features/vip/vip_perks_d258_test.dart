// D258 (owner's VIP 1 perks, contract v1.83-social §10.94): a member's VIP
// on every UserSummary and profile, the tiers' perks inherited, and what a
// member wears — the badge, the name colour, the chat bubble, the animated
// avatar frame and the VIP person card.

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart' show publicProfileJson;
import '../../goldens/live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;
import '../../helpers/golden.dart';

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);
const _vip2 = UserVip(tier: 'VIP_2', rank: 2, color: 0xFF2F6FDB);

VipPerk _perk(
  String code, {
  bool available = true,
  String? still,
  String? animation,
  int? amount,
}) => VipPerk(
  code: code,
  title: code,
  available: available,
  still: still,
  animation: animation,
  amount: amount,
);

VipTier _tier(String code, int level, int color, List<VipPerk> perks) =>
    VipTier(
      // VIP 1's special text colour: the owner's gold (§10.94.10).
      nameColor: code == 'VIP_1' ? 0xFFFFC928 : null,
      id: 'id-$code',
      code: code,
      name: code,
      level: level,
      color: color,
      priceCoins: 1000000 * level,
      durationDays: 30,
      perks: perks,
    );

/// VIP 1 as the owner chose it (the built perks), VIP 2 adding its own.
final VipTierList catalog = VipTierList(
  tiers: [
    _tier('VIP_2', 2, 0xFF2F6FDB, [
      _perk(VipPerks.badge, still: 'https://cdn.test/vip/top_2.png'),
      _perk('MONTHLY_GIFT', available: false),
    ]),
    _tier('VIP_1', 1, 0xFF2E8B3D, [
      _perk(VipPerks.badge),
      _perk(
        VipPerks.avatarFrame,
        still: 'https://cdn.test/vip/top_1.png',
        animation: 'https://cdn.test/vip/frame.svga',
      ),
      _perk(VipPerks.nameColor),
      _perk(VipPerks.bubble),
      _perk(VipPerks.profileCard, still: 'https://cdn.test/vip/card.png'),
      _perk(VipPerks.dailyBullet, available: false, amount: 3),
    ]),
  ],
  maxAheadDays: 400,
);

/// The stand-in art for the hosted URLs (bundled Kabso art).
String _assetFor(String url) {
  final name = url.split('/').last.replaceAll('.png', '');
  if (name.startsWith('top_')) return 'assets/live_top_frames/$name.webp';
  return 'assets/host_frames/host_frame_pink.webp';
}

void main() {
  setUp(() {
    vipImageFor = (url) => AssetImage(_assetFor(url));
  });
  tearDown(() => vipImageFor = NetworkImage.new);

  test('UserVip reads {tier, rank, color}; anything else is no VIP', () {
    expect(
      userVipFromJson({'tier': 'VIP_1', 'rank': 1, 'color': '#2E8B3D'}),
      _vip1,
    );
    expect(userVipToJson(_vip1), {
      'tier': 'VIP_1',
      'rank': 1,
      'color': '#2E8B3D',
    });
    expect(
      userVipFromJson({'tier': 'VIP_1', 'rank': 1, 'color': 'green'}),
      isNull,
    );
    expect(userVipFromJson(null), isNull);
    final summary = UserSummary.fromJson({
      'id': 'u',
      'username': 'u',
      'displayName': 'U',
      'avatarUrl': null,
      'vip': {'tier': 'VIP_2', 'rank': 2, 'color': '#2F6FDB'},
    });
    expect(summary.vip, _vip2);
    expect(
      UserSummary.fromJson({
        'id': 'u',
        'username': 'u',
        'displayName': 'U',
        'avatarUrl': null,
      }).vip,
      isNull,
    );
  });

  test("a tier holds the lower tiers' built perks; its own art wins", () {
    final one = vipLookOf(_vip1, catalog)!;
    expect(one.perks.keys.toSet(), {
      VipPerks.badge,
      VipPerks.avatarFrame,
      VipPerks.nameColor,
      VipPerks.bubble,
      VipPerks.profileCard,
    });
    expect(one.nameColor, vipNameTint(const Color(0xFF2E8B3D)));
    // D268: no BADGE art → no name-badge art (the «VIPn» pill).
    expect(one.nameBadgeArt, isNull);
    final two = vipLookOf(_vip2, catalog)!;
    // VIP 2 holds VIP 1's frame, colour, bubble and card, and its own badge.
    expect(two.has(VipPerks.avatarFrame), isTrue);
    expect(two.nameBadgeArt?.still, 'https://cdn.test/vip/top_2.png');
    expect(two.nameBadgeArt?.aspect, VipLook.nameBadgeTemplateAspect);
    expect(two.level, 2);
    expect(two.has('MONTHLY_GIFT'), isFalse);
    // An unknown tier (off sale) or no catalogue: the colour only.
    final off = vipLookOf(
      const UserVip(tier: 'OLD', rank: 9, color: 0xFFAA0000),
      catalog,
    )!;
    expect(off.perks, isEmpty);
    expect(off.tier, isNull);
    expect(vipLookOf(null, catalog), isNull);
    // The bubble: the tier colour without art; null without the perk.
    expect(vipBubbleDecoration(one, radius: 12)?.gradient, isNotNull);
    expect(vipBubbleDecoration(off, radius: 12), isNull);
  });

  Future<void> pumpLine(
    WidgetTester tester, {
    required AppLanguage language,
    UserVip? vip,
    GoldenViewport viewport = GoldenViewport.phone,
    double textScale = 1,
  }) async {
    await pumpGolden(
      tester,
      viewport: viewport,
      MediaQuery(
        data: MediaQueryData(
          size: viewport.logicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: ProviderScope(
          overrides: [vipCatalogProvider.overrideWith((ref) async => catalog)],
          child: ColoredBox(
            color: const Color(0xFF3A4150),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiveChatFlatLine(
                      name: language == AppLanguage.ar ? 'ليلى' : 'Layla',
                      text: language == AppLanguage.ar
                          ? 'مرحباً بالجميع'
                          : 'Hello everyone',
                      label: 'line',
                      role: LiveChatRole.viewer,
                      vip: vip,
                      // The owner's three lines: levels, medals, message.
                      badges: const LiveChatAuthorBadges(
                        charmLevel: 12,
                        supportLevel: 32,
                        medals: [
                          LiveChatAuthorMedal(
                            code: 'm1',
                            iconKey: 'medal_first_family',
                          ),
                          LiveChatAuthorMedal(
                            code: 'm2',
                            iconKey: 'medal_first_family',
                          ),
                          LiveChatAuthorMedal(
                            code: 'm3',
                            iconKey: 'medal_first_family',
                          ),
                          // D269: up to 5, on line 2.
                          LiveChatAuthorMedal(
                            code: 'm4',
                            iconKey: 'medal_first_family',
                          ),
                          LiveChatAuthorMedal(
                            code: 'm5',
                            iconKey: 'medal_first_family',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    LiveChatFlatLine(
                      name: language == AppLanguage.ar ? 'سامي' : 'Sami',
                      text: language == AppLanguage.ar ? 'أهلاً' : 'Hi',
                      label: 'line',
                      role: LiveChatRole.viewer,
                      vip: _vip2,
                    ),
                    const SizedBox(height: 6),
                    LiveChatFlatLine(
                      name: language == AppLanguage.ar ? 'منى' : 'Mona',
                      text: language == AppLanguage.ar ? 'بدون VIP' : 'No VIP',
                      label: 'line',
                      role: LiveChatRole.viewer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      language: language,
      bare: true,
    );
    await tester.pump();
    await tester.pump();
    await precacheImages(tester);
  }

  testWidgets('the chat line: the badge first, the name colour, the bubble', (
    tester,
  ) async {
    await pumpLine(tester, language: AppLanguage.en, vip: _vip1);
    expect(find.byKey(VipNameBadge.badgeKey), findsNWidgets(2));
    expect(find.text('VIP1'), findsOneWidget);
    expect(find.byKey(KFlatChat.vipBubbleKey), findsNWidgets(2));
    final name = tester.widget<Text>(find.text(KFormat.bidiIsolate('Layla')));
    expect(name.style?.color, vipNameTint(const Color(0xFF2E8B3D)));
    final plain = tester.widget<Text>(find.text(KFormat.bidiIsolate('Mona')));
    expect(plain.style?.color, KFlatChat.name);
  });

  forEachLanguage((language) {
    testWidgets('golden vip.chat_line ($language)', (tester) async {
      await pumpLine(tester, language: language, vip: _vip1);
      await expectScreenGolden('vip.chat_line', language: language);
    });

    testWidgets('golden vip.chat_line 360 × 1.3 ($language)', (tester) async {
      await pumpLine(
        tester,
        language: language,
        vip: _vip1,
        viewport: GoldenViewport.android,
        textScale: 1.3,
      );
      await expectScreenGolden(
        'vip.chat_line.scaled',
        language: language,
        viewport: GoldenViewport.android,
      );
    });

    testWidgets('golden vip.person_card ($language)', (tester) async {
      final profile = personCardProfile(ar: language == AppLanguage.ar)
          .copyWith(vip: _vip1);
      await pumpPersonCardRoom(
        tester,
        language: language,
        profile: profile,
        extraOverrides: [
          vipCatalogProvider.overrideWith((ref) async => catalog),
        ],
      );
      expect(find.byKey(LivePersonSheet.vipCardKey), findsOneWidget);
      expect(find.byKey(VipAvatarFrame.frameKey), findsWidgets);
      expect(find.byKey(VipNameBadge.badgeKey), findsWidgets);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/vip.person_card.${language.name}.phone.png'),
      );
    });
  });

  testWidgets('the VIP badge and the levels (line 1) and the medals (line '
      '2, D269) show at one visible height (within 1 pt)', (tester) async {
    await pumpLine(tester, language: AppLanguage.en, vip: _vip1);
    final header = find.byKey(LiveChatFlatLine.vipHeaderKey).first;
    var render = tester.renderObject(header);
    while (!render.isRepaintBoundary) {
      render = render.parent!;
    }
    final boundary = render;
    final origin = (boundary as RenderBox).localToGlobal(Offset.zero);
    final image = await tester.runAsync(() async {
      final layer = boundary.debugLayer! as OffsetLayer;
      final img = await layer.toImage(boundary.paintBounds);
      return (await img.toByteData())!;
    });
    final w = boundary.paintBounds.width.round();
    // The visible rows of [rect]: pixels unlike the backdrop (#3A4150).
    double visible(Rect rect, {double above = 8}) {
      // (Some emblems draw beyond their box, e.g. the charm creature.)
      final r = Rect.fromLTRB(
        rect.left,
        rect.top - above,
        rect.right,
        rect.bottom + 1,
      ).shift(-origin);
      int? top;
      int? bottom;
      for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
        for (var x = r.left.ceil(); x < r.right.floor(); x++) {
          final i = (y * w + x) * 4;
          final d =
              (image!.getUint8(i) - 0x3A).abs() +
              (image.getUint8(i + 1) - 0x41).abs() +
              (image.getUint8(i + 2) - 0x50).abs();
          if (d > 60) {
            top ??= y;
            bottom = y;
            break;
          }
        }
      }
      return top == null ? 0 : (bottom! - top + 1).toDouble();
    }

    final vipH = visible(
      tester.getRect(
        find.descendant(
          of: header,
          matching: find.byKey(VipNameBadge.badgeKey),
        ),
      ),
    );
    // D269: the medals on line 2, at the same height.
    // (Its own rows only: line 1 is just above it.)
    final medalH = visible(
      tester.getRect(find.byKey(LiveChatMedalRow.medalKey('m1')).first),
      above: 0,
    );
    final charmH = visible(
      tester.getRect(
        find.descendant(of: header, matching: find.byType(CharmLevelBadge)),
      ),
    );
    final supportH = visible(
      tester.getRect(
        find.descendant(of: header, matching: find.byType(KLevelBadge)),
      ),
    );
    expect(vipH, greaterThan(18));
    expect((vipH - charmH).abs(), lessThanOrEqualTo(1), reason: 'charm');
    expect((vipH - supportH).abs(), lessThanOrEqualTo(1), reason: 'support');
    expect((vipH - medalH).abs(), lessThanOrEqualTo(1), reason: 'medal');
  });

  for (final language in [AppLanguage.en, AppLanguage.ar]) {
    testWidgets('D268: the VIP badge comes right after the name, before '
        'the levels (${language.name})', (tester) async {
      await pumpLine(tester, language: language, vip: _vip1);
      final header = find.byKey(LiveChatFlatLine.vipHeaderKey).first;
      final name = tester.getRect(
        find.descendant(of: header, matching: find.byType(Text)).first,
      );
      final badge = tester.getRect(
        find.descendant(
          of: header,
          matching: find.byKey(VipNameBadge.badgeKey),
        ),
      );
      final charm = tester.getRect(
        find.descendant(of: header, matching: find.byType(CharmLevelBadge)),
      );
      if (language == AppLanguage.ar) {
        expect(badge.right, lessThanOrEqualTo(name.left));
        expect(charm.right, lessThanOrEqualTo(badge.left));
      } else {
        expect(badge.left, greaterThanOrEqualTo(name.right));
        expect(charm.left, greaterThanOrEqualTo(badge.right));
      }
      // D269: the medals on line 2 (none in line 1), the message on line 3.
      expect(
        find.descendant(of: header, matching: find.byType(MedalIcon)),
        findsNothing,
      );
      final medals = tester.getRect(find.byKey(LiveChatMedalRow.rowKey).first);
      final bubble = tester.getRect(find.byKey(KFlatChat.vipBubbleKey).first);
      expect(medals.top, greaterThanOrEqualTo(tester.getRect(header).bottom));
      expect(bubble.top, greaterThanOrEqualTo(medals.bottom));
      expect(find.byType(MedalIcon), findsNWidgets(5));
    });
  }

  testWidgets("D268: the BADGE perk's art is a wide pill at its own ratio, "
      "never the tier's medal", (tester) async {
    const wide = VipTierList(
      tiers: [
        VipTier(
          id: 'id-VIP_1',
          code: 'VIP_1',
          name: 'VIP 1',
          level: 1,
          color: 0xFF2E8B3D,
          badgeStill: 'https://cdn.test/vip/medal.png',
          priceCoins: 1,
          durationDays: 30,
          perks: [
            VipPerk(
              code: VipPerks.badge,
              title: 'b',
              available: true,
              still: 'https://cdn.test/vip/name_badge.png',
              artWidth: 1943,
              artHeight: 634,
            ),
          ],
        ),
      ],
      maxAheadDays: 400,
    );
    expect(
      vipLookOf(_vip1, wide)!.nameBadgeArt?.still,
      'https://cdn.test/vip/name_badge.png',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vipCatalogProvider.overrideWith((ref) async => wide)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: VipNameBadge(vip: _vip1, height: 22)),
        ),
      ),
    );
    await tester.pump();
    final size = tester.getSize(find.byKey(VipNameBadge.badgeKey));
    expect(size.height, 22);
    expect(size.width, closeTo(22 * 1943 / 634, 0.01));
    // Only the tier's medal: no name-badge art (the «VIPn» pill).
    const medalOnly = VipTierList(
      tiers: [
        VipTier(
          id: 'id-VIP_1',
          code: 'VIP_1',
          name: 'VIP 1',
          level: 1,
          color: 0xFF2E8B3D,
          badgeStill: 'https://cdn.test/vip/medal.png',
          priceCoins: 1,
          durationDays: 30,
          perks: [VipPerk(code: VipPerks.badge, title: 'b', available: true)],
        ),
      ],
      maxAheadDays: 400,
    );
    expect(vipLookOf(_vip1, medalOnly)!.nameBadgeArt, isNull);
  });

  test('a VIP name stays ≥ 4.5:1 on its bubble and the chat box', () {
    // The owner's tier colours and the edge cases (white, black, yellow).
    const colours = [
      0xFF2E7D32, 0xFF1E88E5, 0xFFD4AF37, 0xFFE91E63, 0xFF7B1FA2, //
      0xFFFFFFFF, 0xFF000000, 0xFFFFEB3B, 0xFF00E5FF, 0xFFFF6D00,
    ];
    for (final c in colours) {
      final name = vipNameTint(Color(c));
      final (top, bottom) = vipBubbleShades(Color(c));
      for (final bubble in [
        top,
        bottom,
        const Color(0xFF000000),
        // Under the owner's animated bubble (its inside's veil).
        Color.alphaBlend(vipBubbleArtVeil, top),
        Color.alphaBlend(vipBubbleArtVeil, bottom),
      ]) {
        expect(
          vipContrast(name, bubble),
          greaterThanOrEqualTo(4.5),
          reason: 'name of ${c.toRadixString(16)} on $bubble',
        );
        expect(
          vipContrast(const Color(0xFFFFFFFF), bubble),
          greaterThanOrEqualTo(4.5),
          reason: 'text on the bubble of ${c.toRadixString(16)}',
        );
      }
    }
  });

  test('a profile reads its VIP', () {
    final json = Map<String, dynamic>.of(publicProfileJson())
      ..['vip'] = {'tier': 'VIP_1', 'rank': 1, 'color': '#2E8B3D'};
    expect(PublicProfile.fromJson(json).vip, _vip1);
    expect(PublicProfile.fromJson(publicProfileJson()).vip, isNull);
  });
}
