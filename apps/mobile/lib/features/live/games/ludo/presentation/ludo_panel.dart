import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/games/ludo/application/ludo_controller.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_board.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';
import 'package:kabso_live/features/live/games/ludo/presentation/ludo_art.dart';
import 'package:kabso_live/features/live/games/ludo/presentation/ludo_board_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The words for a Ludo intent the server refused.
String ludoFailureText(AppLocalizations l10n, AppFailure failure) {
  final raw = failure is ServerFailure ? failure.rawCode : '';
  return switch (raw) {
    'LUDO_NOT_IN_ROOM' => l10n.ludoErrorNotInRoom,
    'LUDO_SEAT_UNAVAILABLE' => l10n.ludoErrorSeat,
    'LUDO_NOT_STARTABLE' => l10n.ludoErrorNotStartable,
    'LUDO_NOT_YOUR_TURN' || 'LUDO_STALE_VERSION' => l10n.ludoErrorTurn,
    'LUDO_GAME_EXISTS' => l10n.ludoErrorExists,
    _ => failureMessage(l10n, failure),
  };
}

/// D168: the host's «لودو» tool — the room's game when there is one,
/// otherwise the new-round card, then the new game's lobby.
Future<void> openLiveLudo(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
}) async {
  final controller = ref.read(liveLudoProvider(roomId).notifier);
  final game = ref.read(liveLudoProvider(roomId)).game;
  if (game != null && game.isOpen) {
    controller.show();
    return;
  }
  final choice = await showLudoNewRound(context);
  if (choice == null || !context.mounted) return;
  final failure = await controller.create(
    quick: choice.quick,
    players: choice.players,
  );
  if (!context.mounted) return;
  if (failure != null) {
    KSnack.error(context, ludoFailureText(context.l10n, failure));
  } else {
    controller.show();
  }
}

/// The prototype's «جولة جديدة» card: 2 or 4 players, classic or quick.
Future<({bool quick, int players})?> showLudoNewRound(BuildContext context) =>
    showDialog<({bool quick, int players})>(
      context: context,
      barrierColor: const Color(0xA6140A3A),
      builder: (context) => const _NewRoundCard(),
    );

/// D168: the room's Ludo over the lower part of the live room (the
/// stream, the host bar and the seats stay visible above it; the room's
/// action bar stays usable under it). Folds to its bar; closed, a banner
/// offers it again while a game is open.
class LiveLudoLayer extends ConsumerWidget {
  const new({required this.roomId, required this.host, super.key});

  final String roomId;
  final bool host;

  /// Room left for the room's own action bar (chat, gifts) under the
  /// panel.
  static const double barReserve = 52;

  /// The folded panel: its header only.
  static const double foldedHeight = 58;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveLudoProvider(roomId));
    final game = view.game;
    final media = MediaQuery.of(context);
    final bottom = media.padding.bottom + barReserve;
    if (game == null || (!view.shown && !game.isOpen)) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }
    if (!view.shown) {
      final me = ref.watch(currentUserProvider)?.id;
      final canJoin =
          game.status == LudoStatus.lobby &&
          game.seatOf(me) == null &&
          game.seated < game.maxPlayers;
      return PositionedDirectional(
        start: KSpacing.md,
        bottom: bottom + KSpacing.sm,
        child: _Banner(
          label: canJoin
              ? context.l10n.ludoBannerJoin
              : context.l10n.ludoBannerWatch,
          onTap: ref.read(liveLudoProvider(roomId).notifier).show,
        ),
      );
    }
    final h = media.size.height;
    final open = math.max(
      300,
      math.min(h * 0.58, h - 150 - bottom),
    ).toDouble();
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return AnimatedPositioned(
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
      curve: Curves.easeOut,
      left: 4,
      right: 4,
      bottom: bottom,
      height: view.collapsed ? foldedHeight : open,
      child: LudoPanel(roomId: roomId, host: host),
    );
  }
}

/// The light-blue panel: close, the rank pill and fold on top; the board
/// with the players on its edges; the status line.
class LudoPanel extends ConsumerWidget {
  const new({required this.roomId, required this.host, super.key});

  final String roomId;
  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(liveLudoProvider(roomId));
    final controller = ref.read(liveLudoProvider(roomId).notifier);
    final game = view.game;
    if (game == null) return const SizedBox.shrink();
    final me = ref.watch(currentUserProvider)?.id;
    final mine = game.seatOf(me);
    final playing = game.status == LudoStatus.playing;
    final myTurn = playing && mine != null && game.turn == mine.seat;
    final idle = !view.busy;

    Future<void> run(Future<AppFailure?> Function() intent) async {
      final failure = await intent();
      if (failure != null && context.mounted) {
        KSnack.error(context, ludoFailureText(l10n, failure));
      }
    }

    return Semantics(
      container: true,
      label: l10n.ludoTitle,
      child: Container(
        key: LudoKeys.panel,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LudoArt.panelTop, LudoArt.panelMiddle, LudoArt.panelEdge],
            stops: [0, 0.6, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                children: [
                  _Header(
                    game: game,
                    collapsed: view.collapsed,
                    onClose: () => unawaited(_close(context, ref, game, mine)),
                    onFold: controller.toggleCollapsed,
                  ),
                  if (!view.collapsed) ...[
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math
                              .min(box.maxWidth - 52, box.maxHeight - 44)
                              .clamp(160.0, 400.0);
                          return Directionality(
                            textDirection: TextDirection.ltr,
                            child: Center(
                              child: LudoBoardView(
                                game: game,
                                size: side,
                                turnLeft: () => view.turnLeft(clock.now()),
                                onRoll:
                                    myTurn &&
                                        game.phase == LudoPhase.roll &&
                                        idle
                                    ? () => unawaited(run(controller.roll))
                                    : null,
                                onMove:
                                    myTurn &&
                                        game.phase == LudoPhase.move &&
                                        idle
                                    ? (piece) => unawaited(
                                        run(() => controller.move(piece)),
                                      )
                                    : null,
                                onSeat:
                                    game.status == LudoStatus.lobby &&
                                        me != null &&
                                        mine == null &&
                                        idle
                                    ? (seat) => unawaited(
                                        run(() => controller.takeSeat(seat)),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _StatusLine(
                      text: _status(l10n, game, mine, spectator: mine == null),
                    ),
                    if (host && game.status == LudoStatus.lobby)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _PrimaryButton(
                          key: LudoKeys.start,
                          label: l10n.ludoStart,
                          onTap: game.seated >= 2 && idle
                              ? () => unawaited(run(controller.start))
                              : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (game.status == LudoStatus.finished && !view.collapsed)
              Positioned.fill(
                child: _WinnerCard(
                  game: game,
                  me: me,
                  host: host,
                  onDone: controller.hide,
                  onNewRound: () {
                    controller.hide();
                    unawaited(openLiveLudo(context, ref, roomId: roomId));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ✕: the host ends the game for everyone; a player leaves (the server
  /// plays their seat once started); a spectator just closes the panel.
  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    LudoGame game,
    LudoSeat? mine,
  ) async {
    final l10n = context.l10n;
    final controller = ref.read(liveLudoProvider(roomId).notifier);
    if (!game.isOpen) {
      controller.hide();
      return;
    }
    if (host) {
      final ok = await _confirm(context, l10n.ludoEndConfirm, l10n.ludoEnd);
      if (!ok || !context.mounted) return;
      final failure = await controller.end();
      if (!context.mounted) return;
      if (failure != null) {
        KSnack.error(context, ludoFailureText(l10n, failure));
        return;
      }
      controller.hide();
      return;
    }
    if (mine != null) {
      final ok = await _confirm(
        context,
        game.status == LudoStatus.lobby
            ? l10n.ludoLeaveLobbyConfirm
            : l10n.ludoLeaveConfirm,
        l10n.ludoLeave,
      );
      if (!ok || !context.mounted) return;
      final failure = await controller.leaveSeat(mine.seat);
      if (failure != null && context.mounted) {
        KSnack.error(context, ludoFailureText(l10n, failure));
      }
    }
    controller.hide();
  }

  Future<bool> _confirm(BuildContext context, String text, String action) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ludoCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// The status line under the board.
String _status(
  AppLocalizations l10n,
  LudoGame game,
  LudoSeat? mine, {
  required bool spectator,
}) {
  switch (game.status) {
    case LudoStatus.lobby:
      return l10n.ludoWaiting('${game.seated}', '${game.maxPlayers}');
    case LudoStatus.finished:
      final w = game.winner;
      return w == null ? l10n.ludoEnded : l10n.ludoWon(ludoSeatName(l10n, game, w));
    case LudoStatus.ended:
      return l10n.ludoEnded;
    case LudoStatus.playing:
      break;
  }
  final turn = game.turn;
  if (turn == null) return '';
  for (final e in game.events) {
    final seat = e.seat;
    if (seat == null || seat == turn) continue;
    if (e.kind == LudoEvent.threeSixes) {
      return l10n.ludoThreeSixes(ludoSeatName(l10n, game, seat));
    }
    if (e.kind == LudoEvent.noMove) {
      return l10n.ludoNoMove(ludoSeatName(l10n, game, seat), '${e.dice}');
    }
  }
  if (mine != null && mine.seat == turn) {
    if (game.phase == LudoPhase.move) return l10n.ludoChoose('${game.dice}');
    final extra = game.events.any(
      (e) => e.seat == turn && e.kind == LudoEvent.move,
    );
    return extra ? l10n.ludoExtraTurn : l10n.ludoYourTurn;
  }
  final name = ludoSeatName(l10n, game, turn);
  return spectator
      ? '${l10n.ludoTurnOf(name)} · ${l10n.ludoSpectating}'
      : l10n.ludoTurnOf(name);
}

class _StatusLine extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        key: LudoKeys.status,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: LudoArt.status,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Close, the rank pill (the two leading seats' progress points) and fold.
class _Header extends StatelessWidget {
  const new({
    required this.game,
    required this.collapsed,
    required this.onClose,
    required this.onFold,
  });

  final LudoGame game;
  final bool collapsed;
  final VoidCallback onClose;
  final VoidCallback onFold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ranked = [
      for (final s in game.seats) LudoBoard.points(s.pieces),
    ]..sort((a, b) => b.compareTo(a));
    final first = ranked.isEmpty ? 0 : ranked[0];
    final second = ranked.length < 2 ? 0 : ranked[1];
    const label = TextStyle(
      color: LudoArt.gold,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    const value = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          _RoundButton(
            key: LudoKeys.close,
            icon: Icons.close_rounded,
            label: l10n.ludoClose,
            onTap: onClose,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              key: LudoKeys.rank,
              label: l10n.ludoRankLabel('$first', '$second'),
              excludeSemantics: true,
              child: Container(
                height: 36,
                padding: const EdgeInsets.only(left: 6, right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [LudoArt.rankTop, LudoArt.rankBottom],
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -4),
                      child: const SizedBox(
                        width: 44,
                        height: 40,
                        child: CustomPaint(painter: LudoChestPainter()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            const Text('RANK 1', style: label),
                            const SizedBox(width: 8),
                            Text('$first', style: value),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            const Text('RANK 2', style: label),
                            const SizedBox(width: 8),
                            Text('$second', style: value),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            key: LudoKeys.collapse,
            icon: collapsed
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            label: collapsed ? l10n.ludoExpand : l10n.ludoCollapse,
            onTap: onFold,
          ),
        ],
      ),
    );
  }
}

/// The prototype's glossy round button (34 pt).
class _RoundButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(
        dimension: 38,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.2, -0.4),
                colors: [Color(0xFF8FD8FF), Color(0xFF2B8BE0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}

/// The prototype's yellow button.
class _PrimaryButton extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE27A), Color(0xFFFFC21A)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0xFFD99A00), offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A3A00),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The banner over the room while a game is open and the panel is closed.
class _Banner extends StatelessWidget {
  const new({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: LudoKeys.banner,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.pill),
          gradient: const LinearGradient(
            colors: [LudoArt.panelTop, LudoArt.panelEdge],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.casino_rounded,
                size: 20,
                color: LudoArt.panelEdge,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: LudoArt.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The prototype's card style.
BoxDecoration _cardDecoration() => const BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(22)),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFA8DBFF), Color(0xFF5AAEF6)],
  ),
  boxShadow: [
    BoxShadow(color: Color(0x80000000), blurRadius: 50, offset: Offset(0, 20)),
  ],
);

/// The winner: their picture, «فاز …» (or «فزت بالجولة!»), and for the
/// host a new round.
class _WinnerCard extends StatelessWidget {
  const new({
    required this.game,
    required this.me,
    required this.host,
    required this.onDone,
    required this.onNewRound,
  });

  final LudoGame game;
  final String? me;
  final bool host;
  final VoidCallback onDone;
  final VoidCallback onNewRound;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seat = game.winner ?? 0;
    final winner = game.seatAt(seat);
    final user = winner?.user;
    final mine = user != null && user.id == me;
    final color = LudoBoard.colors[seat];
    return ColoredBox(
      color: const Color(0xA6140A3A),
      child: Center(
        child: Container(
          key: LudoKeys.winner,
          width: 300,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 24),
                  ],
                ),
                child: user == null
                    ? null
                    : KAvatar(
                        name: user.displayName,
                        imageUrl: user.avatarUrl,
                        size: 64,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                mine
                    ? l10n.ludoYouWon
                    : l10n.ludoWon(ludoSeatName(l10n, game, seat)),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LudoArt.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.ludoWonBody(ludoPlayerLabel(l10n, seat)),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF123A6B),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryButton(
                label: host ? l10n.ludoNewRound : l10n.ludoOk,
                onTap: host ? onNewRound : onDone,
              ),
              if (host)
                TextButton(onPressed: onDone, child: Text(l10n.ludoCancel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewRoundCard extends StatefulWidget {
  const new();

  @override
  State<_NewRoundCard> createState() => _NewRoundCardState();
}

class _NewRoundCardState extends State<_NewRoundCard> {
  int _players = 4;
  bool _quick = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const ink = Color(0xFF123A6B);
    Widget choice({
      required String title,
      required String hint,
      required bool selected,
      required VoidCallback onTap,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$title, $hint',
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? const Color(0xFF1E6CC0)
                  : const Color(0xB3FFFFFF),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : LudoArt.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFD6EAFF)
                        : const Color(0xFF3A5A86),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    const caption = TextStyle(
      color: ink,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 320,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.ludoNewRound,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LudoArt.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${l10n.ludoIntro} ${l10n.ludoFree}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ink, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 12),
              Text(l10n.ludoPlayersTitle, style: caption),
              const SizedBox(height: 6),
              Row(
                children: [
                  choice(
                    title: l10n.ludoTwoPlayers,
                    hint: l10n.ludoTwoPlayersHint,
                    selected: _players == 2,
                    onTap: () => setState(() => _players = 2),
                  ),
                  const SizedBox(width: 6),
                  choice(
                    title: l10n.ludoFourPlayers,
                    hint: l10n.ludoFourPlayersHint,
                    selected: _players == 4,
                    onTap: () => setState(() => _players = 4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.ludoModeTitle, style: caption),
              const SizedBox(height: 6),
              Row(
                children: [
                  choice(
                    title: l10n.ludoClassic,
                    hint: l10n.ludoClassicHint,
                    selected: !_quick,
                    onTap: () => setState(() => _quick = false),
                  ),
                  const SizedBox(width: 6),
                  choice(
                    title: l10n.ludoQuick,
                    hint: l10n.ludoQuickHint,
                    selected: _quick,
                    onTap: () => setState(() => _quick = true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: _PrimaryButton(
                  label: l10n.ludoOpen,
                  onTap: () => Navigator.of(
                    context,
                  ).pop((quick: _quick, players: _players)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
