import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/privacy/privacy_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

/// Saves the downloaded ZIP and returns where (overridden in tests).
typedef ExportFileSaver = Future<String> Function(Uint8List bytes, String name);

Future<String> _saveToAppFiles(Uint8List bytes, String name) async {
  // Android: the app's own folder in shared storage (reachable from a file
  // manager, no permission); iOS: the app's Documents (Files app).
  final dir =
      (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
      await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

final exportFileSaverProvider = Provider<ExportFileSaver>(
  (ref) => _saveToAppFiles,
);

/// `/settings/privacy/data-export` (v1.66-social, D198, CONVENTIONS §10.61.1):
/// «تنزيل بياناتي» (GDPR Art. 15/20, CCPA). What the copy holds, the 24-hour
/// rule and the 7-day single download; ask (password again) → «نجهّز
/// بياناتك» → (notification) → «تنزيل الملف» once.
class DataExportScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const requestKey = Key('dataExport.request');
  static const downloadKey = Key('dataExport.download');
  static const statusKey = Key('dataExport.status');
  static const passwordKey = Key('dataExport.password');
  static const passwordSubmitKey = Key('dataExport.passwordSubmit');

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  bool _busy = false;

  String _date(DateTime d) =>
      KFormat.date(d, Localizations.localeOf(context).toLanguageTag());

  Future<void> _request() async {
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      await ref.read(privacyRepositoryProvider).requestExport(password);
      if (mounted) KSnack.success(context, l10n.dataExportRequested);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      KSnack.error(
        context,
        failure.code == ErrorCode.reauthFailed
            ? l10n.errorReauthFailed
            : failureMessage(l10n, failure),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(dataExportsProvider);
      }
    }
  }

  Future<void> _download(DataExport export) async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final bytes = await ref
          .read(privacyRepositoryProvider)
          .download(export.id);
      final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final name = 'kabso-data-$day.zip';
      final path = await ref.read(exportFileSaverProvider)(bytes, name);
      if (mounted) KSnack.success(context, l10n.dataExportSaved(path));
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(dataExportsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final exports = ref.watch(dataExportsProvider);
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.dataExportTitle)),
      body: switch (exports) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(dataExportsProvider.future),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.xl,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExcludeSemantics(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: p.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.dataExportIntro,
                style: t.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.md),
              _Note(icon: Icons.schedule_rounded, text: l10n.dataExportRules),
              const SizedBox(height: KSpacing.sm),
              _Note(
                icon: Icons.shield_outlined,
                text: l10n.dataExportNoSecrets,
              ),
              const SizedBox(height: KSpacing.lg),
              _StatusCard(
                key: DataExportScreen.statusKey,
                list: value,
                date: _date,
              ),
              const SizedBox(height: KSpacing.lg),
              if (value.latest?.status == DataExportStatus.ready)
                KButton(
                  key: DataExportScreen.downloadKey,
                  label: l10n.dataExportDownload,
                  loading: _busy,
                  onPressed: _busy ? null : () => _download(value.latest!),
                )
              else
                KButton(
                  key: DataExportScreen.requestKey,
                  label: l10n.dataExportRequest,
                  loading: _busy,
                  onPressed:
                      _busy ||
                          value.nextAllowedAt != null ||
                          value.latest?.status == DataExportStatus.pending
                      ? null
                      : _request,
                ),
            ],
          ),
        ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(dataExportsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 20, color: p.textSecondary)),
        const SizedBox(width: KSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// The latest export's state, and when a new one may be asked for.
class _StatusCard extends StatelessWidget {
  const new({required this.list, required this.date, super.key});

  final DataExportList list;
  final String Function(DateTime) date;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final latest = list.latest;
    final (IconData icon, Color color, String? text) = switch (latest?.status) {
      null => (Icons.inventory_2_outlined, p.textSecondary, null),
      DataExportStatus.pending => (
        Icons.hourglass_top_rounded,
        p.primary,
        l10n.dataExportPreparing,
      ),
      DataExportStatus.ready => (
        Icons.check_circle_outline_rounded,
        p.success,
        l10n.dataExportReady(
          latest!.expiresAt == null ? '' : date(latest.expiresAt!),
        ),
      ),
      DataExportStatus.downloaded => (
        Icons.download_done_rounded,
        p.textSecondary,
        l10n.dataExportDownloaded(
          latest!.downloadedAt == null ? '' : date(latest.downloadedAt!),
        ),
      ),
      DataExportStatus.expired => (
        Icons.timer_off_outlined,
        p.textSecondary,
        l10n.dataExportExpired,
      ),
      DataExportStatus.failed => (
        Icons.error_outline_rounded,
        p.error,
        l10n.dataExportFailed,
      ),
    };
    final next = list.nextAllowedAt;
    final lines = [
      ?text,
      if (next != null && latest?.status != DataExportStatus.ready)
        l10n.dataExportNextAt(date(next)),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsetsDirectional.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color)),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) const SizedBox(height: KSpacing.xs),
                  Text(line, style: i == 0 ? t.bodyStrong : t.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The password again, before the request (D198: re-authentication).
class _PasswordSheet extends StatefulWidget {
  const new();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.dataExportPasswordTitle,
              style: context.textStyles.title,
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.dataExportPasswordBody,
            style: context.textStyles.body.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: KSpacing.lg),
          KTextField(
            label: l10n.dataExportPasswordLabel,
            fieldKey: DataExportScreen.passwordKey,
            controller: _password,
            obscure: true,
            showPasswordLabel: l10n.passwordShow,
            hidePasswordLabel: l10n.passwordHide,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.isNotEmpty) Navigator.of(context).pop(v);
            },
          ),
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: DataExportScreen.passwordSubmitKey,
            label: l10n.dataExportContinue,
            onPressed: _password.text.isEmpty
                ? null
                : () => Navigator.of(context).pop(_password.text),
          ),
        ],
      ),
    );
  }
}
