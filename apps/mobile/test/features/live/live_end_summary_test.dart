import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_end_summary.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/component_harness.dart';

// D140: the full-screen end-of-live summary from the live's statistics
// (`GET /live/rooms/{roomId}/stats`, CONVENTIONS §10.31). Test data only.

UserSummary _user(String name) => UserSummary(
  id: 'user-$name',
  username: name,
  displayName: name,
  avatarUrl: null,
);

LiveRoomStats _stats({
  LiveViewerStats? viewers = const LiveViewerStats(
    unique: 11,
    guests: 1,
    peak: 9,
    atEnd: 0,
    averageWatch: Duration(seconds: 74),
  ),
  List<LiveViewerCountry> countries = const [
    LiveViewerCountry(country: 'SA', viewers: 3, percent: 27.3),
    LiveViewerCountry(country: 'EG', viewers: 2, percent: 18.2),
    LiveViewerCountry(country: 'OTHER', viewers: 4, percent: 36.4),
    LiveViewerCountry(country: 'UNKNOWN', viewers: 2, percent: 18.2),
  ],
  List<LiveStatsSupporter>? top,
  int hostOwnPoints = 0,
}) => LiveRoomStats(
  roomId: 'room-1',
  ended: true,
  startedAt: DateTime.utc(2026, 10, 27, 18),
  endedAt: DateTime.utc(2026, 10, 27, 18, 3, 18),
  duration: const Duration(minutes: 3, seconds: 18),
  total: 2411,
  tapPoints: 11,
  supportPoints: 2400,
  hostOwnPoints: hostOwnPoints,
  supporters: 4,
  topSupporters:
      top ??
      [
        LiveStatsSupporter(user: _user('mona'), points: 1200),
        LiveStatsSupporter(user: _user('omar'), points: 400),
        LiveStatsSupporter(user: _user('huda'), points: 5),
      ],
  giftCount: 6,
  chatMessages: 31,
  newFollowers: 2,
  viewers: viewers,
  viewerCountries: viewers == null ? const [] : countries,
);

Future<void> _pump(
  WidgetTester tester, {
  LiveRoomStats? stats,
  bool loading = false,
  bool failed = false,
  VoidCallback? onRetry,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: GoLiveSummary(
          localDuration: const Duration(minutes: 3, seconds: 17),
          stats: stats,
          loading: loading,
          failed: failed,
          onRetry: onRetry,
          hostName: 'Sara',
          onDone: () {},
          doneKey: const Key('done'),
        ),
      ),
    ),
    language: language,
  );
}

Finder _within(Key key, Finder matching) =>
    find.descendant(of: find.byKey(key), matching: matching);

void main() {
  test(
    'LiveRoomStats.fromJson reads the contract shape (viewers null too)',
    () {
      final json = <String, dynamic>{
        'roomId': 'room-1',
        'status': 'ENDED',
        'startedAt': '2026-10-27T18:00:00.000Z',
        'endedAt': '2026-10-27T18:03:18.000Z',
        'durationSeconds': 198,
        'score': {'total': 2411, 'tapPoints': 11, 'supportPoints': 2400},
        'hostOwnPoints': 801,
        'supporters': 4,
        'topSupporters': [
          {
            'user': {
              'id': 'u1',
              'username': 'sara',
              'displayName': 'سارة',
              'avatarUrl': null,
            },
            'points': 1200,
          },
        ],
        'giftCount': 6,
        'chatMessages': 3,
        'newFollowers': 2,
        'viewers': {
          'unique': 11,
          'guests': 1,
          'peak': 11,
          'atEnd': 0,
          'averageWatchSeconds': 74,
        },
        'viewerCountries': [
          {'country': 'SA', 'viewers': 3, 'percent': 27.3},
          {'country': 'UNKNOWN', 'viewers': 2, 'percent': 18},
        ],
      };
      final s = LiveRoomStats.fromJson(json);
      expect(s.ended, isTrue);
      expect(s.duration, const Duration(seconds: 198));
      expect((s.total, s.tapPoints, s.supportPoints), (2411, 11, 2400));
      expect(s.hostOwnPoints, 801);
      expect(s.topSupporters.single.user.username, 'sara');
      expect(s.viewers!.averageWatch, const Duration(seconds: 74));
      expect(s.viewerCountries.last.percent, 18.0);
      final legacy = LiveRoomStats.fromJson({
        ...json,
        'status': 'LIVE',
        'endedAt': null,
        'viewers': null,
        'viewerCountries': const <Object>[],
      });
      expect(legacy.ended, isFalse);
      expect(legacy.endedAt, isNull);
      expect(legacy.viewers, isNull);
    },
  );

  testWidgets('shows the totals, the split, the tiles and the done button', (
    tester,
  ) async {
    await _pump(tester, stats: _stats(hostOwnPoints: 801));
    expect(find.text('2,411'), findsOneWidget);
    expect(_within(GoLiveSummary.giftsKey, find.text('2,400')), findsOneWidget);
    expect(_within(GoLiveSummary.tapsKey, find.text('11')), findsOneWidget);
    expect(find.textContaining('801'), findsOneWidget);
    expect(_within(GoLiveSummary.viewersKey, find.text('11')), findsOneWidget);
    expect(_within(GoLiveSummary.peakKey, find.text('9')), findsOneWidget);
    expect(_within(GoLiveSummary.followersKey, find.text('2')), findsOneWidget);
    expect(_within(GoLiveSummary.chatKey, find.text('31')), findsOneWidget);
    expect(_within(GoLiveSummary.giftCountKey, find.text('6')), findsOneWidget);
    expect(
      _within(GoLiveSummary.supportersKey, find.text('4')),
      findsOneWidget,
    );
    // The server's duration wins over the app's own count, and the average
    // watch time reads m:ss.
    expect(find.text('3:18'), findsOneWidget);
    expect(find.text('1:14'), findsOneWidget);
    expect(find.byKey(const Key('done')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('countries: flags, names and shares as sent, OTHER and UNKNOWN '
      'last', (tester) async {
    await _pump(tester, stats: _stats());
    await tester.scrollUntilVisible(
      find.byKey(GoLiveSummary.countryKey('UNKNOWN')),
      200,
    );
    for (final (code, name, percent) in const [
      ('SA', 'Saudi Arabia', '27.3%'),
      ('EG', 'Egypt', '18.2%'),
      ('OTHER', 'Other countries', '36.4%'),
      ('UNKNOWN', 'Not shared', '18.2%'),
    ]) {
      final row = GoLiveSummary.countryKey(code);
      expect(_within(row, find.text(name)), findsOneWidget, reason: code);
      expect(_within(row, find.text(percent)), findsOneWidget, reason: code);
    }
    expect(
      _within(GoLiveSummary.countryKey('SA'), find.byType(Image)),
      findsOneWidget,
    );
    final ys = [
      for (final c in ['SA', 'EG', 'OTHER', 'UNKNOWN'])
        tester.getTopLeft(find.byKey(GoLiveSummary.countryKey(c))).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(
      find.textContaining('Shares of all viewers (\u206811\u2069)'),
      findsOneWidget,
    );
  });

  testWidgets('the podium: first in the middle, second at the start', (
    tester,
  ) async {
    await _pump(tester, stats: _stats());
    await tester.scrollUntilVisible(find.byKey(GoLiveSummary.podiumKey), 200);
    final first = tester.getCenter(find.text('mona'));
    final second = tester.getCenter(find.text('omar'));
    final third = tester.getCenter(find.text('huda'));
    expect(second.dx, lessThan(first.dx));
    expect(third.dx, greaterThan(first.dx));
  });

  testWidgets('no viewers: a quiet line and no countries; no supporters: a '
      'line', (tester) async {
    await _pump(
      tester,
      stats: _stats(
        viewers: const LiveViewerStats(
          unique: 0,
          guests: 0,
          peak: 0,
          atEnd: 0,
          averageWatch: Duration.zero,
        ),
        countries: const [],
        top: const [],
      ),
    );
    expect(find.byKey(GoLiveSummary.noViewersKey), findsOneWidget);
    expect(find.byKey(GoLiveSummary.countriesKey), findsNothing);
    await tester.scrollUntilVisible(find.byKey(GoLiveSummary.podiumKey), 200);
    expect(find.textContaining('No supporters this time'), findsOneWidget);
  });

  testWidgets('a live from before D140: no audience tiles, no countries', (
    tester,
  ) async {
    await _pump(tester, stats: _stats(viewers: null));
    expect(find.byKey(GoLiveSummary.viewersKey), findsNothing);
    expect(find.byKey(GoLiveSummary.peakKey), findsNothing);
    expect(find.byKey(GoLiveSummary.countriesKey), findsNothing);
    expect(find.byKey(GoLiveSummary.noViewersKey), findsNothing);
    expect(find.byKey(GoLiveSummary.followersKey), findsOneWidget);
  });

  testWidgets('loading: placeholders, the app duration and done', (
    tester,
  ) async {
    await _pump(tester, loading: true);
    expect(find.byKey(GoLiveSummary.loadingKey), findsOneWidget);
    expect(find.byKey(GoLiveSummary.pointsKey), findsNothing);
    expect(find.byKey(const Key('done')), findsOneWidget);
  });

  testWidgets('error: the app duration, a retry that reads again, and done', (
    tester,
  ) async {
    var retries = 0;
    await _pump(tester, failed: true, onRetry: () => retries++);
    expect(find.byKey(GoLiveSummary.errorKey), findsOneWidget);
    expect(find.text('3:17'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(find.byKey(const Key('done')), findsOneWidget);
  });

  testWidgets('Arabic: right to left, names in Arabic, numbers in Latin', (
    tester,
  ) async {
    await _pump(tester, stats: _stats(), language: AppLanguage.ar);
    expect(find.text('2,411'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(GoLiveSummary.countryKey('SA')),
      200,
    );
    final row = GoLiveSummary.countryKey('SA');
    expect(_within(row, find.text('المملكة العربية السعودية')), findsOneWidget);
    final flag = tester.getCenter(_within(row, find.byType(Image)));
    final name = tester.getCenter(
      _within(row, find.text('المملكة العربية السعودية')),
    );
    final percent = tester.getCenter(_within(row, find.text('27.3%')));
    expect(flag.dx, greaterThan(name.dx));
    expect(percent.dx, lessThan(name.dx));
    expect(tester.takeException(), isNull);
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: 360×800 at text scale 1.3 without overflow '
        '(every section scrolled through)', (tester) async {
      await _pump(
        tester,
        stats: _stats(hostOwnPoints: 801),
        language: language,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byKey(GoLiveSummary.podiumKey), 300);
      expect(tester.takeException(), isNull);
      // The done button stays on screen, above the scrolled content.
      final done = tester.getRect(find.byKey(const Key('done')));
      expect(done.bottom, lessThanOrEqualTo(800));
    });
  }
}
