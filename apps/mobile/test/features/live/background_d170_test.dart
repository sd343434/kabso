// D170 (owner): a live goes on in the background for everyone. A video
// host in the background has the camera off (muted track): viewers see
// «سيعود المضيف قريباً» ("the host will be right back") instead of a black
// or frozen picture, and it clears when the host returns. The platform
// configuration that keeps the audio running is checked here too.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _hostAway = Key('room.hostAway');

Future<FakeLiveMediaEngine> _pumpRoom(
  WidgetTester tester, {
  required AppLanguage language,
}) async {
  final engine = FakeLiveMediaEngine();
  final hostId = apiRoom().host.id;
  engine.present.add(hostId);
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return engine;
}

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('video live, ${language.name}: the host in the background '
        '(camera muted) shows "the host will be right back"; back → video', (
      tester,
    ) async {
      final engine = await _pumpRoom(tester, language: language);
      final hostId = apiRoom().host.id;
      expect(find.byKey(Key('remote.$hostId')), findsOneWidget);
      expect(find.byKey(_hostAway), findsNothing);

      // The host's app goes to the background: the camera track is muted.
      engine.videoMutedIds.add(hostId);
      engine.ping();
      await tester.pump();
      expect(find.byKey(_hostAway), findsOneWidget);
      expect(find.byKey(Key('remote.$hostId')), findsNothing);
      final text = ar ? 'سيعود المضيف قريباً' : 'The host will be right back';
      expect(find.text(text), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(text))),
        ar ? TextDirection.rtl : TextDirection.ltr,
      );
      // The viewer stays in the room: nothing left the media session.
      expect(engine.stops, 0);

      // Back in the foreground: the camera resumes, the note goes.
      engine.videoMutedIds.remove(hostId);
      engine.ping();
      await tester.pump();
      expect(find.byKey(_hostAway), findsNothing);
      expect(find.byKey(Key('remote.$hostId')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('HOST_AWAY_TIMEOUT is read and told in both languages', () {
    final json =
        jsonDecode(jsonEncode(apiRoom().toJson())) as Map<String, dynamic>
          ..['status'] = 'ENDED'
          ..['endReason'] = 'HOST_AWAY_TIMEOUT';
    final room = LiveRoom.fromJson(json);
    expect(room.endReason, LiveRoomEndReason.hostAwayTimeout);
    expect(
      endReasonText(lookupAppLocalizations(const Locale('ar')), room.endReason),
      'انتهى البث لأن المضيف غاب أكثر من 5 دقائق.',
    );
    expect(
      endReasonText(lookupAppLocalizations(const Locale('en')), room.endReason),
      'The live ended because the host was away for more than 5 minutes.',
    );
  });

  group('platform configuration (D123, D170)', () {
    test('Android: a microphone|mediaPlayback foreground service with its '
        'permissions', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      for (final permission in [
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MICROPHONE',
        'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.WAKE_LOCK',
        'android.permission.RECORD_AUDIO',
      ]) {
        expect(
          manifest,
          contains('<uses-permission android:name="$permission"/>'),
          reason: permission,
        );
      }
      final service = RegExp(
        r'<service[^>]*flutter_foreground_task\.service\.ForegroundService[^>]*>',
      ).firstMatch(manifest)?.group(0);
      expect(service, isNotNull);
      expect(
        service,
        contains('android:foregroundServiceType="microphone|mediaPlayback"'),
      );
      // The camera cannot run in the background: no camera type.
      expect(service, isNot(contains('camera')));
    });

    test('iOS: background audio (not voip)', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final modes = RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)?.group(1);
      expect(modes, isNotNull);
      expect(modes, contains('<string>audio</string>'));
      expect(modes, isNot(contains('voip')));
      expect(plist, contains('NSMicrophoneUsageDescription'));
    });
  });
}
