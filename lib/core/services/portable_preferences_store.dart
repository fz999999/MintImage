import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'app_paths.dart';

/// 把 `shared_preferences` 的存储位置改到应用自身的 data 目录。
///
/// 官方的 `shared_preferences_windows` 会直接实例化 `PathProviderWindows` 并写入
/// `%APPDATA%\<company>\<product>\shared_preferences.json`，既不接受
/// `PathProviderPlatform` 覆写，也无法在受限（低完整性）进程下写入，表现为设置
/// 无法保存。这里实现一份等价的最小存储：同样的 JSON 格式、同样的 `flutter.`
/// 键前缀，只是文件放在 `AppPaths.dataRoot()` 里。
class PortablePreferencesStore extends SharedPreferencesStorePlatform {
  PortablePreferencesStore();

  static final PortablePreferencesStore instance = PortablePreferencesStore();

  /// 与官方 Windows 实现保持一致的文件名。
  static const String _fileName = 'shared_preferences.json';

  /// 官方实现同样使用的前缀。
  static const String _prefix = 'flutter.';

  Map<String, Object>? _cache;

  Future<File> _file() async {
    final directory = await AppPaths.dataRoot();
    return File(p.join(directory.path, _fileName));
  }

  /// 从旧位置（`%APPDATA%`）迁移一次，避免升级后丢失已配置的 API Key。
  File? _legacyFile() {
    if (!Platform.isWindows) {
      return null;
    }
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      return null;
    }
    final legacy = File(p.join(appData, 'com.aiqin', 'MintImage', _fileName));
    return legacy.existsSync() ? legacy : null;
  }

  Map<String, Object> _decode(String raw) {
    final result = <String, Object>{};
    if (raw.isEmpty) {
      return result;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (key is String && value != null) {
            result[key] = value as Object;
          }
        });
      }
    } catch (_) {
      // 文件损坏时按空配置处理，交给调用方回落默认值。
    }
    return result;
  }

  Future<Map<String, Object>> _load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }

    final file = await _file();
    Map<String, Object> data = <String, Object>{};
    try {
      if (file.existsSync()) {
        data = _decode(file.readAsStringSync());
      } else {
        final legacy = _legacyFile();
        if (legacy != null) {
          data = _decode(legacy.readAsStringSync());
          if (data.isNotEmpty) {
            await _save(data);
          }
        }
      }
    } catch (_) {
      data = <String, Object>{};
    }

    _cache = data;
    return data;
  }

  Future<bool> _save(Map<String, Object> data) async {
    _cache = data;
    try {
      final file = await _file();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(json.encode(data));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _matches(String key, PreferencesFilter filter) {
    if (!key.startsWith(filter.prefix)) {
      return false;
    }
    final allowList = filter.allowList;
    return allowList == null || allowList.contains(key);
  }

  @override
  Future<bool> clear() async {
    final data = Map<String, Object>.from(await _load());
    data.removeWhere((key, _) => key.startsWith(_prefix));
    return _save(data);
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    final data = Map<String, Object>.from(await _load());
    data.removeWhere((key, _) => _matches(key, filter));
    return _save(data);
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final data = await _load();
    return <String, Object>{
      for (final entry in data.entries)
        if (entry.key.startsWith(_prefix)) entry.key: entry.value,
    };
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    final data = await _load();
    return <String, Object>{
      for (final entry in data.entries)
        if (_matches(entry.key, filter)) entry.key: entry.value,
    };
  }

  @override
  Future<bool> remove(String key) async {
    final data = Map<String, Object>.from(await _load());
    if (data.remove(key) == null) {
      return true;
    }
    return _save(data);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final data = Map<String, Object>.from(await _load());
    data[key] = value;
    return _save(data);
  }
}
