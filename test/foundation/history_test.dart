import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';

import '../support/app_test_harness.dart';

void main() {
  setUpAll(initAppForTest);

  test('find returns the history for the requested source', () {
    final manager = HistoryManager();
    manager.clearHistory();
    manager.addHistory(_history(ComicType.local));
    manager.addHistory(_history(const ComicType(1)));

    expect(manager.find('shared', ComicType.local)?.type, ComicType.local);
    expect(
      manager.find('shared', const ComicType(1))?.type,
      const ComicType(1),
    );

    manager.clearHistory();
  });
}

History _history(ComicType type) {
  return History.fromMap({
    'id': 'shared',
    'type': type.value,
    'title': 'title',
    'subtitle': '',
    'cover': '',
    'time': 0,
    'ep': 1,
    'page': 1,
    'readEpisode': <String>[],
    'max_page': 1,
    'chapter_group': null,
  });
}
