// D232 (owner's device test of staging): the live's small cards in one
// style (the leave prompt's, with a brand-red button and a red wash), and
// the music that never played a file picked on the phone.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/tools/music/live_music_controller.dart';
import 'package:kabso_live/features/live/tools/music/live_music_mixer.dart';
import 'package:kabso_live/features/live/tools/music/live_music_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';

/// The picker's answers on Android (the plugin copies each `content://`
/// document into the app's storage under a safe ASCII name and returns its
/// display name as picked).
const _picked = [
  LiveMusicFile(
    path: '/data/user/0/com.kabso.kabso_live/files/kabso_music/1_audio.mp3',
    name: '(تمثيل صوتى مسرحى - كأنها بترحب بالجو).mp3',
  ),
  LiveMusicFile(
    path: '/data/user/0/com.kabso.kabso_live/files/kabso_music/2_audio.m4a',
    name: '(تمثيل صوتى مسرحى - كأنها بترحب بالجو)',
  ),
  LiveMusicFile(
    path: '/data/user/0/com.kabso.kabso_live/files/kabso_music/3_My_Song_1.aac',
    name: 'My Song (1).aac',
  ),
  LiveMusicFile(
    path: '/data/user/0/com.kabso.kabso_live/files/kabso_music/4_a_b.wav',
    name: 'a b.wav',
  ),
  LiveMusicFile(
    path: '/data/user/0/com.kabso.kabso_live/files/kabso_music/5_voice.ogg',
    name: 'voice.ogg',
  ),
];

class _Mixer implements LiveMusicMixer {
  final List<String> calls = [];
  final _events = StreamController<LiveMusicEvent>.broadcast();

  /// What the next loads throw (null: they succeed).
  LiveMusicLoadException? loadError;

  /// An error the decoder thread reports while `play` runs.
  LiveMusicError? failOnPlay;

  @override
  LiveMusicUnsupported? get unsupported => null;

  @override
  Future<List<LiveMusicFile>> pickFiles() async {
    calls.add('pick');
    return _picked;
  }

  @override
  Future<Duration?> load(LiveMusicFile file) async {
    calls.add('load:${file.path}');
    if (loadError case final e?) throw e;
    return null;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (failOnPlay case final e?) {
      _events.add(LiveMusicFailed(e));
      // The event is delivered before `play` answers.
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setDucking({required bool on}) async {}

  @override
  Stream<LiveMusicEvent> get events => _events.stream;
}

ProviderContainer _container(_Mixer mixer) {
  final c = ProviderContainer(
    overrides: [liveMusicMixerProvider.overrideWithValue(mixer)],
  );
  addTearDown(c.dispose);
  c.listen(liveMusicProvider, (_, _) {});
  return c;
}

/// WCAG relative contrast.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  group('D232 music: files picked on the phone', () {
    test(
      'every picker shape (Arabic, spaces, brackets, no extension; mp3 '
      'm4a aac wav ogg) is queued by its name and loaded by its path',
      () async {
        final mixer = _Mixer();
        final c = _container(mixer);
        final music = c.read(liveMusicProvider.notifier);
        expect(await music.addFiles(), 0);
        expect(c.read(liveMusicProvider).queue.map((f) => f.name), [
          for (final f in _picked) f.name,
        ]);
        for (var i = 0; i < _picked.length; i++) {
          await music.playAt(i);
          expect(mixer.calls, contains('load:${_picked[i].path}'));
          expect(c.read(liveMusicProvider).playing, isTrue);
          expect(c.read(liveMusicProvider).error, isNull);
        }
      },
    );

    test(
      'the cause on the device: no live microphone module for the mixer '
      '(native `not_ready`) is its own error, not "cannot play this file"',
      () async {
        final mixer = _Mixer()
          ..loadError = const LiveMusicLoadException(LiveMusicError.notReady);
        final c = _container(mixer);
        final music = c.read(liveMusicProvider.notifier);
        await music.addFiles();
        await music.playAt(0);
        expect(c.read(liveMusicProvider).error, LiveMusicError.notReady);
        expect(c.read(liveMusicProvider).playing, isFalse);
        expect(mixer.calls, isNot(contains('play')));
      },
    );

    test('a decode error reported while starting wins: not shown as '
        'playing (was: the pause icon beside the error)', () async {
      final mixer = _Mixer()..failOnPlay = LiveMusicError.unsupported;
      final c = _container(mixer);
      final music = c.read(liveMusicProvider.notifier);
      await music.addFiles();
      await music.playAt(0);
      expect(c.read(liveMusicProvider).error, LiveMusicError.unsupported);
      expect(c.read(liveMusicProvider).playing, isFalse);
    });

    test('play after a failure loads the file again (was a bare `play` on '
        'a dead decoder, shown as playing)', () async {
      final mixer = _Mixer()
        ..loadError = const LiveMusicLoadException(LiveMusicError.notReady);
      final c = _container(mixer);
      final music = c.read(liveMusicProvider.notifier);
      await music.addFiles();
      await music.playAt(0);
      mixer
        ..loadError = null
        ..calls.clear();
      await music.toggle();
      expect(mixer.calls.first, 'load:${_picked.first.path}');
      expect(c.read(liveMusicProvider).playing, isTrue);
      expect(c.read(liveMusicProvider).error, isNull);
    });

    group('the channel', () {
      const channel = MethodChannel('com.kabso/live_music');
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      tearDown(() => messenger.setMockMethodCallHandler(channel, null));

      for (final (code, error) in [
        ('not_ready', LiveMusicError.notReady),
        ('unsupported', LiveMusicError.unsupported),
        ('unreadable', LiveMusicError.unreadable),
      ]) {
        test('load answering `$code` → $error', () async {
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'load') {
              throw PlatformException(code: code);
            }
            return null;
          });
          final mixer = ChannelLiveMusicMixer();
          await expectLater(
            mixer.load(_picked.first),
            throwsA(
              isA<LiveMusicLoadException>().having(
                (e) => e.error,
                'error',
                error,
              ),
            ),
          );
        });
      }

      test('the decoder error event carries its reason', () async {
        final mixer = ChannelLiveMusicMixer();
        final got = <LiveMusicEvent>[];
        final sub = mixer.events.listen(got.add);
        for (final reason in ['unsupported', 'unreadable', null]) {
          await messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('error', reason == null ? null : {'reason': reason}),
            ),
            (_) {},
          );
        }
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(
          [for (final e in got) (e as LiveMusicFailed).error],
          [
            LiveMusicError.unsupported,
            LiveMusicError.unreadable,
            LiveMusicError.unreadable,
          ],
        );
      });
    });

    forEachLanguage((language) {
      testWidgets('${language.name}: the sheet says the precise reason', (
        tester,
      ) async {
        final mixer = _Mixer()
          ..loadError = const LiveMusicLoadException(LiveMusicError.notReady);
        await pumpGolden(
          tester,
          ProviderScope(
            overrides: [liveMusicMixerProvider.overrideWithValue(mixer)],
            child: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    key: const Key('t.play'),
                    onPressed: () async {
                      final m = ref.read(liveMusicProvider.notifier);
                      await m.addFiles();
                      await m.playAt(0);
                    },
                    child: const Text('go'),
                  ),
                  const Expanded(
                    child: SingleChildScrollView(
                      child: LiveMusicSheet(micEnabled: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          language: language,
          brightness: Brightness.light,
        );
        await tester.tap(find.byKey(const Key('t.play')));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(LiveMusicSheet)),
        );
        expect(find.byKey(LiveMusicSheet.errorKey), findsOneWidget);
        expect(find.text(l10n.liveMusicNotReady), findsOneWidget);
        expect(find.text(l10n.liveMusicUnreadable), findsNothing);
        // Not "playing": the play icon, not pause.
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('D232 the live card style (ref 325: red button, red wash)', () {
    for (final language in const [AppLanguage.ar, AppLanguage.en]) {
      for (final viewport in GoldenViewport.values) {
        for (final brightness in Brightness.values) {
          final big = viewport == GoldenViewport.android;
          testWidgets('${language.name} ${viewport.name}${big ? ' ×1.3' : ''} '
              '${brightness.name}: «تابِع واخرج» is the theme primary with '
              'onPrimary text ≥ 4.5:1; the outline exit; a red (not cyan) '
              'wash', (tester) async {
            if (big) {
              tester.platformDispatcher.textScaleFactorTestValue = 1.3;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
            }
            LiveLeaveChoice? choice;
            await pumpGolden(
              tester,
              Builder(
                builder: (context) => TextButton(
                  key: const Key('t.leave'),
                  onPressed: () async => choice = await showLiveLeavePrompt(
                    context,
                    hostName: 'Nabulsi',
                    avatar: null,
                  ),
                  child: const Text('leave'),
                ),
              ),
              language: language,
              viewport: viewport,
              brightness: brightness,
            );
            await tester.tap(find.byKey(const Key('t.leave')));
            await tester.pumpAndSettle();
            final card = find.byKey(KLeavePrompt.cardKey);
            expect(card, findsOneWidget);
            final palette = tester.element(card).palette;
            final follow = tester.widget<Container>(
              find
                  .descendant(
                    of: find.byKey(KLeavePrompt.followKey),
                    matching: find.byType(Container),
                  )
                  .first,
            );
            final fill = (follow.decoration! as BoxDecoration).color!;
            expect(fill, palette.primary);
            final label = tester.widget<Text>(
              find.descendant(
                of: find.byKey(KLeavePrompt.followKey),
                matching: find.byType(Text),
              ),
            );
            expect(label.style!.color, palette.onPrimary);
            expect(
              _contrast(palette.onPrimary, palette.primary),
              greaterThanOrEqualTo(4.5),
            );
            // The exit: outlined, not filled with the brand.
            final exit = tester.widget<Container>(
              find
                  .descendant(
                    of: find.byKey(KLeavePrompt.exitKey),
                    matching: find.byType(Container),
                  )
                  .first,
            );
            final exitBox = exit.decoration! as BoxDecoration;
            expect(exitBox.border, isNotNull);
            expect(exitBox.color, isNot(palette.primary));
            // The wash: red over the surface, never the old cyan.
            final wash =
                tester
                        .widgetList<Container>(
                          find.descendant(
                            of: card,
                            matching: find.byType(Container),
                          ),
                        )
                        .map((c) => c.decoration)
                        .whereType<BoxDecoration>()
                        .firstWhere((d) => d.gradient != null)
                        .gradient!
                    as LinearGradient;
            final top = wash.colors.first;
            expect(top, isNot(const Color(0xFFD4FDFF)));
            expect(top.r, greaterThan(top.g));
            expect(top.r, greaterThan(top.b));
            // The card fits the screen, side margins kept.
            final rect = tester.getRect(card);
            expect(rect.left, greaterThanOrEqualTo(18));
            expect(
              rect.right,
              lessThanOrEqualTo(viewport.logicalSize.width - 18),
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(KLeavePrompt.followKey));
            await tester.pumpAndSettle();
            expect(choice, LiveLeaveChoice.followAndExit);
          });
        }
      }
    }

    testWidgets('showKLiveConfirm: true on confirm, false on cancel and on a '
        'tap outside', (tester) async {
      final answers = <bool>[];
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => TextButton(
            key: const Key('t.ask'),
            onPressed: () async => answers.add(
              await showKLiveConfirm(
                context,
                title: 'End the live?',
                confirmLabel: 'End',
                cancelLabel: 'Keep going',
                confirmKey: const Key('t.yes'),
                cancelKey: const Key('t.no'),
              ),
            ),
            child: const Text('ask'),
          ),
        ),
        language: AppLanguage.en,
        brightness: Brightness.light,
      );
      for (final tap in [const Key('t.yes'), const Key('t.no'), null]) {
        await tester.tap(find.byKey(const Key('t.ask')));
        await tester.pumpAndSettle();
        expect(find.byType(KLiveDialogCard), findsOneWidget);
        if (tap == null) {
          await tester.tapAt(const Offset(20, 20));
        } else {
          await tester.tap(find.byKey(tap));
        }
        await tester.pumpAndSettle();
      }
      expect(answers, [true, false, false]);
    });
  });
}
