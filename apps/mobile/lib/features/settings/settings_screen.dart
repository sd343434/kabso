import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/debug/demo_entry.dart';
import 'package:kabso_live/features/settings/sessions/sessions_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D133: "Country" with the person's country (or "Not set"); opens the
/// country list.
class _CountryTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final arabic = ref.watch(languageControllerProvider) == AppLanguage.ar;
    final country = KCountries.byCode(
      ref.watch(currentUserProvider.select((u) => u?.country)),
    );
    return ListTile(
      key: SettingsScreen.countryKey,
      leading: const Icon(Icons.place_outlined),
      title: Text(l10n.settingsCountry),
      subtitle: Text(
        country == null
            ? l10n.settingsCountryNotSet
            : '${KCountries.flag(country.code)} '
                  '${KCountries.name(country, arabic: arabic)}',
      ),
      onTap: () => showCountryPicker(context),
    );
  }
}

/// D226: «الوضع الداكن» — one switch, light ↔ dark. Until the person
/// touches it the app follows the device (owner decision #6, D68) and the
/// switch shows the device's current mode; the first toggle stores an
/// explicit choice, and «اتباع الجهاز» goes back to following the device.
class _DarkModeTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeControllerProvider);
    final followsDevice = mode == ThemeMode.system;
    final dark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final controller = ref.read(themeModeControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: SettingsScreen.themeKey,
          secondary: Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          ),
          title: Text(l10n.settingsDarkMode),
          subtitle: followsDevice
              ? Text(l10n.settingsThemeFollowsDevice)
              : null,
          value: dark,
          onChanged: (on) =>
              controller.select(on ? ThemeMode.dark : ThemeMode.light),
        ),
        if (!followsDevice)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              // Under the title (16 lead + 24 icon + 16 gap).
              padding: const EdgeInsetsDirectional.only(start: 48),
              child: TextButton.icon(
                key: SettingsScreen.themeFollowDeviceKey,
                onPressed: () => controller.select(ThemeMode.system),
                icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text(l10n.settingsThemeFollowDevice),
              ),
            ),
          ),
      ],
    );
  }
}

/// D226: «اللغة: العربية» — one switch, العربية ↔ English (on = English).
/// The choice is applied at once, kept on this device and sent to the
/// account (PHASE1_1_SCREENS §3.3/§3.4).
class _LanguageTile extends ConsumerWidget {
  const new();

  /// A language's own name, isolated in the other script's sentence.
  static String _name(AppLocalizations l10n, AppLanguage language) =>
      '\u2068${switch (language) {
        AppLanguage.ar => l10n.languageArabic,
        AppLanguage.en => l10n.languageEnglish,
      }}\u2069';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(languageControllerProvider);
    final other = language == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;
    return SwitchListTile(
      key: SettingsScreen.languageKey,
      secondary: const Icon(Icons.translate_rounded),
      title: Text(l10n.settingsLanguageCurrent(_name(l10n, language))),
      subtitle: Text(l10n.settingsLanguageSwitchTo(_name(l10n, other))),
      value: language == AppLanguage.en,
      onChanged: (_) async {
        await ref.read(languageControllerProvider.notifier).select(other);
        await ref.read(localeSyncProvider).languageChanged();
      },
    );
  }
}

/// Theme, language, active sessions and sign-out.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  static const logoutKey = Key('settings.logout');
  static const themeKey = Key('settings.theme');
  static const themeFollowDeviceKey = Key('settings.theme.followDevice');
  static const languageKey = Key('settings.language');
  static const sessionsShowAllKey = Key('settings.sessions.all');
  static const privacyKey = Key('settings.privacy');
  static const blockedKey = Key('settings.blocked');
  static const mutedKey = Key('settings.muted');
  static const storyArchiveKey = Key('settings.storyArchive');
  static const notificationsKey = Key('settings.notifications');
  static const countryKey = Key('settings.country');
  static const usernameKey = Key('settings.username');
  static const usernameLockedKey = Key('settings.username.locked');
  static const baseUsernameKey = Key('settings.username.base');
  static const soundEffectsKey = Key('settings.soundEffects');
  static const deleteAccountKey = Key('settings.deleteAccount');

  static String _username(WidgetRef ref) =>
      ref.watch(currentUserProvider.select((u) => u?.username)) ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: KAppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(vertical: KSpacing.lg),
        children: [
          _SectionHeader(l10n.settingsAppearance),
          const _DarkModeTile(),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsLanguage),
          const _LanguageTile(),
          // D133: the person's own country (the live hub's Nearby).
          if (ref.watch(currentUserProvider) != null) ...[
            const SizedBox(height: KSpacing.sm),
            const _CountryTile(),
          ],
          // D145d: the app's sound effects (the MAX X taps and wins).
          const SizedBox(height: KSpacing.sm),
          SwitchListTile(
            key: soundEffectsKey,
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settingsSoundEffects),
            subtitle: Text(l10n.settingsSoundEffectsHint),
            value: ref.watch(soundEffectsProvider),
            onChanged: (on) =>
                ref.read(soundEffectsProvider.notifier).set(on: on),
          ),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.settingsSessions),
          const _SessionsSection(),
          const SizedBox(height: KSpacing.xl),
          _SectionHeader(l10n.safetySection),
          // CP-009: which kinds of activity notify you.
          ListTile(
            key: notificationsKey,
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(l10n.notificationsSettings),
            onTap: () =>
                GoRouter.maybeOf(context)?.push(AppRoutes.notificationSettings),
          ),
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
          // D146: the username (with its premium badge) and the store.
          Builder(
            builder: (context) {
              // D185 (§10.48.1): a locked special username, with the
              // person's own base username — shown only here and on the
              // change screen (never to anyone else).
              final special = ref.watch(
                currentUserProvider.select((u) => u?.specialUsername),
              );
              final locked = special != null && special.locked;
              return ListTile(
                key: usernameKey,
                leading: const Icon(Icons.alternate_email_rounded),
                title: Text(l10n.settingsUsername),
                // D158: a premium username has no «@».
                subtitle: special == null
                    ? Text(
                        KHandle.isolated(
                          _username(ref),
                          premiumTier: ref.watch(
                            currentUserProvider.select((u) => u?.premiumTier),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(KHandle.isolated(special.username)),
                          Text(
                            l10n.settingsBaseUsername(
                              KHandle.isolated(special.baseUsername),
                            ),
                            key: baseUsernameKey,
                            style: context.textStyles.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                trailing: locked
                    ? Semantics(
                        key: usernameLockedKey,
                        label: l10n.settingsUsernameLocked,
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      )
                    : null,
                onTap: () =>
                    GoRouter.maybeOf(context)?.push(AppRoutes.changeUsername),
              );
            },
          ),
          // D226: «اليوزرات المميزة» and «مستوياتي» are in the «أنا» hub
          // (MeHubItem.premium / MeHubItem.levels), not repeated here.
          // D193: «حذف الحساب» (Apple 5.1.1(v), Google Play).
          ListTile(
            key: deleteAccountKey,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: context.palette.error,
            ),
            title: Text(l10n.settingsDeleteAccount),
            subtitle: Text(l10n.settingsDeleteAccountHint),
            onTap: () =>
                GoRouter.maybeOf(context)?.push(AppRoutes.deleteAccount),
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
          // D226 (owner «وازل معرض المكونات»): the KL-022 component
          // gallery is removed from the app (no row, no route, no screen).
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

/// D226 (owner): the two most recent sessions (this device always one of
/// them) and «عرض الكل (N)» for the full list ([SessionsScreen]).
class _SessionsSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsProvider);

    return switch (sessions) {
      AsyncValue(:final value?) => Column(
        children: [
          for (final s in orderSessions(value).take(kSettingsSessionsShown))
            SessionTile(session: s),
          if (!value.any((s) => !s.current)) const SessionsNoOthers(),
          if (value.length > kSettingsSessionsShown)
            ListTile(
              key: SettingsScreen.sessionsShowAllKey,
              leading: const Icon(Icons.devices_rounded),
              title: Text(l10n.sessionsShowAll(value.length)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => GoRouter.maybeOf(context)?.push(AppRoutes.sessions),
            ),
          // D226 (v1.79-social): only while another session exists.
          RevokeOthersButton(sessions: value),
        ],
      ),
      AsyncValue(:final error?, isLoading: false) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.lg),
        child: SessionsError(error: error),
      ),
      _ => const Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: KSpacing.lg),
        child: SessionsSkeleton(rows: kSettingsSessionsShown),
      ),
    };
  }
}
