import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/model_capabilities.dart';

void main() {
  group('ModelCapabilities.supportsExtendedQuality', () {
    test('只有 gpt-image-2.5 家族支持 xhigh / max', () {
      expect(
        ModelCapabilities.supportsExtendedQuality('gpt-image-2.5-flare'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsExtendedQuality('gpt-image-2.5-sunburst'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsExtendedQuality(
          'gpt-image-2.5-flare-2026-09-08',
        ),
        isTrue,
      );
      expect(ModelCapabilities.supportsExtendedQuality('gpt-image-2'), isFalse);
      expect(
        ModelCapabilities.supportsExtendedQuality('gpt-image-2-2026-04-21'),
        isFalse,
      );
      expect(
        ModelCapabilities.supportsExtendedQuality('gpt-image-1.5'),
        isFalse,
      );
      expect(ModelCapabilities.supportsExtendedQuality(''), isFalse);
    });

    test('模型名大小写和空格不影响判断', () {
      expect(
        ModelCapabilities.supportsExtendedQuality('  GPT-Image-2.5-FLARE '),
        isTrue,
      );
    });
  });

  group('ModelCapabilities.supportedQualities', () {
    test('非 2.5 模型不暴露 xhigh / max', () {
      final qualities = ModelCapabilities.supportedQualities('gpt-image-2');

      expect(qualities, contains(ImageQuality.high));
      expect(qualities, isNot(contains(ImageQuality.xhigh)));
      expect(qualities, isNot(contains(ImageQuality.max)));
    });

    test('2.5 模型暴露全部档位', () {
      expect(
        ModelCapabilities.supportedQualities('gpt-image-2.5-flare'),
        ImageQuality.values,
      );
    });
  });

  group('ModelCapabilities.coerceQuality', () {
    test('不支持时把 xhigh / max 收回 high', () {
      expect(
        ModelCapabilities.coerceQuality(ImageQuality.xhigh, 'gpt-image-2'),
        ImageQuality.high,
      );
      expect(
        ModelCapabilities.coerceQuality(ImageQuality.max, 'gpt-image-1.5'),
        ImageQuality.high,
      );
    });

    test('支持时原样保留', () {
      expect(
        ModelCapabilities.coerceQuality(
          ImageQuality.max,
          'gpt-image-2.5-flare',
        ),
        ImageQuality.max,
      );
      expect(
        ModelCapabilities.coerceQuality(ImageQuality.medium, 'gpt-image-2'),
        ImageQuality.medium,
      );
    });
  });

  group('ModelCapabilities.supportsTransparentBackground', () {
    test('GPT Image 家族支持，DALL·E 不支持，空模型名不支持', () {
      expect(
        ModelCapabilities.supportsTransparentBackground('gpt-image-2'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsTransparentBackground('gpt-image-2.5-flare'),
        isTrue,
      );
      expect(
        ModelCapabilities.supportsTransparentBackground('dall-e-3'),
        isFalse,
      );
      expect(ModelCapabilities.supportsTransparentBackground(''), isFalse);
    });

    test('中转站自定义模型名按支持处理，交给接口报错', () {
      expect(
        ModelCapabilities.supportsTransparentBackground('nano-banana-v2'),
        isTrue,
      );
    });

    test('gpt-image-2 的透明背景标记为预览特性', () {
      expect(
        ModelCapabilities.isTransparentBackgroundPreview('gpt-image-2'),
        isTrue,
      );
      expect(
        ModelCapabilities.isTransparentBackgroundPreview('gpt-image-2.5-flare'),
        isFalse,
      );
    });
  });
}
