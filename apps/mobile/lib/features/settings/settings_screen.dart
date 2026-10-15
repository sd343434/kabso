import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Theme, language, active sessions and sign-out.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  static const logoutKey = Key('settings.logout');

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
              onSelectionChanged: (s) =>
                  ref.read(languageControllerProvider.notifier).select(s.first),
            ),
          ),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsSessions),
          const _SessionsSection(),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsAccount),
          ListTile(
            key: logoutKey,
            leading: Icon(Icons.logout_rounded, color: context.palette.error),
            title: Text(
              l10n.logout,
              style: TextStyle(color: context.palette.error),
            ),
            onTap: () => _confirmLogout(context, ref),
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
    if (confirmed ?? false) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
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
            KInlineMessage(message: failureMessage(l10n, toAppFailure(error))),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final lastActive = DateFormat.yMMMd(locale)
        .add_jm()
        .format(session.lastUsedAt.toLocal());

    final platform = switch (session.platform) {
      SessionPlatform.android => l10n.platformAndroid,
      SessionPlatform.ios => l10n.platformIos,
      SessionPlatform.web => l10n.platformWeb,
      SessionPlatform.other => l10n.platformOther,
      null => null,
    };
    final name = session.deviceName ?? platform ?? l10n.sessionUnknownDevice;
    final subtitle = [
      if (session.current) l10n.sessionsCurrent,
      if (session.deviceName != null && platform != null) platform,
      l10n.sessionsLastActive(lastActive),
    ].join(' · ');

    return ListTile(
      key: Key('session.${session.id}'),
      leading: Icon(
        session.platform == SessionPlatform.ios ||
                session.platform == SessionPlatform.android
            ? Icons.smartphone_rounded
            : Icons.devices_other_rounded,
      ),
      title: Text(name),
      subtitle: Text(subtitle),
      trailing: session.current
          ? null
          : TextButton(
              onPressed: () => _revoke(context, ref),
              child: Text(l10n.sessionsRevoke),
            ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionsRevokeConfirmTitle),
        content: Text(l10n.sessionsRevokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionsRevoke),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      if (context.mounted) KSnack.success(context, l10n.sessionsRevoked);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (context.mounted) ref.invalidate(sessionsProvider);
    }
  }
}
