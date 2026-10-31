import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

/// 音乐目录选择能力。业务层只依赖该接口。
abstract interface class DirectoryPicker {
  Future<String?> pickMusicDirectory();
}

/// 桌面端：走 Rust 侧 rfd 原生目录选择框。
class DesktopDirectoryPicker implements DirectoryPicker {
  const DesktopDirectoryPicker();

  @override
  Future<String?> pickMusicDirectory() => rust.pickDirectory();
}

/// 移动端：后续接 SAF / file_picker。
///
/// 这里保留独立实现，避免业务层出现平台分支；接入 Android 存储权限后
/// 只需替换本实现，不影响 Provider 与页面。
class MobileDirectoryPicker implements DirectoryPicker {
  const MobileDirectoryPicker();

  @override
  Future<String?> pickMusicDirectory() async {
    // TODO(mobile-storage): 接入 Android ACTION_OPEN_DOCUMENT_TREE 或
    // file_picker.getDirectoryPath，并处理 READ_MEDIA_AUDIO / SAF 持久化 URI。
    return null;
  }
}

final directoryPickerProvider = Provider<DirectoryPicker>((ref) {
  throw UnimplementedError(
    'directoryPickerProvider 必须在 bootstrap 中注入',
  );
});
