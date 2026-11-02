// v1.60-live (D250, CONVENTIONS §10.91): live moderation from the panel, the
// app's side — «الإبلاغ عن البث» (a reason and an optional note, LIVE_ROOM),
// the messages of a device ban and of a restriction with the team's reason
// (sign-in, going live), and the LIVE_MODERATED notification (ended, banned
// from going live, suspended, device banned — with the end or «نهائياً» and
// the reason). Arabic and English; goldens of the messages and of the sheet.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_report_sheet.dart';
import 'package:kabso_live/features/medals/application/medals_providers.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final _until = DateTime.utc(2026, 11, 9, 18, 30);
const _reason = 'محتوى غير لائق أثناء البث';

ServerFailure _failure(ErrorCode code, List<FieldIssue> details) =>
    ServerFailure(
      code: code,
      rawCode: code.wire,
      debugMessage: code.wire,
      statusCode: 403,
      details: details,
    );

String _plain(String s) => s.replaceAll(RegExp('[\u2066-\u2069]'), '');

AppNotification _moderated(
  String moderation, {
  DateTime? endsAt,
  bool permanent = false,
  String reason = _reason,
  bool read = false,
}) => AppNotification.fromJson({
  'id': '0192f1d0-0000-7000-8000-0000000002${moderation.length}${read ? 1 : 0}',
  'type': 'LIVE_MODERATED',
  'actors': const <Object>[],
  'actorCount': 0,
  'target': {
    'type': 'LIVE_MODERATION',
    'id': '0192f1d0-9999-7000-8000-000000000250',
    'postId': null,
    'thumbUrl': null,
    'text': reason.length > 80 ? reason.substring(0, 80) : reason,
    'moderation': moderation,
    'reason': reason,
    'roomId': '0192f1d0-8888-7000-8000-000000000250',
    'endsAt': ?endsAt?.toIso8601String(),
    if (permanent) 'permanent': true,
  },
  'createdAt': DateTime.now()
      .subtract(const Duration(minutes: 3))
      .toIso8601String(),
  'read': read,
});

void main() {
  setUpAll(initializeDateFormatting);
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);
  String when(AppLocalizations l, DateTime at) =>
      '${KFormat.date(at, l.localeName)} ${KFormat.time(at, l.localeName)}';

  group('the messages with the team’s reason', () {
    test('DEVICE_BANNED: until when and why, or for good (ar, en)', () {
      final timed = _failure(ErrorCode.deviceBanned, [
        FieldIssue(field: 'until', issue: _until.toIso8601String()),
        const FieldIssue(field: 'reason', issue: _reason),
      ]);
      expect(ErrorCode.fromWire('DEVICE_BANNED'), ErrorCode.deviceBanned);
      expect(
        _plain(failureMessage(ar, timed)),
        _plain(ar.errorDeviceBannedUntil(when(ar, _until), _reason)),
      );
      expect(failureMessage(en, timed), contains('until'));
      expect(_plain(failureMessage(en, timed)), contains('Reason: $_reason'));
      final forever = _failure(ErrorCode.deviceBanned, const [
        FieldIssue(field: 'until', issue: 'permanent'),
        FieldIssue(field: 'reason', issue: 'Ban evasion'),
      ]);
      expect(
        _plain(failureMessage(en, forever)),
        'This device is banned by the Kabso team permanently. '
        'Reason: Ban evasion',
      );
      expect(_plain(failureMessage(ar, forever)), contains('نهائياً'));
      // An older server (no details): the plain sentence.
      expect(
        failureMessage(ar, _failure(ErrorCode.deviceBanned, const [])),
        ar.errorDeviceBanned,
      );
    });

    test('ACCOUNT_RESTRICTED NO_LIVE now says why (going live)', () {
      final f = _failure(ErrorCode.accountRestricted, [
        const FieldIssue(field: 'restriction', issue: 'NO_LIVE'),
        FieldIssue(field: 'until', issue: _until.toIso8601String()),
        const FieldIssue(field: 'reason', issue: _reason),
      ]);
      expect(
        _plain(failureMessage(ar, f)),
        _plain(
          ar.errorAccountRestrictedUntilReason(
            ar.restrictionNoLive,
            when(ar, _until),
            _reason,
          ),
        ),
      );
      expect(_plain(failureMessage(en, f)), endsWith('Reason: $_reason'));
    });
  });

  group('LIVE_MODERATED', () {
    test('parses with its target; system, no tap target, push → inbox', () {
      final n = _moderated('NO_LIVE', endsAt: _until);
      expect(n.type, NotificationType.liveModerated);
      expect(n.type.isSystem, isTrue);
      expect(n.target!.type, NotificationTargetType.liveModeration);
      expect(n.target!.moderation, 'NO_LIVE');
      expect(n.target!.reason, _reason);
      expect(n.target!.endsAt, _until);
      expect(NotificationRow(item: n).routeTo(), isNull);
      expect(
        _moderated('DEVICE_BAN', permanent: true).target!.permanent,
        isTrue,
      );
      expect(
        const PushPayload({'kind': 'notification', 'type': 'LIVE_MODERATED'})
            .route(),
        isNotNull,
      );
    });

    test('the sentence per action (ar, en)', () {
      String text(AppLocalizations l, AppNotification n) =>
          _plain(liveModeratedText(l, n.target, l.localeName));
      final at = _plain(when(en, _until));
      expect(text(en, _moderated('END')), en.notifLiveModeratedEnd);
      expect(
        text(en, _moderated('NO_LIVE', endsAt: _until)),
        _plain(en.notifLiveModeratedNoLive(at)),
      );
      expect(
        text(en, _moderated('SUSPEND', endsAt: _until)),
        _plain(en.notifLiveModeratedSuspend(at)),
      );
      expect(
        text(en, _moderated('DEVICE_BAN', endsAt: _until)),
        _plain(en.notifLiveModeratedDevice(at)),
      );
      expect(
        text(ar, _moderated('DEVICE_BAN', permanent: true)),
        ar.notifLiveModeratedDevicePermanent,
      );
    });
  });

  group('«الإبلاغ عن البث»', () {
    testWidgets('a reason is required; the note is optional; LIVE_ROOM sent', (
      tester,
    ) async {
      final repo = FakeSafetyRepository();
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    unawaited(reportLive(context, ref, roomId: 'room-250')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [safetyRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(en.liveReportTitle), findsOneWidget);
      KButton send() =>
          tester.widget<KButton>(find.byKey(LiveReportSheet.sendKey));
      expect(send().onPressed, isNull);
      await tester.tap(
        find.byKey(LiveReportSheet.reasonKey(ReportReason.harassment)),
      );
      await tester.pump();
      expect(send().onPressed, isNotNull);
      await tester.enterText(
        find.descendant(
          of: find.byKey(LiveReportSheet.noteKey),
          matching: find.byType(EditableText),
        ),
        '  The host insults viewers  ',
      );
      await tester.ensureVisible(find.byKey(LiveReportSheet.sendKey));
      await tester.tap(find.byKey(LiveReportSheet.sendKey));
      await tester.pumpAndSettle();
      expect(
        find.text(en.liveReportSent),
        findsOneWidget,
        reason: '${repo.calls}',
      );
      expect(repo.calls, [
        'reportLive:room-250:HARASSMENT:The host insults viewers',
      ]);
    });
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'live_moderation.messages (${language.name}, ${brightness.name})',
          (tester) async {
            final l = l10nFor(language);
            final banned = failureMessage(
              l,
              _failure(ErrorCode.deviceBanned, [
                FieldIssue(field: 'until', issue: _until.toIso8601String()),
                const FieldIssue(field: 'reason', issue: _reason),
              ]),
            );
            final forever = failureMessage(
              l,
              _failure(ErrorCode.deviceBanned, const [
                FieldIssue(field: 'until', issue: 'permanent'),
                FieldIssue(field: 'reason', issue: 'التهرب من الحظر'),
              ]),
            );
            final noLive = failureMessage(
              l,
              _failure(ErrorCode.accountRestricted, [
                const FieldIssue(field: 'restriction', issue: 'NO_LIVE'),
                FieldIssue(field: 'until', issue: _until.toIso8601String()),
                const FieldIssue(field: 'reason', issue: _reason),
              ]),
            );
            final locked = failureMessage(
              l,
              _failure(ErrorCode.accountLocked, [
                FieldIssue(
                  field: 'lockedUntil',
                  issue: _until.toIso8601String(),
                ),
                const FieldIssue(field: 'reason', issue: 'عُري أثناء البث'),
              ]),
            );
            await pumpGolden(
              tester,
              ProviderScope(
                overrides: [
                  medalCatalogueProvider.overrideWith(
                    (ref) async =>
                        const MedalCatalogue(data: [], total: 0, owned: 0),
                  ),
                ],
                child: ListView(
                  children: [
                    for (final m in [banned, forever, noLive, locked]) ...[
                      KInlineMessage(message: m),
                      const SizedBox(height: KSpacing.sm),
                    ],
                    const SizedBox(height: KSpacing.sm),
                    NotificationRow(item: _moderated('END')),
                    NotificationRow(
                      item: _moderated('NO_LIVE', endsAt: _until),
                    ),
                    NotificationRow(
                      item: _moderated('SUSPEND', endsAt: _until, read: true),
                    ),
                    NotificationRow(
                      item: _moderated(
                        'DEVICE_BAN',
                        permanent: true,
                        reason: 'التهرب من الحظر بحسابات جديدة',
                      ),
                    ),
                  ],
                ),
              ),
              language: language,
              brightness: brightness,
              padding: EdgeInsets.zero,
            );
            await tester.pumpAndSettle();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/png/live_moderation.messages.${brightness.name}.${language.name}.phone.png',
              ),
            );
          },
          tags: goldenTag,
        );
      }
      testWidgets('live_report_sheet (${language.name})', (tester) async {
        await pumpGolden(
          tester,
          const LiveReportSheet(),
          language: language,
          brightness: Brightness.light,
          padding: EdgeInsets.zero,
        );
        await tester.tap(
          find.byKey(LiveReportSheet.reasonKey(ReportReason.harassment)),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/live_report_sheet.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}
