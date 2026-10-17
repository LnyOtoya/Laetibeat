import 'dart:async';
import 'dart:convert';

// 私有字段经命名参数适配,无法使用 initializing formals
// ignore_for_file: prefer_initializing_formals

import 'package:dbus/dbus.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';

typedef MprisStateReader = PlayerState Function();

/// Linux MPRIS2 集成。
///
/// 在 D-Bus session 总线暴露 `org.mpris.MediaPlayer2.laetibeat`,
/// 使 GNOME/KDE 媒体控件、锁屏、waybar/polybar、playerctl 等
/// 都能检测到当前播放曲目并操控播放,无需为各桌面分别适配。
///
/// 播放状态/控制的桥接全部走 [playback_backend]/player_provider,
/// 不引入任何跨 FFI 音频流。
class LinuxMprisIntegration {
  static const busName = 'org.mpris.MediaPlayer2.laetibeat';
  static const objectPath = '/org/mpris/MediaPlayer2';

  final MprisStateReader _readState;
  final Future<void> Function() _onPlay;
  final Future<void> Function() _onPause;
  final void Function() _onNext;
  final void Function() _onPrevious;
  final void Function(Duration) _onSeek;

  DBusClient? _client;
  _MprisObject? _object;
  DBusRequestNameReply? _nameReply;
  StreamSubscription<String>? _nameAcquiredSub;
  StreamSubscription<String>? _nameLostSub;

  LinuxMprisIntegration({
    required MprisStateReader readState,
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required void Function() onNext,
    required void Function() onPrevious,
    required void Function(Duration) onSeek,
  })  : _readState = readState,
        _onPlay = onPlay,
        _onPause = onPause,
        _onNext = onNext,
        _onPrevious = onPrevious,
        _onSeek = onSeek;

  bool get _ownsName =>
      _client != null &&
      (_nameReply == DBusRequestNameReply.primaryOwner ||
          _nameReply == DBusRequestNameReply.alreadyOwner);

  PlayerState get state => _readState();

  /// 连接 session 总线并暴露对象。无 D-Bus 会话/已被同名实例占用时静默降级,不抛错。
  Future<void> start() async {
    try {
      _client = DBusClient.session();
      _object = _MprisObject(this);
      await _client!.registerObject(_object!);
      // 名字所有权自愈:被抢占/异常丢失时自动重新申请,避免 waybar 一直
      // 读到"ServiceUnknown"而永久不显示;重新拿到时立即补推一次属性。
      _nameAcquiredSub = _client!.nameAcquired.listen((name) {
        if (name != busName) return;
        _nameReply = DBusRequestNameReply.primaryOwner;
        push();
      });
      _nameLostSub = _client!.nameLost.listen((name) {
        if (name != busName) return;
        _nameReply = null;
        _requestName();
      });
      await _requestName();
    } catch (_) {
      _nameReply = null;
    }
    if (_ownsName) {
      await push();
    }
  }

  Future<void> _requestName() async {
    try {
      _nameReply = await _client?.requestName(busName);
    } catch (_) {
      _nameReply = null;
    }
  }

  Future<void> stop() async {
    try {
      await _nameAcquiredSub?.cancel();
      await _nameLostSub?.cancel();
      _nameAcquiredSub = null;
      _nameLostSub = null;
      final client = _client;
      if (client != null) {
        if (_ownsName) await client.releaseName(busName);
        await client.unregisterObject(_object!);
        await client.close();
      }
    } catch (_) {
      // 忽略关闭时的异常
    }
    _client = null;
    _object = null;
    _nameReply = null;
  }

  // 由外部在播放状态变化时调用,推送 MPRIS 属性变化信号(合并短时间内多次变更)
  Future<void>? _pendingPush;
  Future<void> push() {
    final pending = _pendingPush;
    if (pending != null) return pending;
    final future = _doPush();
    _pendingPush = future;
    return future.whenComplete(() => _pendingPush = null);
  }

  Future<void> _doPush() async {
    if (!_ownsName) return;
    try {
      await _object!.emitPropertiesChanged(
        'org.mpris.MediaPlayer2.Player',
        changedProperties: _object!.currentChangedProperties(),
      );
    } catch (_) {
      // 单次属性推送失败不影响服务存活,忽略
    }
  }

  // --- 由 _MprisObject 调用的桥接 ---
  Future<void> handlePlay() => _onPlay();
  Future<void> handlePause() => _onPause();
  void handleNext() => _onNext();
  void handlePrevious() => _onPrevious();
  void handleToggle() {
    if (_readState().isPlaying) {
      _onPause();
    } else {
      _onPlay();
    }
  }

  void handleSeekRelative(Duration offset) {
    final target = _readState().position + offset;
    _onSeek(target.isNegative ? Duration.zero : target);
  }

  void handleSeekTo(Duration position) => _onSeek(position);
}

/// MPRIS2 的根对象与 Player 接口同挂在 `/org/mpris/MediaPlayer2` 下。
class _MprisObject extends DBusObject {
  final LinuxMprisIntegration _host;

  static const _root = 'org.mpris.MediaPlayer2';
  static const _player = 'org.mpris.MediaPlayer2.Player';

  _MprisObject(this._host)
      : super(DBusObjectPath(LinuxMprisIntegration.objectPath));

  static const _rootProps = <String>[
    'CanQuit',
    'CanSetFullscreen',
    'CanRaise',
    'Fullscreen',
    'HasTrackList',
    'Identity',
    'DesktopEntry',
    'SupportedUriSchemes',
    'SupportedMimeTypes',
  ];

  static const _playerProps = <String>[
    'PlaybackStatus',
    'LoopStatus',
    'Rate',
    'Shuffle',
    'Metadata',
    'Volume',
    'Position',
    'MinimumRate',
    'MaximumRate',
    'CanGoNext',
    'CanGoPrevious',
    'CanPlay',
    'CanPause',
    'CanSeek',
    'CanControl',
  ];

  String get _identity {
    const app = String.fromEnvironment('PROJECT_NAME', defaultValue: 'Laetibeat');
    return app;
  }

  /// 把曲目 id 转成合法的 D-Bus 对象路径段。
  ///
  /// MPRIS 的 mpris:trackid 必须是合法 object path,而当前曲目 id 可能是
  /// 完整文件路径(含 /、空格、& 等非法字符),直接用会抛异常并打崩服务。
  /// 用 base64 编码成安全字符集,再将 base64url 特有的 `-` 替换成
  /// 对象路径允许的 `_`(D-Bus object path 只允许 [A-Za-z0-9_]/)。
  /// 对同一 id 输出稳定、天然对象路径安全。
  String _safeTrackId(String? id) {
    if (id == null || id.isEmpty) return 'none';
    final encoded = base64Url
        .encode(utf8.encode(id))
        .replaceAll('-', '_')
        .replaceAll('=', '');
    return '/org/laetibeat/track/$encoded';
  }

  DBusDict _metadata() {
    final s = _host.state;
    final t = s.current;
    // 注意:DBusDict.stringVariant 会给每个值再包一层 DBusVariant,
    // 这里必须传原始值,否则会变体双重包裹导致客户端解析不到 title
    final map = <String, DBusValue>{
      'mpris:trackid': DBusObjectPath(_safeTrackId(t?.id)),
      'mpris:length': DBusInt64(s.duration.inMicroseconds),
      'xesam:title': DBusString(t?.title ?? ''),
    };
    if (t != null) {
      if (t.artist.isNotEmpty) {
        map['xesam:artist'] = DBusArray(DBusSignature('s'), [DBusString(t.artist)]);
      }
      if (t.album.isNotEmpty) {
        map['xesam:album'] = DBusString(t.album);
      }
      if (t.path.isNotEmpty) {
        map['xesam:url'] = DBusString(Uri.file(t.path).toString());
      }
    }
    return DBusDict.stringVariant(map);
  }

  /// 声明对象对外暴露的接口(方法/属性)。
  ///
  /// 必须覆写 introspect(),否则 busctl / waybar / playerctl / GNOME/KDE
  /// 通过 org.freedesktop.DBus.Introspectable.Introspect 拿不到任何 MPRIS
  /// 接口,表现为"检测不到/无法读取属性"。
  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectMethod method(String name, [List<DBusIntrospectArgument> a = const []]) =>
        DBusIntrospectMethod(name, args: a);
    DBusIntrospectProperty prop(String name, String type,
            {DBusPropertyAccess access = DBusPropertyAccess.read}) =>
        DBusIntrospectProperty(name, DBusSignature(type), access: access);

    final root = DBusIntrospectInterface(
      _root,
      methods: [
        method('Raise'),
        method('Quit'),
      ],
      properties: [
        prop('CanQuit', 'b'),
        prop('Fullscreen', 'b'),
        prop('CanSetFullscreen', 'b'),
        prop('CanRaise', 'b'),
        prop('HasTrackList', 'b'),
        prop('Identity', 's'),
        prop('DesktopEntry', 's'),
        prop('SupportedUriSchemes', 'as'),
        prop('SupportedMimeTypes', 'as'),
      ],
    );

    final player = DBusIntrospectInterface(
      _player,
      methods: [
        method('Next'),
        method('Previous'),
        method('Pause'),
        method('PlayPause'),
        method('Stop'),
        method('Play'),
        method('Seek', [DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_)]),
        method('SetPosition', [
          DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_),
          DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_),
        ]),
      ],
      properties: [
        prop('PlaybackStatus', 's'),
        prop('LoopStatus', 's'),
        prop('Rate', 'd'),
        prop('Shuffle', 'b'),
        prop('Metadata', 'a{sv}'),
        prop('Volume', 'd'),
        prop('Position', 'x'),
        prop('MinimumRate', 'd'),
        prop('MaximumRate', 'd'),
        prop('CanGoNext', 'b'),
        prop('CanGoPrevious', 'b'),
        prop('CanPlay', 'b'),
        prop('CanPause', 'b'),
        prop('CanSeek', 'b'),
        prop('CanControl', 'b'),
      ],
    );

    return [root, player];
  }

  DBusValue _property(String iface, String name) {
    final s = _host.state;
    if (iface == _root) {
      switch (name) {
        case 'CanQuit':
          return DBusBoolean(false);
        case 'CanSetFullscreen':
          return DBusBoolean(false);
        case 'CanRaise':
          return DBusBoolean(false);
        case 'Fullscreen':
          return DBusBoolean(false);
        case 'HasTrackList':
          return DBusBoolean(false);
        case 'Identity':
          return DBusString(_identity);
        case 'DesktopEntry':
          return DBusString(_identity.toLowerCase());
        case 'SupportedUriSchemes':
          return DBusArray(DBusSignature('s'),
              [DBusString('file'), DBusString('http'), DBusString('https')]);
        case 'SupportedMimeTypes':
          return DBusArray(DBusSignature('s'), <DBusString>[]);
      }
    } else if (iface == _player) {
      switch (name) {
        case 'PlaybackStatus':
          return DBusString(s.isPlaying ? 'Playing' : 'Paused');
        case 'LoopStatus':
          return DBusString('None');
        case 'Rate':
          return DBusDouble(1.0);
        case 'Shuffle':
          return DBusBoolean(false);
        case 'Metadata':
          return _metadata();
        case 'Volume':
          return DBusDouble(1.0);
        case 'Position':
          return DBusInt64(s.position.inMicroseconds);
        case 'MinimumRate':
          return DBusDouble(1.0);
        case 'MaximumRate':
          return DBusDouble(1.0);
        case 'CanGoNext':
          return DBusBoolean(true);
        case 'CanGoPrevious':
          return DBusBoolean(true);
        case 'CanPlay':
          return DBusBoolean(true);
        case 'CanPause':
          return DBusBoolean(true);
        case 'CanSeek':
          return DBusBoolean(true);
        case 'CanControl':
          return DBusBoolean(true);
      }
    }
    throw ArgumentError('unknown property $iface.$name');
  }

  /// 每次播放状态变化要推送的属性(含在 PropertiesChanged 里)
  ///
  /// 传原始值:emitPropertiesChanged 内部会经 DBusDict.stringVariant 包裹一层 variant
  Map<String, DBusValue> currentChangedProperties() {
    return {
      for (final name in _playerProps)
        if (_isPushable(name)) name: _property(_player, name),
    };
  }

  bool _isPushable(String name) {
    // 位置属于轮询型,不作为变更信号推送,避免高频信号
    return name != 'Position' && name != 'Rate';
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    try {
      return DBusGetPropertyResponse(_property(interface, name));
    } catch (_) {
      return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    // 只对已实现的接口取属性;未实现接口(如 org.mpris.MediaPlayer2.TrackList)
    // 必须返回空集合,严禁抛异常,否则会打断 D-Bus 分发循环导致后续回复损坏。
    final List<String> names;
    if (interface == _root) {
      names = _rootProps;
    } else if (interface == _player) {
      names = _playerProps;
    } else {
      return DBusGetAllPropertiesResponse({});
    }
    final result = <String, DBusValue>{};
    for (final name in names) {
      try {
        result[name] = _property(interface, name);
      } catch (_) {
        // 单个属性失败时跳过即可,保证其余属性照常返回
      }
    }
    return DBusGetAllPropertiesResponse(result);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(
      DBusMethodCall methodCall) async {
    final iface = methodCall.interface;
    final member = methodCall.name;
    if (iface == _player) {
      switch (member) {
        case 'Play':
          await _host.handlePlay();
          return DBusMethodSuccessResponse();
        case 'Pause':
          await _host.handlePause();
          return DBusMethodSuccessResponse();
        case 'PlayPause':
          _host.handleToggle();
          return DBusMethodSuccessResponse();
        case 'Next':
          _host.handleNext();
          return DBusMethodSuccessResponse();
        case 'Previous':
          _host.handlePrevious();
          return DBusMethodSuccessResponse();
        case 'Stop':
          await _host.handlePause();
          return DBusMethodSuccessResponse();
        case 'Seek':
          final offset =
              Duration(microseconds: methodCall.values[0].asInt64());
          _host.handleSeekRelative(offset);
          return DBusMethodSuccessResponse();
        case 'SetPosition':
          final micros = methodCall.values[1].asInt64();
          _host.handleSeekTo(Duration(microseconds: micros));
          return DBusMethodSuccessResponse();
      }
    } else if (iface == _root) {
      switch (member) {
        case 'Raise':
          return DBusMethodSuccessResponse();
        case 'Quit':
          return DBusMethodSuccessResponse();
      }
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}