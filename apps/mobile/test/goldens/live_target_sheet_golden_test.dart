// D199b «تارجت» ranking sheet goldens (the owner's contribution-ranking
// layout, Kabso art; test fixtures only): a viewer (light, ar and en) and
// the host (dark, ar) at 393×852 @3x with the phone's insets.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_target_sheet_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_host_targets_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

const _names = ['Layla', 'Omar', 'Sara', 'Yousef', 'Noor', 'Hamza', 'Rania'];
const _amounts = [5300, 1100, 500, 500, 224, 32, 30];

List<Map<String, Object?>> _supporters() => [
  for (var i = 0; i < _names.length; i++)
    {
      'user': {
        'id': 'u$i',
        'username': 'u$i',
        'displayName': _names[i],
        'avatarUrl': null,
        if (i == 1)
          'avatarFrame': {
            'code': 'host_frame_pink',
            'assetKey': 'host_frame_pink',
          },
      },
      'coins': _amounts[i],
      'cherries': _amounts[i] * 6,
      'supportLevel': [65, 51, 54, 60, 23, 34, 50][i],
    },
];

Map<String, Object?> _targetsJson({bool withMe = true}) => {
  'day': '2026-10-31',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2026-10-31T21:00:00.000Z',
  'band': 1,
  'cherries': {'received': 12400, 'target': 50000, 'reached': false},
  'lucky': {'received': 20000, 'target': 20000, 'reached': true},
  'topSupporters': _supporters(),
  'luckySupporters': _supporters(),
  'me': withMe
      ? {
          'cherries': {'rank': null, 'amount': 0},
          'lucky': {'rank': null, 'amount': 0},
        }
      : null,
};

class _Repo extends FakeLiveHostTargetsRepository {
  new()
    : super(
        stats: {
          for (final p in HostStatsPeriod.values)
            p: HostGiftStats.fromJson({
              'period': p.wire,
              'timeZone': 'Asia/Riyadh',
              'from': '2026-10-30T21:00:00.000Z',
              'to': '2026-10-31T21:00:00.000Z',
              'cherries': {
                'received': 12400,
                'gifts': 31,
                'givers': 9,
                'topSupporters': _supporters(),
                'series': const <Object?>[],
              },
              'lucky': {
                'coins': 20000,
                'gifts': 6,
                'givers': 2,
                'topSupporters': _supporters(),
              },
              'targets': p == HostStatsPeriod.day
                  ? _targetsJson(withMe: false)
                  : null,
            }),
        },
      );

  @override
  Future<LiveHostTargets?> targets(String username) async =>
      LiveHostTargets.fromJson(_targetsJson());
}

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  required bool host,
  Brightness brightness = Brightness.light,
}) async {
  HostTargetSheet.clock = () => DateTime.utc(2026, 10, 31, 15, 43);
  addTearDown(() => HostTargetSheet.clock = DateTime.now);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        liveHostTargetsRepositoryProvider.overrideWithValue(_Repo()),
        currentUserProvider.overrideWithValue(
          testUser(displayName: 'Kabso fan'),
        ),
      ],
      child: ColoredBox(
        // The dimmed live behind the sheet (a plain stand-in).
        color: const Color(0xFF3B3346),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: HostTargetSheet(
            isHost: host,
            username: host ? null : 'host',
            onSupport: host ? null : () {},
          ),
        ),
      ),
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  await precacheImages(tester);
}

void main() {
  forEachLanguage((language) {
    testWidgets('live_target_sheet viewer, light (${language.name})', (
      tester,
    ) async {
      await _pump(tester, language: language, host: false);
      await expectScreenGolden('live_target_sheet', language: language);
    });
  });

  testWidgets('live_target_sheet host, dark (ar)', (tester) async {
    await _pump(
      tester,
      language: AppLanguage.ar,
      host: true,
      brightness: Brightness.dark,
    );
    await expectScreenGolden(
      'live_target_sheet_host_dark',
      language: AppLanguage.ar,
    );
  });
}
