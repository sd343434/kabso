import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What this host may do with «جولة أخرى» (D242); null for viewers.
class PkRematchActions {
  const new({
    required this.onOffer,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final Future<void> Function() onOffer;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final Future<void> Function() onCancel;
}

/// v1.55-live (D242, owner: «لا يحتوي pk زر إعادة pk أو لعب جولة أخرى»):
/// «جولة أخرى» in the PK's result for the two hosts, in the D238 dock style
/// (the small white card of the leave prompt, at the bottom of the room):
///
/// - nothing asked yet: «العب جولة أخرى مع @B؟» and the red «جولة أخرى»;
/// - this host asked: «بانتظار @B…» with the answer's ring and «إلغاء»;
/// - the other host asked: «@A يريد جولة أخرى» with the ring, «قبول» and
///   «رفض».
///
/// Nothing for viewers (their «جولة أخرى!» banner is on the stage), during
/// the battle, while a dare runs, or past the limit in a row. The server
/// decides; a refusal shows its message.
class PkRematchDock extends StatefulWidget {
  const new({
    required this.match,
    required this.roomId,
    required this.now,
    required this.actions,
    super.key,
    this.ticks = true,
  });

  final PkMatch match;
  final String roomId;
  final DateTime Function() now;
  final PkRematchActions actions;

  /// The countdown rebuilds every second (off in widget tests and goldens).
  final bool ticks;

  static const cardKey = Key('pk.rematch');
  static const offerKey = Key('pk.rematch.offer');
  static const waitingKey = Key('pk.rematch.waiting');
  static const cancelKey = Key('pk.rematch.cancel');
  static const promptKey = Key('pk.rematch.prompt');
  static const acceptKey = Key('pk.rematch.accept');
  static const declineKey = Key('pk.rematch.decline');

  /// Goldens: the answer's seconds pinned.
  @visibleForTesting
  static int? debugSeconds;

  /// The answer's full time (PK_REMATCH_ACCEPT_SECONDS default) for the ring.
  static const int acceptSeconds = 15;

  /// Whether [match] has anything to show to a host of [roomId].
  static bool shows(PkMatch match, String roomId) =>
      match.status == PkMatchStatus.result &&
      (match.rematch != null || match.canOfferRematch);

  @override
  State<PkRematchDock> createState() => _PkRematchDockState();
}

class _PkRematchDockState extends State<PkRematchDock> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The D238 docked card: always the white leave-prompt card in the room
  /// (its ink, red and outline read from the light theme).
  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(
      brightness: Brightness.light,
      locale: Localizations.localeOf(context),
    ),
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final match = widget.match;
    if (!PkRematchDock.shows(match, widget.roomId)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final (_, other) = match.of(widget.roomId);
    final name = KFormat.bidiIsolate('@${other.host.username}');
    final offer = match.rematch;
    final mine = offer?.byRoomId == widget.roomId;
    final left =
        PkRematchDock.debugSeconds ??
        (offer == null
            ? 0
            : math.max(0, offer.expiresAt.difference(widget.now()).inSeconds));
    final ink = KLiveDialogCard.inkOf(context);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    Widget line(String text, {Key? key}) => Text(
      text,
      key: key,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textScaler: scaler,
      style: context.textStyles.body.copyWith(
        color: ink,
        fontSize: PkDareDock.textSize,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
    );
    Widget ring() => Semantics(
      label: l10n.pkRematchSeconds('$left'),
      excludeSemantics: true,
      child: PkDareRing(
        seconds: left,
        fraction: left / PkRematchDock.acceptSeconds,
        onCard: true,
        size: PkDareDock.ring,
      ),
    );
    final (String text, Key key, List<KLiveDialogAction> actions) = switch ((
      offer,
      mine,
    )) {
      (null, _) => (
        l10n.pkRematchAsk(name),
        PkRematchDock.cardKey,
        [
          KLiveDialogAction(
            key: PkRematchDock.offerKey,
            label: l10n.pkRematch,
            primary: true,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onOffer)),
          ),
        ],
      ),
      (_, true) => (
        l10n.pkRematchWaiting(name),
        PkRematchDock.waitingKey,
        [
          KLiveDialogAction(
            key: PkRematchDock.cancelKey,
            label: MaterialLocalizations.of(context).cancelButtonLabel,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onCancel)),
          ),
        ],
      ),
      (_, false) => (
        l10n.pkRematchOffered(name),
        PkRematchDock.promptKey,
        [
          KLiveDialogAction(
            key: PkRematchDock.acceptKey,
            label: l10n.pkDareAccept,
            primary: true,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onAccept)),
          ),
          KLiveDialogAction(
            key: PkRematchDock.declineKey,
            label: l10n.pkDareRefuse,
            onPressed: _busy
                ? null
                : () => unawaited(_run(widget.actions.onDecline)),
          ),
        ],
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: KLiveDialogCard(
          key: key,
          semanticsLabel: text,
          padding: KLiveDialogCard.densePadding,
          dense: true,
          body: Row(
            children: [
              Expanded(child: line(text)),
              if (offer != null) ...[
                const SizedBox(width: KSpacing.xs),
                ring(),
              ],
            ],
          ),
          actions: actions,
        ),
      ),
    );
  }
}

/// D242: «جولة أخرى!» over the stage for everyone when the new battle
/// starts (about 2.4 s).
class PkRematchBanner extends StatelessWidget {
  const new({super.key});

  static const bannerKey = Key('pk.rematch.banner');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l10n.pkRematchBanner,
      excludeSemantics: true,
      child: Container(
        key: bannerKey,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.xs,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE50914), Color(0xFF3D8BFF)],
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Text(
          l10n.pkRematchBanner,
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
          style: context.textStyles.title.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
