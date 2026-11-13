import 'dart:io';
import 'dart:typed_data';

/// A fresh path for a clip in the app's temporary folder.
Future<String?> newVoicePath() async {
  final dir = await Directory.systemTemp.createTemp('kabso_voice');
  return '${dir.path}/clip.m4a';
}

/// The clip's bytes; the file (and its folder) is deleted after.
Future<Uint8List?> takeVoiceBytes(String path) async {
  final file = File(path);
  try {
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  } finally {
    await deleteVoiceFile(path);
  }
}

/// Deletes a clip that will not be sent.
Future<void> deleteVoiceFile(String path) async {
  try {
    await File(path).parent.delete(recursive: true);
  } on FileSystemException {
    // Already gone.
  }
}
