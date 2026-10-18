import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'persistence.dart';

const String _serversKey = 'subsonic.servers'; // 旧版多服务器列表
const String _serverKey = 'subsonic.server'; // 新版单服务器配置
const String _secretPrefix = 'subsonic.secret.'; // 旧版按服务器 id 存密钥
const String _secretKey = 'subsonic.secret'; // 新版单服务器密钥

/// 认证方式
enum SubsonicAuthMode {
  apiKey('API Key'),
  token('用户名密码');

  const SubsonicAuthMode(this.label);
  final String label;

  String get wireName => this == SubsonicAuthMode.apiKey ? 'apiKey' : 'token';
}

/// 服务器非敏感配置;密钥/密码单独放在安全存储里
class SubsonicServerConfig {
  const SubsonicServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.authMode,
    this.username,
  });

  final String id;
  final String name;
  final String baseUrl;
  final SubsonicAuthMode authMode;
  final String? username;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'authMode': authMode.name,
        'username': username,
      };

  static SubsonicServerConfig? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'] as String?;
    final name = value['name'] as String?;
    final baseUrl = value['baseUrl'] as String?;
    if (id == null || name == null || baseUrl == null) return null;

    final authName = value['authMode'] as String?;
    final authMode = SubsonicAuthMode.values.firstWhere(
      (mode) => mode.name == authName,
      orElse: () => SubsonicAuthMode.apiKey,
    );
    return SubsonicServerConfig(
      id: id,
      name: name,
      baseUrl: baseUrl,
      authMode: authMode,
      username: value['username'] as String?,
    );
  }
}

/// 服务器配置持久化:配置走 preferences,密钥走系统安全存储
class SubsonicServerStore {
  SubsonicServerStore(
    this._prefs, [
    this._secure = const FlutterSecureStorage(),
  ]);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  List<SubsonicServerConfig> loadConfigs() {
    final raw = _prefs.getString(_serverKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final config = SubsonicServerConfig.fromJson(jsonDecode(raw));
        if (config != null) return <SubsonicServerConfig>[config];
      } catch (e) {
        debugPrint('读取远端服务器配置失败: $e');
      }
    }

    // 兼容旧版多服务器列表:只取第一个
    final legacy = _loadLegacyConfigs();
    return legacy.isEmpty
        ? const <SubsonicServerConfig>[]
        : <SubsonicServerConfig>[legacy.first];
  }

  List<SubsonicServerConfig> _loadLegacyConfigs() {
    final raw = _prefs.getString(_serversKey);
    if (raw == null || raw.isEmpty) return const <SubsonicServerConfig>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SubsonicServerConfig>[];
      final configs = <SubsonicServerConfig>[];
      for (final item in decoded) {
        final config = SubsonicServerConfig.fromJson(item);
        if (config != null) configs.add(config);
      }
      return configs;
    } catch (e) {
      debugPrint('读取旧版远端服务器配置失败: $e');
      return const <SubsonicServerConfig>[];
    }
  }

  Future<void> saveConfigs(List<SubsonicServerConfig> configs) {
    if (configs.isEmpty) {
      return _prefs.remove(_serverKey);
    }
    // 单服务器模式:只保留第一个配置
    return _prefs.setString(_serverKey, jsonEncode(configs.first.toJson()));
  }

  /// 把旧版多服务器配置迁移为单服务器配置,并迁移第一个服务器的密钥。
  Future<void> migrateLegacyIfNeeded() async {
    if (_prefs.containsKey(_serverKey)) return;
    final legacy = _loadLegacyConfigs();
    if (legacy.isEmpty) return;

    final first = legacy.first;
    await _prefs.setString(_serverKey, jsonEncode(first.toJson()));

    try {
      final secret = await _secure.read(key: '$_secretPrefix${first.id}');
      if (secret != null && secret.isNotEmpty) {
        await _secure.write(key: _secretKey, value: secret);
      }
    } catch (e) {
      // 安全存储不可用时只记录日志,不阻塞配置读取
      debugPrint('迁移远端服务器密钥失败: $e');
    }
  }

  Future<String?> readSecret(String id) async {
    final direct = await _secure.read(key: _secretKey);
    if (direct != null && direct.isNotEmpty) return direct;
    // 兼容旧版按服务器 id 存储的密钥
    return _secure.read(key: '$_secretPrefix$id');
  }

  Future<void> writeSecret(String id, String secret) =>
      _secure.write(key: _secretKey, value: secret);

  Future<void> deleteSecret(String id) async {
    await _secure.delete(key: _secretKey);
    await _secure.delete(key: '$_secretPrefix$id');
  }
}

final subsonicServerStoreProvider = Provider<SubsonicServerStore>((ref) {
  return SubsonicServerStore(ref.read(sharedPreferencesProvider));
});

/// 已配置服务器列表
final subsonicServersProvider =
    AsyncNotifierProvider<SubsonicServersNotifier, List<SubsonicServerConfig>>(
  SubsonicServersNotifier.new,
);

class SubsonicServersNotifier
    extends AsyncNotifier<List<SubsonicServerConfig>> {
  @override
  Future<List<SubsonicServerConfig>> build() async {
    final store = ref.read(subsonicServerStoreProvider);
    // 旧版多服务器配置在首次读取时迁移为单服务器配置
    await store.migrateLegacyIfNeeded();
    return store.loadConfigs();
  }

  static String newId() => const Uuid().v4();

  /// 测试连接,同时把 Rust 客户端注册进内存
  Future<rust_subsonic.UiSubsonicServerInfo> test({
    required SubsonicServerConfig config,
    required String secret,
  }) {
    return rust_subsonic.configureSubsonic(
      sourceId: config.id,
      baseUrl: config.baseUrl,
      authMode: config.authMode.wireName,
      username: config.authMode == SubsonicAuthMode.token
          ? config.username
          : null,
      secret: secret,
      clientName: 'laetibeat',
    );
  }

  /// 测试成功后保存配置与密钥
  Future<rust_subsonic.UiSubsonicServerInfo> save({
    required SubsonicServerConfig config,
    required String secret,
  }) async {
    final info = await test(config: config, secret: secret);

    final store = ref.read(subsonicServerStoreProvider);
    await store.writeSecret(config.id, secret);

    // 单服务器模式:保存即替换现有配置
    final current = <SubsonicServerConfig>[config];
    await store.saveConfigs(current);
    state = AsyncData(current);
    return info;
  }

  /// 删除服务器及其密钥
  Future<void> delete(String id) async {
    try {
      await rust_subsonic.removeSubsonic(sourceId: id);
    } catch (e) {
      debugPrint('移除远端客户端失败: $e');
    }

    final store = ref.read(subsonicServerStoreProvider);
    await store.deleteSecret(id);

    // 单服务器模式:删除即清空唯一配置
    const current = <SubsonicServerConfig>[];
    await store.saveConfigs(current);
    state = const AsyncData(current);
  }

  Future<String?> readSecret(String id) =>
      ref.read(subsonicServerStoreProvider).readSecret(id);
}

/// 启动时后台重连可能尚未完成;播放远端曲目前按需补一次配置。
Future<void> ensureSubsonicConfigured(Ref ref, String sourceId) {
  return ensureSubsonicConfiguredWithPrefs(
    ref.read(sharedPreferencesProvider),
    sourceId,
  );
}

/// 同上,供只有 WidgetRef 的 UI 重试入口使用。
Future<void> ensureSubsonicConfiguredWithPrefs(
  SharedPreferences prefs,
  String sourceId,
) async {
  final store = SubsonicServerStore(prefs);

  SubsonicServerConfig? config;
  for (final item in store.loadConfigs()) {
    if (item.id == sourceId) {
      config = item;
      break;
    }
  }
  if (config == null) {
    throw Exception('找不到远端服务器配置');
  }

  final secret = await store.readSecret(sourceId);
  if (secret == null || secret.isEmpty) {
    throw Exception('远端服务器密钥不可用');
  }

  await rust_subsonic.configureSubsonic(
    sourceId: config.id,
    baseUrl: config.baseUrl,
    authMode: config.authMode.wireName,
    username:
        config.authMode == SubsonicAuthMode.token ? config.username : null,
    secret: secret,
    clientName: 'laetibeat',
  );
}

/// 应用启动后在后台重新连接已保存的服务器。
/// 失败只记录日志,不影响本地功能。
Future<void> reconnectSubsonicServers(SharedPreferences prefs) async {
  final store = SubsonicServerStore(prefs);
  for (final config in store.loadConfigs()) {
    try {
      final secret = await store.readSecret(config.id);
      if (secret == null || secret.isEmpty) continue;
      await rust_subsonic.configureSubsonic(
        sourceId: config.id,
        baseUrl: config.baseUrl,
        authMode: config.authMode.wireName,
        username: config.authMode == SubsonicAuthMode.token
            ? config.username
            : null,
        secret: secret,
        clientName: 'laetibeat',
      );
    } catch (e) {
      debugPrint('自动连接服务器 ${config.name} 失败: $e');
    }
  }
}
