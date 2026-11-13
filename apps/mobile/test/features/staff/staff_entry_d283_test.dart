// D283 (owner: «سيارة دخولية للمشرفين والإدارة»): a Kabso Team account's
// visible entry («فريق كابسو», the server's `staff-join`) plays the team's
// own entry car — the bundled SVGA, bottom-anchored full width like the VIP
// car (D280), once per join and not again after the live is minimized and
// opened again. A hidden watch sends nothing (no `staff-join`), so nothing
// plays. A FINANCE account joins as a viewer: its fixed team picture marks
// it, and the team's car plays instead of any VIP or store one.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _teamUrl = 'https://api.k.test/api/v1/staff/team-avatar.png';

const _moderator = UserSummary(
  id: 'u-mod',
  username: 'kabso.mod',
  displayName: 'Kabso Moderator',
  avatarUrl: _teamUrl,
);
const _finance = UserSummary(
  id: 'u-fin',
  username: 'kabso.fin',
  displayName: 'Kabso Finance',
  avatarUrl: _teamUrl,
);
const _plain = UserSummary(
  id: 'u-plain',
  username: 'plain',
  displayName: 'Plain',
  avatarUrl: null,
);

class _Live extends StatelessWidget {
  const new({required this.shown});

  final ValueListenable<bool> shown;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: shown,
    builder: (context, on, _) => Stack(
      fit: StackFit.expand,
      children: [if (on) const LiveVipEntranceLayer(roomId: 'room-0')],
    ),
  );
}

final Finder _car = find.byKey(LiveVipEntranceLayer.carKey);

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump();
  }
}

/// The car the layer shows within a few frames: the bundled team SVGA,
/// bottom-anchored full width (in tests the art does not play, so it leaves
/// right after its first frame).
Future<VipAnimatedArt?> _shownCar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    final art = find.descendant(
      of: _car,
      matching: find.byType(VipAnimatedArt),
    );
    if (art.evaluate().isNotEmpty) return tester.widget<VipAnimatedArt>(art);
    await tester.pump();
  }
  return null;
}

Future<({FakeLiveMediaEngine engine, ProviderContainer container})> _pump(
  WidgetTester tester,
  ValueNotifier<bool> shown,
) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    _Live(shown: shown),
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      currentUserProvider.overrideWithValue(testUser()),
      vipCatalogProvider.overrideWith(
        (ref) async => const VipTierList(tiers: [], maxAheadDays: 400),
      ),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(_Live)),
  );
  final keep = container.listen(liveChatProvider('room-0'), (_, _) {});
  addTearDown(keep.close);
  await container
      .read(liveChatProvider('room-0').notifier)
      .attach(engine, enabled: true, muted: false);
  await _frames(tester);
  return (engine: engine, container: container);
}

void main() {
  setUp(() => LiveVipEntranceLayer.animate = false);
  tearDown(() => LiveVipEntranceLayer.animate = true);

  test('the staff-join data message is read (and only that type)', () {
    final e = LiveChatEvent.parse({
      'type': 'staff-join',
      'user': {
        'id': 'u-mod',
        'username': 'kabso.mod',
        'displayName': 'Kabso Moderator',
        'avatarUrl': _teamUrl,
      },
    });
    expect(e, isA<LiveStaffJoined>());
    expect((e! as LiveStaffJoined).user.id, 'u-mod');
  });

  testWidgets("a visible staff entry plays the team's car (bottom-anchored, "
      'full width, its sound) once; no chat line; not again after '
      'minimize / restore', (tester) async {
    final shown = ValueNotifier(true);
    final (:engine, :container) = await _pump(tester, shown);
    engine.chat.add(const LiveStaffJoined(_moderator));
    final car = await _shownCar(tester);
    expect(car, isNotNull);
    expect(car!.animation, LiveVipEntranceLayer.teamCarSource);
    expect(car.animation, startsWith(SvgaDocs.assetPrefix));
    expect(car.fit, LiveVipEntranceLayer.carFit);
    expect(car.alignment, LiveVipEntranceLayer.carAlignment);
    expect(car.once, isTrue);
    // No chat line and no join strip for the team (D273).
    final chat = container.read(liveChatProvider('room-0'));
    expect(chat.latestJoin, isNull);
    expect(chat.items.whereType<LiveChatJoinItem>(), isEmpty);
    await _frames(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_car, findsNothing);

    // Minimized and opened again: nothing plays again.
    shown.value = false;
    await _frames(tester);
    shown.value = true;
    expect(await _shownCar(tester), isNull);
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('a hidden watch announces nothing; an ordinary join without '
      'VIP plays no car', (tester) async {
    final shown = ValueNotifier(true);
    final (:engine, container: _) = await _pump(tester, shown);
    // (A hidden `staff:` observer sends no data message at all.)
    engine.chat.add(const LiveChatJoined(_plain));
    expect(await _shownCar(tester), isNull);
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets("FINANCE joining as a viewer: the team's car, by its fixed "
      'picture', (tester) async {
    final shown = ValueNotifier(true);
    final (:engine, container: _) = await _pump(tester, shown);
    engine.chat.add(const LiveChatJoined(_finance));
    expect(
      (await _shownCar(tester))?.animation,
      LiveVipEntranceLayer.teamCarSource,
    );
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('the bundled entry car is a readable SVGA: 396 × 720, 12 fps, '
      '73 frames, with its sound', (tester) async {
    final doc = await tester.runAsync(() async {
      final data = await rootBundle.load(LiveVipEntranceLayer.teamCarAsset);
      return SvgaDoc.parse(data.buffer.asUint8List());
    });
    expect(doc, isNotNull);
    expect(doc!.viewBox, const Size(396, 720));
    expect(doc.fps, 12);
    expect(doc.frameCount, 73);
    expect(doc.sounds, isNotEmpty);
    // Played through the shared engine like a hosted car.
    expect(VipSvga.enabled, isA<bool>());
  });
}
