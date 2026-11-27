import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera/utils/data.dart';

void main() {
  test('pruneAutoExportBackups keeps the newest 10 archives by name', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));

    final base = DateTime(2026, 1, 1);
    // Invert mtimes on purpose: copied backups get a fresh mtime that does not
    // match the timestamp in their file name.
    for (var i = 0; i < 12; i++) {
      final day = (i + 1).toString().padLeft(2, '0');
      final file = File('${dir.path}/data_202601${day}_000000.venera')
        ..writeAsStringSync('backup $i');
      file.setLastModifiedSync(base.add(Duration(hours: 11 - i)));
    }
    File('${dir.path}/notes.txt').writeAsStringSync('keep me');
    File(
      '${dir.path}/data_20260110_000000.venera.tmp',
    ).writeAsStringSync('partial');

    await pruneAutoExportBackups(dir);

    final names = dir
        .listSync()
        .whereType<File>()
        .map((file) => file.path.split(Platform.pathSeparator).last)
        .toSet();
    expect(names.length, 11);
    expect(names, contains('notes.txt'));
    expect(names, isNot(contains('data_20260110_000000.venera.tmp')));
    expect(names, isNot(contains('data_20260101_000000.venera')));
    expect(names, isNot(contains('data_20260102_000000.venera')));
    expect(names, contains('data_20260111_000000.venera'));
    expect(names, contains('data_20260112_000000.venera'));
  });

  test('autoExportTimestamp zero-pads every field', () {
    expect(
      autoExportTimestamp(DateTime(2026, 3, 1, 5, 4, 3)),
      '20260301_050403',
    );
    expect(
      autoExportTimestamp(DateTime(2026, 12, 31, 23, 59, 59)),
      '20261231_235959',
    );
  });
}
