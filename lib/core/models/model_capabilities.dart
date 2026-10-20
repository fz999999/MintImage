import 'generation_request.dart';

/// 按模型判断「哪些参数能用」。
///
/// 依据 OpenAI 官方 SDK 的 image_generate_params 字段说明：
/// - `background: transparent`：`gpt-image-2.5-sunburst` / `gpt-image-2.5-flare`
///   及其 2026-09-08 快照正式支持；`gpt-image-2` 属于 preview；且输出格式必须是
///   png 或 webp（JPEG 没有 alpha 通道）。
/// - `quality: xhigh / max`：**只有** `gpt-image-2.5-sunburst` / `gpt-image-2.5-flare`
///   支持，其他模型只认 low / medium / high / auto。
/// - 任意分辨率（宽高都要是 16 的倍数、比例 1:3~3:1、最大 3840×2160）：
///   `gpt-image-2` 与 `gpt-image-2.5` 家族支持。
///
/// 中转站可能自定义模型名，所以这里只做「已知不支持」的拦截，不确定时按支持处理。
class ModelCapabilities {
  const ModelCapabilities._();

  static String _normalize(String model) => model.trim().toLowerCase();

  /// gpt-image-2.5 家族（含 sunburst / flare 与日期快照）。
  static bool isGptImage25(String model) =>
      _normalize(model).startsWith('gpt-image-2.5');

  /// gpt-image-2（含 2026-04-21 快照），但不含 2.5。
  static bool isGptImage2(String model) {
    final normalized = _normalize(model);
    return normalized.startsWith('gpt-image-2') &&
        !normalized.startsWith('gpt-image-2.5');
  }

  static bool isGptImageFamily(String model) {
    final normalized = _normalize(model);
    return normalized.startsWith('gpt-image') ||
        normalized.startsWith('chatgpt-image');
  }

  /// 是否支持透明背景（还要叠加「输出格式是 png / webp」这个条件）。
  ///
  /// 只拦「明确不支持」的：DALL·E 系列根本不接受 background 参数。
  /// 中转站经常自定义模型名（image-1、nano-banana…），认不出来的按支持处理，
  /// 真不支持时接口会直接报错，比把功能藏起来更容易排查。
  static bool supportsTransparentBackground(String model) {
    final normalized = _normalize(model);
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.startsWith('dall-e')) {
      return false;
    }
    return true;
  }

  /// gpt-image-2 的透明背景是 preview 特性，界面可以给个「预览」提示。
  static bool isTransparentBackgroundPreview(String model) =>
      isGptImage2(model);

  /// 是否支持 xhigh / max 两档高画质。
  static bool supportsExtendedQuality(String model) => isGptImage25(model);

  /// 是否支持任意 W×H 分辨率。
  static bool supportsArbitrarySize(String model) =>
      isGptImage25(model) || isGptImage2(model);

  /// 该模型在质量选择器里应该出现哪些档位。
  static List<ImageQuality> supportedQualities(String model) {
    if (supportsExtendedQuality(model)) {
      return ImageQuality.values;
    }
    return ImageQuality.values
        .where(
          (quality) =>
              quality != ImageQuality.xhigh && quality != ImageQuality.max,
        )
        .toList(growable: false);
  }

  /// 把当前画质收敛到该模型支持的范围内（不支持 xhigh / max 时回退到 high）。
  static ImageQuality coerceQuality(ImageQuality quality, String model) {
    if (quality == ImageQuality.xhigh || quality == ImageQuality.max) {
      return supportsExtendedQuality(model) ? quality : ImageQuality.high;
    }
    return quality;
  }
}
