import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/sqlite_connection.dart';
import 'package:venera/network/bangumi.dart';
import 'package:venera/utils/translations.dart';

/// User-facing text for errors returned by [BangumiClient].
String bangumiErrorText(Object error) {
  final text = error.toString();
  if (text.contains('invalid or expired')) {
    return 'Bangumi token is invalid or expired'.tl;
  }
  if (text.contains('permission denied')) {
    return 'Bangumi permission denied'.tl;
  }
  if (text.contains('Not found on Bangumi')) {
    return 'Not found on Bangumi'.tl;
  }
  if (text.contains('Too many requests')) {
    return 'Too many requests. Please try again later.'.tl;
  }
  return text;
}

/// Current reading progress for a history record.
///
/// Flat chapter lists use the current chapter index. Grouped chapter lists use
/// the number of distinct chapters read, because the flat index cannot be
/// recovered without the chapter structure.
int historyProgress(History history) =>
    history.group == null ? history.ep : history.readEpisode.length;

/// Local mapping between a comic and its Bangumi subject.
class BangumiLink {
  const BangumiLink({
    required this.comicId,
    required this.sourceKey,
    required this.subjectId,
    required this.subjectName,
    required this.subjectNameCn,
    required this.seriesStatus,
    required this.totalEps,
    required this.totalVolumes,
    required this.collectionType,
    required this.epStatus,
    required this.updatedAt,
  });

  final String comicId;
  final String sourceKey;
  final int subjectId;
  final String subjectName;
  final String subjectNameCn;
  final BangumiSeriesStatus seriesStatus;
  final int totalEps;
  final int totalVolumes;
  final BangumiCollectionType collectionType;

  /// Last progress synced to Bangumi, not the current local progress.
  final int epStatus;

  final DateTime updatedAt;

  String get displayName =>
      subjectNameCn.isNotEmpty ? subjectNameCn : subjectName;

  BangumiLink copyWith({
    String? subjectName,
    String? subjectNameCn,
    BangumiSeriesStatus? seriesStatus,
    int? totalEps,
    int? totalVolumes,
    BangumiCollectionType? collectionType,
    int? epStatus,
    DateTime? updatedAt,
  }) {
    return BangumiLink(
      comicId: comicId,
      sourceKey: sourceKey,
      subjectId: subjectId,
      subjectName: subjectName ?? this.subjectName,
      subjectNameCn: subjectNameCn ?? this.subjectNameCn,
      seriesStatus: seriesStatus ?? this.seriesStatus,
      totalEps: totalEps ?? this.totalEps,
      totalVolumes: totalVolumes ?? this.totalVolumes,
      collectionType: collectionType ?? this.collectionType,
      epStatus: epStatus ?? this.epStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BangumiLink.fromRow(Row row) {
    return BangumiLink(
      comicId: row['comic_id'] as String,
      sourceKey: row['source_key'] as String,
      subjectId: row['subject_id'] as int,
      subjectName: row['subject_name'] as String,
      subjectNameCn: row['subject_name_cn'] as String,
      seriesStatus: BangumiSeriesStatus.fromValue(row['series_status'] as int),
      totalEps: row['total_eps'] as int,
      totalVolumes: row['total_volumes'] as int,
      collectionType: BangumiCollectionType.fromValue(
        row['collection_type'] as int,
      ),
      epStatus: row['ep_status'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}

class BangumiManager with ChangeNotifier {
  BangumiManager._();

  static final BangumiManager _instance = BangumiManager._();

  factory BangumiManager() => _instance;

  late Database _db;

  bool isInitialized = false;

  final _links = <String, BangumiLink>{};

  final _syncing = <String>{};

  /// Called after an automatic progress sync succeeds. The UI uses this for
  /// the optional sync reminder.
  void Function(BangumiLink link, int ep)? onAutoSynced;

  /// Called when an automatic progress sync fails, so failures do not stay
  /// silent.
  void Function(BangumiLink link, int ep, Object error)? onAutoSyncFailed;

  Future<void> init() async {
    if (isInitialized) {
      return;
    }
    _db = openSqliteDatabase('${App.dataPath}/bangumi.db');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS bangumi_links (
        comic_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        subject_name TEXT NOT NULL,
        subject_name_cn TEXT NOT NULL,
        series_status INTEGER NOT NULL DEFAULT 0,
        total_eps INTEGER NOT NULL DEFAULT 0,
        total_volumes INTEGER NOT NULL DEFAULT 0,
        collection_type INTEGER NOT NULL DEFAULT 1,
        ep_status INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (comic_id, source_key)
      );
    ''');
    for (final row in _db.select('SELECT * FROM bangumi_links;')) {
      final link = BangumiLink.fromRow(row);
      _links[_key(link.comicId, link.sourceKey)] = link;
    }
    HistoryManager().addListener(_onHistoryChanged);
    isInitialized = true;
    notifyListeners();
  }

  String get token =>
      ((appdata.implicitData['bangumiToken'] as String?) ?? '').trim();

  /// Whether the Bangumi feature is enabled and usable.
  bool get isEnabled =>
      appdata.settings['bangumiEnabled'] == true && token.isNotEmpty;

  Future<void> setEnabled(bool value) async {
    if (appdata.settings['bangumiEnabled'] == value) {
      return;
    }
    appdata.settings['bangumiEnabled'] = value;
    await appdata.saveData();
    notifyListeners();
  }

  /// Turns the master switch off when the token is no longer accepted, so an
  /// expired token stops retrying on every chapter.
  Future<void> disableForAuthError(Object error) async {
    if (!error.toString().contains('invalid or expired')) {
      return;
    }
    await setEnabled(false);
  }

  Future<void> setToken(String value) async {
    var token = value.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    if (token.isEmpty) {
      appdata.implicitData.remove('bangumiToken');
    } else {
      appdata.implicitData['bangumiToken'] = token;
    }
    await appdata.writeImplicitData();
  }

  BangumiLink? linkOf(String comicId, String sourceKey) {
    if (!isInitialized) {
      return null;
    }
    return _links[_key(comicId, sourceKey)];
  }

  List<BangumiLink> allLinks() {
    if (!isInitialized) {
      return const [];
    }
    final links = _links.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return links;
  }

  /// Number of chapters marked as read in the local history.
  int localProgress(String comicId, String sourceKey) {
    final history = HistoryManager().find(comicId, _comicType(sourceKey));
    return history == null ? 0 : historyProgress(history);
  }

  Future<BangumiLink> linkAndSync({
    required String comicId,
    required String sourceKey,
    required BangumiSubject subject,
    required BangumiCollectionType type,
    required int epStatus,
  }) async {
    final targetEp = type == BangumiCollectionType.done && subject.eps > 0
        ? max(epStatus, subject.eps)
        : epStatus;
    await BangumiClient(
      token,
    ).updateCollection(subject.id, type: type, epStatus: targetEp);
    final link = BangumiLink(
      comicId: comicId,
      sourceKey: sourceKey,
      subjectId: subject.id,
      subjectName: subject.name,
      subjectNameCn: subject.nameCn,
      seriesStatus: subject.seriesStatus,
      totalEps: subject.eps,
      totalVolumes: subject.volumes,
      collectionType: type,
      epStatus: targetEp,
      updatedAt: DateTime.now(),
    );
    await _save(link);
    return link;
  }

  Future<BangumiLink> updateLink(
    BangumiLink link, {
    required BangumiCollectionType type,
    required int epStatus,
  }) async {
    final targetEp = type == BangumiCollectionType.done && link.totalEps > 0
        ? max(epStatus, link.totalEps)
        : epStatus;
    await BangumiClient(
      token,
    ).updateCollection(link.subjectId, type: type, epStatus: targetEp);
    final updated = link.copyWith(
      collectionType: type,
      epStatus: targetEp,
      updatedAt: DateTime.now(),
    );
    await _save(updated);
    return updated;
  }

  /// Refresh stored subject metadata without touching the collection progress.
  Future<BangumiLink> refreshMetadata(
    BangumiLink link,
    BangumiSubject subject,
  ) async {
    final updated = link.copyWith(
      subjectName: subject.name,
      subjectNameCn: subject.nameCn,
      seriesStatus: subject.seriesStatus,
      totalEps: subject.eps,
      totalVolumes: subject.volumes,
    );
    await _save(updated);
    return updated;
  }

  Future<void> removeLink(BangumiLink link) async {
    _db.execute(
      'DELETE FROM bangumi_links WHERE comic_id = ? AND source_key = ?;',
      [link.comicId, link.sourceKey],
    );
    _links.remove(_key(link.comicId, link.sourceKey));
    notifyListeners();
  }

  void _onHistoryChanged() {
    if (!isInitialized || _links.isEmpty) {
      return;
    }
    if (!isEnabled || appdata.settings['bangumiAutoSync'] != true) {
      return;
    }
    for (final history in HistoryManager().cachedHistories.values.toList()) {
      _autoSync(history);
    }
  }

  void _autoSync(History history) {
    final link = linkOf(history.id, history.sourceKey);
    if (link == null) {
      return;
    }
    if (link.collectionType == BangumiCollectionType.onHold ||
        link.collectionType == BangumiCollectionType.dropped) {
      return;
    }
    final progress = historyProgress(history);
    if (progress <= link.epStatus) {
      return;
    }
    final capped = link.totalEps > 0 ? min(progress, link.totalEps) : progress;
    final next = nextAutoType(
      link.collectionType,
      progress: capped,
      totalEps: link.totalEps,
    );
    _syncInBackground(link, next, capped);
  }

  Future<void> _syncInBackground(
    BangumiLink link,
    BangumiCollectionType type,
    int ep,
  ) async {
    final key = _key(link.comicId, link.sourceKey);
    if (_syncing.contains(key)) {
      return;
    }
    _syncing.add(key);
    BangumiLink? saved;
    try {
      // Only send the collection type when it changes: Bangumi would create a
      // timeline entry for it on every chapter otherwise.
      await BangumiClient(token).updateCollection(
        link.subjectId,
        type: type != link.collectionType ? type : null,
        epStatus: ep,
      );
      // Do not undo a manual status change or unlink that happened while the
      // request was in flight.
      final latest = linkOf(link.comicId, link.sourceKey);
      if (latest == null ||
          latest.collectionType != link.collectionType ||
          latest.epStatus >= ep) {
        return;
      }
      final updated = link.copyWith(
        collectionType: type,
        epStatus: ep,
        updatedAt: DateTime.now(),
      );
      await _save(updated);
      saved = updated;
    } catch (e, s) {
      // Reading must not be interrupted by a failed background sync. The next
      // chapter retries because epStatus is only updated on success.
      Log.error(
        'Bangumi',
        'Failed to sync progress for ${link.comicId}: $e',
        s,
      );
      // An expired token would otherwise fail on every chapter.
      await disableForAuthError(e);
      onAutoSyncFailed?.call(link, ep, e);
    } finally {
      _syncing.remove(key);
    }
    if (saved != null) {
      onAutoSynced?.call(saved, ep);
    }
  }

  Future<void> _save(BangumiLink link) async {
    _db.execute(
      '''
      INSERT OR REPLACE INTO bangumi_links (
        comic_id, source_key, subject_id, subject_name, subject_name_cn,
        series_status, total_eps, total_volumes, collection_type, ep_status,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        link.comicId,
        link.sourceKey,
        link.subjectId,
        link.subjectName,
        link.subjectNameCn,
        link.seriesStatus.value,
        link.totalEps,
        link.totalVolumes,
        link.collectionType.value,
        link.epStatus,
        link.updatedAt.millisecondsSinceEpoch,
      ],
    );
    _links[_key(link.comicId, link.sourceKey)] = link;
    notifyListeners();
  }

  static String _key(String comicId, String sourceKey) =>
      '$sourceKey\u0000$comicId';

  static ComicType _comicType(String sourceKey) =>
      sourceKey == 'local' ? ComicType.local : ComicType.fromKey(sourceKey);
}
