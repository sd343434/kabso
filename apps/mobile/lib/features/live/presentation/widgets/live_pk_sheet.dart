import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_pages.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The message of a refused PK call (the PK codes, else the generic one).
String pkFailureMessage(AppLocalizations l10n, Object error) {
  final failure = toAppFailure(error);
  final code = failure is ServerFailure ? failure.rawCode : null;
  return switch (code) {
    'PK_HOST_BUSY' => l10n.pkErrorBusy,
    'PK_INVITES_OFF' => l10n.pkErrorInvitesOff,
    'PK_INVITE_COOLDOWN' => l10n.pkErrorCooldown,
    'PK_UNAVAILABLE' => l10n.pkErrorUnavailable,
    'PK_INVITE_CLOSED' => l10n.pkErrorInviteClosed,
    _ => failureMessage(l10n, failure),
  };
}

/// The message of a refused booster gift (409 `PK_BOOSTER_UNAVAILABLE`, the
/// detail's issue), or null for any other failure.
String? pkBoosterFailureMessage(
  AppLocalizations l10n,
  Object error, {
  PkBoosterRule? rule,
}) {
  final failure = toAppFailure(error);
  if (failure is! ServerFailure ||
      failure.rawCode != 'PK_BOOSTER_UNAVAILABLE') {
    return null;
  }
  final issue = failure.details.firstOrNull?.issue;
  return switch (issue) {
    'too_early' => l10n.pkBoosterTooEarly(
      (rule?.lastSeconds ?? 60) > 60
          ? l10n.pkBoosterLastTwoMinutes
          : l10n.pkBoosterLastMinute,
    ),
    'limit_reached' => l10n.pkBoosterLimit,
    'active_higher' => l10n.pkBoosterActiveHigher,
    _ => l10n.pkBoosterNoMatch,
  };
}

/// The host's «PK» sheet — D195's PK in the owner's layout (D199, refs
/// 276 / 277): the history clock and the settings gear at the start, «PK»
/// with its help in the middle, ✕ at the end; three mode cards — «PK ثنائي»
/// works, «PK الفرق» and «PK متعدد» are not built and say «قريباً»; the
/// «الأصدقاء» tab (mutual follows live now) with Kabi when there is nobody;
/// search and «مطابقة عشوائية» (D195) at the bottom. During a PK: start (a
/// connected PK), mute the opponent and End PK.
Future<void> showLivePkSheet(BuildContext context, {required String roomId}) {
  // The sheet's route lives in the app's navigator: it keeps the room's
  // provider container (the PK state of this room).
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x33000000),
    // A white sheet over the dark room: the light theme inside it.
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: Theme(
        data: buildAppTheme(
          brightness: Brightness.light,
          locale: Localizations.localeOf(sheet),
        ),
        child: LivePkSheet(roomId: roomId),
      ),
    ),
  );
}

/// D199: the PK sheet's measured geometry (ref 276, 393 lp wide, @1.878 px
/// per lp in the 738 px capture).
abstract final class PkSheetMetrics {
  /// 639 of 852 lp: the sheet reaches the bottom from 213 lp.
  static const heightFactor = 0.75;
  static const radius = 21.0;
  static const topRowHeight = 44.8;
  static const iconSize = 22.0;
  static const cardsTop = 53.2;
  static const cardHeight = 59.1;
  static const cardSide = 18.1;
  static const cardGap = 13.8;
  static const cardRadius = 7.5;
  static const friendsTop = 136.0;
  static const emptyArt = 102.0;

  /// Kabso's take on the reference's peach → blue wash: peach → rose.
  static const washStart = Color(0xFFFDD69B);
  static const washEnd = Color(0xFFFFC2CC);
  static const red = Color(0xFFE50914);
  static const ink = Color(0xFF1F1F24);
  static const grey = Color(0xFF8A8D92);
}

enum PkSheetMode { oneVsOne, team, multi }

class LivePkSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const sheetKey = Key('pk.sheet');
  static const historyKey = Key('pk.sheet.history');
  static const settingsKey = Key('pk.sheet.settings');
  static const helpKey = Key('pk.sheet.help');
  static const closeKey = Key('pk.sheet.close');
  static const friendsTabKey = Key('pk.sheet.friends');
  static const friendsHelpKey = Key('pk.sheet.friends.help');
  static const emptyKey = Key('pk.sheet.empty');
  static const searchKey = Key('pk.sheet.search');
  static const randomKey = Key('pk.sheet.random');
  static const stopRandomKey = Key('pk.sheet.random.stop');
  static const cancelInviteKey = Key('pk.sheet.invite.cancel');
  static const startKey = Key('pk.sheet.start');
  static const endKey = Key('pk.sheet.end');
  static const muteKey = Key('pk.sheet.mute');
  static Key modeKey(PkSheetMode m) => Key('pk.sheet.mode.${m.name}');
  static Key candidateKey(String roomId) => Key('pk.sheet.candidate.$roomId');

  @override
  ConsumerState<LivePkSheet> createState() => _LivePkSheetState();
}

class _LivePkSheetState extends ConsumerState<LivePkSheet> {
  String _query = '';
  Timer? _debounce;
  Timer? _tick;
  Future<List<PkCandidate>>? _candidates;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (LivePkStage.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// No search: the «Friends» (mutual follows live now); a search: any
  /// host who may be invited.
  void _load() {
    final q = _query.trim();
    _candidates = ref
        .read(livePkRepositoryProvider)
        .candidates(widget.roomId, query: q, friends: q.isEmpty);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, pkFailureMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pk = ref.watch(livePkProvider(widget.roomId));
    final controller = ref.read(livePkProvider(widget.roomId).notifier);
    final match = pk.match;
    final height =
        MediaQuery.sizeOf(context).height * PkSheetMetrics.heightFactor;
    return Material(
      key: LivePkSheet.sheetKey,
      color: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PkSheetMetrics.radius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                PkSheetMetrics.washStart,
                Color(0xFFF2EDEE),
                PkSheetMetrics.washEnd,
              ],
            ),
          ),
          child: DecoratedBox(
            // The wash fades to white over the sheet's top 58 %.
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.58],
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x99FFFFFF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topRow(context),
                  if (match != null)
                    Expanded(child: _duringMatch(context, match, controller))
                  else ...[
                    const SizedBox(height: 8.4),
                    _modeCards(context),
                    const SizedBox(height: 23.7),
                    _friendsHeader(context),
                    Expanded(child: _body(context, pk, controller)),
                    _bottomBar(context, pk, controller),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow(BuildContext context) {
    final l10n = context.l10n;
    Widget icon(Key key, IconData icon, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: key,
            onTap: onTap,
            radius: 22,
            child: SizedBox.square(
              dimension: 36.4,
              child: Icon(
                icon,
                size: PkSheetMetrics.iconSize,
                color: PkSheetMetrics.ink,
              ),
            ),
          ),
        );
    return SizedBox(
      height: PkSheetMetrics.topRowHeight,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 11.1,
            top: 4.2,
            child: Row(
              children: [
                icon(
                  LivePkSheet.historyKey,
                  Icons.history_rounded,
                  l10n.pkHistoryTitle,
                  () => unawaited(showPkHistory(context)),
                ),
                icon(
                  LivePkSheet.settingsKey,
                  Icons.settings_outlined,
                  l10n.pkSettingsTitle,
                  () => unawaited(showPkSettings(context)),
                ),
              ],
            ),
          ),
          Align(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The PK wordmark: italic and heavy, in Kabso's ink.
                Text(
                  'PK',
                  textDirection: TextDirection.ltr,
                  style: context.textStyles.title.copyWith(
                    fontFamily: 'Inter',
                    fontSize: 21,
                    height: 1,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                    color: PkSheetMetrics.ink,
                  ),
                ),
                const SizedBox(width: 8.5),
                Semantics(
                  button: true,
                  label: l10n.pkHelpTitle,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: LivePkSheet.helpKey,
                    onTap: () => _help(l10n.pkHelpTitle, l10n.pkHelpBody),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: PkSheetMetrics.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: 11.4,
            top: 4.2,
            child: icon(
              LivePkSheet.closeKey,
              Icons.close_rounded,
              MaterialLocalizations.of(context).closeButtonLabel,
              () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  void _help(String title, String body) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
        ),
      ],
    ),
  );

  Widget _modeCards(BuildContext context) {
    final l10n = context.l10n;
    PkModeCard card(PkSheetMode m) => PkModeCard(
      key: LivePkSheet.modeKey(m),
      mode: m,
      label: switch (m) {
        PkSheetMode.oneVsOne => l10n.pkModeOneVsOne,
        PkSheetMode.team => l10n.pkModeTeam,
        PkSheetMode.multi => l10n.pkModeMulti,
      },
      // 1 v 1 is the only mode built (D195): always the selected one.
      selected: m == PkSheetMode.oneVsOne,
      soon: m != PkSheetMode.oneVsOne,
      onTap: m == PkSheetMode.oneVsOne
          ? null
          : () => KSnack.info(
              context,
              l10n.pkModeSoon(
                m == PkSheetMode.team ? l10n.pkModeTeam : l10n.pkModeMulti,
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PkSheetMetrics.cardSide),
      child: SizedBox(
        height: PkSheetMetrics.cardHeight,
        child: Row(
          children: [
            Expanded(child: card(PkSheetMode.oneVsOne)),
            const SizedBox(width: PkSheetMetrics.cardGap),
            Expanded(child: card(PkSheetMode.team)),
            const SizedBox(width: PkSheetMetrics.cardGap),
            Expanded(child: card(PkSheetMode.multi)),
          ],
        ),
      ),
    );
  }

  Widget _friendsHeader(BuildContext context) {
    final l10n = context.l10n;
    final style = context.textStyles.title.copyWith(
      fontSize: 18,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: PkSheetMetrics.ink,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20.2, 0, 20.2, 0),
      child: Row(
        children: [
          Semantics(
            key: LivePkSheet.friendsTabKey,
            selected: true,
            header: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.pkFriendsTab, style: style),
                const SizedBox(height: 2),
                Container(
                  width: 6.9,
                  height: 2.7,
                  decoration: BoxDecoration(
                    color: PkSheetMetrics.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: l10n.pkFriendsTab,
            excludeSemantics: true,
            child: GestureDetector(
              key: LivePkSheet.friendsHelpKey,
              onTap: () => _help(l10n.pkFriendsTab, l10n.pkFriendsHelp),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 22,
                color: PkSheetMetrics.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LivePkState pk,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final outgoing = pk.outgoing;
    final until = pk.queueUntil;
    if (outgoing != null) {
      final left = outgoing.expiresAt.difference(pk.now());
      return _status(
        avatar: KAvatar(
          name: outgoing.to.displayName,
          imageUrl: outgoing.to.avatarUrl,
          size: 64,
        ),
        text: l10n.pkWaitingFor(
          outgoing.to.displayName,
          '${left.isNegative ? 0 : left.inSeconds}',
        ),
        action: KButton(
          key: LivePkSheet.cancelInviteKey,
          variant: KButtonVariant.secondary,
          label: l10n.pkCancel,
          expand: false,
          onPressed: () => unawaited(_run(controller.cancelInvite)),
        ),
      );
    }
    if (until != null && until.isAfter(pk.now())) {
      return _status(
        avatar: const Icon(
          Icons.shuffle_rounded,
          size: 56,
          color: PkSheetMetrics.red,
        ),
        text: l10n.pkRandomSearching(
          KFormat.countdown(until.difference(pk.now())),
        ),
        action: KButton(
          key: LivePkSheet.stopRandomKey,
          variant: KButtonVariant.secondary,
          label: l10n.pkRandomStop,
          expand: false,
          loading: _busy,
          onPressed: () => unawaited(_run(controller.leaveRandom)),
        ),
      );
    }
    return FutureBuilder<List<PkCandidate>>(
      future: _candidates,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const <PkCandidate>[];
        if (list.isEmpty) {
          return _Empty(
            key: LivePkSheet.emptyKey,
            text: _query.trim().isEmpty
                ? l10n.pkNoFriends
                : l10n.pkNoCandidates,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          itemCount: list.length,
          itemBuilder: (context, i) => _candidate(context, list[i], controller),
        );
      },
    );
  }

  Widget _status({
    required Widget avatar,
    required String text,
    required Widget action,
  }) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: KSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.textStyles.body.copyWith(color: PkSheetMetrics.ink),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        action,
      ],
    ),
  );

  Widget _candidate(
    BuildContext context,
    PkCandidate c,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    return ListTile(
      key: LivePkSheet.candidateKey(c.roomId),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: KAvatar(
        name: c.host.displayName,
        imageUrl: c.host.avatarUrl,
        size: 40,
      ),
      title: Text(
        c.host.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.bodyStrong.copyWith(
          color: PkSheetMetrics.ink,
        ),
      ),
      subtitle: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: PkSheetMetrics.red,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: _busy
            ? null
            : () => unawaited(
                _run(() async {
                  await controller.invite(c.roomId);
                  if (!context.mounted) return;
                  KSnack.info(context, l10n.pkInviteSent(c.host.displayName));
                }),
              ),
        child: Text(l10n.pkInvite),
      ),
    );
  }

  /// D195's search and «مطابقة عشوائية», at the foot of the sheet (the
  /// reference leaves its lower half empty).
  Widget _bottomBar(
    BuildContext context,
    LivePkState pk,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final until = pk.queueUntil;
    final waiting = until != null && until.isAfter(pk.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PkSheetMetrics.cardSide,
        KSpacing.sm,
        PkSheetMetrics.cardSide,
        KSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                key: LivePkSheet.searchKey,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: l10n.pkSearchHint,
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F3F6),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted) return;
                    setState(() {
                      _query = v;
                      _load();
                    });
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          if (!waiting)
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                key: LivePkSheet.randomKey,
                style: FilledButton.styleFrom(
                  backgroundColor: PkSheetMetrics.red,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _busy || pk.outgoing != null
                    ? null
                    : () => unawaited(_run(controller.joinRandom)),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: Text(l10n.pkTabRandom),
              ),
            ),
        ],
      ),
    );
  }

  Widget _duringMatch(
    BuildContext context,
    PkMatch match,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final (own, other) = match.of(widget.roomId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.sm,
        KSpacing.md,
        KSpacing.sm,
      ),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: KAvatar(
            name: other.host.displayName,
            imageUrl: other.host.avatarUrl,
            size: 40,
          ),
          title: Text(other.host.displayName),
          subtitle: Text(
            match.connected
                ? l10n.pkConnectedHint
                : l10n.pkScoreSemantics(
                    KFormat.grouped(own.score),
                    KFormat.grouped(other.score),
                  ),
          ),
        ),
        if (match.connected) ...[
          const SizedBox(height: KSpacing.sm),
          KButton(
            key: LivePkSheet.startKey,
            icon: Icons.play_arrow_rounded,
            label: l10n.pkStart,
            loading: _busy,
            onPressed: () => unawaited(_run(controller.start)),
          ),
        ],
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: LivePkSheet.muteKey,
          variant: KButtonVariant.secondary,
          icon: own.mutesOpponent
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: own.mutesOpponent
              ? l10n.pkUnmuteOpponent
              : l10n.pkMuteOpponent,
          loading: _busy,
          onPressed: () => unawaited(
            _run(() => controller.setMuteOpponent(muted: !own.mutesOpponent)),
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: LivePkSheet.endKey,
          variant: KButtonVariant.destructive,
          icon: Icons.flag_rounded,
          label: l10n.pkEnd,
          loading: _busy,
          onPressed: () => unawaited(_confirmEnd(match, controller)),
        ),
      ],
    );
  }

  Future<void> _confirmEnd(PkMatch match, LivePkController controller) async {
    final l10n = context.l10n;
    if (match.status == PkMatchStatus.battle) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.pkEndConfirmTitle),
          content: Text(l10n.pkEndConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.pkCancel),
            ),
            TextButton(
              key: const Key('pk.end.confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.pkEnd),
            ),
          ],
        ),
      );
      if (!(ok ?? false)) return;
    }
    await _run(controller.end);
    if (mounted) Navigator.of(context).maybePop();
  }
}

/// One of the three mode cards (white, 7.5 lp corners; the selected one in
/// a 2.7 lp Kabso-red ring). Team and Multi PK are not built: greyed with
/// «قريباً», never selectable.
class PkModeCard extends StatelessWidget {
  const new({
    required this.mode,
    required this.label,
    required this.selected,
    required this.soon,
    this.onTap,
    super.key,
  });

  final PkSheetMode mode;
  final String label;
  final bool selected;
  final bool soon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !soon,
      label: soon ? '$label، ${l10n.liveSoon}' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(
                    PkSheetMetrics.cardRadius,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: -1.3,
                top: -1.3,
                right: -1.3,
                bottom: -1.3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      PkSheetMetrics.cardRadius + 1.3,
                    ),
                    border: Border.all(color: PkSheetMetrics.red, width: 2.7),
                  ),
                ),
              ),
            Positioned.fill(
              child: Opacity(
                opacity: soon ? 0.45 : 1,
                child: Column(
                  children: [
                    const SizedBox(height: 10.2),
                    SizedBox(height: 21, child: PkModeArt(mode: mode)),
                    const Spacer(),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: 1.15),
                      style: context.textStyles.label.copyWith(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: PkSheetMetrics.ink,
                      ),
                    ),
                    const SizedBox(height: 9.5),
                  ],
                ),
              ),
            ),
            if (soon)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EAF0),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Text(
                    l10n.liveSoon,
                    textScaler: TextScaler.noScaling,
                    style: context.textStyles.caption.copyWith(
                      color: const Color(0xFF5A5B6A),
                      fontSize: 8,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kabso-drawn mode art (no third-party icons): two people with a bolt
/// (1 v 1), a group (Team), a grid of four (Multi), in Kabso's warm
/// gradient.
class PkModeArt extends StatelessWidget {
  const new({required this.mode, super.key});

  final PkSheetMode mode;

  @override
  Widget build(BuildContext context) {
    final glyph = switch (mode) {
      PkSheetMode.oneVsOne => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 21),
          Icon(Icons.bolt_rounded, size: 15),
          Icon(Icons.person_rounded, size: 21),
        ],
      ),
      PkSheetMode.team => const Icon(Icons.groups_rounded, size: 24),
      PkSheetMode.multi => const Icon(Icons.grid_view_rounded, size: 20),
    };
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB13D), Color(0xFFFF5A5F), PkSheetMetrics.red],
      ).createShader(r),
      child: IconTheme(
        data: const IconThemeData(color: Color(0xFFFFFFFF)),
        child: glyph,
      ),
    );
  }
}

/// Kabi and the line of the empty «Friends» list (ref 276: the art 102 lp
/// tall, its text 11.7 lp, grey).
class _Empty extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 59),
      KabiEmoji(
        KabsoEmoji.kabi('think'),
        size: PkSheetMetrics.emptyArt,
        repeat: false,
      ),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.textStyles.body.copyWith(
            fontSize: 14,
            height: 1.25,
            color: PkSheetMetrics.grey,
          ),
        ),
      ),
    ],
  );
}

/// The invited host's question: «{name} يدعوك إلى تحدي PK» — accept or
/// decline before the invitation's 15 s run out (it closes itself then).
class LivePkIncomingInvite extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.invite, super.key});

  final String roomId;
  final PkInvite invite;

  static const acceptKey = Key('pk.incoming.accept');
  static const declineKey = Key('pk.incoming.decline');

  @override
  ConsumerState<LivePkIncomingInvite> createState() =>
      _LivePkIncomingInviteState();
}

class _LivePkIncomingInviteState extends ConsumerState<LivePkIncomingInvite> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (LivePkStage.ticks) {
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

  Future<void> _answer({required bool accept}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(livePkProvider(widget.roomId).notifier);
    try {
      await (accept ? controller.accept() : controller.decline());
    } on Object catch (e) {
      if (mounted) KSnack.error(context, pkFailureMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final from = widget.invite.from;
    final pk = ref.watch(livePkProvider(widget.roomId));
    final left = widget.invite.expiresAt.difference(pk.now());
    final seconds = left.isNegative ? 0 : left.inSeconds;
    return KLiveSurface(
      child: Material(
        color: const Color(0x00000000),
        child: Container(
          margin: const EdgeInsets.all(KSpacing.md),
          padding: const EdgeInsets.all(KSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF22A0A0E), Color(0xF2120608)],
            ),
            borderRadius: BorderRadius.circular(KRadius.lg),
            border: Border.all(color: const Color(0xFFE50914), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.pkIncomingTitle,
                style: context.textStyles.label.copyWith(
                  color: const Color(0xFFFFC94D),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              KAvatar(
                name: from.displayName,
                imageUrl: from.avatarUrl,
                size: 56,
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.pkIncomingBody(from.displayName),
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(
                  color: const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                KFormat.countdown(Duration(seconds: seconds)),
                style: context.textStyles.caption.copyWith(
                  color: const Color(0xCCFFFFFF),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: KSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      key: LivePkIncomingInvite.declineKey,
                      variant: KButtonVariant.secondary,
                      label: l10n.pkDecline,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_answer(accept: false)),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: KButton(
                      key: LivePkIncomingInvite.acceptKey,
                      label: l10n.pkAccept,
                      loading: _busy,
                      onPressed: () => unawaited(_answer(accept: true)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
