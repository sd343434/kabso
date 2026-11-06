import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.78-live (D288, CONVENTIONS §10.101; owner: «ان البلاغ يصل كل المشرفين
/// والدعم والذي يقوم بحله يضغط تم حله»): «بلاغات» — the panel's shared report
/// queue on the phone, for MODERATION and SUPPORT. «غير محلولة» (oldest
/// first) and «تم حلها» (newest resolution first); each report with what it
/// is about, why, the reported text, who reported it and — once closed — who
/// resolved it, when and their note. «تم حله» (with an optional note)
/// resolves it for the whole team; a second press shows «تم حله بالفعل».
class StaffReportsScreen extends ConsumerStatefulWidget {
  const new({super.key, this.focusReportId});

  /// The report a `STAFF_REPORT_NEW` tap opens on (highlighted).
  final String? focusReportId;

  static const tabsKey = Key('staffReports.tabs');
  static Key card(String id) => Key('staffReports.card.$id');
  static Key resolve(String id) => Key('staffReports.resolve.$id');

  @override
  ConsumerState<StaffReportsScreen> createState() => _StaffReportsScreenState();
}

class _StaffReportsScreenState extends ConsumerState<StaffReportsScreen> {
  SharedReportTab _tab = SharedReportTab.open;

  void _reload() {
    ref
      ..invalidate(staffSharedReportsProvider(SharedReportTab.open))
      ..invalidate(staffSharedReportsProvider(SharedReportTab.resolved));
    if (ref.exists(staffOpenReportsProvider)) {
      unawaited(ref.read(staffOpenReportsProvider.notifier).refresh());
    }
  }

  Future<void> _resolve(SharedReport report) async {
    final l10n = context.l10n;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const SharedReportResolveDialog(),
    );
    if (note == null || !mounted) return;
    try {
      await ref
          .read(staffRepositoryProvider)
          .resolveReport(report.id, note: note);
      if (mounted) KSnack.success(context, l10n.staffSharedDone);
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!mounted) return;
      if (failure.code == ErrorCode.reportAlreadyResolved) {
        // Somebody else pressed first: the list shows who.
        KSnack.info(context, l10n.staffSharedAlreadyResolved);
      } else {
        KSnack.error(context, failureMessage(l10n, failure));
        return;
      }
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final status = ref.watch(staffStatusProvider).value;
    final canResolve = status?.can(SharedReportCapability.resolve) ?? false;
    final page = ref.watch(staffSharedReportsProvider(_tab));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffSharedReportsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.xs,
            ),
            child: Text(
              l10n.staffSharedReportsHint,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
          KScrollableTabs(
            key: StaffReportsScreen.tabsKey,
            labels: [l10n.staffSharedTabOpen, l10n.staffSharedTabResolved],
            selectedIndex: _tab.index,
            onSelected: (i) => setState(() => _tab = SharedReportTab.values[i]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _reload();
                await ref.read(staffSharedReportsProvider(_tab).future);
              },
              child: switch (page) {
                AsyncData(:final value) when value.items.isEmpty => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(KSpacing.xxl),
                      child: Text(
                        _tab == SharedReportTab.open
                            ? l10n.staffSharedEmptyOpen
                            : l10n.staffSharedEmptyResolved,
                        textAlign: TextAlign.center,
                        style: context.textStyles.body.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                AsyncData(:final value) => ListView.separated(
                  padding: const EdgeInsets.all(KSpacing.lg),
                  itemCount: value.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: KSpacing.md),
                  itemBuilder: (_, i) {
                    final r = value.items[i];
                    return SharedReportCard(
                      key: StaffReportsScreen.card(r.id),
                      report: r,
                      focused: r.id == widget.focusReportId,
                      onResolve: canResolve && r.isOpen
                          ? () => unawaited(_resolve(r))
                          : null,
                    );
                  },
                ),
                AsyncError(:final error) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(KSpacing.xl),
                      child: Text(
                        failureMessage(l10n, toAppFailure(error)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// D288: what a report is about, in words.
String sharedReportTypeLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'POST' => l10n.staffReportTypePost,
      'COMMENT' => l10n.staffReportTypeComment,
      'STORY' => l10n.staffReportTypeStory,
      'USER' => l10n.staffReportTypeUser,
      'LIVE_ROOM' => l10n.staffReportTypeLive,
      'LIVE_CHAT_MESSAGE' => l10n.staffReportTypeLiveChat,
      'CP_CONFESSION' => l10n.staffReportTypeConfession,
      'FAMILY_CHAT_MESSAGE' => l10n.staffReportTypeFamilyChat,
      'DM_MESSAGE' => l10n.staffReportTypeDm,
      'PROFILE_LINK' => l10n.staffReportTypeLink,
      _ => type,
    };

/// D288: a report's reason, in the report sheet's words.
String sharedReportReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'SPAM' => l10n.reportReasonSpam,
      'NUDITY' => l10n.reportReasonNudity,
      'VIOLENCE' => l10n.reportReasonViolence,
      'HATE' => l10n.reportReasonHate,
      'HARASSMENT' => l10n.reportReasonHarassment,
      'ILLEGAL' => l10n.reportReasonIllegal,
      _ => l10n.reportReasonOther,
    };

/// One report of «بلاغات» with its details and, while it is open, «تم حله».
class SharedReportCard extends StatelessWidget {
  const new({
    required this.report,
    super.key,
    this.focused = false,
    this.onResolve,
  });

  final SharedReport report;
  final bool focused;

  /// Null: no «تم حله» (resolved already, or the role cannot resolve).
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(DateTime at) {
      final local = at.toLocal();
      return '${KFormat.date(local, locale)} ${KFormat.time(local, locale)}';
    }

    final r = report;
    final muted = t.caption.copyWith(color: p.textSecondary);
    Widget chip(String label, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: t.caption.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(
          color: focused ? KBrandColors.red600 : p.border,
          width: focused ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: KSpacing.xs,
                    runSpacing: KSpacing.xxs,
                    children: [
                      chip(
                        sharedReportTypeLabel(l10n, r.targetType),
                        p.primary,
                      ),
                      chip(
                        sharedReportReasonLabel(l10n, r.reason),
                        KBrandColors.red600,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Text(when(r.createdAt), style: muted),
              ],
            ),
            if (r.authorName != null) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.staffSharedAuthor(
                  '${KFormat.bidiIsolate(r.authorName!)} · '
                  '${KHandle.isolated(r.authorUsername ?? '')}',
                ),
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
            ],
            if (r.previewText case final text? when text.isNotEmpty) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: p.textPrimary),
              ),
            ],
            if (r.gone) ...[
              const SizedBox(height: KSpacing.xxs),
              Text(l10n.staffSharedGone, style: muted),
            ],
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.staffSharedReportedBy(
                KHandle.isolated(r.reporterUsername ?? ''),
              ),
              style: muted,
            ),
            if (r.note case final note? when note.isNotEmpty)
              Text(
                l10n.staffSharedReporterNote(KFormat.bidiIsolate(note)),
                style: muted,
              ),
            if (!r.isOpen) ...[
              const SizedBox(height: KSpacing.sm),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(KRadius.md),
                  border: BorderDirectional(
                    start: BorderSide(color: p.success, width: 3),
                  ),
                ),
                padding: const EdgeInsets.all(KSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.resolvedBy != null && r.resolvedAt != null
                          ? l10n.staffSharedResolvedBy(
                              KFormat.bidiIsolate(r.resolvedBy!.label),
                              when(r.resolvedAt!),
                            )
                          : l10n.staffSharedResolvedAt(
                              r.resolvedAt == null ? '' : when(r.resolvedAt!),
                            ),
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                    if (r.status == 'DISMISSED')
                      Text(l10n.staffSharedOutcomeDismissed, style: muted),
                    if (r.resolutionNote case final note? when note.isNotEmpty)
                      Text(
                        l10n.staffSharedResolutionNote(
                          KFormat.bidiIsolate(note),
                        ),
                        style: muted,
                      ),
                  ],
                ),
              ),
            ],
            if (onResolve != null) ...[
              const SizedBox(height: KSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  key: StaffReportsScreen.resolve(r.id),
                  onPressed: onResolve,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(l10n.staffSharedResolve),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «تم حله»: an optional note; pops the note ('' for none), or null.
class SharedReportResolveDialog extends StatefulWidget {
  const new({super.key});

  static const noteKey = Key('staffReports.resolve.note');
  static const applyKey = Key('staffReports.resolve.apply');

  @override
  State<SharedReportResolveDialog> createState() =>
      _SharedReportResolveDialogState();
}

class _SharedReportResolveDialogState extends State<SharedReportResolveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.staffSharedResolveTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.staffSharedResolveIntro,
              style: context.textStyles.caption.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            TextField(
              key: SharedReportResolveDialog.noteKey,
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.staffSharedResolveNote,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: SharedReportResolveDialog.applyKey,
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: Text(l10n.staffSharedResolve),
        ),
      ],
    );
  }
}

/// D288: the unresolved count at the end of the «بلاغات» row — hidden at 0,
/// «99+» above 99; Western digits, so the number reads the same in RTL and
/// LTR, and placed at the row's logical end by the row itself.
class StaffReportsCountBadge extends StatelessWidget {
  const new({required this.count, super.key});

  static const badgeKey = Key('staffReports.badge');

  final int count;

  static String? text(int count) =>
      count <= 0 ? null : (count > 99 ? '99+' : '$count');

  @override
  Widget build(BuildContext context) {
    final label = text(count);
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.staffSharedReportsBadge(count),
      excludeSemantics: true,
      child: Container(
        key: badgeKey,
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: KBrandColors.red600,
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: context.textStyles.caption.copyWith(
            color: const Color(0xFFFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
