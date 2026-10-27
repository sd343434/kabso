import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart' show immutable;

/// `LiveSeatEmoji` (v1.27.5-live, D138, CONVENTIONS §10.30): one of the
/// owner's pack emojis played once on someone's own tile in a room with
/// seats — the answer of `POST /live/rooms/{roomId}/seat-emoji` and the
/// `seat-emoji` data message (topic `seat-emoji`).
@immutable
final class LiveSeatEmoji {
  const new({
    required this.id,
    required this.seat,
    required this.user,
    required this.token,
    required this.createdAt,
  });

  factory fromJson(Map<String, dynamic> json) => LiveSeatEmoji(
    id: json['id']! as String,
    seat: (json['seat']! as num).toInt(),
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    token: json['token']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );

  final String id;

  /// The tile: 0 for the host, else the seat index.
  final int seat;
  final UserSummary user;

  /// `:<pack>_<id>:`.
  final String token;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'seat': seat,
    'user': user.toJson(),
    'token': token,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
