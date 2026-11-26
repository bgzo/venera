import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/bangumi.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/network/bangumi.dart';

void main() {
  group('seriesStatusFromInfobox', () {
    test('completed when an end date exists', () {
      expect(
        seriesStatusFromInfobox([
          {'key': '开始', 'value': '2001-07-12'},
          {'key': '结束', 'value': '2010-06-12'},
        ]),
        BangumiSeriesStatus.completed,
      );
    });

    test('ongoing when only a start date exists', () {
      expect(
        seriesStatusFromInfobox([
          {'key': '连载开始', 'value': '2020-04-28'},
          {'key': '册数', 'value': '112卷既刊'},
        ]),
        BangumiSeriesStatus.ongoing,
      );
    });

    test('follows the explicit serialization status field', () {
      expect(
        seriesStatusFromInfobox([
          {'key': '连载状态', 'value': '已完结'},
        ]),
        BangumiSeriesStatus.completed,
      );
      expect(
        seriesStatusFromInfobox([
          {'key': '連載狀態', 'value': '連載中'},
        ]),
        BangumiSeriesStatus.ongoing,
      );
    });

    test('ongoing when volumes are marked as still publishing', () {
      expect(
        seriesStatusFromInfobox([
          {'key': '册数', 'value': '112卷既刊'},
        ]),
        BangumiSeriesStatus.ongoing,
      );
    });

    test('unknown without start or end metadata', () {
      expect(
        seriesStatusFromInfobox([
          {'key': '册数', 'value': '24'},
        ]),
        BangumiSeriesStatus.unknown,
      );
      expect(seriesStatusFromInfobox(null), BangumiSeriesStatus.unknown);
    });
  });

  group('nextAutoType', () {
    test('wish becomes reading once there is progress', () {
      expect(
        nextAutoType(BangumiCollectionType.wish, progress: 0, totalEps: 10),
        BangumiCollectionType.wish,
      );
      expect(
        nextAutoType(BangumiCollectionType.wish, progress: 1, totalEps: 10),
        BangumiCollectionType.doing,
      );
    });

    test('reading becomes completed at the last chapter', () {
      expect(
        nextAutoType(BangumiCollectionType.doing, progress: 10, totalEps: 10),
        BangumiCollectionType.done,
      );
      expect(
        nextAutoType(BangumiCollectionType.doing, progress: 9, totalEps: 10),
        BangumiCollectionType.doing,
      );
    });

    test('unknown total never auto-completes', () {
      expect(
        nextAutoType(BangumiCollectionType.doing, progress: 100, totalEps: 0),
        BangumiCollectionType.doing,
      );
    });

    test('on hold and dropped are never changed automatically', () {
      for (final type in [
        BangumiCollectionType.onHold,
        BangumiCollectionType.dropped,
      ]) {
        expect(nextAutoType(type, progress: 10, totalEps: 10), type);
      }
    });
  });

  group('historyProgress', () {
    History history({int ep = 0, int? group, List<String> read = const []}) {
      return History.fromMap({
        'type': 0,
        'time': 0,
        'title': 'title',
        'subtitle': '',
        'cover': '',
        'ep': ep,
        'page': 1,
        'id': '1',
        'readEpisode': read,
        'max_page': 1,
        'chapter_group': group,
      });
    }

    test('uses the chapter index for flat chapter lists', () {
      expect(historyProgress(history(ep: 12, read: ['1', '2'])), 12);
    });

    test('counts distinct chapters for grouped chapter lists', () {
      expect(
        historyProgress(history(ep: 2, group: 1, read: ['1-1', '1-2'])),
        2,
      );
    });
  });

  group('reconcileLink', () {
    BangumiLink link({
      BangumiCollectionType type = BangumiCollectionType.wish,
      int epStatus = 0,
    }) {
      return BangumiLink(
        comicId: '1',
        sourceKey: 'source',
        subjectId: 2,
        subjectName: 'Name',
        subjectNameCn: '',
        seriesStatus: BangumiSeriesStatus.ongoing,
        totalEps: 10,
        totalVolumes: 0,
        collectionType: type,
        epStatus: epStatus,
        updatedAt: DateTime(2026),
      );
    }

    test('returns null when the local copy already matches', () {
      expect(
        reconcileLink(
          link(type: BangumiCollectionType.doing, epStatus: 3),
          const BangumiUserCollection(
            type: BangumiCollectionType.doing,
            epStatus: 3,
          ),
        ),
        isNull,
      );
    });

    test('adopts the remote type and progress, including a lower progress', () {
      final updated = reconcileLink(
        link(type: BangumiCollectionType.doing, epStatus: 5),
        const BangumiUserCollection(
          type: BangumiCollectionType.onHold,
          epStatus: 2,
        ),
      );
      expect(updated, isNotNull);
      expect(updated!.collectionType, BangumiCollectionType.onHold);
      expect(updated.epStatus, 2);
      expect(updated.comicId, '1');
    });
  });

  group('JSON parsing', () {
    test('subject metadata and infobox', () {
      final subject = BangumiSubject.fromJson({
        'id': 34373,
        'name': 'NARUTO -ナルト-',
        'name_cn': '火影忍者',
        'platform': '漫画',
        'eps': 700,
        'volumes': 72,
        'series': true,
        'date': '2000-03-03',
        'images': {'grid': 'https://lain.bgm.tv/grid.jpg'},
        'infobox': [
          {'key': '结束', 'value': '2014-11-10'},
        ],
      });
      expect(subject.id, 34373);
      expect(subject.displayName, '火影忍者');
      expect(subject.eps, 700);
      expect(subject.volumes, 72);
      expect(subject.series, isTrue);
      expect(subject.cover, 'https://lain.bgm.tv/grid.jpg');
      expect(subject.coverLarge, 'https://lain.bgm.tv/grid.jpg');
      expect(subject.seriesStatus, BangumiSeriesStatus.completed);
    });

    test('search result pagination', () {
      final result = BangumiSearchResult.fromJson({
        'total': 3,
        'limit': 2,
        'offset': 0,
        'data': [
          {'id': 1, 'name': 'A'},
          {'id': 2, 'name': 'B'},
        ],
      });
      expect(result.items.length, 2);
      expect(result.total, 3);
      expect(result.hasMore, isTrue);

      final lastPage = BangumiSearchResult.fromJson({
        'total': 3,
        'limit': 2,
        'offset': 2,
        'data': [
          {'id': 3, 'name': 'C'},
        ],
      });
      expect(lastPage.hasMore, isFalse);
    });

    test('user avatar', () {
      final user = BangumiUser.fromJson({
        'username': 'bool',
        'nickname': 'Bool',
        'avatar': {
          'large': 'https://lain.bgm.tv/l.jpg',
          'medium': 'https://lain.bgm.tv/m.jpg',
          'small': 'https://lain.bgm.tv/s.jpg',
        },
      });
      expect(user.displayName, 'Bool');
      expect(user.avatar, 'https://lain.bgm.tv/l.jpg');

      final empty = BangumiUser.fromJson({'username': 'bool'});
      expect(empty.avatar, '');
    });

    test('user collection', () {
      final collection = BangumiUserCollection.fromJson({
        'type': 3,
        'ep_status': 12,
      });
      expect(collection.type, BangumiCollectionType.doing);
      expect(collection.epStatus, 12);
    });
  });
}
