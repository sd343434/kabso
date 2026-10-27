import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'هدى',
  avatarUrl: null,
);
const _troll = UserSummary(
  id: 'u-troll',
  username: 'troll',
  displayName: 'Troll',
  avatarUrl: null,
);

LiveChatEntry _entry(
  String id,
  String text, {
  UserSummary author = _huda,
  LiveChatRole role = LiveChatRole.viewer,
}) => LiveChatEntry(
  id: id,
  roomId: 'room-1',
  author: author,
  authorRole: role,
  text: text,
  createdAt: DateTime.utc(2026, 10, 24, 20),
);

/// The lines' texts; the rules line (D118) only where [notice]; D131's join
/// lines (the video live's rows) only where [joins].
List<String> _texts(
  LiveChatState state, {
  bool notice = false,
  bool joins = false,
}) => [
  for (final item in state.items)
    if ((notice || item is! LiveChatNoticeLine) &&
        (joins || item is! LiveChatJoinItem))
      switch (item) {
        LiveChatJoinItem(:final join) => '+${join.user.username}',
        LiveChatPosted(:final entry) => entry.text,
        LiveChatPending(:final text, :final failed) =>
          failed ? '!$text' : '…$text',
        LiveChatBulletLine(:final bullet) => '*${bullet.text}',
        LiveChatNoticeLine() => '#rules',
      },
];

void main() {
  late FakeLiveRepository repo;
  late FakeLiveMediaEngine engine;
  late FakeSafetyRepository safety;
  late ProviderContainer container;
  final me = testUser();

  setUp(() {
    repo = FakeLiveRepository()
      ..chatAuthor = UserSummary(
        id: me.id,
        username: me.username,
        displayName: me.displayName,
        avatarUrl: null,
      );
    engine = FakeLiveMediaEngine();
    safety = FakeSafetyRepository(blockedUsers: [_troll]);
    container = ProviderContainer(
      overrides: [
        liveRepositoryProvider.overrideWithValue(repo),
        safetyRepositoryProvider.overrideWithValue(safety),
        currentUserProvider.overrideWithValue(me),
      ],
    );
    addTearDown(container.dispose);
  });

  LiveChatController chat() =>
      container.read(liveChatProvider('room-1').notifier);
  LiveChatState state() => container.read(liveChatProvider('room-1'));

  Future<void> attach({bool enabled = true, bool muted = false}) async {
    container.listen(liveChatProvider('room-1'), (_, _) {});
    await chat().attach(engine, enabled: enabled, muted: muted);
    await pumpEventQueue();
  }

  test('loads the last messages, then adds what the room delivers', () async {
    repo.chat = [_entry('m1', 'hello'), _entry('m2', 'hi')];
    await attach();
    expect(state().loaded, isTrue);
    expect(_texts(state()), ['hello', 'hi']);
    engine.chat
      ..add(LiveChatReceived(_entry('m3', 'welcome')))
      ..add(LiveChatReceived(_entry('m3', 'welcome'))) // a repeat
      ..add(const LiveChatJoined(_huda))
      ..add(const LiveChatDeleted('m1'));
    await pumpEventQueue();
    // D119: a join is the chat's latest join (the audio room's strip);
    // D131: and a join line for the video live's rows.
    expect(_texts(state()), ['hi', 'welcome']);
    expect(state().latestJoin?.user, _huda);
    expect(_texts(state(), joins: true), [
      'hi',
      'welcome',
      '+${_huda.username}',
    ]);
  });

  test('D131: join lines keep their own budget of four and never push out '
      'a message', () async {
    await attach();
    engine.chat.add(LiveChatReceived(_entry('m1', 'first')));
    for (var i = 0; i < 6; i++) {
      engine.chat.add(LiveChatJoined(i.isEven ? _huda : _omar));
    }
    await pumpEventQueue();
    expect(state().items.whereType<LiveChatJoinItem>(), hasLength(4));
    expect(_texts(state()), ['first']);
  });

  test('D119: each join replaces the latest; quick ones add up (+N); '
      'joins do not count toward the 50 lines', () async {
    var now = DateTime.utc(2026, 10, 26, 20);
    await withClock(Clock(() => now), () async {
      await attach();
      engine.chat.add(const LiveChatJoined(_huda));
      await pumpEventQueue();
      final first = state().latestJoin!;
      expect((first.user, first.burst), (_huda, 0));
      now = now.add(const Duration(milliseconds: 500));
      engine.chat.add(const LiveChatJoined(_omar));
      await pumpEventQueue();
      final second = state().latestJoin!;
      expect((second.user, second.burst), (_omar, 1));
      expect(second.serial, greaterThan(first.serial));
      now = now.add(const Duration(seconds: 5));
      engine.chat.add(const LiveChatJoined(_huda));
      await pumpEventQueue();
      expect((state().latestJoin!.user, state().latestJoin!.burst), (_huda, 0));
    });
    expect(state().items.whereType<LiveChatPosted>(), isEmpty);
    // 50 messages after the rules line: all 50 stay with the rules line.
    for (var i = 0; i < 50; i++) {
      engine.chat.add(LiveChatReceived(_entry('x$i', 'm$i')));
    }
    await pumpEventQueue();
    expect(_texts(state()), [for (var i = 0; i < 50; i++) 'm$i']);
    expect(state().items.whereType<LiveChatNoticeLine>(), hasLength(1));
    engine.chat.add(LiveChatReceived(_entry('x50', 'm50')));
    await pumpEventQueue();
    expect(_texts(state()).first, 'm1');
    expect(_texts(state()), hasLength(50));
  });

  test('D118: the rules line comes once, after the last messages and '
      'before what the room delivers; it is local (never sent)', () async {
    repo.chat = [_entry('m1', 'hello')];
    await attach();
    expect(_texts(state(), notice: true), ['hello', '#rules']);
    engine.chat.add(LiveChatReceived(_entry('m2', 'hi')));
    await pumpEventQueue();
    // A second attach (the chat box reopened) adds no second rules line.
    await attach();
    expect(_texts(state(), notice: true), ['hello', '#rules', 'hi']);
    expect(repo.chatCalls, ['list']);
  });

  test('hides live lines from people this person blocked', () async {
    await attach();
    engine.chat
      ..add(LiveChatReceived(_entry('t1', 'spam', author: _troll)))
      ..add(const LiveChatJoined(_troll))
      ..add(LiveChatReceived(_entry('h1', 'ok')));
    await pumpEventQueue();
    expect(_texts(state()), ['ok']);
    expect(state().latestJoin, isNull);
  });

  test('the host turns the chat off and on (chat-state)', () async {
    await attach();
    engine.chat.add(const LiveChatStateChanged(enabled: false));
    await pumpEventQueue();
    expect(state().enabled, isFalse);
    engine.chat.add(const LiveChatStateChanged(enabled: true));
    await pumpEventQueue();
    expect(state().enabled, isTrue);
  });

  test('sending shows the line at once, then the stored message', () async {
    await attach();
    final sending = chat().send('  salam  ');
    expect(_texts(state()), ['…salam']);
    expect(await sending, isNull);
    expect(repo.chatCalls, contains('send:salam'));
    expect(_texts(state()), ['salam']);
    // The room's copy of the same message does not double it.
    engine.chat.add(
      LiveChatReceived(_entry('sent-0', 'salam', author: repo.chatAuthor)),
    );
    await pumpEventQueue();
    expect(_texts(state()), ['salam']);
    // Empty text sends nothing.
    expect(await chat().send('   '), isNull);
    expect(repo.chatCalls.where((c) => c.startsWith('send:')), hasLength(1));
  });

  test('our own message from the room replaces the pending line', () async {
    await attach();
    // The room delivers our message while the API call is still open.
    final sending = chat().send('fast');
    expect(_texts(state()), ['…fast']);
    engine.chat.add(
      LiveChatReceived(_entry('sent-0', 'fast', author: repo.chatAuthor)),
    );
    await pumpEventQueue();
    await sending;
    expect(_texts(state()), ['fast']);
  });

  test('muted: the line goes and the chat knows', () async {
    await attach();
    repo.chatFailure = const ServerFailure(
      code: ErrorCode.liveChatMuted,
      rawCode: 'LIVE_CHAT_MUTED',
      statusCode: 403,
      debugMessage: 'muted',
    );
    final failure = await chat().send('hey');
    expect(failure?.code, ErrorCode.liveChatMuted);
    expect(state().muted, isTrue);
    expect(_texts(state()), isEmpty);
  });

  test('chat off: the line goes and the chat knows', () async {
    await attach();
    repo.chatFailure = const ServerFailure(
      code: ErrorCode.liveChatClosed,
      rawCode: 'LIVE_CHAT_CLOSED',
      statusCode: 409,
      debugMessage: 'closed',
    );
    await chat().send('hey');
    expect(state().enabled, isFalse);
    expect(_texts(state()), isEmpty);
  });

  test('a failed line stays with a retry that reuses its client id', () async {
    await attach();
    repo.chatFailure = const NetworkFailure.offline();
    expect((await chat().send('again'))?.code, ErrorCode.networkOffline);
    expect(_texts(state()), ['!again']);
    final failed = state().items.whereType<LiveChatPending>().single;
    expect(await chat().retry(failed), isNull);
    expect(_texts(state()), ['again']);
    // Discarding a failed line drops it.
    repo.chatFailure = const NetworkFailure.offline();
    await chat().send('gone');
    chat().discard(state().items.whereType<LiveChatPending>().single);
    expect(_texts(state()), ['again']);
  });

  test('keeps the newest 50 lines', () async {
    repo.chat = [for (var i = 0; i < 50; i++) _entry('m$i', 'line $i')];
    await attach();
    engine.chat.add(LiveChatReceived(_entry('m50', 'line 50')));
    await pumpEventQueue();
    // D119: 50 messages; the rules line (D118) stays and does not count.
    expect(_texts(state()), hasLength(LiveChatController.maxLines));
    expect(_texts(state(), notice: true)[49], '#rules');
    expect(_texts(state()).first, 'line 1');
    expect(_texts(state()).last, 'line 50');
  });

  test('delete, mute, the chat switch and reports call the API', () async {
    await attach();
    final entry = _entry('m9', 'bad');
    engine.chat.add(LiveChatReceived(entry));
    await pumpEventQueue();
    await chat().delete(entry);
    expect(_texts(state()), isEmpty);
    await chat().setMuted('huda', muted: true);
    await chat().setMuted('huda', muted: false);
    await chat().setEnabled(enabled: false);
    expect(state().enabled, isFalse);
    expect(repo.chatCalls, [
      'list',
      'delete:m9',
      'mute:huda',
      'unmute:huda',
      'enabled:false',
    ]);
  });

  test("attach starts with the room's chat switch and mute", () async {
    await attach(enabled: false, muted: true);
    expect(state().enabled, isFalse);
    expect(state().muted, isTrue);
  });
}
