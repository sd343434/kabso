import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Theme, language, active sessions and sign-out.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  static const logoutKey = Key('settings.logout');
  static const levelsKey = Key('settings.levels');
  static const privacyKey = Key('settings.privacy');
  static const blockedKey = Key('settings.blocked');
  static const mutedKey = Key('settings.muted');
  static const storyArchiveKey = Key('settings.storyArchive');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final language = ref.watch(languageControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(vertical: KSpacing.lg),
        children: [
          _SectionHeader(l10n.settingsAppearance),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.lg,
            ),
            child: SegmentedButton<ThemeMode>(
              key: const Key('settings.theme'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) => ref
                  .read(themeModeControllerProvider.notifier)
                  .select(s.first),
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsLanguage),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.lg,
            ),
            child: SegmentedButton<AppLanguage>(
              key: const Key('settings.language'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AppLanguage.ar,
                  label: Text(l10n.languageArabic),
                ),
                ButtonSegment(
                  value: AppLanguage.en,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {language},
              onSelectionChanged: (s) async {
                // Apply locally first, then persist on the account
                // (PHASE1_1_SCREENS §3.3/§3.4).
                await ref
                    .read(languageControllerProvider.notifier)
                    .select(s.first);
                await ref.read(localeSyncProvider).languageChanged();
              },
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsSessions),
          const _SessionsSection(),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.safetySection),
          ListTile(
            key: privacyKey,
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(l10n.safetyPrivacy),
            onTap: () => GoRouter.maybeOf(context)?.push(AppRoutes.privacy),
          ),
          ListTile(
            key: blockedKey,
            leading: const Icon(Icons.block_rounded),
            title: Text(l10n.safetyBlockedAccounts),
            onTap: () =>
                GoRouter.maybeOf(context)?.push(AppRoutes.blockedAccounts),
          ),
          ListTile(
            key: mutedKey,
            leading: const Icon(Icons.volume_off_outlined),
            title: Text(l10n.safetyMutedAccounts),
            onTap: () =>
                GoRouter.maybeOf(context)?.push(AppRoutes.mutedAccounts),
          ),
          // CP-008: your stories, active and expired (only you see them).
          ListTile(
            key: storyArchiveKey,
            leading: const Icon(Icons.history_rounded),
            title: Text(l10n.storyArchiveTitle),
            onTap: () =>
                GoRouter.maybeOf(context)?.push(AppRoutes.storyArchive),
          ),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsAccount),
          // D72: the caller's four levels.
          ListTile(
            key: levelsKey,
            leading: const Icon(Icons.military_tech_outlined),
            title: Text(l10n.levelsTitle),
            onTap: () => GoRouter.maybeOf(context)?.push(AppRoutes.levels),
          ),
          ListTile(
            key: logoutKey,
            leading: Icon(Icons.logout_rounded, color: context.palette.error),
            title: Text(
              l10n.logout,
              style: TextStyle(color: context.palette.error),
            ),
            onTap: () => _confirmLogout(context, ref),
          ),
          // D86: Demo data (test builds only; nothing in release).
          const DemoDataTile(),
          // KL-022: developer entry to the component gallery (never in
          // release builds).
          if (!kReleaseMode)
            ListTile(
              key: const Key('settings.debug.components'),
              leading: const Icon(Icons.widgets_outlined),
              title: Text(l10n.debugComponentGallery),
              onTap: () =>
                  GoRouter.maybeOf(context)?.push(AppRoutes.debugComponents),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('settings.logout.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    final done = l10n.logoutDone;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(sessionControllerProvider.notifier).logout();
    // Shown on the Login screen (root messenger survives the navigation).
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  }
}

class _SectionHeader extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: context.textStyles.label.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SessionsSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsProvider);

    return switch (sessions) {
      AsyncValue(:final value?) => Column(
        children: [
          for (final s in value) _SessionTile(session: s),
          if (!value.any((s) => !s.current))
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: KSpacing.lg,
                vertical: KSpacing.sm,
              ),
              child: Text(
                l10n.sessionsNoOthers,
                style: context.textStyles.caption,
              ),
            ),
        ],
      ),
      AsyncValue(:final error?, isLoading: false) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FailureBanner(failure: toAppFailure(error)),
            const SizedBox(height: KSpacing.sm),
            KButton(
              label: l10n.actionRetry,
              variant: KButtonVariant.secondary,
              onPressed: () => ref.invalidate(sessionsProvider),
            ),
          ],
        ),
      ),
      _ => const Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: KSpacing.lg),
        child: Column(
          children: [
            KSkeleton(height: 56, radius: KRadius.md),
            SizedBox(height: KSpacing.sm),
            KSkeleton(height: 56, radius: KRadius.md),
          ],
        ),
      ),
    };
  }
}

class _SessionTile extends ConsumerWidget {
  const new({required this.session});

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
