import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import 'settings_pane.dart';
import 'settings_provider.dart';
import 'subsonic_provider.dart';

/// OpenSubsonic / Navidrome 服务器设置
class SubsonicSettings extends ConsumerWidget {
  const SubsonicSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final servers = ref.watch(subsonicServersProvider);

    return SettingsPane(
      title: '服务器',
      children: [
        // 服务器页是从"内容 → navidrome音乐库 → 连接配置"进入的,
        // 不占用左侧设置分类,这里提供返回入口。
        Align(
          alignment: Alignment.centerLeft,
          child: M3EButton.text(
            size: M3EButtonSize.sm,
            onPressed: () => ref
                .read(settingsCategoryProvider.notifier)
                .select(SettingsCategory.content),
            child: const Text('← 返回内容'),
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                'OpenSubsonic / Navidrome',
                style: theme.typeScale.titleMedium,
              ),
            ),
            M3EButton(
              size: M3EButtonSize.sm,
              icon: const Icon(Icons.add),
              label: const Text('添加服务器'),
              style: M3EButtonStyle.filled,
              onPressed: () => _openEditor(context, ref),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        servers.when(
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
            child: Center(
              child: M3ELoadingIndicator(
                color: scheme.primary,
                containerColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          error: (error, _) => Text(
            '读取服务器配置失败: $error',
            style: theme.typeScale.bodyMedium.copyWith(color: scheme.error),
          ),
          data: (list) => list.isEmpty
              ? _empty(theme, scheme)
              : M3EList(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final server = list[index];
                    return M3EListItem(
                      leading: M3EShapeContainer.square(
                        width: theme.spacing.xxl * 1.5,
                        height: theme.spacing.xxl * 1.5,
                        color: scheme.secondaryContainer,
                        child: const Icon(Icons.dns),
                      ),
                      headline: server.name,
                      supportingText:
                          '${server.baseUrl} · ${server.authMode.label}',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          M3EIconButton(
                            size: M3EIconButtonSize.xs,
                            icon: const Icon(Icons.edit),
                            tooltip: '编辑',
                            onPressed: () => _openEditor(
                              context,
                              ref,
                              existing: server,
                            ),
                          ),
                          M3EIconButton(
                            size: M3EIconButtonSize.xs,
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () =>
                                _confirmDelete(context, ref, server),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _empty(M3EThemeData theme, M3EColorScheme scheme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: theme.spacing.md),
          Text('还没有配置服务器', style: theme.typeScale.titleMedium),
          SizedBox(height: theme.spacing.xs),
          Text(
            '添加 OpenSubsonic / Navidrome 服务器后即可浏览远端音乐。',
            textAlign: TextAlign.center,
            style: theme.typeScale.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    SubsonicServerConfig? existing,
  }) async {
    String? secret;
    if (existing != null) {
      try {
        secret = await ref
            .read(subsonicServersProvider.notifier)
            .readSecret(existing.id);
      } catch (e) {
        debugPrint('读取服务器密钥失败: $e');
      }
    }
    if (!context.mounted) return;

    await M3EBottomSheet.show<void>(
      context,
      builder: (sheetContext) => _ServerEditorSheet(
        existing: existing,
        initialSecret: secret,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SubsonicServerConfig server,
  ) async {
    final theme = M3ETheme.of(context);
    await M3EBottomSheet.show<void>(
      context,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('删除服务器', style: theme.typeScale.titleLarge),
              SizedBox(height: theme.spacing.sm),
              Text(
                '确定删除“${server.name}”？本机保存的密钥也会一起移除。',
                style: theme.typeScale.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  M3EButton.text(
                    size: M3EButtonSize.sm,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('取消'),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  M3EButton(
                    size: M3EButtonSize.sm,
                    style: M3EButtonStyle.filled,
                    label: const Text('删除'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(subsonicServersProvider.notifier)
                          .delete(server.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerEditorSheet extends ConsumerStatefulWidget {
  const _ServerEditorSheet({
    this.existing,
    this.initialSecret,
  });

  final SubsonicServerConfig? existing;
  final String? initialSecret;

  @override
  ConsumerState<_ServerEditorSheet> createState() => _ServerEditorSheetState();
}

class _ServerEditorSheetState extends ConsumerState<_ServerEditorSheet> {
  late final String _id;
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _apiKey;
  late final TextEditingController _password;
  late SubsonicAuthMode _authMode;

  bool _testing = false;
  bool _saving = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? SubsonicServersNotifier.newId();
    _name = TextEditingController(text: existing?.name ?? '');
    _url = TextEditingController(text: existing?.baseUrl ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _authMode = existing?.authMode ?? SubsonicAuthMode.apiKey;

    // API Key 与密码使用独立 controller,切换认证方式时互不串值
    final secret = widget.initialSecret ?? '';
    _apiKey = TextEditingController(
      text: _authMode == SubsonicAuthMode.apiKey ? secret : '',
    );
    _password = TextEditingController(
      text: _authMode == SubsonicAuthMode.token ? secret : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _username.dispose();
    _apiKey.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _secretText =>
      _authMode == SubsonicAuthMode.apiKey ? _apiKey.text : _password.text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.lg,
        theme.spacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? '添加服务器' : '编辑服务器',
                    style: theme.typeScale.titleLarge,
                  ),
                ),
                M3EIconButton(
                  size: M3EIconButtonSize.xs,
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            M3ETextField(
              key: const ValueKey('subsonic-name'),
              controller: _name,
              label: '名称',
              placeholder: '例如：家里的 Navidrome',
            ),
            SizedBox(height: theme.spacing.md),
            M3ETextField(
              key: const ValueKey('subsonic-url'),
              controller: _url,
              label: '服务器地址',
              placeholder: 'https://music.example.com',
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: theme.spacing.md),
            M3ESegmentedButton<SubsonicAuthMode>(
              segments: const [
                M3ESegment(
                  value: SubsonicAuthMode.apiKey,
                  label: 'API Key',
                ),
                M3ESegment(
                  value: SubsonicAuthMode.token,
                  label: '用户名密码',
                ),
              ],
              selected: {_authMode},
              onSelectionChanged: (value) {
                setState(() {
                  _authMode = value.first;
                  _error = null;
                  _info = null;
                });
              },
            ),
            SizedBox(height: theme.spacing.md),
            if (_authMode == SubsonicAuthMode.apiKey)
              M3ETextField(
                key: const ValueKey('subsonic-api-key'),
                controller: _apiKey,
                label: 'API Key',
                placeholder: '在服务器中生成的 API Key',
                obscureText: true,
                showPasswordToggle: true,
              )
            else ...[
              M3ETextField(
                key: const ValueKey('subsonic-username'),
                controller: _username,
                label: '用户名',
                placeholder: 'Subsonic 用户名',
              ),
              SizedBox(height: theme.spacing.md),
              M3ETextField(
                key: const ValueKey('subsonic-password'),
                controller: _password,
                label: '密码',
                placeholder: 'Subsonic 密码',
                obscureText: true,
                showPasswordToggle: true,
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: theme.spacing.md),
              Text(
                _error!,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            if (_info != null) ...[
              SizedBox(height: theme.spacing.md),
              Text(
                _info!,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                M3EButton(
                  size: M3EButtonSize.sm,
                  style: M3EButtonStyle.tonal,
                  label: Text(_testing ? '测试中…' : '测试连接'),
                  onPressed: _testing || _saving ? null : _test,
                ),
                SizedBox(width: theme.spacing.sm),
                M3EButton(
                  size: M3EButtonSize.sm,
                  style: M3EButtonStyle.filled,
                  label: Text(_saving ? '保存中…' : '保存'),
                  onPressed: _testing || _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SubsonicServerConfig? _buildConfig() {
    final rawUrl = _url.text.trim();
    final url = rawUrl.contains('://') ? rawUrl : 'https://$rawUrl';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _error = '请输入有效的服务器地址（http/https）';
      return null;
    }

    final secret = _secretText;
    if (secret.isEmpty) {
      _error = _authMode == SubsonicAuthMode.apiKey ? '请输入 API Key' : '请输入密码';
      return null;
    }
    final username = _username.text.trim();
    if (_authMode == SubsonicAuthMode.token && username.isEmpty) {
      _error = '请输入用户名';
      return null;
    }

    final name = _name.text.trim().isEmpty
        ? (uri.host.isEmpty ? '服务器' : uri.host)
        : _name.text.trim();

    return SubsonicServerConfig(
      id: _id,
      name: name,
      baseUrl: url,
      authMode: _authMode,
      username: _authMode == SubsonicAuthMode.token ? username : null,
    );
  }

  Future<void> _test() async {
    final config = _buildConfig();
    if (config == null) {
      setState(() {});
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await ref.read(subsonicServersProvider.notifier).test(
            config: config,
            secret: _secretText,
          );
      if (!mounted) return;
      setState(() {
        _info = '连接成功：${info.serverType ?? 'Subsonic'} '
            '${info.serverVersion ?? ''}'
            '${info.openSubsonic ? ' · OpenSubsonic' : ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final config = _buildConfig();
    if (config == null) {
      setState(() {});
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(subsonicServersProvider.notifier).save(
            config: config,
            secret: _secretText,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
