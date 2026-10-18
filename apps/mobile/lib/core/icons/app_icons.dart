import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Asset paths of the owner-supplied app icon set (`assets/icons/`, 24-unit
/// SVGs). Outline icons draw in `currentColor` and are tinted by [AppIcon];
/// the multicolour ones ([createButton], [createButtonLight], [followBadge],
/// [coinGold]) keep their own colours (`tint: false`).
abstract final class AppIcons {
  static const String _p = 'assets/icons';
  static const String home = '$_p/home.svg';
  static const String homeFilled = '$_p/home_filled.svg';
  static const String friends = '$_p/friends.svg';
  static const String friendsFilled = '$_p/friends_filled.svg';
  static const String inbox = '$_p/inbox.svg';
  static const String inboxFilled = '$_p/inbox_filled.svg';
  static const String profile = '$_p/profile.svg';
  static const String profileFilled = '$_p/profile_filled.svg';
  static const String plus = '$_p/plus.svg';
  static const String createButton = '$_p/create_button.svg';
  static const String createButtonLight = '$_p/create_button_light.svg';
  static const String heart = '$_p/heart.svg';
  static const String heartFilled = '$_p/heart_filled.svg';
  static const String comment = '$_p/comment.svg';
  static const String commentFilled = '$_p/comment_filled.svg';
  static const String bookmark = '$_p/bookmark.svg';
  static const String bookmarkFilled = '$_p/bookmark_filled.svg';
  static const String share = '$_p/share.svg';
  static const String shareFilled = '$_p/share_filled.svg';
  static const String musicDisc = '$_p/music_disc.svg';
  static const String musicNote = '$_p/music_note.svg';
  static const String followBadge = '$_p/follow_badge.svg';
  static const String repost = '$_p/repost.svg';
  static const String download = '$_p/download.svg';
  static const String link = '$_p/link.svg';
  static const String search = '$_p/search.svg';
  static const String liveTv = '$_p/live_tv.svg';
  static const String close = '$_p/close.svg';
  static const String back = '$_p/back.svg';
  static const String chevronDown = '$_p/chevron_down.svg';
  static const String chevronDownCircle = '$_p/chevron_down_circle.svg';
  static const String moreHoriz = '$_p/more_horiz.svg';
  static const String settings = '$_p/settings.svg';
  static const String checkCircle = '$_p/check_circle.svg';
  static const String send = '$_p/send.svg';
  static const String viewers = '$_p/viewers.svg';
  static const String gift = '$_p/gift.svg';
  static const String giftFilled = '$_p/gift_filled.svg';
  static const String emoji = '$_p/emoji.svg';
  static const String coin = '$_p/coin.svg';
  static const String coinGold = '$_p/coin_gold.svg';
  static const String handWave = '$_p/hand_wave.svg';
  static const String diamond = '$_p/diamond.svg';
  static const String crown = '$_p/crown.svg';
  static const String crownFilled = '$_p/crown_filled.svg';
  static const String mic = '$_p/mic.svg';
  static const String flipCamera = '$_p/flip_camera.svg';
  static const String trophy = '$_p/trophy.svg';
}

/// Renders an [AppIcons] asset, tinted with [color] (or the ambient
/// [IconTheme] colour). Pass `tint: false` for the multicolour assets.
class AppIcon extends StatelessWidget {
  const new(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.tint = true,
    this.semanticLabel,
  });

  final String asset;
  final double? size;
  final Color? color;
  final bool tint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF000000);
    return SvgPicture.asset(
      asset,
      width: s,
      height: s,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      colorFilter: tint ? ColorFilter.mode(c, BlendMode.srcIn) : null,
    );
  }
}
