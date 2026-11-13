// D216 (owner): the interrupted-live states share one card in Kabso's
// identity (KLiveInterruption); the quips' Kabi art. (D224 replaced D216's
// quip banner with the gift strip: live_polish2_d224_test.) Checked
// in Arabic RTL and English LTR at 393×852 and 360×800 with text scale 1.3:
// no overflow; motion stops with reduced motion; the room's behaviour (when
// each state shows, the quip queue and the mute) is unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

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
      'quips/gulf',
      'quips/jordan',
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
