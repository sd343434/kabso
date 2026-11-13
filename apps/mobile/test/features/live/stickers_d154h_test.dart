// D154h («ملصقات», CONVENTIONS §10.38): the stickers over a live — where
// they land (relative to the picture, the same on every screen), the
// host's drag saved, the viewers' stickers untouchable, a change arriving
// live, the host's sheet (art, text, the limit of 3, remove, a refused
// save going back) — Arabic RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_sticker_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_sticker_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_sticker_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _room = 'room-0';

/// Kabi art loops for ever, so fixed steps instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const _love = LiveSticker(id: 's1', artKey: 'kabi_love', x: 0.25, y: 0.5);
const _hello = LiveSticker(
  id: 's2',
  text: 'أهلاً بكم',
  x: 0.75,
  y: 0.25,
  scale: 1.5,
  rotation: 0.4,
);

class _Live extends ConsumerStatefulWidget {
  const new(this.engine, {required this.editable});

  final FakeLiveMediaEngine engine;
  final bool editable;

  @override
  ConsumerState<_Live> createState() => _LiveState();
}

class _LiveState extends ConsumerState<_Live> {
  @override
  void initState() {
    super.initState();
    ref.read(liveStickersProvider(_room).notifier).attach(widget.engine);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF333344),
    body: Stack(
      fit: StackFit.expand,
      children: [
        LiveStickerLayer(roomId: _room, editable: widget.editable),
        Positioned(
          bottom: 8,
          left: 8,
          child: Builder(
            builder: (context) => TextButton(
              key: const Key('test.sheet'),
              onPressed: () =>
                  unawaited(showLiveStickerSheet(context, roomId: _room)),
              child: const SizedBox.square(dimension: 24),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<(FakeLiveStickerRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<LiveSticker> stickers = const [_love, _hello],
  bool editable = false,
}) async {
  setViewport(tester, GoldenViewport.android);
  final repo = FakeLiveStickerRepository(stickers: {_room: stickers});
  final engine = FakeLiveMediaEngine();
  await pumpScreen(
    tester,
    _Live(engine, editable: editable),
    language: language,
    liveStickerRepository: repo,
    liveMediaEngine: engine,
  );
  await _settle(tester);
  return (repo, engine);
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('the stickers land at their place on the picture, whatever '
        'the direction; viewers cannot move them (${language.name})', (
      tester,
    ) async {
      final (repo, _) = await _pump(tester, language: language);
      final art = tester.getCenter(find.byKey(LiveStickerLayer.stickerKey(0)));
      expect(art.dx, closeTo(360 * 0.25, 0.5));
      expect(art.dy, closeTo(800 * 0.5, 0.5));
      final text = tester.getCenter(find.byKey(LiveStickerLayer.stickerKey(1)));
      expect(text.dx, closeTo(360 * 0.75, 0.5));
      expect(text.dy, closeTo(800 * 0.25, 0.5));
      expect(find.text('أهلاً بكم'), findsOneWidget);
      await tester.drag(
        find.byKey(LiveStickerLayer.stickerKey(0)),
        const Offset(40, 0),
        warnIfMissed: false,
      );
      await _settle(tester);
      expect(repo.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("the host's drag moves the sticker and saves the list", (
    tester,
  ) async {
    final (repo, _) = await _pump(tester, editable: true);
    await tester.drag(
      find.byKey(LiveStickerLayer.stickerKey(0)),
      const Offset(72, -80),
    );
    await _settle(tester);
    expect(repo.saved, hasLength(1));
    final moved = repo.saved.single.first;
    expect(moved.id, 's1');
    // The drag's slop eats a few points; the place moved by about the drag.
    expect(moved.x, closeTo(0.25 + 72 / 360, 0.03));
    expect(moved.y, closeTo(0.5 - 80 / 800, 0.03));
    expect(repo.saved.single.last, _hello);
  });

  testWidgets("a change arrives live; art this app can't draw is skipped", (
    tester,
  ) async {
    final (_, engine) = await _pump(tester, stickers: const []);
    expect(find.byKey(LiveStickerLayer.stickerKey(0)), findsNothing);
    engine.chat.add(
      const LiveStickersChanged(
        LiveStickers(
          roomId: _room,
          items: [
            LiveSticker(id: 'a', artKey: 'acme_logo', x: 0.5, y: 0.5),
            LiveSticker(id: 'b', text: 'Hi', x: 0.5, y: 0.5),
          ],
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(LiveStickerLayer.stickerKey(0)), findsNothing);
    expect(find.byKey(LiveStickerLayer.stickerKey(1)), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the sheet adds art and text up to 3, then says so; remove '
        'frees a place (${language.name})', (tester) async {
      final (repo, _) = await _pump(
        tester,
        language: language,
        stickers: const [_love],
        editable: true,
      );
      await tester.tap(find.byKey(const Key('test.sheet')));
      await _settle(tester);
      // Only art this app can draw is offered.
      expect(find.byKey(LiveStickerSheet.artKey('acme_unknown')), findsNothing);
      await tester.tap(find.byKey(LiveStickerSheet.artKey('kabi_fire')));
      await _settle(tester);
      expect(repo.saved.last.map((s) => s.artKey), ['kabi_love', 'kabi_fire']);
      await tester.enterText(find.byKey(LiveStickerSheet.textKey), ' Hello ');
      await tester.tap(find.byKey(LiveStickerSheet.addTextKey));
      await _settle(tester);
      expect(repo.saved.last.last.text, 'Hello');
      expect(find.byKey(LiveStickerSheet.fullKey), findsOneWidget);
      await tester.tap(find.byKey(LiveStickerSheet.artKey('kabi_hi')));
      await _settle(tester);
      expect(repo.saved, hasLength(2));
      await tester.tap(find.byKey(LiveStickerSheet.removeKey(0)));
      await _settle(tester);
      expect(repo.saved.last.map((s) => s.id), ['sticker-0', 'sticker-1']);
      expect(find.byKey(LiveStickerSheet.fullKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a refused save goes back to the saved stickers and says why', (
    tester,
  ) async {
    final (repo, _) = await _pump(tester, stickers: const [_love]);
    repo.failure = const ServerFailure(
      code: ErrorCode.validationFailed,
      rawCode: 'VALIDATION_FAILED',
      debugMessage: 'x',
      statusCode: 400,
    );
    await tester.tap(find.byKey(const Key('test.sheet')));
    await _settle(tester);
    await tester.tap(find.byKey(LiveStickerSheet.removeKey(0)));
    await _settle(tester);
    expect(find.byKey(LiveStickerSheet.removeKey(0)), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  test('the data message', () {
    final event = LiveChatEvent.parse({
      'type': 'stickers',
      'stickers': {
        'roomId': _room,
        'items': [
          {
            'id': 's1',
            'artKey': 'kabi_love',
            'text': null,
            'x': 0.5,
            'y': 0.4,
            'scale': 1.2,
            'rotation': -0.5,
          },
        ],
      },
    });
    final items = (event! as LiveStickersChanged).stickers.items;
    expect(items.single.scale, 1.2);
    expect(items.single.toRequest(), {
      'id': 's1',
      'artKey': 'kabi_love',
      'x': 0.5,
      'y': 0.4,
      'scale': 1.2,
      'rotation': -0.5,
    });
    expect(
      const LiveSticker(id: '', x: 2, y: -1).moved(rotation: 4).toRequest(),
      {'x': 1.0, 'y': 0.0, 'scale': 1.0, 'rotation': closeTo(4 - 6.2832, 1e-3)},
    );
  });
}
