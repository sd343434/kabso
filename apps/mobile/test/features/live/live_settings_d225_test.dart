// D225 (owner, 2026-11-01): the live settings rearranged per live type —
// «إعدادات البث» first in ≡ Room Tools in every mode, the host's mic on every
// bar, YouTube in the audio room only, the podcast bar without PK, «كتم
// الجميع» (seat rooms), the host's camera off (video lives), and the viewer's
// «إعدادات المشاهدة» (this live's sound, reset when they leave). Fakes stand in
// for the API and the media engine (tests only). With
// --dart-define=D225_CAPTURE_DIR=<dir> the owner's captures are written
// (393×852 @3x).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_settings_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_live_watch_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D225_CAPTURE_DIR');

/// Writes the screen as it is now to [_captureDir]/[name].png.
Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final size = tester.view.physicalSize;
    final image = await layer.toImage(Offset.zero & size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(_captureDir).create(recursive: true);
    await File('$_captureDir/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
}

AppLocalizations _l10n(WidgetTester tester, Type screen) =>
    AppLocalizations.of(tester.element(find.byType(screen)));

Finder _tile(String id) => find.byKey(GoLiveKeys.tool(id));
Finder _row(String id) => find.byKey(LiveSettingsSheet.itemKey(id));

bool _switchOn(WidgetTester tester, String id) => tester
    .widget<Switch>(
      find.descendant(of: _row(id), matching: find.byType(Switch)),
    )
    .value;

/// The host on air in [mode] (the fakes answer like the server).
Future<(FakeLiveRepository, FakeLiveMediaEngine)> _hostOnAir(
  WidgetTester tester, {
  required LiveRoomMode mode,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  FakeLivePkRepository? pk,
}) async {
  final repo = FakeLiveRepository(
    categories: const [LiveCategory(slug: 'chat', name: 'Chat')],
  );
  final engine = FakeLiveMediaEngine();
  setViewport(tester, viewport);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: engine,
    livePkRepository: pk,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
  if (mode != LiveRoomMode.solo) {
    // D224: the type row scrolls sideways (the podcast may be off screen).
    await tester.ensureVisible(find.byKey(GoLiveKeys.mode(mode)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoLiveKeys.mode(mode)));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'سهرة');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pump();
  if (mode.isVoice) {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }
  await tester.pumpAndSettle();
  expect(repo.startRequests.single.mode, mode);
  // The text scale applies on air only: the go-live setup's mode tabs are
  // D224's (they overflow at ×1.3 on 393 and 360 dp before this change too).
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
  }
  return (repo, engine);
}

Future<void> _openTools(WidgetTester tester, LiveRoomMode mode) async {
  await tester.tap(
    find.byKey(mode.isVoice ? GoLiveScreen.audioMoreKey : KHostBar.toolsKey),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester, LiveRoomMode mode) async {
  await _openTools(tester, mode);
  await tester.tap(_tile('liveSettings'));
  await tester.pumpAndSettle();
  expect(find.byKey(LiveSettingsSheet.sheetKey), findsOneWidget);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 12));
}

/// The ids of the tools in the open Room Tools sheet, in order.
List<String> _toolIds(WidgetTester tester) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w is GestureDetector &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('goLive.tool.'),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('goLive.tool.'.length),
];

void main() {
  // The bundled fonts, so the owner's captures show real text.
  setUpAll(() async {
    if (_captureDir.isNotEmpty) await loadAppFonts();
  });

  group('host: Room Tools and the bar per mode', () {
    testWidgets('SOLO: «إعدادات البث» first; the mic, the voice, YouTube, '
        'beauty, the filters, the chat, the visitors and the schedule are not '
        'repeated; D253: the mic is in ≡, not on the bar', (tester) async {
      final (_, engine) = await _hostOnAir(tester, mode: LiveRoomMode.solo);
      expect(find.byKey(KHostBar.micKey), findsNothing);
      await _openTools(tester, LiveRoomMode.solo);
      await tester.tap(find.byKey(GoLiveKeys.tool('mic')));
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isFalse);
      expect(find.byKey(GoLiveScreen.micOffKey), findsOneWidget);
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      await _capture(tester, 'solo.bar.ar');
      await _openTools(tester, LiveRoomMode.solo);
      final ids = _toolIds(tester);
      expect(ids.first, 'liveSettings');
      for (final gone in [
        'voice',
        'youtube',
        'beauty',
        'magic',
        'chat',
        'guests',
        'time',
        'theme',
        'seats',
      ]) {
        expect(ids, isNot(contains(gone)), reason: gone);
      }
      for (final kept in [
        'share',
        'fillLight',
        'flip',
        'dual',
        'quality',
        'sticker',
        'music',
        'sounds',
        'minimize',
        'wish',
        'topic',
        'viewers',
        'management',
        'recorder',
        'traffic',
        'mic',
        'quickReplies',
      ]) {
        expect(ids, contains(kept), reason: kept);
      }
      await _capture(tester, 'solo.tools.ar');
      await _leave(tester);
    });

    testWidgets('PK (inside SOLO): the same tools, «إعدادات البث» first, no '
        'YouTube', (tester) async {
      final pk = FakeLivePkRepository();
      await _hostOnAir(tester, mode: LiveRoomMode.solo, pk: pk);
      final element = tester.element(find.byType(GoLiveScreen));
      ProviderScope.containerOf(element)
          .read(livePkProvider('room-host').notifier)
          .debugSetMatch(
            pkMatchFixture(now: DateTime.now(), ownRoom: 'room-host'),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(GoLiveScreen.pkStageKey), findsOneWidget);
      expect(find.byKey(KHostBar.micKey), findsNothing);
      await _openTools(tester, LiveRoomMode.solo);
      final ids = _toolIds(tester);
      expect(ids.first, 'liveSettings');
      expect(ids, isNot(contains('youtube')));
      await _leave(tester);
    });

    testWidgets('AUDIO: «إعدادات البث», the mic (D225b), YouTube, music, '
        'sounds, seat emoji, program, topic, wishes; no screen share, '
        'singing, seats or theme tiles; the bar: ≡ … ∞, PK «قريباً», games, '
        'gift — no mic (D225b)', (tester) async {
      final (_, engine) = await _hostOnAir(tester, mode: LiveRoomMode.audio);
      final l10n = _l10n(tester, GoLiveScreen);
      // D225b (owner: «ضع زر المايك في ادوات الغرفة وارجع pk هذا
      // للمضيف»): the bar's PK is back as before D225, the mic is in ≡.
      expect(find.byKey(GoLiveScreen.barMicKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioPkKey), findsOneWidget);
      expect(find.byKey(LiveAudioRoomLayout.crowdedBarKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioGamesKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.audioPkKey));
      await tester.pump();
      expect(find.text(l10n.goLivePkSoon), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await _capture(tester, 'audio.bar.ar');
      await _openTools(tester, LiveRoomMode.audio);
      // The mic tile, toggled while the mic is on; a tap mutes.
      final mic = _tile('mic');
      expect(
        tester.getSemantics(mic).flagsCollection.isToggled,
        ui.Tristate.isTrue,
      );
      expect(
        find.descendant(of: mic, matching: find.text(l10n.goLiveMicrophone)),
        findsOneWidget,
      );
      final ids = _toolIds(tester);
      expect(ids.take(9), [
        'liveSettings',
        'mic',
        'youtube',
        'music',
        'sounds',
        'seatEmoji',
        'program',
        'topic',
        'wish',
      ]);
      for (final gone in [
        'screen',
        'singing',
        'seats',
        'theme',
        'voice',
        'chat',
        'guests',
        'time',
      ]) {
        expect(ids, isNot(contains(gone)), reason: gone);
      }
      // «التسجيل» stays where it was, an honest «قريباً».
      expect(ids, contains('recorder'));
      await _capture(tester, 'audio.tools.ar');
      // A tap on the mic tile mutes (the sheet closes); the tile then says
      // so the next time ≡ opens.
      await tester.tap(mic);
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isFalse);
      await _openTools(tester, LiveRoomMode.audio);
      expect(
        tester.getSemantics(_tile('mic')).flagsCollection.isToggled,
        ui.Tristate.isFalse,
      );
      await tester.tap(_tile('mic'));
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isTrue);
      await _leave(tester);
    });

    testWidgets('PODCAST: «إعدادات البث», the hands, music (intro / outro); '
        'no YouTube, no seats; the bar: mic, ✋, games, gift — no PK', (
      tester,
    ) async {
      await _hostOnAir(tester, mode: LiveRoomMode.podcast);
      expect(find.byKey(GoLiveScreen.barMicKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.audioPkKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioGamesKey), findsOneWidget);
      await _capture(tester, 'podcast.bar.ar');
      await _openTools(tester, LiveRoomMode.podcast);
      final ids = _toolIds(tester);
      expect(ids.take(3), ['liveSettings', 'hands', 'music']);
      for (final gone in ['youtube', 'seats', 'screen', 'singing', 'theme']) {
        expect(ids, isNot(contains(gone)), reason: gone);
      }
      expect(ids, contains('seatEmoji'));
      expect(ids, contains('recorder'));
      await _capture(tester, 'podcast.tools.ar');
      await _leave(tester);
    });
  });

  group('«إعدادات البث» per mode', () {
    testWidgets('SOLO: sound, camera, room, general — no seats or questions; '
        'the camera turns off and on (the track muted)', (tester) async {
      final (_, engine) = await _hostOnAir(tester, mode: LiveRoomMode.solo);
      await _openSettings(tester, LiveRoomMode.solo);
      await _capture(tester, 'solo.settings.ar');
      for (final id in [
        'mic',
        'noise',
        'enhance',
        'camera',
        'flip',
        'quality',
        'light',
        'chat',
        'blockedWords',
        'guests',
        'wish',
        // D305: the account's strip switches, in the host's sheet too.
        'giftStrip',
        'gameStrip',
        'schedule',
      ]) {
        await tester.scrollUntilVisible(
          _row(id),
          60,
          scrollable: find.descendant(
            of: find.byKey(LiveSettingsSheet.sheetKey),
            matching: find.byType(Scrollable),
          ),
        );
        expect(_row(id), findsOneWidget, reason: id);
      }
      for (final id in ['seatCount', 'muteAll', 'questions', 'theme']) {
        expect(_row(id), findsNothing, reason: id);
      }
      await tester.scrollUntilVisible(
        _row('camera'),
        -60,
        scrollable: find.descendant(
          of: find.byKey(LiveSettingsSheet.sheetKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(_switchOn(tester, 'camera'), isTrue);
      // D305: two more rows above; bring the row fully into view.
      await tester.ensureVisible(_row('camera'));
      await tester.pumpAndSettle();
      await tester.tap(_row('camera'));
      await tester.pumpAndSettle();
      expect(engine.videoPaused, isTrue);
      expect(_switchOn(tester, 'camera'), isFalse);
      await tester.tap(_row('camera'));
      await tester.pumpAndSettle();
      expect(engine.videoPaused, isFalse);
      await _leave(tester);
    });

    testWidgets('the settings mic mutes the host (every mode has it)', (
      tester,
    ) async {
      final (_, engine) = await _hostOnAir(tester, mode: LiveRoomMode.podcast);
      await _openSettings(tester, LiveRoomMode.podcast);
      expect(_switchOn(tester, 'mic'), isTrue);
      await tester.tap(_row('mic'));
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isFalse);
      expect(_switchOn(tester, 'mic'), isFalse);
      await _leave(tester);
    });

    testWidgets('AUDIO: no camera group; seats, «كتم الجميع» and the theme', (
      tester,
    ) async {
      await _hostOnAir(tester, mode: LiveRoomMode.audio);
      await _openSettings(tester, LiveRoomMode.audio);
      await _capture(tester, 'audio.settings.ar');
      expect(_row('camera'), findsNothing);
      expect(_row('seatCount'), findsOneWidget);
      expect(_row('muteAll'), findsOneWidget);
      expect(_row('theme'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('PODCAST: the questions (open / closed, the time), «كتم '
        'الجميع», no seat count and no camera', (tester) async {
      final (repo, _) = await _hostOnAir(tester, mode: LiveRoomMode.podcast);
      await _openSettings(tester, LiveRoomMode.podcast);
      await _capture(tester, 'podcast.settings.ar');
      expect(_row('seatCount'), findsNothing);
      expect(_row('camera'), findsNothing);
      expect(_row('questions'), findsOneWidget);
      expect(_row('questionTime'), findsOneWidget);
      expect(_row('muteAll'), findsOneWidget);
      expect(_switchOn(tester, 'questions'), isTrue);
      await tester.tap(_row('questions'));
      await tester.pumpAndSettle();
      expect(repo.podcastSettings.last.questionsOpen, isFalse);
      expect(_switchOn(tester, 'questions'), isFalse);
      await tester.tap(_row('questionTime'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveSettingsSheet.optionKey('picker', 0)));
      await tester.pumpAndSettle();
      expect(repo.podcastSettings.last.setSeconds, isTrue);
      expect(repo.podcastSettings.last.seconds, 60);
      await _leave(tester);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final viewport in GoldenViewport.values) {
        // D369: no multi-guest mode for a host any more (retired).
        for (final mode in [
          LiveRoomMode.solo,
          LiveRoomMode.audio,
          LiveRoomMode.podcast,
        ]) {
          testWidgets('no overflow: ${mode.name} bar, tools and settings '
              '(${language.name}, ${viewport.name}, ×1.3)', (tester) async {
            await _hostOnAir(
              tester,
              mode: mode,
              language: language,
              viewport: viewport,
              textScale: 1.3,
            );
            expect(tester.takeException(), isNull);
            // Every bar button is on screen (a crowded voice bar scrolls).
            expect(find.byKey(LiveAudioRoomLayout.crowdedBarKey), findsNothing);
            if (mode.isVoice) {
              // D225b: the audio room's PK is back; the gift stays on screen.
              final gift = tester.getRect(
                find.byKey(GoLiveScreen.audioGiftKey),
              );
              final width =
                  tester.view.physicalSize.width / tester.view.devicePixelRatio;
              expect(gift.left, greaterThanOrEqualTo(0));
              expect(gift.right, lessThanOrEqualTo(width));
              expect(
                find.byKey(GoLiveScreen.audioPkKey),
                mode == LiveRoomMode.audio ? findsOneWidget : findsNothing,
              );
              expect(
                find.byKey(GoLiveScreen.barMicKey),
                mode == LiveRoomMode.podcast ? findsOneWidget : findsNothing,
              );
            }
            await _openSettings(tester, mode);
            expect(tester.takeException(), isNull);
            await tester.fling(
              find.descendant(
                of: find.byKey(LiveSettingsSheet.sheetKey),
                matching: find.byType(Scrollable),
              ),
              const Offset(0, -600),
              2000,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await _leave(tester);
          });
        }
      }
    }
  });

  group('viewer «إعدادات المشاهدة»', () {
    Future<FakeLiveMediaEngine> viewer(
      WidgetTester tester, {
      LiveRoomMode mode = LiveRoomMode.solo,
      AppLanguage language = AppLanguage.ar,
      GoldenViewport viewport = GoldenViewport.phone,
      double textScale = 1,
      FakeLiveMediaEngine? engine,
    }) async {
      setViewport(tester, viewport);
      if (textScale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final camera = engine ?? (FakeLiveMediaEngine()..present.add('user-0'));
      final repo = FakeLiveRepository(
        room: (id) {
          final room = apiRoom(id: id, ar: language == AppLanguage.ar);
          return mode == LiveRoomMode.audio
              ? room.copyWith(mode: mode, seatCount: 10)
              : room;
        },
      );
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        language: language,
        liveMediaEngine: camera,
        liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
        liveWatchRepository: FakeLiveWatchRepository(),
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile()),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      return camera;
    }

    Future<void> openMenu(WidgetTester tester) async {
      final video = find.byKey(LiveRoomScreen.menuKey);
      await tester.tap(
        video.evaluate().isNotEmpty
            ? video
            : find.byKey(AudioRoomViewKeys.menu),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openViewerSettings(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(_tile('viewerSettings'));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveSettingsSheet.sheetKey), findsOneWidget);
    }

    testWidgets('≡: «إعدادات المشاهدة» first; the old «قريباً» tiles are gone; '
        'no YouTube suggestion in a video live', (tester) async {
      await viewer(tester);
      await openMenu(tester);
      final ids = _toolIds(tester);
      expect(ids.first, 'viewerSettings');
      for (final gone in [
        'giftSounds',
        'giftEffects',
        'clearScreen',
        'suggestVideo',
      ]) {
        expect(ids, isNot(contains(gone)), reason: gone);
      }
      await _leave(tester);
    });

    testWidgets('AUDIO: the YouTube suggestion stays', (tester) async {
      await viewer(tester, mode: LiveRoomMode.audio);
      await openMenu(tester);
      expect(_toolIds(tester), contains('suggestVideo'));
      await tester.tap(_tile('viewerSettings'));
      await tester.pumpAndSettle();
      // A voice room has no data saver (there is no video to save).
      expect(_row('dataSaver'), findsNothing);
      await _capture(tester, 'viewer.audio.settings.ar');
      await _leave(tester);
    });

    testWidgets('«كتم صوت البث عندي» mutes this live here only, and resets '
        'when the viewer leaves the live', (tester) async {
      final engine = await viewer(tester);
      await openViewerSettings(tester);
      await _capture(tester, 'viewer.settings.ar');
      expect(_switchOn(tester, 'muteLive'), isFalse);
      await tester.tap(_row('muteLive'));
      await tester.pumpAndSettle();
      expect(engine.playbackVolume, 0);
      expect(_switchOn(tester, 'muteLive'), isTrue);
      // Leave the live, come back: the live plays again.
      await _leave(tester);
      final again = await viewer(tester);
      await openViewerSettings(tester);
      expect(_switchOn(tester, 'muteLive'), isFalse);
      expect(again.volumeCalls, isEmpty);
      await _leave(tester);
    });

    testWidgets('the effects and sounds switches are kept on this device', (
      tester,
    ) async {
      await viewer(tester);
      await openViewerSettings(tester);
      for (final id in [
        'giftSounds',
        'giftEffects',
        'quipSounds',
        'entrances',
      ]) {
        await tester.tap(_row(id));
        await tester.pumpAndSettle();
        expect(_switchOn(tester, id), isTrue, reason: id);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(LiveViewerPrefsController.giftSoundsKey), isTrue);
      expect(prefs.getBool(LiveViewerPrefsController.giftEffectsKey), isTrue);
      expect(prefs.getBool(LiveViewerPrefsController.entrancesKey), isTrue);
      expect(prefs.getBool(QuipsMuted.prefKey), isTrue);
      await _leave(tester);
    });

    testWidgets('clean screen hides the chat; «إظهار الكل» brings it back', (
      tester,
    ) async {
      await viewer(tester);
      expect(find.byType(LiveRoomChatLines), findsOneWidget);
      await openViewerSettings(tester);
      await tester.scrollUntilVisible(
        _row('clean'),
        60,
        scrollable: find.descendant(
          of: find.byKey(LiveSettingsSheet.sheetKey),
          matching: find.byType(Scrollable),
        ),
      );
      // D305: two more rows above; bring the row fully into view.
      await tester.ensureVisible(_row('clean'));
      await tester.pumpAndSettle();
      await tester.tap(_row('clean'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomChatLines), findsNothing);
      expect(find.byKey(LiveRoomScreen.cleanRestoreKey), findsOneWidget);
      await tester.tap(find.byKey(LiveRoomScreen.cleanRestoreKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomChatLines), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('data saver (video lives): no video received, the host '
        'picture instead', (tester) async {
      final engine = await viewer(tester);
      await openViewerSettings(tester);
      await tester.scrollUntilVisible(
        _row('dataSaver'),
        60,
        scrollable: find.descendant(
          of: find.byKey(LiveSettingsSheet.sheetKey),
          matching: find.byType(Scrollable),
        ),
      );
      // D305: two more rows above; bring the row fully into view.
      await tester.ensureVisible(_row('dataSaver'));
      await tester.pumpAndSettle();
      await tester.tap(_row('dataSaver'));
      await tester.pumpAndSettle();
      expect(engine.receiveVideo, isFalse);
      await tester.tapAt(const Offset(200, 120));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.dataSaverKey), findsOneWidget);
      await _leave(tester);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final viewport in GoldenViewport.values) {
        for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
          testWidgets('no overflow: viewer ${mode.name} settings '
              '(${language.name}, ${viewport.name}, ×1.3)', (tester) async {
            await viewer(
              tester,
              mode: mode,
              language: language,
              viewport: viewport,
              textScale: 1.3,
            );
            await openViewerSettings(tester);
            expect(tester.takeException(), isNull);
            await tester.fling(
              find.descendant(
                of: find.byKey(LiveSettingsSheet.sheetKey),
                matching: find.byType(Scrollable),
              ),
              const Offset(0, -600),
              2000,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await _leave(tester);
          });
        }
      }
    }
  });

  test('the viewer prefs default off', () {
    const prefs = LiveViewerPrefs();
    expect(prefs.giftSoundsMuted, isFalse);
    expect(prefs.chatTextSize, LiveChatTextSize.normal);
  });
}
