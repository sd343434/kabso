// D119 (owner: "make the chat text like this"; reference screenshot,
// third-party, kept out of git, look only): live chat messages show the
// author's picture at the reading start, then the name, a row of the
// badges the data has (role, charm and support levels, family) and the text
// in a rounded bubble. System lines (joins, the rules notice) stay compact.
// Contract v1.24.3-live: `LiveChatMessage.authorBadges`.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_media.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);

/// A mixed-direction name (Arabic with Latin and digits).
const _mixed = UserSummary(
  id: 'u-mixed',
  username: 'noor',
  displayName: 'نور Star 99',
  avatarUrl: null,
);

const _full = LiveChatAuthorBadges(
  charmLevel: 32,
  supportLevel: 12,
  family: LiveChatAuthorFamily(name: 'Kabso Stars', level: 4),
);

LiveChatEntry _entry(
  String id,
  String text, {
  UserSummary author = _huda,
  LiveChatRole role = LiveChatRole.viewer,
  LiveChatAuthorBadges? badges,
  bool cpBubble = false,
  LiveChatKind kind = LiveChatKind.text,
}) => LiveChatEntry(
  id: id,
  roomId: 'room-0',
  author: author,
  authorRole: role,
  text: text,
  createdAt: DateTime.utc(2026, 10, 26, 20),
  cpBubble: cpBubble,
  authorBadges: badges,
  kind: kind,
  media: kind == LiveChatKind.voice
      ? const LiveChatMedia(
          id: 'media-v1',
          url: 'https://m.test/v1',
          thumbUrl: 'https://m.test/v1',
          durationMs: 7000,
        )
      : null,
  expiresAt: kind == LiveChatKind.voice
      ? DateTime.utc(2026, 10, 26, 20, 1)
      : null,
);

LiveSeats _seats() => LiveSeats(
  roomId: 'room-0',
  mode: LiveRoomMode.audio,
  version: 1,
  seatCount: 10,
  seats: [
    for (var i = 1; i < 10; i++)
      LiveSeat(index: i, state: LiveSeatState.empty, user: null),
  ],
  moderators: const [],
  mine: const LiveSeatsMine(
    role: LiveSeatRole.viewer,
    seatIndex: null,
    request: null,
    invite: null,
  ),
);

Future<FakeLiveMediaEngine> _room(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  bool audio = true,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, viewport);
  final repo = FakeLiveRepository(
    room: (id) => audio
        ? apiRoom(id: id).copyWith(mode: LiveRoomMode.audio, seatCount: 10)
        : apiRoom(id: id),
  );
  if (audio) repo.seatState = _seats();
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: language == AppLanguage.ar)),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return engine;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Finder _line(String key) => find.byKey(LiveRoomChatLines.lineKey(key));
Finder _in(String key, Finder finder) =>
    find.descendant(of: _line(key), matching: finder);

void main() {
  final en = l10nFor(AppLanguage.en);

  group('authorBadges (contract v1.24.3-live)', () {
    final json = <String, dynamic>{
      'id': 'm1',
      'roomId': 'room-0',
      'author': {
        'id': 'u-huda',
        'username': 'huda',
        'displayName': 'Huda',
        'avatarUrl': null,
      },
      'authorRole': 'VIEWER',
      'kind': 'TEXT',
      'text': 'hi',
      'media': null,
      'expiresAt': null,
      'createdAt': '2026-10-26T20:00:00.000Z',
      'cpBubble': false,
    };

    test('read; null fields and an older server mean no badges', () {
      expect(LiveChatEntry.fromJson(json).authorBadges, isNull);
      final read = LiveChatEntry.fromJson({
        ...json,
        'authorBadges': {
          'charmLevel': 32,
          'supportLevel': null,
          'family': {'name': 'نجوم', 'level': 4},
        },
      }).authorBadges;
      expect(read?.charmLevel, 32);
      expect(read?.supportLevel, isNull);
      expect(read?.family, const LiveChatAuthorFamily(name: 'نجوم', level: 4));
      expect(
        LiveChatEntry.fromJson({
          ...json,
          'authorBadges': {
            'charmLevel': null,
            'supportLevel': null,
            'family': null,
          },
        }).authorBadges,
        const LiveChatAuthorBadges(),
      );
    });
  });

  for (final language in AppLanguage.values) {
    final rtl = language == AppLanguage.ar;
    group('layout (${language.name})', () {
      testWidgets('D131 video live (ref 158): one row, no picture; the badges '
          'then the name and the text inline, at the reading start', (
        tester,
      ) async {
        final engine = await _room(tester, language: language, audio: false);
        engine.chat.add(LiveChatReceived(_entry('m1', 'hello', badges: _full)));
        await tester.pumpAndSettle();
        expect(
          _in('m:m1', find.byKey(LiveChatAuthoredLine.avatarKey)),
          findsNothing,
        );
        final row = tester.getRect(
          _in('m:m1', find.byKey(LiveChatInlineRow.rowKey)),
        );
        final badges = tester.getRect(
          _in('m:m1', find.byType(LiveChatBadgeRow)),
        );
        final list = tester.getRect(find.byKey(LiveRoomChatLines.listKey));
        expect(row.contains(badges.center), isTrue);
        // The badges at the row's reading start, inside its padding.
        expect(
          rtl
              ? (row.right - badges.right - 8).abs() < 1.5
              : (badges.left - row.left - 8).abs() < 1.5,
          isTrue,
        );
        expect(
          rtl
              ? (list.right - row.right).abs() < 1
              : (row.left - list.left).abs() < 1,
          isTrue,
        );
        // 13 sp lines 18.2 pt apart: one line is about 23 pt (ref 22–23);
        // the test font's wide glyphs wrap this badge-full line once.
        expect(row.height, inInclusiveRange(21, 46));
        final text = tester.widget<RichText>(
          _in('m:m1', find.byType(RichText)).first,
        );
        final plain = text.text.toPlainText();
        expect(plain, contains('Huda'));
        expect(plain, contains('hello'));
        expect(plain.indexOf('Huda'), lessThan(plain.indexOf('hello')));
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });
      for (final audio in [true]) {
        testWidgets('${audio ? 'audio room' : 'video live'}: picture at the '
            'reading start, then name, badges and bubble', (tester) async {
          final engine = await _room(tester, language: language, audio: audio);
          engine.chat.add(
            LiveChatReceived(_entry('m1', 'hello', badges: _full)),
          );
          await tester.pumpAndSettle();
          final avatar = tester.getRect(
            _in('m:m1', find.byKey(LiveChatAuthoredLine.avatarKey)),
          );
          final name = tester.getRect(
            _in('m:m1', find.byKey(LiveChatAuthoredLine.nameKey)),
          );
          final badges = tester.getRect(
            _in('m:m1', find.byType(LiveChatBadgeRow)),
          );
          final bubble = tester.getRect(
            _in('m:m1', find.byKey(LiveChatAuthoredLine.bubbleKey)),
          );
          expect(avatar.width, LiveChatAuthoredLine.avatar);
          // Top-aligned: the name starts near the picture's top.
          expect(
            (name.top - avatar.top - LiveChatAuthoredLine.nameTop).abs(),
            lessThanOrEqualTo(1),
          );
          // Stacked: name, badges, bubble.
          expect(badges.top, greaterThanOrEqualTo(name.bottom));
          expect(bubble.top, greaterThanOrEqualTo(badges.bottom));
          // The column sits after the picture in reading order.
          for (final r in [name, badges, bubble]) {
            expect(
              rtl ? r.right <= avatar.left : r.left >= avatar.right,
              isTrue,
              reason: '$r vs $avatar',
            );
          }
          // One box around the whole line (owner): the picture at its
          // reading start, inside the padding; the box at the chat's start.
          final list = tester.getRect(find.byKey(LiveRoomChatLines.listKey));
          final box = tester.getRect(
            _in('m:m1', find.byKey(LiveChatAuthoredLine.boxKey)),
          );
          for (final r in [avatar, name, badges, bubble]) {
            expect(
              box.contains(r.topLeft) &&
                  box.contains(r.bottomRight - const Offset(0.01, 0.01)),
              isTrue,
              reason: '$r in $box',
            );
          }
          expect(
            rtl
                ? (list.right - box.right).abs() < 1 &&
                      (box.right - avatar.right - 8).abs() < 1
                : (box.left - list.left).abs() < 1 &&
                      (avatar.left - box.left - 8).abs() < 1,
            isTrue,
          );
          expect(
            _in('m:m1', find.text('\u2068Kabso Stars\u2069')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _leave(tester);
        });
      }
    });
  }

  testWidgets('badges only with data: none, some, all; host tag', (
    tester,
  ) async {
    final engine = await _room(tester);
    engine.chat
      ..add(LiveChatReceived(_entry('m1', 'old server')))
      ..add(
        LiveChatReceived(
          _entry('m2', 'no levels', badges: const LiveChatAuthorBadges()),
        ),
      )
      ..add(
        LiveChatReceived(
          _entry(
            'm3',
            'charm only',
            badges: const LiveChatAuthorBadges(charmLevel: 5),
          ),
        ),
      )
      ..add(
        LiveChatReceived(
          _entry('m4', 'all', badges: _full, role: LiveChatRole.host),
        ),
      );
    await tester.pumpAndSettle();
    for (final key in ['m:m1', 'm:m2']) {
      expect(_in(key, find.byType(LiveChatBadgeRow)), findsNothing);
      expect(_in(key, find.byKey(LiveChatAuthoredLine.avatarKey)), findsOne);
    }
    expect(_in('m:m3', find.byKey(LiveChatBadgeRow.charmKey)), findsOne);
    expect(_in('m:m3', find.byKey(LiveChatBadgeRow.supportKey)), findsNothing);
    expect(_in('m:m3', find.byKey(LiveChatBadgeRow.familyKey)), findsNothing);
    for (final key in [
      LiveChatBadgeRow.roleKey,
      LiveChatBadgeRow.charmKey,
      LiveChatBadgeRow.supportKey,
      LiveChatBadgeRow.familyKey,
    ]) {
      expect(_in('m:m4', find.byKey(key)), findsOne);
    }
    expect(_in('m:m4', find.text(en.liveChatHostBadge)), findsOne);
    // The screen reader hears the badges with the line.
    expect(
      find.bySemanticsLabel(
        [
          en.liveChatLineLabel('Huda', 'all'),
          en.liveChatCharmLabel(32),
          en.liveChatSupportLabel(12),
          en.liveChatFamilyLabel('\u2068Kabso Stars\u2069', 4),
        ].join('. '),
      ),
      findsOne,
    );
    // No badges: the bubble comes right under the name.
    final name = tester.getRect(
      _in('m:m2', find.byKey(LiveChatAuthoredLine.nameKey)),
    );
    final bubble = tester.getRect(
      _in('m:m2', find.byKey(LiveChatAuthoredLine.bubbleKey)),
    );
    expect(bubble.top - name.bottom, lessThanOrEqualTo(6));
    await _leave(tester);
  });

  testWidgets('the CP bubble keeps its pink style in the same layout', (
    tester,
  ) async {
    final engine = await _room(tester);
    engine.chat
      ..add(LiveChatReceived(_entry('m1', 'hello', badges: _full)))
      ..add(
        LiveChatReceived(_entry('m2', 'hello', badges: _full, cpBubble: true)),
      );
    await tester.pumpAndSettle();
    final cp = _in('m:m2', find.byKey(LiveCpChatBubble.bubbleKey));
    expect(cp, findsOne);
    expect(_in('m:m1', find.byKey(LiveCpChatBubble.bubbleKey)), findsNothing);
    expect(_in('m:m2', find.byKey(LiveRoomChatLines.cpHeartKey)), findsOne);
    expect(_in('m:m2', find.byKey(LiveChatAuthoredLine.avatarKey)), findsOne);
    // Same size as a plain line; the pink is the whole line's box (owner:
    // one box around the person and what they sent).
    expect(tester.getSize(_line('m:m2')), tester.getSize(_line('m:m1')));
    final pink = tester.getRect(cp);
    for (final key in [
      LiveChatAuthoredLine.avatarKey,
      LiveChatAuthoredLine.nameKey,
      LiveChatAuthoredLine.bubbleKey,
    ]) {
      final r = tester.getRect(_in('m:m2', find.byKey(key)));
      expect(pink.contains(r.center), isTrue);
    }
    expect(
      tester.getRect(_in('m:m2', find.byKey(LiveChatAuthoredLine.boxKey))),
      pink,
    );
    await _leave(tester);
  });

  testWidgets('a voice clip fits the same layout; long press opens the '
      'message actions', (tester) async {
    final engine = await _room(tester);
    engine.chat.add(
      LiveChatReceived(
        _entry('v1', '', badges: _full, kind: LiveChatKind.voice),
      ),
    );
    await tester.pumpAndSettle();
    final pill = _in('m:v1', find.byKey(LiveVoiceClipPill.keyFor('media-v1')));
    expect(pill, findsOne);
    expect(_in('m:v1', find.byKey(LiveChatAuthoredLine.avatarKey)), findsOne);
    expect(_in('m:v1', find.byKey(LiveChatBadgeRow.familyKey)), findsOne);
    expect(
      find.descendant(
        of: _in('m:v1', find.byKey(LiveChatAuthoredLine.bubbleKey)),
        matching: pill,
      ),
      findsOne,
    );
    await tester.longPress(
      _in('m:v1', find.byKey(LiveChatAuthoredLine.nameKey)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liveChat.action.profile')), findsOne);
    await _leave(tester);
  });

  for (final audio in [true, false]) {
    testWidgets('D135: the rules line is the first line of the visit: at the '
        'bottom on entering, it rises with the messages and leaves at the top '
        'like any line; no "no messages" line (${audio ? 'audio' : 'video'})', (
      tester,
    ) async {
      final engine = await _room(tester, audio: audio);
      final notice = find.byKey(LiveRoomChatLines.noticeKey);
      expect(notice, findsOne);
      expect(find.textContaining('No messages yet'), findsNothing);
      // A line of the list, its newest so far.
      expect(
        find.descendant(
          of: find.byKey(LiveRoomChatLines.listKey),
          matching: notice,
        ),
        findsOne,
      );
      engine.chat.add(LiveChatReceived(_entry('n0', 'message 0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The new message comes under it.
      expect(
        tester.getRect(_line('m:n0')).top,
        greaterThanOrEqualTo(tester.getRect(notice).bottom - 0.5),
      );
      for (var i = 1; i < LiveRoomChatLines.maxVisibleLines + 2; i++) {
        engine.chat.add(LiveChatReceived(_entry('n$i', 'message $i')));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));
      // Pushed out at the top like an old line.
      expect(notice, findsNothing);
      await _leave(tester);
    });
  }

  test('D135: the see-through rules line reads at 4.5:1 or more over the '
      'brightest backgrounds tested (a bright video frame, the bright room '
      'themes) and on dark ones', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    // Mean colour under the chat area: ref 158's bright video frame, the
    // bright themes' lower half (sunset-sky, heart-garden, moon-palace,
    // ocean-depths), black and the classic navy.
    for (final (under, bright) in const [
      (Color(0xFF9B8D87), false),
      (Color(0xFFAD7467), true),
      (Color(0xFFBC414D), true),
      (Color(0xFF8C6D87), true),
      (Color(0xFF4165AD), true),
      (Color(0xFF000000), false),
      (Color(0xFF0A1220), false),
    ]) {
      final box = Color.alphaBlend(
        bright ? LiveRoomRulesNotice.fillBright : LiveRoomRulesNotice.fill,
        under,
      );
      expect(
        contrast(LiveRoomRulesNotice.textColor, box),
        greaterThanOrEqualTo(4.5),
        reason: '$under',
      );
      expect(
        contrast(LiveRoomRulesNotice.icon, box),
        greaterThanOrEqualTo(3),
        reason: '$under',
      );
    }
    // The fill stays see-through (owner: "a transparent background").
    expect(LiveRoomRulesNotice.fill.a, lessThan(0.45));
    expect(LiveRoomRulesNotice.fillBright.a, lessThan(0.45));
    expect(LiveRoomRulesNotice.isBrightTheme('sunset-sky'), isTrue);
    expect(LiveRoomRulesNotice.isBrightTheme('classic'), isFalse);
  });

  testWidgets('system lines stay compact: the rules notice has no picture; '
      'a join is not a line', (tester) async {
    final engine = await _room(tester);
    engine.chat.add(const LiveChatJoined(_huda));
    await tester.pump();
    await tester.pump(LiveChatJoinStrip.swap);
    expect(find.byKey(LiveRoomChatLines.noticeKey), findsOne);
    expect(
      find.descendant(
        of: find.byKey(LiveRoomChatLines.listKey),
        matching: find.byKey(LiveChatAuthoredLine.avatarKey),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(LiveRoomChatLines.listKey),
        matching: find.textContaining('joined'),
      ),
      findsNothing,
    );
    await _leave(tester);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the join strip: pinned under the newest message, the latest '
        'join replaces it, +N for quick joins, hides after 4 s '
        '(${language.name})', (tester) async {
      final l10n = l10nFor(language);
      final engine = await _room(tester, language: language);
      Finder strip(String name) => find.descendant(
        of: find.byKey(LiveChatJoinStrip.stripKey),
        matching: find.text(l10n.chatJoined('\u2068$name\u2069')),
      );
      engine.chat
        ..add(LiveChatReceived(_entry('m1', 'hello', badges: _full)))
        ..add(const LiveChatJoined(_huda));
      await tester.pump();
      await tester.pump(LiveChatJoinStrip.swap);
      expect(strip('Huda'), findsOne);
      // Under the newest message, at the reading start.
      final box = tester.getRect(find.byKey(LiveChatJoinStrip.stripKey).first);
      final line = tester.getRect(_line('m:m1'));
      expect(box.top, greaterThanOrEqualTo(line.bottom));
      expect(
        language == AppLanguage.ar
            ? (box.right - line.right).abs() < 1
            : (box.left - line.left).abs() < 1,
        isTrue,
      );
      // The next join replaces it (quick: "+1").
      engine.chat.add(const LiveChatJoined(_mixed));
      await tester.pump();
      await tester.pump(LiveChatJoinStrip.swap);
      expect(strip('Huda'), findsNothing);
      expect(strip('نور Star 99'), findsOne);
      expect(
        find.descendant(
          of: find.byKey(LiveChatJoinStrip.stripKey),
          matching: find.text('+1'),
        ),
        findsOne,
      );
      expect(find.byKey(LiveChatJoinStrip.stripKey), findsOne);
      // Gone 4 s after the last join; messages are untouched.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(LiveChatJoinStrip.stripKey), findsOne);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatJoinStrip.stripKey), findsNothing);
      expect(_line('m:m1'), findsOne);
      await _leave(tester);
    });
  }

  testWidgets('the join strip swaps at once with reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final engine = await _room(tester);
    engine.chat.add(const LiveChatJoined(_huda));
    await tester.pump();
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pump();
    final strip = find.byKey(LiveChatJoinStrip.stripKey);
    expect(strip, findsOne);
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: strip, matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
    await _leave(tester);
  });

  testWidgets('the picture and the name open the person card; the bubble '
      'opens the actions', (tester) async {
    final engine = await _room(tester);
    engine.chat.add(LiveChatReceived(_entry('m1', 'hello', badges: _full)));
    await tester.pumpAndSettle();
    await tester.tap(_in('m:m1', find.byKey(LiveChatAuthoredLine.avatarKey)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room.userCard.profile')), findsOne);
    expect(find.byKey(const Key('liveChat.action.profile')), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(_in('m:m1', find.byKey(LiveChatAuthoredLine.nameKey)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room.userCard.profile')), findsOne);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(
      _in('m:m1', find.textContaining('hello', findRichText: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liveChat.action.profile')), findsOne);
    expect(find.byKey(const Key('liveChat.action.report')), findsOne);
    await _leave(tester);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360 × 800, text scale 2, a long mixed-direction name and a '
        'long message (${language.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // The video live: the audio room's own header does not fit 360 pt at
      // text scale 2 yet (not the chat; reported separately).
      final engine = await _room(
        tester,
        language: language,
        audio: false,
        viewport: GoldenViewport.android,
      );
      engine.chat
        ..add(
          LiveChatReceived(
            _entry(
              'm1',
              'A long message that wraps over several lines in the bubble '
                  'and never runs off the screen',
              author: const UserSummary(
                id: 'u-long',
                username: 'longname',
                displayName:
                    'A very very long display name that cannot fit on one line',
                avatarUrl: null,
              ),
              badges: _full,
            ),
          ),
        )
        ..add(LiveChatReceived(_entry('m2', 'مرحبا hi 2026', author: _mixed)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final screen = tester.getRect(find.byType(LiveRoomScreen));
      // D131: rows wrap inside the chat's width (81 %, at most 318.5 pt).
      for (final key in ['m:m1', 'm:m2']) {
        final row = tester.getRect(
          _in(key, find.byKey(LiveChatInlineRow.rowKey)),
        );
        expect(row.left, greaterThanOrEqualTo(screen.left));
        expect(row.right, lessThanOrEqualTo(screen.right));
        expect(row.width, lessThanOrEqualTo(360 * 0.81 + 0.5));
      }
      // The name is isolated from the layout's direction.
      final mixed = tester.widget<RichText>(
        _in('m:m2', find.byType(RichText)).first,
      );
      expect(mixed.text.toPlainText(), contains('\u2068نور Star 99\u2069'));
      await _leave(tester);
    });
  }
}
