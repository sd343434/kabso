// Deterministic in-memory images for widget and golden tests. The PNGs are
// encoded here in plain Dart (stored/uncompressed deflate), so the bytes
// never depend on the engine, the network or the host OS.

import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

final Map<String, MemoryImage> _cache = {};

/// A vertical two-colour gradient with soft diagonal bands, standing in for
/// a live cover or avatar photo. Same arguments → same bytes.
MemoryImage fixtureImage({
  required Color top,
  required Color bottom,
  int width = 90,
  int height = 120,
}) => _cache.putIfAbsent(
  '${top.toARGB32()}-${bottom.toARGB32()}-$width-$height',
  () => MemoryImage(_gradientPng(top, bottom, width, height)),
);

/// Bytes that are not an image: decoding fails, which exercises the
/// error builders (cover unavailable, avatar initials).
final MemoryImage brokenFixtureImage = MemoryImage(
  Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7]),
);

Uint8List _gradientPng(Color top, Color bottom, int width, int height) {
  int channel(double a, double b, double t) =>
      ((a + (b - a) * t) * 255).round().clamp(0, 255);
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    final t = y / (height - 1);
    for (var x = 0; x < width; x++) {
      final band = ((x + y) ~/ 12).isEven ? 0.0 : 0.08;
      final r = channel(top.r, bottom.r, t);
      final g = channel(top.g, bottom.g, t);
      final b = channel(top.b, bottom.b, t);
      raw
        ..addByte((r * (1 - band)).round())
        ..addByte((g * (1 - band)).round())
        ..addByte((b * (1 - band)).round())
        ..addByte(255);
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  return (BytesBuilder()
        ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', _zlibStored(raw.toBytes())))
        ..add(_chunk('IEND', Uint8List(0))))
      .toBytes();
}

Uint8List _chunk(String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)
    ..setUint32(0, _crc32(Uint8List.fromList([...typeBytes, ...data])));
  return (BytesBuilder()
        ..add(length.buffer.asUint8List())
        ..add(typeBytes)
        ..add(data)
        ..add(crc.buffer.asUint8List()))
      .toBytes();
}

/// zlib stream made of uncompressed ("stored") deflate blocks.
Uint8List _zlibStored(Uint8List data) {
  const maxBlock = 0xFFFF;
  final out = BytesBuilder()..add(const [0x78, 0x01]);
  var offset = 0;
  do {
    final size = (data.length - offset).clamp(0, maxBlock);
    final last = offset + size >= data.length;
    out
      ..addByte(last ? 1 : 0)
      ..addByte(size & 0xFF)
      ..addByte(size >> 8)
      ..addByte(~size & 0xFF)
      ..addByte((~size >> 8) & 0xFF)
      ..add(Uint8List.sublistView(data, offset, offset + size));
    offset += size;
  } while (offset < data.length);
  var a = 1;
  var b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  final adler = ByteData(4)..setUint32(0, (b << 16) | a);
  return (out..add(adler.buffer.asUint8List())).toBytes();
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c.isOdd ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
