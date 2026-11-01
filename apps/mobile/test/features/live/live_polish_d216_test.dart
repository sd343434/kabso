// D216 (owner): the interrupted-live states share one card in Kabso's
// identity (KLiveInterruption), and a sent quip shows as a joyful banner
// (pop in, Kabi art, the sender, the words, a time line, lift away). Checked
// in Arabic RTL and English LTR at 393×852 and 360×800 with text scale 1.3:
// no overflow; motion stops with reduced motion; the room's behaviour (when
// each state shows, the quip queue and the mute) is unchanged.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _Audio implements QuipAudio {
  final played = <String>[];

  @override
  Future<void> play(String soundKey) async => played.add(soundKey);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// [child] at [scale] with motion on or off.
Widget _scaled(Widget child, {double scale = 1.3, bool still = false}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: still,
        ),
        child: child,
      ),
    );

LiveQuip _quip(String id, {String code = 'quip_ghazal_01'}) =>
    LiveQuip.fromJson(liveQuipJson(id: id, code: code));

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    for (final viewport in GoldenViewport.values) {
      final tag = '${language.name}, ${viewport.name}';

      group('interruption states ($tag, text ×1.3)', () {
        testWidgets('the ended card: the host, the reason badge, the title, '
            'the reason and the two real actions; no overflow', (tester) async {
          setViewport(tester, viewport);
          var back = 0;
          await pumpScreen(
            tester,
            _scaled(
              KRoomEndedOverlay(
                hostName: ar ? 'سارة' : 'Sara',
                reason: ar
                    ? 'انتهى البث لأن المضيف غاب أكثر من 5 دقائق.'
                    : 'The live ended because the host was away for more '
                          'than 5 minutes.',
                reasonIcon: endReasonIcon(LiveRoomEndReason.hostAwayTimeout),
                onBack: () => back++,
                followAction: KButton(label: 'Follow', onPressed: () {}),
              ),
            ),
            language: language,
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(KRoomEndedOverlay)),
          );
          expect(find.byType(KLiveInterruption), findsOneWidget);
          expect(find.text(l10n.liveRoomEndedTitle), findsOneWidget);
          expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
          expect(
            Directionality.of(
              tester.element(find.text(l10n.liveRoomEndedTitle)),
            ),
            ar ? TextDirection.rtl : TextDirection.ltr,
          );
          await tester.tap(find.byKey(const Key('room.back')));
          expect(back, 1);
          expect(tester.takeException(), isNull);
        });

        testWidgets('reconnecting (fixture): the card with the arc; the arc '
            'turns only with motion on', (tester) async {
          setViewport(tester, viewport);
          KLiveInterruption.animate = true;
          addTearDown(() => KLiveInterruption.animate = false);
          await pumpScreen(
            tester,
            _scaled(
              const KRoomReconnecting(frame: ColoredBox(color: Colors.blue)),
              still: true,
            ),
            language: language,
          );
          await tester.pump();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(KRoomReconnecting)),
          );
          expect(find.text(l10n.liveRoomReconnecting), findsOneWidget);
          expect(find.text(l10n.liveRoomReconnectingBody), findsOneWidget);
          // Reduced motion: nothing moves.
          expect(tester.hasRunningAnimations, isFalse);
          expect(tester.takeException(), isNull);

          await pumpScreen(
            tester,
            _scaled(const KRoomReconnecting(frame: SizedBox.expand())),
            language: language,
          );
          await tester.pump();
          expect(tester.hasRunningAnimations, isTrue);
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('a room that cannot open (offline): the card with Retry '
            'and Back', (tester) async {
          setViewport(tester, viewport);
          var retry = 0;
          var close = 0;
          await pumpScreen(
            tester,
            _scaled(
              KRoomMessage(
                icon: Icons.wifi_off_rounded,
                title: ar ? 'أنت غير متصل بالإنترنت' : "You're offline",
                message: ar
                    ? 'تحقّق من اتصالك ثم أعد المحاولة.'
                    : 'Check your connection, then try again.',
                onClose: () => close++,
                onRetry: () => retry++,
              ),
            ),
            language: language,
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(KRoomMessage)),
          );
          expect(find.byType(KLiveInterruption), findsOneWidget);
          await tester.tap(find.text(l10n.actionRetry));
          await tester.tap(find.text(l10n.liveRoomBackToLive));
          expect((retry, close), (1, 1));
          expect(tester.takeException(), isNull);
        });

        testWidgets('host away in the room: the card with the host and the '
            'line under the title', (tester) async {
          setViewport(tester, viewport);
          final engine = FakeLiveMediaEngine();
          await pumpScreen(
            tester,
            _scaled(const LiveRoomScreen(roomId: 'room-0')),
            language: language,
            liveMediaEngine: engine,
            overrides: [
              liveRepositoryProvider.overrideWithValue(
                FakeLiveRepository(
                  room: (id) => apiRoom(id: id, ar: ar),
                ),
              ),
            ],
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(LiveRoomScreen)),
          );
          final away = find.byKey(const Key('room.hostAway'));
          expect(away, findsOneWidget);
          Finder inAway(Finder f) => find.descendant(of: away, matching: f);
          expect(inAway(find.byType(KLiveInterruption)), findsOneWidget);
          expect(inAway(find.text(l10n.liveHostAway)), findsOneWidget);
          expect(inAway(find.text(l10n.liveHostAwayBody)), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      });

      group('quip banner ($tag, text ×1.3)', () {
        Future<(ProviderContainer, _Audio)> pump(
          WidgetTester tester, {
          bool still = false,
        }) async {
          setViewport(tester, viewport);
          final audio = _Audio();
          await pumpScreen(
            tester,
            _scaled(
              const Scaffold(
                body: Stack(
                  children: [
                    Positioned(
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
              ),
              still: still,
            ),
            language: language,
            liveGiftRepository: FakeLiveGiftRepository(
              codes: [...giftFixtureCodes, ...quipFixtureCodes],
              ar: ar,
            ),
            overrides: [
              liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
              currentUserProvider.overrideWithValue(testUser()),
              quipAudioProvider.overrideWithValue(audio),
            ],
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(LiveQuipBubble)),
          )..listen(liveQuipsProvider('room-0'), (_, _) {});
          return (container, audio);
        }

        testWidgets('pops in with the Kabi art, the sender and the words, '
            'then lifts away; the next quip in the queue follows', (
          tester,
        ) async {
          final (container, audio) = await pump(tester);
          container.read(liveQuipsProvider('room-0').notifier)
            ..receive(_quip('a'))
            ..receive(_quip('b', code: 'quip_clap'));
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(LiveQuipBubble.bubbleKey), findsOneWidget);
          // The entrance is running.
          expect(tester.hasRunningAnimations, isTrue);
          final art = tester.widget<KabiEmoji>(find.byType(KabiEmoji));
          expect(art.emoji, KabsoEmoji.kabi('kiss'));
          expect(find.text('إيه الجمال ده! تحفة بجد!'), findsOneWidget);
          expect(find.textContaining('لينا'), findsOneWidget);
          await tester.pump(LiveQuipBubble.enter);
          expect(tester.takeException(), isNull);
          // a ends (4362 ms): b (the clap, Kiki's art) takes its place.
          await tester.pump(const Duration(milliseconds: 4362));
          await tester.pump(LiveQuipBubble.enter);
          expect(audio.played, ['kabi/ghazal_01', 'room/clap']);
          expect(
            tester.widget<KabiEmoji>(find.byType(KabiEmoji)).emoji,
            KabsoEmoji.byKey('kiki_clap'),
          );
          await tester.pump(const Duration(milliseconds: 2038));
          await tester.pumpAndSettle();
          expect(find.byKey(LiveQuipBubble.bubbleKey), findsNothing);
          expect(tester.takeException(), isNull);
        });

        testWidgets('reduced motion: it simply appears and goes', (
          tester,
        ) async {
          final (container, _) = await pump(tester, still: true);
          container
              .read(liveQuipsProvider('room-0').notifier)
              .receive(_quip('a'));
          await tester.pump(const Duration(milliseconds: 10));
          expect(find.byKey(LiveQuipBubble.bubbleKey), findsOneWidget);
          expect(tester.hasRunningAnimations, isFalse);
          await tester.pump(const Duration(milliseconds: 4362));
          await tester.pump();
          expect(find.byKey(LiveQuipBubble.bubbleKey), findsNothing);
        });

        testWidgets('the speaker still mutes quips on this phone', (
          tester,
        ) async {
          final (container, _) = await pump(tester);
          container
              .read(liveQuipsProvider('room-0').notifier)
              .receive(_quip('a'));
          await tester.pump(LiveQuipBubble.enter);
          await tester.tap(find.byKey(LiveQuipBubble.muteKey));
          await tester.pump();
          expect(container.read(quipsMutedProvider), isTrue);
          expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        });
      });
    }
  }

  test('every quip art key has Kabso art', () {
    for (final key in [
      'quips/clap',
      'quips/laugh',
      'quips/welcome',
      'quips/wow',
      'quips/tada',
      'quips/ya_salam',
      'quips/bell',
      'quips/sad',
      'quips/ghazal',
      'quips/funny',
      'quips/tease',
      'quips/unknown',
    ]) {
      expect(quipArt(key).asset, startsWith('assets/emojis/'), reason: key);
    }
  });

  test('every end reason has its badge', () {
    expect(
      {for (final r in LiveRoomEndReason.values) endReasonIcon(r)},
      containsAll([
        Icons.stop_rounded,
        Icons.wifi_off_rounded,
        Icons.hourglass_bottom_rounded,
        Icons.sensors_off_rounded,
      ]),
    );
  });
}
