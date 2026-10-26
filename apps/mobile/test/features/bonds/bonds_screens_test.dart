// CP-018 screens: create a family (coins), join requests, CP requests and
// gifts, the medal showcase picker (at most 6, in order), the medals grid,
// notifications of the new types, Arabic and English, 360×800 at text
// scale 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_screen.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/create_family_screen.dart';
import 'package:kabso_live/features/families/presentation/families_screen.dart';
import 'package:kabso_live/features/families/presentation/family_screen.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/features/medals/presentation/showcase_picker_screen.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bonds/bonds_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'bonds_harness.dart';

const _familyId = '0192f1d0-8888-7000-8000-000000000002';

Family _family({FamilyRole? role, String? requestId, int members = 3}) =>
    Family.fromJson(
      familyJson(
        myRole: role?.wire,
        myRequestId: requestId,
        memberCount: members,
      ),
    );

FamilyMember _member(String username, FamilyRole role) => FamilyMember(
  user: Family.fromJson(familyJson()).leader!
      .copyWith(id: 'id-$username', username: username, displayName: username),
  role: role,
  joinedAt: DateTime.utc(2026, 10, 26),
  points: 120,
);

void main() {
  final en = l10nFor(AppLanguage.en);

  group('create a family', () {
    testWidgets('too few coins: said up front and the button is off', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.live.coins = 100;
      await pumpBonds(tester, const CreateFamilyScreen(), fakes: fakes);
      final price = en.bondsCoins(500);
      expect(find.text(en.familyCreateCost(price)), findsOneWidget);
      expect(find.text(en.bondsBalance(en.bondsCoins(100))), findsOneWidget);
      expect(find.byKey(CreateFamilyScreen.notEnoughKey), findsOneWidget);
      expect(find.text(en.familyCreateNotEnough(price)), findsOneWidget);
      await tester.enterText(find.byKey(CreateFamilyScreen.nameKey), 'Stars');
      await tester.tap(find.byKey(CreateFamilyScreen.submitKey));
      await tester.pumpAndSettle();
      expect(
        fakes.families.calls.where((c) => c.startsWith('create')),
        isEmpty,
      );
    });

    testWidgets('the server refuses for coins: nothing created, said so', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.live.coins = 600;
      fakes.families.failNext['create'] = bondFailure(
        ErrorCode.insufficientCoins,
      );
      await pumpBonds(tester, const CreateFamilyScreen(), fakes: fakes);
      expect(find.byKey(CreateFamilyScreen.notEnoughKey), findsNothing);
      await tester.enterText(find.byKey(CreateFamilyScreen.nameKey), 'Stars');
      await tester.tap(find.byKey(CreateFamilyScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateFamilyScreen.notEnoughKey), findsOneWidget);
      expect(fakes.visited, isEmpty);
    });

    testWidgets('a taken name shows on the field; a retry keeps clientId', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.live.coins = 600;
      fakes.families
        ..coinsAfterCreate = 100
        ..failNext['create'] = bondFailure(ErrorCode.familyNameTaken);
      await pumpBonds(tester, const CreateFamilyScreen(), fakes: fakes);
      await tester.enterText(find.byKey(CreateFamilyScreen.nameKey), 'S');
      await tester.tap(find.byKey(CreateFamilyScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(en.familyNameInvalid), findsOneWidget);
      await tester.enterText(find.byKey(CreateFamilyScreen.nameKey), 'Stars');
      await tester.tap(find.byKey(CreateFamilyScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(en.errorFamilyNameTaken), findsOneWidget);
      await tester.enterText(find.byKey(CreateFamilyScreen.nameKey), 'Moons');
      await tester.tap(find.byKey(CreateFamilyScreen.submitKey));
      await tester.pumpAndSettle();
      final creates = [
        for (final c in fakes.families.calls)
          if (c.startsWith('create')) c.split(':'),
      ];
      expect(creates, hasLength(2));
      // The same attempt: the same clientId.
      expect(creates[0][2], creates[1][2]);
      expect(fakes.visited, ['/families/$_familyId']);
    });
  });

  group('a family page', () {
    testWidgets('ask to join, then the request can be cancelled', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family()
        ..memberList = [_member('sara', FamilyRole.leader)];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.text('عائلة النجوم'), findsWidgets);
      expect(find.text('48213907'), findsOneWidget);
      expect(find.text('500 / 1,000'), findsOneWidget);
      expect(find.text(en.familyToReach(2)), findsOneWidget);
      // Not a leader or deputy: no join requests tool.
      expect(find.byKey(FamilyScreen.requestsToolKey), findsNothing);
      await tester.tap(find.byKey(FamilyScreen.joinKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('join:$_familyId'));
      expect(find.text(en.familyJoinSent), findsOneWidget);
      expect(find.byKey(FamilyScreen.cancelKey), findsOneWidget);
      await tester.tap(find.byKey(FamilyScreen.cancelKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('cancelMyRequest'));
      expect(find.byKey(FamilyScreen.joinKey), findsOneWidget);
    });

    testWidgets('a pending request elsewhere: offered to cancel it first', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family()
        ..failNext['join'] = bondFailure(ErrorCode.familyRequestPending);
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      await tester.tap(find.byKey(FamilyScreen.joinKey));
      await tester.pumpAndSettle();
      expect(find.text(en.errorFamilyRequestPending), findsOneWidget);
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(
        fakes.families.calls.where(
          (c) => c.startsWith('join') || c == 'cancelMyRequest',
        ),
        ['join:$_familyId', 'cancelMyRequest', 'join:$_familyId'],
      );
    });

    testWidgets('the leader accepts a join request; members show roles', (
      tester,
    ) async {
      // A tall phone: the members list sits below the header.
      tester.view
        ..physicalSize = const Size(1179, 2556)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family(role: FamilyRole.leader)
        ..memberList = [
          _member('sara', FamilyRole.leader),
          _member('huda', FamilyRole.deputy),
        ]
        ..requests = [
          FamilyJoinRequest.fromJson(familyJoinRequestJson(id: 'r1')),
        ];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.text(en.familyRoleLeader), findsOneWidget);
      expect(find.text(en.familyRoleDeputy), findsOneWidget);
      // The leader manages others, never themselves.
      await tester.tap(find.byKey(FamilyScreen.memberMenuKey('huda')));
      await tester.pumpAndSettle();
      expect(find.text(en.familyTransfer), findsOneWidget);
      expect(find.text(en.familyChatMute), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyScreen.memberMenuKey('sara')));
      await tester.pumpAndSettle();
      expect(find.text(en.familyTransfer), findsNothing);
      expect(find.text(en.familyViewProfile), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      // The leader does not leave.
      await tester.tap(find.byKey(FamilyScreen.manageKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyScreen.leaveKey), findsNothing);
      expect(find.byKey(FamilyScreen.disbandKey), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      // Join requests open from the tool tile.
      await tester.tap(find.byKey(FamilyScreen.requestsToolKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyScreen.requestsKey), findsOneWidget);
      await tester.tap(find.byKey(FamilyScreen.acceptKey('r1')));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('accept:r1'));
      expect(find.text(en.familyAccepted('Omar')), findsOneWidget);
      expect(find.text(en.familyRequestsEmpty), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyScreen.memberKey('omar')), findsOneWidget);
    });

    testWidgets('a member leaves after confirming', (tester) async {
      final fakes = BondFakes();
      fakes.families.byId[_familyId] = _family(role: FamilyRole.member);
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      await tester.tap(find.byKey(FamilyScreen.manageKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyScreen.leaveKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('leave:$_familyId'));
    });

    testWidgets('a missing family says so', (tester) async {
      await pumpBonds(tester, const FamilyScreen(familyId: 'gone'));
      expect(find.byKey(FamilyScreen.notFoundKey), findsOneWidget);
    });
  });

  testWidgets('families: your family or Create, the list, empty search', (
    tester,
  ) async {
    final fakes = await pumpBonds(tester, const FamiliesScreen());
    expect(find.byKey(FamiliesScreen.createKey), findsOneWidget);
    // No family on the board yet: says so.
    expect(find.byKey(FamiliesScreen.emptyKey), findsOneWidget);
    expect(find.text(en.familiesBoardEmpty), findsOneWidget);
    // Searching lists the matches with Join.
    await tester.enterText(find.byKey(FamiliesScreen.searchKey), 'النجوم');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(FamiliesScreen.tileKey(_familyId)), findsOneWidget);
    expect(find.byKey(FamiliesScreen.joinKey(_familyId)), findsOneWidget);
    await tester.enterText(find.byKey(FamiliesScreen.searchKey), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(FamiliesScreen.emptyKey), findsOneWidget);
    expect(find.text(en.familiesNoMatch), findsOneWidget);
    await tester.enterText(find.byKey(FamiliesScreen.searchKey), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FamiliesScreen.createKey));
    await tester.pumpAndSettle();
    expect(fakes.visited, ['/families/new']);
  });

  group('CP', () {
    testWidgets('accept an incoming request: the couple shows', (tester) async {
      final fakes = BondFakes();
      fakes.cp.incoming = [CpRequest.fromJson(cpRequestJson(id: 'r1'))];
      await pumpBonds(tester, const CpScreen(), fakes: fakes);
      expect(find.byKey(CpScreen.noneKey), findsOneWidget);
      expect(find.text(en.cpRequestFrom('سارة')), findsOneWidget);
      await tester.tap(find.byKey(CpScreen.acceptKey('r1')));
      await tester.pumpAndSettle();
      expect(fakes.cp.calls, contains('accept:r1'));
      expect(find.byKey(CpScreen.coupleKey), findsOneWidget);
      expect(find.text('Silver couple'), findsOneWidget);
      // CP-021 added "Open CP space" to the couple: the list is further down.
      await tester.scrollUntilVisible(find.text(en.cpIncomingEmpty), 200);
      expect(find.text(en.cpIncomingEmpty), findsOneWidget);
      expect(find.byKey(CpScreen.spaceKey), findsOneWidget);
    });

    testWidgets('cancel a sent request (refund) and decline one', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.cp
        ..incoming = [CpRequest.fromJson(cpRequestJson(id: 'in1'))]
        ..outgoing = [CpRequest.fromJson(cpRequestJson(id: 'out1'))];
      await pumpBonds(tester, const CpScreen(), fakes: fakes);
      await tester.tap(find.byKey(CpScreen.declineKey('in1')));
      await tester.pumpAndSettle();
      expect(fakes.cp.calls, contains('decline:in1'));
      await tester.tap(find.byKey(CpScreen.outgoingKey));
      await tester.pumpAndSettle();
      expect(find.text(en.cpRequestTo('ليلى')), findsOneWidget);
      await tester.tap(find.byKey(CpScreen.cancelKey('out1')));
      await tester.pumpAndSettle();
      expect(fakes.cp.calls, contains('cancel:out1'));
      expect(find.text(en.cpCancelled), findsOneWidget);
    });

    testWidgets('a gift from the preset amounts, after confirming', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.cp.couple = CpCouple.fromJson(cpCoupleJson());
      await pumpBonds(tester, const CpScreen(), fakes: fakes);
      for (final amount in [10, 52, 99, 520, 1314]) {
        expect(find.byKey(CpScreen.giftKey(amount)), findsOneWidget);
      }
      expect(find.text(en.cpDay(7)), findsNothing); // joined with the date
      expect(find.textContaining(en.cpDay(7)), findsOneWidget);
      await tester.ensureVisible(find.byKey(CpScreen.giftKey(52)));
      await tester.tap(find.byKey(CpScreen.giftKey(52)));
      await tester.pumpAndSettle();
      expect(
        find.text(en.cpGiftConfirmTitle(en.bondsCoins(52))),
        findsOneWidget,
      );
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(
        fakes.cp.calls.where((c) => c.startsWith('gift:52:')),
        hasLength(1),
      );
      expect(find.text(en.cpGiftSent('52')), findsOneWidget);
    });

    testWidgets('a gift without enough coins says so', (tester) async {
      final fakes = BondFakes();
      fakes.cp
        ..couple = CpCouple.fromJson(cpCoupleJson())
        ..failNext['gift'] = bondFailure(ErrorCode.insufficientCoins);
      await pumpBonds(tester, const CpScreen(), fakes: fakes);
      await tester.ensureVisible(find.byKey(CpScreen.giftKey(1314)));
      await tester.tap(find.byKey(CpScreen.giftKey(1314)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(find.text(en.cpGiftNotEnough), findsOneWidget);
    });
  });

  group('medal showcase picker', () {
    testWidgets('at most 6, kept in the order chosen, saved with PUT', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals.medals = testMedals(owned: 8);
      await pumpBonds(tester, const ShowcasePickerScreen(), fakes: fakes);
      // Only earned medals are offered.
      expect(find.byKey(ShowcasePicker.optionKey('M8')), findsNothing);
      for (final code in ['M5', 'M0', 'M3', 'M7', 'M1', 'M2', 'M4']) {
        await tester.scrollUntilVisible(
          find.byKey(ShowcasePicker.optionKey(code)),
          100,
        );
        await tester.tap(find.byKey(ShowcasePicker.optionKey(code)));
        await tester.pump();
      }
      // The 7th was refused.
      expect(find.text(en.medalsShowcaseLimit(6)), findsOneWidget);
      expect(find.text(en.medalsShowcaseCount(6, 6)), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShowcasePicker.saveKey));
      await tester.pumpAndSettle();
      expect(fakes.medals.calls, contains('setShowcase:M5,M0,M3,M7,M1,M2'));
    });

    testWidgets('starts from the saved order; taking one out moves the rest', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.medals
        ..medals = testMedals(owned: 4)
        ..chosen = [
          const ProfileMedal(code: 'M2', name: 'M2', iconKey: 'k'),
          const ProfileMedal(code: 'M0', name: 'M0', iconKey: 'k'),
        ];
      await pumpBonds(tester, const ShowcasePickerScreen(), fakes: fakes);
      final m2 = tester.getCenter(
        find.byKey(ShowcasePicker.chosenItemKey('M2')),
      );
      final m0 = tester.getCenter(
        find.byKey(ShowcasePicker.chosenItemKey('M0')),
      );
      expect(m2.dx, lessThan(m0.dx)); // LTR: first on the left
      await tester.tap(find.byKey(ShowcasePicker.chosenItemKey('M2')));
      await tester.pump();
      await tester.tap(find.byKey(ShowcasePicker.optionKey('M2')));
      await tester.pump();
      await tester.tap(find.byKey(ShowcasePicker.saveKey));
      await tester.pumpAndSettle();
      expect(fakes.medals.calls, contains('setShowcase:M0,M2'));
    });

    testWidgets('nothing earned: says so, nothing to choose', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = testMedals(owned: 0);
      await pumpBonds(tester, const ShowcasePickerScreen(), fakes: fakes);
      expect(find.text(en.medalsShowcaseNoneEarned), findsOneWidget);
    });
  });

  testWidgets('medals grid: earned and locked, Choose opens the picker', (
    tester,
  ) async {
    final fakes = BondFakes();
    fakes.medals.medals = testMedals(owned: 2, total: 4);
    await pumpBonds(tester, const MedalsScreen(), fakes: fakes);
    expect(find.text(en.medalsOwned(2, 4)), findsOneWidget);
    expect(find.bySemanticsLabel('Medal 0'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Medal 3, ${en.medalsLocked}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(MedalsScreen.chooseKey));
    await tester.pumpAndSettle();
    expect(fakes.visited, ['/medals/showcase']);
  });

  group('notifications of CP-018', () {
    AppNotification n(
      String type,
      Map<String, Object?>? target, {
      bool actor = true,
    }) => AppNotification.fromJson({
      'id': 'n-$type',
      'type': type,
      'actors': [if (actor) bondUserJson(displayName: 'Sara')],
      'actorCount': actor ? 1 : 0,
      'target': target,
      'createdAt': '2026-10-26T18:30:00.000Z',
      'read': false,
    });

    testWidgets('sentences and where a tap goes', (tester) async {
      final fakes = BondFakes();
      fakes.medals.medals = [
        Medal.fromJson(medalJson('FIRST_CP', name: 'First couple')),
      ];
      final items = [
        n('CP_REQUEST', {
          'type': 'USER',
          'id': 'sara',
          'postId': null,
          'thumbUrl': null,
          'text': null,
        }),
        n('CP_ACCEPTED', {
          'type': 'USER',
          'id': 'sara',
          'postId': null,
          'thumbUrl': null,
          'text': null,
        }),
        n('FAMILY_JOIN_ACCEPTED', {
          'type': 'FAMILY',
          'id': 'f1',
          'postId': null,
          'thumbUrl': null,
          'text': 'Stars',
        }),
        n('FAMILY_JOIN_DECLINED', {
          'type': 'FAMILY',
          'id': 'f1',
          'postId': null,
          'thumbUrl': null,
          'text': 'Stars',
        }),
        n('MEDAL_AWARDED', {
          'type': 'MEDAL',
          'id': 'FIRST_CP',
          'postId': null,
          'thumbUrl': null,
          'text': null,
        }, actor: false),
      ];
      expect(items.map((i) => i.type), [
        NotificationType.cpRequest,
        NotificationType.cpAccepted,
        NotificationType.familyJoinAccepted,
        NotificationType.familyJoinDeclined,
        NotificationType.medalAwarded,
      ]);
      expect(items.map((i) => NotificationRow(item: i).routeTo()), [
        '/cp',
        '/cp',
        '/families/f1',
        '/families/f1',
        '/medals',
      ]);
      await pumpBonds(
        tester,
        Scaffold(
          body: ListView(
            children: [for (final i in items) NotificationRow(item: i)],
          ),
        ),
        fakes: fakes,
      );
      String plain(String s) => s.replaceAll(RegExp('[\u2066-\u2069]'), '');
      final texts = [
        for (final w in tester.widgetList<RichText>(find.byType(RichText)))
          plain(w.text.toPlainText()),
      ];
      final who = plain(en.notifActors('Sara', 0));
      expect(texts, contains(plain(en.notifCpRequest(who))));
      expect(texts, contains(plain(en.notifCpAccepted(who))));
      expect(texts, contains(plain(en.notifFamilyJoinAccepted('Stars'))));
      expect(texts, contains(plain(en.notifFamilyJoinDeclined('Stars'))));
      expect(texts, contains(plain(en.notifMedalAwarded('First couple'))));
      expect(tester.takeException(), isNull);
    });

    test('unknown types and targets do not fail the page', () {
      final item = n('SOMETHING_NEW', {
        'type': 'GROUP',
        'id': 'x',
        'postId': null,
        'thumbUrl': null,
        'text': null,
      });
      expect(item.type, NotificationType.unknown);
      expect(item.target, isNull);
      expect(NotificationRow(item: item).routeTo(), isNull);
    });
  });

  group('Arabic and English at 360×800, text scale 2', () {
    Future<void> each(
      WidgetTester tester,
      Widget screen,
      void Function(BondFakes) setUp,
    ) async {
      setViewport(tester, GoldenViewport.android);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in AppLanguage.values) {
        final fakes = BondFakes();
        setUp(fakes);
        await pumpBonds(tester, screen, language: language, fakes: fakes);
        expect(tester.takeException(), isNull, reason: language.name);
        final dir = Directionality.of(
          tester.element(find.byType(Scaffold).first),
        );
        expect(
          dir,
          language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }

    testWidgets('family page (leader, requests, members)', (tester) async {
      await each(tester, const FamilyScreen(familyId: _familyId), (f) {
        f.families
          ..byId[_familyId] = _family(role: FamilyRole.leader)
          ..memberList = [
            _member('sara', FamilyRole.leader),
            _member('huda', FamilyRole.deputy),
          ]
          ..requests = [FamilyJoinRequest.fromJson(familyJoinRequestJson())];
      });
    });

    testWidgets('families list', (tester) async {
      await each(tester, const FamiliesScreen(), (_) {});
    });

    testWidgets('create a family (too few coins)', (tester) async {
      await each(tester, const CreateFamilyScreen(), (f) => f.live.coins = 1);
    });

    testWidgets('CP with a couple and requests', (tester) async {
      await each(tester, const CpScreen(), (f) {
        f.cp
          ..couple = CpCouple.fromJson(cpCoupleJson())
          ..incoming = [CpRequest.fromJson(cpRequestJson())];
      });
    });

    testWidgets('medals and the showcase picker', (tester) async {
      await each(
        tester,
        const MedalsScreen(),
        (f) => f.medals.medals = testMedals(owned: 3),
      );
      await each(
        tester,
        const ShowcasePickerScreen(),
        (f) => f.medals.medals = testMedals(owned: 7),
      );
    });
  });
}
