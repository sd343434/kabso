// KL-022 goldens: P0 live components in ar and en, dark (live surfaces are
// always dark). KL-033 adds the primary tabs + chips, compact states and
// the bottom nav. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_score_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_fixtures.dart';
import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      testWidgets('badges and viewer chips', (tester) async {
        await pumpGolden(
          tester,
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.md,
            children: [
              const KBadge.live(),
              const KBadge.pk(),
              const KBadge.newRoom(),
              const KBadge.multiGuest(count: 4),
              for (final count in viewerCountSamples)
                KViewerCountChip(count: count),
              const KLiveWithViewers(count: 12345),
            ],
          ),
          language: language,
        );
        await expectScreenGolden('badges', language: language);
      });

      testWidgets('avatar rings', (tester) async {
        await pumpGolden(
          tester,
          Wrap(
            spacing: KSpacing.lg,
            runSpacing: KSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final size in const [
                KSizes.avatarSm,
                KSizes.avatarMd,
                KSizes.avatarLg,
              ])
                for (final ring in KAvatarRing.values)
                  KAvatar(
                    name: 'Sara',
                    image: avatarImage,
                    size: size,
                    ring: ring,
                  ),
              const KAvatar.story(name: 'نور'),
              KAvatar.story(name: 'Omar', image: avatarImage),
              KAvatar.story(
                name: 'Lina',
                image: avatarImage,
                ring: KAvatarRing.storySeen,
              ),
              KAvatar.story(
                name: 'Ali',
                image: avatarImage,
                ring: KAvatarRing.live,
              ),
            ],
          ),
          language: language,
        );
        await expectScreenGolden('avatar_rings', language: language);
      });

      testWidgets('scrollable category tabs', (tester) async {
        await pumpGolden(
          tester,
          Column(
            children: [
              KScrollableTabs(
                labels: categories(language),
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              const SizedBox(height: KSpacing.xl),
              KScrollableTabs(
                labels: categories(language),
                selectedIndex: 2,
                onSelected: (_) {},
              ),
            ],
          ),
          language: language,
          padding: EdgeInsets.zero,
        );
        await expectScreenGolden('tabs', language: language);
      });

      for (final viewport in GoldenViewport.values) {
        testWidgets('cover card grid (${viewport.name})', (tester) async {
          await pumpGolden(
            tester,
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: KMetrics.liveGridGap,
              crossAxisSpacing: KMetrics.liveGridGap,
              childAspectRatio: KSizes.liveCardAspect,
              children: [
                for (final room in liveRooms(language))
                  KLiveCoverCard(room: room, onTap: () {}),
                // KL-047: the LIVE badge is on by default; this card shows
                // the opt-out.
                KLiveCoverCard(
                  room: liveRooms(language).first,
                  showLiveBadge: false,
                ),
                const KLiveCoverCardSkeleton(),
              ],
            ),
            language: language,
            viewport: viewport,
            padding: const EdgeInsets.all(KMetrics.liveGridPadding),
          );
          await expectScreenGolden(
            'cover_cards',
            language: language,
            viewport: viewport,
          );
        });
      }

      testWidgets('primary tabs, chips and secondary tabs (VG-07)', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(language.locale);
        await pumpGolden(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final selected in [1, 0])
                KPrimaryTabs(
                  labels: [
                    l10n.feedTabFollowing,
                    l10n.feedTabPopular,
                    l10n.feedTabNew,
                  ],
                  selectedIndex: selected,
                  onSelected: (_) {},
                ),
              const SizedBox(height: KSpacing.lg),
              KChipRow(
                children: [KChip(label: l10n.liveHubChipAll, selected: true)],
              ),
              KChipRow(
                children: [
                  for (final (i, label) in categories(language).indexed)
                    KChip(label: label, selected: i == 2, onSelected: () {}),
                ],
              ),
              const SizedBox(height: KSpacing.lg),
              KScrollableTabs(
                labels: categories(language),
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ],
          ),
          language: language,
          padding: EdgeInsets.zero,
        );
        await expectScreenGolden('tabs_primary_chips', language: language);
      });

      testWidgets('compact empty and error states (VG-03)', (tester) async {
        final l10n = lookupAppLocalizations(language.locale);
        await pumpGolden(
          tester,
          Column(
            children: [
              KEmptyState(
                compact: true,
                icon: Icons.sensors_outlined,
                title: l10n.liveHubPopularUnavailableTitle,
                message: l10n.liveHubPopularUnavailableBody,
              ),
              KEmptyState(
                compact: true,
                icon: Icons.sensors_off_outlined,
                title: l10n.liveHubFollowingEmptyTitle,
                message: l10n.feedPullToRefresh,
                actionLabel: l10n.feedSeePopular,
                onAction: () {},
              ),
              KErrorState(
                compact: true,
                title: l10n.liveHubErrorTitle,
                message: l10n.errorNetworkOffline,
                retryLabel: l10n.actionRetry,
                onRetry: () {},
              ),
            ],
          ),
          language: language,
          padding: EdgeInsets.zero,
        );
        await expectScreenGolden('states_compact', language: language);
      });

      testWidgets('bottom nav: Home, Create and Live active', (tester) async {
        final l10n = lookupAppLocalizations(language.locale);
        await pumpGolden(
          tester,
          Column(
            children: [
              for (final index in [0, 2, 3]) ...[
                KBottomNav(
                  items: shellNavItems(l10n),
                  currentIndex: index,
                  onSelect: (_) {},
                ),
                const SizedBox(height: KSpacing.lg),
              ],
            ],
          ),
          language: language,
          padding: EdgeInsets.zero,
        );
        await expectScreenGolden('bottom_nav', language: language);
      });

      testWidgets('chat overlay', (tester) async {
        await pumpGolden(
          tester,
          Stack(
            fit: StackFit.expand,
            children: [
              fakeVideoFrame(),
              Padding(
                padding: const EdgeInsets.all(KSpacing.sm),
                child: KLiveChatOverlay(lines: chatLines(language)),
              ),
            ],
          ),
          language: language,
          bare: true,
        );
        await expectScreenGolden('chat_overlay', language: language);
      });

      testWidgets('gift panel', (tester) async {
        await pumpGolden(
          tester,
          Stack(
            fit: StackFit.expand,
            children: [
              fakeVideoFrame(),
              ColoredBox(color: KPalette.dark.scrim),
              Align(
                alignment: Alignment.bottomCenter,
                child: KGiftPanel(
                  gifts: gifts(language),
                  selectedId: 'star',
                  comboCount: 3,
                  onSelected: (_) {},
                ),
              ),
            ],
          ),
          language: language,
          bare: true,
        );
        await expectScreenGolden('gift_panel', language: language);
      });

      testWidgets('PK score bar states', (tester) async {
        await pumpGolden(
          tester,
          Column(
            children: [
              for (final (host, opponent, time, result) in pkSnapshots)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.lg),
                  child: KPkScoreBar(
                    hostScore: host,
                    opponentScore: opponent,
                    timeLeft: time,
                    result: result,
                  ),
                ),
            ],
          ),
          language: language,
        );
        await expectScreenGolden('pk_bar', language: language);
      });

      for (final viewport in GoldenViewport.values) {
        for (final variant in const ['viewer', 'pk', 'gifts']) {
          testWidgets('room scaffold $variant (${viewport.name})', (
            tester,
          ) async {
            await pumpGolden(
              tester,
              _room(language, variant),
              language: language,
              viewport: viewport,
              bare: true,
            );
            await expectScreenGolden(
              'room_$variant',
              language: language,
              viewport: viewport,
            );
          });
        }
      }
    });
  });
}

Widget _room(AppLanguage language, String variant) {
  final (host, opponent, time, _) = pkSnapshots[1];
  return KLiveRoomScaffold(
    video: fakeVideoFrame(),
    header: KHostPill(
      hostName: language == AppLanguage.ar ? 'سارة' : 'Sara',
      avatar: avatarImage,
      following: false,
      onFollow: () {},
    ),
    viewers: const KViewerStrip(names: viewerNames, count: 12345),
    onClose: () {},
    pk: variant == 'pk'
        ? KPkScoreBar(hostScore: host, opponentScore: opponent, timeLeft: time)
        : null,
    chat: KLiveChatOverlay(lines: chatLines(language)),
    actionBar: KRoomActionBar(onComment: () {}, onShare: () {}, onGift: () {}),
    overlay: variant == 'gifts'
        ? ColoredBox(
            color: KPalette.dark.scrim,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: KGiftPanel(gifts: gifts(language), onSelected: (_) {}),
            ),
          )
        : null,
  );
}
