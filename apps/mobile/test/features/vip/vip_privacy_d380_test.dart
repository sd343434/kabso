// D380 (owner 2026-11-11; contract v1.133-social, CONVENTIONS §10.170): the
// VIP privacy perks in the app — the holder's switches in «الخصوصية» (only
// while held), the «إهداء مجهول» send, «مجهول» with the generic avatar on a
// gift strip, and what the recipient of an anonymous gift can do (report the
// sender, refuse their anonymous gifts) without learning who it is.
// Goldens: 393 × 852, status bar 59, home indicator 34, real fonts; ar / en,
// light / dark. Test-only stand-in data.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_anonymous_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/features/vip/presentation/vip_anonymous.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const PrivacySettings _holder = PrivacySettings(
  whoCanMention: MentionPolicy.everyone,
  defaultWhoCanComment: WhoCanComment.everyone,
  hideCherriesReceived: false,
  hideCoinsSent: false,
  hiddenVisit: true,
  rankingAnonymous: false,
  kickMuteShield: true,
);

/// The «مجهول» stand-in as the server sends it (a random id each time).
Map<String, Object?> _anonymousJson() => {
  'id': '0192f1d0-aaaa-7000-8000-00000000a380',
  'username': 'kabso.anonymous',
  'displayName': 'مجهول',
  'avatarUrl': null,
  'anonymous': true,
};

LiveGift _anonymousGift({String recipientId = 'user-sara'}) =>
    LiveGift.fromJson({
      ...liveGiftJson(
        sender: _anonymousJson(),
        recipients: [
          {...giftUserJson('sara', 'سارة'), 'id': recipientId},
        ],
      ),
      'anonymous': true,
    });

/// The privacy screen, full-screen with the phone's insets.
Future<FakeSafetyRepository> _pumpPrivacy(
  WidgetTester tester, {
  required PrivacySettings settings,
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.light,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final safety = FakeSafetyRepository()..privacySettings = settings;
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        safetyRepositoryProvider.overrideWithValue(safety),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        home: const PrivacyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return safety;
}

/// A button that opens the recipient's anonymous gift actions for [gift].
Future<FakeLiveGiftRepository> _pumpActions(
  WidgetTester tester,
  LiveGift gift, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final gifts = FakeLiveGiftRepository();
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveGiftRepositoryProvider.overrideWithValue(gifts),
      ],
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => openAnonymousGiftActions(context, ref, gift),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gifts;
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('D380 wire', () {
    late FakeHttpAdapter http;
    const base = '/api/v1';
    Dio dio() =>
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http;
    setUp(() => http = FakeHttpAdapter());

    test('an anonymous send says so; a named one sends no flag', () async {
      final bodies = <Object?>[];
      http.on('POST', '$base/live/rooms/r1/gifts', (req) {
        bodies.add(req.data);
        return FakeResponse(
          201,
          body: liveGiftResultJson(gift: liveGiftJson()),
        );
      });
      final repo = LiveGiftRepositoryImpl(dio());
      for (final anonymous in [true, false]) {
        await repo.send(
          'r1',
          giftCode: 'rose',
          quantity: 1,
          recipients: const ['sara'],
          source: LiveGiftSource.coins,
          clientId: 'c-$anonymous',
          anonymous: anonymous,
        );
      }
      expect((bodies[0]! as Map)['anonymous'], isTrue);
      expect((bodies[1]! as Map).containsKey('anonymous'), isFalse);
    });

    test('report a gift and refuse / allow its anonymous sender', () async {
      Object? reported;
      http
        ..on('POST', '$base/live/gifts/g1/reports', (req) {
          reported = req.data;
          return const FakeResponse(
            201,
            body: {'reportedAt': '2026-11-12T00:00:00.000Z'},
          );
        })
        ..on(
          'PUT',
          '$base/live/gifts/g1/anonymous-block',
          (_) => const FakeResponse(200, body: {'blocked': true}),
        )
        ..on(
          'DELETE',
          '$base/live/gifts/g1/anonymous-block',
          (_) => const FakeResponse(200, body: {'blocked': false}),
        );
      final repo = LiveGiftRepositoryImpl(dio());
      await repo.reportGift('g1', reason: 'HARASSMENT');
      expect(reported, {'reason': 'HARASSMENT'});
      expect(await repo.setAnonymousSenderRefused('g1', refused: true), isTrue);
      expect(
        await repo.setAnonymousSenderRefused('g1', refused: false),
        isFalse,
      );
    });

    test('«مجهول» parses; a named person is not anonymous; VIP_PROTECTED '
        'maps', () {
      final anonymous = UserSummary.fromJson(_anonymousJson());
      expect(anonymous.anonymous, isTrue);
      expect(anonymous.shownName(en), 'Anonymous');
      expect(anonymous.shownName(ar), 'مجهول');
      final named = UserSummary.fromJson(giftUserJson('sara', 'سارة'));
      expect(named.anonymous, isFalse);
      expect(named.shownName(en), 'سارة');
      expect(named.toJson().containsKey('anonymous'), isFalse);
      expect(_anonymousGift().anonymous, isTrue);
      expect(
        LiveGift.fromJson(liveGiftJson()).anonymous,
        isFalse,
        reason: 'an older server sends no flag',
      );
      expect(ErrorCode.fromWire('VIP_PROTECTED'), ErrorCode.vipProtected);
      expect(en.errorVipProtected, contains('host'));
    });

    test('the privacy answer carries a switch only while its perk is held', () {
      final held = PrivacySettings.fromJson(const {
        'whoCanMention': 'EVERYONE',
        'defaultWhoCanComment': 'EVERYONE',
        'hiddenVisit': true,
        'kickMuteShield': false,
      });
      expect(held.hiddenVisit, isTrue);
      expect(held.rankingAnonymous, isNull);
      expect(held.kickMuteShield, isFalse);
      expect(held.hasVipSwitches, isTrue);
      final none = PrivacySettings.fromJson(const {
        'whoCanMention': 'EVERYONE',
        'defaultWhoCanComment': 'EVERYONE',
      });
      expect(none.hasVipSwitches, isFalse);
    });
  });

  group('D380 privacy switches', () {
    testWidgets('a holder sees the three switches with their values; a '
        'change is sent at once', (tester) async {
      final safety = await _pumpPrivacy(tester, settings: _holder);
      final hidden = find.byKey(PrivacyScreen.hiddenVisitKey);
      await tester.scrollUntilVisible(
        find.byKey(PrivacyScreen.kickMuteShieldKey),
        100,
      );
      await tester.pumpAndSettle();
      expect(find.text(en.privacyVipTitle), findsOneWidget);
      expect(tester.widget<SwitchListTile>(hidden).value, isTrue);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(PrivacyScreen.rankingAnonymousKey),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(PrivacyScreen.kickMuteShieldKey))
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(PrivacyScreen.rankingAnonymousKey));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('updatePrivacy:::rankingAnon=true'));
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(PrivacyScreen.rankingAnonymousKey),
            )
            .value,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(hidden);
      await tester.pumpAndSettle();
      expect(safety.calls, contains('updatePrivacy:::hiddenVisit=false'));
    });

    testWidgets('without the perks (or an older server): no VIP section', (
      tester,
    ) async {
      await _pumpPrivacy(
        tester,
        settings: const PrivacySettings(
          whoCanMention: MentionPolicy.everyone,
          defaultWhoCanComment: WhoCanComment.everyone,
          hideCherriesReceived: false,
          hideCoinsSent: false,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(PrivacyScreen.dataExportKey),
        100,
      );
      expect(find.byKey(PrivacyScreen.vipSectionKey), findsNothing);
      expect(find.byKey(PrivacyScreen.hiddenVisitKey), findsNothing);
    });

    testWidgets('only the held switch shows (an inherited single perk)', (
      tester,
    ) async {
      await _pumpPrivacy(
        tester,
        settings: const PrivacySettings(
          whoCanMention: MentionPolicy.everyone,
          defaultWhoCanComment: WhoCanComment.everyone,
          kickMuteShield: true,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(PrivacyScreen.kickMuteShieldKey),
        100,
      );
      expect(find.byKey(PrivacyScreen.hiddenVisitKey), findsNothing);
      expect(find.byKey(PrivacyScreen.rankingAnonymousKey), findsNothing);
    });
  });

  group('D380 anonymous gift', () {
    testWidgets('the strip shows «مجهول» with the generic avatar, never the '
        'sender', (tester) async {
      await pumpGolden(
        tester,
        LiveGiftBanner(gift: _anonymousGift(), name: 'Rose'),
        language: AppLanguage.en,
      );
      expect(find.textContaining('Anonymous'), findsOneWidget);
      expect(find.textContaining('kabso.anonymous'), findsNothing);
      expect(find.byKey(AnonymousAvatar.avatarKey), findsOneWidget);
      expect(find.byType(KAvatar), findsNothing);
    });

    testWidgets('the recipient reports the sender with a reason', (
      tester,
    ) async {
      final gifts = await _pumpActions(tester, _anonymousGift());
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(AnonymousGiftKeys.sheet), findsOneWidget);
      expect(find.text(en.liveGiftAnonymousFrom), findsOneWidget);
      await tester.tap(find.byKey(AnonymousGiftKeys.report));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('feed.post.report.harassment')),
      );
      await tester.pumpAndSettle();
      expect(gifts.giftReports, [
        (giftId: _anonymousGift().id, reason: 'HARASSMENT'),
      ]);
      expect(find.text(en.liveGiftReported), findsOneWidget);
    });

    testWidgets("the recipient refuses the sender's anonymous gifts", (
      tester,
    ) async {
      final gifts = await _pumpActions(tester, _anonymousGift());
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AnonymousGiftKeys.refuse));
      await tester.pumpAndSettle();
      expect(gifts.refusedGifts, {_anonymousGift().id});
      expect(find.text(en.liveGiftAnonymousRefused), findsOneWidget);
    });
  });

  group('D380 goldens', () {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final brightness in Brightness.values) {
        testWidgets('privacy VIP switches ${language.name} '
            '${brightness.name}', (tester) async {
          await _pumpPrivacy(
            tester,
            settings: _holder,
            language: language,
            brightness: brightness,
          );
          await tester.scrollUntilVisible(
            find.byKey(PrivacyScreen.kickMuteShieldKey),
            100,
          );
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -120),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(PrivacyScreen),
            matchesGoldenFile(
              'png/vip.d380.privacy.${language.name}.${brightness.name}'
              '.phone.png',
            ),
          );
        });
      }
      testWidgets('anonymous gift strip and actions ${language.name}', (
        tester,
      ) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        tester.view.padding = const FakeViewPadding(
          top: 59 * GoldenViewport.pixelRatio,
          bottom: 34 * GoldenViewport.pixelRatio,
        );
        addTearDown(tester.view.resetPadding);
        final prefs = await testPrefs(language: language.name);
        final gift = _anonymousGift();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              liveGiftRepositoryProvider.overrideWithValue(
                FakeLiveGiftRepository(),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: language.locale,
              supportedLocales: KabsoApp.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: buildAppTheme(
                brightness: Brightness.dark,
                locale: language.locale,
              ),
              builder: (context, app) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: app!,
              ),
              home: Scaffold(
                backgroundColor: const Color(0xFF1B1530),
                body: SafeArea(
                  child: Consumer(
                    builder: (context, ref, _) => Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LiveGiftBanner(gift: gift, name: 'Rose'),
                          const SizedBox(height: KSpacing.lg),
                          TextButton(
                            key: const Key('open'),
                            onPressed: () =>
                                openAnonymousGiftActions(context, ref, gift),
                            child: const Text('·'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/vip.d380.anonymous_gift.${language.name}.dark.phone.png',
          ),
        );
      });
    }
  });
}
