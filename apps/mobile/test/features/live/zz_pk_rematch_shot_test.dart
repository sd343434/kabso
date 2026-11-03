// TEMPORARY (screenshots for the owner, never merged).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _shot = Key('shot');

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      tester.renderObject(find.byKey(_shot)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image img = await boundary.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  final now = DateTime.now();

  testWidgets('SHOT sheet', (tester) async {
    await loadAppFonts();
    setViewport(tester, GoldenViewport.phone);
    final match = pkRematchFixture(now: now);
    final repo = FakeLivePkRepository(snapshot: PkState(match: match));
    await pumpScreen(
      tester,
      const RepaintBoundary(
        key: _shot,
        child: Scaffold(
          backgroundColor: Color(0xFF1B1530),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LivePkSheet(roomId: 'room-0'),
          ),
        ),
      ),
      language: AppLanguage.ar,
      livePkRepository: repo,
    );
    ProviderScope.containerOf(tester.element(find.byType(LivePkSheet)))
        .read(livePkProvider('room-0').notifier)
        .debugSetMatch(match);
    await _save(tester, 'pk_sheet_request');
  });

  testWidgets('SHOT opponent box', (tester) async {
    await loadAppFonts();
    PkRematchDock.debugSeconds = 12;
    addTearDown(() => PkRematchDock.debugSeconds = null);
    setViewport(tester, GoldenViewport.phone);
    final match = pkRematchFixture(now: now, offerBy: 'room-b');
    await pumpScreen(
      tester,
      RepaintBoundary(
        key: _shot,
        child: MediaQuery(
          data: MediaQueryData(
            size: GoldenViewport.phone.logicalSize,
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF1B1530),
            resizeToAvoidBottomInset: false,
            body: KLiveRoomScaffold(
              header: const SizedBox(height: 48),
              stage: LivePkStage(
                match: match,
                roomId: 'room-0',
                ownVideo: null,
                opponentVideo: null,
                now: () => now,
              ),
              stageEdgeToEdge: true,
              chat: const SizedBox(height: 120),
              dock: LivePkStage.dareDock(
                match: match,
                roomId: 'room-0',
                now: () => now,
                isHost: true,
                rematch: PkRematchActions(
                  onOffer: () async {},
                  onAccept: () async {},
                  onDecline: () async {},
                  onCancel: () async {},
                ),
              ),
              actionBar: const SizedBox(height: 76),
            ),
          ),
        ),
      ),
      language: AppLanguage.ar,
    );
    await _save(tester, 'pk_opponent_box');
  });
}
