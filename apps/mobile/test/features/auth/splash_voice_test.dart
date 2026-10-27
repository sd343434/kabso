import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Records what the splash voice asks of the audio plugin.
class _FakePlayer extends Fake implements AudioPlayer {
  new({this.fail = false});

  final bool fail;
  final complete = StreamController<void>.broadcast();
  final played = <({Source source, PlayerMode? mode, AudioContext? ctx})>[];
  ReleaseMode? setMode;
  bool disposed = false;

  @override
  Stream<void> get onPlayerComplete => complete.stream;

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async =>
      setMode = releaseMode;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (fail) throw StateError('no audio');
    played.add((source: source, mode: mode, ctx: ctx));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _Players {
  final created = <_FakePlayer>[];
  bool fail = false;

  AudioPlayer create() {
    final player = _FakePlayer(fail: fail);
    created.add(player);
    return player;
  }
}

void main() {
  test('the voice asset is bundled', () {
    expect(File('assets/${AudioplayersSplashVoice.asset}').existsSync(), true);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('    - assets/splash/\n'));
  });

  test(
    'plays the voice on the media stream, mixed, through MediaPlayer',
    () async {
      final players = _Players();
      final voice = AudioplayersSplashVoice(createPlayer: players.create);

      await voice.play();

      final player = players.created.single;
      final call = player.played.single;
      expect((call.source as AssetSource).path, 'splash/kabso_voice.mp3');
      expect(call.mode, PlayerMode.mediaPlayer);
      final android = call.ctx!.android;
      // Not sonification: many phones keep that stream muted.
      expect(android.usageType, AndroidUsageType.media);
      expect(android.contentType, AndroidContentType.music);
      expect(android.audioFocus, AndroidAudioFocus.none);
      expect(call.ctx!.iOS.category, AVAudioSessionCategory.ambient);
      expect(player.setMode, ReleaseMode.release);
    },
  );

  test(
    'keeps the player until the voice completes, then releases it',
    () async {
      final players = _Players();
      final voice = AudioplayersSplashVoice(createPlayer: players.create);

      await voice.play();
      final player = players.created.single;
      await pumpEventQueue();
      expect(player.disposed, false);

      player.complete.add(null);
      await pumpEventQueue();
      expect(player.disposed, true);
    },
  );

  test('plays once per app process', () async {
    final players = _Players();
    final voice = AudioplayersSplashVoice(createPlayer: players.create);

    await voice.play();
    await voice.play();

    expect(players.created, hasLength(1));
  });

  test('a player that cannot play is released and never throws', () async {
    final players = _Players()..fail = true;
    final voice = AudioplayersSplashVoice(createPlayer: players.create);

    await voice.play();

    expect(players.created.single.disposed, true);
  });

  test('the provider survives a read with no listener (the splash only reads '
      'it)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final voice = container.read(splashVoiceProvider);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.exists(splashVoiceProvider), true);
    expect(container.read(splashVoiceProvider), same(voice));
  });

  testWidgets('cold start: the splash plays the voice, which outlives the '
      'splash screen', (tester) async {
    final players = _Players();
    await pumpKabsoApp(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        splashVoiceProvider.overrideWith((ref) {
          final voice = AudioplayersSplashVoice(createPlayer: players.create);
          ref.onDispose(() => unawaited(voice.dispose()));
          return voice;
        }),
      ],
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    final player = players.created.single;
    expect(
      (player.played.single.source as AssetSource).path,
      AudioplayersSplashVoice.asset,
    );

    await tester.pump(KSplash.total);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(player.disposed, false, reason: 'the voice is not cut off');

    player.complete.add(null);
    await tester.pump();
    expect(player.disposed, true);
    expect(players.created, hasLength(1));
  });
}
