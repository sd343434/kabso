// D217 (v1.74-social): `DeviceInfo.installId` is a random id kept per install.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/ids/install_id.dart';
import 'package:kabso_live/core/storage/preferences.dart';

import '../helpers/pump_app.dart';

void main() {
  test('a new install saves a random id and keeps it', () async {
    final prefs = await testPrefs();
    final first = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final id = first.read(installIdProvider);
    expect(id, matches(RegExp(r'^[A-Za-z0-9-]{8,64}$')));
    await pumpEventQueue();
    expect(prefs.getString(PreferenceKeys.installId), id);

    final again = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(again.read(installIdProvider), id);
  });

  test(
    'another install gets another id; a malformed saved id is replaced',
    () async {
      final a = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await testPrefs()),
        ],
      ).read(installIdProvider);
      final prefs = await testPrefs(
        extra: {PreferenceKeys.installId: 'bad id!'},
      );
      final b = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      ).read(installIdProvider);
      expect(b, isNot('bad id!'));
      expect(b, isNot(a));
    },
  );

  test('without preferences no id is sent (as from an older app)', () {
    expect(ProviderContainer.test().read(installIdProvider), isNull);
  });
}
