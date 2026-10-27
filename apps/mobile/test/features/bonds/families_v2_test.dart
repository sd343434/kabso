// CP-022 (D116): the families list (boards, podium, rows, Join, the pinned
// rank, "Soon" battles), the family page (hero, tools, tabs: members with
// presence, contributions, ranking; invite, chat), the family chat (send,
// muted, members only, delete, report), Arabic and English at 393×852 and
// 360×800 with text scale 1.3 and 2.
// D125: the owner's podium cards (emblem in each card's circle, the place,
// name, level, points and Join in its panel) and the default hero art.
// D127: the owner's own mockup, literally: rows left to right in both
// directions, the activity card, the podium backdrop, the hero layout
// (level chip left, number box right, emblem over the sheet's edge).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/families_screen.dart';
import 'package:kabso_live/features/families/presentation/family_chat_screen.dart';
import 'package:kabso_live/features/families/presentation/family_screen.dart';
import 'package:kabso_live/features/families/presentation/family_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bonds/bonds_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/pump_app.dart';
import 'bonds_harness.dart';

const _familyId = '0192f1d0-8888-7000-8000-000000000002';

/// Six families on the prestige board; the caller's family 9th.
FamilyRankings _board({String board = 'PRESTIGE', bool me = true}) =>
    FamilyRankings.fromJson(
      familyRankingsJson(
        board: board,
        entries: [
          for (var i = 0; i < 6; i++)
            (
              familyCardJson(
                id: 'fam-$i',
                name: 'Family $i',
                number: 10000000 + i,
                memberCount: 411 - i,
                level: 5 - (i ~/ 2),
              ),
              56540000 - i * 1000000,
            ),
        ],
        me: me ? {'family': familyCardJson(), 'rank': 9, 'score': 1200} : null,
      ),
    );

FamilyMember _member(
  String username,
  String role, {
  int points = 100,
  int? rank,
  bool online = true,
  bool hidden = false,
  bool? muted,
}) => FamilyMember.fromJson(
  familyMemberJson(
    user: bondUserJson(
      id: 'id-$username',
      username: username,
      displayName: username,
    ),
    role: role,
    points: points,
    rank: rank,
    chatMuted: muted,
    presence: hidden
        ? null
        : familyPresenceJson(
            online: online,
            lastActiveAt: online
                ? DateTime.now().toUtc().toIso8601String()
                : DateTime.now()
                      .subtract(const Duration(minutes: 10))
                      .toUtc()
                      .toIso8601String(),
          ),
  ),
);

Family _family({
  String? role = 'LEADER',
  int pending = 3,
  int members = 12400,
}) => Family.fromJson({
  ...familyJson(myRole: role, memberCount: members),
  'tagline': 'عائلة عالمية · ترفيه · بث مباشر',
  'pendingRequestCount': role == 'LEADER' || role == 'DEPUTY' ? pending : null,
});

void _tall(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1179, 2556)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Records what the app puts on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  final en = l10nFor(AppLanguage.en);

  group('families list', () {
    testWidgets('prestige board: podium 2-1-3, ranked rows, Join, my rank', (
      tester,
    ) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..boards[FamilyRankingBoard.prestige] = _board()
        ..byId['fam-3'] = Family.fromJson(
          familyJson(id: 'fam-3', myRole: null),
        );
      await pumpBonds(tester, const FamiliesScreen(), fakes: fakes);
      expect(fakes.families.calls, contains('rankings:PRESTIGE'));
      expect(find.byKey(FamiliesScreen.podiumKey), findsOneWidget);
      double x(int place) =>
          tester.getCenter(find.byKey(FamiliesScreen.podiumSlotKey(place))).dx;
      expect(x(2), lessThan(x(1)));
      expect(x(1), lessThan(x(3)));
      // The first place card is the largest.
      expect(
        tester.getSize(find.byKey(FamiliesScreen.podiumSlotKey(1))).width,
        greaterThan(
          tester.getSize(find.byKey(FamiliesScreen.podiumSlotKey(2))).width,
        ),
      );
      expect(find.text('Family 0'), findsOneWidget);
      // Rows from 4th on, with the month's points and members.
      expect(find.byKey(FamiliesScreen.tileKey('fam-3')), findsOneWidget);
      expect(find.text(en.familiesMonthPointsLabel), findsWidgets);
      expect(find.text('53.5M'), findsOneWidget);
      expect(find.text(en.familiesRowMembers(408, 500)), findsOneWidget);
      // The caller's family is pinned at the bottom.
      expect(find.byKey(FamiliesScreen.myRankKey), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      // Join from a row.
      await tester.ensureVisible(find.byKey(FamiliesScreen.joinKey('fam-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamiliesScreen.joinKey('fam-3')));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('join:fam-3'));
      expect(find.text(en.familyJoinSent), findsOneWidget);
    });

    testWidgets('most active board; battles are "Soon" and do nothing', (
      tester,
    ) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..boards[FamilyRankingBoard.prestige] = _board()
        ..boards[FamilyRankingBoard.active] = _board(board: 'ACTIVE');
      await pumpBonds(tester, const FamiliesScreen(), fakes: fakes);
      expect(find.text(en.familySoon), findsOneWidget);
      await tester.tap(find.byKey(FamiliesScreen.battleTabKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls.where((c) => c.startsWith('rankings')), [
        'rankings:PRESTIGE',
      ]);
      expect(
        tester.getSemantics(find.byKey(FamiliesScreen.battleTabKey)).label,
        en.familiesSoonLabel(en.familiesTabBattle),
      );
      await tester.tap(
        find.byKey(FamiliesScreen.tabKey(FamilyRankingBoard.active)),
      );
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('rankings:ACTIVE'));
      expect(find.text(en.familiesActiveLabel), findsWidgets);
      expect(find.text('53.5M'), findsOneWidget);
    });

    testWidgets('a member of a family sees no Join buttons', (tester) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..myFamily = _family()
        ..boards[FamilyRankingBoard.prestige] = _board();
      await pumpBonds(tester, const FamiliesScreen(), fakes: fakes);
      expect(find.byKey(FamiliesScreen.mineKey), findsOneWidget);
      expect(find.byKey(FamiliesScreen.joinKey('fam-3')), findsNothing);
      expect(find.byKey(FamiliesScreen.joinKey('fam-0')), findsNothing);
    });
  });

  group('family page', () {
    testWidgets('hero, tools, members by points with presence, invite', (
      tester,
    ) async {
      _tall(tester);
      final copied = _clipboard(tester);
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family()
        ..memberList = [
          _member('oz', 'LEADER', points: 500, rank: 1),
          _member('lina', 'DEPUTY', points: 420, rank: 2, online: false),
          _member('sami', 'MEMBER', points: 320, rank: 3, hidden: true),
          _member('maya', 'MEMBER', points: 280, rank: 4, muted: true),
        ];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.text(en.familyLevelLong(1)), findsWidgets);
      // D127: the number box (label and digits) at the hero's top right.
      expect(find.text(en.familyNumberLabel), findsOneWidget);
      expect(find.text('48213907'), findsOneWidget);
      expect(find.text('عائلة عالمية · ترفيه · بث مباشر'), findsOneWidget);
      expect(find.text('12.4K'), findsOneWidget);
      // Members by points, with medals and presence.
      expect(fakes.families.calls, contains('members:$_familyId:points'));
      expect(find.byType(FamilyRankMedal), findsNWidgets(4));
      expect(find.text(en.familyOnlineNow), findsNWidgets(2));
      expect(find.text(en.relativeMinutesAgo(10)), findsOneWidget);
      // Tools: requests with the count; three "Soon" tiles.
      expect(find.byKey(FamilyScreen.requestsToolKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(FamilyScreen.requestsToolKey),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.byType(FamilySoonBadge),
        findsNWidgets(4),
      ); // 3 tools + events
      // Search members.
      await tester.enterText(find.byKey(FamilyScreen.memberSearchKey), 'li');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('members:$_familyId:points:q=li'));
      expect(find.byKey(FamilyScreen.memberKey('lina')), findsOneWidget);
      expect(find.byKey(FamilyScreen.memberKey('oz')), findsNothing);
      // Invite copies the family's name and number.
      await tester.tap(find.byKey(FamilyScreen.inviteKey));
      await tester.pumpAndSettle();
      expect(copied.single, en.familyInviteText('عائلة النجوم', '48213907'));
      expect(find.text(en.familyInviteCopied), findsOneWidget);
      // Message the family opens the chat.
      await tester.tap(find.byKey(FamilyScreen.chatKey));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/families/$_familyId/chat']);
    });

    testWidgets('contributions and ranking tabs; events is not a tab', (
      tester,
    ) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family(role: 'MEMBER')
        ..contributionList = [
          FamilyContribution.fromJson(
            familyContributionJson(
              user: bondUserJson(id: 'u1', username: 'oz'),
              role: 'LEADER',
              points: 900,
            ),
          ),
          FamilyContribution.fromJson(
            familyContributionJson(
              rank: 2,
              user: bondUserJson(id: 'u2', username: 'lina'),
              points: 400,
            ),
          ),
        ];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      // A member has no manage or requests tools.
      expect(find.byKey(FamilyScreen.requestsToolKey), findsNothing);
      expect(find.byKey(FamilyScreen.manageToolKey), findsNothing);
      expect(find.byKey(FamilyScreen.tabKey(1)), findsNothing);
      await tester.tap(find.byKey(FamilyScreen.tabKey(2)));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('contributions:$_familyId'));
      expect(find.byKey(FamilyScreen.contributionKey('oz')), findsOneWidget);
      expect(find.text(en.familyPoints('900')), findsOneWidget);
      await tester.tap(find.byKey(FamilyScreen.tabKey(3)));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyScreen.standingKey), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('#12'), findsOneWidget);
    });

    testWidgets('the leader sets the tagline and mutes a member in chat', (
      tester,
    ) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family()
        ..memberList = [
          _member('oz', 'LEADER', rank: 1),
          _member('maya', 'MEMBER', rank: 2, muted: false),
        ];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      await tester.tap(find.byKey(FamilyScreen.manageKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.familyTaglineTitle).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(FamilyScreen.taglineKey), 'Fun · Live');
      await tester.tap(find.text(en.familySave));
      await tester.pumpAndSettle();
      expect(
        fakes.families.calls,
        contains('updateLook:$_familyId::Fun · Live'),
      );
      await tester.tap(find.byKey(FamilyScreen.memberMenuKey('maya')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.familyChatMute));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('chatMute:maya:true'));
    });

    testWidgets('someone outside asks to join from the bottom bar', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.families.byId[_familyId] = _family(role: null, members: 3);
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.byKey(FamilyScreen.chatKey), findsNothing);
      await tester.tap(find.byKey(FamilyScreen.joinKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('join:$_familyId'));
    });
  });

  group('family chat', () {
    setUp(() => FamilyChatScreen.pollEvery = const Duration(days: 1));

    testWidgets('reads, sends, deletes own and reports others', (tester) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family(role: 'MEMBER')
        ..chatMessages = [
          FamilyChatMessage.fromJson(
            familyChatMessageJson(id: 'm1', text: 'hello family'),
          ),
        ];
      await pumpBonds(
        tester,
        const FamilyChatScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.text('hello family'), findsOneWidget);
      await tester.enterText(find.byKey(FamilyChatScreen.inputKey), ' hi all ');
      await tester.tap(find.byKey(FamilyChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('sendChat:hi all'));
      expect(find.text('hi all'), findsOneWidget);
      // Own message: delete.
      await tester.longPress(find.text('hi all'));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyChatScreen.reportKey), findsNothing);
      await tester.tap(find.byKey(FamilyChatScreen.deleteKey));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('deleteChat:sent-1'));
      expect(find.text('hi all'), findsNothing);
      // Someone else's: report (a member cannot delete it).
      await tester.longPress(find.text('hello family'));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyChatScreen.deleteKey), findsNothing);
      await tester.tap(find.byKey(FamilyChatScreen.reportKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(fakes.families.calls, contains('reportChat:m1:SPAM'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a muted member reads only; a refused send turns it off', (
      tester,
    ) async {
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family(role: 'MEMBER')
        ..chatMuted = true;
      await pumpBonds(
        tester,
        const FamilyChatScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.byKey(FamilyChatScreen.mutedKey), findsOneWidget);
      expect(find.byKey(FamilyChatScreen.inputKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final again = BondFakes();
      again.families
        ..byId[_familyId] = _family(role: 'MEMBER')
        ..failNext['sendChat'] = bondFailure(
          ErrorCode.familyChatMuted,
          status: 403,
        );
      await pumpBonds(
        tester,
        const FamilyChatScreen(familyId: _familyId),
        fakes: again,
      );
      await tester.enterText(find.byKey(FamilyChatScreen.inputKey), 'hi');
      await tester.tap(find.byKey(FamilyChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FamilyChatScreen.mutedKey), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('not a member: says the chat is for members', (tester) async {
      final fakes = BondFakes();
      fakes.families
        ..byId[_familyId] = _family(role: null)
        ..failNext['chat'] = bondFailure(ErrorCode.authForbidden, status: 403);
      await pumpBonds(
        tester,
        const FamilyChatScreen(familyId: _familyId),
        fakes: fakes,
      );
      expect(find.byKey(FamilyChatScreen.notMemberKey), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('D125 family art', () {
    Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

    testWidgets('podium: the three owner cards, 1st centred and larger, the '
        'emblem inside each circle, place / name / level / points and Join '
        'inside the panel; a tap opens the family', (tester) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families.boards[FamilyRankingBoard.prestige] = _board();
      await pumpBonds(tester, const FamiliesScreen(), fakes: fakes);
      for (var place = 1; place <= 3; place++) {
        final slot = find.byKey(FamiliesScreen.podiumSlotKey(place));
        final art = FamilyArt.podiumCards[place - 1];
        final image = find.descendant(
          of: slot,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == art.asset,
          ),
        );
        expect(image, findsOneWidget, reason: '$place');
        final card = rectOf(tester, slot);
        // The card keeps the art's aspect.
        expect(
          card.height / card.width,
          closeTo(art.size.height / art.size.width, 0.01),
        );
        final drawn = card;
        final circle = art.map(
          Rect.fromCircle(center: art.circleCentre, radius: art.circleRadius),
          drawn,
        );
        final emblem = rectOf(
          tester,
          find.descendant(of: slot, matching: find.byType(FamilyEmblem)),
        );
        expect(emblem.center.dx, closeTo(circle.center.dx, 0.5));
        expect(emblem.center.dy, closeTo(circle.center.dy, 0.5));
        final panel = art.map(art.panel, drawn).inflate(0.5);
        // The place badge sits on the circle's lower edge.
        final placeBadge = rectOf(
          tester,
          find.byKey(FamiliesScreen.podiumPlaceKey(place)),
        );
        expect(placeBadge.center.dx, closeTo(circle.center.dx, 0.5));
        expect(placeBadge.center.dy, closeTo(circle.bottom - 2, 1));
        final name = rectOf(
          tester,
          find.descendant(of: slot, matching: find.text('Family ${place - 1}')),
        );
        expect(panel.contains(name.center), isTrue);
        final join = rectOf(
          tester,
          find.byKey(FamiliesScreen.joinKey('fam-${place - 1}')),
        );
        expect(join.top, closeTo(panel.bottom - 0.5 - 10, 1.5));
      }
      // CTO review: readable sizes, nothing scaled below them at scale 1.
      for (var i = 0; i < 3; i++) {
        final name = find.text('Family $i');
        final style = tester.widget<Text>(name).style!;
        expect(style.fontSize, greaterThanOrEqualTo(13));
        expect(style.fontWeight, FontWeight.w800);
        // Not shrunk by a FittedBox: on screen the line is full height.
        expect(
          tester.getRect(name).height,
          greaterThanOrEqualTo(13 * 1.15 - 0.01),
          reason: 'Family $i',
        );
        final level = find.descendant(
          of: find.byKey(FamiliesScreen.podiumSlotKey(i + 1)),
          matching: find.text(en.familyLevelLong(5 - (i ~/ 2))),
        );
        expect(
          tester.widget<Text>(level).style!.fontSize,
          greaterThanOrEqualTo(11),
        );
        expect(
          tester.getSize(find.byKey(FamiliesScreen.joinKey('fam-$i'))).width,
          greaterThanOrEqualTo(28),
        );
        expect(
          tester
              .getSize(find.byKey(FamiliesScreen.podiumPlaceKey(i + 1)))
              .width,
          greaterThanOrEqualTo(24),
        );
      }
      // D127: the cards stand inside the warm backdrop (10 pt gutters),
      // the side cards' centres 125/373 of it from the middle.
      final podium = rectOf(tester, find.byKey(FamiliesScreen.podiumKey));
      expect(podium.left, 0);
      expect(podium.right, 393);
      final c2 = rectOf(tester, find.byKey(FamiliesScreen.podiumSlotKey(2)));
      final c3 = rectOf(tester, find.byKey(FamiliesScreen.podiumSlotKey(3)));
      // Only the wing tips reach into the gutters.
      expect(c2.left, greaterThan(0));
      expect(c3.right, lessThan(393));
      expect(c2.center.dx, closeTo(196.5 - 120, 0.5));
      expect(c3.center.dx, closeTo(196.5 + 120, 0.5));
      final first = rectOf(tester, find.byKey(FamiliesScreen.podiumSlotKey(1)));
      final second = rectOf(
        tester,
        find.byKey(FamiliesScreen.podiumSlotKey(2)),
      );
      expect(first.top, lessThan(second.top));
      expect(first.bottom, closeTo(second.bottom, 0.5));
      await tester.tap(find.text('Family 0'));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/families/fam-0']);
    });

    testWidgets('family page without a cover (D127): the owner art at full '
        'bleed with the emblem in its gold ring (never mirrored), the level '
        'chip top left, the number box top right, the emblem over the '
        "sheet's edge on the left and the members on the right", (
      tester,
    ) async {
      for (final language in AppLanguage.values) {
        _tall(tester);
        final fakes = BondFakes();
        fakes.families.byId[_familyId] = _family();
        await pumpBonds(
          tester,
          const FamilyScreen(familyId: _familyId),
          fakes: fakes,
          language: language,
        );
        final art = rectOf(tester, find.byKey(FamilyScreen.heroArtKey));
        // The crest (x 1340 of 1860) centred, the right edges together.
        expect(art.right, closeTo(393, 0.5));
        expect(art.left + 1340 * art.width / 1860, closeTo(196.5, 0.5));
        // The art's ring stays empty (owner: one emblem on the page).
        expect(find.byKey(FamilyScreen.heroEmblemKey), findsNothing);
        final chip = rectOf(tester, find.byType(FamilyLevelCrownChip));
        final number = rectOf(tester, find.byKey(FamilyScreen.numberKey));
        expect(chip.left, 14);
        expect(number.right, 393 - 13);
        expect(chip.top, closeTo(55, 0.5));
        // The emblem in its ring on the sheet's edge (left, both
        // directions), the name beside it, the members on the right.
        expect(find.byType(FamilyEmblem), findsOneWidget);
        final name = rectOf(tester, find.text('عائلة النجوم'));
        expect(name.left, closeTo(91, 0.5));
        final members = rectOf(
          tester,
          find.byKey(FamilyScreen.membersCountKey),
        );
        expect(members.right, closeTo(393 - 13, 0.5));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('D127: in Arabic the rows still run left to right (place, '
        'emblem, text, Join; medal, avatar, name, presence, menu); the tools '
        'and tabs follow the reading order', (tester) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families
        ..boards[FamilyRankingBoard.prestige] = _board()
        ..boards[FamilyRankingBoard.active] = _board(board: 'ACTIVE');
      await pumpBonds(
        tester,
        const FamiliesScreen(),
        fakes: fakes,
        language: AppLanguage.ar,
      );
      final row = find.byKey(FamiliesScreen.tileKey('fam-3'));
      final rank = rectOf(
        tester,
        find.descendant(of: row, matching: find.text('4')),
      );
      final join = rectOf(tester, find.byKey(FamiliesScreen.joinKey('fam-3')));
      expect(rank.center.dx, lessThan(40));
      expect(join.right, greaterThan(370));
      // The board pills: prestige on the left in both directions.
      expect(
        rectOf(
          tester,
          find.byKey(FamiliesScreen.tabKey(FamilyRankingBoard.prestige)),
        ).left,
        10,
      );
      // The activity card opens the prestige board.
      await tester.tap(
        find.byKey(FamiliesScreen.tabKey(FamilyRankingBoard.active)),
      );
      await tester.pumpAndSettle();
      final ar = l10nFor(AppLanguage.ar);
      expect(find.text(ar.familiesActiveLabel), findsWidgets);
      await tester.tap(find.byKey(FamiliesScreen.activityMonthlyKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.familiesMonthPointsLabel), findsWidgets);
      expect(find.text(ar.familiesActiveLabel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final page = BondFakes();
      page.families
        ..byId[_familyId] = _family()
        ..memberList = [_member('oz', 'LEADER', points: 500, rank: 1)];
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: page,
        language: AppLanguage.ar,
      );
      final member = find.byKey(FamilyScreen.memberKey('oz'));
      final medal = rectOf(
        tester,
        find.descendant(of: member, matching: find.byType(FamilyRankMedal)),
      );
      final menu = rectOf(tester, find.byKey(FamilyScreen.memberMenuKey('oz')));
      expect(medal.left, lessThan(20));
      expect(menu.right, greaterThan(385));
      // Tools in reading order: manage first, on the right in Arabic.
      final manage = rectOf(tester, find.byKey(FamilyScreen.manageToolKey));
      final requests = rectOf(tester, find.byKey(FamilyScreen.requestsToolKey));
      expect(manage.left, greaterThan(requests.left));
      expect(manage.right, closeTo(393 - 12, 0.5));
      // Message on the left, Invite on the right, in both directions.
      final chat = rectOf(tester, find.byKey(FamilyScreen.chatKey));
      final invite = rectOf(tester, find.byKey(FamilyScreen.inviteKey));
      expect(chat.left, 12);
      expect(chat.width, 146);
      expect(invite.left, greaterThan(chat.right));
    });

    testWidgets("a leader's cover replaces the art (same layout)", (
      tester,
    ) async {
      _tall(tester);
      final fakes = BondFakes();
      fakes.families.byId[_familyId] = Family.fromJson({
        ...familyJson(),
        'pendingRequestCount': 0,
        'coverUrl': 'https://media.example.test/cover.webp',
      });
      await pumpBonds(
        tester,
        const FamilyScreen(familyId: _familyId),
        fakes: fakes,
      );
      // No network in tests: the cover falls back to the gradient.
      tester.takeException();
      expect(find.byKey(FamilyScreen.heroArtKey), findsNothing);
      expect(find.byKey(FamilyScreen.heroEmblemKey), findsNothing);
      // The emblem over the sheet's edge only (no art ring).
      expect(find.byType(FamilyEmblem), findsOneWidget);
      expect(find.text(en.familyNumberLabel), findsOneWidget);
    });
  });

  group('Arabic and English, 393×852 and 360×800, text scale 1.3 and 2', () {
    setUp(() => FamilyChatScreen.pollEvery = const Duration(days: 1));

    Future<void> each(
      WidgetTester tester,
      Widget screen,
      void Function(BondFakes) setUp,
    ) async {
      for (final size in [const Size(393, 852), const Size(360, 800)]) {
        for (final scale in [1.3, 2.0]) {
          tester.view
            ..physicalSize = size * 3
            ..devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final language in AppLanguage.values) {
            final fakes = BondFakes();
            setUp(fakes);
            await pumpBonds(tester, screen, language: language, fakes: fakes);
            expect(
              tester.takeException(),
              isNull,
              reason: '${language.name} $size $scale',
            );
            expect(
              Directionality.of(tester.element(find.byType(Scaffold).first)),
              language == AppLanguage.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            );
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }

    testWidgets('families list with the podium', (tester) async {
      await each(tester, const FamiliesScreen(), (f) {
        f.families.boards[FamilyRankingBoard.prestige] = _board();
      });
    });

    testWidgets('family page (leader)', (tester) async {
      await each(tester, const FamilyScreen(familyId: _familyId), (f) {
        f.families
          ..byId[_familyId] = _family()
          ..memberList = [
            _member('oz', 'LEADER', rank: 1),
            _member(
              'a-very-long-member-name',
              'DEPUTY',
              rank: 2,
              online: false,
            ),
          ];
      });
    });

    testWidgets('family chat', (tester) async {
      await each(tester, const FamilyChatScreen(familyId: _familyId), (f) {
        f.families
          ..byId[_familyId] = _family(role: 'MEMBER')
          ..chatMessages = [
            FamilyChatMessage.fromJson(familyChatMessageJson(id: 'm1')),
          ];
      });
    });
  });
}
