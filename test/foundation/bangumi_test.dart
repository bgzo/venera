import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/bangumi.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/network/bangumi.dart';

import '../support/app_test_harness.dart';

void main() {
  setUpAll(initAppForTest);
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

  group('BangumiManager auto sync', () {
    final manager = BangumiManager();
    late Database db;
    late _FakeBangumiClient client;

    const subject = BangumiSubject(
      id: 2,
      name: 'Name',
      nameCn: '',
      platform: '漫画',
      eps: 10,
      volumes: 0,
      series: true,
      date: '',
      cover: '',
      coverLarge: '',
      seriesStatus: BangumiSeriesStatus.ongoing,
    );

    setUp(() {
      manager.resetForTest();
      db = sqlite3.openInMemory();
      manager.initForTest(db);
      client = _FakeBangumiClient();
      manager.clientFactory = (_) => client;
      appdata.settings['bangumiEnabled'] = true;
      appdata.settings['bangumiAutoSync'] = true;
      appdata.implicitData['bangumiToken'] = 'token';
    });

    tearDown(() {
      manager.resetForTest();
      db.dispose();
      appdata.settings['bangumiEnabled'] = false;
      appdata.settings['bangumiAutoSync'] = true;
      appdata.implicitData.remove('bangumiToken');
    });

    Future<BangumiLink> link({
      BangumiCollectionType type = BangumiCollectionType.wish,
      int epStatus = 0,
    }) async {
      final saved = await manager.linkAndSync(
        comicId: '1',
        sourceKey: 'local',
        subject: subject,
        type: type,
        epStatus: epStatus,
      );
      client.updates.clear();
      return saved;
    }

    History history(int ep) {
      return History.fromMap({
        'type': 0,
        'time': 0,
        'title': 'title',
        'subtitle': '',
        'cover': '',
        'ep': ep,
        'page': 1,
        'id': '1',
        'readEpisode': <String>[],
        'max_page': 1,
        'chapter_group': null,
      });
    }

    test('rejects writes after the database is unavailable', () async {
      manager.resetForTest();
      await expectLater(
        manager.linkAndSync(
          comicId: '1',
          sourceKey: 'local',
          subject: subject,
          type: BangumiCollectionType.wish,
          epStatus: 0,
        ),
        throwsA(isA<BangumiException>()),
      );
    });

    test('does nothing while the master switch is off', () async {
      await link();
      appdata.settings['bangumiEnabled'] = false;
      manager.autoSyncForTest(history(1));
      await Future<void>.delayed(Duration.zero);
      expect(client.updates, isEmpty);
    });

    test('does nothing while automatic sync is off', () async {
      await link();
      appdata.settings['bangumiAutoSync'] = false;
      manager.autoSyncForTest(history(1));
      await Future<void>.delayed(Duration.zero);
      expect(client.updates, isEmpty);
    });

    test('does not send progress when the collection is wish', () async {
      final saved = await manager.linkAndSync(
        comicId: '1',
        sourceKey: 'local',
        subject: subject,
        type: BangumiCollectionType.wish,
        epStatus: 5,
      );
      expect(saved.epStatus, 0);
      expect(client.updates.single.epStatus, 0);
    });

    test('resets progress when switching a link to wish', () async {
      final saved = await link(type: BangumiCollectionType.doing, epStatus: 5);
      final updated = await manager.updateLink(
        saved,
        type: BangumiCollectionType.wish,
        epStatus: 5,
      );
      expect(updated.epStatus, 0);
      expect(client.updates.single.epStatus, 0);
    });

    test('moves wish to doing and sends the new chapter', () async {
      await link();
      manager.autoSyncForTest(history(1));
      await Future<void>.delayed(Duration.zero);
      expect(client.updates, hasLength(1));
      expect(client.updates.single.type, BangumiCollectionType.doing);
      expect(client.updates.single.epStatus, 1);
    });

    test('completes at the last chapter and caps progress', () async {
      await link(type: BangumiCollectionType.doing, epStatus: 9);
      manager.autoSyncForTest(history(12));
      await Future<void>.delayed(Duration.zero);
      expect(client.updates.single.type, BangumiCollectionType.done);
      expect(client.updates.single.epStatus, 10);
    });

    test('skips on hold and dropped links', () async {
      for (final type in [
        BangumiCollectionType.onHold,
        BangumiCollectionType.dropped,
      ]) {
        await link(type: type);
        manager.autoSyncForTest(history(1));
        await Future<void>.delayed(Duration.zero);
        expect(client.updates, isEmpty);
        await manager.removeLink(manager.linkOf('1', 'local')!);
      }
    });

    test('ignores a second trigger while one sync is in flight', () async {
      await link();
      final blocker = Completer<void>();
      client.blocker = blocker;
      manager.autoSyncForTest(history(1));
      manager.autoSyncForTest(history(1));
      expect(client.updates, hasLength(1));
      blocker.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test(
      'does not overwrite a manual change made during the request',
      () async {
        final saved = await link();
        final blocker = Completer<void>();
        client.blocker = blocker;
        manager.autoSyncForTest(history(1));
        expect(client.updates, hasLength(1));

        client.blocker = null;
        await manager.updateLink(
          saved,
          type: BangumiCollectionType.onHold,
          epStatus: 0,
        );
        blocker.complete();
        await pumpEventQueue();

        expect(client.updates, hasLength(3));
        expect(client.updates.last.type, BangumiCollectionType.onHold);
        expect(client.updates.last.epStatus, 0);

        final latest = manager.linkOf('1', 'local')!;
        expect(latest.collectionType, BangumiCollectionType.onHold);
        expect(latest.epStatus, 0);
      },
    );

    test('converges the remote when progress changes in flight', () async {
      final saved = await link(type: BangumiCollectionType.doing);
      final blocker = Completer<void>();
      client.blocker = blocker;
      manager.autoSyncForTest(history(1));
      expect(client.updates, hasLength(1));

      client.blocker = null;
      await manager.updateLink(
        saved,
        type: BangumiCollectionType.doing,
        epStatus: 10,
      );
      blocker.complete();
      await pumpEventQueue();

      expect(client.updates, hasLength(3));
      expect(client.updates.last.type, isNull);
      expect(client.updates.last.epStatus, 10);
      expect(manager.linkOf('1', 'local')!.epStatus, 10);
    });

    test('turns the switch off and reports an auth failure', () async {
      await link();
      Object? failure;
      manager.onAutoSyncFailed = (_, _, error) => failure = error;
      client.error = BangumiException('Bangumi token is invalid or expired');

      manager.autoSyncForTest(history(1));
      await pumpEventQueue();

      expect(failure, isA<BangumiException>());
      expect(appdata.settings['bangumiEnabled'], isFalse);
    });

    test('keeps the switch on for a transient failure', () async {
      await link();
      Object? failure;
      manager.onAutoSyncFailed = (_, _, error) => failure = error;
      client.error = BangumiException('network down');

      manager.autoSyncForTest(history(1));
      await pumpEventQueue();

      expect(failure, isNotNull);
      expect(appdata.settings['bangumiEnabled'], isTrue);
    });

    test('disables the master switch only for auth errors', () async {
      await manager.disableForAuthError(BangumiException('network down'));
      expect(appdata.settings['bangumiEnabled'], isTrue);

      await manager.disableForAuthError(
        BangumiException('Bangumi token is invalid or expired'),
      );
      expect(appdata.settings['bangumiEnabled'], isFalse);
    });

    test('syncFromRemote overwrites the local type and progress', () async {
      final saved = await link(type: BangumiCollectionType.doing, epStatus: 5);
      final updated = await manager.syncFromRemote(
        saved,
        const BangumiUserCollection(
          type: BangumiCollectionType.onHold,
          epStatus: 2,
        ),
      );
      expect(updated.collectionType, BangumiCollectionType.onHold);
      expect(updated.epStatus, 2);
      expect(
        manager.linkOf('1', 'local')!.collectionType,
        BangumiCollectionType.onHold,
      );
    });

    test('localProgress uses the matching history source', () {
      HistoryManager().clearHistory();
      HistoryManager().addHistory(history(1));
      HistoryManager().addHistory(
        History.fromMap({
          'type': 1,
          'time': 0,
          'title': 'title',
          'subtitle': '',
          'cover': '',
          'ep': 7,
          'page': 1,
          'id': '1',
          'readEpisode': <String>[],
          'max_page': 1,
          'chapter_group': null,
        }),
      );
      expect(manager.localProgress('1', 'local'), 1);
      HistoryManager().clearHistory();
    });

    test('reuses the client until the token changes', () {
      var created = 0;
      manager.clientFactory = (_) {
        created++;
        return _FakeBangumiClient();
      };
      final first = manager.client;
      expect(identical(manager.client, first), isTrue);
      expect(created, 1);

      appdata.implicitData['bangumiToken'] = 'other';
      expect(identical(manager.client, first), isFalse);
      expect(created, 2);
    });
  });
}

class _FakeBangumiClient extends BangumiClient {
  _FakeBangumiClient() : super('token');

  final updates = <_FakeUpdate>[];
  Completer<void>? blocker;
  Object? error;

  @override
  Future<void> updateCollection(
    int subjectId, {
    BangumiCollectionType? type,
    int? epStatus,
    int? volStatus,
  }) async {
    updates.add(_FakeUpdate(type, epStatus));
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final waitFor = blocker;
    if (waitFor != null) {
      await waitFor.future;
    }
  }
}

class _FakeUpdate {
  const _FakeUpdate(this.type, this.epStatus);

  final BangumiCollectionType? type;
  final int? epStatus;
}
