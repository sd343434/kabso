// D154f («مساعد البث», owner item 11): the host's rule-based assistant —
// each rule (welcome, thank, silence, audience, rest, question) with its
// pause, the hint over the host's live (one at a time, gone after a while
// or a tap), the settings (off, per kind, kept) — Arabic RTL and English at
// 360×800.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_assistant.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_assistant_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _host = UserSummary(
  id: 'host',
  username: 'host',
  displayName: 'Host',
  avatarUrl: null,
);
UserSummary _user(String name) => UserSummary(
  id: 'user-$name',
  username: name,
  displayName: name,
  avatarUrl: null,
);

final _t0 = DateTime.utc(2026, 10, 28, 20);
DateTime _at(int minutes, [int seconds = 0]) =>
    _t0.add(Duration(minutes: minutes, seconds: seconds));

void main() {
  group('rules', () {
    LiveAssistantRules rules() =>
        LiveAssistantRules(startedAt: _t0, selfId: _host.id);

    test('welcome: the joiners since the last one, at most every 90 s; '
        'never the host', () {
      final r = rules();
      expect(r.onJoin(_host, _at(0)), isNull);
      final first = r.onJoin(_user('Sara'), _at(0, 10));
      expect(first, (
        kind: LiveAssistantKind.welcome,
        name: 'Sara',
        count: 0,
        other: 0,
      ));
      expect(r.onJoin(_user('Omar'), _at(0, 30)), isNull);
      expect(r.onJoin(_user('Lina'), _at(1)), isNull);
      // The pause is over: the waiting joiners in one hint.
      final next = r.tick(_at(1, 40), speaking: true, micOn: true);
      expect(next?.kind, LiveAssistantKind.welcome);
      expect(next?.name, 'Omar');
      expect(next?.count, 1);
    });

    test('thank: a big gift (500 coins and more), not the host own', () {
      final r = rules();
      expect(r.onGift(_user('Sara'), 499, _at(1)), isNull);
      expect(r.onGift(_host, 5000, _at(1)), isNull);
      expect(
        r.onGift(_user('Sara'), 500, _at(1))?.kind,
        LiveAssistantKind.thank,
      );
      expect(r.onGift(_user('Omar'), 900, _at(1, 10)), isNull);
      expect(r.onGift(_user('Omar'), 900, _at(1, 30))?.name, 'Omar');
    });

    test('silence: 3 min quiet with the microphone on; not when muted', () {
      final r = rules();
      expect(r.tick(_at(1), speaking: true, micOn: true), isNull);
      expect(r.tick(_at(3, 30), speaking: false, micOn: true), isNull);
      final hint = r.tick(_at(4, 1), speaking: false, micOn: true);
      expect(hint?.kind, LiveAssistantKind.silence);
      expect(hint?.count, 3);
      final muted = rules();
      expect(muted.tick(_at(10), speaking: false, micOn: false), isNull);
    });

    test('audience: up by half (5 or more) or down by 30 % (3 or more) '
        'against 5 min before', () {
      final up = rules();
      for (var m = 0; m <= 5; m++) {
        final h = up.tick(_at(m), speaking: true, micOn: true, viewers: 2);
        expect(h, isNull);
      }
      final rising = up.tick(_at(6), speaking: true, micOn: true, viewers: 10);
      expect(rising, (
        kind: LiveAssistantKind.audience,
        name: null,
        count: 10,
        other: 2,
      ));
      final down = rules()
        ..onChat(_at(0))
        ..tick(_at(0), speaking: true, micOn: true, viewers: 10);
      for (var m = 1; m <= 4; m++) {
        down
          ..onChat(_at(m))
          ..onChat(_at(m, 1))
          ..tick(_at(m), speaking: true, micOn: true, viewers: 10);
      }
      down
        ..onChat(_at(6))
        ..onChat(_at(6, 1));
      final falling = down.tick(
        _at(6),
        speaking: true,
        micOn: true,
        viewers: 6,
      );
      expect(falling?.kind, LiveAssistantKind.audience);
      expect(falling?.other, 10);
    });

    test('rest every 2 h; question when the chat is quiet', () {
      final r = rules();
      // 5 min in, 3 people, no chat: a question.
      expect(
        r.tick(_at(5), speaking: true, micOn: true, viewers: 3)?.kind,
        LiveAssistantKind.question,
      );
      // Not again for 10 min.
      expect(r.tick(_at(10), speaking: true, micOn: true, viewers: 3), isNull);
      expect(
        r.tick(_at(120), speaking: true, micOn: true)?.kind,
        LiveAssistantKind.rest,
      );
      expect(r.tick(_at(121), speaking: true, micOn: true), isNull);
      expect(r.tick(_at(240), speaking: true, micOn: true)?.count, 4);
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('the hint shows over the live, then goes; a turned-off kind '
        'stays quiet (${language.name})', (tester) async {
      setViewport(tester, GoldenViewport.android);
      final engine = FakeLiveMediaEngine();
      late WidgetRef ref;
      await withClock(Clock.fixed(_at(1)), () async {
        await pumpScreen(
          tester,
          Consumer(
            builder: (context, r, _) {
              ref = r;
              return const Scaffold(
                backgroundColor: Color(0xFF333344),
                body: Stack(
                  children: [LiveAssistantHintLayer(roomId: 'room-0')],
                ),
              );
            },
          ),
          language: language,
          liveMediaEngine: engine,
        );
        ref
            .read(liveAssistantProvider('room-0').notifier)
            .attach(engine, startedAt: _t0, selfId: _host.id);
        engine.chat.add(LiveChatJoined(_user('Sara')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
      final ar = language == AppLanguage.ar;
      expect(find.byKey(LiveAssistantHintLayer.hintKey), findsOneWidget);
      expect(find.textContaining(ar ? 'رحّب بـ' : 'Welcome'), findsOneWidget);
      final box = tester.getRect(find.byKey(LiveAssistantHintLayer.hintKey));
      expect(box.right, lessThanOrEqualTo(360));
      expect(box.left, greaterThanOrEqualTo(0));
      await tester.pump(LiveAssistant.showTime);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveAssistantHintLayer.hintKey), findsNothing);

      // The thank-you kind off: a big gift says nothing.
      ref
          .read(liveAssistantSettingsProvider.notifier)
          .setKind(LiveAssistantKind.thank, on: false);
      engine.chat.add(
        LiveGiftReceived(LiveGift.fromJson(liveGiftJson(quantity: 999))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LiveAssistantHintLayer.hintKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the settings: off disables the kinds; choices are kept', (
    tester,
  ) async {
    setViewport(tester, GoldenViewport.android);
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('test.open'),
              onPressed: () => showLiveAssistantSettings(context),
              child: const SizedBox.square(dimension: 40),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('test.open')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LiveAssistantSettingsSheet)),
    );
    await tester.tap(
      find.byKey(LiveAssistantSettingsSheet.kindKey(LiveAssistantKind.rest)),
    );
    await tester.pumpAndSettle();
    expect(container.read(liveAssistantSettingsProvider).off, {
      LiveAssistantKind.rest,
    });
    await tester.tap(find.byKey(LiveAssistantSettingsSheet.enabledKey));
    await tester.pumpAndSettle();
    expect(container.read(liveAssistantSettingsProvider).enabled, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(
              LiveAssistantSettingsSheet.kindKey(LiveAssistantKind.welcome),
            ),
          )
          .onChanged,
      isNull,
    );
    // Kept: a new read of the preferences gives the same.
    container.invalidate(liveAssistantSettingsProvider);
    final kept = container.read(liveAssistantSettingsProvider);
    expect(kept.enabled, isFalse);
    expect(kept.off, {LiveAssistantKind.rest});
  });
}
