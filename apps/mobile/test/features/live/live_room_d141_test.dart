// D141 (owner's device feedback on the live rooms): the elapsed pill, the
// rules line that rises with the chat, the keyboard over the chat box, one
// header gap for every room, the bidi order of the chat rows, the wish
// picker's tabs, the chat's 429, the public message card, whole chat lines,
// no ink on the animated header buttons and the camera flip.
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_public_message.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
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

LiveChatEntry _entry(String id, String text) => LiveChatEntry(
  id: id,
  roomId: 'room-1',
  author: _huda,
  authorRole: LiveChatRole.viewer,
  text: text,
  createdAt: DateTime.utc(2026, 10, 27, 20),
);

/// The lines as short labels: `#` the rules line, else the message text.
List<String> _lines(LiveChatState state) => [
  for (final item in state.items)
    switch (item) {
      LiveChatNoticeLine() => '#',
      LiveChatPosted(:final entry) => entry.text,
      LiveChatPending(:final text, :final failed) =>
        failed ? '!$text' : '…$text',
      _ => '?',
    },
];

/// `chatMessages` that waits for [gate].
class _GatedRepository extends FakeLiveRepository {
  Completer<void>? gate;

  @override
  Future<List<LiveChatEntry>> chatMessages(String roomId) async {
    await gate?.future;
    return await super.chatMessages(roomId);
  }
}

Future<void> _pumpBare(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.en,
  MediaQueryData Function(MediaQueryData)? media,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) {
        final data = MediaQuery.of(context);
        return MediaQuery(data: media?.call(data) ?? data, child: child);
      },
    ),
    language: language,
  );
  await tester.pump();
}

void main() {
  group('2. the rules line rises with the chat (controller)', () {
    late _GatedRepository repo;
    late FakeLiveMediaEngine engine;
    late ProviderContainer container;

    setUp(() {
      repo = _GatedRepository();
      engine = FakeLiveMediaEngine();
      container = ProviderContainer(
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(container.dispose);
    });

    LiveChatState state() => container.read(liveChatProvider('room-1'));
    ProviderSubscription<LiveChatState>? listening;
    Future<void> attach() async {
      listening = container.listen(liveChatProvider('room-1'), (_, _) {});
      await container
          .read(liveChatProvider('room-1').notifier)
          .attach(engine, enabled: true, muted: false);
      await pumpEventQueue();
    }

    test('first line of the visit, after the history; N messages later it '
        'is above all of them', () async {
      repo.chat = [_entry('h1', 'old 1'), _entry('h2', 'old 2')];
      await attach();
      expect(_lines(state()), ['old 1', 'old 2', '#']);
      for (var i = 0; i < 6; i++) {
        engine.chat.add(LiveChatReceived(_entry('m$i', 'new $i')));
      }
      await pumpEventQueue();
      final lines = _lines(state());
      expect(lines.indexOf('#'), 2);
      for (var i = 0; i < 6; i++) {
        expect(lines.indexOf('new $i'), greaterThan(lines.indexOf('#')));
      }
    });

    test(
      'a line that arrives while the history loads stays under the '
      'rules line, even when the history has it too (the device bug)',
      () async {
        repo
          ..gate = Completer<void>()
          ..chat = [_entry('h1', 'old'), _entry('m1', 'early')];
        container.listen(liveChatProvider('room-1'), (_, _) {});
        final attaching = container
            .read(liveChatProvider('room-1').notifier)
            .attach(engine, enabled: true, muted: false);
        await pumpEventQueue();
        engine.chat.add(LiveChatReceived(_entry('m1', 'early')));
        await pumpEventQueue();
        repo.gate!.complete();
        await attaching;
        await pumpEventQueue();
        expect(_lines(state()), ['old', '#', 'early']);
      },
    );

    test('the chat rebuilt (the host minimized and reopened the live): the '
        'rules line stays where it was said, not at the bottom', () async {
      repo.chat = [_entry('h1', 'old')];
      await attach();
      engine.chat
        ..add(LiveChatReceived(_entry('m1', 'one')))
        ..add(LiveChatReceived(_entry('m2', 'two')));
      await pumpEventQueue();
      expect(_lines(state()), ['old', '#', 'one', 'two']);
      // The controller goes (nothing listens: the screen closed while
      // minimized); the history now has everything.
      listening!.close();
      await pumpEventQueue();
      repo.chat = [
        _entry('h1', 'old'),
        _entry('m1', 'one'),
        _entry('m2', 'two'),
      ];
      engine = FakeLiveMediaEngine();
      await attach();
      expect(_lines(state()), ['old', '#', 'one', 'two']);
      // Leaving the room ends the visit: the next one has its own line.
      endLiveChatVisit(container.read(liveChatVisitsProvider), 'room-1');
      listening!.close();
      await pumpEventQueue();
      engine = FakeLiveMediaEngine();
      await attach();
      expect(_lines(state()), ['old', 'one', 'two', '#']);
    });

    test('12: a line sent faster than one a second waits its turn and goes '
        'by itself (429 + Retry-After); still refused: it says why', () async {
      await attach();
      const tooFast = ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'x',
        statusCode: 429,
        retryAfter: Duration(milliseconds: 20),
      );
      repo
        ..chatFailureRepeated = tooFast
        ..chatFailureTimes = 1;
      final chat = container.read(liveChatProvider('room-1').notifier);
      final failure = await chat.send(':flags_ps:');
      expect(failure, isNull);
      expect(_lines(state()).last, ':flags_ps:');
      expect(repo.chatCalls.where((c) => c == 'send::flags_ps:'), hasLength(2));
      repo.chatFailureTimes = LiveChatController.rateRetries + 1;
      final refused = await chat.send(':kabi_hi:');
      expect(refused?.code, ErrorCode.rateLimited);
      final pending = state().items.whereType<LiveChatPending>().single;
      expect(pending.failed, isTrue);
      expect(pending.tooFast, isTrue);
    });
  });

  group('1. the elapsed pill', () {
    testWidgets('LIVE capsule with a dot, tabular time; reduced motion keeps '
        'the dot still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final since = DateTime.now().subtract(
        const Duration(minutes: 2, seconds: 22),
      );
      await _pumpBare(tester, Center(child: KLiveElapsedPill(since: since)));
      expect(find.text('LIVE'), findsOneWidget);
      final time = tester.widget<Text>(find.byKey(KLiveElapsedPill.timeKey));
      expect(time.data, startsWith('2:2'));
      expect(
        time.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<AnimatedOpacity>(find.byKey(KLiveElapsedPill.dotKey))
              .opacity,
          1,
        );
      }
      expect(
        tester.getSize(find.byType(KLiveElapsedPill)).height,
        greaterThanOrEqualTo(KViewerRoom.chipHeight),
      );
    });
  });

  group('3 + 5. keyboard and the header gap', () {
    testWidgets('one header gap: the video pill and the audio card both start '
        '${KMetrics.liveHeaderGap} pt under the status bar', (tester) async {
      MediaQueryData inset(MediaQueryData d) =>
          d.copyWith(padding: d.padding.copyWith(top: 47));
      await _pumpBare(
        tester,
        const KLiveRoomScaffold(header: KHostPill(hostName: 'Oz')),
        media: inset,
      );
      final pill = tester.getRect(find.byKey(KHostPill.pillKey));
      expect(pill.top, closeTo(47 + KMetrics.liveHeaderGap, 0.5));
      await _pumpBare(
        tester,
        const LiveAudioRoomLayout(
          header: LiveAudioRoomHeader(
            cover: SizedBox(),
            title: 'Room',
            username: 'oz',
            minimizeTooltip: 'm',
            onMinimize: null,
            endTooltip: 'e',
            onEnd: null,
          ),
          stage: SizedBox(),
          barStart: [],
          barEnd: [],
        ),
        media: inset,
      );
      final card = tester.getRect(find.byKey(LiveAudioRoomHeader.barKey));
      expect(card.top, closeTo(pill.top, 0.5));
    });

    testWidgets('the keyboard up: the video room bar sits right on it', (
      tester,
    ) async {
      const bar = Key('bar');
      await _pumpBare(
        tester,
        const KLiveRoomScaffold(
          header: KHostPill(hostName: 'Oz'),
          actionBar: SizedBox(key: bar, height: 48),
        ),
        media: (d) => d.copyWith(
          viewInsets: const EdgeInsets.only(bottom: 300),
          padding: d.padding.copyWith(bottom: 0),
        ),
      );
      final rect = tester.getRect(find.byKey(bar));
      expect(rect.bottom, closeTo(852 - 300, 0.5));
    });

    testWidgets('the keyboard up: the audio room chat box sits right on it', (
      tester,
    ) async {
      const composer = Key('composer');
      await _pumpBare(
        tester,
        const LiveAudioRoomLayout(
          header: SizedBox(height: 48),
          stage: SizedBox(),
          barStart: [],
          barEnd: [],
          composer: SizedBox(key: composer, height: 60),
        ),
        media: (d) => d.copyWith(
          viewInsets: const EdgeInsets.only(bottom: 300),
          padding: d.padding.copyWith(bottom: 0),
        ),
      );
      expect(
        tester.getRect(find.byKey(composer)).bottom,
        closeTo(852 - 300, 0.5),
      );
    });
  });

  group('9. chat rows in reading order (bidi)', () {
    const badges = LiveChatAuthorBadges(charmLevel: 12);
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final (label, text) in [
        ('emoji only', ':kiki_love:'),
        ('text and emoji', ar ? 'يا :kabi_hi: هلا' : 'hi :kabi_hi: all'),
        ('two emojis', ':kabi_hi: :kiki_love:'),
      ]) {
        testWidgets('${language.name}, $label: badges, then the name, then '
            'the message in reading order', (tester) async {
          await _pumpBare(
            tester,
            Align(
              alignment: AlignmentDirectional.topStart,
              child: LiveChatInlineRow(
                maxWidth: 380,
                color: const Color(0x66000000),
                label: 'row',
                name: 'Oz',
                role: LiveChatRole.host,
                badges: badges,
                text: text,
              ),
            ),
            language: language,
          );
          final badge = tester.getRect(find.byType(LiveChatBadgeRow));
          final emojis = [
            for (final e in find.byType(KabiEmoji).evaluate())
              tester.getRect(find.byWidget(e.widget)),
          ];
          expect(emojis, isNotEmpty);
          // The name sits between the badges and the first emoji.
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(KBidiRichTextRaw),
          );
          final plain = paragraph.text.toPlainText();
          final at = plain.indexOf('Oz');
          final nameBox = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: at, extentOffset: at + 2),
              )
              .first;
          final origin = paragraph.localToGlobal(Offset.zero);
          final nameLeft = origin.dx + nameBox.left;
          final nameRight = origin.dx + nameBox.right;
          if (ar) {
            expect(badge.left, greaterThanOrEqualTo(nameRight - 0.5));
            for (final e in emojis) {
              expect(e.right, lessThanOrEqualTo(nameLeft + 0.5));
            }
          } else {
            expect(badge.right, lessThanOrEqualTo(nameLeft + 0.5));
            for (final e in emojis) {
              expect(e.left, greaterThanOrEqualTo(nameRight - 0.5));
            }
          }
          if (label == 'two emojis') {
            // :kabi_hi: comes first in reading order.
            final hi = tester.getRect(
              find.byWidgetPredicate(
                (w) => w is KabiEmoji && w.emoji.key == 'kabi_hi',
              ),
            );
            final love = tester.getRect(
              find.byWidgetPredicate(
                (w) => w is KabiEmoji && w.emoji.key == 'kiki_love',
              ),
            );
            expect(ar ? hi.left > love.left : hi.left < love.left, isTrue);
          }
        });
      }
    }
  });

  group('18. whole chat lines', () {
    testWidgets('a line that does not fit whole is left out (not cut), the '
        'newest at the bottom', (tester) async {
      Widget line(String k) => ColoredBox(
        key: Key(k),
        color: const Color(0xFF000000),
        child: const SizedBox(width: 100, height: 40),
      );
      await _pumpBare(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 100,
            width: 200,
            child: LiveChatWholeLines(
              children: [line('a'), line('b'), line('c')],
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('a')).hitTestable(), findsNothing);
      expect(find.byKey(const Key('b')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('c')).hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('c'))).bottom, 100);
      expect(tester.getRect(find.byKey(const Key('b'))).top, 20);
    });
  });

  group('16 + 17. the public message card', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: a pack token plays as the emoji (never '
          'the raw text); the badges the chat knows; ribbon and time', (
        tester,
      ) async {
        final l = l10nFor(language);
        await _pumpBare(
          tester,
          Center(
            child: LivePublicMessage(
              bullet: LiveBullet(
                id: 'b1',
                text: ':kiki_love:',
                sender: _huda,
                roomId: 'room-1',
                createdAt: DateTime(2026, 10, 27, 10, 37),
              ),
              badges: const LiveChatAuthorBadges(charmLevel: 12),
            ),
          ),
          language: language,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(LivePublicMessage.keyFor('b1')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is KabiEmoji && w.emoji.key == 'kiki_love',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(':kiki_love:', findRichText: true),
          findsNothing,
        );
        expect(find.text(l.liveBulletTag), findsOneWidget);
        expect(find.byType(LiveChatBadgeRow), findsOneWidget);
        expect(find.byKey(LiveChatBadgeRow.charmKey), findsOneWidget);
        expect(find.text('10:37'), findsOneWidget);
        // No SVIP in Kabso.
        expect(find.textContaining('SVIP'), findsNothing);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('D141a (${language.name}): compact — a 32 pt avatar, 13 sp '
          'text, at most 78 % of the screen wide, legible at text 1.3', (
        tester,
      ) async {
        await _pumpBare(
          tester,
          Align(
            alignment: AlignmentDirectional.topStart,
            child: LivePublicMessage(
              bullet: LiveBullet(
                id: 'b2',
                text:
                    'Welcome everyone to the live tonight, enjoy the show '
                    'and send your love to the host!',
                sender: _huda,
                roomId: 'room-1',
                createdAt: DateTime(2026, 10, 27, 10, 37),
              ),
            ),
          ),
          language: language,
          media: (d) => d.copyWith(textScaler: const TextScaler.linear(1.3)),
        );
        await tester.pump(const Duration(seconds: 3));
        final card = tester.getRect(find.byKey(LivePublicMessage.keyFor('b2')));
        expect(card.width, lessThanOrEqualTo(393 * 0.78 + 0.5));
        final avatar = tester.getSize(
          find
              .descendant(
                of: find.byKey(LivePublicMessage.keyFor('b2')),
                matching: find.byType(KAvatar),
              )
              .first,
        );
        expect(avatar.width, lessThanOrEqualTo(LivePublicMessage.avatar));
        expect(LivePublicMessage.textSize, 13);
        // The whole text shows (wraps, never cut) and the ribbon stays on.
        expect(find.byKey(LivePublicMessage.ribbonKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        // RTL: the avatar is at the right (reading start).
        final avatarRect = tester.getRect(
          find
              .descendant(
                of: find.byKey(LivePublicMessage.keyFor('b2')),
                matching: find.byType(KAvatar),
              )
              .first,
        );
        expect(
          language == AppLanguage.ar
              ? avatarRect.center.dx > card.center.dx
              : avatarRect.center.dx < card.center.dx,
          isTrue,
        );
      });
    }
  });

  group('10. the wish picker has the gift panel tabs', () {
    testWidgets('tabs, switching filters, the choice stays across tabs, 4 '
        'at most', (tester) async {
      final saved = <List<String>>[];
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLiveWishSheet(
                  context,
                  initial: const [],
                  onSave: (codes) async => saved.add(codes),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      Finder tab(String wire) => find.byKey(KLiveGiftSheet.tabKey(wire));
      Finder gift(String code) => find.byKey(LiveWishSheetKeys.gift(code));
      String count() => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(LiveWishSheetKeys.count),
              matching: find.byType(Text),
            ),
          )
          .data!;
      for (final wire in ['POPULAR', 'EVENT', 'FUN']) {
        expect(tab(wire), findsOneWidget, reason: wire);
      }
      // Popular first: its gifts only.
      expect(gift('rose'), findsOneWidget);
      expect(gift('lantern'), findsNothing);
      await tester.tap(gift('rose'));
      await tester.pump();
      expect(count(), '1/4');
      await tester.tap(tab('EVENT'));
      await tester.pumpAndSettle();
      expect(gift('rose'), findsNothing);
      expect(gift('lantern'), findsOneWidget);
      await tester.tap(gift('lantern'));
      await tester.tap(gift('cake'));
      await tester.pump();
      expect(count(), '3/4');
      await tester.tap(tab('POPULAR'));
      await tester.pumpAndSettle();
      // Still chosen on its own tab.
      expect(
        tester.getSemantics(gift('rose')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await tester.tap(gift('crown'));
      await tester.pump();
      expect(count(), '4/4');
      await tester.tap(gift('heart_balloon'));
      await tester.pump();
      expect(count(), '4/4');
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(LiveWishSheetKeys.save));
      await tester.pumpAndSettle();
      expect(saved, [
        ['rose', 'lantern', 'cake', 'crown'],
      ]);
    });
  });

  group('19. no ink circle on the animated header buttons', () {
    for (final (name, button, key) in [
      ('hub party', const LiveHubPartyButton(), LiveHubPartyButton.buttonKey),
      (
        'voice rooms Live',
        const VoiceRoomsLiveButton(),
        VoiceRoomsLiveButton.buttonKey,
      ),
    ]) {
      testWidgets('$name: pressing paints no highlight or splash', (
        tester,
      ) async {
        await _pumpBare(tester, Center(child: button));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(key)),
        );
        await tester.pump(const Duration(milliseconds: 200));
        // The ink layers inside the button (Material's private
        // `_InkFeatures`).
        final layers = find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_InkFeatures',
          ),
        );
        expect(layers, findsWidgets);
        final ink = <InkFeature>[
          for (final e in layers.evaluate())
            // A test-only getter on a private type.
            ...?(e.renderObject! as dynamic).debugInkFeatures
                as List<InkFeature>?,
        ];
        for (final f in ink) {
          expect(f, isNot(isA<InkSplash>()));
          expect(f, isNot(isA<InkRipple>()));
          expect(f, isNot(isA<InkSparkle>()));
          if (f is InkHighlight) expect(f.color.a, 0);
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
      });
    }
  });

  group('20. camera flip', () {
    test('before the camera starts, Flip picks the other camera and the '
        'preview will not mirror the back one', () async {
      final engine = LiveKitMediaEngine();
      expect(engine.frontCamera, isTrue);
      await engine.flipCamera();
      expect(engine.frontCamera, isFalse);
      await engine.flipCamera();
      expect(engine.frontCamera, isTrue);
    });
  });
}
