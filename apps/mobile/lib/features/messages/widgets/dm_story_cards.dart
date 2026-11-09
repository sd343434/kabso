import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D336: geometry of the Messages tab's story cards, measured on the owner's
/// reference (1.356 px/dp; colours, ring and badge are Kabso's).
abstract final class KDmStoryCards {
  static const double height = 152;
  static const double addWidth = 89;
  static const double width = 97;
  static const double gap = 7;
  static const double startInset = 21;
  static const double radius = KRadius.md;

  /// «أضف قصة»: the caller's picture, its top inside the card, the red «+».
  static const double addAvatar = 56;
  static const double addAvatarTop = 38;
  static const double addBadge = 22;

  /// A followed account: the ringed picture (68 dp + a 2.5 dp ring).
  static const double avatar = 68;
  static const double ring = 2.5;
  static const double avatarTop = 15;
  static const double nameSize = 16;
  static const double timeSize = 13;
  static const double labelSize = 14;
}

/// D336: the stories row of the Messages tab — «أضف قصة» first (the
/// caller's own stories when they have one, the «+» adds), then the
/// followed accounts with active stories in the tray's order (CP-008
/// `GET /feed/stories`, unseen first). While the tray loads, when it fails
/// or when nobody has a story, only the caller's card is shown: nothing is
/// guessed. The card's picture is the account's own (the tray carries no
/// story media).
class DmStoryCards extends ConsumerWidget {
  const new({super.key});

  static const rowKey = Key('dm.stories');
  static const addKey = Key('dm.stories.add');
  static const addBadgeKey = Key('dm.stories.add.badge');
  static Key cardKey(String username) => Key('dm.stories.$username');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final tray = ref.watch(storyTrayProvider).value ?? const <StoryTrayItem>[];
    final own = [
      for (final i in tray)
        if (i.user.id == me?.id) i,
    ].firstOrNull;
    final others = [
      for (final i in tray)
        if (i.user.id != me?.id) i,
    ];
    return SizedBox(
      height: KDmStoryCards.height,
      child: ListView(
        key: rowKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(
          start: KDmStoryCards.startInset,
          end: KDmStoryCards.startInset,
        ),
        children: [
          if (me != null)
            _AddCard(
              name: me.displayName.isEmpty ? me.username : me.displayName,
              avatarUrl: me.avatarUrl,
              hasStory: own != null,
              onOpen: own == null
                  ? null
                  : () => context.push(AppRoutes.stories(me.username)),
              onAdd: () => context.push(AppRoutes.newStory),
            ),
          for (final item in others) ...[
            const SizedBox(width: KDmStoryCards.gap),
            _StoryCard(
              item: item,
              onTap: () => context.push(AppRoutes.stories(item.user.username)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The caller's card: a pale card, their picture with the «+» and «أضف
/// قصة» (or «قصتك» while they have a story; a tap opens it).
class _AddCard extends StatelessWidget {
  const new({
    required this.name,
    required this.avatarUrl,
    required this.hasStory,
    required this.onAdd,
    this.onOpen,
  });

  final String name;
  final String? avatarUrl;
  final bool hasStory;
  final VoidCallback onAdd;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final light = Theme.of(context).brightness == Brightness.light;
    // A faint Kabso-red tint over the page surface (the reference's pale
    // card, in Kabso's colour).
    final fill = Color.alphaBlend(
      p.primary.withValues(alpha: light ? 0.06 : 0.12),
      light ? p.surface : p.surfaceRaised,
    );
    final label = hasStory ? l10n.storyYourStory : l10n.dmStoriesAdd;
    return Semantics(
      button: true,
      label: hasStory ? l10n.storyOpenOwn : l10n.storyAdd,
      onTap: onOpen ?? onAdd,
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(KDmStoryCards.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: DmStoryCards.addKey,
          onTap: onOpen ?? onAdd,
          child: SizedBox(
            width: KDmStoryCards.addWidth,
            child: Column(
              children: [
                const SizedBox(height: KDmStoryCards.addAvatarTop),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasStory ? p.primary : p.border,
                          width: 1.5,
                        ),
                      ),
                      child: KAvatar(
                        name: name,
                        imageUrl: avatarUrl,
                        size: KDmStoryCards.addAvatar,
                      ),
                    ),
                    PositionedDirectional(
                      end: -4,
                      bottom: -4,
                      child: GestureDetector(
                        key: DmStoryCards.addBadgeKey,
                        onTap: onAdd,
                        child: Container(
                          width: KDmStoryCards.addBadge,
                          height: KDmStoryCards.addBadge,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: fill, width: 2),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: t.label.copyWith(
                      fontSize: KDmStoryCards.labelSize,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A followed account's card: their picture blurred behind, the ringed
/// picture (red while unseen, faint once seen), the name and how long ago
/// the newest story was posted.
class _StoryCard extends StatelessWidget {
  const new({required this.item, required this.onTap});

  final StoryTrayItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final l10n = context.l10n;
    final user = item.user;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    // D336: compact on screen («5د», "5m"), in words for screen readers.
    final ago =
        KFormat.relativeShort(item.latestAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    final agoSpoken =
        KFormat.relative(item.latestAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    final url = user.avatarUrl;
    // Without a picture: a Kabso red-to-dark card.
    const fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KBrandColors.red600, KBrandColors.red700],
        ),
      ),
    );
    const outer = KDmStoryCards.avatar + 2 * KDmStoryCards.ring;
    return Semantics(
      button: true,
      label: l10n.storyOpen(name),
      value: agoSpoken,
      onTap: onTap,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KDmStoryCards.radius),
        child: SizedBox(
          width: KDmStoryCards.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                fallback
              else
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                ),
              // Darker towards the bottom, for the white name.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x14000000), Color(0x8C000000)],
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: KDmStoryCards.avatarTop),
                  Container(
                    width: outer,
                    height: outer,
                    padding: const EdgeInsets.all(KDmStoryCards.ring),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: item.hasUnseen
                          ? const SweepGradient(
                              colors: [
                                KBrandColors.red400,
                                KBrandColors.red500,
                                KBrandColors.gold,
                                KBrandColors.red400,
                              ],
                            )
                          : null,
                      color: item.hasUnseen ? null : const Color(0x99FFFFFF),
                    ),
                    child: KAvatar(
                      name: name,
                      imageUrl: url,
                      size: KDmStoryCards.avatar,
                    ),
                  ),
                  const SizedBox(height: KSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.xs,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.bodyStrong.copyWith(
                        fontSize: KDmStoryCards.nameSize,
                        height: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    ago,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      fontSize: KDmStoryCards.timeSize,
                      color: const Color(0xD9FFFFFF),
                    ),
                  ),
                ],
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: DmStoryCards.cardKey(user.username),
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
