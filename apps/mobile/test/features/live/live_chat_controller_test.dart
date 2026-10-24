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

List<String> _texts(LiveChatState state) => [
  for (final item in state.items)
    switch (item) {
      LiveChatPosted(:final entry) => entry.text,
      LiveChatPending(:final text, :final failed) =>
        failed ? '!$text' : '…$text',
      LiveChatJoinLine(:final user) => '+${user.username}',
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
    expect(_texts(state()), ['hi', 'welcome', '+huda']);
  });

  test('hides live lines from people this person blocked', () async {
    await attach();
    engine.chat
      ..add(LiveChatReceived(_entry('t1', 'spam', author: _troll)))
      ..add(const LiveChatJoined(_troll))
      ..add(LiveChatReceived(_entry('h1', 'ok')));
    await pumpEventQueue();
    expect(_texts(state()), ['ok']);
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
    final failed = state().items.single as LiveChatPending;
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
    expect(state().items, hasLength(LiveChatController.maxLines));
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
