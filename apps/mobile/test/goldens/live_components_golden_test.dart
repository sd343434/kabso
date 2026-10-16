// KL-022 goldens: P0 live components in ar and en, dark (live surfaces are
// always dark). Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_score_bar.dart';
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
              mainAxisSpacing: KSpacing.sm,
              crossAxisSpacing: KSpacing.sm,
              childAspectRatio: KSizes.liveCardAspect,
              children: [
                for (final room in liveRooms(language))
                  KLiveCoverCard(room: room, onTap: () {}),
                const KLiveCoverCardSkeleton(),
                const KLiveCoverCardSkeleton(),
              ],
            ),
            language: language,
            viewport: viewport,
            padding: const EdgeInsets.all(KSpacing.sm),
          );
          await expectScreenGolden(
            'cover_cards',
            language: language,
            viewport: viewport,
          );
        });
      }

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
