import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D201 «كاميرتان»: the main feed full screen and the other camera as a small
/// picture the viewer can drag (it settles on the nearer side) and tap to
/// swap — on this screen only. [defaultMain] is the host's choice
/// (`kabso.mainFeed`); a viewer's own swap holds until the host changes it.
/// Without [second] it is just [host].
class LiveDualCameraView extends StatefulWidget {
  const new({
    required this.host,
    required this.second,
    this.defaultMain = SecondCameraFeed.host,
    this.topInset = 120,
    super.key,
  });

  final Widget host;
  final Widget? second;
  final SecondCameraFeed defaultMain;

  /// Where the small picture starts, from the top (under the top bar).
  final double topInset;

  static const pipKey = Key('dual.pip');
  static const mainKey = Key('dual.main');

  /// D243: the swap hint on the small picture (a tap swaps).
  static const swapHintKey = Key('dual.swapHint');

  /// The small picture's size (9 : 16).
  static const pipSize = Size(96, 170);

  @override
  State<LiveDualCameraView> createState() => _LiveDualCameraViewState();
}

class _LiveDualCameraViewState extends State<LiveDualCameraView> {
  SecondCameraFeed? _mine;

  /// From the end edge and the top.
  Offset? _offset;
  bool _dragging = false;

  SecondCameraFeed get _main => _mine ?? widget.defaultMain;

  @override
  void didUpdateWidget(LiveDualCameraView old) {
    super.didUpdateWidget(old);
    if (old.defaultMain != widget.defaultMain || widget.second == null) {
      _mine = null;
    }
  }

  void _swap() => setState(
    () => _mine = _main == SecondCameraFeed.host
        ? SecondCameraFeed.second
        : SecondCameraFeed.host,
  );

  @override
  Widget build(BuildContext context) {
    final second = widget.second;
    if (second == null) return SizedBox.expand(child: widget.host);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final big = _main == SecondCameraFeed.host ? widget.host : second;
    final small = _main == SecondCameraFeed.host ? second : widget.host;
    const size = LiveDualCameraView.pipSize;
    return LayoutBuilder(
      builder: (context, box) {
        const margin = 12.0;
        final maxX = (box.maxWidth - size.width - margin).clamp(
          margin,
          double.infinity,
        );
        final maxY = (box.maxHeight - size.height - margin).clamp(
          margin,
          double.infinity,
        );
        final offset =
            _offset ?? Offset(margin, widget.topInset.clamp(margin, maxY));
        return Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: LiveDualCameraView.mainKey, child: big),
            AnimatedPositionedDirectional(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              end: offset.dx,
              top: offset.dy,
              width: size.width,
              height: size.height,
              child: Semantics(
                button: true,
                label: context.l10n.liveCam2Swap,
                child: GestureDetector(
                  key: LiveDualCameraView.pipKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _swap,
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanUpdate: (d) => setState(() {
                    // `end` grows towards the start side: left in LTR, right
                    // in RTL.
                    final dx = rtl ? d.delta.dx : -d.delta.dx;
                    _offset = Offset(
                      (offset.dx + dx).clamp(margin, maxX),
                      (offset.dy + d.delta.dy).clamp(margin, maxY),
                    );
                  }),
                  onPanEnd: (_) => setState(() {
                    _dragging = false;
                    final now = _offset ?? offset;
                    // Settle on the nearer side.
                    _offset = Offset(
                      now.dx < (box.maxWidth - size.width) / 2 ? margin : maxX,
                      now.dy,
                    );
                  }),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xE6FFFFFF),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 8),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const Color(0xFF000000),
                            child: small,
                          ),
                          // D243: says a tap swaps the two (the owner asked
                          // for it to be discoverable).
                          const PositionedDirectional(
                            bottom: 6,
                            end: 6,
                            child: ExcludeSemantics(
                              child: DecoratedBox(
                                key: LiveDualCameraView.swapHintKey,
                                decoration: BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
