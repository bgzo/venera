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

  test('pruneExportTempFiles removes only stale files', () async {
    final dir = Directory.systemTemp.createTempSync('venera_export_temp');
    addTearDown(() => dir.deleteSync(recursive: true));
    final old = File('${dir.path}/old.venera')
      ..writeAsStringSync('old')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final fresh = File('${dir.path}/fresh.venera')..writeAsStringSync('fresh');

    await pruneExportTempFiles(dir);

    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test('autoExportInto saves, deletes the source, and prunes', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (var i = 0; i < 11; i++) {
      final day = (i + 1).toString().padLeft(2, '0');
      File(
        '${dir.path}/data_200001${day}_000000.venera',
      ).writeAsStringSync('old $i');
    }
    final source = File('${dir.path}/source.venera')
      ..writeAsStringSync('payload');

    await autoExportInto(dir, () async => source);

    expect(source.existsSync(), isFalse);
    final archives = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.venera'))
        .toList();
    expect(archives, hasLength(10));
    expect(
      File('${dir.path}/data_20000101_000000.venera').existsSync(),
      isFalse,
    );
    expect(
      File('${dir.path}/data_20000102_000000.venera').existsSync(),
      isFalse,
    );
    expect(
      File('${dir.path}/data_20000111_000000.venera').existsSync(),
      isTrue,
    );
    final newest = archives.singleWhere(
      (file) =>
          !file.path.split(Platform.pathSeparator).last.startsWith('data_2000'),
    );
    expect(newest.readAsStringSync(), 'payload');
  });

  test('saveAutoExportArchive writes a timestamped copy', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = File('${dir.path}/source.venera')
      ..writeAsStringSync('payload');

    await saveAutoExportArchive(source, dir, DateTime(2026, 3, 1, 5, 4, 3));

    final target = File('${dir.path}/data_20260301_050403.venera');
    expect(target.readAsStringSync(), 'payload');
    expect(File('${target.path}.tmp').existsSync(), isFalse);
  });

  test('saveAutoExportArchive overwrites an existing archive', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));
    final time = DateTime(2026, 3, 1, 5, 4, 3);
    final target = File('${dir.path}/data_20260301_050403.venera')
      ..writeAsStringSync('old');
    final source = File('${dir.path}/source.venera')..writeAsStringSync('new');

    await saveAutoExportArchive(source, dir, time);

    expect(target.readAsStringSync(), 'new');
    expect(File('${target.path}.tmp').existsSync(), isFalse);
  });

  test('saveAutoExportArchive removes temp file when copy fails', () async {
    final dir = Directory.systemTemp.createTempSync('venera_auto_export');
    addTearDown(() => dir.deleteSync(recursive: true));
    final temp = File('${dir.path}/data_20260301_050403.venera.tmp')
      ..writeAsStringSync('partial');

    await expectLater(
      saveAutoExportArchive(
        File('${dir.path}/missing.venera'),
        dir,
        DateTime(2026, 3, 1, 5, 4, 3),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(temp.existsSync(), isFalse);
  });
}
