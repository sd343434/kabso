import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/shared_models.dart';

/// `LiveLudoGame.status` (v1.45-live, D168, CONVENTIONS §10.42).
enum LudoStatus { lobby, playing, finished, ended }

/// `LiveLudoGame.phase`: rolling, or choosing a piece.
enum LudoPhase { roll, move }

LudoStatus _status(String raw) => switch (raw) {
  'LOBBY' => LudoStatus.lobby,
  'PLAYING' => LudoStatus.playing,
  'FINISHED' => LudoStatus.finished,
  _ => LudoStatus.ended,
};

LudoPhase? _phase(Object? raw) => switch (raw) {
  'ROLL' => LudoPhase.roll,
  'MOVE' => LudoPhase.move,
  _ => null,
};

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

List<int> _ints(Object? raw) => [
  for (final v in raw is List<dynamic> ? raw : const <dynamic>[])
    (v as num).toInt(),
];

/// `LiveLudoCapture`: a piece a move sent back to its base.
@immutable
final class LudoCapture {
  const new({required this.seat, required this.piece, required this.from});

  factory fromJson(Map<String, dynamic> json) => LudoCapture(
    seat: (json['seat']! as num).toInt(),
    piece: (json['piece']! as num).toInt(),
    from: (json['from']! as num).toInt(),
  );

  final int seat;
  final int piece;
  final int from;
}

/// `LiveLudoEvent`: what the server's last change did, in order (the app
/// animates them). Kinds this build does not know are kept and ignored.
@immutable
final class LudoEvent {
  const new({
    required this.kind,
    this.seat,
    this.dice,
    this.piece,
    this.from,
    this.to,
    this.auto = false,
    this.reached = false,
    this.captured = const [],
    this.reason,
  });

  factory fromJson(Map<String, dynamic> json) => LudoEvent(
    kind: json['kind']! as String,
    seat: _int(json['seat']),
    dice: _int(json['dice']),
    piece: _int(json['piece']),
    from: _int(json['from']),
    to: _int(json['to']),
    auto: json['auto'] as bool? ?? false,
    reached: json['reached'] as bool? ?? false,
    captured: [
      for (final c in json['captured'] as List<dynamic>? ?? const [])
        LudoCapture.fromJson(c as Map<String, dynamic>),
    ],
    reason: json['reason'] as String?,
  );

  static const roll = 'ROLL';
  static const move = 'MOVE';
  static const noMove = 'NO_MOVE';
  static const threeSixes = 'THREE_SIXES';
  static const autoOn = 'AUTO';
  static const win = 'WIN';

  final String kind;
  final int? seat;
  final int? dice;
  final int? piece;
  final int? from;
  final int? to;
  final bool auto;
  final bool reached;
  final List<LudoCapture> captured;
  final String? reason;
}

/// `LiveLudoSeat`: seat 0 red, 1 green, 2 yellow, 3 blue.
@immutable
final class LudoSeat {
  const new({
    required this.seat,
    required this.pieces,
    this.user,
    this.auto = false,
  });

  factory fromJson(Map<String, dynamic> json) => LudoSeat(
    seat: (json['seat']! as num).toInt(),
    user: switch (json['user']) {
      final Map<String, dynamic> u => UserSummary.fromJson(u),
      _ => null,
    },
    auto: json['auto'] as bool? ?? false,
    pieces: _ints(json['pieces']),
  );

  final int seat;

  /// The player; null for a free seat of the lobby.
  final UserSummary? user;

  /// The server plays this seat.
  final bool auto;

  /// Each piece's step: -1 base, 0–51 track, 52–56 home column, 57 home.
  final List<int> pieces;

  /// Pieces that reached home.
  int get home => pieces.where((p) => p >= LudoGame.finish).length;
}

/// `LiveLudoGame`: the server's whole game (D168). The app shows it and
/// sends intents with [version]; it never sends positions.
@immutable
final class LudoGame {
  const new({
    required this.id,
    required this.roomId,
    required this.status,
    required this.quick,
    required this.maxPlayers,
    required this.version,
    required this.seats,
    required this.serverTime,
    this.piecesPerPlayer = 4,
    this.turn,
    this.phase,
    this.dice,
    this.sixes = 0,
    this.movable = const [],
    this.turnEndsAt,
    this.turnSeconds = 15,
    this.winner,
    this.events = const [],
  });

  /// Reads [json]; throws on a malformed one.
  factory fromJson(Map<String, dynamic> json) => LudoGame(
    id: json['id']! as String,
    roomId: json['roomId']! as String,
    status: _status(json['status']! as String),
    quick: json['mode'] == 'QUICK',
    maxPlayers: (json['maxPlayers']! as num).toInt(),
    piecesPerPlayer: _int(json['piecesPerPlayer']) ?? 4,
    version: (json['version']! as num).toInt(),
    seats: [
      for (final s in json['seats']! as List<dynamic>)
        LudoSeat.fromJson(s as Map<String, dynamic>),
    ],
    turn: _int(json['turn']),
    phase: _phase(json['phase']),
    dice: _int(json['dice']),
    sixes: _int(json['sixes']) ?? 0,
    movable: _ints(json['movable']),
    turnEndsAt: switch (json['turnEndsAt']) {
      final String t => DateTime.parse(t),
      _ => null,
    },
    turnSeconds: _int(json['turnSeconds']) ?? 15,
    winner: _int(json['winner']),
    events: [
      for (final e in json['events'] as List<dynamic>? ?? const [])
        LudoEvent.fromJson(e as Map<String, dynamic>),
    ],
    serverTime: DateTime.parse(json['serverTime']! as String),
  );

  /// A piece's step at home (the centre).
  static const finish = 57;

  final String id;
  final String roomId;
  final LudoStatus status;

  /// QUICK (2 pieces each) rather than CLASSIC (4).
  final bool quick;
  final int maxPlayers;
  final int piecesPerPlayer;
  final int version;
  final List<LudoSeat> seats;
  final int? turn;
  final LudoPhase? phase;
  final int? dice;
  final int sixes;
  final List<int> movable;
  final DateTime? turnEndsAt;
  final int turnSeconds;
  final int? winner;
  final List<LudoEvent> events;
  final DateTime serverTime;

  /// In its lobby or playing (the room's current game).
  bool get isOpen => status == LudoStatus.lobby || status == LudoStatus.playing;

  LudoSeat? seatAt(int seat) {
    for (final s in seats) {
      if (s.seat == seat) return s;
    }
    return null;
  }

  /// [userId]'s seat, if they play.
  LudoSeat? seatOf(String? userId) {
    if (userId == null) return null;
    for (final s in seats) {
      if (s.user?.id == userId) return s;
    }
    return null;
  }

  /// How many seats have a player.
  int get seated => seats.where((s) => s.user != null).length;

  /// The seat whose turn it is.
  LudoSeat? get current => turn == null ? null : seatAt(turn!);
}
