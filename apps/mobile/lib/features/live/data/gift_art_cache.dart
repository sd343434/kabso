import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:path_provider/path_provider.dart';

/// Gift art hosted on the server (D126, CONVENTIONS §10.23): a gift's
/// `imageUrl` and `animationUrl` are downloaded on demand and kept on the
/// device, so a new gift needs no app release. The URLs are content-addressed
/// and immutable (new bytes, new URL), so a file once cached is never checked
/// again.
abstract class GiftArtCache {
  /// The app's cache; tests replace it.
  static GiftArtCache instance = DiskGiftArtCache();

  /// Animations at most this big are fetched when the gift panel opens;
  /// bigger ones only when a gift is sent or received.
  static const int prefetchMaxBytes = 2 * 1024 * 1024;

  /// The bytes of [url], from the device or downloaded once (concurrent
  /// calls share one download). Throws when the URL is refused or the
  /// download fails; a failed download is retried on the next call.
  Future<Uint8List> load(String url);

  /// Starts downloading [url] if it is not on the device; never throws.
  void prefetch(String url) {
    unawaited(load(url).then((_) {}, onError: (Object _) {}));
  }

  /// Prefetches the small animations of [catalogue] (the panel opened).
  void prefetchSmallAnimations(GiftCatalogue catalogue) {
    for (final gift in catalogue.data) {
      final url = gift.animationUrl;
      final bytes = gift.animationBytes;
      if (url != null && bytes != null && bytes <= prefetchMaxBytes) {
        prefetch(url);
      }
    }
  }

  /// Whether [url] may be fetched: https (plain http only in debug builds,
  /// for a local MinIO).
  static bool allowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http');
  }
}

/// [GiftArtCache] in the app's cache directory (`gift_art/`, which the OS
/// may clear): one file per URL, named by the URL's SHA-256, written whole
/// before it is used, oldest-used files removed past [maxTotalBytes].
class DiskGiftArtCache extends GiftArtCache {
  new({
    Dio? dio,
    Future<Directory> Function()? directory,
    this.maxTotalBytes = 300 * 1024 * 1024,
    this.maxFileBytes = 26 * 1024 * 1024,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               // Between bytes; a slow but moving download goes on.
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _directory = directory ?? _defaultDirectory;

  final Dio _dio;
  final Future<Directory> Function() _directory;

  /// The cache's size limit; the oldest-used files go first.
  final int maxTotalBytes;

  /// A file bigger than this is refused (the server's limit is 25 MiB).
  final int maxFileBytes;

  final _inFlight = <String, Future<File>>{};
  Future<Directory>? _dir;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/gift_art');

  Future<Directory> _root() => _dir ??= () async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return dir;
  }();

  /// The file of [url]: SHA-256 of the URL, plus the URL's extension.
  static String fileName(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final ext = RegExp(r'\.(png|webp|svga)$').firstMatch(path)?.group(0) ?? '';
    return '${sha256.convert(url.codeUnits)}$ext';
  }

  @override
  Future<Uint8List> load(String url) =>
      _file(url).then((file) => file.readAsBytes());

  Future<File> _file(String url) {
    if (!GiftArtCache.allowed(url)) {
      return Future.error(ArgumentError.value(url, 'url', 'not allowed'));
    }
    final running = _inFlight[url];
    if (running != null) return running;
    // (A block body: whenComplete would wait on the removed future, itself.)
    final future = _fetch(url).whenComplete(() {
      unawaited(_inFlight.remove(url));
    });
    _inFlight[url] = future;
    return future;
  }

  Future<File> _fetch(String url) async {
    final root = await _root();
    final file = File('${root.path}/${fileName(url)}');
    if (file.existsSync()) {
      // Remember it was used (the trim removes the oldest-used first).
      try {
        file.setLastModifiedSync(DateTime.now());
      } on FileSystemException {
        // Read-only times: the order is a little off, nothing else.
      }
      return file;
    }
    final part = File('${file.path}.part');
    final cancel = CancelToken();
    try {
      await _dio.download(
        url,
        part.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > maxFileBytes || total > maxFileBytes) {
            cancel.cancel('larger than $maxFileBytes bytes');
          }
        },
      );
      await part.rename(file.path);
    } on Object {
      if (part.existsSync()) await part.delete();
      rethrow;
    }
    unawaited(_trim(root, keep: file.path));
    return file;
  }

  /// Removes the oldest-used files while the cache is above its limit.
  Future<void> _trim(Directory root, {required String keep}) async {
    try {
      final files = <File, FileStat>{
        for (final e in root.listSync())
          if (e is File && !e.path.endsWith('.part')) e: e.statSync(),
      };
      var total = files.values.fold<int>(0, (sum, s) => sum + s.size);
      if (total <= maxTotalBytes) return;
      final oldest = files.keys.toList()
        ..sort((a, b) => files[a]!.modified.compareTo(files[b]!.modified));
      for (final f in oldest) {
        if (total <= maxTotalBytes) break;
        if (f.path == keep) continue;
        total -= files[f]!.size;
        await f.delete();
      }
    } on FileSystemException {
      // The OS may be clearing the cache itself; try again next time.
    }
  }
}
