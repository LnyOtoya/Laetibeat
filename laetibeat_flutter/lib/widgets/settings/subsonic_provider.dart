import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'persistence.dart';

const String _serversKey = 'subsonic.servers';
const String _secretPrefix = 'subsonic.secret.';

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
      debugPrint('读取远端服务器配置失败: $e');
      return const <SubsonicServerConfig>[];
    }
  }

  Future<void> saveConfigs(List<SubsonicServerConfig> configs) {
    return _prefs.setString(
      _serversKey,
      jsonEncode([for (final config in configs) config.toJson()]),
    );
  }

  Future<String?> readSecret(String id) =>
      _secure.read(key: '$_secretPrefix$id');

  Future<void> writeSecret(String id, String secret) =>
      _secure.write(key: '$_secretPrefix$id', value: secret);

  Future<void> deleteSecret(String id) =>
      _secure.delete(key: '$_secretPrefix$id');
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
    return ref.read(subsonicServerStoreProvider).loadConfigs();
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

    final current = <SubsonicServerConfig>[
      ...(state.value ?? const <SubsonicServerConfig>[]),
    ];
    final index = current.indexWhere((item) => item.id == config.id);
    if (index >= 0) {
      current[index] = config;
    } else {
      current.add(config);
    }
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

    final current = <SubsonicServerConfig>[
      for (final config in state.value ?? const <SubsonicServerConfig>[])
        if (config.id != id) config,
    ];
    await store.saveConfigs(current);
    state = AsyncData(current);
  }

  Future<String?> readSecret(String id) =>
      ref.read(subsonicServerStoreProvider).readSecret(id);
}

/// 启动时后台重连可能尚未完成;播放远端曲目前按需补一次配置。
Future<void> ensureSubsonicConfigured(Ref ref, String sourceId) async {
  final prefs = ref.read(sharedPreferencesProvider);
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
