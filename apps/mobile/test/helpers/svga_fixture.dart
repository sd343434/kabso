// D272 / D272b: a small SVGA 2.x file built in memory (one 100 × 200
// picture per frame and two MP3 sounds) and a fake audio player, for the
// shared SVGA engine's tests.
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

/// A tiny protobuf writer (the SVGA 2.x MovieEntity fields).
class _Pb {
  final _b = BytesBuilder();

  void _varint(int v) {
    var x = v;
    while (x >= 0x80) {
      _b.addByte((x & 0x7f) | 0x80);
      x >>= 7;
    }
    _b.addByte(x);
  }

  void int32(int field, int v) {
    _varint(field << 3);
    _varint(v);
  }

  void float(int field, double v) {
    _varint((field << 3) | 5);
    _b.add((ByteData(4)..setFloat32(0, v, Endian.little)).buffer.asUint8List());
  }

  void bytes(int field, List<int> v) {
    _varint((field << 3) | 2);
    _varint(v.length);
    _b.add(v);
  }

  void string(int field, String v) => bytes(field, v.codeUnits);

  void message(int field, void Function(_Pb m) build) {
    final m = _Pb();
    build(m);
    bytes(field, m.done());
  }

  Uint8List done() => _b.toBytes();
}

/// A fake MP3 (its ID3 header and some bytes).
final svgaFixtureMp3 = Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  4,
  0,
  0,
  ...List.filled(40, 7),
]);

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// An SVGA of [frames] frames at [fps] on a 100 × 200 canvas: one picture
/// per frame (`f0`…, 100 × 200, drawn full size like the owner's peacock),
/// plus a sound `s` from frame 2 (120 ms in) to 6, and `t` without an end.
/// [vector]: frame 0 has a clip path. D280: [drawHeight] — the pictures
/// are 100 × [drawHeight] at the canvas's top (a car whose canvas has empty
/// rows below its art).
Future<Uint8List> svgaFixture({
  int frames = 8,
  int fps = 20,
  bool vector = false,
  int drawHeight = 200,
}) async {
  final png = await _png(100, drawHeight);
  final pb = _Pb()
    ..string(1, '2.0.0')
    ..message(2, (m) {
      m
        ..float(1, 100)
        ..float(2, 200)
        ..int32(3, fps)
        ..int32(4, frames);
    });
  for (var i = 0; i < frames; i++) {
    pb
      ..message(3, (m) {
        m
          ..string(1, 'f$i')
          ..bytes(2, png);
      })
      ..message(4, (m) {
        m.string(1, 'f$i');
        for (var j = 0; j < frames; j++) {
          m.message(2, (f) {
            if (j != i) return; // hidden (alpha 0).
            // A clip path: only the package's player draws it.
            if (vector && i == 0) f.string(4, 'M0 0 L100 0 L100 200 Z');
            f
              ..float(1, 1)
              ..message(2, (l) {
                l
                  ..float(3, 100)
                  ..float(4, drawHeight.toDouble());
              })
              ..message(3, (t) {
                t
                  ..float(1, 1)
                  ..float(4, 1);
              });
          });
        }
      });
  }
  pb
    ..message(3, (m) {
      m
        ..string(1, 's')
        ..bytes(2, svgaFixtureMp3);
    })
    ..message(3, (m) {
      m
        ..string(1, 't')
        ..bytes(2, svgaFixtureMp3);
    })
    ..message(5, (m) {
      m
        ..string(1, 's')
        ..int32(2, 2)
        ..int32(3, 6)
        ..int32(4, 120)
        ..int32(5, 900);
    })
    ..message(5, (m) => m.string(1, 't'));
  return Uint8List.fromList(ZLibCodec().encode(pb.done()));
}

class FakeSvgaPlayer implements AudioPlayer {
  new(this.log);

  final List<String> log;
  Duration? position;
  bool stopped = false;
  bool disposed = false;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    this.position = position;
    if (source is BytesSource) log.add('play ${source.bytes.length}');
  }

  @override
  Future<void> stop() async {
    stopped = true;
    log.add('stop');
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
