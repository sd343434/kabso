import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Asset paths of the owner-supplied app icon set (`assets/icons/`, 24-unit
/// SVGs). D56: the owner's Kabso set (`<name>_outline.svg` before a tap,
/// `<name>_filled.svg` after, 2-unit round strokes) replaces the earlier
/// icons wherever it has one; the rest keep their earlier files. Outline
/// icons draw in `currentColor` and are tinted by [AppIcon]; the multicolour
/// ones ([createButton], [createButtonLight], [followBadge], [coinGold])
/// keep their own colours (`tint: false`).
abstract final class AppIcons {
  static const String _p = 'assets/icons';

  /// D64: provider glyphs on the (not yet working) social sign-in buttons;
  /// Simple Icons (CC0) placeholders until the official button assets.
  static const String google = '$_p/brand/google.svg';
  static const String apple = '$_p/brand/apple.svg';
  static const String home = '$_p/home_outline.svg';
  static const String homeFilled = '$_p/home_filled.svg';
  static const String friends = '$_p/users_outline.svg';
  static const String friendsFilled = '$_p/users_filled.svg';
  static const String inbox = '$_p/inbox_outline.svg';
  static const String inboxFilled = '$_p/inbox_filled.svg';
  static const String profile = '$_p/profile_outline.svg';
  static const String profileFilled = '$_p/profile_filled.svg';
  static const String plus = '$_p/plus.svg';
  static const String createButton = '$_p/create_button.svg';
  static const String createButtonLight = '$_p/create_button_light.svg';
  static const String heart = '$_p/heart_outline.svg';
  static const String heartFilled = '$_p/heart_filled.svg';
  static const String comment = '$_p/comment_outline.svg';
  static const String commentFilled = '$_p/comment_filled.svg';
  static const String bookmark = '$_p/bookmark_outline.svg';
  static const String bookmarkFilled = '$_p/bookmark_filled.svg';
  static const String share = '$_p/share_outline.svg';
  static const String shareFilled = '$_p/share_filled.svg';
  static const String musicDisc = '$_p/music_disc.svg';
  static const String musicNote = '$_p/music_outline.svg';
  static const String followBadge = '$_p/follow_badge.svg';
  static const String repost = '$_p/repost_outline.svg';
  static const String download = '$_p/download.svg';
  static const String link = '$_p/link.svg';
  static const String search = '$_p/search_outline.svg';
  static const String liveTv = '$_p/live_outline.svg';
  static const String close = '$_p/close.svg';
  static const String back = '$_p/back.svg';
  static const String chevronDown = '$_p/chevron_down.svg';
  static const String chevronDownCircle = '$_p/chevron_down_circle.svg';
  static const String moreHoriz = '$_p/more_horiz.svg';
  static const String settings = '$_p/settings_outline.svg';
  static const String checkCircle = '$_p/check_circle.svg';
  static const String send = '$_p/send_outline.svg';
  static const String viewers = '$_p/viewers.svg';
  static const String gift = '$_p/gift_outline.svg';
  static const String giftFilled = '$_p/gift_filled.svg';
  static const String emoji = '$_p/emoji_outline.svg';
  static const String coin = '$_p/coin_outline.svg';
  static const String coinGold = '$_p/coin_gold.svg';
  static const String handWave = '$_p/hand_wave.svg';
  static const String diamond = '$_p/diamond.svg';
  static const String crown = '$_p/crown.svg';
  static const String crownFilled = '$_p/crown_filled.svg';
  static const String mic = '$_p/mic_outline.svg';
  static const String flipCamera = '$_p/flip_outline.svg';
  static const String trophy = '$_p/trophy_outline.svg';

  // KL-056 additions drawn for Kabso in the set's style (24 grid, 1.8 round
  // strokes): the reel badge, post meta and the reel "More" sheet.
  static const String reels = '$_p/reels_outline.svg';
  static const String clock = '$_p/clock.svg';
  static const String location = '$_p/location.svg';
  static const String eyeOff = '$_p/eye_off.svg';
  static const String flag = '$_p/flag_outline.svg';

  // D56 additions from the owner's set.
  static const String play = '$_p/play_filled.svg';
  static const String follow = '$_p/follow_outline.svg';
  static const String followFilled = '$_p/follow_filled.svg';
  static const String grid = '$_p/grid_outline.svg';
  static const String gridFilled = '$_p/grid_filled.svg';
  static const String reelsFilled = '$_p/reels_filled.svg';
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
