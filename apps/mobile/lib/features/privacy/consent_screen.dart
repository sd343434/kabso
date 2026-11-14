import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/consent_required.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/privacy/privacy_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// `/legal/consent` (v1.66-social, D198, CONVENTIONS §10.61.2): after the
/// owner publishes a new version of the terms or the privacy policy, the app
/// shows this polite but blocking screen on the next open — each document's
/// version, date and summary of changes, a link to the full text, «أوافق
/// وأتابع», and the ways out (download the data, delete the account, sign
/// out). The API answers 428 to everything else until the person accepts.
class ConsentScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const acceptKey = Key('consent.accept');
  static const logoutKey = Key('consent.logout');
  static const exportKey = Key('consent.export');
  static const deleteKey = Key('consent.delete');
  static Key documentKey(LegalKind k) => Key('consent.doc.${k.wire}');

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepting = false;

  Future<void> _accept(List<LegalDocument> docs) async {
    setState(() => _accepting = true);
    final l10n = context.l10n;
    try {
      final status = await ref.read(privacyRepositoryProvider).accept(docs);
      if (!mounted) return;
      if (status.required.isEmpty) {
        KSnack.success(context, l10n.consentAccepted);
        // The router leaves this screen when the flag clears.
        ref.read(consentRequiredProvider.notifier).value = false;
      } else {
        ref.invalidate(consentStatusProvider);
      }
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      KSnack.error(context, failureMessage(l10n, failure));
      if (failure.code == ErrorCode.consentVersionMismatch) {
        ref.invalidate(consentStatusProvider);
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final status = ref.watch(consentStatusProvider);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final tag = Localizations.localeOf(context).toLanguageTag();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: switch (status) {
            AsyncValue(:final value?) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      KSpacing.lg,
                      KSpacing.xl,
                      KSpacing.lg,
                      KSpacing.lg,
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
                              Icons.policy_outlined,
                              color: p.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: KSpacing.md),
                      Semantics(
                        header: true,
                        child: Text(l10n.consentTitle, style: t.title),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        l10n.consentBody,
                        style: t.body.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: KSpacing.lg),
                      for (final doc in value.required) ...[
                        _DocumentCard(
                          key: ConsentScreen.documentKey(doc.kind),
                          name: doc.kind == LegalKind.terms
                              ? l10n.consentTermsName
                              : l10n.consentPrivacyName,
                          version: l10n.consentVersion(
                            '\u2068${doc.version}\u2069',
                            KFormat.date(doc.effectiveAt, tag),
                          ),
                          summary: arabic ? doc.summaryAr : doc.summaryEn,
                          onRead: () => launcher.launchUrl(
                            Uri.parse(arabic ? doc.url : '${doc.url}?lang=en'),
                            mode: launcher.LaunchMode.externalApplication,
                          ),
                        ),
                        const SizedBox(height: KSpacing.md),
                      ],
                      Text(
                        l10n.consentNotNow,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Wrap(
                        spacing: KSpacing.xs,
                        children: [
                          TextButton(
                            key: ConsentScreen.exportKey,
                            onPressed: () => context.push(AppRoutes.dataExport),
                            child: Text(l10n.dataExportTitle),
                          ),
                          TextButton(
                            key: ConsentScreen.deleteKey,
                            onPressed: () =>
                                context.push(AppRoutes.deleteAccount),
                            child: Text(l10n.settingsDeleteAccount),
                          ),
                          TextButton(
                            key: ConsentScreen.logoutKey,
                            onPressed: () => ref
                                .read(sessionControllerProvider.notifier)
                                .logout(),
                            child: Text(l10n.consentLogout),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    KSpacing.lg,
                    KSpacing.sm,
                    KSpacing.lg,
                    KSpacing.lg,
                  ),
                  child: KButton(
                    key: ConsentScreen.acceptKey,
                    label: l10n.consentAccept,
                    loading: _accepting,
                    onPressed: _accepting
                        ? null
                        : value.required.isEmpty
                        ? () =>
                              ref.read(consentRequiredProvider.notifier).value =
                                  false
                        : () => _accept(value.required),
                  ),
                ),
              ],
            ),
            AsyncError(:final error) => FailureErrorState(
              title: l10n.errorTitle,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(consentStatusProvider),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const new({
    required this.name,
    required this.version,
    required this.summary,
    required this.onRead,
    super.key,
  });

  final String name;
  final String version;
  final String summary;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsetsDirectional.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: t.bodyStrong),
          const SizedBox(height: KSpacing.xxs),
          Text(version, style: t.caption.copyWith(color: p.textSecondary)),
          const SizedBox(height: KSpacing.sm),
          Text(summary, style: t.body),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onRead,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(context.l10n.consentReadFull),
            ),
          ),
        ],
      ),
    );
  }
}
