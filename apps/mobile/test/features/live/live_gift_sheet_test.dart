// CP-020: the live gift panel — tabs, gifts, recipients, quantity, sending
// with coins and from the bag, combos, the clientId retry, refusals, the
// empty catalogue, missing art, guests and the host; D117: the
// sub-category chips; D128: the host or a seated guest gifting themself and
// a Send that is never silent; Arabic RTL and English at 360×800 with text
// scale 2.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
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
const _omar = UserSummary(
  id: 'user-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);
const _nour = UserSummary(
  id: 'user-nour',
  username: 'nour',
  displayName: 'Nour',
  avatarUrl: null,
);

const _open = Key('test.openGifts');

class _Opener extends StatelessWidget {
  const new({required this.room, this.preselect});

  final LiveGiftRoom room;
  final LiveGiftPreselect? preselect;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () => unawaited(
          KLiveGiftSheet.show(context, room: room, preselect: preselect),
        ),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

class _Harness {
  new(this.gifts, this.live);

  final FakeLiveGiftRepository gifts;
  final FakeLiveRepository live;
  int staleSeats = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  FakeLiveGiftRepository? gifts,
  AppLanguage language = AppLanguage.en,
  List<UserSummary> seated = const [_omar, _nour],
  LiveGiftPreselect? preselect,
  User? user,
  bool signedIn = true,
  int coins = 1000,
}) async {
  setViewport(tester, GoldenViewport.android);
  final h = _Harness(
    gifts ??
        FakeLiveGiftRepository(
          codes: giftFixtureCodes,
          ar: language == AppLanguage.ar,
          coins: coins,
        ),
    FakeLiveRepository()..coins = coins,
  );
  await pumpScreen(
    tester,
    _Opener(
      preselect: preselect,
      room: LiveGiftRoom(
        roomId: 'room-0',
        host: _host,
        seated: (_) => seated,
        onSeatsStale: () => h.staleSeats++,
      ),
    ),
    language: language,
    liveGiftRepository: h.gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(h.live),
      currentUserProvider.overrideWithValue(
        signedIn ? user ?? testUser() : null,
      ),
    ],
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return h;
}

Finder _cell(String code, {bool bag = false}) =>
    find.byKey(KLiveGiftSheet.cellKey(code, bag: bag));

bool _selected(WidgetTester tester, Finder finder) =>
    tester
        .getSemantics(
          find.descendant(of: finder, matching: find.byType(Semantics)).first,
        )
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

/// Send is lit (D128: a dimmed Send still takes taps, to say why).
bool _sendEnabled(WidgetTester tester) =>
    tester
        .getSemantics(find.bySemanticsLabel(en.giftSend))
        .getSemanticsData()
        .flagsCollection
        .isEnabled ==
    Tristate.isTrue;

/// The message over the grid (D128), or null.
String? _toast(WidgetTester tester) {
  final f = find.descendant(
    of: find.byKey(KLiveGiftSheet.toastKey),
    matching: find.byType(Text),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Why Send is off, as screen readers hear it (null: no hint).
String? _sendHint(WidgetTester tester) {
  final hint = tester
      .getSemantics(find.bySemanticsLabel(en.giftSend))
      .getSemanticsData()
      .hint;
  return hint == '' ? null : hint;
}

final AppLocalizations en = l10nFor(AppLanguage.en);

String? _reason(WidgetTester tester) {
  final f = find.byKey(KLiveGiftSheet.reasonKey);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('tabs from the catalogue plus the bag; 4-column grid with '
      'names, prices and badges', (tester) async {
    await _pump(tester);
    expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
    for (final tab in [
      en.liveGiftTabPopular,
      en.liveGiftTabEvent,
      en.liveGiftTabFun,
    ]) {
      expect(find.text(tab), findsOneWidget);
    }
    // D117: the bag is an icon at the end, named for screen readers.
    expect(find.bySemanticsLabel(en.liveGiftTabBag), findsOneWidget);
    for (final code in ['rose', 'heart_balloon', 'crown', 'sports_car']) {
      expect(_cell(code), findsOneWidget, reason: code);
      expect(find.text(giftFixtureName(code, ar: false)), findsOneWidget);
    }
    expect(_cell('lantern'), findsNothing);
    // Prices with the coin (digits as in the reference, D117), NEW badges.
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('299'), findsOneWidget);
    expect(find.text(en.liveGiftBadgeNew.toUpperCase()), findsNWidgets(2));
    // Four in a row.
    final y = tester.getCenter(_cell('rose')).dy;
    for (final code in ['heart_balloon', 'crown', 'sports_car']) {
      expect(tester.getCenter(_cell(code)).dy, y);
    }

    await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('EVENT')));
    expect(_cell('lantern'), findsOneWidget);
    expect(_cell('cake'), findsOneWidget);
    expect(find.text(en.liveGiftBadgeEvent), findsNWidgets(2));
    expect(_cell('rose'), findsNothing);

    await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('FUN')));
    expect(_cell('confetti'), findsOneWidget);
    expect(_cell('kabi_dance'), findsOneWidget);
  });

  testWidgets('D135: bigger gifts (70 pt, 4 columns, two rows showing), the '
      'gold coin on prices and the balance, 48 pt recipients that scroll', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 8; i++)
        UserSummary(
          id: 'u-$i',
          username: 'guest$i',
          displayName: 'Guest $i',
          avatarUrl: null,
        ),
    ];
    for (final viewport in [GoldenViewport.android, GoldenViewport.phone]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, seated: many);
      if (viewport == GoldenViewport.phone) {
        setViewport(tester, viewport);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: viewport.name);
      // The picture: 70 pt (was 54).
      final image = tester.getSize(
        find.byKey(KLiveGiftSheet.giftImageKey('rose')),
      );
      expect(image.width, closeTo(70, 0.5), reason: viewport.name);
      // Four in a row, and the second row is on screen too.
      final y = tester.getCenter(_cell('rose')).dy;
      for (final code in ['heart_balloon', 'crown', 'sports_car']) {
        expect(tester.getCenter(_cell(code)).dy, y);
      }
      // Every coin is the owner's gold coin.
      final coins = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/currency/kabso_coin.png',
      );
      expect(coins, findsAtLeastNWidgets(5));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('kabso_coin.webp'),
        ),
        findsNothing,
      );
      // Recipients: 48 pt targets with 40 pt pictures; the row scrolls.
      final host = find.byKey(KLiveGiftSheet.recipientKey('sara'));
      final size = tester.getSize(host);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      final last = find.byKey(KLiveGiftSheet.recipientKey('guest7'));
      final row = find
          .ancestor(of: host, matching: find.byType(Scrollable))
          .first
          .evaluate()
          .single;
      await tester.scrollUntilVisible(
        last,
        80,
        scrollable: find.byElementPredicate((e) => e == row),
      );
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(_selected(tester, last), isTrue);
      expect(tester.takeException(), isNull, reason: viewport.name);
    }
  });

  testWidgets('recipients: the host by default with the Host chip; several '
      'at once; All on mic and back', (tester) async {
    await _pump(tester);
    final host = find.byKey(KLiveGiftSheet.recipientKey('sara'));
    final omar = find.byKey(KLiveGiftSheet.recipientKey('omar'));
    final nour = find.byKey(KLiveGiftSheet.recipientKey('nour'));
    expect(find.text(en.liveGiftHost), findsOneWidget);
    expect(_selected(tester, host), isTrue);
    expect(_selected(tester, omar), isFalse);
    // Nothing chosen to send yet: Send is dimmed and says why (the
    // reference's own state shows no line, D117).
    expect(_sendEnabled(tester), isFalse);
    expect(_reason(tester), isNull);
    expect(_sendHint(tester), en.liveGiftPickGift);
    // D128: a tap on the dimmed Send says why (it never does nothing), and
    // the message goes by itself.
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_toast(tester), en.liveGiftPickGift);
    await tester.pump(KLiveGiftSheet.toastTime);
    await tester.pumpAndSettle();
    expect(_toast(tester), isNull);

    await _tap(tester, _cell('rose'));
    expect(_sendEnabled(tester), isTrue);
    expect(_reason(tester), isNull);

    await _tap(tester, omar);
    expect(_selected(tester, omar), isTrue);
    expect(_selected(tester, host), isTrue);
    await _tap(tester, host);
    await _tap(tester, omar);
    expect(_sendEnabled(tester), isFalse);
    expect(_reason(tester), en.liveGiftPickRecipient);
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_toast(tester), en.liveGiftPickRecipient);
    await tester.pump(KLiveGiftSheet.toastTime);

    await _tap(tester, find.byKey(KLiveGiftSheet.allKey));
    for (final f in [host, omar, nour]) {
      expect(_selected(tester, f), isTrue);
    }
    await _tap(tester, find.byKey(KLiveGiftSheet.allKey));
    expect(_selected(tester, host), isTrue);
    expect(_selected(tester, omar), isFalse);
    expect(_selected(tester, nour), isFalse);
  });

  testWidgets('send with coins: the chosen quantity and recipients, the '
      'balance from the answer, the effect queued', (tester) async {
    final h = await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(KLiveGiftSheet.balanceKey),
        matching: find.text('1,000'),
      ),
      findsOneWidget,
    );
    await _tap(tester, _cell('heart_balloon'));
    await _tap(tester, find.byKey(KLiveGiftSheet.recipientKey('omar')));
    // D131 (ref 161): the quantities sit in the pill, one tap each.
    await _tap(tester, find.byKey(KLiveGiftSheet.quantityOptionKey(10)));
    expect(
      find.descendant(
        of: find.byKey(KLiveGiftSheet.quantityKey),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    final send = h.gifts.sends.single;
    expect(send.roomId, 'room-0');
    expect(send.giftCode, 'heart_balloon');
    expect(send.quantity, 10);
    expect(send.recipients, ['sara', 'omar']);
    expect(send.source, LiveGiftSource.coins);
    expect(
      send.clientId,
      matches(RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')),
    );
    // 10 coins × 10 × 2 recipients.
    expect(
      find.descendant(
        of: find.byKey(KLiveGiftSheet.balanceKey),
        matching: find.text('800'),
      ),
      findsOneWidget,
    );
    expect(_reason(tester), isNull);
    // The combo window ends.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('combo: quick taps queue more sends, each with a new '
      'clientId; ×N from the answers; a spinner while sending', (tester) async {
    final h = await _pump(tester);
    await _tap(tester, _cell('rose'));
    final gate = h.gifts.sendGate = Completer<void>();
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pump();
    expect(h.gifts.sends, hasLength(1));
    h.gifts.sendGate = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect(h.gifts.sends, hasLength(3));
    expect(h.gifts.sends.map((s) => s.clientId).toSet(), hasLength(3));
    expect(find.byKey(KLiveGiftSheet.comboKey), findsOneWidget);
    expect(find.text(en.giftCombo(3)), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // After the combo window the counter goes.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(KLiveGiftSheet.comboKey), findsNothing);
  });

  testWidgets('a lost answer is sent again with the same clientId; a new '
      'gift gets a new one', (tester) async {
    final h = await _pump(tester);
    await _tap(tester, _cell('rose'));
    h.gifts.failNext['send'] = const NetworkFailure.timeout();
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_reason(tester), en.errorNetworkTimeout);
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends, hasLength(2));
    expect(h.gifts.sends[1].clientId, h.gifts.sends[0].clientId);
    expect(_reason(tester), isNull);
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends[2].clientId, isNot(h.gifts.sends[0].clientId));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('not enough coins: the message, the balance read again, '
      'nothing charged', (tester) async {
    final h = await _pump(tester, coins: 100);
    final reads = h.live.walletReads;
    await _tap(tester, _cell('crown'));
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_reason(tester), en.liveGiftNotEnoughCoins);
    // D128: never silent — the message also shows over the grid.
    expect(_toast(tester), en.liveGiftNotEnoughCoins);
    expect(h.gifts.coins, 100);
    expect(h.live.walletReads, greaterThan(reads));
    expect(find.byKey(KLiveGiftSheet.comboKey), findsNothing);
  });

  testWidgets('a recipient who left the mic: the message, seats read again', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _tap(tester, _cell('rose'));
    h.gifts.failNext['send'] = FakeLiveGiftRepository.conflict(
      ErrorCode.liveGiftRecipientUnavailable,
    );
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_reason(tester), en.errorLiveGiftRecipientUnavailable);
    expect(_toast(tester), en.errorLiveGiftRecipientUnavailable);
    expect(h.staleSeats, 1);
  });

  testWidgets('the bag: ×N corners; a send from the bag takes from it, no '
      'coins', (tester) async {
    final h = await _pump(
      tester,
      gifts: FakeLiveGiftRepository(
        codes: giftFixtureCodes,
        held: const {'rose': 5, 'cake': 1},
      ),
    );
    await _tap(
      tester,
      find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab)),
    );
    expect(_cell('rose', bag: true), findsOneWidget);
    expect(_cell('cake', bag: true), findsOneWidget);
    expect(
      find.descendant(
        of: _cell('rose', bag: true),
        matching: find.text(en.giftCombo(5)),
      ),
      findsOneWidget,
    );
    await _tap(tester, _cell('rose', bag: true));
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends.single.source, LiveGiftSource.bag);
    expect(h.gifts.coins, 1000);
    expect(
      find.descendant(
        of: _cell('rose', bag: true),
        matching: find.text(en.giftCombo(4)),
      ),
      findsOneWidget,
    );
    // Too many for the bag.
    await _tap(tester, find.byKey(KLiveGiftSheet.allKey));
    // D131 (ref 161): the quantities sit in the pill, one tap each.
    await _tap(tester, find.byKey(KLiveGiftSheet.quantityOptionKey(10)));
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_reason(tester), en.errorGiftBagInsufficient);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('an empty bag says so', (tester) async {
    await _pump(tester);
    await _tap(
      tester,
      find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab)),
    );
    expect(find.text(en.liveGiftBagEmptyTitle), findsOneWidget);
  });

  testWidgets('empty catalogue (production today): "No gifts yet", no '
      'invented gifts, Send off', (tester) async {
    await _pump(tester, gifts: FakeLiveGiftRepository());
    expect(find.text(en.liveGiftEmptyTitle), findsOneWidget);
    expect(find.text(en.liveGiftEmptyMessage), findsOneWidget);
    expect(find.byType(KGiftImage), findsNothing);
    expect(_sendEnabled(tester), isFalse);
    // Every tab is empty, the bag too.
    await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('FUN')));
    expect(find.text(en.liveGiftEmptyTitle), findsOneWidget);
    await _tap(
      tester,
      find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab)),
    );
    expect(find.text(en.liveGiftEmptyTitle), findsOneWidget);
  });

  testWidgets('gift art not in the app yet: the faded Kabso gift box, no '
      'error', (tester) async {
    await _pump(tester);
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (_, _) {});
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: _cell('rose'),
        matching: find.byKey(KGiftImage.fallbackKey),
      ),
      findsOneWidget,
    );
    expect(KGiftAssets.image('gift_rose'), 'assets/gifts/gift_rose.png');
    expect(KGiftAssets.image('../secret'), isNull);
    expect(KGiftAssets.image('a/../b'), isNull);
    expect(
      KGiftAssets.animation('fx_sports_car'),
      'assets/gifts/anim/fx_sports_car.svga',
    );
    expect(KGiftAssets.animation(null), isNull);
  });

  testWidgets("a person's card: that person chosen; someone off the mic: "
      'the host and a note', (tester) async {
    await _pump(tester, preselect: (username: 'omar', name: 'Omar'));
    expect(
      _selected(tester, find.byKey(KLiveGiftSheet.recipientKey('omar'))),
      isTrue,
    );
    expect(
      _selected(tester, find.byKey(KLiveGiftSheet.recipientKey('sara'))),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, preselect: (username: 'zaid', name: 'Zaid'));
    expect(
      _selected(tester, find.byKey(KLiveGiftSheet.recipientKey('sara'))),
      isTrue,
    );
    expect(find.textContaining("isn't on the mic"), findsOneWidget);
  });

  testWidgets('D128: the host may gift themself — alone in the live, the '
      'host is chosen and Send sends to them', (tester) async {
    final hostUser = testUser(username: 'sara', displayName: 'Sara');
    final h = await _pump(
      tester,
      user: hostUser.copyWith(id: 'user-sara'),
      seated: [],
    );
    // D131 (ref 161): one possible recipient, no row; the host is it.
    expect(find.byKey(KLiveGiftSheet.recipientKey('sara')), findsNothing);
    expect(find.byKey(KLiveGiftSheet.allKey), findsNothing);
    await _tap(tester, _cell('rose'));
    expect(_sendEnabled(tester), isTrue);
    expect(_reason(tester), isNull);
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends.single.recipients, ['sara']);
    expect(_reason(tester), isNull);
    expect(_toast(tester), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('D128: the host with people on the mic: themself by default, '
      'the others too', (tester) async {
    final hostUser = testUser(username: 'sara', displayName: 'Sara');
    final h = await _pump(
      tester,
      user: hostUser.copyWith(id: 'user-sara'),
      seated: const [_omar],
    );
    expect(
      _selected(tester, find.byKey(KLiveGiftSheet.recipientKey('sara'))),
      isTrue,
    );
    await _tap(tester, find.byKey(KLiveGiftSheet.recipientKey('omar')));
    await _tap(tester, _cell('rose'));
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends.single.recipients, ['sara', 'omar']);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('D128: a seated guest may gift themself', (tester) async {
    final guest = testUser(username: 'omar', displayName: 'Omar');
    final h = await _pump(
      tester,
      user: guest.copyWith(id: 'user-omar'),
      seated: const [_omar],
    );
    final me = find.byKey(KLiveGiftSheet.recipientKey('omar'));
    expect(me, findsOneWidget);
    // The host stays the default.
    expect(
      _selected(tester, find.byKey(KLiveGiftSheet.recipientKey('sara'))),
      isTrue,
    );
    await _tap(tester, find.byKey(KLiveGiftSheet.recipientKey('sara')));
    await _tap(tester, me);
    await _tap(tester, _cell('rose'));
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(h.gifts.sends.single.recipients, ['omar']);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('D128: a viewer off the mic is never offered as a recipient', (
    tester,
  ) async {
    // testUser() is not the host and not seated.
    await _pump(tester, seated: const [_omar]);
    expect(
      find.byKey(KLiveGiftSheet.recipientKey(testUser().username)),
      findsNothing,
    );
    expect(find.byKey(KLiveGiftSheet.recipientKey('sara')), findsOneWidget);
    expect(find.byKey(KLiveGiftSheet.recipientKey('omar')), findsOneWidget);
  });

  testWidgets('D128: an unexpected failure is shown, never silent', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _tap(tester, _cell('rose'));
    h.gifts.failNext['send'] = FakeLiveGiftRepository.conflict(
      ErrorCode.liveRoomEnded,
    );
    await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
    expect(_reason(tester), isNotNull);
    expect(_toast(tester), _reason(tester));
    expect(find.byKey(KLiveGiftSheet.comboKey), findsNothing);
  });

  testWidgets('D117: chips "All" plus the open tab\'s tags filter the grid; '
      'no chip row for a tab without tags', (tester) async {
    await _pump(tester);
    final all = find.byKey(KLiveGiftSheet.tagKey(null));
    final love = find.byKey(KLiveGiftSheet.tagKey('love'));
    final luxury = find.byKey(KLiveGiftSheet.tagKey('luxury'));
    expect(all, findsOneWidget);
    expect(find.text(en.liveGiftTagAll), findsWidgets);
    expect(find.text('Love'), findsOneWidget);
    expect(find.text('Luxury'), findsOneWidget);
    expect(_selected(tester, all), isTrue);
    // Love first: the order the tags first appear.
    expect(tester.getCenter(love).dx < tester.getCenter(luxury).dx, isTrue);

    await _tap(tester, _cell('rose'));
    await _tap(tester, luxury);
    expect(_selected(tester, luxury), isTrue);
    expect(_cell('crown'), findsOneWidget);
    expect(_cell('sports_car'), findsOneWidget);
    expect(_cell('rose'), findsNothing);
    expect(_cell('heart_balloon'), findsNothing);
    // The gift picked under another chip is no longer picked.
    expect(_sendEnabled(tester), isFalse);

    await _tap(tester, all);
    expect(_cell('rose'), findsOneWidget);
    expect(_cell('crown'), findsOneWidget);

    await _tap(tester, luxury);
    await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('EVENT')));
    expect(all, findsNothing);
    expect(_cell('lantern'), findsOneWidget);
    // Back on the tab, the chips start at All again.
    await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('POPULAR')));
    expect(_selected(tester, all), isTrue);
    expect(_cell('rose'), findsOneWidget);
  });

  testWidgets('guests are asked to log in; nothing is read', (tester) async {
    final h = await _pump(tester, signedIn: false);
    expect(find.text(en.liveGiftSignIn), findsOneWidget);
    expect(h.gifts.calls, isEmpty);
  });

  testWidgets('Arabic (RTL) and English at 360×800, text scale 2: no '
      'overflow, the first gift at the reading start', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull, reason: language.name);
      final l10n = language == AppLanguage.ar ? ar : en;
      expect(find.text(l10n.liveGiftTabPopular), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.liveGiftTabBag), findsOneWidget);
      expect(
        find.text(giftFixtureName('rose', ar: language == AppLanguage.ar)),
        findsOneWidget,
      );
      final first = tester.getCenter(_cell('rose')).dx;
      final second = tester.getCenter(_cell('heart_balloon')).dx;
      expect(first < second, language == AppLanguage.en);
      await _tap(tester, _cell('sports_car'));
      await _tap(tester, find.byKey(KLiveGiftSheet.allKey));
      expect(tester.takeException(), isNull, reason: language.name);
      await _tap(
        tester,
        find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab)),
      );
      expect(find.text(l10n.liveGiftBagEmptyTitle), findsOneWidget);
      expect(tester.takeException(), isNull, reason: language.name);
    }
  });

  group('D131 (ref 161): Recent, price order, the bottom row', () {
    testWidgets('Recent lists what this phone sent, newest first', (
      tester,
    ) async {
      await _pump(tester, seated: const []);
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('RECENT')));
      expect(find.text(en.liveGiftRecentEmptyTitle), findsOneWidget);
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('POPULAR')));
      for (final code in ['rose', 'crown']) {
        await _tap(tester, _cell(code));
        await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
        await tester.pump(const Duration(seconds: 6));
      }
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('RECENT')));
      expect(_cell('crown'), findsOneWidget);
      expect(_cell('rose'), findsOneWidget);
      expect(
        tester.getCenter(_cell('crown')).dx,
        lessThan(tester.getCenter(_cell('rose')).dx),
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Price sorting: off → low to high → high to low', (
      tester,
    ) async {
      await _pump(tester);
      double x(String code) => tester.getCenter(_cell(code)).dx;
      // Catalogue order: rose 1, heart_balloon 10, crown 299, car 5000.
      await _tap(tester, find.byKey(KLiveGiftSheet.priceSortKey));
      expect(x('rose'), lessThan(x('crown')));
      await _tap(tester, find.byKey(KLiveGiftSheet.priceSortKey));
      expect(x('sports_car'), lessThan(x('crown')));
      expect(x('crown'), lessThan(x('rose')));
      await _tap(tester, find.byKey(KLiveGiftSheet.priceSortKey));
      expect(x('rose'), lessThan(x('sports_car')));
    });

    testWidgets('the quantities sit in the pill beside Send; every one is '
        'reachable on a 360 pt phone', (tester) async {
      await _pump(tester);
      final send = tester.getRect(find.byKey(KLiveGiftSheet.sendKey));
      for (final q in const [1, 10, 66, 99, 188, 520, 1314]) {
        final option = find.byKey(KLiveGiftSheet.quantityOptionKey(q));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(tester.getRect(option).right, lessThanOrEqualTo(send.left));
      }
      expect(tester.getSize(find.byKey(KLiveGiftSheet.sendKey)).height, 44);
    });
  });

  group('D132 lucky gifts', () {
    FakeLiveGiftRepository lucky({bool confirmed = true, String? reason}) {
      final repo =
          FakeLiveGiftRepository(codes: [...giftFixtureCodes, 'lucky_clover'])
            ..categories = const ['POPULAR', 'EVENT', 'FUN', 'LUCKY']
            ..ageConfirmed = confirmed;
      if (reason != null) {
        repo.odds = ({required ageConfirmed}) => luckyOddsJson(reason: reason);
      }
      return repo;
    }

    testWidgets('no Lucky tab without lucky gifts', (tester) async {
      await _pump(tester);
      expect(find.byKey(KLiveGiftSheet.tabKey('LUCKY')), findsNothing);
    });

    testWidgets('the Lucky tab, its odds, and a win shown with the balance', (
      tester,
    ) async {
      final repo = lucky()
        ..nextLucky = {
          'draws': 1,
          'wins': [
            {'multiplier': 100, 'count': 1, 'coins': 1000},
          ],
          'coinsWon': 1000,
          'topMultiplier': 100,
          'downgraded': 0,
        };
      await _pump(tester, gifts: repo, seated: const []);
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
      expect(_cell('lucky_clover'), findsOneWidget);
      await _tap(tester, find.byKey(KLiveGiftSheet.luckyOddsKey));
      expect(find.text(en.liveLuckyOddsTitle), findsOneWidget);
      expect(find.byKey(KLiveGiftSheet.oddsRowKey(500)), findsOneWidget);
      expect(find.text('0.0034%'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await _tap(tester, _cell('lucky_clover'));
      await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
      expect(repo.sends.single.source, LiveGiftSource.coins);
      expect(_toast(tester), en.liveLuckyWon('\u20681,000\u2069', '100'));
      // 1000 − 10 + 1000.
      expect(
        find.descendant(
          of: find.byKey(KLiveGiftSheet.balanceKey),
          matching: find.text('1,990'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('18+: asked once before the first lucky gift; Cancel sends '
        'nothing', (tester) async {
      final repo = lucky(confirmed: false);
      await _pump(tester, gifts: repo, seated: const []);
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
      await _tap(tester, _cell('lucky_clover'));
      await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
      expect(find.byKey(KLiveGiftSheet.ageDialogKey), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sends, isEmpty);
      await _tap(tester, find.byKey(KLiveGiftSheet.sendKey));
      await _tap(tester, find.byKey(KLiveGiftSheet.ageConfirmKey));
      expect(repo.calls, contains('confirmLuckyAge'));
      expect(repo.sends, hasLength(1));
      expect(_toast(tester), en.liveLuckyNoWin);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('not in this country: the tab says so and Send stays off', (
      tester,
    ) async {
      await _pump(
        tester,
        gifts: lucky(reason: 'REGION_UNAVAILABLE'),
        seated: const [],
      );
      await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
      expect(find.byKey(KLiveGiftSheet.luckyBlockedKey), findsOneWidget);
      expect(find.text(en.liveLuckyRegion), findsOneWidget);
      expect(_cell('lucky_clover'), findsNothing);
      expect(find.byKey(KLiveGiftSheet.luckyOddsKey), findsOneWidget);
    });
  });
}
