// v1.136-social (D384, owner 2026-11-12: «record and pick from the
// gallery»; CONVENTIONS §10.173.2): the VIP animated picture from a video
// the member picks. The app's video picker (`videoPickerProvider`,
// image_picker) picks it; the member keeps 3 s of it (cutout_trim.dart);
// our own platform channel `com.kabso/video_frames` reads its frames at 15 a
// second (Android MediaMetadataRetriever OPTION_CLOSEST, iOS
// AVAssetImageGenerator with zero tolerance; upright, rotation applied); the
// same on-device ML Kit selfie segmentation as the camera path removes the
// background. Device-only code: tests use a fake [CutoutGallery].

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_trim.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

/// The picked video cannot be read (no file, no frames).
class CutoutClipException implements Exception {
  const new([this.cause]);

  final Object? cause;
}

/// A picked video: its file, length and shown size (rotation applied).
@immutable
class PickedClip {
  const new({
    required this.path,
    required this.durationMs,
    this.width = 0,
    this.height = 0,
  });

  final String path;
  final int durationMs;
  final int width;
  final int height;
}

/// Picks a video and turns 3 s of it into cut-out frames.
abstract interface class CutoutGallery {
  /// The picked video; null when cancelled. Throws [CutoutClipException].
  Future<PickedClip?> pick();

  /// The frame at [ms] for the trim preview, or null.
  Future<ImageProvider?> frameAt(PickedClip clip, int ms);

  /// The frames of the 3 s from [startMs] (15 a second, at most 45) with the
  /// person's alpha, upright. [onProgress] gets 0–1. Throws
  /// [CutoutClipException].
  Future<List<CutoutFrame>> frames(
    PickedClip clip,
    int startMs, {
    required void Function(double progress) onProgress,
  });
}

/// The phone's gallery path; tests override it.
final Provider<CutoutGallery> cutoutGalleryProvider = Provider<CutoutGallery>(
  (ref) => DeviceCutoutGallery(ref.watch(videoPickerProvider)),
);

/// `com.kabso/video_frames` (MainActivity.kt / AppDelegate.swift).
abstract final class VideoFramesChannel {
  static const channel = MethodChannel('com.kabso/video_frames');

  /// The JPEG files of the frames at [timesMs] (null where there is none).
  static Future<List<String?>> extract(
    String path,
    List<int> timesMs, {
    required int maxSide,
    required String outDir,
  }) async {
    final out = await channel.invokeListMethod<Object?>('extract', {
      'path': path,
      'timesMs': timesMs,
      'maxSide': maxSide,
      'outDir': outDir,
    });
    return [
      for (final p in out ?? const <Object?>[])
        if (p is String) p else null,
    ];
  }
}

class DeviceCutoutGallery implements CutoutGallery {
  new(this._picker);

  final VideoPicker _picker;

  /// The longer side of a frame read for segmentation.
  static const int frameSide = 640;

  Future<String> _outDir() async =>
      '${(await getTemporaryDirectory()).path}/d384_frames';

  @override
  Future<PickedClip?> pick() async {
    final PickedVideo? video;
    try {
      video = await _picker.pickVideo(maxDuration: const Duration(minutes: 10));
    } on Object catch (e) {
      throw CutoutClipException(e);
    }
    if (video == null) return null;
    final path = video.path;
    if (path == null || video.duration <= Duration.zero) {
      throw const CutoutClipException();
    }
    return PickedClip(
      path: path,
      durationMs: video.duration.inMilliseconds,
      width: video.width,
      height: video.height,
    );
  }

  @override
  Future<ImageProvider?> frameAt(PickedClip clip, int ms) async {
    try {
      final paths = await VideoFramesChannel.extract(
        clip.path,
        [ms],
        maxSide: 480,
        outDir: await _outDir(),
      );
      final p = paths.firstOrNull;
      return p == null ? null : FileImage(File(p));
    } on Object {
      return null;
    }
  }

  @override
  Future<List<CutoutFrame>> frames(
    PickedClip clip,
    int startMs, {
    required void Function(double progress) onProgress,
  }) async {
    final window = trimWindow(clip.durationMs, startMs);
    final times = frameTimesMs(window.startMs, window.lengthMs);
    final List<String?> files;
    try {
      files = await VideoFramesChannel.extract(
        clip.path,
        times,
        maxSide: frameSide,
        outDir: await _outDir(),
      );
    } on Object catch (e) {
      throw CutoutClipException(e);
    }
    onProgress(0.3);
    final segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: true,
    );
    final frames = <CutoutFrame>[];
    try {
      for (var i = 0; i < files.length; i++) {
        final path = files[i];
        if (path == null) continue;
        final mask = await segmenter.processImage(
          InputImage.fromFilePath(path),
        );
        final rgba = await _decode(File(path).readAsBytesSync());
        onProgress(0.3 + 0.7 * (i + 1) / files.length);
        if (mask == null || rgba == null) continue;
        frames.add(
          CutoutFrame(
            width: rgba.width,
            height: rgba.height,
            rgba: rgba.data,
            alpha: alphaFromConfidences(
              mask.confidences,
              mask.width,
              mask.height,
              rgba.width,
              rgba.height,
            ),
          ),
        );
      }
    } finally {
      await segmenter.close();
      for (final p in files) {
        if (p != null) unawaited(File(p).delete().catchError((_) => File(p)));
      }
    }
    if (frames.isEmpty) throw const CutoutClipException();
    return frames;
  }

  static Future<({Uint8List data, int width, int height})?> _decode(
    Uint8List jpeg,
  ) async {
    final codec = await ui.instantiateImageCodec(jpeg);
    final image = (await codec.getNextFrame()).image;
    try {
      final data = await image.toByteData();
      if (data == null) return null;
      return (
        data: data.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
}
