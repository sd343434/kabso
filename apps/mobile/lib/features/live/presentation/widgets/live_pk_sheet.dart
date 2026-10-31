import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
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

/// The host's «PK» sheet (D195): invite a live host (search and
/// suggestions), «مطابقة عشوائية», the invitations switch; during a PK the
/// mute-opponent toggle and End PK (a forfeit while the battle runs).
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

class LivePkSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const sheetKey = Key('pk.sheet');
  static const inviteTabKey = Key('pk.sheet.tab.invite');
  static const randomTabKey = Key('pk.sheet.tab.random');
  static const searchKey = Key('pk.sheet.search');
  static const randomKey = Key('pk.sheet.random');
  static const stopRandomKey = Key('pk.sheet.random.stop');
  static const cancelInviteKey = Key('pk.sheet.invite.cancel');
  static const invitesSwitchKey = Key('pk.sheet.invites');
  static const endKey = Key('pk.sheet.end');
  static const muteKey = Key('pk.sheet.mute');
  static Key candidateKey(String roomId) => Key('pk.sheet.candidate.$roomId');

  @override
  ConsumerState<LivePkSheet> createState() => _LivePkSheetState();
}

class _LivePkSheetState extends ConsumerState<LivePkSheet> {
  bool _random = false;
  String _query = '';
  Timer? _debounce;
  Timer? _tick;
  Future<List<PkCandidate>>? _candidates;
  bool? _invitesEnabled;
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
    unawaited(_readSwitch());
  }

  Future<void> _readSwitch() async {
    try {
      final s = await ref.read(livePkRepositoryProvider).state(widget.roomId);
      if (mounted) setState(() => _invitesEnabled = s.invitesEnabled ?? true);
    } on Object {
      // The switch shows as on until known.
    }
  }

  void _load() {
    _candidates = ref
        .read(livePkRepositoryProvider)
        .candidates(widget.roomId, query: _query);
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
    final l10n = context.l10n;
    final pk = ref.watch(livePkProvider(widget.roomId));
    final controller = ref.read(livePkProvider(widget.roomId).notifier);
    final match = pk.match;
    final t = context.textStyles;
    const ink = Color(0xFF1C1B2E);
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return Material(
      key: LivePkSheet.sheetKey,
      color: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.md,
              KSpacing.md,
              KSpacing.md,
              KSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.pkSheetTitle,
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                if (match != null)
                  ..._duringMatch(context, match, controller)
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _TabChip(
                          key: LivePkSheet.inviteTabKey,
                          label: l10n.pkTabInvite,
                          selected: !_random,
                          onTap: () => setState(() => _random = false),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: _TabChip(
                          key: LivePkSheet.randomTabKey,
                          label: l10n.pkTabRandom,
                          selected: _random,
                          onTap: () => setState(() => _random = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Expanded(
                    child: _random
                        ? _randomTab(context, pk, controller)
                        : _inviteTab(context, pk, controller),
                  ),
                  SwitchListTile.adaptive(
                    key: LivePkSheet.invitesSwitchKey,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.pkInvitesSwitch,
                      style: t.body.copyWith(color: ink),
                    ),
                    value: _invitesEnabled ?? true,
                    onChanged: (v) => unawaited(
                      _run(() async {
                        final on = await controller.setInvitesEnabled(
                          enabled: v,
                        );
                        if (mounted) setState(() => _invitesEnabled = on);
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _duringMatch(
    BuildContext context,
    PkMatch match,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final (own, other) = match.of(widget.roomId);
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: KAvatar(
          name: other.host.displayName,
          imageUrl: other.host.avatarUrl,
          size: 40,
        ),
        title: Text(other.host.displayName),
        subtitle: Text(
          l10n.pkScoreSemantics(
            KFormat.grouped(own.score),
            KFormat.grouped(other.score),
          ),
        ),
      ),
      const SizedBox(height: KSpacing.sm),
      KButton(
        key: LivePkSheet.muteKey,
        variant: KButtonVariant.secondary,
        icon: own.mutesOpponent
            ? Icons.volume_up_rounded
            : Icons.volume_off_rounded,
        label: own.mutesOpponent ? l10n.pkUnmuteOpponent : l10n.pkMuteOpponent,
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
    ];
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

  Widget _inviteTab(
    BuildContext context,
    LivePkState pk,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final outgoing = pk.outgoing;
    if (outgoing != null) {
      final left = outgoing.expiresAt.difference(pk.now());
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KAvatar(
            name: outgoing.to.displayName,
            imageUrl: outgoing.to.avatarUrl,
            size: 64,
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.pkWaitingFor(
              outgoing.to.displayName,
              '${left.isNegative ? 0 : left.inSeconds}',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: LivePkSheet.cancelInviteKey,
            variant: KButtonVariant.secondary,
            label: l10n.pkCancel,
            expand: false,
            onPressed: () => unawaited(_run(controller.cancelInvite)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: LivePkSheet.searchKey,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l10n.pkSearchHint,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KRadius.pill),
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
        const SizedBox(height: KSpacing.sm),
        Text(
          l10n.pkLiveNow,
          style: context.textStyles.label.copyWith(
            color: const Color(0xFF6E6E80),
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PkCandidate>>(
            future: _candidates,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? const <PkCandidate>[];
              if (list.isEmpty) {
                return Center(child: Text(l10n.pkNoCandidates));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    key: LivePkSheet.candidateKey(c.roomId),
                    contentPadding: EdgeInsets.zero,
                    leading: KAvatar(
                      name: c.host.displayName,
                      imageUrl: c.host.avatarUrl,
                      size: 40,
                    ),
                    title: Text(
                      c.host.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _run(() async {
                                await controller.invite(c.roomId);
                                if (!context.mounted) return;
                                KSnack.info(
                                  context,
                                  l10n.pkInviteSent(c.host.displayName),
                                );
                              }),
                            ),
                      child: Text(l10n.pkInvite),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _randomTab(
    BuildContext context,
    LivePkState pk,
    LivePkController controller,
  ) {
    final l10n = context.l10n;
    final until = pk.queueUntil;
    final waiting = until != null && until.isAfter(pk.now());
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shuffle_rounded, size: 56, color: Color(0xFFE50914)),
        const SizedBox(height: KSpacing.sm),
        Text(
          waiting
              ? l10n.pkRandomSearching(
                  KFormat.countdown(until.difference(pk.now())),
                )
              : l10n.pkRandomHint,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KSpacing.md),
        KButton(
          key: waiting ? LivePkSheet.stopRandomKey : LivePkSheet.randomKey,
          variant: waiting ? KButtonVariant.secondary : KButtonVariant.primary,
          label: waiting ? l10n.pkRandomStop : l10n.pkRandomStart,
          loading: _busy,
          onPressed: () => unawaited(
            _run(waiting ? controller.leaveRandom : controller.joinRandom),
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF4A4A), Color(0xFFE50914)],
                )
              : null,
          color: selected ? null : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Text(
          label,
          style: context.textStyles.label.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFFFFFFFF) : const Color(0xFF1C1B2E),
          ),
        ),
      ),
    ),
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
