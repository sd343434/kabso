import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The label of a report reason.
String reportReasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.nudity => l10n.reportReasonNudity,
      ReportReason.violence => l10n.reportReasonViolence,
      ReportReason.hate => l10n.reportReasonHate,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.illegal => l10n.reportReasonIllegal,
      ReportReason.other => l10n.reportReasonOther,
    };

/// A sheet that asks why a post or comment is reported ([title]); `null`
/// when dismissed.
Future<ReportReason?> pickReportReason(BuildContext context, String title) {
  final l10n = context.l10n;
  return showModalBottomSheet<ReportReason>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(title)),
          for (final reason in ReportReason.values)
            ListTile(
              key: ValueKey('feed.post.report.${reason.name}'),
              title: Text(reportReasonLabel(l10n, reason)),
              onTap: () => Navigator.of(sheet).pop(reason),
            ),
        ],
      ),
    ),
  );
}
