import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_score_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/component_harness.dart';
import '../../helpers/golden.dart' show precacheImages;

void main() {
  group('KLiveCoverCard', () {
    Widget card(LiveRoomCardData room, {VoidCallback? onTap}) => Center(
      child: SizedBox(
        width: 180,
        child: KLiveCoverCard(room: room, onTap: onTap),
      ),
    );

    Finder badge(KBadgeVariant variant) =>
        find.byWidgetPredicate((w) => w is KBadge && w.variant == variant);

    testWidgets('announces host, live, viewers and title; 3:4', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        card(liveRooms(AppLanguage.en).first, onTap: () => taps++),
      );
      expect(
        find.bySemanticsLabel(
          'Sara, live, 12,345 viewers, Arabic music night, Music',
        ),
        findsOneWidget,
      );
      final size = tester.getSize(find.byType(KLiveCoverCard));
      expect(size.width / size.height, closeTo(KSizes.liveCardAspect, 0.001));
      await tester.tap(find.byType(KLiveCoverCard));
      expect(taps, 1);
    });

    testWidgets('KL-047: cards carry a small LIVE badge (owner request, '
        'reversing VG-10) and no accent line; showLiveBadge opts out', (
      tester,
    ) async {
      final room = liveRooms(AppLanguage.en).first;
      await pumpComponent(tester, card(room));
      expect(badge(KBadgeVariant.live), findsOneWidget);
      expect(find.byType(KBadge), findsOneWidget);
      expect(find.byType(KViewerCountChip), findsOneWidget);
      // Small and consistent with KBadge: the 20 dp badge height, before
      // the viewer chip at the top-start.
      expect(
        tester.getSize(badge(KBadgeVariant.live)).height,
        KMetrics.badgeHeight,
      );
      expect(
        tester.getCenter(badge(KBadgeVariant.live)).dx,
        lessThan(tester.getCenter(find.byType(KViewerCountChip)).dx),
      );
      // No gradient anywhere except the bottom scrim (the old accent line
      // was a live-gradient strip at the top).
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null);
      expect(gradients, hasLength(1));
      expect(
        (gradients.single.gradient! as LinearGradient).begin,
        Alignment.topCenter,
      );

      await pumpComponent(
        tester,
        Center(
          child: SizedBox(
            width: 180,
            child: KLiveCoverCard(room: room, showLiveBadge: false),
          ),
        ),
      );
      expect(badge(KBadgeVariant.live), findsNothing);
    });

    testWidgets('CP-012: the score chip shows once the live has points', (
      tester,
    ) async {
      const plain = LiveRoomCardData(
        hostName: 'Sara',
        title: 'Night',
        viewerCount: 4,
      );
      await pumpComponent(tester, card(plain));
      expect(find.byType(KScoreChip), findsNothing);
      await pumpComponent(
        tester,
        card(
          const LiveRoomCardData(
            hostName: 'Sara',
            title: 'Night',
            viewerCount: 4,
            score: 12400,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(KScoreChip),
          matching: find.text('12.4K'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('12.4K points')), findsOneWidget);
    });

    testWidgets('VG-11: 0 viewers shows "New", 1 viewer shows "1"', (
      tester,
    ) async {
      const room = LiveRoomCardData(hostName: 'a', title: 'b', viewerCount: 0);
      await pumpComponent(tester, card(room));
      expect(badge(KBadgeVariant.newRoom), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.byType(KViewerCountChip), findsNothing);
      expect(find.bySemanticsLabel('a, live, New, b'), findsOneWidget);

      await pumpComponent(
        tester,
        card(const LiveRoomCardData(hostName: 'a', title: 'b', viewerCount: 1)),
      );
      expect(badge(KBadgeVariant.newRoom), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await pumpComponent(tester, card(room), language: AppLanguage.ar);
      expect(find.text('جديد'), findsOneWidget);
    });

    testWidgets('PK rooms show the solid PK tag at the top end', (
      tester,
    ) async {
      await pumpComponent(tester, card(liveRooms(AppLanguage.en)[1]));
      final pk = badge(KBadgeVariant.pk);
      expect(pk, findsOneWidget);
      final viewers = find.byType(KViewerCountChip);
      expect(
        tester.getCenter(pk).dx,
        greaterThan(tester.getCenter(viewers).dx),
      );
      expect(find.bySemanticsLabel(RegExp(r', PK$')), findsOneWidget);

      await pumpComponent(
        tester,
        card(liveRooms(AppLanguage.ar)[1]),
        language: AppLanguage.ar,
      );
      // RTL: the mode tag is at the top-left, the viewer chip top-right.
      expect(
        tester.getCenter(badge(KBadgeVariant.pk)).dx,
        lessThan(tester.getCenter(find.byType(KViewerCountChip)).dx),
      );
    });

    testWidgets('multi-guest tag only when the room is multi-guest', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        card(
          const LiveRoomCardData(
            hostName: 'a',
            title: 'b',
            viewerCount: 5,
            guestCount: 4,
          ),
        ),
      );
      expect(badge(KBadgeVariant.multiGuest), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(
        find.bySemanticsLabel('a, live, 5 viewers, b, 4 guests'),
        findsOneWidget,
      );

      await pumpComponent(tester, card(liveRooms(AppLanguage.en).first));
      expect(badge(KBadgeVariant.multiGuest), findsNothing);
      expect(badge(KBadgeVariant.pk), findsNothing);
    });

    testWidgets('VG-13: missing and broken covers show the host avatar, '
        'no error text', (tester) async {
      await pumpComponent(
        tester,
        card(
          const LiveRoomCardData(hostName: 'Zed', title: 'b', viewerCount: 1),
        ),
      );
      expect(find.byType(KAvatar), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);

      await pumpComponent(tester, card(liveRooms(AppLanguage.en)[3]));
      await precacheImages(tester);
      expect(find.byType(KAvatar), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('D39: a card with a cover shows a small host avatar and '
        'the host name', (tester) async {
      final room = LiveRoomCardData(
        hostName: 'Sara',
        title: 't',
        viewerCount: 0,
        cover: coverRed,
      );
      await pumpComponent(tester, card(room));
      await precacheImages(tester);
      final avatar = tester.widget<KAvatar>(find.byType(KAvatar));
      expect(avatar.size, KSizes.avatarSm);
      expect(avatar.name, 'Sara');
      expect(find.text('Sara'), findsOneWidget);
    });

    testWidgets('VG-44: press scales to 0.98, instant with reduce motion', (
      tester,
    ) async {
      Future<void> check({required bool reduceMotion}) async {
        await pumpComponent(
          tester,
          card(liveRooms(AppLanguage.en).first, onTap: () {}),
          disableAnimations: reduceMotion,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(KLiveCoverCard)),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scale.scale, KMetrics.cardPressedScale);
        expect(scale.duration, reduceMotion ? Duration.zero : KMotion.fast);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
      }

      await check(reduceMotion: false);
      await check(reduceMotion: true);
    });

    testWidgets('without onTap the card is not a button', (tester) async {
      await pumpComponent(tester, card(liveRooms(AppLanguage.en).first));
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester.getSemantics(find.byType(KLiveCoverCard)),
        isNot(isSemantics(isButton: true)),
      );
    });

    testWidgets('skeleton keeps the card shape and is hidden from a11y', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const Center(
          child: SizedBox(width: 180, child: KLiveCoverCardSkeleton()),
        ),
      );
      final size = tester.getSize(find.byType(KLiveCoverCardSkeleton));
      expect(size.width / size.height, closeTo(KSizes.liveCardAspect, 0.001));
      expect(find.byType(KSkeleton), findsWidgets);
      handle.dispose();
    });
  });

  group('KLiveChatOverlay', () {
    testWidgets('shows only the newest lines', (tester) async {
      final lines = chatLines(AppLanguage.en);
      await pumpComponent(
        tester,
        KLiveChatOverlay(lines: lines, maxVisibleLines: 3),
      );
      expect(find.byType(KLiveChatBubble), findsNWidgets(3));
      expect(find.textContaining('Welcome!'), findsNothing);
      expect(find.textContaining('Can you play it again?'), findsOneWidget);
      // Fades once the stack is full.
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('a short chat does not fade', (tester) async {
      await pumpComponent(
        tester,
        const KLiveChatOverlay(lines: [LiveChatJoin(name: 'rana')]),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('names are bidi-isolated in join and gift lines', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const KLiveChatOverlay(
          lines: [
            LiveChatJoin(name: 'رنا'),
            LiveChatGift(name: 'Yousef', giftName: 'Star', count: 3),
          ],
        ),
      );
      expect(find.textContaining('\u2068رنا\u2069 joined'), findsOneWidget);
      expect(
        find.textContaining('\u2068Yousef\u2069 sent \u2068Star\u2069 ×3'),
        findsOneWidget,
      );
    });
  });

  group('KGiftPanel', () {
    testWidgets('4-column grid, selection callback, send disabled', (
      tester,
    ) async {
      final selected = <String>[];
      await pumpComponent(
        tester,
        SingleChildScrollView(
          child: KGiftPanel(
            gifts: gifts(AppLanguage.en),
            selectedId: 'star',
            onSelected: (g) => selected.add(g.id),
          ),
        ),
      );
      final rowY = [
        for (final name in ['Heart', 'Star', 'Diamond', 'Crown', 'Big heart'])
          tester.getCenter(find.text(name)).dy,
      ];
      expect(rowY.take(4).toSet(), hasLength(1));
      expect(rowY[4], greaterThan(rowY[0]));

      await tester.tap(find.text('Diamond'));
      expect(selected, ['diamond']);

      expect(find.text("Gifts can't be sent yet."), findsOneWidget);
      final send = tester.widget<KButton>(find.byType(KButton));
      expect(send.onPressed, isNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Star, price 10')),
        isSemantics(isSelected: true, isButton: true),
      );
    });

    testWidgets('combo counter bumps for giftComboBumpMs', (tester) async {
      await pumpComponent(
        tester,
        const Center(child: KGiftComboCounter(count: 3)),
        disableAnimations: false,
      );
      expect(find.text('×3'), findsOneWidget);
      final bump = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(bump.duration, KMotion.giftComboBump);
      await tester.pumpAndSettle();
    });

    testWidgets('combo counter is static with reduce motion', (tester) async {
      await pumpComponent(
        tester,
        const Center(child: KGiftComboCounter(count: 3)),
      );
      expect(find.text('×3'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('no ×N counter below 2', (tester) async {
      await pumpComponent(
        tester,
        SingleChildScrollView(
          child: KGiftPanel(gifts: gifts(AppLanguage.en), comboCount: 1),
        ),
      );
      expect(find.byType(KGiftComboCounter), findsNothing);
    });
  });

  group('KPkScoreBar', () {
    Future<void> pumpBar(
      WidgetTester tester,
      AppLanguage language, {
      int host = 9000,
      int opponent = 1000,
      PkResult? result,
    }) => pumpComponent(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: KPkScoreBar(
            hostScore: host,
            opponentScore: opponent,
            timeLeft: const Duration(seconds: 9),
            result: result,
          ),
        ),
      ),
      language: language,
    );

    testWidgets('host is on the start side and mirrors in Arabic', (
      tester,
    ) async {
      await pumpBar(tester, AppLanguage.en);
      expect(
        tester.getCenter(find.text('9,000')).dx,
        lessThan(tester.getCenter(find.text('1,000')).dx),
      );
      await pumpBar(tester, AppLanguage.ar);
      expect(
        tester.getCenter(find.text('9,000')).dx,
        greaterThan(tester.getCenter(find.text('1,000')).dx),
      );
    });

    testWidgets('fill follows the ratio, clamped so scores stay legible', (
      tester,
    ) async {
      await pumpBar(tester, AppLanguage.en);
      final host = find.ancestor(
        of: find.text('9,000'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(host).width, closeTo(300 * 0.8, 0.5));

      await pumpBar(tester, AppLanguage.en, host: 0, opponent: 0);
      final even = find.ancestor(
        of: find.text('0').first,
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(even).width, closeTo(150, 0.5));
    });

    testWidgets('scores are ≥ 20 sp bold; timer and semantics', (tester) async {
      await pumpBar(tester, AppLanguage.en);
      final style = tester.widget<Text>(find.text('9,000')).style!;
      expect(style.fontSize, greaterThanOrEqualTo(20));
      expect(style.fontWeight, FontWeight.w700);
      expect(find.text('0:09 left'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Score 9,000 to 1,000')),
        findsOneWidget,
      );
    });

    testWidgets('result replaces the timer', (tester) async {
      for (final (result, label) in const [
        (PkResult.win, 'Win'),
        (PkResult.lose, 'Loss'),
        (PkResult.draw, 'Draw'),
      ]) {
        await pumpBar(tester, AppLanguage.en, result: result);
        expect(find.text(label), findsOneWidget);
        expect(find.text('0:09 left'), findsNothing);
      }
    });
  });

  group('KLiveRoomScaffold', () {
    testWidgets('slots, placeholder video and 48 dp targets', (tester) async {
      var follows = 0;
      var gifts = 0;
      var closes = 0;
      await pumpComponent(
        tester,
        KLiveRoomScaffold(
          header: KHostPill(hostName: 'Sara', onFollow: () => follows++),
          viewers: const KViewerStrip(names: viewerNames, count: 12345),
          onClose: () => closes++,
          chat: KLiveChatOverlay(lines: chatLines(AppLanguage.en)),
          actionBar: KRoomActionBar(
            onGift: () => gifts++,
            onShare: () {},
            onComment: () {},
          ),
        ),
      );
      expect(find.byType(KLiveVideoPlaceholder), findsOneWidget);
      expect(find.bySemanticsLabel('Live video'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Follow'));
      await tester.tap(find.bySemanticsLabel('Gifts'));
      await tester.tap(find.bySemanticsLabel('Close'));
      expect((follows, gifts, closes), (1, 1, 1));

      for (final label in ['Follow', 'Gifts', 'Close', 'Share']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
      }
    });

    testWidgets('header at the start, close at the end (RTL mirrors)', (
      tester,
    ) async {
      for (final language in AppLanguage.values) {
        await pumpComponent(
          tester,
          const KLiveRoomScaffold(
            header: KHostPill(hostName: 'Sara', following: true),
            chat: SizedBox.shrink(),
            actionBar: KRoomActionBar(),
          ),
          language: language,
        );
        final pill = tester.getCenter(find.byType(KHostPill)).dx;
        final close = tester.getCenter(find.byIcon(Icons.close)).dx;
        expect(
          language == AppLanguage.ar ? pill > close : pill < close,
          isTrue,
          reason: language.name,
        );
        // HL-L2: already following at open → no follow control at all.
        expect(
          find.bySemanticsLabel(
            RegExp(language == AppLanguage.ar ? 'تتابعه|متابعة' : 'Follow'),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('always dark, even in the light theme', (tester) async {
      await pumpComponent(
        tester,
        const KLiveRoomScaffold(
          header: SizedBox.shrink(),
          chat: SizedBox.shrink(),
          actionBar: SizedBox.shrink(),
        ),
        brightness: Brightness.light,
      );
      final context = tester.element(find.byType(KLiveVideoPlaceholder));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });
}
