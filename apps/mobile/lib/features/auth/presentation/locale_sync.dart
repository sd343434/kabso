import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// Keeps the account's stored locale in line with the device's language
/// choice (PHASE1_1_SCREENS §3.4, contract v1.2 `PATCH /me`).
///
/// Never blocks or reverts the UI; failures are silent and retried later.
class LocaleSync {
  new(this._ref);

  final Ref _ref;

  /// Guards against overlapping PATCH calls (e.g. a retry triggered by the
  /// refresh that the PATCH itself caused).
  bool _pushing = false;

  /// QA-011: the latest language requested while a PATCH is in flight.
  /// Requests coalesce, so the **last** user choice always wins: it is
  /// pushed as soon as the in-flight PATCH completes.
  AppLanguage? _next;

  LanguageController get _language =>
      _ref.read(languageControllerProvider.notifier);

  /// After login 200 or register/verify 201.
  ///
  /// - A local explicit choice that differs from `me.locale` → `PATCH /me`.
  /// - No local choice and `me.locale` differs from the displayed language →
  ///   adopt `me.locale` (stored as the choice), no PATCH.
  Future<void> afterSignIn(User user) async {
    final displayed = _ref.read(languageControllerProvider);
    if (_language.hasExplicitChoice) {
      if (displayed.name != user.locale) {
        await _push(displayed);
      } else {
        await _setPending(value: false);
      }
      return;
    }
    final account = AppLanguage.tryParse(user.locale);
    if (account != null && account != displayed) {
      await _language.select(account);
    }
  }

  /// The user picked a language while signed in (Settings): already applied
  /// locally; persist it on the server in the background.
  Future<void> languageChanged() async {
    if (_ref.read(currentUserProvider) == null) return;
    await _push(_ref.read(languageControllerProvider));
  }

  /// App start with a restored session: retry a sync that failed earlier.
  Future<void> retryPending() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (!(prefs.getBool(PreferenceKeys.localeSyncPending) ?? false)) return;
    if (_ref.read(currentUserProvider) == null) return;
    await _push(_ref.read(languageControllerProvider));
  }

  Future<void> _push(AppLanguage language) async {
    _next = language;
    if (_pushing) {
      // Durable until the queued value lands (survives an app kill).
      await _setPending(value: true);
      return;
    }
    _pushing = true;
    try {
      for (var target = _next; target != null; target = _next) {
        _next = null;
        if (!await _pushOnce(target)) {
          // Retryable failure: the flag is set; retryPending() later pushes
          // whatever language is displayed then.
          _next = null;
          break;
        }
      }
    } finally {
      _pushing = false;
    }
  }

  /// One PATCH. Returns `false` on a retryable failure.
  Future<bool> _pushOnce(AppLanguage language) async {
    try {
      final user = await _ref
          .read(authRepositoryProvider)
          .updateLocale(language.name);
      // A newer choice is queued: keep the flag until it lands.
      if (_next == null) await _setPending(value: false);
      _ref.read(sessionControllerProvider.notifier).updateUser(user);
      return true;
    } on AppFailure catch (f) {
      if (f.code == ErrorCode.validationFailed) {
        // 400: retrying cannot help; drop the flag.
        AppLogger.warning('Locale sync rejected: ${f.code.wire}');
        if (_next == null) await _setPending(value: false);
        return true;
      }
      // Offline, timeout, 5xx, 429 (401 is handled globally): retry later.
      await _setPending(value: true);
      return false;
    }
  }

  Future<void> _setPending({required bool value}) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (value) {
      await prefs.setBool(PreferenceKeys.localeSyncPending, true);
    } else {
      await prefs.remove(PreferenceKeys.localeSyncPending);
    }
  }
}

final localeSyncProvider = Provider<LocaleSync>(LocaleSync.new);
