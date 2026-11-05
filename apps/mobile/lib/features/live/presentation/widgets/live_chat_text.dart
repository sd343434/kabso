/// D269 (owner: «ووحد حجم الخط في جميع البثوث سواء بث حي او صوتي او ستريمير
/// او اي كان» — and «اريد حجم التكست بحجم الايف … يمكن تكبيره كم نقطة»): the
/// ONE chat text size of every live — video / solo, multi-guest, audio,
/// podcast, streamer (host and viewer), PK and any other mode; the host's
/// flat chat, the authored lines and the viewer rows alike. The video live's
/// viewer rows (13.5) one point larger. Every chat line reads these; the
/// viewer's own «حجم الخط» preference still scales them.
abstract final class KChat {
  /// The message.
  static const double textSize = 14.5;

  /// The author's name and the one-line joins / gifts.
  static const double nameSize = 14;

  /// D284 (owner: «ايقونة الجديد اجعلها بنفس مقاس باقي الايقونات، حاول
  /// توحيد الايقونات بالحجم»): the emblems of a chat line's first row — the
  /// charm creature, the support art, the VIP badge's art, the agent and
  /// recharge badges — fill this height on screen (the boxed lines' and the
  /// host's flat line's; the video live's rows are taller, 23).
  static const double emblemHeight = 20;

  /// D284: the emblems' art carries a bar — the charm level's pill (1 / 1.55
  /// of its creature, 0.645), the VIP art's (measured 0.64 of the art), the
  /// support art's ([supportBarShare]) — and the text tags («جديد», the host
  /// / moderator tags, the VIP pill without art, the family) are that bar
  /// alone: [tagShare] of the emblems' height, within 1 pt of every bar.
  static const double tagShare = 0.61;

  /// D284: a text tag's height on a line whose emblems are [emblem] tall.
  static double tagHeight(double emblem) => emblem * tagShare;

  /// D284: a text tag's words, ≈ the level numbers' size on their bars.
  static double tagTextSize(double tag) => tag * 0.74;

  /// D284: the support art's bar, as a share of the art's height (measured
  /// on the 21 tiers: 0.54–0.58).
  static const double supportBarShare = 0.57;
}
