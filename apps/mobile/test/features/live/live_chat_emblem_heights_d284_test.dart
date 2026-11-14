// D284 (owner, on the audio room's chat: «ايقونة الجديد اجعلها بنفس مقاس
// باقي الايقونات، حاول توحيد الايقونات بالحجم»): on every chat line the
// «جديد» tag, the role tags, the VIP badge, the family and the level
// emblems' bars are one visible height (within 1 pt), and the emblems' art
// is one height — in the audio / podcast boxed lines, the video rows, the
// host's flat line and the VIP layout. The Kabso Team badge stays taller
// (D282b).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_text.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// A VIP 1 member: the badge with no art (the «VIP1» pill), no bubble.
const _vip = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

/// A VIP 2 member with the chat bubble: the VIP layout (D265 / D269).
const _vipBubble = UserVip(tier: 'VIP_2', rank: 2, color: 0xFF2E5BFF);

VipTier _tier(int level, {bool bubble = false}) => VipTier(
  id: 'id-VIP_$level',
  code: 'VIP_$level',
  name: 'VIP $level',
  level: level,
  color: 0xFF2E8B3D,
  nameColor: 0xFFFFC928,
  priceCoins: 1000000,
  durationDays: 30,
  perks: [
    const VipPerk(code: VipPerks.badge, title: 'badge', available: true),
    const VipPerk(code: VipPerks.nameColor, title: 'name', available: true),
    if (bubble)
      const VipPerk(code: VipPerks.bubble, title: 'bubble', available: true),
  ],
);

final _catalog = VipTierList(
  tiers: [_tier(1), _tier(2, bubble: true)],
  maxAheadDays: 400,
);

const _badges = LiveChatAuthorBadges(
  charmLevel: 17,
  supportLevel: 12,
  family: LiveChatAuthorFamily(name: 'black', level: 7),
  newcomer: true,
);

Future<void> _pump(WidgetTester tester, Widget line) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    ColoredBox(
      color: const Color(0xFF22303F),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(width: 380, child: line),
      ),
    ),
    language: AppLanguage.ar,
    overrides: [vipCatalogProvider.overrideWith((ref) async => _catalog)],
  );
  await tester.pump();
  await tester.pump();
}

/// The visible bars of the line's tags and level emblems.
Map<String, double> _bars(
  WidgetTester tester, {
  Key roleKey = LiveChatBadgeRow.roleKey,
}) {
  double h(Finder f) => tester.getSize(f).height;
  final charm = find.descendant(
    of: find.byType(CharmLevelBadge),
    matching: find.byType(Container),
  );
  final support = find.descendant(
    of: find.byType(KLevelBadge),
    matching: find.byType(Image),
  );
  return {
    'role': h(find.byKey(roleKey)),
    'newcomer': h(find.byKey(LiveChatBadgeRow.newcomerKey)),
    'family': h(find.byKey(LiveChatBadgeRow.familyKey)),
    'vip': h(find.byKey(VipNameBadge.badgeKey)),
    // The charm level's pill, the support art's bar.
    'charm': h(charm.first),
    // On screen (the art is scaled around its middle).
    'support': tester.getRect(support.first).height * KChat.supportBarShare,
  };
}

/// The level emblems' art: the charm creature, the support art (≈ 0.97 of
/// it visible).
(double, double) _art(WidgetTester tester) => (
  tester
      .getSize(
        find.descendant(
          of: find.byType(CharmLevelBadge),
          matching: find.byType(Image),
        ),
      )
      .height,
  tester
          .getRect(
            find.descendant(
              of: find.byType(KLevelBadge),
              matching: find.byType(Image),
            ),
          )
          .height *
      0.97,
);

void _expectOneHeight(
  WidgetTester tester,
  double emblem, {
  Key roleKey = LiveChatBadgeRow.roleKey,
}) {
  final bars = _bars(tester, roleKey: roleKey);
  final tag = KChat.tagHeight(emblem);
  for (final MapEntry(:key, :value) in bars.entries) {
    expect(value, closeTo(tag, 1), reason: '$key: $bars');
  }
  // The tags themselves: one height (within 1 px of each other).
  final tags = [
    for (final k in ['role', 'newcomer', 'family', 'vip']) bars[k]!,
  ]..sort();
  expect(tags.last - tags.first, lessThanOrEqualTo(1), reason: '$bars');
  final (charm, support) = _art(tester);
  expect(charm, closeTo(emblem, 1));
  expect(support, closeTo(emblem, 1));
  expect((charm - support).abs(), lessThanOrEqualTo(1));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the audio / podcast boxed line', (tester) async {
    await _pump(
      tester,
      const LiveChatAuthoredLine(
        name: 'ليلى',
        avatarUrl: null,
        label: 'line',
        message: Text('أهلاً'),
        maxWidth: 380,
        color: Color(0x33000000),
        role: LiveChatRole.host,
        badges: _badges,
        vip: _vip,
      ),
    );
    _expectOneHeight(tester, LiveChatAuthoredLine.badgeRowHeight);
    // The «جديد» tag no taller than the VIP badge or the level's pill.
    expect(
      tester.getSize(find.byKey(LiveChatBadgeRow.newcomerKey)).height,
      lessThanOrEqualTo(KChat.tagHeight(KChat.emblemHeight) + 0.5),
    );
  });

  testWidgets('the video live row', (tester) async {
    await _pump(
      tester,
      const LiveChatInlineRow(
        maxWidth: 380,
        color: LiveRoomChatLines.messageBox,
        label: 'line',
        name: 'ليلى',
        role: LiveChatRole.moderator,
        badges: _badges,
        text: 'أهلاً',
        vip: _vip,
      ),
    );
    _expectOneHeight(tester, LiveChatInlineRow.badgeHeight);
  });

  testWidgets("the host's flat line", (tester) async {
    await _pump(
      tester,
      const LiveChatFlatLine(
        name: 'ليلى',
        text: 'أهلاً',
        label: 'line',
        role: LiveChatRole.host,
        badges: _badges,
        vip: _vip,
      ),
    );
    expect(find.byKey(LiveChatFlatLine.vipHeaderKey), findsNothing);
    _expectOneHeight(
      tester,
      KFlatChat.emblemHeight,
      roleKey: LiveChatFlatLine.tagKey,
    );
  });

  testWidgets('the VIP layout', (tester) async {
    await _pump(
      tester,
      const LiveChatFlatLine(
        name: 'ليلى',
        text: 'أهلاً',
        label: 'line',
        role: LiveChatRole.moderator,
        badges: _badges,
        vip: _vipBubble,
      ),
    );
    expect(find.byKey(LiveChatFlatLine.vipHeaderKey), findsOneWidget);
    _expectOneHeight(tester, LiveChatInlineRow.badgeHeight);
  });
}
