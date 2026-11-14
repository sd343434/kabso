import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/create_media_step.dart'
    show videoRejectionMessage;
import 'package:kabso_live/features/level_raise/data/level_raise_repository.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The status's name in the app's language.
String levelRaiseStatusName(AppLocalizations l10n, LevelRaiseStatus s) =>
    switch (s) {
      LevelRaiseStatus.pending => l10n.lrStatusPending,
      LevelRaiseStatus.approved => l10n.lrStatusApproved,
      LevelRaiseStatus.rejected => l10n.lrStatusRejected,
    };

/// The confidence label of a source app («مؤكد» / «تقدير»).
String levelRaiseConfidenceName(
  AppLocalizations l10n,
  LevelRaiseConfidence c,
) => c == LevelRaiseConfidence.confirmed ? l10n.lrConfirmed : l10n.lrEstimate;

/// The message of a refused request (`ADMIN_ACTION_REFUSED` with the rule's
/// issue; v1.89-social `LEVEL_RAISE_DUPLICATE` with the existing request's
/// status, date and staff member), else the general failure message.
String levelRaiseFailure(
  AppLocalizations l10n,
  AppFailure f, {
  String localeTag = 'en',
}) {
  if (f case ServerFailure(
    code: ErrorCode.levelRaiseDuplicate,
    :final details,
  )) {
    String of(String field) =>
        details.where((d) => d.field == field).firstOrNull?.issue ?? '';
    final at = DateTime.tryParse(of('createdAt'));
    return l10n.lrDuplicate(
      of('status') == 'APPROVED' ? l10n.lrStatusApproved : l10n.lrStatusPending,
      KFormat.bidiIsolate(at == null ? '—' : KFormat.date(at, localeTag)),
      KFormat.bidiIsolate(of('requestedBy').isEmpty ? '—' : of('requestedBy')),
    );
  }
  if (f case ServerFailure(:final details) when details.isNotEmpty) {
    final issue = details.first.issue;
    final field = details.first.field;
    if (issue == 'level_raise_open_exists') return l10n.lrOpenExists;
    if (issue == 'level_raise_staff_account') return l10n.lrStaffAccount;
    if (field == 'username' && issue == 'not_found') return l10n.lrNotFound;
  }
  return failureMessage(l10n, f);
}

/// v1.89-social (D290): «طلبات رفع الليفيل» in the staff Me tab (MODERATION /
/// SUPPORT) — the staff member's own requests with their status, and «طلب
/// جديد».
class StaffLevelRaisesScreen extends ConsumerWidget {
  const new({super.key});

  static const listKey = Key('levelRaises.list');
  static const newKey = Key('levelRaises.new');
  static Key rowKey(String id) => Key('levelRaises.row.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final data = ref.watch(myLevelRaisesProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.lrTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: newKey,
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        onPressed: () async {
          final sent = await context.push<bool>(AppRoutes.staffLevelRaiseNew);
          if (sent ?? false) ref.invalidate(myLevelRaisesProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.lrNew),
      ),
      body: switch (data) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(myLevelRaisesProvider.future),
          child: ListView(
            key: listKey,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              96,
            ),
            children: [
              Text(
                l10n.lrIntro,
                style: t.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.md),
              if (value.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xxl),
                  child: Text(
                    l10n.lrEmpty,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: p.textSecondary),
                  ),
                )
              else
                for (final r in value) LevelRaiseRow(request: r),
            ],
          ),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Text(
              failureMessage(l10n, toAppFailure(error)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One request: the supporter, the app / level / ID, the status and the
/// result (the approved level, or the reason of a rejection).
class LevelRaiseRow extends StatelessWidget {
  const new({required this.request, super.key});

  final LevelRaiseRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final r = request;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final color = switch (r.status) {
      LevelRaiseStatus.pending => p.info,
      LevelRaiseStatus.approved => p.success,
      LevelRaiseStatus.rejected => p.error,
    };
    return Card(
      key: StaffLevelRaisesScreen.rowKey(r.id),
      color: p.surface,
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KAvatar(
              name: r.supporter.displayName,
              imageUrl: r.supporter.avatarUrl,
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.supporter.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    '@${r.supporter.username}',
                    textDirection: TextDirection.ltr,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    l10n.lrSourceLine(
                      KFormat.bidiIsolate(r.appName(ar: ar)),
                      KFormat.bidiIsolate('${r.sourceLevel}'),
                      KFormat.bidiIsolate(r.sourceAccountId),
                    ),
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Wrap(
                    spacing: KSpacing.xs,
                    runSpacing: KSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(
                        text: levelRaiseStatusName(l10n, r.status),
                        color: color,
                      ),
                      if (r.previouslyRejected)
                        _Pill(
                          icon: Icons.history_rounded,
                          text: l10n.lrPreviouslyRejected,
                          color: p.warning,
                        ),
                      if (r.status == LevelRaiseStatus.approved &&
                          r.approvedLevel != null)
                        _Pill(
                          icon: Icons.trending_up_rounded,
                          text: l10n.lrApprovedLevel(
                            KFormat.bidiIsolate('${r.approvedLevel}'),
                          ),
                          color: p.success,
                        ),
                      Text(
                        KFormat.date(r.createdAt, locale),
                        style: t.caption.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                  if (r.status == LevelRaiseStatus.rejected &&
                      (r.rejectReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      l10n.lrRejectReason(r.rejectReason!),
                      style: t.caption.copyWith(color: p.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: t.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v1.89-social (D290, §10.103.2): «طلب رفع ليفيل» — the form: the Kabso
/// username (checked: the recharge and the levels; a Kabso Team account or an
/// open request refused), the source app with its confidence label (or
/// "other" with its name), the ID and level there, the video (≤ 90 s, ≤
/// 200 MiB, uploaded as `LEVEL_RAISE_VIDEO`) and a note. Pops `true` when
/// sent.
class LevelRaiseFormScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const usernameKey = Key('levelRaise.username');
  static const checkKey = Key('levelRaise.check');
  static const appKey = Key('levelRaise.app');
  static const otherNameKey = Key('levelRaise.otherName');
  static const accountKey = Key('levelRaise.account');
  static const levelKey = Key('levelRaise.level');
  static const videoKey = Key('levelRaise.video');
  static const noteKey = Key('levelRaise.note');
  static const sendKey = Key('levelRaise.send');
  static const evidenceKey = Key('levelRaise.evidence');
  static Key suggestionKey(String id) => Key('levelRaise.suggestion.$id');

  @override
  ConsumerState<LevelRaiseFormScreen> createState() =>
      _LevelRaiseFormScreenState();
}

class _LevelRaiseFormScreenState extends ConsumerState<LevelRaiseFormScreen> {
  final _username = TextEditingController();
  final _otherName = TextEditingController();
  final _account = TextEditingController();
  final _level = TextEditingController();
  final _note = TextEditingController();
  LevelRaiseCheck? _check;
  bool _checking = false;
  String? _app;
  PickedVideo? _video;
  List<LevelRaiseSuggestion> _suggestions = const [];
  Timer? _suggestTimer;
  double? _progress;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _username.dispose();
    _otherName.dispose();
    _account.dispose();
    _level.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _name => _username.text.trim().replaceFirst(RegExp('^@'), '');

  Future<void> _runCheck() async {
    if (_name.isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final c = await ref.read(levelRaiseRepositoryProvider).check(_name);
      if (mounted) setState(() => _check = c);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = levelRaiseFailure(
            context.l10n,
            toAppFailure(e),
            localeTag: Localizations.localeOf(context).toLanguageTag(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickVideo() async {
    final l10n = context.l10n;
    try {
      final v = await ref
          .read(videoPickerProvider)
          .pickVideo(maxDuration: maxPostVideoLength);
      if (!mounted || v == null) return;
      if (checkVideo(v, reel: false) case final rejection?) {
        KSnack.error(context, videoRejectionMessage(l10n, rejection));
        return;
      }
      setState(() => _video = v);
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    } on Object {
      if (mounted) KSnack.error(context, l10n.createVideoUnreadable);
    }
  }

  /// «هل تقصد: …؟»: suggestions for the typed "other" name (debounced).
  void _onOtherName(String text) {
    setState(() {});
    _suggestTimer?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await ref.read(levelRaiseRepositoryProvider).suggest(q);
        if (!mounted || _otherName.text.trim() != q) return;
        setState(
          () => _suggestions = [
            for (final s in found)
              if (s.app != null || s.name != q) s,
          ],
        );
      } on Object {
        if (mounted) setState(() => _suggestions = const []);
      }
    });
  }

  /// A listed app is selected instead of "other"; an earlier name is used
  /// as typed then.
  void _pickSuggestion(LevelRaiseSuggestion s) {
    setState(() {
      if (s.app case final app?) {
        _app = app.code;
        _otherName.clear();
      } else if (s.name case final name?) {
        _otherName.text = name;
      }
      _suggestions = const [];
    });
  }

  bool _ready(List<LevelRaiseSourceApp> apps) {
    final app = apps.where((a) => a.code == _app).firstOrNull;
    final level = int.tryParse(_level.text.trim());
    return (_check?.usable ?? false) &&
        app != null &&
        (!app.isOther || _otherName.text.trim().isNotEmpty) &&
        _account.text.trim().isNotEmpty &&
        level != null &&
        level >= 1 &&
        level <= 999 &&
        _video != null &&
        !_sending;
  }

  Future<void> _send(List<LevelRaiseSourceApp> apps) async {
    final l10n = context.l10n;
    final app = apps.firstWhere((a) => a.code == _app);
    setState(() {
      _sending = true;
      _error = null;
      _progress = 0;
    });
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadVideo(
            _video!,
            reel: false,
            kind: 'LEVEL_RAISE_VIDEO',
            onProgress: (v) {
              if (mounted) setState(() => _progress = v);
            },
          );
      await ref
          .read(levelRaiseRepositoryProvider)
          .create(
            LevelRaiseDraft(
              username: _name,
              sourceApp: app.code,
              sourceAppName: app.isOther ? _otherName.text.trim() : null,
              sourceAccountId: _account.text.trim(),
              sourceLevel: int.parse(_level.text.trim()),
              videoId: asset.id,
              note: _note.text.trim(),
            ),
          );
      if (!mounted) return;
      KSnack.success(context, l10n.lrSent);
      context.pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = levelRaiseFailure(
            l10n,
            toAppFailure(e),
            localeTag: Localizations.localeOf(context).toLanguageTag(),
          );
          _sending = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final apps = ref.watch(levelRaiseSourceAppsProvider).value ?? const [];
    final chosen = apps.where((a) => a.code == _app).firstOrNull;
    final check = _check;
    final video = _video;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.lrFormTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KTextField(
                  fieldKey: LevelRaiseFormScreen.usernameKey,
                  label: l10n.lrUsername,
                  controller: _username,
                  textDirection: TextDirection.ltr,
                  maxLength: 41,
                  onChanged: (_) => setState(() => _check = null),
                  onSubmitted: (_) => unawaited(_runCheck()),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: KButton(
                  key: LevelRaiseFormScreen.checkKey,
                  label: l10n.lrCheck,
                  expand: false,
                  variant: KButtonVariant.secondary,
                  loading: _checking,
                  onPressed: _name.isEmpty
                      ? null
                      : () => unawaited(_runCheck()),
                ),
              ),
            ],
          ),
          if (check != null) ...[
            const SizedBox(height: KSpacing.sm),
            _CheckResult(check: check),
          ],
          const SizedBox(height: KSpacing.md),
          // Rebuilt when a suggestion picks the app (the field keeps its own
          // value otherwise).
          KeyedSubtree(
            key: ValueKey('levelRaise.app.$_app'),
            child: DropdownButtonFormField<String>(
              key: LevelRaiseFormScreen.appKey,
              initialValue: _app,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.lrSourceApp),
              items: [
                for (final a in apps)
                  DropdownMenuItem(
                    value: a.code,
                    child: Text(
                      '${a.name(ar: ar)} · '
                      '${levelRaiseConfidenceName(l10n, a.confidence)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _app = v),
            ),
          ),
          if (chosen?.isOther ?? false) ...[
            const SizedBox(height: KSpacing.md),
            KTextField(
              fieldKey: LevelRaiseFormScreen.otherNameKey,
              status: _suggestions.isEmpty
                  ? null
                  : _SuggestionChips(
                      items: _suggestions,
                      onPick: _pickSuggestion,
                    ),
              label: l10n.lrOtherName,
              controller: _otherName,
              maxLength: 60,
              onChanged: _onOtherName,
            ),
          ],
          const SizedBox(height: KSpacing.md),
          KTextField(
            fieldKey: LevelRaiseFormScreen.accountKey,
            label: l10n.lrAccountId,
            controller: _account,
            textDirection: TextDirection.ltr,
            maxLength: 64,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpacing.md),
          KTextField(
            fieldKey: LevelRaiseFormScreen.levelKey,
            label: l10n.lrSourceLevel,
            helperText: l10n.lrLevelRange,
            controller: _level,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.lrVideo,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.lrVideoHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          KButton(
            key: LevelRaiseFormScreen.videoKey,
            label: video == null
                ? l10n.lrVideoPick
                : l10n.lrVideoChosen(
                    KFormat.bidiIsolate('${video.duration.inSeconds}'),
                  ),
            icon: video == null
                ? Icons.video_library_rounded
                : Icons.check_circle_rounded,
            variant: KButtonVariant.secondary,
            onPressed: _sending ? null : () => unawaited(_pickVideo()),
          ),
          const SizedBox(height: KSpacing.md),
          KTextField(
            fieldKey: LevelRaiseFormScreen.noteKey,
            label: l10n.lrNote,
            controller: _note,
            maxLength: 500,
          ),
          if (_error case final e?) ...[
            const SizedBox(height: KSpacing.sm),
            Text(e, style: t.caption.copyWith(color: p.error)),
          ],
          if (_progress case final v?) ...[
            const SizedBox(height: KSpacing.sm),
            LinearProgressIndicator(value: v),
            Text(
              l10n.lrVideoUploading(
                KFormat.bidiIsolate('${(v * 100).round()}'),
              ),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: LevelRaiseFormScreen.sendKey,
            label: l10n.lrSend,
            loading: _sending,
            onPressed: _ready(apps) ? () => unawaited(_send(apps)) : null,
          ),
        ],
      ),
    );
  }
}

/// What the check found: the supporter, their recharge and levels, and
/// whether the recharge already allows approval.
class _CheckResult extends StatelessWidget {
  const new({required this.check});

  final LevelRaiseCheck check;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    if (!check.found) {
      return Text(l10n.lrNotFound, style: t.caption.copyWith(color: p.error));
    }
    if (check.staffAccount) {
      return Text(
        l10n.lrStaffAccount,
        style: t.caption.copyWith(color: p.error),
      );
    }
    final e = check.evidence!;
    final s = check.supporter!;
    return Card(
      key: LevelRaiseFormScreen.evidenceKey,
      color: p.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KAvatar(name: s.displayName, imageUrl: s.avatarUrl),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(
                    s.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.lrTotalRecharge(
                KFormat.bidiIsolate(KFormat.grouped(e.totalRechargeCoins)),
              ),
              style: t.caption.copyWith(color: p.textPrimary),
            ),
            Text(
              l10n.lrFirstDaysRecharge(
                KFormat.bidiIsolate('${e.firstDays}'),
                KFormat.bidiIsolate(KFormat.grouped(e.firstDaysRechargeCoins)),
              ),
              style: t.caption.copyWith(color: p.textPrimary),
            ),
            Text(
              l10n.lrLevels(
                KFormat.bidiIsolate('${e.supportLevel}'),
                KFormat.bidiIsolate('${e.charmLevel}'),
              ),
              style: t.caption.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              e.eligible
                  ? l10n.lrEligible
                  : l10n.lrNotEligible(
                      KFormat.bidiIsolate(KFormat.grouped(e.minRechargeCoins)),
                    ),
              style: t.caption.copyWith(
                color: e.eligible ? p.success : p.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (check.openRequest) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.lrOpenExists,
                style: t.caption.copyWith(color: p.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «هل تقصد: …؟» under the "other" name: tapping one picks that app or name.
class _SuggestionChips extends StatelessWidget {
  const new({required this.items, required this.onPick});

  final List<LevelRaiseSuggestion> items;
  final ValueChanged<LevelRaiseSuggestion> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.xs),
      child: Wrap(
        spacing: KSpacing.xs,
        runSpacing: KSpacing.xs,
        children: [
          for (final s in items)
            ActionChip(
              key: LevelRaiseFormScreen.suggestionKey(
                s.app?.code ?? s.name ?? '',
              ),
              avatar: Icon(
                s.app == null ? Icons.history_rounded : Icons.apps_rounded,
                size: 16,
              ),
              label: Text(switch (s.app) {
                null => l10n.lrDidYouMean(s.label(ar: ar)),
                final app =>
                  '${l10n.lrDidYouMean(s.label(ar: ar))} · '
                      '${levelRaiseConfidenceName(l10n, app.confidence)}',
              }),
              onPressed: () => onPick(s),
            ),
        ],
      ),
    );
  }
}
