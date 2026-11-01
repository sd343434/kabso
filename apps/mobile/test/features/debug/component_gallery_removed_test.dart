// D226 (owner «وازل معرض المكونات»): the KL-022 component gallery is
// removed from the app — no Settings row, no previews-hub entry, no
// `/debug/components` route and no screen. This guard keeps it out.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no component gallery anywhere in lib/', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final text = f.readAsStringSync();
          return text.contains('ComponentGallery') ||
              text.contains('debugComponents') ||
              text.contains('/debug/components') ||
              text.contains('settings.debug.components');
        })
        .map((f) => f.path)
        .toList();
    expect(users, isEmpty);
  });
}
