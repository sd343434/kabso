// D356 (CONVENTIONS §10.152): the panel's live preview of the event page —
// the preview entry (`lib/preview_main.dart`) parses the panel's postMessage
// (origin allowed, versioned JSON text, an `EventDetail` with its design),
// places the dates for the asked state, makes SAMPLE boards, and draws the
// app's real `EventDetailScreen`: a design it knows → `EventDesignedPage`; no
// design, an unknown version or layout → today's page; a broken message →
// ignored (the last page stays).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_designed_page.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/preview/event_preview_app.dart';
import 'package:kabso_live/preview/event_preview_protocol.dart';

import '../helpers/pump_app.dart';

const _origin = 'https://admin.example.test';
final _now = DateTime.utc(2026, 11, 10, 12);

Map<String, Object?> _design({int v = 1, String layout = 'STAGE'}) => {
  'v': v,
  'layout': layout,
  'leaderboard': 'PODIUM',
  'countdown': 'FLIP',
  'preset': 'GLASS',
  'rulesButton': {'style': 'GOLD_PILL', 'edge': 'END'},
  'sections': [
    for (final id in ['BOARDS', 'GIFTS', 'RULES', 'REWARDS', 'MILESTONES'])
      {'id': id, 'visible': true},
  ],
  'leaderboardBackgroundMediaId': null,
  'leaderboardBackgroundUrl': null,
  'rewards': null,
  'motion': {'entrance': 'NONE', 'durationMs': 0},
};

Map<String, Object?> _event({Object? design, bool permanent = false}) => {
  'id': 'preview',
  'title': 'ملك الهدايا',
  'rules': 'شارك بإرسال هدايا الفعالية.',
  'metric': 'EVENT_GIFTS',
  'audience': 'EVERYONE',
  'permanent': permanent,
  'featured': true,
  'timeZone': 'Asia/Riyadh',
  'art': {'background': null, 'titleUrl': null, 'overlay': null},
  'gifts': [
    {
      'code': 'rose',
      'name': 'وردة',
      'priceCoins': 100,
      'assetKey': 'rose',
      'imageUrl': null,
      'pointsPerCoin': 1,
      'pointsPerGift': 0,
      'pointsEach': 100,
    },
  ],
  'boards': [
    {
      'kind': 'SENDERS',
      'minPoints': 1000,
      'shown': 20,
      'prizes': [
        {
          'rankFrom': 1,
          'rankTo': 3,
          'items': [
            {'type': 'COINS', 'amount': 1000},
          ],
        },
      ],
    },
  ],
  'milestones': const <Object?>[],
  'design': design,
};

String _message({
  Object? event,
  int v = 1,
  String type = kPreviewRender,
  String? state,
  String language = 'ar',
  bool reduceMotion = true,
}) => jsonEncode({
  'type': type,
  'v': v,
  'seq': 7,
  'language': language,
  'theme': 'dark',
  'state': ?state,
  'reduceMotion': reduceMotion,
  'event': event ?? _event(design: _design()),
});

PreviewParse _parse(Object? data, {String origin = _origin}) =>
    parsePreviewMessage(
      data,
      origin: origin,
      allowedOrigins: {_origin},
      now: _now,
    );

PreviewRequest _request(String message) =>
    (_parse(message) as PreviewOk).request;

void main() {
  group('the message', () {
    test('only an allowed origin and a render message are listened to', () {
      expect(
        _parse(_message(), origin: 'https://evil.test'),
        isA<PreviewIgnored>(),
      );
      expect(_parse({'type': kPreviewRender}), isA<PreviewIgnored>());
      expect(_parse(_message(type: 'other')), isA<PreviewIgnored>());
      expect(previewAllowedOrigins(_origin, ' http://localhost:5180 , '), {
        _origin,
        'http://localhost:5180',
      });
      expect(previewAllowedOrigins('null', ''), isEmpty);
    });

    test('a broken message is reported, never drawn', () {
      expect(_parse('{nope'), isA<PreviewInvalid>());
      expect(_parse('[1]'), isA<PreviewInvalid>());
      final v2 = _parse(_message(v: 2));
      expect(v2, isA<PreviewInvalid>());
      expect((v2 as PreviewInvalid).seq, 7);
      expect(
        _parse(jsonEncode({'type': kPreviewRender, 'v': 1, 'seq': 3})),
        isA<PreviewInvalid>(),
      );
      // Not an EventDetail (no title).
      expect(
        _parse(_message(event: {'id': 'x', 'boards': const <Object?>[]})),
        isA<PreviewInvalid>(),
      );
    });

    test('a render request: the language, theme, state and reduce-motion', () {
      final r = _request(_message(state: 'ENDED', language: 'en'));
      expect(r.seq, 7);
      expect(r.language, AppLanguage.en);
      expect(r.dark, isTrue);
      expect(r.state, PreviewState.ended);
      expect(r.reduceMotion, isTrue);
      expect(r.event.design, isNotNull);
      // An unknown state is a running event.
      expect(_request(_message(state: 'SOMEDAY')).state, PreviewState.running);
    });

    test('an unknown design version or layout is today’s page', () {
      expect(
        _request(_message(event: _event(design: _design(v: 2)))).event.design,
        isNull,
      );
      expect(
        _request(
          _message(
            event: _event(design: _design(layout: 'GRID')),
          ),
        ).event.design,
        isNull,
      );
      expect(_request(_message(event: _event())).event.design, isNull);
    });

    test('the dates follow the state, around now', () {
      EventDetail at(String state, {bool permanent = false}) => _request(
        _message(
          state: state,
          event: _event(permanent: permanent),
        ),
      ).event;
      final upcoming = at('UPCOMING');
      expect(upcoming.status, EventStatus.upcoming);
      expect(upcoming.startsAt.isAfter(_now), isTrue);
      final running = at('RUNNING');
      expect(running.status, EventStatus.running);
      expect(running.endsAt!.difference(_now).inHours, greaterThan(24));
      final last = at('FINAL_HOUR');
      expect(last.endsAt!.difference(_now).inMinutes, inInclusiveRange(1, 59));
      final ended = at('ENDED');
      expect(ended.status, EventStatus.ended);
      expect(ended.endsAt!.isBefore(_now), isTrue);
      expect(at('RUNNING', permanent: true).endsAt, isNull);
      expect(
        previewEventJson(
          {'title': 't'},
          state: PreviewState.running,
          now: _now,
        )['id'],
        kPreviewEventId,
      );
    });

    test('the replies are versioned JSON text', () {
      expect(jsonDecode(previewReply(kPreviewReady)), {
        'type': kPreviewReady,
        'v': 1,
      });
      expect(
        jsonDecode(previewReply(kPreviewRendered, seq: 3, designed: true)),
        {'type': kPreviewRendered, 'v': 1, 'seq': 3, 'designed': true},
      );
    });
  });

  group('the sample boards', () {
    test('12 made-up entrants, the viewer 8th, final when ended', () {
      final b = previewLeaderboard(
        EventBoardKind.senders,
        ar: true,
        ended: true,
        minPoints: 1000,
      );
      expect(b.giftRows, hasLength(12));
      expect(b.myRank, 8);
      expect(b.isFinal, isTrue);
      expect(b.giftRows.first.user.avatarUrl, previewPhotoUrl('avatar_layla'));
      expect(b.giftRows.every((r) => r.score >= 1000), isTrue);
      final cp = previewLeaderboard(
        EventBoardKind.cp,
        ar: false,
        ended: false,
        minPoints: 0,
        photos: false,
      );
      expect(cp.giftRows.first.partner, isNotNull);
      expect(cp.giftRows.first.user.avatarUrl, isNull);
      final agencies = previewLeaderboard(
        EventBoardKind.agencies,
        ar: false,
        ended: false,
        minPoints: 0,
      );
      expect(agencies.giftRows.first.agencyName, 'Sara Agency');
    });

    test('the repository answers the event and boards only', () async {
      final repo = PreviewProgramsRepository(photos: false)
        ..request = _request(_message());
      expect((await repo.event('preview')).title, 'ملك الهدايا');
      expect(
        (await repo.leaderboard('preview', board: 'SENDERS')).minPoints,
        1000,
      );
      expect(repo.tasks, throwsUnsupportedError);
    });
  });

  group('the page', () {
    Future<EventPreviewController> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final controller = EventPreviewController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        EventPreviewApp(
          controller: controller,
          prefs: await testPrefs(language: 'ar'),
          photos: false,
          onRendered: (r, {required designed}) =>
              rendered.add((r.seq, designed)),
        ),
      );
      return controller;
    }

    Future<void> show(
      WidgetTester tester,
      EventPreviewController controller,
      String message,
    ) async {
      controller.value = _request(message);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    setUp(rendered.clear);

    testWidgets('waits for the panel, then draws the designed page with the '
        'sample label', (tester) async {
      final c = await pump(tester);
      expect(find.byKey(EventPreviewApp.waitingKey), findsOneWidget);
      await show(tester, c, _message());
      expect(find.byKey(EventDesignedPage.pageKey), findsOneWidget);
      expect(find.byKey(EventPreviewApp.labelKey), findsOneWidget);
      expect(find.text('معاينة · بيانات المتصدرين تجريبية'), findsOneWidget);
      expect(rendered, [(7, true)]);
      // Reduce motion from the panel.
      final media = MediaQuery.of(
        tester.element(find.byKey(EventDesignedPage.pageKey)),
      );
      expect(media.disableAnimations, isTrue);
    });

    testWidgets('no design or an unknown one: today’s page', (tester) async {
      final c = await pump(tester);
      await show(tester, c, _message(event: _event(design: _design(v: 2))));
      expect(find.byKey(EventDesignedPage.pageKey), findsNothing);
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('ملك الهدايا'), findsWidgets);
      expect(rendered.single.$2, isFalse);
    });

    test('a new section order opens the page afresh (its first tab)', () {
      final a = _request(_message());
      final reordered = _design()
        ..['sections'] = [
          for (final id in [
            'REWARDS',
            'BOARDS',
            'GIFTS',
            'RULES',
            'MILESTONES',
          ])
            {'id': id, 'visible': true},
        ];
      final b = _request(_message(event: _event(design: reordered)));
      final c = _request(
        _message(event: _event(design: _design()..['preset'] = 'NEON')),
      );
      expect(previewPageKey(a), isNot(previewPageKey(b)));
      expect(previewPageKey(a), previewPageKey(c));
      expect(
        previewPageKey(_request(_message(event: _event()))),
        'preview/today',
      );
    });

    testWidgets('a new message redraws in place; English labels', (
      tester,
    ) async {
      final c = await pump(tester);
      await show(tester, c, _message());
      expect(find.byKey(EventDesignedPage.pageKey), findsOneWidget);
      await show(tester, c, _message(event: _event(), language: 'en'));
      expect(find.byKey(EventDesignedPage.pageKey), findsNothing);
      expect(find.text('Preview · sample leaderboard data'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(EventDetailScreen))),
        TextDirection.ltr,
      );
    });
  });
}

final rendered = <(int, bool)>[];
