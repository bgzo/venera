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

Future<void> showBangumiDialog(Comic comic) {
  return showDialog<void>(
    context: App.rootContext,
    builder: (_) => _BangumiDialog(comic: comic),
  );
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
      body: links.isEmpty
          ? Center(child: Text('No linked comics'.tl))
          : ListView.builder(
              itemCount: links.length,
              itemBuilder: (context, index) {
                final link = links[index];
                return ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
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
                  onTap: () => showBangumiDialog(
                    Comic(
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
            ),
    );
  }
}

class _BangumiDialog extends StatefulWidget {
  const _BangumiDialog({required this.comic});

  final Comic comic;

  @override
  State<_BangumiDialog> createState() => _BangumiDialogState();
}

class _BangumiDialogState extends State<_BangumiDialog> {
  final _manager = BangumiManager();

  late final TextEditingController _searchController;

  BangumiLink? _link;
  BangumiSubject? _subject;
  BangumiUserCollection? _remote;
  var _results = <BangumiSubject>[];
  var _type = BangumiCollectionType.wish;
  var _loading = false;
  var _searching = false;
  var _saving = false;
  var _searched = false;
  String? _error;
  var _localEp = 0;

  bool get _hasToken => _manager.token.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.comic.title);
    _localEp = _manager.localProgress(widget.comic.id, widget.comic.sourceKey);
    _link = _manager.linkOf(widget.comic.id, widget.comic.sourceKey);
    if (_link != null) {
      _type = _link!.collectionType;
      if (_hasToken) {
        _loadLink();
      }
    } else if (_hasToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _search();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLink() async {
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

  Future<void> _search() async {
    if (_searching) {
      return;
    }
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
      _error = null;
    });
    try {
      final results = await BangumiClient(
        _manager.token,
      ).searchSubjects(keyword);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _error = bangumiErrorText(e);
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectSubject(BangumiSubject subject) async {
    setState(() {
      _subject = subject;
      _remote = null;
      _type = _defaultType(subject, null);
      _loading = true;
      _error = null;
    });
    try {
      final remote = await BangumiClient(
        _manager.token,
      ).getCollection(subject.id);
      if (!mounted) return;
      setState(() {
        _remote = remote;
        _type = _defaultType(subject, remote);
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
    final link = _link;
    if (subject == null && link == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final totalEps = subject?.eps ?? link!.totalEps;
      final local = totalEps > 0 ? min(_localEp, totalEps) : _localEp;
      final baseEp = max(
        local,
        max(_remote?.epStatus ?? 0, link?.epStatus ?? 0),
      );
      if (link == null) {
        _link = await _manager.linkAndSync(
          comicId: widget.comic.id,
          sourceKey: widget.comic.sourceKey,
          subject: subject!,
          type: _type,
          epStatus: baseEp,
        );
      } else {
        final refreshed = subject == null
            ? link
            : link.copyWith(
                subjectName: subject.name,
                subjectNameCn: subject.nameCn,
                seriesStatus: subject.seriesStatus,
                totalEps: subject.eps,
                totalVolumes: subject.volumes,
              );
        _link = await _manager.updateLink(
          refreshed,
          type: _type,
          epStatus: baseEp,
        );
      }
      if (!mounted) return;
      context.showMessage(message: 'Synced to Bangumi'.tl);
      context.pop();
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
            context.pop();
          }
        });
      },
    );
  }

  void _openSettings() {
    context.pop();
    App.rootContext.to(
      () => const SettingsPage(initialPage: bangumiSettingsPageIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: 'Bangumi'.tl,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading || _searching) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            if (!_hasToken)
              _buildSetup(context)
            else if (_link == null)
              _buildSearch(context)
            else
              ..._buildSelected(context),
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  Widget _buildSetup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configure Bangumi Access Token in Settings > Bangumi'.tl),
        const SizedBox(height: 8),
        Text(
          'Token is stored locally and is not synced via WebDAV.'.tl,
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search on Bangumi'.tl,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _searching ? null : _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 8),
        if (_searched && !_searching && _results.isEmpty && _error == null)
          Text('No results'.tl),
        if (_results.isNotEmpty) ...[
          Text('Search results'.tl, style: context.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final subject in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: _SubjectCover(
                cover: subject.cover,
                selected: _subject?.id == subject.id,
              ),
              title: Text(subject.displayName),
              subtitle: Text(
                [
                  if (subject.name != subject.displayName) subject.name,
                  if (subject.date.isNotEmpty) subject.date,
                  if (subject.platform.isNotEmpty) subject.platform,
                  if (subject.series) 'Series'.tl,
                ].join(' · '),
              ),
              onTap: (_loading || _saving)
                  ? null
                  : () => _selectSubject(subject),
            ),
        ],
        if (_subject != null) ..._buildSelected(context),
      ],
    );
  }

  List<Widget> _buildSelected(BuildContext context) {
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

    return [
      const Divider(),
      Text(name, style: context.textTheme.titleMedium),
      if (original.isNotEmpty && original != name)
        Text(original, style: context.textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text('${'Series status'.tl}: ${seriesStatus.labelKey.tl}'),
          if (totalEps > 0) Text('${'Total chapters'.tl}: $totalEps'),
          if (totalVolumes > 0) Text('${'Total volumes'.tl}: $totalVolumes'),
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
      const SizedBox(height: 12),
      Text('Status'.tl, style: context.textTheme.titleSmall),
      const SizedBox(height: 4),
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
    ];
  }

  List<Widget> _buildActions(BuildContext context) {
    if (!_hasToken) {
      return [
        if (_link != null)
          TextButton(onPressed: _unlink, child: Text('Unlink'.tl)),
        TextButton(onPressed: context.pop, child: Text('Cancel'.tl)),
        FilledButton(onPressed: _openSettings, child: Text('Open settings'.tl)),
      ];
    }
    return [
      if (_link != null)
        TextButton(
          onPressed: _saving ? null : _unlink,
          child: Text('Unlink'.tl),
        ),
      TextButton(
        onPressed: _saving ? null : context.pop,
        child: Text('Cancel'.tl),
      ),
      if (_subject != null || _link != null)
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save and sync'.tl),
        ),
    ];
  }
}

class _SubjectCover extends StatelessWidget {
  const _SubjectCover({required this.cover, required this.selected});

  final String cover;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 56,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: cover.isEmpty
                    ? const Icon(Icons.menu_book_outlined, size: 20)
                    : AnimatedImage(
                        image: CachedImageProvider(cover),
                        fit: BoxFit.cover,
                        width: 40,
                        height: 56,
                      ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 10,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
