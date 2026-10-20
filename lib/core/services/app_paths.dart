import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 统一解析应用数据目录。
///
/// Windows 便携模式：所有应用自身的数据（数据库、日志、生成图片、恢复出来的
/// 附件）都放在 exe 同级的 `data` 目录下。
///
/// 之所以不放在 `%APPDATA%` / `我的文档`：从压缩包解压出来、或由受限进程写出
/// 的可执行文件可能带有低完整性级别（Low Integrity）标签，这类进程写入中等
/// 完整性目录（AppData、Documents）会被系统拒绝，表现为
/// `PathAccessException ... (OS Error: 拒绝访问。, errno = 5)`。
/// 放在 exe 同级目录可以完全避开这一限制，同时让应用变成绿色便携版。
///
/// 其他平台（Android / iOS / macOS）保持原有系统目录行为。
class AppPaths {
  const AppPaths._();

  static bool get _portable => Platform.isWindows;

  /// exe 所在目录（Windows 便携模式的根）。
  static Directory get executableDirectory =>
      File(Platform.resolvedExecutable).parent;

  /// 应用数据根目录。
  static Future<Directory> dataRoot() async {
    if (_portable) {
      final directory = Directory(p.join(executableDirectory.path, 'data'));
      await directory.create(recursive: true);
      return directory;
    }

    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return directory;
  }

  /// 数据根目录下的具名子目录，不存在时自动创建。
  static Future<Directory> subDirectory(String name) async {
    final root = await dataRoot();
    final directory = Directory(p.join(root.path, name));
    await directory.create(recursive: true);
    return directory;
  }

  /// 旧版本（数据放在 `%APPDATA%`）的数据目录，用于一次性迁移。
  ///
  /// 只读用途：新位置为空时才从这里搬数据，迁移完成后旧目录不再使用。
  static Directory? legacyDataRoot() {
    if (!Platform.isWindows) {
      return null;
    }

    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      return null;
    }

    final directory = Directory(p.join(appData, 'com.aiqin', 'MintImage'));
    return directory.existsSync() ? directory : null;
  }
}
