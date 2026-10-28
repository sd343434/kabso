// D154 («إفيهات», CONVENTIONS §10.33): the quips tab of the gift panel
// (paid lines, the free sound, quantity 1, the free-quip refusal, the
// host's and moderators' soundboard), the room's quip player (one at a
// time after the server's delay; the Sound effects setting and the local
// mute; duplicates and blocked senders), the quip bubble, and the host's
// soundboard sheet — Arabic RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_soundboard_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

const _open = Key('test.openGifts');
const _openBoard = Key('test.openBoard');

/// Records what the player was asked to play.
class _FakeAudio implements QuipAudio {
  final played = <String>[];
  int stops = 0;

  @override
  Future<void> play(String soundKey) async => played.add(soundKey);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}

class _Room extends ConsumerWidget {
  const new({required this.soundboard});

  final bool soundboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              key: _open,
              onPressed: () => unawaited(
                KLiveGiftSheet.show(
                  context,
                  room: LiveGiftRoom(
                    roomId: 'room-0',
                    host: _host,
                    seated: (_) => const [],
                    soundboard: (_) => soundboard,
                  ),
                ),
              ),
              child: const SizedBox.square(dimension: 40),
            ),
            TextButton(
              key: _openBoard,
              onPressed: () =>
                  unawaited(showLiveSoundboard(context, roomId: 'room-0')),
              child: const SizedBox.square(dimension: 40),
            ),
          ],
        ),
        const Positioned(
          top: LiveQuipBubble.top,
          left: 16,
          right: 16,
          child: Align(
            alignment: Alignment.topCenter,
            child: LiveQuipBubble(roomId: 'room-0'),
          ),
        ),
      ],
    ),
  );
}

class _Harness {
  new(this.gifts, this.audio, this.container);

  final FakeLiveGiftRepository gifts;
  final _FakeAudio audio;
  final ProviderContainer container;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  bool soundboard = false,
  FakeLiveMediaEngine? engine,
}) async {
  setViewport(tester, GoldenViewport.android);
  final gifts = FakeLiveGiftRepository(
    codes: [...giftFixtureCodes, ...quipFixtureCodes],
    ar: language == AppLanguage.ar,
  )..categories = const ['POPULAR', 'EVENT', 'FUN', 'QUIPS'];
  final audio = _FakeAudio();
  await pumpScreen(
    tester,
    _Room(soundboard: soundboard),
    language: language,
    liveGiftRepository: gifts,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
      quipAudioProvider.overrideWithValue(audio),
    ],
  );
  // The room's player is alive for the whole test (the room attaches it).
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_Room)),
  )..listen(liveQuipsProvider('room-0'), (_, _) {});
  return _Harness(gifts, audio, container);
}

Future<void> _openQuips(WidgetTester tester) async {
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  // The tabs scroll sideways on a 360 pt phone.
  await tester.ensureVisible(find.byKey(KLiveGiftSheet.tabKey('QUIPS')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(KLiveGiftSheet.tabKey('QUIPS')));
  await tester.pumpAndSettle();
}

LiveQuip _quip(String id, {String code = 'quip_ghazal_01', int delay = 0}) =>
    LiveQuip.fromJson(liveQuipJson(id: id, code: code, delayMs: delay));

void main() {
  for (final language in AppLanguage.values) {
    group('quips tab (${language.name})', () {
      testWidgets('lists the quips with their words, «free» and the price; '
          'a paid quip is sent once, with coins, and is heard', (tester) async {
        final h = await _pump(tester, language: language);
        await _openQuips(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(KLiveGiftSheet)),
        );
        expect(find.text(l10n.liveGiftTabQuips), findsOneWidget);
        expect(find.byKey(KLiveGiftSheet.cellKey('quip_clap')), findsOneWidget);
        Finder inCell(String code, Finder f) => find.descendant(
          of: find.byKey(KLiveGiftSheet.cellKey(code)),
          matching: f,
        );
        expect(inCell('quip_clap', find.text(l10n.liveQuipFree)), findsOne);
        expect(
          inCell('quip_ghazal_01', find.text('إيه الجمال ده! تحفة بجد!')),
          findsOne,
        );
        expect(inCell('quip_ghazal_01', find.text('99')), findsOne);
        // The quantity is 1 for a quip.
        await tester.tap(find.byKey(KLiveGiftSheet.cellKey('quip_ghazal_01')));
        await tester.pumpAndSettle();
        expect(find.byKey(KLiveGiftSheet.quantityOptionKey(10)), findsNothing);
        await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
        await tester.pump();
        expect(h.gifts.sends.single.giftCode, 'quip_ghazal_01');
        expect(h.gifts.sends.single.quantity, 1);
        expect(h.gifts.sends.single.source, LiveGiftSource.coins);
        await tester.pump(const Duration(milliseconds: 50));
        // Heard at once and shown as a bubble with its words.
        expect(h.audio.played, ['kabi/ghazal_01']);
        expect(find.byKey(LiveQuipBubble.bubbleKey), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 4400));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveQuipBubble.bubbleKey), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('a quip waiting in the queue says when it starts', (
    tester,
  ) async {
    final h = await _pump(tester);
    h.gifts.nextQuipDelayMs = 7200;
    await _openQuips(tester);
    await tester.tap(find.byKey(KLiveGiftSheet.cellKey('quip_ghazal_01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Queued — starts in 8 s'), findsOneWidget);
    expect(h.audio.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 7200));
    expect(h.audio.played, ['kabi/ghazal_01']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('one free quip per live: a second one is refused with the '
      'reason, nothing heard', (tester) async {
    final h = await _pump(tester);
    await _openQuips(tester);
    await tester.tap(find.byKey(KLiveGiftSheet.cellKey('quip_clap')));
    await tester.pumpAndSettle();
    expect(find.text('One free quip for you in each live.'), findsOneWidget);
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.audio.played, ['room/clap']);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("You've used your free quip in this live."), findsWidgets);
    expect(h.audio.played, ['room/clap']);
    await tester.pumpAndSettle();
  });

  testWidgets('the host or a moderator plays free quips from the soundboard '
      '(no free-quip limit)', (tester) async {
    final h = await _pump(tester, soundboard: true);
    await _openQuips(tester);
    expect(find.text('∞ Free'), findsOne);
    await tester.tap(find.byKey(KLiveGiftSheet.cellKey('quip_clap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.gifts.sends, isEmpty);
    expect(h.gifts.sounds.single.soundCode, 'quip_clap');
    expect(h.audio.played, ['room/clap']);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the soundboard sheet lists the free sounds and plays one; the '
      'mute switch stops the sound on this phone', (tester) async {
    final h = await _pump(tester, language: AppLanguage.ar);
    // The catalogue loads with the panel.
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_openBoard));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveSoundboardSheet.soundKey('quip_clap')), findsOne);
    expect(
      find.byKey(LiveSoundboardSheet.soundKey('quip_ghazal_01')),
      findsNothing,
    );
    await tester.tap(find.byKey(LiveSoundboardSheet.soundKey('quip_clap')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.gifts.sounds.single.soundCode, 'quip_clap');
    expect(h.audio.played, ['room/clap']);
    await tester.tap(find.byKey(LiveSoundboardSheet.muteKey));
    await tester.pump();
    expect(h.container.read(quipsMutedProvider), isTrue);
    expect(h.audio.stops, 1);
    await tester.pump(const Duration(seconds: 3));
    // The bubble's way out ends.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(LiveSoundboardSheet.soundKey('quip_clap')));
    await tester.pump(const Duration(milliseconds: 50));
    // Muted: the bubble shows, nothing is heard.
    expect(h.audio.played, ['room/clap']);
    expect(find.byKey(LiveQuipBubble.bubbleKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('the room player', () {
    testWidgets("plays the room's quips after their delay, one at a time; "
        'a repeat is skipped', (tester) async {
      final engine = FakeLiveMediaEngine();
      final h = await _pump(tester, engine: engine);
      h.container.read(liveQuipsProvider('room-0').notifier).attach(engine);
      engine.chat
        ..add(LiveQuipReceived(_quip('a')))
        ..add(LiveQuipReceived(_quip('a')))
        ..add(LiveQuipReceived(_quip('b', code: 'quip_clap', delay: 1000)));
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.audio.played, ['kabi/ghazal_01']);
      // b's delay passed while a still plays: it waits for a to end.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(h.audio.played, ['kabi/ghazal_01']);
      expect(h.container.read(liveQuipsProvider('room-0'))?.id, 'a');
      await tester.pump(const Duration(milliseconds: 3000));
      expect(h.audio.played, ['kabi/ghazal_01', 'room/clap']);
      expect(h.container.read(liveQuipsProvider('room-0'))?.id, 'b');
      await tester.pump(const Duration(seconds: 3));
      expect(h.container.read(liveQuipsProvider('room-0')), isNull);
    });

    testWidgets('Sound effects off in Settings: the bubble shows, no sound', (
      tester,
    ) async {
      final h = await _pump(tester);
      await h.container.read(soundEffectsProvider.notifier).set(on: false);
      h.container
          .read(liveQuipsProvider('room-0').notifier)
          .receive(_quip('a'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.audio.played, isEmpty);
      expect(find.byKey(LiveQuipBubble.bubbleKey), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets("the bubble's speaker mutes quips on this phone", (
      tester,
    ) async {
      final h = await _pump(tester, language: AppLanguage.ar);
      h.container
          .read(liveQuipsProvider('room-0').notifier)
          .receive(_quip('a'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('😍 إيه الجمال ده! تحفة بجد!'), findsOneWidget);
      await tester.tap(find.byKey(LiveQuipBubble.muteKey));
      await tester.pump();
      expect(h.container.read(quipsMutedProvider), isTrue);
      expect(h.audio.stops, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
