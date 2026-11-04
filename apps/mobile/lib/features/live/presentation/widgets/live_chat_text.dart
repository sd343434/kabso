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
}
