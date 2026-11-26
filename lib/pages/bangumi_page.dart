import 'dart:math';

import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/bangumi.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/network/bangumi.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/translations.dart';

Future<void> showBangumiDialog(Comic comic) async {
  final manager = BangumiManager();
  if (!manager.isInitialized) {
    App.rootContext.showMessage(
      message:
          'Bangumi storage is unavailable. Restart the app and try again.'.tl,
    );
    return;
  }
  if (manager.token.isEmpty) {
    await _showTokenSetup();
    return;
  }
  if (!manager.isEnabled) {
    App.rootContext.showMessage(
      message: 'Enable Bangumi sync in Settings > Bangumi'.tl,
    );
    return;
  }
  final link = manager.linkOf(comic.id, comic.sourceKey);
  await showPopUpWidget(
    App.rootContext,
    link == null
        ? BangumiSearchPage(comic: comic)
        : BangumiSubjectPage(comic: comic),
  );
}

Future<void> _showTokenSetup() {
  return showDialog<void>(
    context: App.rootContext,
    builder: (context) => ContentDialog(
      title: 'Bangumi'.tl,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configure Bangumi Access Token in Settings > Bangumi'.tl),
            const SizedBox(height: 8),
            Text(
              'Token is stored locally and is not synced via WebDAV.'.tl,
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text('Cancel'.tl)),
        FilledButton(
          onPressed: () {
            context.pop();
            App.rootContext.to(
              () => const SettingsPage(initialPage: bangumiSettingsPageIndex),
            );
          },
          child: Text('Open settings'.tl),
        ),
      ],
    ),
  );
}

void _closePage(BuildContext context) {
  if (context.canPop()) {
    context.pop(true);
  } else {
    App.pop();
  }
}

class BangumiSearchPage extends StatefulWidget {
  const BangumiSearchPage({required this.comic, super.key});

  final Comic comic;

  @override
  State<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends State<BangumiSearchPage> {
  final _manager = BangumiManager();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  var _items = <BangumiSubject>[];
  var _loading = false;
  var _searched = false;
  var _hasMore = false;
  String? _error;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.comic.title;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _search();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _items = [];
      _hasMore = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    try {
      final result = await BangumiClient(
        _manager.token,
      ).searchSubjects(keyword, offset: 0);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = bangumiErrorText(e));
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) {
      return;
    }
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    final requestId = _requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BangumiClient(
        _manager.token,
      ).searchSubjects(keyword, offset: _items.length);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      context.showMessage(message: bangumiErrorText(e));
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openSubject(BangumiSubject subject) async {
    final saved = await context.to<bool>(
      () => BangumiSubjectPage(comic: widget.comic, subject: subject),
    );
    if (saved == true && mounted) {
      _closePage(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: 'Bangumi'.tl,
      titleIcon: const BangumiIcon(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search on Bangumi'.tl,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_loading && _items.isEmpty) const LinearProgressIndicator(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _search, child: Text('Retry'.tl)),
          ],
        ).paddingHorizontal(24),
      );
    }
    if (_searched && !_loading && _items.isEmpty) {
      return Center(child: Text('No results'.tl));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount:
          _items.length + (_items.isNotEmpty && (_loading || _hasMore) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text('Load more'.tl),
                    ),
            ),
          );
        }
        return _SubjectListTile(
          subject: _items[index],
          onTap: () => _openSubject(_items[index]),
        );
      },
    );
  }
}

class BangumiSubjectPage extends StatefulWidget {
  const BangumiSubjectPage({required this.comic, this.subject, super.key});

  final Comic comic;

  /// When set, this is a new/replacement link flow and any existing link is
  /// ignored.
  final BangumiSubject? subject;

  @override
  State<BangumiSubjectPage> createState() => _BangumiSubjectPageState();
}

class _BangumiSubjectPageState extends State<BangumiSubjectPage> {
  final _manager = BangumiManager();

  BangumiLink? _link;
  BangumiSubject? _subject;
  BangumiUserCollection? _remote;
  var _type = BangumiCollectionType.wish;
  var _loading = false;
  var _saving = false;
  String? _error;
  var _localEp = 0;

  bool get _isNewLink => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _localEp = _manager.localProgress(widget.comic.id, widget.comic.sourceKey);
    if (_isNewLink) {
      _subject = widget.subject;
      _type = _defaultType(widget.subject!, null);
      _loadRemote(widget.subject!.id);
    } else {
      _link = _manager.linkOf(widget.comic.id, widget.comic.sourceKey);
      _type = _link?.collectionType ?? BangumiCollectionType.wish;
      if (_link != null) {
        _loadLinked();
      }
    }
  }

  Future<void> _loadLinked() async {
    final link = _link!;
    setState(() => _loading = true);
    try {
      final client = BangumiClient(_manager.token);
      final subject = await client.getSubject(link.subjectId);
      final refreshed = await _manager.refreshMetadata(link, subject);
      if (!mounted) return;
      setState(() {
        _subject = subject;
        _link = refreshed;
      });
      try {
        final remote = await client.getCollection(link.subjectId);
        if (!mounted) return;
        setState(() {
          _remote = remote;
          if (remote != null) {
            _type = remote.type;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = bangumiErrorText(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = bangumiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRemote(int subjectId) async {
    setState(() => _loading = true);
    try {
      final remote = await BangumiClient(
        _manager.token,
      ).getCollection(subjectId);
      if (!mounted) return;
      setState(() {
        _remote = remote;
        _type = _defaultType(_subject!, remote);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = bangumiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BangumiCollectionType _defaultType(
    BangumiSubject subject,
    BangumiUserCollection? remote,
  ) {
    final local = subject.eps > 0 ? min(_localEp, subject.eps) : _localEp;
    var type =
        remote?.type ??
        (local > 0 ? BangumiCollectionType.doing : BangumiCollectionType.wish);
    if (type == BangumiCollectionType.wish && local > 0) {
      type = BangumiCollectionType.doing;
    }
    if ((type == BangumiCollectionType.wish ||
            type == BangumiCollectionType.doing) &&
        subject.eps > 0 &&
        local >= subject.eps) {
      type = BangumiCollectionType.done;
    }
    return type;
  }

  Future<void> _save() async {
    final subject = _subject;
    if (subject == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final totalEps = subject.eps > 0 ? subject.eps : (_link?.totalEps ?? 0);
      final local = totalEps > 0 ? min(_localEp, totalEps) : _localEp;
      final baseEp = max(
        local,
        max(_remote?.epStatus ?? 0, _link?.epStatus ?? 0),
      );
      if (_link == null) {
        await _manager.linkAndSync(
          comicId: widget.comic.id,
          sourceKey: widget.comic.sourceKey,
          subject: subject,
          type: _type,
          epStatus: baseEp,
        );
      } else {
        final refreshed = _link!.copyWith(
          subjectName: subject.name,
          subjectNameCn: subject.nameCn,
          seriesStatus: subject.seriesStatus,
          totalEps: subject.eps,
          totalVolumes: subject.volumes,
        );
        await _manager.updateLink(refreshed, type: _type, epStatus: baseEp);
      }
      if (!mounted) return;
      context.showMessage(message: 'Synced to Bangumi'.tl);
      _closePage(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = bangumiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _unlink() {
    final link = _link;
    if (link == null) {
      return;
    }
    showConfirmDialog(
      context: context,
      title: 'Unlink Bangumi'.tl,
      content:
          'Only removes the local link. The Bangumi collection is not deleted.'
              .tl,
      confirmText: 'Unlink'.tl,
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        _manager.removeLink(link).then((_) {
          if (mounted) {
            _closePage(context);
          }
        });
      },
    );
  }

  Future<void> _changeSubject() async {
    final saved = await context.to<bool>(
      () => BangumiSearchPage(comic: widget.comic),
    );
    if (saved == true && mounted) {
      _closePage(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    final link = _link;
    final name = subject?.displayName ?? link?.displayName ?? '';
    final original = subject?.name ?? link?.subjectName ?? '';
    final seriesStatus =
        subject?.seriesStatus ??
        link?.seriesStatus ??
        BangumiSeriesStatus.unknown;
    final totalEps = subject?.eps ?? link?.totalEps ?? 0;
    final totalVolumes = subject?.volumes ?? link?.totalVolumes ?? 0;
    final localEp = totalEps > 0 ? min(_localEp, totalEps) : _localEp;
    final cover = subject?.coverLarge ?? '';

    return PopUpWidgetScaffold(
      title: 'Bangumi'.tl,
      titleIcon: const BangumiIcon(),
      tailing: link != null && !_isNewLink
          ? [
              IconButton(
                tooltip: 'Change subject'.tl,
                icon: const Icon(Icons.search),
                onPressed: _saving ? null : _changeSubject,
              ),
            ]
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_loading) const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BangumiCover(cover: cover, width: 140, height: 200, radius: 10),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.textTheme.titleLarge),
                    if (original.isNotEmpty && original != name) ...[
                      const SizedBox(height: 4),
                      Text(original, style: context.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${'Series status'.tl}: ${seriesStatus.labelKey.tl}',
                        ),
                        if (totalEps > 0)
                          Text('${'Total chapters'.tl}: $totalEps'),
                        if (totalVolumes > 0)
                          Text('${'Total volumes'.tl}: $totalVolumes'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                '${'Local read'.tl}: $localEp'
                '${totalEps > 0 ? ' / $totalEps' : ''}',
              ),
              if (_remote != null)
                Text(
                  '${'Bangumi progress'.tl}: ${_remote!.epStatus}'
                  '${totalEps > 0 ? ' / $totalEps' : ''}',
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Status'.tl, style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in BangumiCollectionType.values)
                ChoiceChip(
                  label: Text(type.labelKey.tl),
                  selected: _type == type,
                  onSelected: _saving
                      ? null
                      : (_) {
                          setState(() => _type = type);
                        },
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: subject == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save and sync'.tl),
          ),
          if (link != null && !_isNewLink) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _unlink,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text('Unlink'.tl),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectListTile extends StatelessWidget {
  const _SubjectListTile({required this.subject, required this.onTap});

  final BangumiSubject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (subject.name != subject.displayName) subject.name,
      if (subject.date.isNotEmpty) subject.date,
      if (subject.platform.isNotEmpty) subject.platform,
      if (subject.series) 'Series'.tl,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BangumiCover(
              cover: subject.cover,
              width: 64,
              height: 90,
              radius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BangumiCover extends StatelessWidget {
  const _BangumiCover({
    required this.cover,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final String cover;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: cover.isEmpty
            ? const Icon(Icons.menu_book_outlined)
            : AnimatedImage(
                image: CachedImageProvider(cover),
                fit: BoxFit.cover,
                width: width,
                height: height,
              ),
      ),
    );
  }
}

class LinkedComicsPage extends StatefulWidget {
  const LinkedComicsPage({super.key});

  @override
  State<LinkedComicsPage> createState() => _LinkedComicsPageState();
}

class _LinkedComicsPageState extends State<LinkedComicsPage> {
  final _manager = BangumiManager();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = _manager.allLinks();
    return PopUpWidgetScaffold(
      title: 'Linked comics'.tl,
      titleIcon: const BangumiIcon(monochrome: true),
      body: links.isEmpty
          ? Center(child: Text('No linked comics'.tl))
          : ListView.builder(
              itemCount: links.length,
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  leading: const BangumiIcon(size: 24, monochrome: true),
                  title: Text(link.displayName),
                  subtitle: Text(
                    [
                      link.collectionType.labelKey.tl,
                      link.seriesStatus.labelKey.tl,
                    ].join(' · '),
                  ),
                  trailing: Text(
                    '${link.epStatus}'
                    '${link.totalEps > 0 ? ' / ${link.totalEps}' : ''}',
                  ),
                  onTap: () {
                    context.to(
                      () => BangumiSubjectPage(
                        comic: Comic(
                          link.displayName,
                          '',
                          link.comicId,
                          null,
                          null,
                          '',
                          link.sourceKey,
                          null,
                          null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
