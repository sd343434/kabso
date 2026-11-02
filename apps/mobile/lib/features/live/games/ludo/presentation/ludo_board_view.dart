import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_board.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';
import 'package:kabso_live/features/live/games/ludo/presentation/ludo_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the Ludo board (tests).
abstract final class LudoKeys {
  static const board = Key('ludo.board');
  static const die = Key('ludo.die');
  static const panel = Key('ludo.panel');
  static const close = Key('ludo.close');
  static const collapse = Key('ludo.collapse');
  static const status = Key('ludo.status');
  static const start = Key('ludo.start');
  static const winner = Key('ludo.winner');
  static const banner = Key('ludo.banner');
  static const rank = Key('ludo.rank');
  static const toast = Key('ludo.toast');
  static Key piece(int seat, int index) => Key('ludo.piece.$seat.$index');
  static Key chip(int seat) => Key('ludo.chip.$seat');
  static Key tabs(int seat) => Key('ludo.tabs.$seat');
}

/// The player label of a seat: «اللاعب 1» … «اللاعب 4».
String ludoPlayerLabel(AppLocalizations l10n, int seat) =>
    l10n.ludoPlayer('${seat + 1}');

/// The name of a seat's player (their display name, else the seat label).
String ludoSeatName(AppLocalizations l10n, LudoGame game, int seat) {
  final name = game.seatAt(seat)?.user?.displayName.trim() ?? '';
  return name.isEmpty ? ludoPlayerLabel(l10n, seat) : name;
}

/// D168: the board of the prototype with the pieces, the die on the base
/// of the seat whose turn it is, the six-counter tabs and the player chips
/// on its edges. Moves are animated square by square from the server's
/// `events`; the server's pieces are always the end state.
class LudoBoardView extends StatefulWidget {
  const new({
    required this.game,
    required this.size,
    this.turnLeft,
    this.onRoll,
    this.onMove,
    this.onSeat,
    super.key,
  });

  final LudoGame game;

  /// The board's side; chips reach past it on the left and right.
  final double size;

  /// The time left of the turn now.
  final Duration Function()? turnLeft;

  /// This phone may roll now.
  final VoidCallback? onRoll;

  /// This phone may move one of [LudoGame.movable] now.
  final ValueChanged<int>? onMove;

  /// The lobby: this phone may sit on a free seat.
  final ValueChanged<int>? onSeat;

  /// One step of a piece.
  static const hop = Duration(milliseconds: 170);

  @override
  State<LudoBoardView> createState() => _LudoBoardViewState();
}

class _LudoBoardViewState extends State<LudoBoardView>
    with SingleTickerProviderStateMixin {
  late Map<int, List<int>> _shown = _piecesOf(widget.game);
  late int _version = widget.game.version;
  late String _id = widget.game.id;
  Future<void> _queue = Future.value();
  int? _face;
  bool _rolling = false;
  String? _toast;
  Color _toastColor = Colors.white;
  Timer? _toastTimer;
  late final AnimationController _ring = AnimationController(vsync: this);
  final _random = math.Random();

  bool get _animate => !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  static Map<int, List<int>> _piecesOf(LudoGame game) => {
    for (final s in game.seats) s.seat: [...s.pieces],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRing();
  }

  @override
  void didUpdateWidget(LudoBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final game = widget.game;
    if (game.id != _id) {
      _id = game.id;
      _version = game.version;
      _shown = _piecesOf(game);
      _syncRing();
      return;
    }
    if (game.version > _version) {
      _version = game.version;
      _queue = _queue.then((_) => _play(game));
      _syncRing();
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  void _syncRing() {
    final game = widget.game;
    final left = widget.turnLeft?.call() ?? Duration.zero;
    final total = Duration(seconds: game.turnSeconds);
    if (game.status != LudoStatus.playing || left == Duration.zero) {
      _ring.value = 0;
      return;
    }
    _ring.value = (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    if (_animate) unawaited(_ring.animateTo(0, duration: left));
  }

  Future<void> _wait(Duration d) =>
      _animate ? Future<void>.delayed(d) : Future<void>.value();

  /// Plays the [game]'s events, then shows its pieces.
  Future<void> _play(LudoGame game) async {
    final l10n = context.l10n;
    for (final e in game.events) {
      if (!mounted) return;
      switch (e.kind) {
        case LudoEvent.roll when _animate:
          setState(() => _rolling = true);
          for (var k = 0; k < 7; k++) {
            if (!mounted) return;
            setState(() => _face = 1 + _random.nextInt(6));
            await _wait(const Duration(milliseconds: 55));
          }
          if (!mounted) return;
          setState(() {
            _rolling = false;
            _face = e.dice;
          });
        case LudoEvent.move:
          await _move(e);
          if (!mounted) return;
          final seat = e.seat ?? 0;
          if (e.captured.isNotEmpty) {
            final other = e.captured.first.seat;
            _say(
              l10n.ludoCaptured(
                ludoSeatName(l10n, game, seat),
                ludoSeatName(l10n, game, other),
              ),
              LudoBoard.colors[seat],
            );
          } else if (e.reached) {
            _say(
              l10n.ludoArrived(ludoSeatName(l10n, game, seat)),
              LudoBoard.colors[seat],
            );
          }
        default:
          break;
      }
    }
    if (!mounted) return;
    setState(() {
      _face = null;
      _shown = _piecesOf(widget.game);
    });
  }

  Future<void> _move(LudoEvent e) async {
    final seat = e.seat;
    final piece = e.piece;
    final from = e.from;
    final to = e.to;
    if (seat == null || piece == null || from == null || to == null) return;
    final pieces = _shown[seat];
    if (pieces == null || piece >= pieces.length) return;
    final path = from < 0 ? [to] : [for (var s = from + 1; s <= to; s++) s];
    for (final step in path) {
      if (!mounted) return;
      setState(() => pieces[piece] = step);
      await _wait(LudoBoardView.hop);
    }
    if (e.captured.isEmpty) return;
    await _wait(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() {
      for (final c in e.captured) {
        final theirs = _shown[c.seat];
        if (theirs != null && c.piece < theirs.length) theirs[c.piece] = -1;
      }
    });
    await _wait(const Duration(milliseconds: 250));
  }

  void _say(String text, Color color) {
    _toastTimer?.cancel();
    setState(() {
      _toast = text;
      _toastColor = color;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final game = widget.game;
    final u = widget.size / LudoBoard.cells;
    final duration = _animate
        ? const Duration(milliseconds: 160)
        : Duration.zero;
    final movable = widget.onMove == null ? const <int>[] : game.movable;
    final playing = game.status == LudoStatus.playing;

    // Pieces sharing a square sit round it, smaller (the prototype).
    final groups = <String, List<(int, int)>>{};
    for (final s in game.seats) {
      final shown = _shown[s.seat] ?? s.pieces;
      for (var i = 0; i < shown.length; i++) {
        final step = shown[i];
        final key = step < 0
            ? 'b${s.seat}.$i'
            : step >= LudoBoard.finish
            ? 'f${s.seat}'
            : '${LudoBoard.cellOf(s.seat, step, i)}';
        (groups[key] ??= []).add((s.seat, i));
      }
    }
    final pieces = <Widget>[];
    final front = <Widget>[];
    for (final list in groups.values) {
      for (final (k, (seat, i)) in list.indexed) {
        final step = (_shown[seat] ?? const [])[i];
        var at = LudoBoard.cellOf(seat, step, i);
        var d = step < 0 ? 1.32 : 0.86;
        if (list.length > 1) {
          final a = k / list.length * math.pi * 2;
          at += Offset(math.cos(a) * 0.2, math.sin(a) * 0.2);
          d = 0.62;
        }
        final mine = movable.contains(i) && game.turn == seat;
        final where = step < 0
            ? l10n.ludoInBase
            : step >= LudoBoard.finish
            ? l10n.ludoAtHome
            : l10n.ludoOnBoard;
        final piece = AnimatedPositioned(
          key: LudoKeys.piece(seat, i),
          duration: duration,
          curve: Curves.easeOut,
          left: at.dx * u - d * u / 2,
          top: at.dy * u - d * u / 2,
          width: d * u,
          height: d * u,
          child: Semantics(
            container: true,
            label: l10n.ludoPiece(ludoPlayerLabel(l10n, seat), '${i + 1}', where),
            button: mine,
            onTap: mine ? () => _tapPiece(i) : null,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: mine ? () => _tapPiece(i) : null,
              child: _Piece(color: LudoBoard.colors[seat], glow: mine),
            ),
          ),
        );
        (mine ? front : pieces).add(piece);
      }
    }

    final turn = game.turn;
    final (dieRow, dieCol) = LudoBoard.dieAt[turn ?? game.seats.first.seat];
    final dieSize = 1.55 * u;
    final face = _face ?? game.dice ?? 6;
    final canRoll = widget.onRoll != null && !_rolling;

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              label: l10n.ludoBoard,
              container: true,
              child: const CustomPaint(
                key: LudoKeys.board,
                painter: LudoBoardPainter(),
              ),
            ),
          ),
          for (final s in game.seats)
            if (playing) _tabs(s.seat, u),
          ...pieces,
          ...front,
          if (playing)
            AnimatedPositioned(
              key: LudoKeys.die,
              duration: _animate
                  ? const Duration(milliseconds: 300)
                  : Duration.zero,
              left: dieCol * u - dieSize / 2,
              top: dieRow * u - dieSize / 2,
              width: dieSize,
              height: dieSize,
              child: Semantics(
                container: true,
                button: canRoll,
                label: canRoll ? l10n.ludoRollDie : l10n.ludoDieValue('$face'),
                onTap: canRoll ? _tapRoll : null,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: canRoll ? _tapRoll : null,
                  child: _Die(
                    face: face,
                    ready: canRoll,
                    rolling: _rolling,
                    pulse: _animate,
                  ),
                ),
              ),
            ),
          for (final s in game.seats) _chip(s, u),
          if (_toast case final text?)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _Toast(key: LudoKeys.toast, text: text, color: _toastColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _tapRoll() {
    unawaited(HapticFeedback.mediumImpact());
    widget.onRoll?.call();
  }

  void _tapPiece(int piece) {
    unawaited(HapticFeedback.selectionClick());
    widget.onMove?.call(piece);
  }

  Widget _tabs(int seat, double u) {
    final (row, col, fromStart) = LudoBoard.tabsAt[seat];
    final on = widget.game.turn == seat ? widget.game.sixes : 0;
    return Positioned(
      key: LudoKeys.tabs(seat),
      left: col * u,
      top: row * u - 8,
      width: 2.2 * u,
      height: 16,
      child: ExcludeSemantics(
        child: Row(
          textDirection: TextDirection.ltr,
          mainAxisAlignment: fromStart
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            for (var j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: 3),
              _SixTab(on: j < on),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(LudoSeat seat, double u) {
    final l10n = context.l10n;
    final game = widget.game;
    final (row, col) = LudoBoard.chipAt[seat.seat];
    final color = LudoBoard.colors[seat.seat];
    final active = game.status == LudoStatus.playing && game.turn == seat.seat;
    final user = seat.user;
    final free = user == null;
    final onSeat = widget.onSeat;
    final label = ludoPlayerLabel(l10n, seat.seat);
    const width = 76.0;
    const avatar = 46.0;
    Widget face;
    if (free) {
      face = Container(
        width: avatar,
        height: avatar,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x66FFFFFF),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Icon(
          onSeat == null ? Icons.event_seat_outlined : Icons.add_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    } else {
      face = Container(
        width: avatar,
        height: avatar,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            const BoxShadow(
              color: Color(0x59000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            if (active) BoxShadow(color: color, blurRadius: 16, spreadRadius: 3),
          ],
        ),
        child: KAvatar(
          name: user.displayName,
          imageUrl: user.avatarUrl,
          size: avatar - 6,
        ),
      );
    }
    final semantics = free
        ? '$label, ${l10n.ludoFreeSeat}'
        : '$label, ${ludoSeatName(l10n, game, seat.seat)}'
              '${seat.auto ? ', AUTO' : ''}';
    return Positioned(
      key: LudoKeys.chip(seat.seat),
      left: col * u - width / 2,
      top: row * u - avatar / 2 - 6,
      width: width,
      child: Semantics(
        container: true,
        label: semantics,
        button: free && onSeat != null,
        onTap: free && onSeat != null ? () => onSeat(seat.seat) : null,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: free && onSeat != null ? () => onSeat(seat.seat) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: avatar + 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (active)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _ring,
                          builder: (context, _) => CustomPaint(
                            painter: LudoRingPainter(
                              left: _ring.value,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    face,
                    if (seat.auto)
                      Positioned(
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AUTO',
                            style: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 8,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xB81A1440),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  free && onSeat != null ? l10n.ludoSit : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A piece: the airplane on a white disc ringed in its colour.
class _Piece extends StatelessWidget {
  const new({required this.color, required this.glow});

  final Color color;

  /// This phone may move it now.
  final bool glow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white,
          Colors.white,
          color,
          color,
          LudoArt.mix(color, -0.3),
        ],
        stops: const [0, 0.55, 0.57, 0.74, 0.76],
      ),
      boxShadow: [
        BoxShadow(color: LudoArt.mix(color, -0.45), offset: const Offset(0, 2)),
        const BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
        if (glow) ...const [
          BoxShadow(color: Colors.white, spreadRadius: 3),
          BoxShadow(color: Colors.white, blurRadius: 14, spreadRadius: 4),
        ],
      ],
    ),
    child: FractionallySizedBox(
      widthFactor: 0.58,
      heightFactor: 0.58,
      child: CustomPaint(painter: LudoPlanePainter(color)),
    ),
  );
}

/// The die: white rounded square with pips (red for a six); it glows on
/// the base of the player who may roll now.
class _Die extends StatefulWidget {
  const new({
    required this.face,
    required this.ready,
    required this.rolling,
    required this.pulse,
  });

  final int face;
  final bool ready;
  final bool rolling;

  /// Animations are on (the glow breathes, the die spins).
  final bool pulse;

  static const _pips = <int, List<int>>{
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  State<_Die> createState() => _DieState();
}

class _DieState extends State<_Die> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Die oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulse && (widget.ready || widget.rolling)) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat());
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _Die._pips[widget.face.clamp(1, 6)]!;
    final pip = widget.face == 6
        ? const Color(0xFFE5414A)
        : const Color(0xFF1C2233);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth;
        final die = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(side * 0.22),
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.5),
              colors: [Colors.white, Color(0xFFF1F4FA), Color(0xFFCCD5E6)],
              stops: [0, 0.55, 1],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0xFF9AA6BF), offset: Offset(0, 4)),
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(side * 0.17),
            child: GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < 9; i++)
                  Center(
                    child: on.contains(i)
                        ? Container(
                            width: side * 0.15,
                            height: side * 0.15,
                            decoration: BoxDecoration(
                              color: pip,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            final glow = math.sin(t * math.pi);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.ready)
                  Positioned(
                    left: -side * 0.35 - glow * side * 0.08,
                    top: -side * 0.35 - glow * side * 0.08,
                    right: -side * 0.35 - glow * side * 0.08,
                    bottom: -side * 0.35 - glow * side * 0.08,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xBFFFFFFF), Color(0x00FFFFFF)],
                          stops: [0, 0.65],
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Transform.rotate(
                    angle: widget.rolling ? t * 2 * math.pi * 2 : 0,
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: die,
        );
      },
    );
  }
}

/// One of the three six-counter tabs by a base.
class _SixTab extends StatelessWidget {
  const new({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(color: Color(0xFFD4D4E6), offset: Offset(0, 2)),
      ],
    ),
    alignment: Alignment.center,
    child: Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0xFFE5414A) : const Color(0xFFE9E9F2),
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  const new({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xEB1A1440),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color, width: 2),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
