// D376 «الحالة» (owner 2026-11-12): animated status emoji that rise over a
// picture like bubbles and burst with sparkles.
//
// Checked: the catalogue (142 Kabso + 24 «عام» free, 27 «المميزة»; birds
// sway their face); the picker (pack tabs, «بدون حالة», Save; «المميزة»
// locked until held — preview yes, save no, «افتح المتجر»); «متجر الحالة»
// (server price, buy, renew, too few coins → recharge, «استخدم»); the
// layer (bubbles with one ticker, reduced motion → still, the comments'
// badge, busy seat rows animate only the speakers).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/status/status_picker_sheet.dart';
import 'package:kabso_live/features/status/status_store_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../fixtures/status/status_fixtures.dart';
import '../../helpers/fake_status_repository.dart';
import 'status_harness.dart';

/// Whether the status [id]'s layer animates (bubbles sit in a
/// VisibilityDetector so the ticker runs only on screen).
bool _moving(String id) => find
    .descendant(
      of: find.byKey(StatusEmojiLayer.keyOf(id)),
      matching: find.byType(VisibilityDetector),
    )
    .evaluate()
    .isNotEmpty;

LiveSeat _seat(int i, String status) => LiveSeat(
  index: i,
  state: LiveSeatState.taken,
  user: UserSummary(
    id: 'u$i',
    username: 'guest$i',
    displayName: 'Guest $i',
    avatarUrl: null,
    statusEmojiId: status,
  ),
);

void main() {
  group('catalogue', () {
    test('the owner pack sizes and ids', () {
      final free = StatusCatalogue.packs.where(
        (p) => p.kind == StatusPackKind.free,
      );
      final kabso = free.where((p) => p.id != 'noto');
      expect(kabso.expand((p) => p.emojis), hasLength(142));
      // The Kabso packs reuse the chat emoji files (no duplicate assets).
      expect(
        kabso.map((p) => p.id).toSet(),
        EmojiPack.values.map((p) => p.name).toSet(),
      );
      for (final e in kabso.expand((p) => p.emojis)) {
        expect(e.asset, startsWith('assets/emojis/${e.packId}/'));
      }
      expect(StatusCatalogue.pack('noto')!.emojis, hasLength(24));
      final premium = StatusCatalogue.pack('premium')!;
      expect(premium.kind, StatusPackKind.store);
      expect(premium.emojis, hasLength(27));
      expect(premium.emojis.where((e) => e.faceSway), hasLength(9));
      for (final e in [
        ...StatusCatalogue.pack('noto')!.emojis,
        ...premium.emojis,
      ]) {
        expect(e.asset, startsWith('assets/emojis/noto/'));
        expect(
          e.id,
          matches(RegExp(r'^[a-z][a-z0-9]{0,23}\.[a-z0-9_]{1,39}$')),
        );
      }
      // Noto's first frame is empty for some: their still is later.
      expect(StatusCatalogue.byId('premium.dragon')!.stillAt, 0.75);
      expect(StatusCatalogue.byId('noto.happy')!.stillAt, 0);
      expect(StatusCatalogue.byId('kabi.love')!.stillAt, 0);
      expect(StatusCatalogue.byId('premium.parrot'), isNull);
      // Every file of assets/emojis/noto/ is a status emoji, and back.
      final notoFiles = Directory('assets/emojis/noto')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.json'))
          .toSet();
      expect(notoFiles, {
        for (final e in [
          ...StatusCatalogue.pack('noto')!.emojis,
          ...premium.emojis,
        ])
          e.asset,
      });
      expect(notoFiles, hasLength(51));
      expect(StatusCatalogue.byId('nope.x'), isNull);
    });
  });

  group('picker', () {
    testWidgets('a free status: preview, Save returns it; «بدون حالة»', (
      tester,
    ) async {
      final picks = <StatusPick?>[];
      await pumpStatus(
        tester,
        StatusSheetHost(initialId: 'noto.party', onPick: picks.add),
        language: AppLanguage.en,
      );
      expect(find.byKey(StatusPickerSheet.previewKey), findsOneWidget);
      expect(find.byKey(StatusEmojiLayer.keyOf('noto.party')), findsOneWidget);
      expect(_moving('noto.party'), isTrue);
      expect(find.byKey(StatusPickerSheet.lockKey('premium')), findsOneWidget);
      expect(find.byKey(StatusPickerSheet.lockKey('noto')), findsNothing);

      await tester.tap(
        find.byKey(StatusPickerSheet.itemKey('noto.heart_eyes')),
      );
      await tester.pump();
      expect(
        find.byKey(StatusEmojiLayer.keyOf('noto.heart_eyes')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(StatusPickerSheet.saveKey));
      await settleStatus(tester);
      expect(picks.single?.emoji?.id, 'noto.heart_eyes');
      expect(tester.takeException(), isNull);
    });

    testWidgets('«بدون حالة» clears the preview and saves null', (
      tester,
    ) async {
      final picks = <StatusPick?>[];
      await pumpStatus(
        tester,
        StatusSheetHost(initialId: 'kabi.crown', onPick: picks.add),
      );
      await tester.tap(find.byKey(StatusPickerSheet.noneKey));
      await tester.pump();
      expect(find.byKey(StatusEmojiLayer.keyOf('kabi.crown')), findsNothing);
      await tester.tap(find.byKey(StatusPickerSheet.saveKey));
      await settleStatus(tester);
      expect(picks, hasLength(1));
      expect(picks.single!.emoji, isNull);
    });

    testWidgets('«المميزة» not held: preview allowed, save refused, store', (
      tester,
    ) async {
      await pumpStatus(tester, const StatusSheetHost(initialId: null));
      await tester.ensureVisible(
        find.byKey(StatusPickerSheet.tabKey('premium')),
      );
      await tester.pump();
      await tester.tap(find.byKey(StatusPickerSheet.tabKey('premium')));
      await settleStatus(tester);
      await tester.tap(find.byKey(StatusPickerSheet.itemKey('premium.eagle')));
      await settleStatus(tester);
      expect(
        find.byKey(StatusEmojiLayer.keyOf('premium.eagle')),
        findsOneWidget,
      );
      expect(find.byKey(StatusPickerSheet.lockedHintKey), findsOneWidget);
      expect(find.byKey(StatusPickerSheet.saveKey), findsNothing);
      expect(find.byKey(StatusPickerSheet.storeKey), findsOneWidget);

      await tester.tap(find.byKey(StatusPickerSheet.storeKey));
      await settleStatus(tester);
      expect(find.byType(StatusStoreScreen), findsOneWidget);
      // The store opens on the emoji being previewed.
      expect(
        find.descendant(
          of: find.byType(StatusStoreScreen),
          matching: find.byKey(StatusEmojiLayer.keyOf('premium.eagle')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('«المميزة» held: no lock, Save returns it', (tester) async {
      final picks = <StatusPick?>[];
      await pumpStatus(
        tester,
        StatusSheetHost(initialId: 'premium.crown', onPick: picks.add),
        repo: FakeStatusRepository(
          list: statusPackListFixture(
            heldUntil: DateTime.now().toUtc().add(const Duration(days: 3)),
          ),
        ),
      );
      expect(find.byKey(StatusPickerSheet.lockKey('premium')), findsNothing);
      expect(find.byKey(StatusPickerSheet.lockedHintKey), findsNothing);
      await tester.tap(find.byKey(StatusPickerSheet.saveKey));
      await settleStatus(tester);
      expect(picks.single?.emoji?.id, 'premium.crown');
    });
  });

  group('store', () {
    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.byKey(StatusStoreScreen.buyKey));
      await settleStatus(tester);
      await tester.tap(find.byType(FilledButton).last);
      await settleStatus(tester);
    }

    testWidgets('buys at the server price; then «استخدم»', (tester) async {
      final repo = await pumpStatus(
        tester,
        const StatusStoreScreen(packId: 'premium', displayName: 'Layla'),
        language: AppLanguage.en,
      );
      expect(find.text('Buy · 100,000 coins'), findsOneWidget);
      expect(find.byKey(StatusStoreScreen.activeKey), findsNothing);
      await tester.tap(find.byKey(StatusStoreScreen.itemKey('premium.lion')));
      await tester.pump();
      expect(
        find.byKey(StatusEmojiLayer.keyOf('premium.lion')),
        findsOneWidget,
      );

      await confirm(tester);
      expect(repo.bought, hasLength(1));
      expect(repo.bought.single.packId, 'premium');
      expect(repo.bought.single.days, 30);
      expect(repo.bought.single.price, 100000);
      expect(repo.bought.single.key, isNotEmpty);
      expect(find.byKey(StatusStoreScreen.activeKey), findsOneWidget);
      expect(find.byKey(StatusStoreScreen.useKey), findsOneWidget);
      expect(find.text('Renew · 100,000 coins'), findsOneWidget);
      // The one price of the server's table, under the emoji.
      await tester.scrollUntilVisible(
        find.byKey(StatusStoreScreen.optionKey(30)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(StatusStoreScreen.optionKey(30)), findsOneWidget);
    });

    testWidgets('held: Renew adds the days to what is left', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(days: 10));
      final repo = await pumpStatus(
        tester,
        const StatusStoreScreen(packId: 'premium', displayName: 'Layla'),
        language: AppLanguage.en,
        repo: FakeStatusRepository(
          list: statusPackListFixture(heldUntil: until),
        ),
      );
      expect(find.byKey(StatusStoreScreen.activeKey), findsOneWidget);
      expect(find.text('Renew · 100,000 coins'), findsOneWidget);
      await confirm(tester);
      expect(
        repo.list.pack('premium')!.expiresAt,
        until.add(const Duration(days: 30)),
      );
    });

    testWidgets('too few coins: nothing bought, «اشحن» offered', (
      tester,
    ) async {
      final repo = await pumpStatus(
        tester,
        const StatusStoreScreen(packId: 'premium', displayName: 'Layla'),
        repo: FakeStatusRepository(
          list: statusPackListFixture(coins: 500),
          buyFailure: const ServerFailure(
            code: ErrorCode.insufficientCoins,
            rawCode: 'INSUFFICIENT_COINS',
            debugMessage: 'short',
            statusCode: 409,
          ),
        ),
      );
      await confirm(tester);
      expect(repo.bought, isEmpty);
      expect(find.byKey(StatusStoreScreen.shortKey), findsOneWidget);
      expect(find.byKey(StatusStoreScreen.rechargeKey), findsOneWidget);
    });
  });

  group('layer', () {
    testWidgets('reduced motion: the still emoji, no ticker', (tester) async {
      await pumpStatus(
        tester,
        const Center(
          child: SizedBox.square(
            dimension: 120,
            child: StatusAvatar(
              radius: 60,
              statusEmojiId: 'noto.love',
              child: KAvatar(name: 'Layla', size: 120),
            ),
          ),
        ),
        disableAnimations: true,
      );
      expect(find.byKey(StatusEmojiLayer.keyOf('noto.love')), findsOneWidget);
      expect(_moving('noto.love'), isFalse);
    });

    testWidgets('bubbles run one ticker, stopped when the layer goes', (
      tester,
    ) async {
      final fixed = StatusEmojiLayer.debugTime;
      StatusEmojiLayer.debugTime = null;
      addTearDown(() => StatusEmojiLayer.debugTime = fixed);
      await pumpStatus(
        tester,
        const Center(
          child: SizedBox.square(
            dimension: 120,
            child: StatusAvatar(
              radius: 60,
              statusEmojiId: 'noto.love',
              child: KAvatar(name: 'Layla', size: 120),
            ),
          ),
        ),
      );
      expect(_moving('noto.love'), isTrue);
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('an unknown id shows only the picture', (tester) async {
      await pumpStatus(
        tester,
        const StatusAvatar(
          radius: 20,
          statusEmojiId: 'premium.parrot',
          child: KAvatar(name: 'Layla', size: 40),
        ),
      );
      expect(find.byType(StatusEmojiLayer), findsNothing);
      expect(find.byType(KAvatar), findsOneWidget);
    });

    testWidgets('comments: a small still badge (no motion in a list)', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        Scaffold(
          body: CommentRow(
            name: 'Layla',
            text: 'hello',
            when: '1m',
            likeCount: 0,
            liked: false,
            onLike: () {},
            statusEmojiId: 'kabi.love',
          ),
        ),
      );
      expect(find.byKey(StatusEmojiLayer.keyOf('kabi.love')), findsOneWidget);
      expect(_moving('kabi.love'), isFalse);
    });

    testWidgets('seats: all rise up to 5 on stage, then speakers only', (
      tester,
    ) async {
      Future<void> ring(int guests) => pumpStatus(
        tester,
        Scaffold(
          body: AudioSeatRing(
            count: 8,
            host: const KAvatar(name: 'Host', size: AudioSeatRing.picture),
            hostName: 'Host',
            hostStatusEmojiId: 'noto.party',
            speaking: const {2},
            seats: [for (var i = 1; i <= guests; i++) _seat(i, 'kabi.love')],
          ),
        ),
      );
      await ring(3);
      expect(_moving('noto.party'), isTrue);
      expect(find.byKey(StatusEmojiLayer.keyOf('kabi.love')), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byKey(StatusEmojiLayer.keyOf('kabi.love')),
          matching: find.byType(VisibilityDetector),
        ),
        findsNWidgets(3),
      );
      await ring(6);
      expect(_moving('noto.party'), isFalse);
      // Only seat 2 is speaking.
      expect(
        find.descendant(
          of: find.byKey(StatusEmojiLayer.keyOf('kabi.love')),
          matching: find.byType(VisibilityDetector),
        ),
        findsOneWidget,
      );
    });
  });
}
