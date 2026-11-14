// Owner D111 ("CP pair on seats"): two CP partners on adjacent audio seats
// are joined by a translucent band behind their pictures with an ornament
// between them — rows of 5 (consecutive tiles of a row, the host tile 0;
// every room size since D118). Partners apart, one partner seated
// (the API lists no couple) or no couple: nothing drawn. Arabic mirrors the
// layout; at 360 × 800 with 20 seats (D123: full size) nothing overflows and
// the ornaments never cover a picture or a name.
//
// Owner D113: the couple's level frame (levels 1–6) is cut into a left ring,
// a right ring and a centre piece: each ring's hole sits exactly on its
// partner's picture (the visually left partner gets the left ring, also in
// Arabic), clipped to the tile and above the name; the centre piece is the
// ornament. The amendment: a light animation of the owner's small parts
// around each pair, richer with the level, never over a picture, a name or
// a mic badge, still with reduced motion.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_mic_effect.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seat_fx.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _user(int i) => UserSummary(
  id: 'u$i',
  username: 'u$i',
  displayName: 'Guest $i',
  avatarUrl: null,
);

/// Every seat of a [count]-tile room taken by `Guest <index>`.
List<LiveSeat> _full(int count) => [
  for (var i = 1; i < count; i++)
    LiveSeat(index: i, state: LiveSeatState.taken, user: _user(i)),
];

Future<void> _ring(
  WidgetTester tester,
  int count,
  List<CpSeatPair> pairs, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  Set<int> micOff = const {},
  Set<int> speaking = const {},
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: AudioSeatRing(
          count: count,
          host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
          hostName: 'Layla',
          hostPoints: '0',
          seats: _full(count),
          cpPairs: pairs,
          micOff: micOff,
          speaking: speaking,
          onSeat: (_) {},
        ),
      ),
    ),
    language: language,
  );
  await tester.pumpAndSettle();
}

/// D115: the CP mic effect on tile [i].
Finder _micOn(int i) => find.descendant(
  of: find.byKey(AudioSeatRing.seatKey(i)),
  matching: find.byType(CpMicEffect),
);

/// A 10-seat room (two rows) without settling (the animation may run).
Future<void> _ringNoSettle(
  WidgetTester tester,
  List<CpSeatPair> pairs,
  AppLanguage language,
) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: AudioSeatRing(
        count: 10,
        host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
        hostName: 'Layla',
        seats: _full(10),
        cpPairs: pairs,
      ),
    ),
    language: language,
  );
  await tester.pump();
}

Finder _band(int a, int b) => find.byKey(AudioSeatRing.cpBandKey(a, b));
Finder _ornament(int a, int b) => find.byKey(AudioSeatRing.cpOrnamentKey(a, b));
Finder _ringOf(int a, int b, {required bool left}) =>
    find.byKey(AudioSeatRing.cpRingKey(a, b, left: left));

/// The asset an [Image.asset] under [f] shows.
String _assetUnder(WidgetTester tester, Finder f) {
  final image = tester.widget<Image>(
    find.descendant(of: f, matching: find.byType(Image)).first,
  );
  return (image.image as AssetImage).assetName;
}

/// D113: the rings of (a, b) — the left one on the visually left picture,
/// each hole exactly on its picture, the art shown only within the tile
/// (a tile wide) and above the name, from the [level] frame.
void _expectRings(WidgetTester tester, int a, int b, {int level = 1}) {
  final frame = CpSeatFrames.forLevel(level);
  final pa = _picture(tester, a);
  final pb = _picture(tester, b);
  // A tile is the distance between neighbours (D118: always rows).
  final cell = (pa.center - pb.center).distance / (pa.width / 50);
  final leftTile = pa.center.dx <= pb.center.dx ? a : b;
  for (final left in [true, false]) {
    final tile = left == (leftTile == a) ? a : b;
    final picture = _picture(tester, tile);
    final ring = _ringOf(a, b, left: left);
    expect(ring, findsOneWidget, reason: 'ring ${left ? 'l' : 'r'}');
    final piece = left ? frame.left : frame.right;
    expect(_assetUnder(tester, ring), piece.asset);
    // The whole piece (unclipped): its hole is the picture.
    final art = tester.getRect(
      find.descendant(of: ring, matching: find.byType(Image)).first,
    );
    final scale = art.width / piece.size.width;
    final hole = art.topLeft + piece.hole * scale;
    expect(hole.dx, closeTo(picture.center.dx, 0.5));
    expect(hole.dy, closeTo(picture.center.dy, 0.5));
    expect(piece.holeDiameter * scale, closeTo(picture.width, 0.5));
    // Rows: what shows stays within the tile, above the name.
    final shown = tester.getRect(ring);
    final s = picture.width / 50;
    expect(
      shown.left,
      greaterThanOrEqualTo(picture.center.dx - cell / 2 * s - 0.5),
    );
    expect(
      shown.right,
      lessThanOrEqualTo(picture.center.dx + cell / 2 * s + 0.5),
    );
    expect(shown.bottom, lessThanOrEqualTo(_name(tester, tile).top + 0.5));
  }
}

Rect _picture(WidgetTester tester, int i) => tester.getRect(
  find
      .descendant(
        of: find.byKey(AudioSeatRing.seatKey(i)),
        matching: find.byType(ClipOval),
      )
      .first,
);

Rect _name(WidgetTester tester, int i) => tester.getRect(
  find.descendant(
    of: find.byKey(AudioSeatRing.seatKey(i)),
    matching: find.text(i == 0 ? 'Layla' : 'Guest $i'),
  ),
);

/// The animation parts of (a, b) on screen.
List<Rect> _fxParts(WidgetTester tester, int a, int b) {
  final ornament = find
      .descendant(
        of: find.byKey(AudioSeatRing.cpOrnamentKey(a, b)),
        matching: find.byType(Image),
      )
      .evaluate()
      .toSet();
  return [
    for (final e
        in find
            .descendant(
              of: find.byKey(CpPairFx.keyFor(a, b)),
              matching: find.byType(Image),
            )
            .evaluate())
      if (!ornament.contains(e)) _rectOf(e),
  ];
}

Rect _rectOf(Element e) {
  final box = e.renderObject! as RenderBox;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// No part of (a, b)'s animation covers a picture, a name or a mic badge of
/// the room's [count] tiles.
void _expectFxClear(WidgetTester tester, int a, int b, int count) {
  final badges = find.byIcon(Icons.mic_off_rounded).evaluate().isEmpty
      ? <Rect>[]
      : [
          for (final e in find.byIcon(Icons.mic_off_rounded).evaluate())
            _rectOf(e).inflate(3),
        ];
  for (final part in _fxParts(tester, a, b)) {
    final r = part.deflate(0.5);
    for (var i = 0; i < count; i++) {
      final p = _picture(tester, i);
      final c = p.center;
      final nx = c.dx.clamp(r.left, r.right);
      final ny = c.dy.clamp(r.top, r.bottom);
      final d2 = (c.dx - nx) * (c.dx - nx) + (c.dy - ny) * (c.dy - ny);
      expect(
        d2,
        greaterThanOrEqualTo(p.width * p.width / 4 - 0.5),
        reason: 'fx part covers picture $i',
      );
      expect(
        _name(tester, i).deflate(0.5).overlaps(r),
        isFalse,
        reason: 'fx part covers the name of $i',
      );
    }
    for (final badge in badges) {
      expect(
        badge.deflate(0.5).overlaps(r),
        isFalse,
        reason: 'fx part covers a mic badge',
      );
    }
  }
}

/// The ornament of (a, b) sits between the two pictures and covers no
/// picture and no name of the room.
/// Owner D113: the ornament of (a, b) is exactly in the middle of the two
/// pictures, 62 pt wide at the room's full size, upright and never
/// mirrored, and the partners' names, mic-off badges and "Host" tag are
/// painted above it. Returns its width.
double _expectOrnamentClear(WidgetTester tester, int a, int b, int count) {
  final o = tester.getRect(_ornament(a, b));
  final pa = _picture(tester, a);
  final pb = _picture(tester, b);
  final mid = Offset.lerp(pa.center, pb.center, 0.5)!;
  expect(o.center.dx, closeTo(mid.dx, 0.5));
  expect(o.center.dy, closeTo(mid.dy, 0.5));
  final scale = pa.width / 50;
  expect(o.width, closeTo(AudioSeatRing.cpOrnamentSize * scale, 0.5));
  // Upright: no turn, no mirror.
  final art = find
      .descendant(of: _ornament(a, b), matching: find.byType(Image))
      .evaluate()
      .single;
  final m = (art.renderObject! as RenderBox).getTransformTo(null);
  expect(m.entry(0, 1).abs(), lessThan(1e-6));
  expect(m.entry(1, 0).abs(), lessThan(1e-6));
  expect(m.entry(0, 0), greaterThan(0));
  expect(m.entry(1, 1), greaterThan(0));
  // Painted after the ornament (above it): each partner's name, badge and
  // tag, in tree order.
  for (final i in [a, b]) {
    final texts =
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(AudioSeatRing.seatKey(i)),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .toSet()
          // Not the picture's own letters (the picture stays under it).
          ..removeAll(
            tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.descendant(
                      of: find.byKey(AudioSeatRing.seatKey(i)),
                      matching: find.byType(ClipOval),
                    ),
                    matching: find.byType(Text),
                  ),
                )
                .map((t) => t.data),
          );
    for (final text in texts) {
      final order = find
          .byWidgetPredicate(
            (w) =>
                w.key == AudioSeatRing.cpOrnamentKey(a, b) ||
                (w is Text && w.data == text),
          )
          .evaluate()
          .toList();
      expect(order.last.widget, isA<Text>(), reason: '"$text" of $i above');
    }
  }
  return o.width;
}

void main() {
  group('data', () {
    Map<String, Object?> json({List<Object?>? couples}) => {
      'roomId': 'room-0',
      'mode': 'AUDIO',
      'version': 3,
      'seatCount': 10,
      'seats': [
        {
          'index': 1,
          'state': 'TAKEN',
          'user': {
            'id': 'u1',
            'username': 'u1',
            'displayName': 'Guest 1',
            'avatarUrl': null,
          },
          'mutedByHost': false,
        },
        {
          'index': 2,
          'state': 'TAKEN',
          'user': {
            'id': 'u2',
            'username': 'u2',
            'displayName': 'Guest 2',
            'avatarUrl': null,
          },
          'mutedByHost': false,
        },
        for (var i = 3; i < 10; i++)
          {'index': i, 'state': 'EMPTY', 'user': null, 'mutedByHost': false},
      ],
      'moderators': <Object?>[],
      'couples': ?couples,
    };

    test('LiveSeats reads couples (v1.23.3-live), empty from an older API', () {
      final seats = LiveSeats.fromJson(
        json(
          couples: [
            {
              'userIds': ['u1', 'u2'],
              'level': 3,
              'levelName': 'Gold couple',
            },
          ],
        ),
      );
      expect(seats.couples, [
        const LiveSeatCouple(
          userIds: ['u1', 'u2'],
          level: 3,
          levelName: 'Gold couple',
        ),
      ]);
      expect(LiveSeats.fromJson(json()).couples, isEmpty);
    });

    test('D115: couples carry their privileges; MIC_EFFECT marks the pair', () {
      final seats = LiveSeats.fromJson(
        json(
          couples: [
            {
              'userIds': ['u1', 'u2'],
              'level': 3,
              'levelName': 'Gold couple',
              'privileges': ['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT'],
            },
          ],
        ),
      );
      expect(seats.couples.single.privileges, contains('MIC_EFFECT'));
      expect(cpSeatPairs(seats, hostId: 'host').single.micEffect, isTrue);
      final older = LiveSeats.fromJson(
        json(
          couples: [
            {
              'userIds': ['u1', 'u2'],
              'level': 3,
              'levelName': 'Gold couple',
            },
          ],
        ),
      );
      expect(older.couples.single.privileges, isEmpty);
      expect(cpSeatPairs(older, hostId: 'host').single.micEffect, isFalse);
    });

    test('cpSeatPairs: the host is tile 0, seats their index; a partner not '
        'on a tile drops the couple', () {
      final seats = LiveSeats.fromJson(
        json(
          couples: [
            {
              'userIds': ['u2', 'u1'],
              'level': 2,
              'levelName': 'Silver couple',
            },
            {
              'userIds': ['host', 'u1'],
              'level': 1,
              'levelName': 'x',
            },
            {
              'userIds': ['u2', 'gone'],
              'level': 1,
              'levelName': 'x',
            },
          ],
        ),
      );
      expect(cpSeatPairs(seats, hostId: 'host'), const [
        CpSeatPair(1, 2, level: 2, levelName: 'Silver couple'),
        CpSeatPair(0, 1, levelName: 'x'),
      ]);
      expect(cpSeatPairs(null, hostId: 'host'), isEmpty);
    });

    test('adjacency (D118: rows of 5 for every size): the same row, '
        'consecutive; no ring closing any more', () {
      bool rows(int a, int b, [int count = 25]) =>
          cpRowsAdjacent(CpSeatPair(a, b), count: count);
      expect(rows(0, 1), isTrue);
      expect(rows(3, 4), isTrue);
      expect(rows(4, 5), isFalse, reason: 'two rows');
      expect(rows(5, 7), isFalse);
      expect(rows(23, 24), isTrue);
      expect(rows(14, 15, 15), isFalse, reason: 'tile 15 does not exist');

      // 5 and 10 tiles are rows too (they were a circle before D118).
      expect(rows(0, 1, 5), isTrue, reason: 'the host is a tile of the row');
      expect(rows(3, 4, 5), isTrue);
      expect(rows(4, 5, 10), isFalse, reason: 'two rows');
      expect(rows(8, 9, 10), isTrue);
      expect(rows(1, 9, 10), isFalse, reason: 'no ring closing');
    });

    test('the ornament box: the exact midpoint, its width, the art aspect', () {
      final rect = cpOrnamentRect(
        const Offset(10, 20),
        const Offset(88, 60),
        size: 62,
        aspect: 1.25,
      );
      expect(rect.center, const Offset(49, 40));
      expect(rect.width, 62);
      expect(rect.height, closeTo(49.6, 1e-9));
    });

    test(
      'D113: one frame per CP level 1–6, cut in a left ring, a right '
      'ring and a centre piece, all bundled; other levels use the nearest',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('    - assets/live_cp_seats/\n'));
        expect(CpSeatFrames.levels, [1, 2, 3, 4, 5, 6]);
        final assets = <String>{};
        for (final level in CpSeatFrames.levels) {
          final f = CpSeatFrames.forLevel(level);
          for (final piece in [f.left, f.right]) {
            // The hole lies inside the piece and is a picture-sized circle.
            expect(piece.hole.dx - piece.holeDiameter / 2, greaterThan(0));
            expect(
              piece.hole.dx + piece.holeDiameter / 2,
              lessThan(piece.size.width),
            );
            expect(piece.holeDiameter, inInclusiveRange(140, 160));
            expect(piece.asset, contains('level_${level}_ring_'));
            // rectFor puts the hole on the picture.
            final r = piece.rectFor(const Offset(100, 50), 50);
            expect(
              r.left + piece.hole.dx * r.width / piece.size.width,
              closeTo(100, 1e-9),
            );
            expect(
              r.width * piece.holeDiameter / piece.size.width,
              closeTo(50, 1e-9),
            );
          }
          expect(f.left.asset, endsWith('_ring_l.webp'));
          expect(f.right.asset, endsWith('_ring_r.webp'));
          expect(f.center, 'assets/live_cp_seats/level_${level}_center.webp');
          expect(f.centerAspect, inInclusiveRange(0.8, 1.6));
          assets.addAll([f.left.asset, f.right.asset, f.center]);
        }
        expect(assets, hasLength(18));
        for (final a in assets) {
          expect(File(a).existsSync(), isTrue, reason: a);
        }
        expect(CpSeatFrames.forLevel(0), same(CpSeatFrames.forLevel(1)));
        expect(CpSeatFrames.forLevel(7), same(CpSeatFrames.forLevel(6)));
      },
    );
  });

  for (final language in [AppLanguage.en, AppLanguage.ar]) {
    final ar = language == AppLanguage.ar;
    group(language.name, () {
      testWidgets('rows (15): adjacent pairs joined (the host too), pairs '
          'apart and across rows not', (tester) async {
        await _ring(tester, 15, const [
          CpSeatPair(0, 1),
          CpSeatPair(2, 3),
          CpSeatPair(4, 5), // the end of row 1 and the start of row 2
          CpSeatPair(7, 9), // apart
        ], language: language);
        expect(find.byType(CpBand), findsNWidgets(2));
        for (final (a, b) in [(0, 1), (2, 3)]) {
          expect(_band(a, b), findsOneWidget);
          expect(_ornament(a, b), findsOneWidget);
          final band = tester.getRect(_band(a, b));
          // Behind both pictures, from one to the other.
          expect(band.contains(_picture(tester, a).center), isTrue);
          expect(band.contains(_picture(tester, b).center), isTrue);
          expect(
            band.left,
            lessThanOrEqualTo(
              [
                _picture(tester, a).left,
                _picture(tester, b).left,
              ].reduce((x, y) => x < y ? x : y),
            ),
          );
          // Above the names.
          expect(band.bottom, lessThanOrEqualTo(_name(tester, a).top + 0.5));
          _expectOrnamentClear(tester, a, b, 15);
          _expectRings(tester, a, b);
        }
        expect(_band(4, 5), findsNothing);
        expect(_band(7, 9), findsNothing);
        // Reading order: in Arabic tile 1 is left of tile 0.
        final host = _picture(tester, 0).center.dx;
        final one = _picture(tester, 1).center.dx;
        expect(ar ? one < host : one > host, isTrue);
        expect(tester.takeException(), isNull);
      });

      for (final count in [5, 10]) {
        testWidgets('rows ($count, D118: no circle): neighbours in a row '
            'joined (the host too); pairs apart or across rows not', (
          tester,
        ) async {
          await _ring(tester, count, [
            const CpSeatPair(0, 1),
            const CpSeatPair(2, 3),
            if (count == 10) ...const [
              CpSeatPair(5, 6),
              CpSeatPair(4, 5), // the end of row 1 and the start of row 2
              CpSeatPair(1, 9), // no ring closing any more
            ],
          ], language: language);
          final joined = [(0, 1), (2, 3), if (count == 10) (5, 6)];
          expect(find.byType(CpBand), findsNWidgets(joined.length));
          for (final (a, b) in joined) {
            expect(_band(a, b), findsOneWidget);
            expect(_ornament(a, b), findsOneWidget);
            _expectOrnamentClear(tester, a, b, count);
            _expectRings(tester, a, b);
          }
          expect(_band(4, 5), findsNothing);
          expect(_band(1, 9), findsNothing);
          // Every tile of a row on one line, the host first.
          final top = _picture(tester, 0).center.dy;
          for (var i = 1; i < 5; i++) {
            expect(_picture(tester, i).center.dy, closeTo(top, 0.5));
          }
          if (count == 10) {
            expect(_picture(tester, 5).center.dy, greaterThan(top + 50));
          }
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('D113: every CP level 1–6 draws its own frame, in rooms of '
          '15 and 10', (tester) async {
        await _ring(tester, 15, const [
          CpSeatPair(0, 1, level: 6, levelName: 'Eternal couple'),
          CpSeatPair(2, 3, level: 2),
          CpSeatPair(5, 6, level: 3),
          CpSeatPair(8, 9, level: 4),
          CpSeatPair(10, 11, level: 5),
          CpSeatPair(13, 14),
        ], language: language);
        for (final (a, b, level) in [
          (0, 1, 6),
          (2, 3, 2),
          (5, 6, 3),
          (8, 9, 4),
          (10, 11, 5),
          (13, 14, 1),
        ]) {
          _expectRings(tester, a, b, level: level);
          _expectFxClear(tester, a, b, 15);
          expect(
            _assetUnder(tester, _ornament(a, b)),
            CpSeatFrames.forLevel(level).center,
          );
          final w = _expectOrnamentClear(tester, a, b, 15);
          // Reports the sizes reached (owner D113 feedback asks for them).
          // ignore: avoid_print
          print('D113 rows ornament L$level ($a, $b): ${w.toStringAsFixed(1)}');
        }
        expect(find.bySemanticsLabel('Eternal couple'), findsOneWidget);
        // Arabic mirrors the placement, never the art: tile 1 is left of the
        // host there, so it wears the left ring.
        final hostLeft =
            _picture(tester, 0).center.dx < _picture(tester, 1).center.dx;
        expect(hostLeft, !ar);
        expect(tester.takeException(), isNull);

        final fxCounts = <int, int>{};
        for (final level in CpSeatFrames.levels) {
          await _ring(tester, 10, [
            CpSeatPair(3, 4, level: level),
            CpSeatPair(6, 7, level: level),
          ], language: language);
          for (final (a, b) in [(3, 4), (6, 7)]) {
            _expectRings(tester, a, b, level: level);
            final w = _expectOrnamentClear(tester, a, b, 10);
            // Reports the sizes reached (owner D113 feedback asks for them).
            // ignore: avoid_print
            print(
              'D113 10-seat ornament L$level ($a, $b): '
              '${w.toStringAsFixed(1)}',
            );
            _expectFxClear(tester, a, b, 10);
            fxCounts[level] =
                (fxCounts[level] ?? 0) + _fxParts(tester, a, b).length;
          }
          expect(tester.takeException(), isNull);
        }
        // Every level animates something, and richness grows with it.
        expect(fxCounts[1], greaterThan(0));
        expect(fxCounts[6], greaterThan(fxCounts[1]!));
        expect(fxCounts[5], greaterThan(fxCounts[2]!));
      });

      testWidgets('D113 animation: ticks only while allowed — still with '
          'reduced motion', (tester) async {
        addTearDown(() {
          CpPairFx.animate = false;
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        });
        CpPairFx.animate = true;
        await _ringNoSettle(tester, const [
          CpSeatPair(3, 4, level: 6),
        ], language);
        final before = _fxParts(tester, 3, 4);
        expect(before, isNotEmpty);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(_fxParts(tester, 3, 4), isNot(equals(before)));
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await _ringNoSettle(tester, const [
          CpSeatPair(3, 4, level: 6),
        ], language);
        final still = _fxParts(tester, 3, 4);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(_fxParts(tester, 3, 4), equals(still));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('D115: a speaking partner of a couple with MIC_EFFECT gets '
          'the CP mic effect instead of the glow (adjacent or not); others '
          'keep the glow', (tester) async {
        await _ring(
          tester,
          10,
          const [
            CpSeatPair(2, 3, level: 3, micEffect: true),
            CpSeatPair(5, 8, level: 4, micEffect: true), // apart
            CpSeatPair(6, 7, level: 2), // no MIC_EFFECT yet
          ],
          language: language,
          speaking: const {2, 8, 6, 9},
          micOff: const {2},
        );
        expect(_micOn(2), findsOneWidget);
        expect(_micOn(3), findsNothing, reason: 'not speaking');
        expect(_micOn(8), findsOneWidget, reason: 'partners apart too');
        expect(_micOn(6), findsNothing, reason: 'level 2: no mic effect');
        expect(_micOn(9), findsNothing, reason: 'no couple');
        // The effect (rings, glow, hearts) shows only in its area: the tile,
        // down to the name's top; it never reaches a name or another
        // seat's picture. Hearts: 4–6 in view; the badge ~18 pt.
        for (final i in [2, 8]) {
          final picture = _picture(tester, i);
          final effect = find.descendant(
            of: find.byKey(AudioSeatRing.seatKey(i)),
            matching: find.byType(CpMicEffect),
          );
          final areas = [
            for (final e
                in find
                    .descendant(of: effect, matching: find.byType(ShaderMask))
                    .evaluate())
              _rectOf(e),
          ];
          expect(areas, hasLength(2));
          final badge = _rectOf(
            find
                .descendant(of: effect, matching: find.byType(Image))
                .evaluate()
                .last,
          );
          expect(badge.width, closeTo(18, 0.5));
          for (final r in [...areas, badge]) {
            expect(r.left, greaterThanOrEqualTo(picture.center.dx - 36 - 0.5));
            expect(r.right, lessThanOrEqualTo(picture.center.dx + 36 + 0.5));
            for (var n = 0; n < 10; n++) {
              expect(
                _name(tester, n).deflate(0.5).overlaps(r),
                isFalse,
                reason: 'mic effect of $i covers the name of $n',
              );
              if (n == i) continue;
              expect(
                cpEllipseHits(
                  CpCircleObstacle(
                    _picture(tester, n).center,
                    _picture(tester, n).width / 2,
                  ),
                  r.deflate(0.5),
                ),
                isFalse,
                reason: 'mic effect of $i reaches the picture of $n',
              );
            }
          }
          final hearts = tester
              .widgetList<Opacity>(
                find.descendant(of: effect, matching: find.byType(Opacity)),
              )
              .where((o) => o.opacity > 0.15);
          expect(hearts.length, inInclusiveRange(4, 6));
        }
        expect(
          find.descendant(
            of: find.byKey(AudioSeatRing.seatKey(2)),
            matching: find.byIcon(Icons.mic_off_rounded),
          ),
          findsOneWidget,
        );
        // Rows: the host as a partner.
        await _ring(
          tester,
          15,
          const [CpSeatPair(0, 1, level: 6, micEffect: true)],
          language: language,
          speaking: const {0},
        );
        expect(_micOn(0), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('D115: the mic effect animates only while allowed', (
        tester,
      ) async {
        addTearDown(() {
          CpMicEffect.animate = false;
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        });
        CpMicEffect.animate = true;
        Future<void> pump() async {
          setViewport(tester, GoldenViewport.phone);
          await pumpScreen(
            tester,
            Scaffold(
              body: AudioSeatRing(
                count: 10,
                host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
                hostName: 'Layla',
                seats: _full(10),
                speaking: const {2},
                cpPairs: const [CpSeatPair(2, 3, level: 3, micEffect: true)],
              ),
            ),
            language: language,
          );
          await tester.pump();
        }

        await pump();
        expect(_micOn(2), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox.shrink());

        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await pump();
        expect(_micOn(2), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('no couple, or one partner seated (the API lists none): '
          'nothing drawn', (tester) async {
        await _ring(tester, 10, const [], language: language);
        expect(find.byType(CpBand), findsNothing);
        expect(find.byType(CpOrnament), findsNothing);
        await _ring(tester, 20, const [], language: language);
        expect(find.byType(CpBand), findsNothing);
      });

      testWidgets('360 × 800, 20 seats (the most since D123), every adjacent '
          'pair joined, mics off: no overflow, ornaments clear of pictures '
          'and names', (tester) async {
        final pairs = [
          for (var first = 0; first < 20; first += 5) ...[
            CpSeatPair(first, first + 1),
            CpSeatPair(first + 2, first + 3),
          ],
        ];
        setViewport(tester, GoldenViewport.android);
        await pumpScreen(
          tester,
          Scaffold(
            body: LiveAudioRoomLayout(
              header: const SizedBox(height: 48),
              chips: const SizedBox(height: 32),
              stage: AudioSeatRing(
                count: 20,
                host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
                hostName: 'Layla',
                hostPoints: '0',
                hostMicOn: false,
                seats: _full(20),
                cpPairs: pairs,
                micOff: const {1, 3, 6, 8},
                onSeat: (_) {},
              ),
              chat: [
                for (var i = 0; i < 6; i++)
                  SizedBox(key: ValueKey('chat$i'), height: 36),
              ],
              barStart: const [SizedBox.square(dimension: 44)],
              barEnd: const [SizedBox.square(dimension: 44)],
            ),
          ),
          language: language,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CpBand), findsNWidgets(pairs.length));
        const screen = Rect.fromLTWH(0, 0, 360, 800);
        final widths = <double>[];
        for (final p in pairs) {
          final band = tester.getRect(_band(p.a, p.b));
          expect(screen.inflate(12).contains(band.topLeft), isTrue);
          expect(screen.inflate(12).contains(band.bottomRight), isTrue);
          final ornament = _ornament(p.a, p.b);
          if (ornament.evaluate().isEmpty) continue;
          expect(screen.contains(tester.getRect(ornament).center), isTrue);
          widths.add(_expectOrnamentClear(tester, p.a, p.b, 20));
        }
        for (final p in pairs) {
          _expectRings(tester, p.a, p.b);
          _expectFxClear(tester, p.a, p.b, 20);
          final parts = _fxParts(tester, p.a, p.b);
          // Many pairs: each keeps a small budget.
          expect(parts.length, lessThanOrEqualTo(CpPairFx.crowdedParts));
          for (final part in parts) {
            expect(screen.contains(part.center), isTrue);
          }
          for (final left in [true, false]) {
            final shown = tester.getRect(_ringOf(p.a, p.b, left: left));
            expect(screen.contains(shown.topLeft), isTrue);
            expect(screen.contains(shown.bottomRight), isTrue);
          }
        }
        // Every pair has room for an ornament at this size.
        expect(find.byType(CpOrnament), findsNWidgets(pairs.length));
        // Reports the sizes reached (owner D113 feedback asks for them).
        // ignore: avoid_print
        print(
          'D113 ornament widths at 360 x 800, 20 seats ($language): '
          '${widths.map((w) => w.toStringAsFixed(1)).join(', ')}',
        );
      });

      testWidgets('the viewer room draws the pairs from the seats data', (
        tester,
      ) async {
        UserSummary user(String id, String name) => UserSummary(
          id: id,
          username: id,
          displayName: name,
          avatarUrl: null,
        );
        final repo =
            FakeLiveRepository(
                room: (id) => apiRoom(
                  id: id,
                  ar: ar,
                ).copyWith(mode: LiveRoomMode.audio, seatCount: 10),
              )
              ..seatState = LiveSeats(
                roomId: 'room-0',
                mode: LiveRoomMode.audio,
                version: 1,
                seatCount: 10,
                seats: [
                  LiveSeat(
                    index: 1,
                    state: LiveSeatState.taken,
                    user: user('a', 'Lina'),
                  ),
                  LiveSeat(
                    index: 2,
                    state: LiveSeatState.taken,
                    user: user('b', 'Omar'),
                  ),
                  for (var i = 3; i < 10; i++)
                    LiveSeat(index: i, state: LiveSeatState.empty, user: null),
                ],
                moderators: const [],
                couples: const [
                  LiveSeatCouple(
                    userIds: ['a', 'b'],
                    level: 2,
                    levelName: 'Silver couple',
                  ),
                ],
              );
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const LiveRoomScreen(roomId: 'room-0'),
          language: language,
          overrides: [
            liveRepositoryProvider.overrideWithValue(repo),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile(ar: ar)),
            ),
            currentUserProvider.overrideWithValue(testUser()),
          ],
        );
        await tester.pumpAndSettle();
        expect(_band(1, 2), findsOneWidget);
        expect(_ornament(1, 2), findsOneWidget);
        expect(find.bySemanticsLabel('Silver couple'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    });
  }
}
