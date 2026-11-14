// D293 (owner «نعم»: the verification badge beside the name EVERYWHERE the
// name appears): the seal (`VerificationSeal`, sized to the name's text) on
// a live chat line, a DM list row and a post's author row — right after the
// name in both directions, none without a badge; `UserSummary.verification`
// read from the wire (unknown → none).
//
// With D293_CAPTURE_DIR set, the capture group writes PNGs to
// `<dir>/everywhere/` (not committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_text.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';

UserSummary _user(VerificationBadge? badge, {bool ar = true}) => UserSummary(
  id: 'u1',
  username: 'layla.k',
  displayName: ar ? 'ليلى' : 'Layla',
  avatarUrl: null,
  verification: badge,
);

Widget _chatLine(VerificationBadge? badge, {bool ar = true}) => Align(
  alignment: AlignmentDirectional.topStart,
  child: LiveChatAuthoredLine(
    name: ar ? 'ليلى' : 'Layla',
    verification: badge,
    avatarUrl: null,
    label: 'line',
    message: Text(ar ? 'مرحبا بالجميع' : 'Hello everyone'),
    maxWidth: 320,
    color: const Color(0x66000000),
  ),
);

Widget _dmRow(VerificationBadge? badge, {bool ar = true}) => DmConversationRow(
  item: DmConversation(
    id: 'c1',
    peer: _user(badge, ar: ar),
    status: DmConversationStatus.accepted,
    lastActivityAt: DateTime.utc(2026, 11, 6, 10),
  ),
);

Widget _postAuthor(VerificationBadge? badge, {bool ar = true}) => ProviderScope(
  child: SingleChildScrollView(
    child: FeedPostTile(
      post: FeedPostData(
        authorName: ar ? 'ليلى' : 'Layla',
        authorUsername: 'layla.k',
        authorVerification: badge,
        postedAt: DateTime.utc(2026, 11, 6, 9),
        text: ar ? 'منشور جديد' : 'A new post',
      ),
    ),
  ),
);

/// The seal is after [name] in reading order, on its line.
void _expectAfter(WidgetTester tester, Finder name, {required bool rtl}) {
  final n = tester.getRect(name);
  final s = tester.getRect(find.byKey(ProfileVerificationBadge.badgeKey));
  expect(s.center.dy, moreOrLessEquals(n.center.dy, epsilon: 6));
  if (rtl) {
    expect(s.right, lessThanOrEqualTo(n.left + 0.5));
  } else {
    expect(s.left, greaterThanOrEqualTo(n.right - 0.5));
  }
}

void main() {
  test('UserSummary.verification from the wire; unknown is none', () {
    final json = {
      'id': 'u1',
      'username': 'a',
      'displayName': 'A',
      'avatarUrl': null,
    };
    expect(
      UserSummary.fromJson({...json, 'verification': 'CREATOR'}).verification,
      VerificationBadge.creator,
    );
    expect(
      UserSummary.fromJson({...json, 'verification': 'LATER'}).verification,
      isNull,
    );
    expect(UserSummary.fromJson(json).verification, isNull);
  });

  test('the seal follows the text size: ≈ 1.15 × the font, at least 14', () {
    expect(ProfileVerificationBadge.sizeForFont(KChat.nameSize), 16);
    expect(ProfileVerificationBadge.sizeForFont(16), 18);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('a live chat line: the seal right after the name '
        '(${language.name})', (tester) async {
      await pumpGolden(
        tester,
        _chatLine(VerificationBadge.rechargeAgent, ar: ar),
        language: language,
      );
      expect(tester.takeException(), isNull);
      _expectAfter(tester, find.byKey(LiveChatAuthoredLine.nameKey), rtl: ar);
      expect(
        tester.getSize(find.byKey(ProfileVerificationBadge.badgeKey)).width,
        ProfileVerificationBadge.sizeForFont(KChat.nameSize),
      );
      // The line's spoken label says which badge it is.
      expect(
        find.bySemanticsLabel(
          RegExp(ar ? 'موثّق: وكيل شحن' : 'Verified: recharge agent'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a DM list row: the seal after the peer name '
        '(${language.name})', (tester) async {
      await pumpGolden(
        tester,
        _dmRow(VerificationBadge.verifiedHost, ar: ar),
        language: language,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(DmInboxScreen.sealKey('layla.k')), findsOneWidget);
      _expectAfter(tester, find.text(ar ? 'ليلى' : 'Layla'), rtl: ar);
    });

    testWidgets('a post author row: the seal after the name '
        '(${language.name})', (tester) async {
      await pumpGolden(
        tester,
        _postAuthor(VerificationBadge.hostAgent, ar: ar),
        language: language,
      );
      expect(tester.takeException(), isNull);
      _expectAfter(tester, find.text(ar ? 'ليلى' : 'Layla').first, rtl: ar);
    });
  }

  testWidgets('D357 (owner «ازيلها»): never the OWNER seal — chat line, DM '
      'row, post author', (tester) async {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      await pumpGolden(
        tester,
        Column(
          children: [
            _chatLine(VerificationBadge.owner, ar: ar),
            _dmRow(VerificationBadge.owner, ar: ar),
            Expanded(child: _postAuthor(VerificationBadge.owner, ar: ar)),
          ],
        ),
        language: language,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileVerificationBadge), findsNothing);
      expect(find.byKey(ProfileVerificationBadge.badgeKey), findsNothing);
      // The DM row keeps its (empty) seal slot: nothing drawn, no width.
      expect(
        tester.getSize(find.byKey(DmInboxScreen.sealKey('layla.k'))),
        Size.zero,
      );
      expect(
        find.bySemanticsLabel(RegExp(ar ? 'مالك التطبيق' : 'app owner')),
        findsNothing,
      );
    }
  });

  testWidgets('no seal anywhere without a badge', (tester) async {
    await pumpGolden(
      tester,
      Column(children: [_chatLine(null), _dmRow(null)]),
      language: AppLanguage.ar,
    );
    expect(find.byType(ProfileVerificationBadge), findsNothing);
  });

  // D357: the founder's name in a chat line and a DM row with no seal.
  final founderDir = Platform.environment['D357_CAPTURE_DIR'];
  group('D357 no-seal captures', skip: founderDir == null, () {
    for (final (language, brightness) in [
      (AppLanguage.ar, Brightness.light),
      (AppLanguage.ar, Brightness.dark),
      (AppLanguage.en, Brightness.light),
    ]) {
      final ar = language == AppLanguage.ar;
      final tag = '${language.name}.${brightness.name}';
      testWidgets('founder rows $tag', (tester) async {
        final founder = UserSummary(
          id: 'owner-0',
          username: 'kabso',
          displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
          avatarUrl: null,
          verification: VerificationBadge.owner,
        );
        await pumpGolden(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColoredBox(
                color: const Color(0xFF3A2A4A),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: LiveChatAuthoredLine(
                      name: founder.displayName,
                      verification: founder.verification,
                      avatarUrl: null,
                      label: 'line',
                      message: Text(
                        ar ? 'أهلاً بكم في كابسو' : 'Welcome to Kabso',
                      ),
                      maxWidth: 320,
                      color: const Color(0x66000000),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DmConversationRow(
                item: DmConversation(
                  id: 'c1',
                  peer: founder,
                  status: DmConversationStatus.accepted,
                  lastActivityAt: DateTime.utc(2026, 11, 6, 10),
                ),
              ),
            ],
          ),
          language: language,
          brightness: brightness,
          padding: EdgeInsets.zero,
        );
        expect(find.byType(ProfileVerificationBadge), findsNothing);
        await precacheImages(tester);
        await tester.runAsync(() async {
          final element = find.byType(MaterialApp).evaluate().first;
          final image = await captureImage(element);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${founderDir!}/founder.no_seal.chat_dm.$tag.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      });
    }
  });

  final captureDir = Platform.environment['D293_CAPTURE_DIR'];
  group('D293 everywhere captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/everywhere/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final (language, brightness) in [
      (AppLanguage.ar, Brightness.dark),
      (AppLanguage.ar, Brightness.light),
      (AppLanguage.en, Brightness.dark),
    ]) {
      final ar = language == AppLanguage.ar;
      final tag = '${language.name}.${brightness.name}';
      testWidgets('chat $tag', (tester) async {
        await pumpGolden(
          tester,
          ColoredBox(
            color: const Color(0xFF3A2A4A),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in VerificationBadge.values) ...[
                  _chatLine(b, ar: ar),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          language: language,
          brightness: brightness,
        );
        await capture(tester, 'chat_line.$tag');
      });
      testWidgets('dm $tag', (tester) async {
        await pumpGolden(
          tester,
          Column(
            children: [
              for (final b in [...VerificationBadge.values, null])
                _dmRow(b, ar: ar),
            ],
          ),
          language: language,
          brightness: brightness,
          padding: EdgeInsets.zero,
        );
        await capture(tester, 'dm_list.$tag');
      });
      testWidgets('post $tag', (tester) async {
        await pumpGolden(
          tester,
          _postAuthor(VerificationBadge.hostAgent, ar: ar),
          language: language,
          brightness: brightness,
          padding: EdgeInsets.zero,
        );
        await capture(tester, 'post_author.$tag');
      });
    }
  });
}
