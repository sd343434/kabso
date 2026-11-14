// D152: push notifications and the in-app sounds (CONVENTIONS §11.12) —
// where a tap goes, when a sound plays (Sound effects, foreground, the open
// chat, no stacking), the token's life with the session, and the
// notification permission asked once with a rationale (D144a pattern),
// Arabic RTL and English LTR at 360 × 800.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/push/notification_sounds.dart';
import 'package:kabso_live/features/push/open_conversation.dart';
import 'package:kabso_live/features/push/push_controller.dart';
import 'package:kabso_live/features/push/push_messaging.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:kabso_live/features/push/push_tokens_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_notifications_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _FakePlayer implements NotificationSoundPlayer {
  final played = <NotificationSound>[];

  @override
  Future<void> play(NotificationSound sound) async => played.add(sound);

  @override
  Future<void> dispose() async {}
}

class _FakeMessaging implements PushMessaging {
  new({this.ready = true, this.initial});

  final bool ready;
  final PushPayload? initial;
  String? current = 'tok-1';
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushPayload>.broadcast();
  final opened = StreamController<PushPayload>.broadcast();
  int inits = 0;

  @override
  Future<bool> init() async {
    inits++;
    return ready;
  }

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushPayload> get onForeground => foreground.stream;

  @override
  Stream<PushPayload> get onOpened => opened.stream;

  @override
  Future<PushPayload?> initialMessage() async => initial;
}

class _FakeTokens implements PushTokensRepository {
  final calls = <String>[];

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String appVersion,
  }) async => calls.add('put:$token:$platform:$appVersion');

  @override
  Future<void> unregister() async => calls.add('delete');
}

class _FakePermissions implements PushPermissions {
  new(this.state, {this.afterRequest});

  KabsoPermissionStatus state;
  KabsoPermissionStatus? afterRequest;
  int checks = 0;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<KabsoPermissionStatus> check() async {
    checks++;
    return state;
  }

  @override
  Future<KabsoPermissionStatus> request() async {
    requests++;
    if (afterRequest case final next?) state = next;
    return state;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A session that is already signed in (no token store, no server).
class _SignedIn extends SessionController {
  @override
  AuthState build() => Authenticated(testUser());
}

class _IntroDone extends SplashIntro {
  @override
  bool build() => true;
}

PushPayload _chat(String familyId) => PushPayload({
  'kind': 'family_chat',
  'channel': 'messages',
  'familyId': familyId,
  'messageId': 'm1',
});

PushPayload _note(Map<String, String> data) =>
    PushPayload({'kind': 'notification', 'channel': 'general', ...data});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('where a tap goes', () {
    test('a family chat message opens that chat', () {
      expect(_chat('f1').route(), AppRoutes.familyChat('f1'));
      expect(_chat('f1').conversation, 'family:f1');
      expect(_chat('f1').isMessage, isTrue);
    });

    test('a notification opens its target as the inbox would', () {
      expect(
        _note({'type': 'FOLLOW', 'targetType': 'USER', 'targetId': 'sara'})
            .route(),
        AppRoutes.userProfile('sara'),
      );
      expect(
        _note({'type': 'LIKE_POST', 'targetType': 'POST', 'targetId': 'p1'})
            .route(),
        AppRoutes.post('p1'),
      );
      expect(
        _note({
          'type': 'COMMENT',
          'targetType': 'COMMENT',
          'targetId': 'c1',
          'targetPostId': 'p9',
        }).route(),
        AppRoutes.post('p9', comments: true),
      );
      expect(
        _note({
          'type': 'MENTION',
          'targetType': 'STORY',
          'targetId': 's1',
          'actorUsername': 'omar',
        }).route(),
        AppRoutes.stories('omar'),
      );
      expect(
        _note({
          'type': 'FAMILY_JOIN_ACCEPTED',
          'targetType': 'FAMILY',
          'targetId': 'f2',
        }).route(),
        AppRoutes.family('f2'),
      );
      expect(_note({'type': 'CP_REQUEST'}).route(), AppRoutes.cp);
      expect(_note({'type': 'MEDAL_AWARDED'}).route(), AppRoutes.medals);
      // D171.
      expect(_note({'type': 'BAG_ITEM_RECEIVED'}).route(), AppRoutes.bag);
      expect(
        _note({
          'type': 'PREMIUM_USERNAME_EXPIRING',
          'targetType': 'PREMIUM_USERNAME',
          'targetId': 'ace',
        }).route(),
        AppRoutes.premium,
      );
      // Removed content and targets this build does not know: the inbox.
      expect(
        _note({'type': 'CONTENT_REMOVED', 'targetType': 'POST'}).route(),
        AppRoutes.notifications,
      );
      expect(
        _note({'type': 'SOMETHING_NEW', 'targetType': 'X', 'targetId': '1'})
            .route(),
        AppRoutes.notifications,
      );
      expect(const PushPayload({'kind': 'unknown'}).route(), isNull);
    });
  });

  group('in-app sounds (phase 1)', () {
    late ProviderContainer container;
    late _FakePlayer player;
    late bool foreground;

    setUp(() async {
      final prefs = await testPrefs();
      player = _FakePlayer();
      foreground = true;
      NotificationSounds.foreground = () => foreground;
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationSoundPlayerProvider.overrideWithValue(player),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('never two at once, each at most once per its gap', () {
      final start = DateTime(2026, 10, 28, 12);
      final sounds = container.read(notificationSoundsProvider);
      withClock(Clock.fixed(start), sounds.general);
      // The message sound while the general one plays: dropped.
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 1))),
        sounds.message,
      );
      // After it ended: plays.
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 3))),
        sounds.message,
      );
      // A second message within 2 s: dropped; after: plays.
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 4))),
        sounds.message,
      );
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 6))),
        sounds.message,
      );
      // The general sound again within 8 s (e.g. the poll after the push):
      // dropped; after: plays.
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 7))),
        sounds.general,
      );
      withClock(
        Clock.fixed(start.add(const Duration(seconds: 9))),
        sounds.general,
      );
      expect(player.played, [
        NotificationSound.general,
        NotificationSound.message,
        NotificationSound.message,
        NotificationSound.general,
      ]);
    });

    test('silent with Sound effects off or in the background', () async {
      final sounds = container.read(notificationSoundsProvider);
      await container.read(soundEffectsProvider.notifier).set(on: false);
      sounds
        ..general()
        ..message();
      await container.read(soundEffectsProvider.notifier).set(on: true);
      foreground = false;
      sounds
        ..general()
        ..message();
      expect(player.played, isEmpty);
      foreground = true;
      sounds.message();
      expect(player.played, [NotificationSound.message]);
    });

    test("the owner's files are the assets played", () {
      expect(NotificationSound.general.asset, 'sounds/kabi_voice_a.mp3');
      expect(NotificationSound.message.asset, 'sounds/kabso_message.mp3');
    });
  });

  group('PushController', () {
    late _FakeMessaging messaging;
    late _FakeTokens tokens;
    late _FakePlayer player;
    late ProviderContainer container;

    Future<ProviderContainer> make({
      bool ready = true,
      PushPayload? initial,
    }) async {
      final prefs = await testPrefs();
      messaging = _FakeMessaging(ready: ready, initial: initial);
      tokens = _FakeTokens();
      player = _FakePlayer();
      NotificationSounds.foreground = () => true;
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              appVersion: '0.1.0-staging+abc1234',
            ),
          ),
          sessionControllerProvider.overrideWith(_SignedIn.new),
          splashIntroProvider.overrideWith(_IntroDone.new),
          pushMessagingProvider.overrideWithValue(messaging),
          pushTokensRepositoryProvider.overrideWithValue(tokens),
          notificationSoundPlayerProvider.overrideWithValue(player),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
        ],
      );
    }

    tearDown(() => container.dispose());

    test('registers the token once signed in and on every refresh; '
        'signing out removes it', () async {
      container = await make();
      final push = container.read(pushControllerProvider);
      await push.start();
      await push.start(); // starts once
      await pumpEventQueue();
      expect(messaging.inits, 1);
      expect(tokens.calls, ['put:tok-1:ANDROID:0.1.0-staging+abc1234']);
      messaging.refresh.add('tok-2');
      await pumpEventQueue();
      expect(tokens.calls.last, 'put:tok-2:ANDROID:0.1.0-staging+abc1234');
      await push.signingOut();
      expect(tokens.calls.last, 'delete');
    });

    test(
      'push off on this device: nothing registered, nothing heard',
      () async {
        container = await make(ready: false);
        final push = container.read(pushControllerProvider);
        await push.start();
        await pumpEventQueue();
        expect(tokens.calls, isEmpty);
        await push.signingOut();
        expect(tokens.calls, isEmpty);
      },
    );

    test('foreground: the open chat is silent, another chat plays the '
        'message sound, a notification the general sound', () async {
      container = await make();
      final push = container.read(pushControllerProvider);
      await push.start();
      container.read(openConversationProvider.notifier).opened('family:f1');
      messaging.foreground.add(_chat('f1'));
      await pumpEventQueue();
      expect(player.played, isEmpty);
      messaging.foreground.add(_chat('f2'));
      await pumpEventQueue();
      expect(player.played, [NotificationSound.message]);
      await withClock(
        Clock.fixed(clock.now().add(const Duration(seconds: 5))),
        () async {
          push.onForeground(_note({'type': 'FOLLOW'}));
        },
      );
      expect(player.played.last, NotificationSound.general);
      // The chat closed: its messages are heard again.
      container.read(openConversationProvider.notifier).closed('family:f1');
      expect(container.read(openConversationProvider), isNull);
    });
  });

  group('screens', () {
    Future<(GoRouter, ProviderContainer)> pumpRoutes(
      WidgetTester tester, {
      required List<Override> overrides,
      String language = 'en',
      String initial = '/home',
    }) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificationSettings,
            builder: (_, _) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.familyChatPattern,
            builder: (_, s) => Text('chat ${s.pathParameters['familyId']}'),
          ),
        ],
      );
      final prefs = await testPrefs(language: language);
      final scope = ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerProvider.overrideWithValue(router),
          ...overrides,
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: router,
            locale: Locale(language),
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: Locale(language),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scope);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      return (router, container);
    }

    testWidgets('a tap on a chat push opens the chat through GoRouter', (
      tester,
    ) async {
      final messaging = _FakeMessaging();
      final (router, container) = await pumpRoutes(
        tester,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              appVersion: '1.0.0',
            ),
          ),
          sessionControllerProvider.overrideWith(_SignedIn.new),
          splashIntroProvider.overrideWith(_IntroDone.new),
          pushMessagingProvider.overrideWithValue(messaging),
          pushTokensRepositoryProvider.overrideWithValue(_FakeTokens()),
        ],
      );
      await container.read(pushControllerProvider).start();
      messaging.opened.add(_chat('fam-7'));
      await tester.pumpAndSettle();
      expect(find.text('chat fam-7'), findsOneWidget);
      // Pushed on top of Home: Back returns into the app.
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.familyChat('fam-7'),
      );
      expect(router.canPop(), isTrue);
    });

    for (final language in ['ar', 'en']) {
      testWidgets('$language: the rationale once, then the system prompt; '
          'never again by itself (360 × 800)', (tester) async {
        setViewport(tester, GoldenViewport.android);
        final permissions = _FakePermissions(
          KabsoPermissionStatus.notAsked,
          afterRequest: KabsoPermissionStatus.granted,
        );
        await pumpRoutes(
          tester,
          language: language,
          initial: AppRoutes.notifications,
          overrides: [
            pushMessagingProvider.overrideWithValue(_FakeMessaging()),
            pushPermissionsProvider.overrideWithValue(permissions),
            notificationsRepositoryProvider.overrideWithValue(
              FakeNotificationsRepository(),
            ),
            currentUserProvider.overrideWithValue(testUser()),
          ],
        );
        final l10n = lookupAppLocalizations(Locale(language));
        expect(find.byKey(PushPermissionKeys.sheet), findsOneWidget);
        expect(find.text(l10n.pushPermissionTitle), findsOneWidget);
        expect(find.text(l10n.pushPermissionBody), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text(l10n.pushPermissionBody))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(PushPermissionKeys.allow));
        await tester.pumpAndSettle();
        expect(permissions.requests, 1);
        expect(find.byKey(PushPermissionKeys.sheet), findsNothing);
      });
    }

    testWidgets('Not now asks nothing; a later visit does not ask again', (
      tester,
    ) async {
      final permissions = _FakePermissions(KabsoPermissionStatus.denied);
      final (router, _) = await pumpRoutes(
        tester,
        initial: AppRoutes.notifications,
        overrides: [
          pushMessagingProvider.overrideWithValue(_FakeMessaging()),
          pushPermissionsProvider.overrideWithValue(permissions),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.tap(find.byKey(PushPermissionKeys.notNow));
      await tester.pumpAndSettle();
      expect(permissions.requests, 0);
      router.go('/home');
      await tester.pumpAndSettle();
      router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();
      expect(find.byKey(PushPermissionKeys.sheet), findsNothing);
      expect(permissions.checks, 1);
    });

    testWidgets('push off on this device (no Firebase): no rationale', (
      tester,
    ) async {
      final permissions = _FakePermissions(KabsoPermissionStatus.notAsked);
      await pumpRoutes(
        tester,
        initial: AppRoutes.notifications,
        overrides: [
          pushMessagingProvider.overrideWithValue(_FakeMessaging(ready: false)),
          pushPermissionsProvider.overrideWithValue(permissions),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      expect(find.byKey(PushPermissionKeys.sheet), findsNothing);
      expect(permissions.checks, 0);
    });

    for (final language in ['ar', 'en']) {
      testWidgets('$language settings: refused for good → «Open settings»; '
          'the family chat switch (360 × 800)', (tester) async {
        setViewport(tester, GoldenViewport.android);
        final permissions = _FakePermissions(KabsoPermissionStatus.blocked);
        final repo = FakeNotificationsRepository();
        await pumpRoutes(
          tester,
          language: language,
          initial: AppRoutes.notificationSettings,
          overrides: [
            pushMessagingProvider.overrideWithValue(_FakeMessaging()),
            pushPermissionsProvider.overrideWithValue(permissions),
            notificationsRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(testUser()),
          ],
        );
        final l10n = lookupAppLocalizations(Locale(language));
        expect(find.byKey(PushPermissionKeys.banner), findsOneWidget);
        expect(find.text(l10n.pushOffBlockedBody), findsOneWidget);
        await tester.tap(find.byKey(PushPermissionKeys.bannerAction));
        await tester.pumpAndSettle();
        expect(permissions.settingsOpened, 1);
        final messages = find.byKey(
          NotificationSettingsScreen.switchKey(NotificationSetting.messages),
        );
        await tester.scrollUntilVisible(messages, 100);
        expect(find.text(l10n.notifSettingMessages), findsOneWidget);
        await tester.tap(messages);
        await tester.pumpAndSettle();
        expect(repo.calls.last, 'setting:messages:false');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('granted: no banner', (tester) async {
      await pumpRoutes(
        tester,
        initial: AppRoutes.notificationSettings,
        overrides: [
          pushMessagingProvider.overrideWithValue(_FakeMessaging()),
          pushPermissionsProvider.overrideWithValue(
            _FakePermissions(KabsoPermissionStatus.granted),
          ),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      expect(find.byKey(PushPermissionKeys.banner), findsNothing);
    });
  });

  test('NotificationSettings: an older server sends no `messages` (on)', () {
    final s = NotificationSettings.fromJson(const {
      'likes': true,
      'comments': true,
      'mentions': true,
      'follows': true,
      'reposts': true,
      'lives': true,
    });
    expect(s.messages, isTrue);
    expect(NotificationSetting.messages.set(s, on: false).messages, isFalse);
  });

  test('the unread count growing plays the general sound', () async {
    final prefs = await testPrefs();
    final player = _FakePlayer();
    NotificationSounds.foreground = () => true;
    final repo = FakeNotificationsRepository()..unread = 1;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationSoundPlayerProvider.overrideWithValue(player),
        notificationsRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(testUser()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(unreadNotificationsProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    expect(player.played, isEmpty); // the first load is not "new"
    repo.unread = 3;
    await container.read(unreadNotificationsProvider.notifier).refresh();
    expect(player.played, [NotificationSound.general]);
  });
}
