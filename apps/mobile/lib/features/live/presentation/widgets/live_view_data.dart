import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:material_ui/material_ui.dart';

/// Presentation-only inputs for the live widgets (KL-022). Production
/// builds cover cards only from API rooms ([LiveRoomCardData.fromSummary]);
/// tests use `test/fixtures/live/` and debug builds use the component
/// gallery.

/// One live room as shown on a cover card.
@immutable
class LiveRoomCardData {
  const new({
    required this.hostName,
    required this.title,
    required this.viewerCount,
    this.cover,
    this.hostAvatar,
    this.inPk = false,
    this.guestCount,
    this.categoryName,
    this.roomId,
  });

  /// A room from `GET /live/rooms` (v1.3): the host's display name and
  /// avatar, the real viewer count (always 0 until presence exists, so the
  /// card shows "New"), the cover when there is one (never in v1.3; the
  /// card then shows the host avatar) and the server-localized category name
  /// when the room has one. Multi-guest rooms carry no guest count in v1.3,
  /// so no seats tag is shown.
  factory fromSummary(LiveRoomSummary room) {
    final cover = room.coverUrl;
    final avatar = room.host.avatarUrl;
    return LiveRoomCardData(
      hostName: room.host.displayName,
      title: room.title,
      viewerCount: room.viewerCount,
      cover: cover == null || cover.isEmpty ? null : _image(cover),
      hostAvatar: avatar == null || avatar.isEmpty ? null : _image(avatar),
      inPk: room.mode == LiveRoomMode.pk,
      categoryName: room.category?.name,
      roomId: room.id,
    );
  }

  /// D86: demo rooms (test builds only) carry `asset:` covers.
  static ImageProvider _image(String url) =>
      kDemoAvailable && url.startsWith('asset:')
      ? AssetImage(url.substring('asset:'.length))
      : NetworkImage(url);

  /// The API room id; `null` for gallery samples and fixtures, which then
  /// open nothing.
  final String? roomId;

  final String hostName;
  final String title;

  /// Below 1 the card shows "New" instead of a count (VG-11).
  final int viewerCount;

  /// `null` (or an image that fails to load) shows the host avatar.
  final ImageProvider? cover;

  /// Host photo for the cover fallback; initials when `null`.
  final ImageProvider? hostAvatar;
  final bool inPk;

  /// Guests on stage in a multi-guest room; `null` when the room is not
  /// multi-guest (no tag is shown).
  final int? guestCount;

  /// The room's category (already localized by the server); `null` when
  /// it has none (nothing is shown).
  final String? categoryName;
}

/// A line in the live chat overlay.
sealed class LiveChatLine {
  const new();
}

final class LiveChatMessage extends LiveChatLine {
  const new({required this.name, required this.text});

  final String name;
  final String text;
}

final class LiveChatJoin extends LiveChatLine {
  const new({required this.name});

  final String name;
}

final class LiveChatGift extends LiveChatLine {
  const new({required this.name, required this.giftName, required this.count});

  final String name;
  final String giftName;
  final int count;
}

/// Moderation / room notices (already localized by the caller).
final class LiveChatSystem extends LiveChatLine {
  const new({required this.text});

  final String text;
}

/// Kabso's own placeholder gift artwork: simple shapes, no third-party art.
enum GiftShape { heart, star, diamond, crown }

@immutable
class GiftItemData {
  const new({
    required this.id,
    required this.name,
    required this.shape,
    this.price,
  });

  final String id;
  final String name;

  /// Coins; shown exactly, never compacted (DESIGN_SYSTEM §3.3). `null`
  /// shows no price: there is no gift catalogue or wallet yet (B5), so
  /// production never shows a price; only fixtures carry one.
  final int? price;
  final GiftShape shape;
}

/// One side of a PK battle (HL-L8), from the host's point of view.
/// Fixture-only until a PK API exists.
@immutable
class PkSideData {
  const new({
    required this.name,
    required this.score,
    this.avatar,
    this.video,
    this.supporters = const [],
  });

  final String name;
  final ImageProvider? avatar;
  final int score;

  /// The pane's video; `null` shows the camera-off fallback.
  final Widget? video;

  /// Top supporters (names), at most 3 shown; nothing when empty.
  final List<String> supporters;
}

/// One seat of a multi-guest room. Fixture-only until a multi-guest API
/// exists.
@immutable
class GuestSeatData {
  const new({
    required this.name,
    this.avatar,
    this.video,
    this.muted = false,
    this.isHost = false,
  });

  final String name;
  final ImageProvider? avatar;
  final Widget? video;
  final bool muted;
  final bool isHost;
}

/// PK outcome from the host's ("start" side) point of view.
enum PkResult { win, lose, draw }

/// Live surfaces are always dark (DESIGN_SYSTEM §2.1), whatever the app
/// theme: this re-themes its subtree with the dark palette.
class KLiveSurface extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return child;
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: child,
    );
  }
}
