// v1.132-social (D379, CONVENTIONS §10.169): the VIP perks inside live
// rooms — the shapes the app reads (pins, the rain effect, the VIP room's
// tier, a kept seat) and the perk codes it acts on.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// D379: the live-room perk codes (D374's catalogue).
abstract final class VipLivePerks {
  static const seatEmoji = 'SEAT_EMOJI';
  static const pinnedMessage = 'PINNED_MESSAGE';
  static const hostGreeting = 'HOST_GREETING';
  static const seatCrown = 'SEAT_CROWN';
  static const bigGiftRain = 'BIG_GIFT_RAIN';
  static const tickerHold = 'TICKER_HOLD';
  static const viewerListPriority = 'VIEWER_LIST_PRIORITY';
  static const seatRequestPriority = 'SEAT_REQUEST_PRIORITY';
  static const vipRoom = 'VIP_ROOM';
  static const seatReserve = 'SEAT_RESERVE';

  /// SEAT_EMOJI's pack token for its [n]-th file (1 …): `:vip_<n>:`.
  static String seatEmojiToken(int n) => ':vip_$n:';

  /// SEAT_EMOJI's art pack: the https files of the perk's value (a list).
  static List<String> artPack(Object? value) => [
    if (value is List)
      for (final v in value)
        if (v is String && v.startsWith('https://')) v,
  ];
}

/// `LiveChatPin` (§10.169.2): a VIP member's own message pinned at the top
/// of the live's chat «رسالة مثبتة» until [until].
@immutable
final class LiveChatPin {
  const new({
    required this.id,
    required this.roomId,
    required this.messageId,
    required this.author,
    required this.text,
    required this.pinnedAt,
    required this.until,
  });

  factory fromJson(Map<String, dynamic> json) => LiveChatPin(
    id: json['id']! as String,
    roomId: json['roomId']! as String,
    messageId: json['messageId']! as String,
    author: UserSummary.fromJson(json['author']! as Map<String, dynamic>),
    text: json['text']! as String,
    pinnedAt: DateTime.parse(json['pinnedAt']! as String),
    until: DateTime.parse(json['until']! as String),
  );

  /// The pin, or null for anything that is not one.
  static LiveChatPin? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return LiveChatPin.fromJson(json);
    } on Object {
      return null;
    }
  }

  final String id;
  final String roomId;
  final String messageId;
  final UserSummary author;

  /// As pinned (the host's blocked words masked).
  final String text;
  final DateTime pinnedAt;
  final DateTime until;

  /// How long it shows in all (the server's seconds, from its own times —
  /// no synced clock needed).
  Duration get length => until.difference(pinnedAt);
}

/// The `vip-rain` data message's `rain` (topic `gift`, §10.169.5):
/// BIG_GIFT_RAIN «مطر عند الهدية الكبيرة» — the effect the owner uploaded
/// for the tier plays over the whole room for [duration] ([animation] SVGA,
/// else [video] MP4, else [still]); without art nothing plays (owner
/// 2026-11-12: no built-in effect).
@immutable
final class VipGiftRain {
  const new({
    required this.giftId,
    required this.roomId,
    required this.sender,
    required this.totalCoins,
    required this.duration,
    this.animation,
    this.still,
    this.video,
  });

  factory fromJson(Map<String, dynamic> json) => VipGiftRain(
    giftId: json['giftId']! as String,
    roomId: json['roomId']! as String,
    sender: UserSummary.fromJson(json['sender']! as Map<String, dynamic>),
    totalCoins: (json['totalCoins']! as num).toInt(),
    duration: Duration(
      milliseconds: ((json['durationMs'] as num?)?.toInt() ?? 4000).clamp(
        1000,
        10000,
      ),
    ),
    animation: json['animation'] as String?,
    still: json['still'] as String?,
    video: json['video'] as String?,
  );

  final String giftId;
  final String roomId;
  final UserSummary sender;
  final int totalCoins;
  final Duration duration;
  final String? animation;
  final String? still;
  final String? video;
}

/// `LiveVipMinTier` (§10.169.9): a VIP room's lowest tier let in.
@immutable
final class LiveVipMinTier {
  const new({required this.code, required this.name, required this.color});

  factory fromJson(Map<String, dynamic> json) => LiveVipMinTier(
    code: json['code']! as String,
    name: json['name']! as String,
    color: json['color']! as String,
  );

  /// Null for anything that is not one (older servers send nothing).
  static LiveVipMinTier? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return LiveVipMinTier.fromJson(json);
    } on Object {
      return null;
    }
  }

  final String code;
  final String name;

  /// `#RRGGBB`.
  final String color;

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'color': color};

  @override
  bool operator ==(Object other) =>
      other is LiveVipMinTier &&
      other.code == code &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(code, name, color);
}

/// `LiveSeatReservation` (§10.169.10): the host keeps this seat for [user]
/// until [until] «قفل المقعد لصديق».
@immutable
final class LiveSeatReservation {
  const new({required this.user, required this.until});

  factory fromJson(Map<String, dynamic> json) => LiveSeatReservation(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    until: DateTime.parse(json['until']! as String),
  );

  final UserSummary user;
  final DateTime until;

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'until': until.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is LiveSeatReservation &&
      other.user == user &&
      other.until == until;

  @override
  int get hashCode => Object.hash(user, until);
}
