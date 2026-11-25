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
    if (_tokenController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _test(silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
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
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                    'Connected as @name'.tlParams({
                      'name': _account!.displayName,
                    }),
                  ),
                  subtitle: Text('@${_account!.username}'),
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
              TextButton.icon(
                onPressed: () {
                  launchUrlString('https://next.bgm.tv/demo/access-token');
                },
                icon: const Icon(Icons.open_in_new),
                label: Text('Get Access Token'.tl),
              ),
              Text(
                'Token is stored locally and is not synced via WebDAV.'.tl,
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Long press a comic and choose Bangumi to link it.'.tl,
                style: context.textTheme.bodySmall,
              ),
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
              const Divider(height: 32),
              _SwitchSetting(
                title: 'Auto sync reading progress'.tl,
                settingKey: 'bangumiAutoSync',
                subtitle:
                    'Update Bangumi ep_status when a new chapter is read.'.tl,
              ),
              _SwitchSetting(
                title: 'Show Bangumi status on comic tile'.tl,
                settingKey: 'showBangumiStatusOnTile',
                onChanged: App.forceRebuild,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}
