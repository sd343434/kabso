import 'dart:ui' show Color, Offset;

/// D168: the Ludo board of the owner-approved prototype, in cell units of
/// a 15 × 15 grid: (row, column) from the top-left. Seat 0 red (top-left
/// base), 1 green (top-right), 2 yellow (bottom-right), 3 blue
/// (bottom-left). The board is never mirrored (Arabic too).
abstract final class LudoBoard {
  static const int cells = 15;

  /// The 52 squares of the shared track, clockwise from red's start.
  static const List<(int, int)> track = [
    (6, 1), (6, 2), (6, 3), (6, 4), (6, 5), (5, 6), (4, 6), (3, 6),
    (2, 6), (1, 6), (0, 6), (0, 7), (0, 8), (1, 8), (2, 8), (3, 8),
    (4, 8), (5, 8), (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
    (7, 14), (8, 14), (8, 13), (8, 12), (8, 11), (8, 10), (8, 9), (9, 8),
    (10, 8), (11, 8), (12, 8), (13, 8), (14, 8), (14, 7), (14, 6),
    (13, 6), (12, 6), (11, 6), (10, 6), (9, 6), (8, 5), (8, 4), (8, 3),
    (8, 2), (8, 1), (8, 0), (7, 0), (6, 0),
  ];

  /// Each seat's start square on [track].
  static const List<int> start = [0, 13, 26, 39];

  /// Squares where nobody is captured (the starts and the stars).
  static const Set<int> safe = {0, 8, 13, 21, 26, 34, 39, 47};

  /// A piece's step at home.
  static const int finish = 57;

  /// The seat colours.
  static const List<Color> colors = [
    Color(0xFFF2545B),
    Color(0xFF2CC56F),
    Color(0xFFF6CC2E),
    Color(0xFF3DA8F5),
  ];

  /// Each base's top-left cell (6 × 6 cells).
  static const List<(int, int)> base = [(0, 0), (0, 9), (9, 9), (9, 0)];

  /// Each seat's home column (5 cells, towards the centre).
  static const List<List<(int, int)>> home = [
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
  ];

  /// Where a piece that reached home rests (its colour's triangle).
  static const List<(double, double)> finishAt = [
    (7.5, 6.75),
    (6.75, 7.5),
    (7.5, 8.25),
    (8.25, 7.5),
  ];

  /// The arrow on each seat's start square: right, down, left, up.
  static const List<int> arrowTurns = [0, 1, 2, 3];

  /// The player chips on the board's edges (centre, may be off the board).
  static const List<(double, double)> chipAt = [
    (1.6, -0.35),
    (1.6, 15.35),
    (13.4, 15.35),
    (13.4, -0.35),
  ];

  /// The die on the base of the seat whose turn it is (centre).
  static const List<(double, double)> dieAt = [
    (0.35, 4.4),
    (0.35, 10.6),
    (14.65, 10.6),
    (14.65, 4.4),
  ];

  /// The three six-counter tabs by each base: top row, start column, and
  /// whether they line up from the start (else from the end) of 2.2 cells.
  static const List<(double, double, bool)> tabsAt = [
    (-0.62, 0.2, true),
    (-0.62, 12.6, false),
    (15.05, 12.6, false),
    (15.05, 0.2, true),
  ];

  /// The shared-track square of [seat]'s piece at [step], or null when it
  /// is not on the shared track.
  static int? square(int seat, int step) =>
      step >= 0 && step <= 51 ? (start[seat] + step) % track.length : null;

  /// The centre of [seat]'s piece [index] at [step], in cells (x = column,
  /// y = row).
  static Offset cellOf(int seat, int step, int index) {
    if (step < 0) {
      // The base's four slots.
      const a = 0.18 + (6 - 0.36) * (0.11 + 0.78 * 0.27);
      const b = 0.18 + (6 - 0.36) * (0.11 + 0.78 * 0.73);
      final (r, c) = base[seat];
      return Offset(
        c + (index.isOdd ? b : a),
        r + (index < 2 ? a : b),
      );
    }
    if (step <= 51) {
      final (r, c) = track[(start[seat] + step) % track.length];
      return Offset(c + 0.5, r + 0.5);
    }
    if (step < finish) {
      final (r, c) = home[seat][step - 52];
      return Offset(c + 0.5, r + 0.5);
    }
    final (r, c) = finishAt[seat];
    return Offset(c, r);
  }

  /// The prototype's progress points of a seat (the rank pill): 100 per
  /// step walked. Display only; worth nothing (D168: free).
  static int points(List<int> pieces) =>
      pieces.fold(0, (sum, p) => sum + (p < 0 ? 0 : (p + 1) * 100));
}
