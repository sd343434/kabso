import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The square part of a photo that becomes the profile photo (D168): the
/// person drags and pinches the photo under a fixed square (with the round
/// outline the photo is shown in), then "Done" renders that square as a
/// PNG of at most [AvatarCropScreen.maxSide] px. The server keeps a 640 px
/// square (§11.1), so nothing larger is sent.
///
/// Pops the PNG bytes, or null when cancelled.
class AvatarCropScreen extends StatefulWidget {
  const new({required this.bytes, super.key});

  final Uint8List bytes;

  static const doneKey = Key('avatarCrop.done');
  static const cancelKey = Key('avatarCrop.cancel');
  static const viewportKey = Key('avatarCrop.viewport');
  static const failedKey = Key('avatarCrop.failed');

  /// The largest side sent (the server's `AVATAR` size).
  static const int maxSide = 640;

  /// How far the photo can be enlarged beyond filling the square.
  static const double maxZoom = 4;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

/// The crop in the photo's pixels: a square of [side] at [left], [top].
@immutable
class AvatarCrop {
  const new(this.left, this.top, this.side);

  /// The square shown in a viewport of [viewport] px when the photo of
  /// [width] × [height] px is enlarged [zoom] times past filling it and its
  /// top-left corner sits at [offset] (viewport px).
  factory of({
    required int width,
    required int height,
    required double viewport,
    required double zoom,
    required Offset offset,
  }) {
    final scale = viewport / math.min(width, height) * zoom;
    return AvatarCrop(-offset.dx / scale, -offset.dy / scale, viewport / scale);
  }

  final double left;
  final double top;
  final double side;
}

/// Keeps the photo of [width] × [height] px, at [scale] viewport px per
/// photo px, covering the [viewport] square: its top-left corner [offset]
/// is clamped so no empty edge shows.
Offset clampAvatarOffset(
  Offset offset, {
  required int width,
  required int height,
  required double scale,
  required double viewport,
}) => Offset(
  offset.dx.clamp(math.min(0, viewport - width * scale), 0).toDouble(),
  offset.dy.clamp(math.min(0, viewport - height * scale), 0).toDouble(),
);

/// Renders [crop] of [image] as a PNG square of at most [maxSide] px.
Future<Uint8List?> renderAvatarCrop(
  ui.Image image,
  AvatarCrop crop, {
  int maxSide = AvatarCropScreen.maxSide,
}) async {
  final side = math.max(1, math.min(maxSide, crop.side.round()));
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    Rect.fromLTWH(crop.left, crop.top, crop.side, crop.side),
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final out = await recorder.endRecording().toImage(side, side);
  try {
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    out.dispose();
  }
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  ui.Image? _image;
  bool _failed = false;
  bool _rendering = false;

  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _viewport = 0;

  // The gesture's start.
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  double _scaleFor(ui.Image image, double zoom) =>
      _viewport / math.min(image.width, image.height) * zoom;

  /// Centres the photo when the square's size is first known (or changes).
  void _layout(double viewport) {
    final image = _image;
    if (image == null || viewport == _viewport) return;
    _viewport = viewport;
    final scale = _scaleFor(image, _zoom);
    _offset = clampAvatarOffset(
      Offset(
        (viewport - image.width * scale) / 2,
        (viewport - image.height * scale) / 2,
      ),
      width: image.width,
      height: image.height,
      scale: scale,
      viewport: viewport,
    );
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startZoom = _zoom;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final image = _image;
    if (image == null) return;
    final zoom = (_startZoom * d.scale).clamp(1.0, AvatarCropScreen.maxZoom);
    final ratio = zoom / _startZoom;
    // The photo point under the first focal point stays under the finger.
    final offset = d.localFocalPoint - (_startFocal - _startOffset) * ratio;
    setState(() {
      _zoom = zoom;
      _offset = clampAvatarOffset(
        offset,
        width: image.width,
        height: image.height,
        scale: _scaleFor(image, zoom),
        viewport: _viewport,
      );
    });
  }

  Future<void> _done() async {
    final image = _image;
    if (image == null || _rendering) return;
    setState(() => _rendering = true);
    final png = await renderAvatarCrop(
      image,
      AvatarCrop.of(
        width: image.width,
        height: image.height,
        viewport: _viewport,
        zoom: _zoom,
        offset: _offset,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final image = _image;
    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        backgroundColor: black,
        foregroundColor: white,
        title: Text(l10n.profileEditCropTitle),
        leading: IconButton(
          key: AvatarCropScreen.cancelKey,
          tooltip: l10n.actionCancel,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            key: AvatarCropScreen.doneKey,
            onPressed: image == null || _rendering ? null : _done,
            child: Text(
              l10n.profileEditCropDone,
              style: t.bodyStrong.copyWith(
                color: image == null ? white.withValues(alpha: 0.4) : white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                key: AvatarCropScreen.failedKey,
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.lg),
                  child: Text(
                    l10n.createPhotoUnsupported,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: white),
                  ),
                ),
              )
            : image == null
            ? const Center(child: CircularProgressIndicator(color: white))
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final side =
                            math.min(box.maxWidth, box.maxHeight) -
                            2 * KSpacing.lg;
                        _layout(side);
                        final scale = _scaleFor(image, _zoom);
                        return Center(
                          child: Semantics(
                            label: l10n.profileEditCropHint,
                            image: true,
                            child: GestureDetector(
                              key: AvatarCropScreen.viewportKey,
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                              child: SizedBox.square(
                                dimension: side,
                                child: ClipRect(
                                  child: CustomPaint(
                                    painter: _CropPainter(
                                      image: image,
                                      scale: scale,
                                      offset: _offset,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.lg,
                      KSpacing.sm,
                      KSpacing.lg,
                      KSpacing.lg,
                    ),
                    child: Text(
                      l10n.profileEditCropHint,
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(
                        color: white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The photo at [scale] and [offset], dimmed outside the round outline the
/// profile photo is shown in.
class _CropPainter extends CustomPainter {
  const new({required this.image, required this.scale, required this.offset});

  final ui.Image image;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        image.width * scale,
        image.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final square = Offset.zero & size;
    final circle = Path()..addOval(square);
    canvas
      ..drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(square), circle),
        Paint()..color = const Color(0x8C000000),
      )
      ..drawPath(
        circle,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.scale != scale || old.offset != offset;
}
