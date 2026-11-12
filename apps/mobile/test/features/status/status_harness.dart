// D376 «الحالة»: pumps the status picker, «متجر الحالة», a profile and the
// audio seats with fake repositories, for the widget tests and the goldens
// (393 × 852, status bar 59, home indicator 34, real fonts).

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/status/status_picker_sheet.dart';
import 'package:kabso_live/features/status/status_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/status/status_fixtures.dart';
import '../../helpers/fake_status_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class StatusCoins extends LiveCoinsController {
  new(this._coins);

  final int _coins;

  @override
  Future<int> build() async => _coins;
}

/// The phone with its insets and the app's fonts.
Future<void> statusDevice(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.reset);
}

/// Loads every status emoji's Lottie outside the fake-async zone (the
/// bubbles draw a composition that is already parsed).
Future<void> precacheStatusArt(WidgetTester tester, [Iterable<String>? ids]) =>
    tester.runAsync(
      () => StatusEmojiArt.precache([
        for (final id
            in ids ??
                StatusCatalogue.packs.expand((p) => p.emojis).map((e) => e.id))
          StatusCatalogue.byId(id)!.asset,
      ]),
    );

/// Lets the grid cells' `Lottie.asset` finish loading (real I/O), then
/// draws a few frames (never `pumpAndSettle`: the selected cell plays).
Future<void> settleStatus(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// The overrides every status screen needs.
List<Override> statusOverrides(FakeStatusRepository repo, {int coins = 0}) => [
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  currentUserProvider.overrideWithValue(testUser()),
  statusRepositoryProvider.overrideWithValue(repo),
  liveCoinsProvider.overrideWith(() => StatusCoins(coins)),
  // A profile: no level badges, an empty grid.
  profileLevelsProvider.overrideWith((ref, _) async => const []),
  profileGridProvider.overrideWith(
    (ref, _) => const FeedItems<ProfileGridItem>([]),
  ),
];

/// Opens the picker as Edit profile does (a modal sheet over a page).
class StatusSheetHost extends StatefulWidget {
  const new({required this.initialId, super.key, this.onPick});

  final String? initialId;
  final ValueChanged<StatusPick?>? onPick;

  @override
  State<StatusSheetHost> createState() => _StatusSheetHostState();
}

class _StatusSheetHostState extends State<StatusSheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pick = await showModalBottomSheet<StatusPick>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => StatusPickerSheet(
          initialId: widget.initialId,
          displayName: 'Layla',
        ),
      );
      widget.onPick?.call(pick);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// Pumps [screen] on the phone with [repo] (the «المميزة» offer; not held
/// unless [repo] says so).
Future<FakeStatusRepository> pumpStatus(
  WidgetTester tester,
  Widget screen, {
  FakeStatusRepository? repo,
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.dark,
  int coins = 250000,
  bool disableAnimations = false,
  List<Override> overrides = const [],
}) async {
  await statusDevice(tester);
  final fake = repo ?? FakeStatusRepository(list: statusPackListFixture());
  await precacheStatusArt(tester);
  await pumpScreen(
    tester,
    screen,
    language: language,
    brightness: brightness,
    disableAnimations: disableAnimations,
    overrides: [
      ...statusOverrides(fake, coins: coins),
      ...overrides,
    ],
  );
  await settleStatus(tester);
  return fake;
}
