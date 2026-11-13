// D240: «القريبة»'s country — the viewer's own choice kept on the device,
// defaulting to the profile country; it never changes the profile.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> make({
    String? profile,
    Map<String, Object> saved = const {},
  }) async {
    final prefs = await testPrefs(extra: saved);
    return ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(
          testUser().copyWith(country: profile),
        ),
      ],
    );
  }

  test('defaults to the profile country; none: null', () async {
    expect((await make(profile: 'JO')).read(liveCountryProvider), 'JO');
    expect((await make()).read(liveCountryProvider), isNull);
  });

  test('a choice wins, is upper-cased and kept on the device', () async {
    final c = await make(profile: 'JO');
    c.read(liveNearbyChoiceProvider.notifier).choose('eg');
    expect(c.read(liveCountryProvider), 'EG');
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString(PreferenceKeys.liveNearbyCountry), 'EG');
    // A new session on this device reads it back.
    final next = await make(
      profile: 'JO',
      saved: {PreferenceKeys.liveNearbyCountry: 'EG'},
    );
    expect(next.read(liveCountryProvider), 'EG');
  });
}
