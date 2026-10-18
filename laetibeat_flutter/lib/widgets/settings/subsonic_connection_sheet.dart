import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import 'subsonic_provider.dart';

/// 打开 Navidrome 连接配置弹层。
/// 单服务器模式:已有配置时直接编辑唯一配置,不进入独立页面。
Future<void> showSubsonicConnectionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final servers = await _loadServers(ref);
  if (!context.mounted) return;
  final existing = servers.isEmpty ? null : servers.first;

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
    builder: (sheetContext) => SubsonicConnectionSheet(
      existing: existing,
      initialSecret: secret,
    ),
  );
}

Future<List<SubsonicServerConfig>> _loadServers(WidgetRef ref) async {
  try {
    return await ref.read(subsonicServersProvider.future);
  } catch (e) {
    debugPrint('读取服务器配置失败: $e');
    return const <SubsonicServerConfig>[];
  }
}

class SubsonicConnectionSheet extends ConsumerStatefulWidget {
  const SubsonicConnectionSheet({
    super.key,
    this.existing,
    this.initialSecret,
  });

  final SubsonicServerConfig? existing;
  final String? initialSecret;

  @override
  ConsumerState<SubsonicConnectionSheet> createState() =>
      _SubsonicConnectionSheetState();
}

class _SubsonicConnectionSheetState
    extends ConsumerState<SubsonicConnectionSheet> {
  late final String _id;
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _apiKey;
  late final TextEditingController _password;
  late SubsonicAuthMode _authMode;

  bool _testing = false;
  bool _saving = false;

  /// 测试成功标记。字段一旦变化就清空,保存随之禁用。
  bool _testPassed = false;

  /// 测试成功时的字段指纹,用于确保保存的是刚测试过的那套配置。
  String? _testedFingerprint;

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

  String get _normalizedUrl {
    final rawUrl = _url.text.trim();
    return rawUrl.contains('://') ? rawUrl : 'https://$rawUrl';
  }

  /// 当前输入内容的指纹。名称也纳入其中,任何字段变化都需要重新测试。
  String _fingerprint() => [
    _name.text.trim(),
    _normalizedUrl,
    _authMode.name,
    _authMode == SubsonicAuthMode.token ? _username.text.trim() : '',
    _secretText,
  ].join('\u0000');

  /// 测试结果是否仍对应当前输入
  bool get _testMatchesInput =>
      _testPassed && _testedFingerprint == _fingerprint();

  bool get _canSave => !_testing && !_saving && _testMatchesInput;

  void _onFieldChanged() {
    setState(() {
      _testPassed = false;
      _testedFingerprint = null;
      _error = null;
      _info = null;
    });
  }

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
                    widget.existing == null ? '连接 Navidrome' : '编辑连接',
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
            SizedBox(height: theme.spacing.xs),
            Text(
              '连接成功后不会自动同步音乐，请在“内容”页点击“同步音乐”。',
              style: theme.typeScale.bodySmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            M3ETextField(
              key: const ValueKey('subsonic-name'),
              controller: _name,
              label: '名称',
              placeholder: '例如：家里的 Navidrome',
              onChanged: (_) => _onFieldChanged(),
            ),
            SizedBox(height: theme.spacing.md),
            M3ETextField(
              key: const ValueKey('subsonic-url'),
              controller: _url,
              label: '服务器地址',
              placeholder: 'https://music.example.com',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onFieldChanged(),
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
                  _testPassed = false;
                  _testedFingerprint = null;
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
                onChanged: (_) => _onFieldChanged(),
              )
            else ...[
              M3ETextField(
                key: const ValueKey('subsonic-username'),
                controller: _username,
                label: '用户名',
                placeholder: 'Subsonic 用户名',
                onChanged: (_) => _onFieldChanged(),
              ),
              SizedBox(height: theme.spacing.md),
              M3ETextField(
                key: const ValueKey('subsonic-password'),
                controller: _password,
                label: '密码',
                placeholder: 'Subsonic 密码',
                obscureText: true,
                showPasswordToggle: true,
                onChanged: (_) => _onFieldChanged(),
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
              children: [
                Expanded(
                  child: Text(
                    _testMatchesInput ? '测试通过，可以保存' : '请先测试连接，测试成功后才能保存',
                    style: theme.typeScale.bodySmall.copyWith(
                      color: _testMatchesInput
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                M3EButton(
                  size: M3EButtonSize.sm,
                  style: M3EButtonStyle.tonal,
                  label: Text(_testing ? '测试中…' : '测试'),
                  onPressed: _testing || _saving ? null : _test,
                ),
                SizedBox(width: theme.spacing.sm),
                M3EButton(
                  size: M3EButtonSize.sm,
                  style: M3EButtonStyle.filled,
                  label: Text(_saving ? '保存中…' : '保存'),
                  onPressed: _canSave ? _save : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SubsonicServerConfig? _buildConfig() {
    final uri = Uri.tryParse(_normalizedUrl);
    if (uri == null ||
        uri.host.isEmpty ||
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
        ? (uri.host.isEmpty ? 'Navidrome' : uri.host)
        : _name.text.trim();

    return SubsonicServerConfig(
      id: _id,
      name: name,
      baseUrl: _normalizedUrl,
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

    final fingerprint = _fingerprint();
    setState(() {
      _testing = true;
      _testPassed = false;
      _testedFingerprint = null;
      _error = null;
      _info = null;
    });
    try {
      final info = await ref
          .read(subsonicServersProvider.notifier)
          .test(config: config, secret: _secretText);
      if (!mounted) return;
      setState(() {
        _testPassed = true;
        _testedFingerprint = fingerprint;
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
    if (!_canSave) return;

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
