// v1.136-social (D384, CONVENTIONS §10.173.2): recording the VIP animated
// picture «صورة متحركة» — 3 s from the front camera, 12 frames a second
// kept from the camera's image stream (no video file to decode), then the
// background removed on the phone with Google ML Kit's selfie segmentation
// (on-device, offline, free; nothing leaves the phone until the member
// saves). Device-only code: tests use a fake [CutoutRecorder].

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:material_ui/material_ui.dart';

/// The camera cannot be used (none, not allowed, failed to start).
class CutoutCameraException implements Exception {
  const new([this.cause]);

  final Object? cause;
}

/// Records a short clip and removes its background.
abstract interface class CutoutRecorder {
  /// Opens the front camera (throws [CutoutCameraException]).
  Future<void> open();

  /// The live camera preview (after [open]).
  Widget preview(BuildContext context);

  /// Records [CutoutLimits.length] and returns its frames with the person's
  /// alpha, upright and mirrored like the preview. [onProgress] gets 0–1:
  /// the recording up to 0.5, the background removal after.
  Future<List<CutoutFrame>> record({
    required void Function(double progress) onProgress,
  });

  /// Releases the camera and the model.
  Future<void> close();
}

/// The phone's recorder (camera + ML Kit); tests override it.
final Provider<CutoutRecorder> cutoutRecorderProvider =
    Provider.autoDispose<CutoutRecorder>((ref) {
      final recorder = CameraCutoutRecorder();
      ref.onDispose(() => unawaited(recorder.close()));
      return recorder;
    });

/// One camera buffer kept while recording (copied: the stream reuses them).
class _Raw {
  new(CameraImage image)
    : width = image.width,
      height = image.height,
      bytesPerRow = image.planes.first.bytesPerRow,
      bytes = Uint8List.fromList(image.planes.first.bytes);

  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List bytes;
}

class CameraCutoutRecorder implements CutoutRecorder {
  CameraController? _camera;
  CameraDescription? _description;
  SelfieSegmenter? _segmenter;

  bool get _android => Platform.isAndroid;

  @override
  Future<void> open() async {
    if (_camera?.value.isInitialized ?? false) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw const CutoutCameraException();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit takes NV21 on Android and BGRA on iOS.
        imageFormatGroup: _android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      _camera = camera;
      _description = front;
    } on CutoutCameraException {
      rethrow;
    } on Object catch (e) {
      throw CutoutCameraException(e);
    }
  }

  @override
  Widget preview(BuildContext context) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(camera);
  }

  @override
  Future<List<CutoutFrame>> record({
    required void Function(double progress) onProgress,
  }) async {
    final camera = _camera;
    final description = _description;
    if (camera == null || description == null) {
      throw const CutoutCameraException();
    }
    final raw = <_Raw>[];
    final watch = Stopwatch()..start();
    final done = Completer<void>();
    var next = 0;
    final total = CutoutLimits.length.inMilliseconds;
    await camera.startImageStream((image) {
      if (done.isCompleted) return;
      final t = watch.elapsedMilliseconds;
      if (t >= total || raw.length >= CutoutLimits.maxFrames) {
        done.complete();
        return;
      }
      if (t < next) return;
      next = t + CutoutLimits.frameMs;
      raw.add(_Raw(image));
      onProgress(0.5 * t / total);
    });
    await done.future.timeout(
      CutoutLimits.length + const Duration(seconds: 2),
      onTimeout: () {},
    );
    await camera.stopImageStream();

    final segmenter = _segmenter ??= SelfieSegmenter(
      mode: SegmenterMode.single,
      // The model's own 256 × 256 mask: far fewer values over the channel;
      // scaled up here.
      enableRawSizeMask: true,
    );
    final front = description.lensDirection == CameraLensDirection.front;
    final frames = <CutoutFrame>[];
    for (var i = 0; i < raw.length; i++) {
      final r = raw[i];
      // A landscape buffer is the sensor's: turn it by the sensor's
      // orientation (front camera, phone upright).
      final turns = r.width > r.height
          ? description.sensorOrientation ~/ 90
          : 0;
      final mask = await segmenter.processImage(
        InputImage.fromBytes(
          bytes: r.bytes,
          metadata: InputImageMetadata(
            size: Size(r.width.toDouble(), r.height.toDouble()),
            rotation:
                InputImageRotationValue.fromRawValue(turns * 90) ??
                InputImageRotation.rotation0deg,
            format: _android
                ? InputImageFormat.nv21
                : InputImageFormat.bgra8888,
            bytesPerRow: r.bytesPerRow,
          ),
        ),
      );
      onProgress(0.5 + 0.5 * (i + 1) / raw.length);
      if (mask == null) continue;
      final rgba = _android
          ? nv21ToRgba(r.bytes, r.width, r.height)
          : bgraToRgba(r.bytes, r.width, r.height, r.bytesPerRow);
      final upright = orientPixels(
        rgba,
        r.width,
        r.height,
        4,
        quarterTurns: turns,
        mirror: front,
      );
      frames.add(
        CutoutFrame(
          width: upright.width,
          height: upright.height,
          rgba: upright.data,
          alpha: alphaFromConfidences(
            mask.confidences,
            mask.width,
            mask.height,
            upright.width,
            upright.height,
            mirror: front,
          ),
        ),
      );
    }
    return frames;
  }

  @override
  Future<void> close() async {
    final camera = _camera;
    _camera = null;
    final segmenter = _segmenter;
    _segmenter = null;
    await camera?.dispose();
    await segmenter?.close();
  }
}
