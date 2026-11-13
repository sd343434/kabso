// D389 (owner: «اجعل عند ضغط عن اي شارة التطبيق يشرح ما هي بصندوق صغير
// شفاف»; CONVENTIONS §10.178): a tap on any badge shows what it is, in the
// app's language, in a small translucent bubble beside it — gone after 3 s
// or on a tap outside, kept inside the screen in both directions, and never
// passing the tap on to the row the badge sits in.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_role_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_badge.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final _now = DateTime.utc(2026, 11, 13, 9);

const _vip3 = UserVip(tier: 'VIP_3', rank: 3, color: 0xFF7B3FE4);

/// Each badge type, its key, and what its bubble says.
typedef _Case = ({
  String name,
  Widget badge,
  String Function(AppLocalizations l) message,
});

List<_Case> _cases() => [
  (
    name: 'kabso team',
    badge: const KabsoTeamBadge(height: 24),
    message: (AppLocalizations l) => l.badgeExplainKabsoTeam,
  ),
  (
    name: 'wealth level',
    badge: const KLevelBadge(
      category: LevelCategory.support,
      levelNumber: 25,
      height: 16,
    ),
    message: (AppLocalizations l) => l.badgeExplainWealthLevel(25),
  ),
  (
    name: 'charm level (person)',
    badge: const CharmLevelBadge(level: 12, height: 16),
    message: (AppLocalizations l) => l.badgeExplainCharmLevel(12),
  ),
  (
    name: 'room level',
    badge: const CharmLevelBadge(level: 30, height: 16, room: true),
    message: (AppLocalizations l) => l.badgeExplainRoomLevel(30),
  ),
  (
    name: 'vip',
    badge: const VipNameBadge(vip: _vip3, height: 18),
    message: (AppLocalizations l) => l.badgeExplainVip(3),
  ),
  (
    name: 'golden id',
    badge: const VipGoldenIdChip(
      goldenId: UserGoldenId(number: '8888', goldenClass: 'REPEATED'),
      height: 18,
    ),
    message: (AppLocalizations l) => l.badgeExplainGoldenId('8888'),
  ),
  (
    name: 'verification (staff)',
    badge: const ProfileVerificationBadge(badge: VerificationBadge.staff),
    message: (AppLocalizations l) =>
        l.badgeExplainVerification(l.verificationBadgeStaff),
  ),
  (
    name: 'verification (creator)',
    badge: const ProfileVerificationBadge(badge: VerificationBadge.creator),
    message: (AppLocalizations l) =>
        l.badgeExplainVerification(l.verificationBadgeCreator),
  ),
  (
    name: 'founder',
    badge: const FounderBadge(),
    message: (AppLocalizations l) => l.badgeExplainFounder,
  ),
  (
    name: 'recharge tier',
    badge: RechargeTierBadge(
      badge: RechargeBadge(tier: 4, until: _now.add(const Duration(hours: 5))),
      height: 20,
    ),
    message: (AppLocalizations l) => l.badgeExplainRechargeTier(4),
  ),
  (
    name: 'recharge agent',
    badge: const RechargeAgentBadge(code: 'coin0001', height: 20),
    message: (AppLocalizations l) =>
        l.badgeExplainRechargeAgent('\u2068coin0001\u2069'),
  ),
  (
    name: 'host agent',
    badge: const HostAgentBadge(code: 'host03', height: 20),
    message: (AppLocalizations l) =>
        l.badgeExplainHostAgent('\u2068host03\u2069'),
  ),
  (
    name: 'item badge',
    badge: const KItemBadgePill(ItemBadgeCode.isNew),
    message: (AppLocalizations l) => l.badgeExplainItem(l.itemBadgeNew),
  ),
  (
    name: 'creator live',
    badge: const CreatorLiveBadge(),
    message: (AppLocalizations l) => l.badgeExplainCreatorLive,
  ),
  (
    name: 'host target',
    badge: const KHostTargetBadge(HostTargetKind.lucky),
    message: (AppLocalizations l) => l.badgeExplainHostTargetLucky,
  ),
  (
    name: 'host tag',
    badge: const LiveChatRoleTag(kind: LiveChatTagKind.host, height: 16),
    message: (AppLocalizations l) => l.badgeExplainHost,
  ),
  (
    name: 'moderator tag',
    badge: const LiveChatRoleTag(kind: LiveChatTagKind.moderator, height: 16),
    message: (AppLocalizations l) => l.badgeExplainModerator,
  ),
  (
    name: 'newcomer',
    badge: const LiveChatNewcomerTag(height: 16, textSize: 10),
    message: (AppLocalizations l) => l.badgeExplainNewcomer,
  ),
  (
    name: 'family',
    badge: const LiveChatFamilyChip(name: 'Falcons', level: 7),
    message: (AppLocalizations l) =>
        l.badgeExplainFamily('\u2068Falcons\u2069', 7),
  ),
];

Widget _scope(Widget child) => ProviderScope(
  overrides: [vipCatalogProvider.overrideWith((ref) async => null)],
  child: child,
);

Finder get _bubble => find.byKey(KBadgeExplainer.bubbleKey);

String _bubbleText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(KBadgeExplainer.textKey)).data!;

/// A tappable row (like a chat line or a list tile) holding [badge] after
/// some text.
Widget _row(Widget badge, VoidCallback onRow) => Material(
  color: const Color(0xFF2A1F3D),
  child: InkWell(
    key: const Key('row'),
    onTap: onRow,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Expanded(child: Text('Omar', key: Key('rowText'))),
          badge,
        ],
      ),
    ),
  ),
);

void main() {
  setUp(KBadgeExplainer.dismiss);

  for (final language in AppLanguage.values) {
    final l = l10nFor(language);
    group('${language.name}: every badge type explains itself', () {
      for (final c in _cases()) {
        testWidgets(c.name, (tester) async {
          await withClock(Clock.fixed(_now), () async {
            await pumpGolden(
              tester,
              _scope(Center(child: c.badge)),
              language: language,
            );
          });
          expect(_bubble, findsNothing);
          await tester.tap(find.byType(KBadgeExplainer).first);
          await tester.pump();
          expect(_bubble, findsOneWidget);
          expect(_bubbleText(tester), c.message(l));
          // Auto-dismissed after about 3 s.
          await tester.pump(const Duration(milliseconds: 2900));
          expect(_bubble, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 200));
          expect(_bubble, findsNothing);
        });
      }
    });
  }

  test('the expected copy, word for word', () {
    final ar = l10nFor(AppLanguage.ar);
    expect(
      ar.badgeExplainKabsoTeam,
      'شارة فريق كابسو — هذا الحساب من فريق كابسو الرسمي',
    );
    expect(ar.badgeExplainWealthLevel(25), 'مستوى الثروة 25');
    expect(ar.badgeExplainVip(3), 'عضوية VIP 3');
    final en = l10nFor(AppLanguage.en);
    expect(en.badgeExplainWealthLevel(25), 'Wealth level 25');
    expect(en.badgeExplainVip(3), 'VIP 3 membership');
  });

  testWidgets('a tap outside closes it; a second tap on the badge too', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const Center(child: KabsoTeamBadge(height: 24)),
      language: AppLanguage.ar,
    );
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pump();
    expect(_bubble, findsOneWidget);
    await tester.tapAt(const Offset(20, 800));
    await tester.pump();
    expect(_bubble, findsNothing);

    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pump();
    expect(_bubble, findsOneWidget);
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pump();
    expect(_bubble, findsNothing);

    // A tap on the bubble itself closes it.
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pump();
    await tester.tap(_bubble);
    await tester.pump();
    expect(_bubble, findsNothing);
  });

  testWidgets('one bubble at a time: a second badge replaces the first', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KabsoTeamBadge(height: 24),
          // Far enough apart that the first bubble does not cover the
          // second badge (a tap on a bubble only closes it).
          SizedBox(height: 160),
          KLevelBadge(
            category: LevelCategory.support,
            levelNumber: 25,
            height: 16,
          ),
        ],
      ),
      language: AppLanguage.en,
    );
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pump();
    expect(_bubbleText(tester), l10nFor(AppLanguage.en).badgeExplainKabsoTeam);
    await tester.tap(find.byType(KLevelBadge));
    await tester.pump();
    expect(_bubble, findsOneWidget);
    expect(_bubbleText(tester), 'Wealth level 25');
    await tester.pump(KBadgeExplainer.showFor);
    expect(_bubble, findsNothing);
  });

  testWidgets('in a tappable row: the badge explains and the row does not '
      'open; beside the badge the row still opens', (tester) async {
    var opened = 0;
    await pumpGolden(
      tester,
      _row(const KabsoTeamBadge(height: 24), () => opened++),
      language: AppLanguage.ar,
    );
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    expect(opened, 0);
    await tester.pump(KBadgeExplainer.showFor);
    expect(_bubble, findsNothing);

    await tester.tap(find.byKey(const Key('rowText')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(_bubble, findsNothing);
  });

  testWidgets('a badge that is only a picture ([explain] false) has no '
      'bubble and lets the row have the tap', (tester) async {
    var opened = 0;
    await pumpGolden(
      tester,
      _row(const KabsoTeamBadge(height: 24, explain: false), () => opened++),
      language: AppLanguage.en,
    );
    await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(opened, 1);
  });

  group('kept inside the screen, in both directions', () {
    for (final viewport in GoldenViewport.values) {
      for (final language in AppLanguage.values) {
        for (final at in [
          AlignmentDirectional.topStart,
          AlignmentDirectional.topEnd,
          AlignmentDirectional.bottomStart,
          AlignmentDirectional.bottomEnd,
          AlignmentDirectional.center,
        ]) {
          testWidgets('${viewport.name} ${language.name} $at', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await pumpGolden(
              tester,
              Align(alignment: at, child: const KabsoTeamBadge(height: 24)),
              language: language,
              viewport: viewport,
              bare: true,
            );
            final badge = tester.getRect(find.byKey(KabsoTeamBadge.badgeKey));
            await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
            await tester.pump();
            expect(tester.takeException(), isNull);
            final bubble = tester.getRect(_bubble);
            final screen = Offset.zero & viewport.logicalSize;
            expect(bubble.left, greaterThanOrEqualTo(screen.left));
            expect(bubble.right, lessThanOrEqualTo(screen.right));
            expect(bubble.top, greaterThanOrEqualTo(screen.top));
            expect(bubble.bottom, lessThanOrEqualTo(screen.bottom));
            expect(bubble.width, lessThanOrEqualTo(KBadgeExplainer.maxWidth));
            // Beside the badge, never over it: under it, or above it when
            // the badge is at the bottom.
            expect(bubble.overlaps(badge), isFalse);
            if (at.y > 0) {
              expect(bubble.bottom, lessThanOrEqualTo(badge.top));
            } else {
              expect(bubble.top, greaterThanOrEqualTo(badge.bottom));
            }
            await tester.pump(KBadgeExplainer.showFor);
          });
        }
      }
    }
  });

  testWidgets('the text follows the language: right to left in Arabic', (
    tester,
  ) async {
    for (final language in AppLanguage.values) {
      await pumpGolden(
        tester,
        const Center(child: KabsoTeamBadge(height: 24)),
        language: language,
      );
      await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
      await tester.pump();
      final text = find.byKey(KBadgeExplainer.textKey);
      expect(
        Directionality.of(tester.element(text)),
        language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
      );
      await tester.pump(KBadgeExplainer.showFor);
    }
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('badge_explainer (${language.name})', (tester) async {
        await withClock(Clock.fixed(_now), () async {
          await pumpGolden(
            tester,
            _scope(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(const KabsoTeamBadge(height: 24), () {}),
                  const SizedBox(height: 96),
                  _row(
                    const KLevelBadge(
                      category: LevelCategory.support,
                      levelNumber: 25,
                      height: 16,
                    ),
                    () {},
                  ),
                  const SizedBox(height: 12),
                  _row(const VipNameBadge(vip: _vip3, height: 18), () {}),
                ],
              ),
            ),
            language: language,
          );
        });
        await tester.tap(find.byKey(KabsoTeamBadge.badgeKey));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        await expectLater(
          // The whole screen at @3x (pumpGolden's boundary).
          find.byKey(const ValueKey('golden-boundary')),
          matchesGoldenFile(
            '../goldens/png/badge_explainer_d389.${language.name}.phone.png',
          ),
        );
        await tester.pump(KBadgeExplainer.showFor);
      }, tags: goldenTag);
    }
  });
}
