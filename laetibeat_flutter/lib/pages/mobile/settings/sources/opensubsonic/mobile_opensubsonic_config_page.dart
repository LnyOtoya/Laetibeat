import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/widgets/settings/remote_sync_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../l10n/generated/app_localizations.dart';
import '../../../widgets/mobile_large_subpage_app_bar.dart';

enum _ServerScheme { http, https }

/// Opensubsonic 服务器配置页面。
class MobileOpensubsonicConfigPage extends ConsumerStatefulWidget {
  const MobileOpensubsonicConfigPage({super.key});

  @override
  ConsumerState<MobileOpensubsonicConfigPage> createState() =>
      _MobileOpensubsonicConfigPageState();
}

class _MobileOpensubsonicConfigPageState
    extends ConsumerState<MobileOpensubsonicConfigPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late String _id;
  _ServerScheme _scheme = _ServerScheme.http;
  String? _existingName;

  bool _testing = false;
  bool _saving = false;
  bool _testPassed = false;
  String? _testedFingerprint;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _id = SubsonicServersNotifier.newId();
    unawaited(_loadExisting());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final servers = await ref.read(subsonicServersProvider.future);
      if (servers.isEmpty || !mounted) return;

      final config = servers.first;
      final secret = await ref
          .read(subsonicServersProvider.notifier)
          .readSecret(config.id);
      if (!mounted) return;

      final uri = Uri.tryParse(config.baseUrl);
      if (uri == null || uri.host.isEmpty) return;

      final path = uri.path == '/' ? '' : uri.path;
      setState(() {
        _id = config.id;
        _existingName = config.name;
        _scheme = uri.scheme == 'http'
            ? _ServerScheme.http
            : _ServerScheme.https;
        _urlController.text = '${uri.host}$path';
        _portController.text = uri.hasPort ? '${uri.port}' : '';
        _usernameController.text = config.username ?? '';
        _passwordController.text = secret ?? '';
      });
    } catch (e) {
      debugPrint('读取 Opensubsonic 配置失败: $e');
    }
  }

  String _fingerprint() {
    return [
      _scheme.name,
      _urlController.text.trim(),
      _portController.text.trim(),
      _usernameController.text.trim(),
      _passwordController.text,
    ].join('\u0000');
  }

  bool get _testMatchesInput =>
      _testPassed && _testedFingerprint == _fingerprint();

  void _resetTestState() {
    _testPassed = false;
    _testedFingerprint = null;
    _info = null;
    _error = null;
  }

  void _onFieldChanged(String _) {
    setState(_resetTestState);
  }

  void _onSchemeChanged(Set<_ServerScheme> next) {
    if (next.isEmpty) return;
    setState(() {
      _scheme = next.first;
      _resetTestState();
    });
  }

  /// 把 URL、端口、用户名和密码组合成服务器配置。
  SubsonicServerConfig? _buildConfig() {
    final l10n = AppLocalizations.of(context);
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      _error = l10n.serverUrlRequired;
      return null;
    }

    final rawWithScheme = rawUrl.contains('://')
        ? rawUrl
        : '${_scheme.name}://$rawUrl';
    final uri = Uri.tryParse(rawWithScheme);
    if (uri == null || uri.host.isEmpty) {
      _error = l10n.serverUrlInvalid;
      return null;
    }

    final portText = _portController.text.trim();
    final int port;
    if (portText.isEmpty) {
      port = 4533;
    } else {
      final parsed = int.tryParse(portText);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        _error = l10n.portInvalid;
        return null;
      }
      port = parsed;
    }

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _error = l10n.usernameRequired;
      return null;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _error = l10n.passwordRequired;
      return null;
    }

    final baseUrl = Uri(
      scheme: _scheme.name,
      host: uri.host,
      port: port,
      path: uri.path,
    ).toString();

    return SubsonicServerConfig(
      id: _id,
      name: _existingName ?? uri.host,
      baseUrl: baseUrl,
      authMode: SubsonicAuthMode.token,
      username: username,
    );
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
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
          .test(config: config, secret: _passwordController.text);
      if (!mounted) return;
      setState(() {
        _testPassed = true;
        _testedFingerprint = fingerprint;
        _info =
            '${l10n.connectionSuccess}'
            '${info.serverType ?? 'Subsonic'} '
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

  Future<void> _scan() async {
    if (!_testMatchesInput || _saving) return;

    final config = _buildConfig();
    if (config == null) {
      setState(() {});
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(subsonicServersProvider.notifier)
          .save(config: config, secret: _passwordController.text);
      _id = config.id;
      _existingName = config.name;
      if (!mounted) return;
      await ref.read(remoteSyncProvider.notifier).start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _syncStatusText(RemoteSyncState? sync) {
    if (sync == null) return null;
    final l10n = AppLocalizations.of(context);
    if (sync.isSyncing) {
      return switch (sync.phase) {
        RemoteSyncPhase.artists => sync.message ?? l10n.syncFetchingArtists,
        RemoteSyncPhase.albums =>
          sync.completed > 0
              ? l10n.syncAlbumsProgress(sync.completed)
              : l10n.syncFetchingAlbums,
        RemoteSyncPhase.tracks =>
          sync.total > 0
              ? l10n.syncTracksProgress(sync.completed, sync.total)
              : l10n.syncTracksCount(sync.completed),
        _ => sync.message ?? l10n.syncScanning,
      };
    }
    if (sync.phase == RemoteSyncPhase.failed) {
      return l10n.syncFailed(sync.error ?? sync.message ?? l10n.syncRetry);
    }
    if (sync.hasResult) {
      final count = sync.meta?.trackCount.toInt() ?? sync.trackCount;
      return l10n.syncComplete(count);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final sync = ref.watch(remoteSyncProvider).value;
    final bool syncing = sync?.isSyncing ?? false;
    final bool canScan = _testMatchesInput && !_testing && !_saving && !syncing;
    final String? syncStatus = _syncStatusText(sync);

    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: 'Opensubsonic',
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: M3EDropdownMenu<_ServerScheme>(
                    singleSelect: true,
                    showChipAnimation: false,
                    items: [
                      M3EDropdownItem<_ServerScheme>(
                        label: 'http',
                        value: _ServerScheme.http,
                        selected: _scheme == _ServerScheme.http,
                      ),
                      M3EDropdownItem<_ServerScheme>(
                        label: 'https',
                        value: _ServerScheme.https,
                        selected: _scheme == _ServerScheme.https,
                      ),
                    ],
                    fieldStyle: const M3EDropdownFieldStyle(
                      hintText: 'http',
                      showArrow: false,
                    ),
                    onSelectionChanged:
                        (List<M3EDropdownItem<_ServerScheme>> items) {
                          _onSchemeChanged(
                            items.map((item) => item.value).toSet(),
                          );
                        },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: M3ETextField(
                    controller: _urlController,
                    variant: M3ETextFieldVariant.filled,
                    maxLines: 1,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    label: l10n.serverUrlLabel,
                    supportingText: l10n.serverUrlSupporting,
                    supportingTextOnFocusOnly: false,
                    isRequired: true,
                    placeholder: 'music.example.com',
                    onChanged: _onFieldChanged,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 14, 6, 0),
                  child: Text(':'),
                ),
                SizedBox(
                  width: 78,
                  child: M3ETextField(
                    controller: _portController,
                    variant: M3ETextFieldVariant.filled,
                    maxLines: 1,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    label: l10n.portLabel,
                    supportingText: l10n.portSupporting,
                    supportingTextOnFocusOnly: false,
                    isRequired: false,
                    placeholder: '4533',
                    onChanged: _onFieldChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            M3ETextField(
              controller: _usernameController,
              variant: M3ETextFieldVariant.filled,
              maxLines: 1,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              label: l10n.usernameLabel,
              supportingText: l10n.usernameLabel,
              supportingTextOnFocusOnly: false,
              isRequired: true,
              leading: const Icon(M3EIcons.person),
              onChanged: _onFieldChanged,
            ),
            const SizedBox(height: 16),
            M3ETextField(
              controller: _passwordController,
              variant: M3ETextFieldVariant.filled,
              maxLines: 1,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              label: l10n.passwordLabel,
              supportingText: l10n.passwordLabel,
              supportingTextOnFocusOnly: false,
              isRequired: true,
              leading: const Icon(M3EIcons.lock),
              obscureText: true,
              showPasswordToggle: true,
              showPasswordSemanticsLabel: l10n.showPassword,
              hidePasswordSemanticsLabel: l10n.hidePassword,
              onChanged: _onFieldChanged,
            ),
            if (_saving || syncing) ...[
              const SizedBox(height: 16),
              Center(
                child: M3EProgressIndicator.circularWavy(
                  size: 48,
                  strokeWidth: 8,
                  trackStrokeWidth: 8,
                  semanticsLabel: l10n.scanningSemantics,
                ),
              ),
            ],
            if (_error != null || _info != null || syncStatus != null) ...[
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.error,
                  ),
                ),
              if (_info != null)
                Text(
                  _info!,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.primary,
                  ),
                ),
              if (syncStatus != null)
                Text(
                  syncStatus,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: sync?.phase == RemoteSyncPhase.failed
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                M3EButton(
                  size: M3EButtonSize.md,
                  shape: M3EButtonShape.square,
                  label: Text(_testing ? l10n.testingButton : l10n.testButton),
                  onPressed: _testing || _saving ? null : _test,
                ),
                const SizedBox(height: 12),
                M3EButton(
                  size: M3EButtonSize.md,
                  shape: M3EButtonShape.square,
                  style: M3EButtonStyle.tonal,
                  enabled: canScan,
                  label: Text(
                    _saving || syncing ? l10n.scanningButton : l10n.scanButton,
                  ),
                  onPressed: canScan ? _scan : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
