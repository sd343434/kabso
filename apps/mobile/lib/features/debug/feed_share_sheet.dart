import 'dart:math' as math;

import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 share sheet, measured from the owner's Figma
/// reference (UI kit "Share", node 501:10941, 415x448). Only geometry and type
/// sizes are taken from it: the destinations are Kabso's own actions, and the
/// kit's third-party app targets and photos are not reproduced.
abstract final class KShareSheet {
  static const double radius = 12;
  static const double headerHeight = 54;
  static const double titleSize = 18;
  static const double closeIcon = 16;
  static const double closeInset = 22;
  static const double rowHeight = 125;
  static const double rowPadding = 5;
  static const double itemWidth = 86;
  static const double itemTile = 60;
  static const double friendLabelGap = 9;
  static const double actionLabelGap = 7;
  static const double labelSize = 12;
  static const double labelWidth = 72;
  static const double actionIcon = 28;
}

/// A test-data friend in the share sheet's "send to" row.
class ShareFriend {
  const new(this.name);

  final String name;
}

/// The friends the preview sheet offers (labelled test data, D46).
List<ShareFriend> shareFriendsFixture({required bool ar}) => [
  ShareFriend(ar ? 'نور (تجربة)' : 'Nour (test)'),
  ShareFriend(ar ? 'سامي (تجربة)' : 'Sami (test)'),
  ShareFriend(ar ? 'هند (تجربة)' : 'Hind (test)'),
  ShareFriend(ar ? 'عمر (تجربة)' : 'Omar (test)'),
  ShareFriend(ar ? 'ليلى (تجربة)' : 'Layla (test)'),
];

/// Bottom sheet opened by the share buttons of the feed and live previews.
/// Every destination closes the sheet; nothing is sent (preview only).
class FeedShareSheet extends StatelessWidget {
  const new({super.key});

  static const sheetKey = Key('feed-share-sheet');
  static const friendsKey = Key('feed-share-friends');
  static const actionsKey = Key('feed-share-actions');
  static const toolsKey = Key('feed-share-tools');
  static const closeKey = Key('feed-share-close');

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (_) => const FeedShareSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final close = Navigator.of(context).maybePop;

    // The measured row height, grown when larger text needs two taller lines.
    final labelLines =
        MediaQuery.textScalerOf(context).scale(KShareSheet.labelSize) * 1.4 * 2;
    double rowHeight(double vertical) => math.max(
      KShareSheet.rowHeight,
      KShareSheet.itemTile +
          KShareSheet.friendLabelGap +
          labelLines +
          2 * (KSpacing.sm + vertical),
    );

    Widget row(Key key, List<Widget> items, {double vertical = 0}) => SizedBox(
      key: key,
      height: rowHeight(vertical),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: KShareSheet.rowPadding,
          vertical: vertical,
        ),
        children: items,
      ),
    );

    Widget action(
      String label,
      String asset, {
      required Color fill,
      required Color ink,
    }) => _ShareItem(
      label: label,
      gap: KShareSheet.actionLabelGap,
      onTap: close,
      tile: DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Center(
          child: AppIcon(asset, size: KShareSheet.actionIcon, color: ink),
        ),
      ),
    );

    return Container(
      key: sheetKey,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KShareSheet.radius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: KShareSheet.headerHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    l10n.shareSheetTitle,
                    style: context.textStyles.bodyStrong.copyWith(
                      fontSize: KShareSheet.titleSize,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  PositionedDirectional(
                    end: KShareSheet.closeInset - KSpacing.sm,
                    child: IconButton(
                      key: closeKey,
                      tooltip: l10n.liveClose,
                      onPressed: close,
                      icon: FeedGlyphIcon(
                        FeedGlyph.close,
                        size: KShareSheet.closeIcon,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            row(friendsKey, [
              for (final f in shareFriendsFixture(ar: ar))
                _ShareItem(
                  label: f.name,
                  gap: KShareSheet.friendLabelGap,
                  onTap: close,
                  tile: KAvatar(name: f.name, size: KShareSheet.itemTile),
                ),
            ]),
            Divider(height: 0.5, thickness: 0.5, color: p.border),
            row(actionsKey, [
              action(
                l10n.shareRepost,
                AppIcons.repost,
                fill: p.warning,
                ink: p.onPrimary,
              ),
              action(
                l10n.shareCopyLink,
                AppIcons.link,
                fill: p.info,
                ink: p.onPrimary,
              ),
              action(
                l10n.shareSend,
                AppIcons.send,
                fill: p.success,
                ink: p.onPrimary,
              ),
              action(
                l10n.livePreviewMore,
                AppIcons.moreHoriz,
                fill: p.surfaceOverlay,
                ink: p.textPrimary,
              ),
            ]),
            row(toolsKey, [
              action(
                l10n.shareSaveVideo,
                AppIcons.download,
                fill: p.surface,
                ink: p.textPrimary,
              ),
              _ShareItem(
                label: l10n.shareReport,
                gap: KShareSheet.actionLabelGap,
                onTap: close,
                tile: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.outlined_flag_rounded,
                    size: KShareSheet.actionIcon,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ShareItem extends StatelessWidget {
  const new({
    required this.label,
    required this.tile,
    required this.gap,
    required this.onTap,
  });

  final String label;
  final Widget tile;
  final double gap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KRadius.sm),
      child: SizedBox(
        width: KShareSheet.itemWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: KSpacing.sm,
          ),
          child: Column(
            children: [
              SizedBox.square(dimension: KShareSheet.itemTile, child: tile),
              SizedBox(height: gap),
              SizedBox(
                width: KShareSheet.labelWidth,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    fontSize: KShareSheet.labelSize,
                    color: context.palette.textSecondary,
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
