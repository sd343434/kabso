import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// D173 (owner: «عند فتح يوتيوب في الغرفة الصوتية تنتقل الكراسي إلى أسفل»
/// and «عندما مشاهدة يوتيوب لا يكون هناك إلا ١٠ كراسي فقط»): the owner's
/// cinema picture, drawn as the audio room's background while the room
/// watches YouTube together. The player sits exactly on the drawn screen and
/// the room's 10 seats (the host's and seats 1–9; the server caps the room
/// at 10 meanwhile, v1.39-live) on the 10 drawn seat backs.
///
/// Every position is a fraction of the picture, measured on it
/// (assets/live_cinema/PROVENANCE.md), so a new version of the picture only
/// needs its file (and the fractions, if the drawing moved).
abstract final class LiveCinema {
  static const asset = 'assets/live_cinema/cinema_room.webp';

  /// The picture's size in pixels (853 × 1844): its aspect ratio.
  static const double imageWidth = 853;
  static const double imageHeight = 1844;

  /// The drawn screen's inner rectangle (16:9), x 79–774, y 330–719 px.
  static const Rect screen = Rect.fromLTRB(
    79 / imageWidth,
    330 / imageHeight,
    774 / imageWidth,
    719 / imageHeight,
  );

  /// The 10 seat backs, row by row (the farther row first), each row from
  /// the left of the picture: x ranges and the rows' tops and bottoms in px.
  static const List<Rect> seats = [
    Rect.fromLTRB(28 / imageWidth, _r1t, 172 / imageWidth, _r1b),
    Rect.fromLTRB(193 / imageWidth, _r1t, 336 / imageWidth, _r1b),
    Rect.fromLTRB(360 / imageWidth, _r1t, 500 / imageWidth, _r1b),
    Rect.fromLTRB(524 / imageWidth, _r1t, 666 / imageWidth, _r1b),
    Rect.fromLTRB(686 / imageWidth, _r1t, 828 / imageWidth, _r1b),
    Rect.fromLTRB(18 / imageWidth, _r2t, 172 / imageWidth, _r2b),
    Rect.fromLTRB(190 / imageWidth, _r2t, 338 / imageWidth, _r2b),
    Rect.fromLTRB(358 / imageWidth, _r2t, 503 / imageWidth, _r2b),
    Rect.fromLTRB(524 / imageWidth, _r2t, 670 / imageWidth, _r2b),
    Rect.fromLTRB(690 / imageWidth, _r2t, 842 / imageWidth, _r2b),
  ];
  static const double _r1t = 876 / imageHeight;
  static const double _r1b = 1021 / imageHeight;
  static const double _r2t = 1021 / imageHeight;
  static const double _r2b = 1210 / imageHeight;

  /// Seats per drawn row.
  static const int perRow = 5;

  /// The room's seats in the cinema (the host's included).
  static const int seatCount = 10;

  /// The picture is drawn [BoxFit.cover] anchored at the top centre, so the
  /// screen and the seats never leave the top part of the room.
  static const Alignment alignment = Alignment.topCenter;

  /// The picture's top rows (its ceiling), filling the space above it when
  /// it moves down.
  static const Color ceiling = Color(0xFF100503);

  /// The picture's scale and offset in a [viewport] (cover, [alignment]).
  /// When the room's top rows reach lower than the drawn screen
  /// ([minScreenTop]: a short or narrow phone, large text), the picture
  /// moves down just enough that the screen starts under them (its bottom,
  /// the carpet, is cut).
  static ({double scale, Offset offset}) fit(
    Size viewport, {
    double minScreenTop = 0,
  }) {
    final scale = math.max(
      viewport.width / imageWidth,
      viewport.height / imageHeight,
    );
    final dx = (viewport.width - imageWidth * scale) / 2;
    final cover =
        (viewport.height - imageHeight * scale) * (alignment.y + 1) / 2;
    final dy = math.max(cover, minScreenTop - screen.top * imageHeight * scale);
    return (scale: scale, offset: Offset(dx, dy));
  }

  /// Where a [fraction] of the picture lands in a [viewport].
  static Rect place(Rect fraction, Size viewport, {double minScreenTop = 0}) {
    final f = fit(viewport, minScreenTop: minScreenTop);
    final w = imageWidth * f.scale;
    final h = imageHeight * f.scale;
    return Rect.fromLTRB(
      f.offset.dx + fraction.left * w,
      f.offset.dy + fraction.top * h,
      f.offset.dx + fraction.right * w,
      f.offset.dy + fraction.bottom * h,
    );
  }

  /// The drawn seat of room seat [index] (0 the host): in reading order —
  /// the farther row first, from the start side (mirrored in Arabic).
  static Rect seatFraction(int index, {required bool rtl}) {
    final row = index ~/ perRow;
    final col = index % perRow;
    return seats[row * perRow + (rtl ? perRow - 1 - col : col)];
  }

  /// The bottom of the drawn seats in a [viewport] (the chat starts below).
  static double seatsBottom(Size viewport, {double minScreenTop = 0}) =>
      place(seats.last, viewport, minScreenTop: minScreenTop).bottom;
}
