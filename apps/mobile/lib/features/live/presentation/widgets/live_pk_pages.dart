import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199: the PK sheet's two pages — the gear's «PK Setting» and the clock's
/// PK history — as white sheets of the PK sheet's height over it, with a
/// back chevron on the reading start.
Future<void> _page(BuildContext context, Widget child) {
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x00000000),
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: Theme(
        data: buildAppTheme(
          brightness: Brightness.light,
          locale: Localizations.localeOf(sheet),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> showPkSettings(BuildContext context) =>
    _page(context, const PkSettingsPage());

Future<void> showPkHistory(BuildContext context) =>
    _page(context, const PkHistoryPage());

const _ink = Color(0xFF1F1F24);
const _soft = Color(0xFF8A8D92);
const _red = Color(0xFFE50914);

class _PageFrame extends StatelessWidget {
  const new({required this.title, required this.child, this.backKey});

  final String title;
  final Widget child;
  final Key? backKey;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: 4,
                    top: 4,
                    child: IconButton(
                      key: backKey,
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 20,
                      color: _ink,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Align(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: context.textStyles.title.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

/// D199 «PK Setting» (owner's reference A): tabs «PK ثنائي | PK متعدد |
/// PK الفرق» (only 1 v 1 is built; the others say «قريباً» and store
/// nothing), then the 1 v 1 rows — mode (single / best of three), time,
/// auto-start, the random queue's gender and region, Auto Match, being
/// suggested, and D195's invitations switch — over the grey notes. Every
/// change is saved on the server at once (`PUT /me/live-pk`).
class PkSettingsPage extends ConsumerStatefulWidget {
  const new({super.key});

  static const backKey = Key('pkSettings.back');
  static const singleKey = Key('pkSettings.mode.single');
  static const bestOfThreeKey = Key('pkSettings.mode.bo3');
  static const modeHelpKey = Key('pkSettings.mode.help');
  static const timeKey = Key('pkSettings.time');
  static const autoStartKey = Key('pkSettings.autoStart');
  static const genderKey = Key('pkSettings.gender');
  static const regionKey = Key('pkSettings.region');
  static const autoMatchKey = Key('pkSettings.autoMatch');
  static const recommendKey = Key('pkSettings.recommend');
  static const invitesKey = Key('pkSettings.invites');
  static const notesKey = Key('pkSettings.notes');
  static Key tabKey(int i) => Key('pkSettings.tab.$i');
  static Key optionKey(String wire) => Key('pkSettings.option.$wire');

  @override
  ConsumerState<PkSettingsPage> createState() => _PkSettingsPageState();
}

class _PkSettingsPageState extends ConsumerState<PkSettingsPage> {
  PkSettings? _s;
  Object? _error;
  bool _saving = false;

  LivePkRepository get _repo => ref.read(livePkRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final s = await _repo.settings();
      if (mounted) setState(() => _s = s);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save(Map<String, Object> changes) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final s = await _repo.saveSettings(changes);
      if (mounted) setState(() => _s = s);
    } on Object {
      if (mounted) KSnack.error(context, context.l10n.pkSettingSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick<T>({
    required String title,
    required List<(T, String, String)> options,
    required T selected,
    required void Function(T) onPick,
  }) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: sheet.textStyles.bodyStrong.copyWith(color: _ink),
              ),
            ),
            for (final (value, wire, label) in options)
              ListTile(
                key: PkSettingsPage.optionKey(wire),
                title: Text(label, style: const TextStyle(color: _ink)),
                trailing: value == selected
                    ? const Icon(Icons.check_rounded, color: _red)
                    : null,
                onTap: () => Navigator.of(sheet).pop(value),
              ),
            const SizedBox(height: KSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null && picked != selected) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _s;
    Widget body;
    if (s == null) {
      body = Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : KErrorState(
                title: l10n.pkSettingsLoadError,
                message: failureMessage(l10n, toAppFailure(_error!)),
                retryLabel: l10n.actionRetry,
                onRetry: () {
                  setState(() => _error = null);
                  unawaited(_load());
                },
                compact: true,
              ),
      );
    } else {
      body = ListView(
        padding: EdgeInsets.zero,
        children: [..._rows(context, s), _notes(context, s)],
      );
    }
    return _PageFrame(
      title: l10n.pkSettingsTitle,
      backKey: PkSettingsPage.backKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabs(context),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final l10n = context.l10n;
    final labels = [l10n.pkModeOneVsOne, l10n.pkModeMulti, l10n.pkModeTeam];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  button: true,
                  selected: i == 0,
                  enabled: i == 0,
                  label: i == 0 ? labels[i] : '${labels[i]}، ${l10n.liveSoon}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: PkSettingsPage.tabKey(i),
                    onTap: i == 0
                        ? null
                        : () => KSnack.info(context, l10n.pkSettingsSoonTab),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[i],
                              style: context.textStyles.bodyStrong.copyWith(
                                fontSize: 15,
                                fontWeight: i == 0
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: i == 0 ? _ink : _soft,
                              ),
                            ),
                            if (i > 0) ...[
                              const SizedBox(width: 3),
                              _SoonBadge(label: l10n.liveSoon),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 14,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == 0 ? _ink : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, PkSettings s) {
    final l10n = context.l10n;
    final label = context.textStyles.body.copyWith(
      fontSize: 14,
      color: _ink,
      fontWeight: FontWeight.w500,
    );
    final value = context.textStyles.body.copyWith(fontSize: 14, color: _soft);
    Widget row({
      required String title,
      Key? key,
      Widget? trailing,
      VoidCallback? onTap,
      VoidCallback? onHelp,
      Key? helpKey,
    }) => InkWell(
      key: key,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Flexible(child: Text(title, style: label)),
              if (onHelp != null)
                GestureDetector(
                  key: helpKey,
                  onTap: onHelp,
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: _soft,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              ?trailing,
            ],
          ),
        ),
      ),
    );
    Widget chevron(String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: value),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, size: 20, color: _soft),
      ],
    );
    Widget toggle(Key key, String field, {required bool on}) => Switch.adaptive(
      key: key,
      value: on,
      activeTrackColor: _red,
      onChanged: _saving ? null : (v) => unawaited(_save({field: v})),
    );
    // D232: the live's card style.
    void help(String title, String body) =>
        unawaited(showKLiveInfo(context, title: title, message: body));
    String gender(PkGenderPref g) => switch (g) {
      PkGenderPref.both => l10n.pkGenderBoth,
      PkGenderPref.male => l10n.pkGenderMale,
      PkGenderPref.female => l10n.pkGenderFemale,
    };
    String region(PkRegionPref r) => switch (r) {
      PkRegionPref.global => l10n.pkRegionGlobal,
      PkRegionPref.sameCountry => l10n.pkRegionSame,
    };
    return [
      row(
        title: l10n.pkSettingMode,
        onHelp: () => help(l10n.pkSettingMode, l10n.pkSettingModeHelp),
        helpKey: PkSettingsPage.modeHelpKey,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _Pill(
              key: PkSettingsPage.singleKey,
              label: l10n.pkModeSingle,
              selected: s.mode == PkMode.single,
              onTap: _saving || s.mode == PkMode.single
                  ? null
                  : () => unawaited(_save({'mode': PkMode.single.wire})),
            ),
            _Pill(
              key: PkSettingsPage.bestOfThreeKey,
              label: l10n.pkModeBestOfThree,
              selected: s.mode == PkMode.bestOfThree,
              onTap: _saving || s.mode == PkMode.bestOfThree
                  ? null
                  : () => unawaited(_save({'mode': PkMode.bestOfThree.wire})),
            ),
          ],
        ),
      ),
      row(
        key: PkSettingsPage.timeKey,
        title: l10n.pkSettingTime,
        trailing: chevron(l10n.pkMinutes('${s.minutes}')),
        onTap: () => unawaited(
          _pick<int>(
            title: l10n.pkSettingTime,
            options: [
              for (final m in const [3, 5, 10])
                (m, '$m', l10n.pkMinutesLong('$m')),
            ],
            selected: s.minutes,
            onPick: (m) => unawaited(_save({'roundMinutes': m})),
          ),
        ),
      ),
      row(
        title: l10n.pkSettingAutoStart,
        trailing: toggle(
          PkSettingsPage.autoStartKey,
          'autoStart',
          on: s.autoStart,
        ),
      ),
      row(
        key: PkSettingsPage.genderKey,
        title: l10n.pkSettingGender,
        trailing: chevron(gender(s.randomGender)),
        onTap: () => unawaited(
          _pick<PkGenderPref>(
            title: l10n.pkSettingGender,
            options: [
              for (final g in PkGenderPref.values) (g, g.wire, gender(g)),
            ],
            selected: s.randomGender,
            onPick: (g) => unawaited(_save({'randomGender': g.wire})),
          ),
        ),
      ),
      row(
        key: PkSettingsPage.regionKey,
        title: l10n.pkSettingRegion,
        trailing: chevron(region(s.randomRegion)),
        onTap: () => unawaited(
          _pick<PkRegionPref>(
            title: l10n.pkSettingRegion,
            options: [
              for (final r in PkRegionPref.values) (r, r.wire, region(r)),
            ],
            selected: s.randomRegion,
            onPick: (r) => unawaited(_save({'randomRegion': r.wire})),
          ),
        ),
      ),
      row(
        title: l10n.pkSettingAutoMatch,
        onHelp: () =>
            help(l10n.pkSettingAutoMatch, l10n.pkSettingAutoMatchHelp),
        trailing: toggle(
          PkSettingsPage.autoMatchKey,
          'autoMatch',
          on: s.autoMatch,
        ),
      ),
      row(
        title: l10n.pkSettingRecommend,
        trailing: toggle(
          PkSettingsPage.recommendKey,
          'recommendable',
          on: s.recommendable,
        ),
      ),
      // D195's switch lives here now.
      row(
        title: l10n.pkInvitesSwitch,
        trailing: toggle(
          PkSettingsPage.invitesKey,
          'invitesEnabled',
          on: s.invitesEnabled,
        ),
      ),
    ];
  }

  Widget _notes(BuildContext context, PkSettings s) {
    final l10n = context.l10n;
    final style = context.textStyles.caption.copyWith(
      fontSize: 12,
      height: 1.45,
      color: const Color(0xFF9A9BA3),
    );
    return Container(
      key: PkSettingsPage.notesKey,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      color: const Color(0xFFF5F5F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pkSettingsNoteEffective(KFormat.grouped(s.effectiveMinPoints)),
            style: style,
          ),
          const SizedBox(height: 4),
          Text(l10n.pkSettingsNoteRandom, style: style),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _red : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(color: selected ? _red : const Color(0xFFD5D6DC)),
        ),
        child: Text(
          label,
          style: context.textStyles.label.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFFFFFFFF) : _ink,
          ),
        ),
      ),
    ),
  );
}

class _SoonBadge extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EAF0),
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      label,
      textScaler: TextScaler.noScaling,
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFF5A5B6A),
        fontSize: 8,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// D199: the clock's PK history — the host's record and last matches
/// (`GET /live/pk/hosts/{username}`, D195 stores them): result, score,
/// rounds of a best of three, and «غير محتسبة» for a PK below the
/// effective threshold.
class PkHistoryPage extends ConsumerStatefulWidget {
  const new({super.key});

  static const backKey = Key('pkHistory.back');
  static const emptyKey = Key('pkHistory.empty');
  static const recordKey = Key('pkHistory.record');
  static Key itemKey(String id) => Key('pkHistory.item.$id');

  @override
  ConsumerState<PkHistoryPage> createState() => _PkHistoryPageState();
}

class _PkHistoryPageState extends ConsumerState<PkHistoryPage> {
  Future<PkHistory>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final me = ref.read(currentUserProvider);
    _future = me == null
        ? Future.value(const PkHistory())
        : ref.read(livePkRepositoryProvider).history(me.username);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PageFrame(
      title: l10n.pkHistoryTitle,
      backKey: PkHistoryPage.backKey,
      child: FutureBuilder<PkHistory>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: KErrorState(
                title: l10n.pkHistoryLoadError,
                message: failureMessage(l10n, toAppFailure(snap.error!)),
                retryLabel: l10n.actionRetry,
                onRetry: () => setState(_load),
                compact: true,
              ),
            );
          }
          final h = snap.data;
          if (h == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = h.record;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                key: PkHistoryPage.recordKey,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.pkRecord('${r.wins}', '${r.losses}', '${r.draws}'),
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyStrong.copyWith(color: _ink),
                ),
              ),
              if (h.recent.isEmpty)
                Padding(
                  key: PkHistoryPage.emptyKey,
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    l10n.pkHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: context.textStyles.body.copyWith(color: _soft),
                  ),
                ),
              for (final m in h.recent) _item(context, m),
            ],
          );
        },
      ),
    );
  }

  Widget _item(BuildContext context, PkHistoryItem m) {
    final l10n = context.l10n;
    final (label, color) = switch (m.result) {
      'WIN' => (l10n.pkWin, const Color(0xFF1E9E5A)),
      'LOSS' => (l10n.pkLose, _red),
      'DRAW' => (l10n.pkDraw, const Color(0xFF6E6E80)),
      _ => (l10n.pkHistoryVoid, _soft),
    };
    final details = [
      '${KFormat.grouped(m.score)} : ${KFormat.grouped(m.opponentScore)}',
      if (m.bestOfThree)
        l10n.pkHistoryRounds('${m.roundsWon}', '${m.opponentRoundsWon}'),
      if (!m.effective && m.result != 'VOID') l10n.pkHistoryNotCounted,
    ].join(' · ');
    return ListTile(
      key: PkHistoryPage.itemKey(m.id),
      contentPadding: EdgeInsets.zero,
      leading: KAvatar(
        name: m.opponent.displayName,
        imageUrl: m.opponent.avatarUrl,
        size: 40,
      ),
      title: Text(
        l10n.pkHistoryVs(KFormat.bidiIsolate(m.opponent.displayName)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.bodyStrong.copyWith(color: _ink),
      ),
      subtitle: Text(details),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Text(
          label,
          style: context.textStyles.label.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
