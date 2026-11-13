// D221 (owner's design «اقتراح عند انقطاع البث وانتهائه»): the shared
// interruption card restyled — glass card, glowing ring with sound waves,
// the reason badge, the red status pill, the gold host name (a crown only
// when the app knows a status for it), the title, one line and full-width
// buttons with 48 dp targets. Checked in Arabic RTL and English LTR at
// 393×852 and 360×800 with text scale 1.3: no overflow, a long host name, no
// avatar (silhouette), crown shown / hidden, symmetric layout, reduced
// motion. Behaviour (the actions and when each state shows) is unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

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

const _crown = Key('live.interruption.crown');
const _status = Key('live.interruption.status');
const _badge = Key('live.interruption.badge');
const _silhouette = Key('live.interruption.silhouette');

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    final l10n = lookupAppLocalizations(language.locale);
    for (final viewport in GoldenViewport.values) {
      final tag = '${language.name}, ${viewport.name}';

      group('D221 card ($tag, text ×1.3)', () {
        testWidgets('ended, no avatar, a long name: silhouette, status pill, '
            'gold name without a crown, title, reason, follow + back; '
            'no overflow', (tester) async {
          setViewport(tester, viewport);
          var back = 0;
          var follow = 0;
          final longName = ar
              ? 'سارة عبد الرحمن الهاشمية من مدينة الإسكندرية الجميلة جدا'
              : 'Sara Abdulrahman Al-Hashimi from the beautiful city of '
                    'Alexandria';
          await pumpScreen(
            tester,
            _scaled(
              KRoomEndedOverlay(
                hostName: longName,
                reason: l10n.liveRoomEndedTimeout,
                reasonIcon: endReasonIcon(LiveRoomEndReason.heartbeatTimeout),
                onBack: () => back++,
                followAction: KLiveInterruptionButton(
                  key: const Key('room.follow'),
                  label: l10n.liveFollow,
                  icon: Icons.add_box_outlined,
                  onPressed: () => follow++,
                ),
              ),
            ),
            language: language,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(_silhouette), findsOneWidget);
          expect(find.byKey(_crown), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(_status),
              matching: find.text(l10n.liveStatusEnded),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.liveRoomEndedTitle), findsOneWidget);
          expect(find.text(l10n.liveRoomEndedTimeout), findsOneWidget);
          expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
          // The name stays on one line, in gold.
          final name = tester.widget<Text>(find.text(longName));
          expect(name.maxLines, 1);
          expect(name.overflow, TextOverflow.ellipsis);
          expect(name.style?.color, KBrandColors.gold);
          // Two full-width buttons, 48 dp targets, the card's real actions.
          final card = tester.getRect(find.byType(KLiveInterruption));
          for (final key in const [Key('room.follow'), Key('room.back')]) {
            final r = tester.getRect(find.byKey(key));
            expect(r.height, KLiveInterruptionButton.target);
            expect(r.width, closeTo(card.width - 56, 0.5));
          }
          expect(find.text(l10n.liveRoomBackToLive), findsOneWidget);
          expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
          await tester.tap(find.byKey(const Key('room.follow')));
          await tester.tap(find.byKey(const Key('room.back')));
          expect((follow, back), (1, 1));
          // Symmetric: the ring, the badge and the pill sit on the card's
          // centre line in both directions.
          final centre = card.center.dx;
          expect(tester.getCenter(find.byKey(_badge)).dx, closeTo(centre, 0.5));
          expect(
            tester.getCenter(find.byKey(_status)).dx,
            closeTo(centre, 0.5),
          );
          expect(card.width, lessThanOrEqualTo(KLiveInterruption.maxWidth));
          expect(tester.takeException(), isNull);
        });

        testWidgets('crowned: the crown sits before the gold name; the photo '
            'replaces the silhouette', (tester) async {
          setViewport(tester, viewport);
          await pumpScreen(
            tester,
            _scaled(
              KRoomEndedOverlay(
                hostName: ar ? 'سارة' : 'Sara',
                avatar: avatarImage,
                crowned: true,
                reason: l10n.liveRoomEndedByHost,
                onBack: () {},
              ),
            ),
            language: language,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(_crown), findsOneWidget);
          expect(find.byKey(_silhouette), findsNothing);
          final crown = tester.getCenter(find.byKey(_crown)).dx;
          final name = tester.getCenter(find.text(ar ? 'سارة' : 'Sara')).dx;
          // Before = the reading start: right of the name in Arabic.
          expect(crown > name, ar);
          // Without a follow action, Back is the red primary button.
          final back = tester.widget<KLiveInterruptionButton>(
            find.byKey(const Key('room.back')),
          );
          expect(back.primary, isTrue);
          expect(tester.takeException(), isNull);
        });

        testWidgets('every state says its status in the pill', (tester) async {
          setViewport(tester, viewport);
          Future<void> expectPill(Widget screen, String status) async {
            await pumpScreen(tester, _scaled(screen), language: language);
            await tester.pump();
            expect(
              find.descendant(
                of: find.byKey(_status),
                matching: find.text(status),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }

          await expectPill(
            KRoomMessage(
              icon: Icons.wifi_off_rounded,
              status: l10n.liveStatusOffline,
              title: l10n.feedOfflineTitle,
              message: l10n.feedOfflineBody,
              onClose: () {},
              onRetry: () {},
            ),
            l10n.liveStatusOffline,
          );
          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          await expectPill(
            KRoomReconnecting(frame: fakeVideoFrame()),
            l10n.liveStatusConnectionLost,
          );
          await expectPill(
            LiveRoomScreen.kickedMessage(l10n, () {}),
            l10n.liveStatusRemoved,
          );
          await expectPill(
            const KRoomVideoUnavailable(),
            l10n.liveStatusUnavailable,
          );
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('waiting: the waves and the arc move with motion on; '
            'everything is still with reduced motion', (tester) async {
          setViewport(tester, viewport);
          KLiveInterruption.animate = true;
          addTearDown(() => KLiveInterruption.animate = false);
          Widget away({required bool still}) => _scaled(
            KLiveInterruption(
              leading: const KLiveHostPicture(size: KLiveInterruption.picture),
              badgeIcon: Icons.hourglass_top_rounded,
              busy: true,
              status: l10n.liveStatusHostAway,
              eyebrow: ar ? 'سارة' : 'Sara',
              title: l10n.liveHostAway,
              message: l10n.liveHostAwayBody,
            ),
            still: still,
          );
          await pumpScreen(tester, away(still: true), language: language);
          await tester.pump();
          expect(tester.hasRunningAnimations, isFalse);
          await pumpScreen(tester, away(still: false), language: language);
          await tester.pump();
          expect(tester.hasRunningAnimations, isTrue);
          // Not busy (ended): still even with motion on.
          await tester.pumpWidget(const SizedBox());
          await pumpScreen(
            tester,
            _scaled(
              KRoomEndedOverlay(
                hostName: 'x',
                reason: l10n.liveRoomEndedOther,
                onBack: () {},
              ),
            ),
            language: language,
          );
          await tester.pump();
          expect(tester.hasRunningAnimations, isFalse);
          await tester.pumpWidget(const SizedBox());
        });
      });
    }
  }
}
