// D231 (owner on a phone, staging build, PK running: «شريط الـpk صغير
// والأرقام غير واضحة … لا تظهر صورة المضيفين كل شخص على جزئه من الأسفل مع
// زر + للإضافة … عند الضغط على الخصم لا تظهر البطاقة التعريفية … خط الـpk
// مرتفع عن الشاشتين»): the PK stage's bar is taller with big outlined
// figures the emblem and Kabi never cover, it sits right on the two videos,
// each host is at the bottom of their half with the opponent's «+», and a
// tap on a half opens that host's card — the other host's for their room,
// without a gift button. Pure stage at 393×852 and 360×800 with text ×1.3,
// ar and en; then the real viewer and host screens.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

typedef _Tap = ({UserSummary host, bool opponent});

Future<List<_Tap>> _stage(
  WidgetTester tester,
  PkMatch match, {
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  VoidCallback? onFollow,
}) async {
  // The bundled faces: the figures are measured as on a phone.
  await loadAppFonts();
  setViewport(tester, viewport);
  final taps = <_Tap>[];
  final size = viewport == GoldenViewport.phone
      ? const Size(393, 852)
      : const Size(360, 800);
  await pumpScreen(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SingleChildScrollView(
          child: LivePkStage(
            match: match,
            roomId: 'room-0',
            ownVideo: null,
            opponentVideo: null,
            now: DateTime.now,
            onFollowOpponent: onFollow,
            onHost: (host, {required opponent}) =>
                taps.add((host: host, opponent: opponent)),
          ),
        ),
      ),
    ),
    language: language,
  );
  await tester.pump();
  return taps;
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// The rendered size of a [Text] (font size × the text scale it uses).
double _fontPx(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key));
  final size = text.style!.fontSize!;
  final scaler =
      text.textScaler ??
      MediaQuery.textScalerOf(tester.element(find.byKey(key)));
  return scaler.scale(size);
}

void main() {
  test('bar figures: short Latin, tenths cut, no bidi marks', () {
    expect(pkBarScore(0), '0');
    expect(pkBarScore(999), '999');
    expect(pkBarScore(12500), '12.5K');
    expect(pkBarScore(834390), '834.3K');
    expect(pkBarScore(1250000), '1.2M');
    expect(pkBarScore(834390).contains(RegExp('[\u2066-\u2069]')), isFalse);
  });

  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    final ar = language == AppLanguage.ar;
    for (final (viewport, scale) in [
      (GoldenViewport.phone, 1.0),
      (GoldenViewport.android, 1.3),
    ]) {
      final tag = '${language.name} ${viewport.name} ×$scale';
      group(tag, () {
        testWidgets('the bar: 30 lp track, big figures, readable timer', (
          tester,
        ) async {
          await _stage(
            tester,
            pkMatchFixture(now: DateTime.now(), ar: ar, otherScore: 834390),
            language: language,
            viewport: viewport,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          final bar = _rect(tester, LivePkStage.barKey);
          expect(bar.height, PkBarMetrics.height);
          expect(PkBarMetrics.track, inInclusiveRange(28, 32));
          // Own side on the reading start: right in Arabic.
          final ownKey = ar
              ? PkBattleBar.rightScoreKey
              : PkBattleBar.leftScoreKey;
          final otherKey = ar
              ? PkBattleBar.leftScoreKey
              : PkBattleBar.rightScoreKey;
          expect(tester.widget<Text>(find.byKey(ownKey)).data, '12.5K');
          expect(tester.widget<Text>(find.byKey(otherKey)).data, '834.3K');
          for (final key in [ownKey, otherKey]) {
            expect(_fontPx(tester, key), greaterThanOrEqualTo(18));
            final r = _rect(tester, key);
            // Inside the track, fully on screen.
            expect(r.top, greaterThanOrEqualTo(bar.bottom - 30 - 0.5));
            expect(r.bottom, lessThanOrEqualTo(bar.bottom + 0.5));
            expect(r.left, greaterThanOrEqualTo(bar.left));
            expect(r.right, lessThanOrEqualTo(bar.right));
            final style = tester.widget<Text>(find.byKey(key)).style!;
            expect(style.color, const Color(0xFFFFFFFF));
            expect(style.fontWeight, FontWeight.w800);
            expect(style.shadows, isNotEmpty, reason: 'outlined');
          }
          // The timer: 15 sp+, centred where the halves meet, hanging
          // from the bar.
          final timer = _rect(tester, LivePkStage.timerKey);
          expect(timer.center.dx, closeTo(bar.center.dx, 1));
          expect(timer.top, closeTo(bar.bottom, 0.5));
          final timerText = find.descendant(
            of: find.byKey(LivePkStage.timerKey),
            matching: find.byType(Text),
          );
          final t = tester.widget<Text>(timerText);
          expect(
            t.textScaler!.scale(t.style!.fontSize!),
            greaterThanOrEqualTo(15),
          );
        });

        testWidgets('the emblem and Kabi never cover the figures', (
          tester,
        ) async {
          for (final (own, other) in [
            (12500, 9800),
            (0, 834390),
            (834390, 0),
            (0, 0),
          ]) {
            await _stage(
              tester,
              pkMatchFixture(
                now: DateTime.now(),
                ar: ar,
                ownScore: own,
                otherScore: other,
              ),
              language: language,
              viewport: viewport,
              textScale: scale,
            );
            final left = _rect(tester, PkBattleBar.leftScoreKey);
            final right = _rect(tester, PkBattleBar.rightScoreKey);
            final emblem = _rect(tester, PkBattleBar.emblemKey);
            expect(
              emblem.left,
              greaterThanOrEqualTo(left.right),
              reason: '$own:$other',
            );
            expect(
              emblem.right,
              lessThanOrEqualTo(right.left),
              reason: '$own:$other',
            );
            // Kabi stands over the track, above the figures.
            final kabi = find.descendant(
              of: find.byKey(LivePkStage.barKey),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Image &&
                    w.image is AssetImage &&
                    (w.image as AssetImage).assetName.contains('/kabi/'),
              ),
            );
            expect(kabi, findsNWidgets(2));
            for (final k in tester.widgetList(kabi)) {
              final r = tester.getRect(find.byWidget(k));
              expect(
                r.bottom,
                lessThanOrEqualTo(math.min(left.top, right.top) + 1),
                reason: '$own:$other',
              );
            }
          }
        });

        testWidgets('no gap: the bar sits right on both videos', (
          tester,
        ) async {
          await _stage(
            tester,
            pkMatchFixture(now: DateTime.now(), ar: ar),
            language: language,
            viewport: viewport,
            textScale: scale,
          );
          final bar = _rect(tester, LivePkStage.barKey);
          final own = _rect(tester, LivePkStage.ownPaneKey);
          final other = _rect(tester, LivePkStage.opponentPaneKey);
          expect(own.top, closeTo(bar.bottom, 0.01));
          expect(other.top, closeTo(bar.bottom, 0.01));
          // The track is the bar's bottom 30 lp; the emblem reaches over
          // the videos' top edge (overlap, never a gap).
          final emblem = _rect(tester, PkBattleBar.emblemKey);
          expect(emblem.bottom, greaterThan(own.top));
        });

        testWidgets('hosts at the bottom of their halves; the «+» only for '
            'the opponent and only when given', (tester) async {
          var follows = 0;
          await _stage(
            tester,
            pkMatchFixture(now: DateTime.now(), ar: ar),
            language: language,
            viewport: viewport,
            textScale: scale,
            onFollow: () => follows++,
          );
          expect(tester.takeException(), isNull);
          final ownPane = _rect(tester, LivePkStage.ownPaneKey);
          final otherPane = _rect(tester, LivePkStage.opponentPaneKey);
          final ownChip = _rect(tester, LivePkStage.ownHostKey);
          final otherChip = _rect(tester, LivePkStage.opponentHostKey);
          for (final (pane, chip) in [
            (ownPane, ownChip),
            (otherPane, otherChip),
          ]) {
            expect(pane.left <= chip.left && chip.right <= pane.right, isTrue);
            expect(chip.bottom, closeTo(pane.bottom - KLivePk.paneInset, 1));
            expect(chip.height, KLivePk.hostChip);
          }
          // Avatars 38 lp in the team ring, the names on one line.
          expect(KLivePk.hostAvatar, inInclusiveRange(36, 40));
          expect(
            find.descendant(
              of: find.byKey(LivePkStage.ownHostKey),
              matching: find.text(ar ? 'سارة' : 'Sara'),
            ),
            findsOneWidget,
          );
          final name = tester.widget<Text>(
            find.descendant(
              of: find.byKey(LivePkStage.opponentHostKey),
              matching: find.text(ar ? 'كريم' : 'Karim'),
            ),
          );
          expect(name.maxLines, 1);
          expect(name.overflow, TextOverflow.ellipsis);
          // The «+» is on the opponent's chip only.
          final plus = find.byKey(LivePkStage.followOpponentKey);
          expect(plus, findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(LivePkStage.opponentHostKey),
              matching: plus,
            ),
            findsOneWidget,
          );
          await tester.tap(plus);
          expect(follows, 1);
          // Not given (yourself, already following, a request pending):
          // no «+».
          await _stage(
            tester,
            pkMatchFixture(now: DateTime.now(), ar: ar),
            language: language,
            viewport: viewport,
            textScale: scale,
          );
          expect(find.byKey(LivePkStage.followOpponentKey), findsNothing);
        });

        testWidgets('a tap on a half or its host: that host (opponent '
            'flagged)', (tester) async {
          final taps = await _stage(
            tester,
            pkMatchFixture(now: DateTime.now(), ar: ar),
            language: language,
            viewport: viewport,
            textScale: scale,
          );
          await tester.tap(find.byKey(LivePkStage.opponentPaneKey));
          await tester.tap(
            find.descendant(
              of: find.byKey(LivePkStage.opponentHostKey),
              matching: find.byType(KAvatar),
            ),
          );
          await tester.tap(find.byKey(LivePkStage.ownPaneKey));
          expect(taps.map((t) => (t.host.id, t.opponent)), [
            ('host-b', true),
            ('host-b', true),
            ('user-0', false),
          ]);
        });
      });
    }
  }

  group('screens', () {
    Future<FakeProfileRepository> viewer(
      WidgetTester tester, {
      bool following = false,
      AppLanguage language = AppLanguage.ar,
    }) async {
      setViewport(tester, GoldenViewport.phone);
      final profiles = FakeProfileRepository(
        apiProfile(isFollowing: following),
      );
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final opponent = FakePkOpponentMedia()..present.add('host-b');
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        language: language,
        liveMediaEngine: engine,
        livePkRepository: FakeLivePkRepository(
          snapshot: PkState(
            match: pkMatchFixture(
              now: DateTime.now(),
              ar: language == AppLanguage.ar,
            ),
          ),
        ),
        pkOpponent: opponent,
        overrides: [
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(room: (id) => apiRoom(id: id, ar: true)),
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      return profiles;
    }

    testWidgets('viewer: «+» follows the other host for real, then hides', (
      tester,
    ) async {
      final profiles = await viewer(tester);
      expect(find.byKey(LivePkStage.ownHostKey), findsOneWidget);
      final plus = find.byKey(LivePkStage.followOpponentKey);
      expect(plus, findsOneWidget);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('PUT host_b'));
      expect(plus, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('viewer: already following — no «+»', (tester) async {
      await viewer(tester, following: true);
      expect(find.byKey(LivePkStage.opponentHostKey), findsOneWidget);
      expect(find.byKey(LivePkStage.followOpponentKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('viewer (${language.name}): a tap on the other half opens '
          "the other host's card for their room, without a gift button", (
        tester,
      ) async {
        await viewer(tester, language: language);
        await tester.tap(find.byKey(LivePkStage.opponentPaneKey));
        await tester.pumpAndSettle();
        final sheet = tester.widget<LivePersonSheet>(
          find.byType(LivePersonSheet),
        );
        expect(sheet.username, 'host_b');
        expect(sheet.scope?.roomId, 'room-b');
        expect(sheet.scope?.viewer, LivePersonRole.viewer);
        expect(sheet.scope?.target, LivePersonRole.host);
        expect(sheet.scope?.onGift, isNull);
        expect(find.byKey(LivePersonSheet.followKey), findsOneWidget);
        expect(find.byKey(LivePersonSheet.giftKey), findsNothing);
        expect(find.byKey(LivePersonToolKeys.kick), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets("viewer: a tap on my half opens this room host's card", (
      tester,
    ) async {
      await viewer(tester);
      await tester.tap(find.byKey(LivePkStage.ownPaneKey));
      await tester.pumpAndSettle();
      final sheet = tester.widget<LivePersonSheet>(
        find.byType(LivePersonSheet),
      );
      expect(sheet.scope?.roomId, 'room-0');
      expect(sheet.scope?.target, LivePersonRole.host);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('host: the other half → their card (no gift); my half → my '
        'own card with my mic; the «+» follows', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final profiles = FakeProfileRepository(apiProfile());
      final now = DateTime.now();
      final repo = FakeLivePkRepository(
        snapshot: PkState(
          match: pkMatchFixture(now: now, ownRoom: 'room-host'),
        ),
      );
      await pumpScreen(
        tester,
        const GoLiveScreen(),
        language: AppLanguage.ar,
        livePkRepository: repo,
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          profileRepositoryProvider.overrideWithValue(profiles),
          currentUserProvider.overrideWithValue(
            testUser(displayName: 'سارة').copyWith(canHost: true),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      final host = container.read(liveHostControllerProvider.notifier);
      await host.setMode(LiveRoomMode.solo);
      await host.goLive(title: 'سهرة');
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.pkStageKey), findsOneWidget);
      final bar = _rect(tester, LivePkStage.barKey);
      expect(
        _rect(tester, LivePkStage.ownPaneKey).top,
        closeTo(bar.bottom, 0.01),
      );
      // The other half → their card for their room.
      await tester.tap(find.byKey(LivePkStage.opponentPaneKey));
      await tester.pumpAndSettle();
      var sheet = tester.widget<LivePersonSheet>(find.byType(LivePersonSheet));
      expect(sheet.username, 'host_b');
      expect(sheet.scope?.roomId, 'room-b');
      expect(sheet.scope?.viewer, LivePersonRole.viewer);
      expect(find.byKey(LivePersonSheet.giftKey), findsNothing);
      Navigator.of(tester.element(find.byType(LivePersonSheet))).pop();
      await tester.pumpAndSettle();
      // My half → my card (host scope, my microphone).
      await tester.tap(find.byKey(LivePkStage.ownPaneKey));
      await tester.pumpAndSettle();
      sheet = tester.widget<LivePersonSheet>(find.byType(LivePersonSheet));
      expect(sheet.scope?.roomId, 'room-host');
      expect(sheet.scope?.viewer, LivePersonRole.host);
      expect(sheet.scope?.selfMic, isNotNull);
      Navigator.of(tester.element(find.byType(LivePersonSheet))).pop();
      await tester.pumpAndSettle();
      // «+» on the other host.
      await tester.tap(find.byKey(LivePkStage.followOpponentKey));
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('PUT host_b'));
      expect(find.byKey(LivePkStage.followOpponentKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
