import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/storage/fresh_install.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class _FailingStore extends InMemoryTokenStore {
  new() : super('sid.stale');

  @override
  Future<void> clear() => Future.error(Exception('keychain locked'));
}

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test(
    'first launch after (re)install clears a surviving refresh token',
    () async {
      final prefs = await prefsWith({});
      final store = InMemoryTokenStore('sid.from-previous-install');

      final cleared = await clearSecureStorageOnFreshInstall(
        prefs: prefs,
        store: store,
      );

      expect(cleared, isTrue);
      expect(store.refreshToken, isNull);
      expect(prefs.getBool(PreferenceKeys.installed), isTrue);
    },
  );

  test('later launches keep the session', () async {
    final prefs = await prefsWith({PreferenceKeys.installed: true});
    final store = InMemoryTokenStore('sid.current');

    final cleared = await clearSecureStorageOnFreshInstall(
      prefs: prefs,
      store: store,
    );

    expect(cleared, isFalse);
    expect(store.refreshToken, 'sid.current');
    expect(store.clears, 0);
  });

  test('runs once: the second launch does not clear a new login', () async {
    final prefs = await prefsWith({});
    final store = InMemoryTokenStore('sid.stale');
    await clearSecureStorageOnFreshInstall(prefs: prefs, store: store);
    await store.writeRefreshToken('sid.new-login');

    await clearSecureStorageOnFreshInstall(prefs: prefs, store: store);

    expect(store.refreshToken, 'sid.new-login');
    expect(store.clears, 1);
  });

  test('a failed clear does not set the flag, so it is retried', () async {
    final prefs = await prefsWith({});
    final SecureTokenStore store = _FailingStore();

    final cleared = await clearSecureStorageOnFreshInstall(
      prefs: prefs,
      store: store,
    );

    expect(cleared, isFalse);
    expect(prefs.getBool(PreferenceKeys.installed), isNull);
  });
}
