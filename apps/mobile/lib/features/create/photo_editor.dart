import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D333: the crop of an edited photo — the photo as it is, a square (1:1)
/// or a portrait (4:5), cut from the centre.
enum PhotoAspect {
  original(null),
  square(1),
  portrait(4 / 5);

  new(this.ratio);

  /// Width ÷ height, or `null` for the photo's own.
  final double? ratio;
}

/// D333: the preset looks (layout pattern of the big apps' editors; our own
/// names and colour matrices).
enum PhotoFilter { normal, vivid, warm, cool, mono, fade }

/// D333: one photo's edit — crop, quarter turns, look, brightness and
/// contrast. Applied on the device before the upload ([renderPhotoEdit]).
@immutable
class PhotoEdit {
  const new({
    this.aspect = PhotoAspect.original,
    this.quarterTurns = 0,
    this.filter = PhotoFilter.normal,
    this.brightness = 0,
    this.contrast = 0,
  });

  final PhotoAspect aspect;

  /// Clockwise quarter turns, 0…3.
  final int quarterTurns;
  final PhotoFilter filter;

  /// −1 … 1 (0: unchanged): ±25 % of the full range added.
  final double brightness;

  /// −1 … 1 (0: unchanged): the contrast factor 0.5 … 1.5.
  final double contrast;

  bool get isIdentity =>
      aspect == PhotoAspect.original &&
      quarterTurns % 4 == 0 &&
      filter == PhotoFilter.normal &&
      brightness == 0 &&
      contrast == 0;

  PhotoEdit copyWith({
    PhotoAspect? aspect,
    int? quarterTurns,
    PhotoFilter? filter,
    double? brightness,
    double? contrast,
  }) => PhotoEdit(
    aspect: aspect ?? this.aspect,
    quarterTurns: (quarterTurns ?? this.quarterTurns) % 4,
    filter: filter ?? this.filter,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
  );

  /// The 4 × 5 colour matrix of the look, brightness and contrast.
  List<double> get matrix => photoEditMatrix(filter, brightness, contrast);
}

const List<double> _identity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> _filterMatrix(PhotoFilter filter) => switch (filter) {
  PhotoFilter.normal => _identity,
  // More saturation.
  PhotoFilter.vivid => _saturation(1.35),
  PhotoFilter.warm => const [
    1.08, 0, 0, 0, 8, //
    0, 1.0, 0, 0, 2, //
    0, 0, 0.88, 0, -6, //
    0, 0, 0, 1, 0, //
  ],
  PhotoFilter.cool => const [
    0.92, 0, 0, 0, -4, //
    0, 1.0, 0, 0, 0, //
    0, 0, 1.1, 0, 8, //
    0, 0, 0, 1, 0, //
  ],
  PhotoFilter.mono => _saturation(0),
  // Lifted blacks, softer colour.
  PhotoFilter.fade => _fade(),
};

List<double> _fade() {
  final m = _saturation(0.8);
  return [
    for (var i = 0; i < 20; i++)
      if (i >= 15)
        m[i]
      else if (i % 5 == 4)
        22
      else if (i % 5 < 3)
        m[i] * 0.9
      else
        m[i],
  ];
}

List<double> _saturation(double s) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final i = 1 - s;
  return [
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// [a] after [b] (both 4 × 5 colour matrices).
List<double> _concat(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? a[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = v;
    }
  }
  return out;
}

/// D333: the colour matrix of a look with brightness and contrast (each
/// −1 … 1) applied after it.
List<double> photoEditMatrix(
  PhotoFilter filter,
  double brightness,
  double contrast,
) {
  final c = 1 + contrast.clamp(-1.0, 1.0) * 0.5;
  final t = 128 * (1 - c) + brightness.clamp(-1.0, 1.0) * 64;
  final adjust = <double>[
    c, 0, 0, 0, t, //
    0, c, 0, 0, t, //
    0, 0, c, 0, t, //
    0, 0, 0, 1, 0, //
  ];
  return _concat(adjust, _filterMatrix(filter));
}

/// The crop (in the turned photo's coordinates) of [aspect] from a
/// [width] × [height] photo: the largest centred rectangle.
Rect photoCropRect(double width, double height, PhotoAspect aspect) {
  final ratio = aspect.ratio;
  if (ratio == null) return Rect.fromLTWH(0, 0, width, height);
  if (width / height > ratio) {
    final w = height * ratio;
    return Rect.fromLTWH((width - w) / 2, 0, w, height);
  }
  final h = width / ratio;
  return Rect.fromLTWH(0, (height - h) / 2, width, h);
}

/// The longest side of an edited photo.
const double maxEditedSide = 2160;

/// D333: applies [edit] to [bytes] on the device: turn, centred crop, look,
/// then a PNG at most [maxEditedSide] on its longest side and under the
/// photo upload limit ([maxPhotoBytes]; scaled down until it is).
Future<Uint8List> renderPhotoEdit(Uint8List bytes, PhotoEdit edit) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  codec.dispose();
  try {
    final turned = edit.quarterTurns.isOdd;
    final w = (turned ? image.height : image.width).toDouble();
    final h = (turned ? image.width : image.height).toDouble();
    final crop = photoCropRect(w, h, edit.aspect);
    var scale = math.min(1, maxEditedSide / math.max(crop.width, crop.height));
    for (var attempt = 0; attempt < 6; attempt++) {
      final out = await _draw(image, edit, crop, scale.toDouble());
      if (out.length <= maxPhotoBytes) return out;
      scale *= 0.8;
    }
    return await _draw(image, edit, crop, scale.toDouble());
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _draw(
  ui.Image image,
  PhotoEdit edit,
  Rect crop,
  double scale,
) async {
  final outW = math.max(1, (crop.width * scale).round());
  final outH = math.max(1, (crop.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(scale)
    ..translate(-crop.left, -crop.top);
  // Turn around the turned frame's origin.
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  switch (edit.quarterTurns % 4) {
    case 1:
      canvas
        ..translate(ih, 0)
        ..rotate(math.pi / 2);
    case 2:
      canvas
        ..translate(iw, ih)
        ..rotate(math.pi);
    case 3:
      canvas
        ..translate(0, iw)
        ..rotate(-math.pi / 2);
  }
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.matrix(edit.matrix),
  );
  final picture = recorder.endRecording();
  final out = await picture.toImage(outW, outH);
  picture.dispose();
  try {
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    out.dispose();
  }
}

/// D333: opens the editor on [bytes]; returns the edited photo, or `null`
/// when closed without applying.
Future<Uint8List?> showPhotoEditor(BuildContext context, Uint8List bytes) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoEditorScreen(bytes: bytes),
      ),
    );

/// D333 (owner: «احترافي مثل انستقرام أو فيسبوك» — the pattern only): the
/// photo editor of Create — the photo large on top, then three tools:
/// Crop (Original · 1:1 · 4:5 and rotate), Filters (six looks, each a
/// live thumbnail) and Adjust (brightness, contrast). Done applies the edit
/// on the device; Cancel keeps the photo as it was.
class PhotoEditorScreen extends StatefulWidget {
  const new({required this.bytes, super.key});

  final Uint8List bytes;

  static const doneKey = Key('photoEditor.done');
  static const cancelKey = Key('photoEditor.cancel');
  static const rotateKey = Key('photoEditor.rotate');
  static const previewKey = Key('photoEditor.preview');
  static const brightnessKey = Key('photoEditor.brightness');
  static const contrastKey = Key('photoEditor.contrast');
  static Key toolKey(int i) => Key('photoEditor.tool.$i');
  static Key aspectKey(PhotoAspect a) => Key('photoEditor.aspect.${a.name}');
  static Key filterKey(PhotoFilter f) => Key('photoEditor.filter.${f.name}');

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  PhotoEdit _edit = const PhotoEdit();
  int _tool = 0;
  bool _saving = false;
  late final MemoryImage _image = MemoryImage(widget.bytes);
  Size? _size;

  @override
  void initState() {
    super.initState();
    final stream = _image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(
          () => _size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
        );
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  Future<void> _done() async {
    if (_edit.isIdentity) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final out = await renderPhotoEdit(widget.bytes, _edit);
      if (mounted) Navigator.of(context).pop(out);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        KSnack.error(context, context.l10n.photoEditFailed);
      }
    }
  }

  String _filterName(PhotoFilter f) {
    final l10n = context.l10n;
    return switch (f) {
      PhotoFilter.normal => l10n.photoFilterNormal,
      PhotoFilter.vivid => l10n.photoFilterVivid,
      PhotoFilter.warm => l10n.photoFilterWarm,
      PhotoFilter.cool => l10n.photoFilterCool,
      PhotoFilter.mono => l10n.photoFilterMono,
      PhotoFilter.fade => l10n.photoFilterFade,
    };
  }

  String _aspectName(PhotoAspect a) {
    final l10n = context.l10n;
    return switch (a) {
      PhotoAspect.original => l10n.photoAspectOriginal,
      PhotoAspect.square => '1:1',
      PhotoAspect.portrait => '4:5',
    };
  }

  Widget _photo({PhotoFilter? filter, bool crop = true}) {
    final edit = filter == null ? _edit : _edit.copyWith(filter: filter);
    final child = ColorFiltered(
      colorFilter: ColorFilter.matrix(edit.matrix),
      child: RotatedBox(
        quarterTurns: edit.quarterTurns,
        child: Image(image: _image, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
    final size = _size;
    if (!crop || size == null) return child;
    final turned = edit.quarterTurns.isOdd;
    final ratio =
        edit.aspect.ratio ??
        (turned ? size.height / size.width : size.width / size.height);
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: turned ? size.height : size.width,
            height: turned ? size.width : size.height,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final tools = [
      l10n.photoToolCrop,
      l10n.photoToolFilters,
      l10n.photoToolAdjust,
    ];
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        leading: IconButton(
          key: PhotoEditorScreen.cancelKey,
          tooltip: l10n.photoEditCancel,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(l10n.photoEditTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
            child: TextButton(
              key: PhotoEditorScreen.doneKey,
              onPressed: _saving ? null : _done,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.photoEditDone),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Center(
                  child: Semantics(
                    key: PhotoEditorScreen.previewKey,
                    image: true,
                    label: l10n.photoEditPreview,
                    child: _photo(),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 128,
              child: switch (_tool) {
                0 => _cropTool(context),
                1 => _filterTool(context),
                _ => _adjustTool(context),
              },
            ),
            Row(
              children: [
                for (final (i, name) in tools.indexed)
                  Expanded(
                    child: Semantics(
                      selected: _tool == i,
                      button: true,
                      child: InkWell(
                        key: PhotoEditorScreen.toolKey(i),
                        onTap: () => setState(() => _tool = i),
                        child: SizedBox(
                          height: KSizes.minTouchTarget + KSpacing.sm,
                          child: Center(
                            child: Text(
                              name,
                              style: t.bodyStrong.copyWith(
                                color: _tool == i
                                    ? p.textPrimary
                                    : p.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cropTool(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Center(
      child: Wrap(
        spacing: KSpacing.sm,
        runSpacing: KSpacing.sm,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final a in PhotoAspect.values)
            ChoiceChip(
              key: PhotoEditorScreen.aspectKey(a),
              label: Text(_aspectName(a)),
              selected: _edit.aspect == a,
              selectedColor: p.primary.withValues(alpha: 0.18),
              onSelected: (_) =>
                  setState(() => _edit = _edit.copyWith(aspect: a)),
            ),
          IconButton.outlined(
            key: PhotoEditorScreen.rotateKey,
            tooltip: l10n.photoEditRotate,
            onPressed: () => setState(
              () =>
                  _edit = _edit.copyWith(quarterTurns: _edit.quarterTurns + 1),
            ),
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
          ),
        ],
      ),
    );
  }

  Widget _filterTool(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      children: [
        for (final f in PhotoFilter.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
            child: Semantics(
              button: true,
              selected: _edit.filter == f,
              label: _filterName(f),
              excludeSemantics: true,
              child: GestureDetector(
                key: PhotoEditorScreen.filterKey(f),
                onTap: () => setState(() => _edit = _edit.copyWith(filter: f)),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(KRadius.sm),
                        border: Border.all(
                          color: _edit.filter == f
                              ? p.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _photo(filter: f, crop: false),
                    ),
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      _filterName(f),
                      style: t.caption.copyWith(
                        color: _edit.filter == f
                            ? p.textPrimary
                            : p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _adjustTool(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    Widget slider(
      Key key,
      String label,
      double value,
      ValueChanged<double> on,
    ) => Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: t.body)),
        Expanded(
          child: Slider(
            key: key,
            value: value,
            min: -1,
            divisions: 40,
            label: (value * 100).round().toString(),
            semanticFormatterCallback: (v) => '${(v * 100).round()}',
            onChanged: on,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          slider(
            PhotoEditorScreen.brightnessKey,
            l10n.photoAdjustBrightness,
            _edit.brightness,
            (v) => setState(() => _edit = _edit.copyWith(brightness: v)),
          ),
          slider(
            PhotoEditorScreen.contrastKey,
            l10n.photoAdjustContrast,
            _edit.contrast,
            (v) => setState(() => _edit = _edit.copyWith(contrast: v)),
          ),
        ],
      ),
    );
  }
}
