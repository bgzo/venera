part of 'settings_page.dart';

class BangumiSettings extends StatefulWidget {
  const BangumiSettings({super.key});

  @override
  State<BangumiSettings> createState() => _BangumiSettingsState();
}

class _BangumiSettingsState extends State<BangumiSettings> {
  late final TextEditingController _tokenController;

  var _showToken = false;
  var _testing = false;
  BangumiUser? _account;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: BangumiManager().token);
    BangumiManager().addListener(_onManagerChanged);
    if (_tokenController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _test(silent: true);
        }
      });
    }
  }

  void _onManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    BangumiManager().removeListener(_onManagerChanged);
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _test({bool silent = false}) async {
    if (_testing) {
      return;
    }
    final token = _tokenController.text.trim();
    await BangumiManager().setToken(token);
    if (!mounted) return;
    final normalizedToken = BangumiManager().token;
    if (_tokenController.text.trim() != normalizedToken) {
      _tokenController.text = normalizedToken;
    }
    if (normalizedToken.isEmpty) {
      setState(() {
        _account = null;
        _error = null;
      });
      await _applyEnabled(false);
      if (!mounted) return;
      if (!silent) {
        context.showMessage(message: 'Token cleared'.tl);
      }
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      final me = await BangumiClient(normalizedToken).getMe();
      if (!mounted) return;
      setState(() => _account = me);
      if (!silent) {
        context.showMessage(
          message: 'Connected as @name'.tlParams({'name': me.displayName}),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await BangumiManager().disableForAuthError(e);
      if (!mounted) return;
      setState(() {
        _account = null;
        _error = bangumiErrorText(e);
      });
      if (!silent) {
        context.showMessage(message: bangumiErrorText(e));
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _applyEnabled(bool value) async {
    await BangumiManager().setEnabled(value);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enabled = appdata.settings['bangumiEnabled'] == true;
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BangumiIcon(size: 22, monochrome: true),
              const SizedBox(width: 8),
              Text('Bangumi'.tl),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usage'.tl, style: ts.s16),
                    const SizedBox(height: 6),
                    Text(
                      'Token is stored locally and is not synced via WebDAV.'
                          .tl,
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Token expiry is managed by Bangumi; check it on the '
                              'token page.'
                          .tl,
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automatic sync updates chapter progress only; volume '
                              'progress is not synced.'
                          .tl,
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Long press a comic and choose Bangumi to link it.'.tl,
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () {
                        launchUrlString(
                          'https://next.bgm.tv/demo/access-token',
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Get or manage Access Token'.tl),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                obscureText: !_showToken,
                decoration: InputDecoration(
                  labelText: 'Bangumi Access Token'.tl,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showToken ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _showToken = !_showToken);
                    },
                  ),
                ),
                onSubmitted: (_) => _test(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Button.filled(
                      isLoading: _testing,
                      onPressed: () {
                        if (!_testing) {
                          _test();
                        }
                      },
                      child: Text('Save and test'.tl),
                    ),
                  ),
                ],
              ),
              if (_account != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _BangumiAvatar(url: _account!.avatar),
                  title: Text(
                    'Connected as @name'.tlParams({
                      'name': _account!.displayName,
                    }),
                  ),
                  subtitle: Text('@${_account!.username}'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: Text('Enable Bangumi sync'.tl),
                subtitle: Text(
                  enabled
                      ? 'Link comics and sync reading progress with Bangumi.'.tl
                      : 'Save a valid Access Token before enabling.'.tl,
                ),
                trailing: Switch(
                  value: enabled,
                  onChanged: enabled || (_account != null && !_testing)
                      ? (value) => _applyEnabled(value)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text('Linked comics'.tl),
                subtitle: Text(
                  'View and edit the comics linked to Bangumi.'.tl,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showPopUpWidget(context, const LinkedComicsPage());
                },
              ),
              if (enabled) ...[
                const Divider(height: 32),
                _SwitchSetting(
                  title: 'Auto sync reading progress'.tl,
                  settingKey: 'bangumiAutoSync',
                  subtitle:
                      'Update Bangumi ep_status when a new chapter is read.'.tl,
                ),
                _SwitchSetting(
                  title: 'Sync notification'.tl,
                  settingKey: 'bangumiSyncReminder',
                  subtitle:
                      'Show a notification after an automatic progress sync.'
                          .tl,
                ),
                _SwitchSetting(
                  title: 'Show Bangumi status on comic tile'.tl,
                  settingKey: 'showBangumiStatusOnTile',
                  onChanged: App.forceRebuild,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _BangumiAvatar extends StatelessWidget {
  const _BangumiAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.surfaceContainerHighest,
      ),
      child: url.isEmpty
          ? const Icon(Icons.person, size: size * 0.6)
          : AnimatedImage(
              image: CachedImageProvider(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
    );
  }
}
