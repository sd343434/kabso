import 'dart:typed_data';

/// Voice clips are not recorded on this platform (the web).
Future<String?> newVoicePath() async => null;

Future<Uint8List?> takeVoiceBytes(String path) async => null;

Future<void> deleteVoiceFile(String path) async {}
