import 'package:venera/foundation/app.dart';
import 'package:venera/network/app_dio.dart';

const _bangumiBaseUrl = 'https://api.bgm.tv';

/// Publication status of a Bangumi subject.
///
/// The v0 API does not expose this directly, so it is derived from the wiki
/// infobox (see [seriesStatusFromInfobox]).
enum BangumiSeriesStatus {
  unknown(0),
  ongoing(1),
  completed(2);

  const BangumiSeriesStatus(this.value);

  final int value;

  static BangumiSeriesStatus fromValue(int value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    return unknown;
  }

  String get labelKey => switch (this) {
    unknown => 'Bangumi: unknown',
    ongoing => 'Bangumi: ongoing',
    completed => 'Bangumi: finished',
  };
}

/// Book collection types of Bangumi.
enum BangumiCollectionType {
  wish(1),
  done(2),
  doing(3),
  onHold(4),
  dropped(5);

  const BangumiCollectionType(this.value);

  final int value;

  static BangumiCollectionType fromValue(int value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return wish;
  }

  String get labelKey => switch (this) {
    wish => 'Bangumi: plan to read',
    done => 'Bangumi: completed',
    doing => 'Bangumi: reading',
    onHold => 'Bangumi: on hold',
    dropped => 'Bangumi: dropped',
  };
}

/// Derive the publication status from a subject's infobox.
///
/// Manga wiki entries use "开始 / 结束" (or "连载开始 / 连载结束"), and some use
/// "连载状态". Entries without either are unknown, which is common for
/// individual volumes rather than series main entries.
BangumiSeriesStatus seriesStatusFromInfobox(dynamic infobox) {
  if (infobox is! List) {
    return BangumiSeriesStatus.unknown;
  }
  var hasStart = false;
  for (final item in infobox) {
    if (item is! Map) {
      continue;
    }
    final key = item['key']?.toString() ?? '';
    final value = item['value'];
    if (key.contains('连载状态') || key.contains('連載狀態')) {
      final text = value is List
          ? value
                .map(
                  (e) => e is Map ? (e['v']?.toString() ?? '') : e.toString(),
                )
                .join(' ')
          : value?.toString() ?? '';
      if (text.contains('完结') || text.contains('完結')) {
        return BangumiSeriesStatus.completed;
      }
      if (text.contains('连载') || text.contains('連載')) {
        return BangumiSeriesStatus.ongoing;
      }
    }
    if (key.contains('结束') || key.contains('結束')) {
      return BangumiSeriesStatus.completed;
    }
    final valueText = value?.toString() ?? '';
    if ((key == '册数' || key == '话数') &&
        (valueText.contains('既刊') || valueText.contains('未完'))) {
      hasStart = true;
    }
    if (key.contains('开始') || key.contains('開始')) {
      hasStart = true;
    }
  }
  return hasStart ? BangumiSeriesStatus.ongoing : BangumiSeriesStatus.unknown;
}

/// Automatic status transition while reading.
///
/// On-hold and dropped entries keep their status. Wish becomes reading once
/// there is progress, and reading becomes completed when all known chapters
/// have been read. Books with unknown total episodes never auto-complete.
BangumiCollectionType nextAutoType(
  BangumiCollectionType current, {
  required int progress,
  required int totalEps,
}) {
  if (current == BangumiCollectionType.onHold ||
      current == BangumiCollectionType.dropped) {
    return current;
  }
  var type = current;
  if (type == BangumiCollectionType.wish && progress > 0) {
    type = BangumiCollectionType.doing;
  }
  if (type != BangumiCollectionType.done &&
      totalEps > 0 &&
      progress >= totalEps) {
    type = BangumiCollectionType.done;
  }
  return type;
}

class BangumiUser {
  const BangumiUser({
    required this.username,
    required this.nickname,
    required this.avatar,
  });

  final String username;
  final String nickname;
  final String avatar;

  String get displayName => nickname.isNotEmpty ? nickname : username;

  factory BangumiUser.fromJson(Map<String, dynamic> json) {
    return BangumiUser(
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: _firstImageUrl(json['avatar'], const [
        'large',
        'medium',
        'small',
      ]),
    );
  }
}

class BangumiSubject {
  const BangumiSubject({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.platform,
    required this.eps,
    required this.volumes,
    required this.series,
    required this.date,
    required this.cover,
    required this.coverLarge,
    required this.seriesStatus,
  });

  final int id;
  final String name;
  final String nameCn;
  final String platform;

  /// Number of chapters for book subjects.
  final int eps;

  /// Number of volumes for book subjects.
  final int volumes;

  /// Whether this is the main entry of a series.
  final bool series;

  final String date;

  /// Cover image URL, preferring the grid-sized variant.
  final String cover;

  /// Larger cover image URL for detail pages.
  final String coverLarge;

  final BangumiSeriesStatus seriesStatus;

  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory BangumiSubject.fromJson(Map<String, dynamic> json) {
    return BangumiSubject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      nameCn: json['name_cn']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      eps: (json['eps'] as num?)?.toInt() ?? 0,
      volumes: (json['volumes'] as num?)?.toInt() ?? 0,
      series: json['series'] == true,
      date: json['date']?.toString() ?? '',
      cover: _firstImageUrl(json['images'], const [
        'grid',
        'small',
        'common',
        'medium',
        'large',
      ]),
      coverLarge: _firstImageUrl(json['images'], const [
        'common',
        'large',
        'medium',
        'grid',
        'small',
      ]),
      seriesStatus: seriesStatusFromInfobox(json['infobox']),
    );
  }
}

class BangumiSearchResult {
  const BangumiSearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<BangumiSubject> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore =>
      items.length >= limit && (total == 0 || offset + items.length < total);

  factory BangumiSearchResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final items = data is List
        ? data
              .whereType<Map>()
              .map((e) => BangumiSubject.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <BangumiSubject>[];
    return BangumiSearchResult(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      limit: (json['limit'] as num?)?.toInt() ?? items.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class BangumiUserCollection {
  const BangumiUserCollection({required this.type, required this.epStatus});
  final BangumiCollectionType type;
  final int epStatus;

  factory BangumiUserCollection.fromJson(Map<String, dynamic> json) {
    return BangumiUserCollection(
      type: BangumiCollectionType.fromValue(
        (json['type'] as num?)?.toInt() ?? 1,
      ),
      epStatus: (json['ep_status'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Coarse error category, so callers do not depend on message wording.
enum BangumiErrorKind { auth, permission, notFound, rateLimit, storage, other }

class BangumiException implements Exception {
  BangumiException(this.message, {this.kind = BangumiErrorKind.other});

  final String message;
  final BangumiErrorKind kind;

  @override
  String toString() => message;
}

class BangumiClient {
  BangumiClient(this.token);

  final String token;

  late final AppDio _dio = AppDio(
    BaseOptions(
      baseUrl: _bangumiBaseUrl,
      headers: {
        'User-Agent':
            'bgzo/venera/${App.version} '
            '(https://github.com/bgzo/venera)',
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ),
  );

  Options _getOptions() => Options(
    headers: const {'cache-time': 'no'},
    extra: const {
      'maskHeadersInLog': ['Authorization'],
    },
  );

  Options _postOptions() => Options(
    extra: const {
      'maskHeadersInLog': ['Authorization'],
    },
  );

  Future<BangumiUser> getMe() async {
    try {
      final res = await _dio.get('/v0/me', options: _getOptions());
      return BangumiUser.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  Future<BangumiSearchResult> searchSubjects(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/v0/search/subjects',
        queryParameters: {'limit': limit, 'offset': offset},
        data: {
          'keyword': keyword,
          'filter': {
            'type': [1],
          },
        },
        options: _postOptions(),
      );
      return BangumiSearchResult.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  Future<BangumiSubject> getSubject(int subjectId) async {
    try {
      final res = await _dio.get(
        '/v0/subjects/$subjectId',
        options: _getOptions(),
      );
      return BangumiSubject.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _error(e);
    }
  }

  /// Returns null when the subject is not in the user's collection.
  Future<BangumiUserCollection?> getCollection(int subjectId) async {
    try {
      final res = await _dio.get(
        '/v0/users/-/collections/$subjectId',
        options: _getOptions(),
      );
      return BangumiUserCollection.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _error(e);
    }
  }

  /// Updates a collection. Null fields are omitted: Bangumi creates one
  /// timeline entry per sent field, even when the value did not change.
  Future<void> updateCollection(
    int subjectId, {
    BangumiCollectionType? type,
    int? epStatus,
    int? volStatus,
  }) async {
    final data = <String, dynamic>{
      if (type != null) 'type': type.value,
      if (epStatus != null) 'ep_status': epStatus,
      if (volStatus != null) 'vol_status': volStatus,
    };
    if (data.isEmpty) {
      return;
    }
    try {
      await _dio.post(
        '/v0/users/-/collections/$subjectId',
        data: data,
        options: _postOptions(),
      );
    } on DioException catch (e) {
      throw _error(e);
    }
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  throw BangumiException('Unexpected response from Bangumi');
}

String _firstImageUrl(dynamic images, List<String> keys) {
  if (images is! Map) {
    return '';
  }
  for (final key in keys) {
    final value = images[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

BangumiException _error(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401) {
    return BangumiException(
      'Bangumi token is invalid or expired',
      kind: BangumiErrorKind.auth,
    );
  }
  if (code == 403) {
    return BangumiException(
      'Bangumi permission denied',
      kind: BangumiErrorKind.permission,
    );
  }
  if (code == 404) {
    return BangumiException(
      'Not found on Bangumi',
      kind: BangumiErrorKind.notFound,
    );
  }
  if (code == 429) {
    return BangumiException(
      'Too many requests. Please try again later.',
      kind: BangumiErrorKind.rateLimit,
    );
  }
  final data = e.response?.data;
  if (data is Map) {
    final title = data['title']?.toString();
    final description = data['description']?.toString();
    final detail = [
      title,
      description,
    ].where((e) => e != null && e.isNotEmpty).join(': ');
    if (detail.isNotEmpty) {
      return BangumiException(detail);
    }
  }
  return BangumiException(e.message ?? e.toString());
}
