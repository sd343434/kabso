// D385 (owner: «اجعل شات الإدارة مثبت في الاعلى بنفس هذه الطريقة بالإضافة
// يمكن للشخص تثبيت ٥ محادثات في الاعلى»): the row of round pictures between
// «الرسائل» and «الدردشات» — «دعم كابسو» always first (fixed, no unpin),
// then the chats the person pinned in pin order with their unread counts and
// (only when the server sends presence) the online dot; pin / unpin from a
// row's long press, a 6th refused with a clear message; no overflow at
// 360 / 393 wide, text ×1.0 / ×1.3, Arabic and English.
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/widgets/dm_pinned_row.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_groups_repository.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fake_support_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 12);
final List<String> _visited = [];

FakeDmRepository _dm({int people = 6}) {
  final dm = FakeDmRepository()..now = _now;
  for (var i = 0; i < people; i++) {
    final u = 'friend_$i';
    dm.addConversation(
      dmPerson(u, name: i == 0 ? 'Abdulrahman Al-Qahtani' : 'Friend $i'),
      unread: i == 1 ? 3 : 0,
      messages: [
        dm.message(
          'c-$u',
          mine: false,
          text: 'hello $i',
          at: _now.subtract(Duration(minutes: 5 + i)),
        ),
      ],
    );
  }
  return dm;
}

DmPin _pin(FakeDmRepository dm, String username) =>
    DmPin(chat: DmChat.direct(dm.byPeer[username]!), pinnedAt: _now);

Future<void> _pump(
  WidgetTester tester, {
  required FakeDmRepository dm,
  FakeDmPinsRepository? pins,
  FakeSupportRepository? support,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  _visited.clear();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const MessagesTab())],
    errorBuilder: (_, state) {
      _visited.add(state.uri.toString());
      return Scaffold(body: Text('at ${state.uri}'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dmRepositoryProvider.overrideWithValue(dm),
        dmGroupsRepositoryProvider.overrideWithValue(FakeDmGroupsRepository()),
        supportRepositoryProvider.overrideWithValue(
          support ?? FakeSupportRepository(),
        ),
        dmPinsRepositoryProvider.overrideWithValue(
          pins ?? FakeDmPinsRepository(),
        ),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The circles of the row, from the reading start (their keys' ids).
List<String> _circles(WidgetTester tester) {
  final circle = RegExp(r'^dm\.pins\.[^.]+$');
  final found = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value != 'dm.pins.row' &&
        circle.hasMatch(k.value);
  });
  final rtl =
      Directionality.of(tester.element(find.byKey(DmPinnedRow.rowKey))) ==
      TextDirection.rtl;
  final items = [
    for (final e in found.evaluate())
      (
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
        (e.widget.key! as ValueKey<String>).value.substring('dm.pins.'.length),
      ),
  ]..sort((a, b) => rtl ? b.$1.compareTo(a.$1) : a.$1.compareTo(b.$1));
  return [for (final i in items) i.$2];
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('«دعم كابسو» is always the first circle, even with no pins', (
    tester,
  ) async {
    await _pump(tester, dm: _dm(people: 1));
    expect(find.byKey(DmPinnedRow.rowKey), findsOneWidget);
    expect(find.byKey(DmPinnedRow.supportKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(DmPinnedRow.supportKey),
        matching: find.text(en.supportChatName),
      ),
      findsOneWidget,
    );
    // Between the title and «الدردشات», as the reference.
    final title = tester.getRect(find.byKey(DmInboxScreen.titleKey));
    final row = tester.getRect(find.byKey(DmPinnedRow.supportKey));
    final chats = tester.getRect(find.text(en.dmTabChats).first);
    expect(row.top, greaterThan(title.bottom));
    expect(chats.top, greaterThan(row.bottom));
    // Circle ≈ 56–60 dp, the name ≈ 12 dp under it.
    expect(KDmPins.circle, inInclusiveRange(56, 60));
    expect(KDmPins.nameSize, 12);
  });

  testWidgets('the support circle shows its unread replies; no unpin on it', (
    tester,
  ) async {
    final support = FakeSupportRepository()..reply('أهلًا');
    await _pump(tester, dm: _dm(people: 1), support: support);
    expect(find.byKey(DmPinnedRow.supportBadgeKey), findsOneWidget);
    await tester.longPress(find.byKey(DmPinnedRow.supportKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DmPinActions.unpinKey), findsNothing);
  });

  testWidgets('pins follow support in pin order, with unread and dots', (
    tester,
  ) async {
    final dm = _dm();
    final pins = FakeDmPinsRepository([
      _pin(dm, 'friend_2'),
      _pin(dm, 'friend_1'),
      _pin(dm, 'friend_4'),
    ]);
    pins.online['c-friend_2'] = true;
    // A peer whose presence the server does not send: no dot.
    await _pump(tester, dm: dm, pins: pins);
    expect(_circles(tester), [
      'support',
      'c-friend_2',
      'c-friend_1',
      'c-friend_4',
    ]);
    expect(find.byKey(DmPinnedRow.dotKey('c-friend_2')), findsOneWidget);
    expect(find.byKey(DmPinnedRow.dotKey('c-friend_1')), findsNothing);
    expect(find.byKey(DmPinnedRow.dotKey('c-friend_4')), findsNothing);
    expect(find.byKey(DmPinnedRow.badgeKey('c-friend_1')), findsOneWidget);
    expect(find.byKey(DmPinnedRow.badgeKey('c-friend_2')), findsNothing);
    // Pinned chats stay in the list below.
    expect(find.byKey(DmInboxScreen.rowKey('c-friend_2')), findsOneWidget);
  });

  testWidgets('pin from the long press; a 6th is refused with a message', (
    tester,
  ) async {
    final dm = _dm();
    final pins = FakeDmPinsRepository();
    await _pump(tester, dm: dm, pins: pins);
    Future<void> pinRow(String id) async {
      await tester.longPress(find.byKey(DmInboxScreen.rowKey(id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DmPinActions.pinKey));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 5; i++) {
      await pinRow('c-friend_$i');
    }
    expect(pins.calls.where((c) => c.startsWith('pin:')), hasLength(5));
    expect(_circles(tester), [
      'support',
      for (var i = 0; i < 5; i++) 'c-friend_$i',
    ]);
    // The 6th: the clear message, nothing asked of the server.
    await pinRow('c-friend_5');
    expect(find.text(en.dmPinLimit(5)), findsOneWidget);
    expect(pins.calls.where((c) => c.startsWith('pin:')), hasLength(5));
  });

  testWidgets('the server refusing a 6th (another device) says the same', (
    tester,
  ) async {
    final dm = _dm();
    final pins = FakeDmPinsRepository([
      for (var i = 0; i < 4; i++) _pin(dm, 'friend_$i'),
    ]);
    await _pump(tester, dm: dm, pins: pins);
    // Another device pinned a 5th meanwhile.
    pins.pins_.add(_pin(dm, 'friend_4'));
    await tester.longPress(find.byKey(DmInboxScreen.rowKey('c-friend_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DmPinActions.pinKey));
    await tester.pumpAndSettle();
    expect(find.text(en.dmPinLimit(5)), findsOneWidget);
  });

  testWidgets('unpin from the circle and from the row', (tester) async {
    final dm = _dm();
    final pins = FakeDmPinsRepository([
      _pin(dm, 'friend_1'),
      _pin(dm, 'friend_2'),
    ]);
    await _pump(tester, dm: dm, pins: pins, language: AppLanguage.ar);
    await tester.longPress(find.byKey(DmPinnedRow.pinKey('c-friend_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DmPinActions.unpinKey));
    await tester.pumpAndSettle();
    expect(find.byKey(DmPinnedRow.pinKey('c-friend_1')), findsNothing);
    expect(find.text(ar.dmUnpinned), findsOneWidget);
    await tester.longPress(find.byKey(DmInboxScreen.rowKey('c-friend_2')));
    await tester.pumpAndSettle();
    expect(find.text(ar.dmUnpin), findsOneWidget);
    await tester.tap(find.byKey(DmPinActions.unpinKey));
    await tester.pumpAndSettle();
    expect(_circles(tester), ['support']);
    expect(pins.calls, containsAll(['unpin:c-friend_1', 'unpin:c-friend_2']));
  });

  testWidgets('a tap on «دعم كابسو» opens the support chat', (tester) async {
    await _pump(tester, dm: _dm(people: 1));
    await tester.tap(find.byKey(DmPinnedRow.supportKey));
    await tester.pumpAndSettle();
    expect(_visited, [AppRoutes.supportChat]);
  });

  group('no overflow', () {
    for (final language in AppLanguage.values) {
      for (final size in const [Size(360, 800), Size(393, 852)]) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets(
            '${language.name} ${size.width.toInt()} ×$scale with 5 pins',
            (tester) async {
              final dm = _dm();
              final pins = FakeDmPinsRepository([
                for (var i = 0; i < 5; i++) _pin(dm, 'friend_$i'),
              ]);
              pins.online['c-friend_0'] = true;
              await withClock(Clock.fixed(_now), () async {
                await _pump(
                  tester,
                  dm: dm,
                  pins: pins,
                  language: language,
                  size: size,
                  textScale: scale,
                );
              });
              expect(tester.takeException(), isNull);
              expect(find.byKey(DmPinnedRow.supportKey), findsOneWidget);
              // The row scrolls sideways: the 6th circle may be off screen.
              await tester.drag(
                find.byKey(DmPinnedRow.rowKey),
                Offset(language == AppLanguage.ar ? 400 : -400, 0),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}
