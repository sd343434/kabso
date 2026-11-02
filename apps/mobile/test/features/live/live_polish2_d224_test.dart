// D224 (owner, 2026-11-01): «الافيهات ارى ان يكون شريط. ارسالها كشريط
// الهدايا الاخرى وتظهر على التكست / اطار التكست للاشخاص بدون ان يكون يرتدي
// فقاعة دردشة عادي بدون اي شيء خلفية بشفافية كما كان قبل / التارجت تصنيفات
// تكون حسب نظام مختار لونها ابيض في لايت مود واسود في داركك مود».
//
// 1. A quip that plays is a gift strip (the same column, queue and time as a
//    gift) and a chat line like a gift's; D216's banner is gone.
// 2. A chat message has no default box in any live category (video, audio,
//    podcast); a worn bubble (CP) still shows; joins keep theirs.
// 3. The «تارجت» sheet's selected tab and period: white in the light theme,
//    black in the dark one, readable text.
// Arabic RTL and English LTR at 393×852 and 360×800 with text ×1.3.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_gift_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'host_target_d199_test.dart' show statsFixture, targetsFixture;

class _Audio implements QuipAudio {
  final played = <String>[];

  @override
  Future<void> play(String soundKey) async => played.add(soundKey);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);

LiveQuip _quip(String id, {String code = 'quip_ghazal_01'}) =>
    LiveQuip.fromJson(liveQuipJson(id: id, code: code));

LiveGift _gift(String id) => LiveGift.fromJson({
  ...liveGiftJson(
    id: id,
    sender: giftUserJson('omar', 'Omar'),
    recipients: [giftUserJson('sara', 'Sara')],
  ),
  'createdAt': '2026-10-30T12:00:00.000Z',
});

LiveChatEntry _entry(String id, String text, {bool cp = false}) =>
    LiveChatEntry(
      id: id,
      roomId: 'room-0',
      author: _huda,
      authorRole: LiveChatRole.viewer,
      text: text,
      createdAt: DateTime.utc(2026, 11, 1, 20),
      cpBubble: cp,
    );

LiveSeats _seats(LiveRoomMode mode, int count) => LiveSeats(
  roomId: 'room-0',
  mode: mode,
  version: 1,
  seatCount: count,
  seats: [
    for (var i = 1; i < count; i++)
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

/// The real viewer screen of a [mode] live, text ×[scale].
Future<(FakeLiveMediaEngine, _Audio)> _room(
  WidgetTester tester, {
  required AppLanguage language,
  required GoldenViewport viewport,
  LiveRoomMode mode = LiveRoomMode.solo,
  double scale = 1.3,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  final audio = _Audio();
  setViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final repo = FakeLiveRepository(
    room: (id) => switch (mode) {
      LiveRoomMode.audio => apiRoom(
        id: id,
      ).copyWith(mode: LiveRoomMode.audio, seatCount: 10),
      LiveRoomMode.multi => apiRoom(
        id: id,
      ).copyWith(mode: LiveRoomMode.multi, seatCount: 4),
      LiveRoomMode.podcast => apiRoom(id: id).copyWith(
        mode: LiveRoomMode.podcast,
        seatCount: 4,
        theme: 'podcast-studio',
        podcast: const LivePodcast(
          episodeNumber: 3,
          topic: PodcastTopic.business,
        ),
      ),
      _ => apiRoom(id: id),
    },
  );
  if (mode == LiveRoomMode.audio) repo.seatState = _seats(mode, 10);
  if (mode == LiveRoomMode.podcast) repo.seatState = _seats(mode, 4);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    liveGiftRepository: FakeLiveGiftRepository(
      codes: [...giftFixtureCodes, ...quipFixtureCodes],
      ar: language == AppLanguage.ar,
    ),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: language == AppLanguage.ar)),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      currentUserProvider.overrideWithValue(testUser()),
      quipAudioProvider.overrideWithValue(audio),
    ],
  );
  await tester.pumpAndSettle();
  return (engine, audio);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
}

Finder _line(String key) => find.byKey(LiveRoomChatLines.lineKey(key));

/// The fill of the first box under [finder] (a Container's decoration).
Color? _fill(WidgetTester tester, Finder finder) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: finder,
          matching: find.byType(Container),
          matchRoot: true,
        )
        .first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    for (final viewport in [GoldenViewport.phone, GoldenViewport.android]) {
      final tag = '${language.name}, ${viewport.name}, text ×1.3';

      group('quips as gift strips ($tag)', () {
        testWidgets('a quip plays as a gift strip (sender, «أرسل إفيه», '
            'its words and Kabi art; no count) in the gifts column with a '
            "gift's strip, and as a chat line; then goes with the gift's "
            'time', (tester) async {
          final (engine, audio) = await _room(
            tester,
            language: language,
            viewport: viewport,
          );
          engine.chat
            ..add(LiveGiftReceived(_gift('g1')))
            ..add(LiveQuipReceived(_quip('q1')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          // The sound is unchanged.
          expect(audio.played, ['kabi/ghazal_01']);
          final strips = find.byKey(LiveGiftStrips.stripsKey);
          final quip = find.byKey(LiveGiftEffectsLayer.quipKey('q1'));
          expect(find.descendant(of: strips, matching: quip), findsOneWidget);
          expect(
            find.descendant(of: strips, matching: find.byType(LiveGiftBanner)),
            findsNWidgets(2),
          );
          Finder inQuip(Finder f) => find.descendant(of: quip, matching: f);
          expect(inQuip(find.text('\u2068لينا\u2069')), findsOneWidget);
          expect(
            inQuip(
              find.text(
                l10n.liveQuipBannerSent('\u2068إيه الجمال ده! تحفة بجد!\u2069'),
              ),
            ),
            findsOneWidget,
          );
          expect(inQuip(find.byType(LiveQuipArt)), findsOneWidget);
          expect(inQuip(find.byType(KGiftComboCounter)), findsNothing);
          // The chat line, the way a gift's line shows.
          final lines = find.byType(LiveChatGiftLineView);
          expect(lines, findsNWidgets(2));
          expect(
            find.text(
              l10n.liveChatQuipLine(
                '\u2068لينا\u2069',
                '\u2068إيه الجمال ده! تحفة بجد!\u2069',
              ),
            ),
            findsOneWidget,
          );
          expect(_line('q:q1'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // A gift's time on screen (3 s), then gone; the line stays.
          await tester.pump(LiveGiftEffects.bannerTime);
          await tester.pump(const Duration(milliseconds: 400));
          expect(quip, findsNothing);
          expect(_line('q:q1'), findsOneWidget);
          await _leave(tester);
        });
      });

      // D234 (owner: «أسود شفاف»; supersedes D224's «بدون اي شيء»): a
      // message without a worn bubble sits on translucent black.
      group('chat lines on translucent black ($tag)', () {
        for (final mode in [
          LiveRoomMode.solo,
          LiveRoomMode.multi,
          LiveRoomMode.audio,
          LiveRoomMode.podcast,
        ]) {
          testWidgets('${mode.name}: a message sits on translucent black '
              '(no border); a worn CP bubble shows instead', (tester) async {
            final (engine, _) = await _room(
              tester,
              language: language,
              viewport: viewport,
              mode: mode,
            );
            engine.chat
              ..add(LiveChatReceived(_entry('m1', 'hello there')))
              ..add(LiveChatReceived(_entry('m2', 'with love', cp: true)));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            final row = find.descendant(
              of: _line('m:m1'),
              matching: find.byKey(
                mode == LiveRoomMode.audio
                    ? LiveChatAuthoredLine.boxKey
                    : LiveChatInlineRow.rowKey,
              ),
            );
            expect(row, findsOneWidget);
            expect(_fill(tester, row), LiveRoomChatLines.messageBox);
            expect(
              LiveRoomChatLines.messageBox.a,
              inInclusiveRange(0.35, 0.45),
            );
            final box = tester.widget<Container>(
              find.descendant(of: row, matching: find.byType(Container)).first,
            );
            final deco = box.decoration! as BoxDecoration;
            expect(deco.border, isNull);
            expect(
              (deco.borderRadius! as BorderRadius).topLeft.x,
              inInclusiveRange(12, 14),
            );
            expect(
              find.descendant(
                of: _line('m:m2'),
                matching: find.byKey(LiveCpChatBubble.bubbleKey),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await _leave(tester);
          });
        }
      });

      group('the «تارجت» sheet tabs ($tag)', () {
        for (final brightness in Brightness.values) {
          testWidgets('${brightness.name}: the selected tab and period on '
              'the theme page colour pill, readable; the others plain', (
            tester,
          ) async {
            HostTargetSheet.clock = () => DateTime.utc(2026, 10, 31, 15, 43);
            addTearDown(() => HostTargetSheet.clock = DateTime.now);
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await pumpGolden(
              tester,
              ProviderScope(
                overrides: [
                  liveHostTargetsRepositoryProvider.overrideWithValue(
                    FakeLiveHostTargetsRepository(
                      byHost: {'host': targetsFixture()},
                      stats: {
                        for (final p in HostStatsPeriod.values)
                          p: statsFixture(p),
                      },
                    ),
                  ),
                  currentUserProvider.overrideWithValue(testUser()),
                ],
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: HostTargetSheet(isHost: true),
                ),
              ),
              language: language,
              viewport: viewport,
              brightness: brightness,
              bare: true,
            );
            await tester.pumpAndSettle();
            final palette = brightness == Brightness.dark
                ? KPalette.dark
                : KPalette.light;
            final white = brightness == Brightness.light;
            expect(
              palette.background,
              white ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0D),
            );
            final day = find.byKey(
              HostTargetSheet.periodKey(HostStatsPeriod.day),
            );
            expect(_fill(tester, day), palette.background);
            final week = find.byKey(
              HostTargetSheet.periodKey(HostStatsPeriod.week),
            );
            expect(_fill(tester, week), isNull);
            final tab = find.byKey(HostTargetSheet.chosenTabKey);
            expect(
              find.descendant(
                of: find.byKey(HostTargetSheet.tabKey(TargetTab.cherries)),
                matching: tab,
              ),
              findsOneWidget,
            );
            expect(_fill(tester, tab), palette.background);
            // Readable: the theme's strongest text on it.
            final label = tester.widget<Text>(
              find.descendant(of: day, matching: find.byType(Text)),
            );
            expect(label.style?.color, palette.textPrimary);
            // Choosing another period moves the pill.
            await tester.ensureVisible(week);
            await tester.tap(week);
            await tester.pumpAndSettle();
            expect(_fill(tester, week), palette.background);
            expect(_fill(tester, day), isNull);
            await tester.tap(
              find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)),
            );
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)),
                matching: tab,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          });
        }
      });
    }
  }

  test('a quip line is added once', () {
    final container = ProviderContainer.test(
      overrides: [
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      ],
    );
    container.listen(liveChatProvider('room-0').notifier, (_, _) {}).read()
      ..addQuip(_quip('q1'))
      ..addQuip(_quip('q1'));
    expect(
      container
          .read(liveChatProvider('room-0'))
          .items
          .whereType<LiveChatQuipLine>()
          .length,
      1,
    );
  });
}
