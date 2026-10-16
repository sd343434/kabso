// G-26: fake data lives in test/fixtures/** only. Production code must
// never import tests, fixtures or flutter_test, so seeded data can't leak
// into Home/Live (which keep their honest empty states).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no file under lib/ imports test code or fixtures', () {
    final forbidden = RegExp(
      r'''^\s*(import|export|part)\s+['"]([^'"]*(/test/|^\.\./|fixtures|fixture_|package:flutter_test|package:kabso_live/test)[^'"]*)['"]''',
      multiLine: true,
    );
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      for (final match in forbidden.allMatches(file.readAsStringSync())) {
        offenders.add('${file.path}: ${match.group(2)}');
      }
    }
    expect(files, isNotEmpty);
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('fixture identifiers are not referenced from lib/', () {
    // Names exported by test/fixtures/**; a copy-paste into lib/ fails here.
    const names = [
      'liveRooms(',
      'chatLines(',
      'pkSnapshots',
      'fixtureImage(',
      'brokenFixtureImage',
      'viewerCountSamples',
      'hubRooms(',
      'feedPosts(',
      'fixtureNow',
      // KL-038 (test/fixtures/live/live_api_fixtures.dart,
      // test/helpers/fake_live_repository.dart).
      'apiRooms(',
      'apiPage(',
      'apiCategories(',
      'liveRoomSummaryJson(',
      'liveRoomPageJson(',
      'publicProfileJson(',
      'FakeLiveRepository',
      'liveOverrides(',
    ];
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final name in names) {
        if (source.contains(name)) offenders.add('${file.path}: $name');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('production code never constructs live rooms or categories', () {
    // KL-038 (D35/D37): rooms, cards and categories reach the UI only from
    // the v1.3 API (`LiveRoomCardData.fromSummary`). Literal construction is
    // allowed in the debug gallery only (`!kReleaseMode`).
    final literal = RegExp(
      r'(?<![\w.])(LiveRoomCardData|LiveRoomSummary|LiveRoom|LiveCategory|UserSummary)\(',
    );
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.endsWith('.g.dart') &&
                  !f.path.endsWith('.freezed.dart') &&
                  !f.path.contains('features/debug/'),
            )) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!literal.hasMatch(line)) continue;
        // The single mapping from an API room to a card.
        final mapping =
            file.path.endsWith('live_view_data.dart') &&
            line.contains('return LiveRoomCardData(');
        if (!mapping) offenders.add('${file.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
