// D223 (owner 2026-11-01: «الجهاز الواحد لا يمكنه عمل غير حسابين لكنه يمكن
// فتح حسابات مختلفة»; contract v1.78-social, CONVENTIONS §10.75): one device
// creates at most 2 accounts; signing in is never limited. The app sends a
// salted SHA-256 of the platform's stable id with a sign-up only, and shows
// DEVICE_ACCOUNT_LIMIT on the sign-up screens with a «تسجيل الدخول» action.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/ids/device_key.dart';
import 'package:kabso_live/core/ids/install_id.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/device_limit_notice.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _arCopy =
    'لا يمكن إنشاء أكثر من حسابين من نفس الجهاز. '
    'يمكنك تسجيل الدخول إلى حساباتك الحالية.';
const _enCopy =
    'You cannot create more than 2 accounts on the same device. '
    'You can log in to your existing accounts.';

ServerFailure _limit([String? max = '2']) => ServerFailure(
  code: ErrorCode.deviceAccountLimit,
  rawCode: 'DEVICE_ACCOUNT_LIMIT',
  debugMessage: 'limit',
  statusCode: 409,
  details: [if (max != null) FieldIssue(field: 'device', issue: max)],
);

class _FixedDeviceKey implements DeviceKeySource {
  new(this.value);

  final String? value;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the device key', () {
    const channel = PlatformDeviceKeySource.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('is the salted SHA-256 of platform and id: 64 hex, stable', () {
      final a = deviceKeyOf('android', 'f00dfeed12345678');
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(deviceKeyOf('android', ' f00dfeed12345678 '), a);
      expect(deviceKeyOf('ios', 'f00dfeed12345678'), isNot(a));
      expect(a, isNot(contains('f00dfeed')));
    });

    test('reads the platform id once and never sends it raw', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.method, 'stableId');
        return 'f00dfeed12345678';
      });
      final source = PlatformDeviceKeySource();
      final key = await source.read();
      expect(key, deviceKeyOf('android', 'f00dfeed12345678'));
      expect(await source.read(), key);
      expect(calls, 1);
    });

    test(
      "no id, a failing channel or the emulators' shared id → null",
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        expect(await PlatformDeviceKeySource().read(), isNull);
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => '9774d56d682e549c',
        );
        expect(await PlatformDeviceKeySource().read(), isNull);
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'x'),
        );
        expect(await PlatformDeviceKeySource().read(), isNull);
      },
    );
  });

  group('the repository sends it with a sign-up only', () {
    final key = 'ab' * 32;
    late FakeHttpAdapter http;
    late _FixedDeviceKey source;
    late ProviderContainer container;

    setUp(() async {
      http = FakeHttpAdapter();
      source = _FixedDeviceKey(key);
      final prefs = await testPrefs();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          installIdProvider.overrideWithValue('install-0001-test'),
          deviceKeySourceProvider.overrideWithValue(source),
        ],
      );
    });

    test(
      'register and registerVerify carry device.deviceKey; login does not',
      () async {
        http
          ..on(
            'POST',
            '/api/v1/auth/register',
            (_) => const FakeResponse(
              202,
              body: {'status': 'verification_pending'},
            ),
          )
          ..on(
            'POST',
            '/api/v1/auth/register/verify',
            (_) => FakeResponse(
              201,
              body: authResponseJson(user: meJson(emailVerified: true)),
            ),
          )
          ..on(
            'POST',
            '/api/v1/auth/login',
            (_) => FakeResponse(
              200,
              body: authResponseJson(user: meJson(emailVerified: true)),
            ),
          );
        final repo = container.read(authRepositoryProvider);
        await repo.register(
          email: 'a@b.co',
          password: 'pa55word!',
          username: 'layla_22',
          displayName: 'Layla',
          gender: Gender.female,
          locale: 'ar',
        );
        await repo.verifyRegistration(email: 'a@b.co', code: '12345678');
        await repo.login(identifier: 'layla_22', password: 'pa55word!');

        Map<String, dynamic> deviceOf(String path) =>
            (http.requestsTo('POST', path).single.data
                    as Map<String, dynamic>)['device']
                as Map<String, dynamic>;
        expect(deviceOf('/api/v1/auth/register'), {
          'platform': 'android',
          'appVersion': '1.2.3',
          'installId': 'install-0001-test',
          'deviceKey': key,
        });
        expect(deviceOf('/api/v1/auth/register/verify')['deviceKey'], key);
        expect(
          deviceOf('/api/v1/auth/login').containsKey('deviceKey'),
          isFalse,
        );
      },
    );

    test('without a device id the sign-up is sent without one', () async {
      container.dispose();
      final prefs = await testPrefs();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          installIdProvider.overrideWithValue('install-0001-test'),
          deviceKeySourceProvider.overrideWithValue(_FixedDeviceKey(null)),
        ],
      );
      http.on(
        'POST',
        '/api/v1/auth/register',
        (_) =>
            const FakeResponse(202, body: {'status': 'verification_pending'}),
      );
      await container
          .read(authRepositoryProvider)
          .register(
            email: 'a@b.co',
            password: 'pa55word!',
            username: 'layla_22',
            displayName: 'Layla',
            gender: Gender.female,
            locale: 'en',
          );
      final device =
          (http.requests.single.data as Map<String, dynamic>)['device']
              as Map<String, dynamic>;
      expect(device.containsKey('deviceKey'), isFalse);
    });
  });

  group('the message', () {
    test("Arabic and English (the owner's copy at the default limit)", () {
      final ar = l10nFor(AppLanguage.ar);
      final en = l10nFor(AppLanguage.en);
      expect(ar.errorDeviceAccountLimit, _arCopy);
      expect(en.errorDeviceAccountLimit, _enCopy);
      expect(failureMessage(ar, _limit()), _arCopy);
      expect(failureMessage(en, _limit()), _enCopy);
      // No detail (an older server): the default copy.
      expect(failureMessage(ar, _limit(null)), _arCopy);
      expect(errorCodeMessage(en, ErrorCode.deviceAccountLimit), _enCopy);
    });

    test('a device with an exception names its own limit (ICU plurals)', () {
      final ar = l10nFor(AppLanguage.ar);
      final en = l10nFor(AppLanguage.en);
      expect(
        failureMessage(ar, _limit('3')),
        'لا يمكن إنشاء أكثر من 3 حسابات من نفس الجهاز. '
        'يمكنك تسجيل الدخول إلى حساباتك الحالية.',
      );
      expect(
        failureMessage(ar, _limit('11')),
        startsWith('لا يمكن إنشاء أكثر من 11 حسابًا من نفس الجهاز.'),
      );
      expect(
        failureMessage(ar, _limit('1')),
        startsWith('لا يمكن إنشاء أكثر من حساب واحد من نفس الجهاز.'),
      );
      expect(
        failureMessage(en, _limit('5')),
        'You cannot create more than 5 accounts on the same device. '
        'You can log in to your existing accounts.',
      );
      expect(
        failureMessage(en, _limit('1')),
        startsWith('You cannot create more than one account'),
      );
    });
  });

  group('the sign-up screens', () {
    late FakeAuthRepository repo;
    setUp(() => repo = FakeAuthRepository());

    Future<void> openApp(WidgetTester tester, AppLanguage language) async {
      await pumpKabsoApp(
        tester,
        language: language.name,
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          usernameDebounceProvider.overrideWithValue(Duration.zero),
        ],
      );
      await tester.pumpAndSettle();
      await openRegister(tester);
    }

    Future<void> submitRegister(WidgetTester tester) async {
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
      await tester.enterText(
        find.byKey(RegisterScreen.usernameKey),
        'layla_22',
      );
      await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'ليلى');
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await chooseGender(tester);
      await tester.pump();
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pumpAndSettle();
    }

    for (final (language, copy, rtl) in [
      (AppLanguage.ar, _arCopy, true),
      (AppLanguage.en, _enCopy, false),
    ]) {
      testWidgets('${language.name}: register 409 shows the message and '
          '«${l10nFor(language).registerSignIn}» opens Log in', (tester) async {
        repo.registerFailure = _limit();
        await openApp(tester, language);
        await submitRegister(tester);

        expect(repo.registerCalls, 1);
        expect(find.byType(RegisterCodeScreen), findsNothing);
        expect(find.byKey(DeviceLimitNotice.messageKey), findsOneWidget);
        expect(find.text(copy), findsOneWidget);
        expect(find.byKey(const Key('failure.banner')), findsNothing);
        expect(
          Directionality.of(tester.element(find.text(copy))),
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        final logIn = find.byKey(DeviceLimitNotice.logInKey);
        expect(
          find.descendant(
            of: logIn,
            matching: find.text(l10nFor(language).registerSignIn),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(logIn);
        await tester.tap(logIn);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(RegisterScreen), findsNothing);
      });
    }

    testWidgets('ar: the code screen shows it too (the limit was reached '
        'meanwhile) with «تسجيل الدخول»', (tester) async {
      await openApp(tester, AppLanguage.ar);
      await submitRegister(tester);
      expect(find.byType(RegisterCodeScreen), findsOneWidget);
      repo.verifyFailures.add(_limit());
      await tester.enterText(
        find.byKey(RegisterCodeScreen.codeFieldKey),
        '12345678',
      );
      await tester.pumpAndSettle();
      expect(find.text(_arCopy), findsOneWidget);
      await tester.ensureVisible(find.byKey(DeviceLimitNotice.logInKey));
      await tester.tap(find.byKey(DeviceLimitNotice.logInKey));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      // The email typed at sign-up is ready in Log in.
      expect(find.text('a@b.co'), findsOneWidget);
    });

    testWidgets('en: at 360 wide and text scale 1.3 the message and the '
        'action fit (no overflow)', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      repo.registerFailure = _limit();
      await openApp(tester, AppLanguage.en);
      await submitRegister(tester);
      expect(find.text(_enCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
