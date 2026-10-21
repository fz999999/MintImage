import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';

import '../models/image_record.dart';
import '../services/image_dimension_reader.dart';

/// 图墙排版用的宽高比缓存。
///
/// 瀑布流要求「建卡片之前就知道卡片多高」，而 `ImageRecord.width/height`
/// 是**请求参数**：选「自动」时它是 0×0，模型实际出图可能是 1024×1536。
/// 所以这里分两步拿比例：
///
/// 1. 请求里明确写了宽高（非 0）→ 直接用，零 IO；
/// 2. 否则读本地文件头解析真实像素尺寸（PNG/JPEG/WebP/GIF/BMP 都支持），
///    只读前 64 KB，不做整图解码。
///
/// 解析结果按「记录 id + 文件路径」缓存在内存里，滚动来回不重复读盘。
/// 实在拿不到（网络图、文件缺失）就退回 [fallbackAspectRatio]，
/// 不会因为一张坏图把整面墙的排版打乱。
class ImageAspectRatioCache extends StateNotifier<int> {
  ImageAspectRatioCache({
    ImageDimensionReader reader = const ImageDimensionReader(),
  }) : _reader = reader,
       super(0);

  final ImageDimensionReader _reader;

  /// key 用「id + 路径」：同一条记录重新生成后路径变了，会重新解析。
  final Map<String, double> _ratios = <String, double>{};
  final Set<String> _inFlight = <String>{};

  /// 拿不到比例时的占位比例（4:3，横图略高一点，和多数出图接近）。
  static const double fallbackAspectRatio = 4 / 3;

  /// 卡片被压到最小/最大高度区间内时，用这个比例画「占位骨架」的图。
  double ratioFor(ImageRecord record) {
    final cached = _ratios[_cacheKey(record)];
    if (cached != null) {
      return cached;
    }
    final declared = _declaredRatio(record);
    if (declared != null) {
      return declared;
    }
    _resolveFromFile(record);
    return fallbackAspectRatio;
  }

  /// 请求参数里写死的宽高是可信任的，不用读盘。
  double? _declaredRatio(ImageRecord record) {
    if (record.width > 0 && record.height > 0) {
      return record.width / record.height;
    }
    return null;
  }

  void _resolveFromFile(ImageRecord record) {
    if (_declaredRatio(record) != null) {
      return;
    }
    final key = _cacheKey(record);
    if (_inFlight.contains(key)) {
      return;
    }

    final path = _probePath(record);
    if (path == null) {
      return;
    }

    _inFlight.add(key);
    _reader.readAspectRatio(path).then((ratio) {
      _inFlight.remove(key);
      if (!mounted || ratio == null || !ratio.isFinite || ratio <= 0) {
        return;
      }
      if (_ratios[key] == ratio) {
        return;
      }
      _ratios[key] = ratio;
      state = state + 1;
    }).catchError((Object _) {
      _inFlight.remove(key);
    });
  }

  /// 解析结果变了才需要刷新；只在本条记录自己的文件上找。
  String? _probePath(ImageRecord record) {
    final resultPath = record.resultImagePath;
    if (resultPath != null &&
        resultPath.isNotEmpty &&
        File(resultPath).existsSync()) {
      return resultPath;
    }
    final sourcePath = record.sourceImagePath;
    if (sourcePath != null &&
        sourcePath.isNotEmpty &&
        File(sourcePath).existsSync()) {
      return sourcePath;
    }
    return null;
  }

  String _cacheKey(ImageRecord record) {
    final path = record.resultImagePath ?? record.sourceImagePath ?? '';
    return '${record.id}|$path';
  }

  /// 清掉已消失记录的比例，避免长会话内存一直涨。由列表在记录变化时调用。
  void retainOnly(Iterable<ImageRecord> records) {
    final liveKeys = records.map(_cacheKey).toSet();
    _ratios.removeWhere((key, _) => !liveKeys.contains(key));
  }
}

final imageAspectRatioCacheProvider =
    StateNotifierProvider<ImageAspectRatioCache, int>((ref) {
      return ImageAspectRatioCache();
    });
