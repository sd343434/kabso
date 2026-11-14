import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/store/data/store_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D270: a store item's art in its box — the animation (SVGA, or MP4 on the
/// gifts' video path) over its still; the still alone in tests and with
/// reduced motion; a neutral glyph of the kind until the owner uploads art.
class StoreArtView extends StatelessWidget {
  const new({
    required this.art,
    required this.kind,
    super.key,
    this.fit = BoxFit.contain,
    this.once = false,
    this.onDone,
  });

  final StoreArt art;
  final StoreKind kind;
  final BoxFit fit;
  final bool once;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return VipAnimatedArt(
      animation: art.animation,
      still: art.still,
      video: art.video,
      fit: fit,
      once: once,
      onDone: onDone,
      placeholder: Center(
        child: Icon(storeKindGlyph(kind), color: p.textTertiary, size: 32),
      ),
    );
  }
}

/// The glyph of a kind (tabs, placeholders).
IconData storeKindGlyph(StoreKind kind) => switch (kind) {
  StoreKind.avatarFrame => Icons.account_circle_rounded,
  StoreKind.profileCard => Icons.badge_rounded,
  StoreKind.chatBubble => Icons.chat_bubble_rounded,
  StoreKind.entryBanner => Icons.campaign_rounded,
  StoreKind.entryEffect => Icons.directions_car_filled_rounded,
};

/// The name of a kind (the tab).
String storeKindLabel(AppLocalizations l10n, StoreKind kind) => switch (kind) {
  StoreKind.avatarFrame => l10n.storeKindAvatarFrame,
  StoreKind.profileCard => l10n.storeKindProfileCard,
  StoreKind.chatBubble => l10n.storeKindChatBubble,
  StoreKind.entryBanner => l10n.storeKindEntryBanner,
  StoreKind.entryEffect => l10n.storeKindEntryEffect,
};

/// D270: the item sheet's big preview — what the person will look like: the
/// frame around their own picture, the card behind their name, the bubble
/// around a sample line, the entry banner with «دخل … البث», the car
/// playing. [name] / [avatarUrl]: the person's own.
class StoreItemPreview extends StatelessWidget {
  const new({
    required this.item,
    required this.name,
    required this.avatarUrl,
    super.key,
  });

  final StoreItem item;
  final String name;
  final String? avatarUrl;

  static const previewKey = Key('store.preview');

  /// The preview's height.
  static const double height = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final art = item.art;
    final Widget child = switch (item.kind) {
      StoreKind.avatarFrame => _FramePreview(
        art: art,
        name: name,
        avatarUrl: avatarUrl,
      ),
      StoreKind.profileCard => _CardPreview(
        art: art,
        name: name,
        avatarUrl: avatarUrl,
      ),
      StoreKind.chatBubble => _BubblePreview(
        art: art,
        name: name,
        text: l10n.storePreviewSample,
      ),
      StoreKind.entryBanner => _BannerPreview(
        art: art,
        text: l10n.agentEntranceJoined(KFormat.bidiIsolate(name)),
      ),
      StoreKind.entryEffect => StoreArtView(art: art, kind: item.kind),
    };
    return Container(
      key: previewKey,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surfaceOverlay, p.surface],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(KSpacing.md),
      child: Center(child: child),
    );
  }
}

class _FramePreview extends StatelessWidget {
  const new({required this.art, required this.name, required this.avatarUrl});

  final StoreArt art;
  final String name;
  final String? avatarUrl;

  static const double picture = 112;

  @override
  Widget build(BuildContext context) {
    final rect = VipAvatarFrame.artRect(
      picture,
      VipAvatarFrame.templateCentre,
      VipAvatarFrame.templateWindow,
    );
    return SizedBox.square(
      dimension: picture,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          KAvatar(name: name, imageUrl: avatarUrl, size: picture),
          Positioned.fromRect(
            rect: rect,
            child: StoreArtView(art: art, kind: StoreKind.avatarFrame),
          ),
        ],
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const new({required this.art, required this.name, required this.avatarUrl});

  final StoreArt art;
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            StoreArtView(
              art: art,
              kind: StoreKind.profileCard,
              fit: BoxFit.cover,
            ),
            Align(
              alignment: const Alignment(0, 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KAvatar(name: name, imageUrl: avatarUrl, size: 44),
                  const SizedBox(height: KSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: KSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(KRadius.pill),
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.label.copyWith(color: const Color(0xFFFFFFFF)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubblePreview extends StatelessWidget {
  const new({required this.art, required this.name, required this.text});

  final StoreArt art;
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      child: Stack(
        children: [
          Positioned.fill(
            child: StoreArtView(
              art: art,
              kind: StoreKind.chatBubble,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.xl,
              vertical: KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: const Color(0xFFFFE08A),
                    shadows: _shadow,
                  ),
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  text,
                  style: t.body.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    shadows: _shadow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft dark edge so white text reads on any art.
const List<Shadow> _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 3)];

class _BannerPreview extends StatelessWidget {
  const new({required this.art, required this.text});

  final StoreArt art;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return AspectRatio(
      aspectRatio: art.aspect?.clamp(2.0, 6.0) ?? 660 / 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          StoreArtView(art: art, kind: StoreKind.entryBanner, fit: BoxFit.fill),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(
                  color: const Color(0xFFFFFFFF),
                  shadows: _shadow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
