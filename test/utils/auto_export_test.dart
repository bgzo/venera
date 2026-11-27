import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera/utils/data.dart';

void main() {
  test('pruneAutoExportBackups keeps the newest 10 archives', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));

    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 12; i++) {
      final file = File('${dir.path}/data_$i.venera')
        ..writeAsStringSync('backup $i');
      file.setLastModifiedSync(base.add(Duration(hours: i)));
    }
    File('${dir.path}/notes.txt').writeAsStringSync('keep me');

    await pruneAutoExportBackups(dir);

    final names = dir
        .listSync()
        .whereType<File>()
        .map((file) => file.path.split(Platform.pathSeparator).last)
        .toSet();
    expect(names.length, 11);
    expect(names, contains('notes.txt'));
    expect(names, isNot(contains('data_0.venera')));
    expect(names, isNot(contains('data_1.venera')));
    expect(names, contains('data_11.venera'));
  });
}
