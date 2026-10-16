// KL-034 live room goldens, ar and en at 393×852 (iPhone-class insets
// 59 / 34) and 360×800 (no insets), @3x, always dark.
//
// Production states run the real `LiveRoomScreen` against fake
// repositories shaped like contract v1.3.1 (what the app shows today):
//   room.video_unavailable, room.ended, room.loading, room.error.
// Fixture-only layouts and states (D35: no API exists for them, so they are
// built from test fixtures and never reachable in production):
//   room.populated (fixture chat), room.gifts, room.pk.split,
//   room.multi_guest, room.state.{weak,reconnecting,camera_off}.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_room_golden_test.dart
@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/guest_seats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_layout.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/live/live_fixtures.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final l10n = lookupAppLocalizations(language.locale);
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        final vp = viewport.name;

        Future<void> golden(
          WidgetTester tester,
          String name,
          Widget child, {
          List<Override> overrides = const [],
        }) async {
          if (viewport == GoldenViewport.phone) {
            tester.view.padding = const FakeViewPadding(
              top: 59 * GoldenViewport.pixelRatio,
              bottom: 34 * GoldenViewport.pixelRatio,
            );
            addTearDown(tester.view.resetPadding);
          }
          await pumpGolden(
            tester,
            ProviderScope(
              retry: (_, _) => null,
              overrides: overrides,
              child: child,
            ),
            language: language,
            viewport: viewport,
            bare: true,
          );
          // Fixture frames are DecorationImages, which `pumpGolden` does not
          // precache: decode them outside fake async, then repaint.
          await tester.runAsync(() async {
            final context = tester.element(find.byType(ProviderScope));
            for (final image in [coverBlue, coverRed, coverGold, avatarImage]) {
              await precacheImage(image, context, onError: (_, _) {});
            }
          });
          await tester.pumpAndSettle();
          await expectScreenGolden(
            name,
            language: language,
            viewport: viewport,
          );
        }

        List<Override> api(RoomHandler? room) => [
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(room: room),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile(ar: ar)),
          ),
        ];

        // ---- Production states (real screen, contract-shaped data) ----

        testWidgets('room.video_unavailable ($vp)', (tester) async {
          await golden(
            tester,
            'room.video_unavailable',
            const LiveRoomScreen(roomId: 'room-0'),
            overrides: api(
              (id) => apiRoom(
                id: id,
                ar: ar,
                category: LiveCategory(
                  slug: 'music',
                  name: ar ? 'موسيقى' : 'Music',
                ),
              ),
            ),
          );
        });

        testWidgets('room.ended ($vp)', (tester) async {
          await golden(
            tester,
            'room.ended',
            const LiveRoomScreen(roomId: 'room-0'),
            overrides: api(
              (id) => apiRoom(
                id: id,
                ar: ar,
                status: LiveRoomStatus.ended,
                endReason: LiveRoomEndReason.heartbeatTimeout,
              ),
            ),
          );
        });

        testWidgets('room.loading ($vp)', (tester) async {
          final never = Completer<LiveRoom>();
          await golden(
            tester,
            'room.loading',
            const LiveRoomScreen(roomId: 'room-0'),
            overrides: api((_) => never.future),
          );
        });

        testWidgets('room.error ($vp)', (tester) async {
          await golden(
            tester,
            'room.error',
            const LiveRoomScreen(roomId: 'room-0'),
            overrides: api(
              (_) => throw const ServerFailure(
                code: ErrorCode.internalError,
                rawCode: 'INTERNAL_ERROR',
                debugMessage: 'x',
                statusCode: 500,
                requestId: 'req-7f3a',
              ),
            ),
          );
        });

        // ---- Fixture-only layouts and states (D35) ----

        testWidgets('room.populated ($vp)', (tester) async {
          await golden(tester, 'room.populated', _room(language, l10n));
        });

        testWidgets('room.gifts ($vp)', (tester) async {
          await golden(
            tester,
            'room.gifts',
            _room(
              language,
              l10n,
              overlay: Align(
                alignment: Alignment.bottomCenter,
                child: KGiftPanel(
                  gifts: gifts(language),
                  selectedId: 'star',
                  comboCount: 3,
                  onSelected: (_) {},
                ),
              ),
            ),
          );
        });

        testWidgets('room.pk.split ($vp)', (tester) async {
          final (host, opponent) = pkSides(language);
          await golden(
            tester,
            'room.pk.split',
            _room(
              language,
              l10n,
              video: const KLiveVideoPlaceholder(child: SizedBox.shrink()),
              stage: KPkLayout(
                host: host,
                opponent: opponent,
                timeLeft: const Duration(seconds: 9),
              ),
              lastLines: 4,
            ),
          );
        });

        testWidgets('room.multi_guest ($vp)', (tester) async {
          await golden(
            tester,
            'room.multi_guest',
            _room(
              language,
              l10n,
              video: const KLiveVideoPlaceholder(child: SizedBox.shrink()),
              stage: KGuestSeatGrid(seats: guestSeats(language)),
              lastLines: 4,
            ),
          );
        });

        testWidgets('room.state.weak ($vp)', (tester) async {
          await golden(
            tester,
            'room.state.weak',
            _room(
              language,
              l10n,
              statusChip: KRoomStatusChip(label: l10n.liveRoomWeakConnection),
            ),
          );
        });

        testWidgets('room.state.reconnecting ($vp)', (tester) async {
          await golden(
            tester,
            'room.state.reconnecting',
            _room(
              language,
              l10n,
              video: KRoomReconnecting(frame: fakeVideoFrame()),
            ),
          );
        });

        testWidgets('room.state.camera_off ($vp)', (tester) async {
          await golden(
            tester,
            'room.state.camera_off',
            _room(
              language,
              l10n,
              video: KRoomCameraOff(
                hostName: ar ? 'سارة' : 'Sara',
                avatar: avatarImage,
              ),
            ),
          );
        });
      }
    });
  });
}

/// The populated room with fixture data: video frame, host pill with a
/// follower line and Follow, viewer count, room info, fixture chat and the
/// full action bar.
Widget _room(
  AppLanguage language,
  AppLocalizations l10n, {
  Widget? video,
  Widget? stage,
  Widget? statusChip,
  Widget? overlay,
  int? lastLines,
}) {
  final ar = language == AppLanguage.ar;
  final all = chatLines(language);
  final lines = lastLines == null ? all : all.sublist(all.length - lastLines);
  return KLiveRoomScaffold(
    video: video ?? fakeVideoFrame(),
    header: KHostPill(
      hostName: ar ? 'سارة' : 'Sara',
      avatar: avatarImage,
      subtitle: l10n.liveRoomFollowers(12345, ar ? '12.3 ألف' : '12.3K'),
      onFollow: () {},
      onTap: () {},
    ),
    viewers: const KViewerStrip(names: viewerNames, count: 12345),
    onClose: () {},
    roomInfo: KRoomInfoRow(
      title: ar ? 'سهرة موسيقى عربية' : 'Arabic music night',
      category: ar ? 'موسيقى' : 'Music',
    ),
    statusChip: statusChip,
    stage: stage,
    chat: KLiveChatOverlay(lines: lines),
    actionBar: KRoomActionBar(onComment: () {}, onShare: () {}, onGift: () {}),
    overlay: overlay,
  );
}
