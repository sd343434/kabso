import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What «الإبلاغ عن البث» sends: a reason and an optional note.
typedef LiveReportChoice = ({ReportReason reason, String? note});

/// v1.60-live (D250, CONVENTIONS §10.91.3): «الإبلاغ عن البث» — the report
/// reasons, an optional note (≤ 500) and «إرسال البلاغ» (off until a reason is
/// picked). Pops the choice, or null when dismissed.
class LiveReportSheet extends StatefulWidget {
  const new({super.key});

  static const sheetKey = Key('live.report.sheet');
  static const noteKey = Key('live.report.note');
  static const sendKey = Key('live.report.send');
  static Key reasonKey(ReportReason r) => Key('live.report.${r.name}');

  @override
  State<LiveReportSheet> createState() => _LiveReportSheetState();
}

class _LiveReportSheetState extends State<LiveReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SafeArea(
      key: LiveReportSheet.sheetKey,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.md,
            KSpacing.lg,
            KSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.liveReportTitle,
                style: t.title.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: KSpacing.sm),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (r) => setState(() => _reason = r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        key: LiveReportSheet.reasonKey(r),
                        value: r,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(reportReasonLabel(l10n, r)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              KTextField(
                key: LiveReportSheet.noteKey,
                label: l10n.liveReportNoteLabel,
                helperText: l10n.liveReportNoteHint,
                controller: _note,
                maxLength: 500,
              ),
              const SizedBox(height: KSpacing.md),
              KButton(
                key: LiveReportSheet.sendKey,
                label: l10n.liveReportSend,
                icon: Icons.flag_outlined,
                variant: KButtonVariant.destructive,
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(context).pop<LiveReportChoice>((
                        reason: _reason!,
                        note: _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim(),
                      )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [LiveReportSheet]; the choice, or null.
Future<LiveReportChoice?> pickLiveReport(BuildContext context) =>
    showModalBottomSheet<LiveReportChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LiveReportSheet(),
    );
