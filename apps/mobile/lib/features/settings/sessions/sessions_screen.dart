import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D226: the sessions in display order — this device first, then the others
/// by their last activity, most recent first (`GET /auth/sessions` is
/// already newest first; the sort keeps the order stable either way).
List<Session> orderSessions(List<Session> sessions) {
  final others = [
    for (final s in sessions)
      if (!s.current) s,
  ]..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  return [
    for (final s in sessions)
      if (s.current) s,
    ...others,
  ];
}

/// D226 (owner): Settings shows only the two most recent sessions — this
/// device is always one of them.
const int kSettingsSessionsShown = 2;

/// D226: «الجلسات النشطة» — every active session of the caller, with the
/// same revoke action as the Settings rows. Opened from «عرض الكل (N)».
/// No "sign out of all other devices": the API has no such endpoint
/// (PHASE1_SCREENS §9.3), and none is added here (no contract change).
class SessionsScreen extends ConsumerWidget {
  const new({super.key});

  static const listKey = Key('sessions.list');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: KAppBar(title: Text(l10n.settingsSessions)),
      body: switch (sessions) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(sessionsProvider.future),
          child: ListView(
            key: listKey,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: KSpacing.lg,
            ),
            children: [
              for (final s in orderSessions(value)) SessionTile(session: s),
              if (!value.any((s) => !s.current)) const SessionsNoOthers(),
            ],
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => Padding(
          padding: const EdgeInsetsDirectional.all(KSpacing.lg),
          child: SessionsError(error: error),
        ),
        _ => const Padding(
          padding: EdgeInsetsDirectional.all(KSpacing.lg),
          child: SessionsSkeleton(rows: 3),
        ),
      },
    );
  }
}

/// "You're signed in on this device only."
class SessionsNoOthers extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.lg,
        vertical: KSpacing.sm,
      ),
      child: Text(
        context.l10n.sessionsNoOthers,
        style: context.textStyles.caption,
      ),
    );
  }
}

/// The failure of `GET /auth/sessions` with a retry.
class SessionsError extends ConsumerWidget {
  const new({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FailureBanner(failure: toAppFailure(error)),
        const SizedBox(height: KSpacing.sm),
        KButton(
          label: context.l10n.actionRetry,
          variant: KButtonVariant.secondary,
          onPressed: () => ref.invalidate(sessionsProvider),
        ),
      ],
    );
  }
}

/// Loading rows (no cache for sessions: security data must be fresh).
class SessionsSkeleton extends StatelessWidget {
  const new({required this.rows, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: KSpacing.sm),
          const KSkeleton(height: 56, radius: KRadius.md),
        ],
      ],
    );
  }
}

/// One session row: device, «هذا الجهاز» / platform / version / last
/// activity, the sign-in date and, for another device, «إنهاء».
class SessionTile extends ConsumerWidget {
  const new({required this.session, super.key});

  final Session session;

  /// Above this text scale the revoke action moves below the row content so
  /// the text keeps a usable width (QA-004).
  static const _stackedTextScale = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final platform = switch (session.platform) {
      SessionPlatform.android => l10n.platformAndroid,
      SessionPlatform.ios => l10n.platformIos,
      SessionPlatform.web => l10n.platformWeb,
      SessionPlatform.other => l10n.platformOther,
      null => null,
    };
    final name = session.deviceName ?? platform ?? l10n.sessionUnknownDevice;
    final relative = KFormat.relative(
      session.lastUsedAt,
      clock.now(),
      l10n,
      locale,
    );
    final activity = [
      if (session.current) l10n.sessionsCurrent,
      if (session.deviceName != null && platform != null) platform,
      if (session.appVersion case final String v when v.isNotEmpty) v,
      if (relative == null)
        l10n.sessionsActiveNow
      else
        l10n.sessionsLastActive(relative),
    ].join(' · ');
    final signedIn = l10n.sessionsSignedIn(
      KFormat.date(session.createdAt, locale),
    );

    final icon = ExcludeSemantics(
      child: Icon(switch (session.platform) {
        SessionPlatform.android ||
        SessionPlatform.ios => Icons.smartphone_rounded,
        SessionPlatform.web => Icons.language_rounded,
        _ => Icons.devices_other_rounded,
      }, color: p.textSecondary),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: t.bodyStrong),
        const SizedBox(height: KSpacing.xxs),
        Text(activity, style: t.caption),
        Text(signedIn, style: t.caption),
      ],
    );
    final revoke = session.current
        ? null
        : TextButton(
            style: TextButton.styleFrom(foregroundColor: p.error),
            onPressed: () => _revoke(context, ref, name),
            child: Text(l10n.sessionsRevoke),
          );

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: KSpacing.xxs),
          child: icon,
        ),
        const SizedBox(width: KSpacing.lg),
        Expanded(child: content),
      ],
    );
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > _stackedTextScale;

    final Widget body;
    if (revoke == null) {
      body = info;
    } else if (stacked) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          Align(alignment: AlignmentDirectional.centerEnd, child: revoke),
        ],
      );
    } else {
      body = Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: KSpacing.sm),
          revoke,
        ],
      );
    }

    return ConstrainedBox(
      key: Key('session.${session.id}'),
      constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.sm,
        ),
        child: body,
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, String name) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionsRevokeConfirmTitle),
        // U+2068/U+2069 isolate the device name (any script) in the sentence.
        content: Text(l10n.sessionsRevokeConfirmBody('\u2068$name\u2069')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('session.revoke.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionsRevokeConfirm),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      if (context.mounted) KSnack.success(context, l10n.sessionsRevoked);
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (context.mounted) {
        if (failure.code == ErrorCode.notFound) {
          // PHASE1_SCREENS §9.3: the session had already ended elsewhere.
          KSnack.info(context, l10n.sessionsAlreadyEnded);
        } else {
          KSnack.error(context, failureMessage(l10n, failure));
        }
      }
    } finally {
      // Refresh in every case: on NOT_FOUND this drops the stale row.
      if (context.mounted) ref.invalidate(sessionsProvider);
    }
  }
}
