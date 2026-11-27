import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String fileDropChannelName = 'mint_image/file_drop';

/// 接收原生桌面窗口拖入的文件路径列表。
class FileDropService {
  FileDropService._();

  static final FileDropService instance = FileDropService._();

  static const MethodChannel _channel = MethodChannel(fileDropChannelName);

  final StreamController<List<String>> _controller =
      StreamController<List<String>>.broadcast();
  bool _initialized = false;

  Stream<List<String>> get onFilesDropped {
    ensureInitialized();
    return _controller.stream;
  }

  void ensureInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onFilesDropped') {
      return;
    }

    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }

    final rawPaths = arguments['paths'];
    if (rawPaths is! List) {
      return;
    }

    final paths = rawPaths
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    if (paths.isNotEmpty) {
      _controller.add(paths);
    }
  }

  @visibleForTesting
  Future<void> handleMethodCallForTest(MethodCall call) =>
      _handleMethodCall(call);
}
