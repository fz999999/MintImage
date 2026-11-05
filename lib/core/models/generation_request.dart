enum SizePreset {
  auto('auto', '自动', 0, 0),
  square1k('square-1k', '方形成图 1K', 1024, 1024),
  posterPortrait('poster-portrait', '竖版海报', 1024, 1536),
  posterLandscape('poster-landscape', '横版海报', 1536, 1024),
  story916('story-9-16', '竖屏故事 9:16', 1088, 1920),
  video169('video-16-9', '视频封面 16:9', 1920, 1088),
  wide2k('wide-2k', '宽屏展示 2K', 2560, 1440),
  portrait2k('portrait-2k', '高清竖图 2K', 1440, 2560),
  square2k('square-2k', '高清方图 2K', 2048, 2048),
  portrait4k('portrait-4k', '高清竖图 4K', 2160, 3840),
  wide4k('wide-4k', '宽屏展示 4K', 3840, 2160),
  custom('custom', '自定义', 1024, 1024);

  const SizePreset(this.storageKey, this.label, this.width, this.height);

  final String storageKey;
  final String label;
  final int width;
  final int height;

  static SizePreset fromStorageKey(String key) {
    return SizePreset.values.firstWhere(
      (preset) => preset.storageKey == key,
      orElse: () => SizePreset.square1k,
    );
  }
}

enum ImageQuality {
  auto('auto', '自动'),
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  xhigh('xhigh', '超高'),
  max('max', '最高');

  const ImageQuality(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ImageQuality fromApiValue(String value) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.apiValue == value,
      orElse: () => ImageQuality.auto,
    );
  }
}

enum ImageOutputFormat {
  png('png', 'PNG'),
  jpeg('jpeg', 'JPEG'),
  webp('webp', 'WEBP'),
  gif('gif', 'GIF'),
  svg('svg', 'SVG');

  const ImageOutputFormat(this.apiValue, this.label);

  final String apiValue;
  final String label;

  String get fileExtension => apiValue;

  bool get requiresImagesGeneration =>
      this == ImageOutputFormat.gif || this == ImageOutputFormat.svg;

  static ImageOutputFormat fromApiValue(String value) {
    return ImageOutputFormat.values.firstWhere(
      (format) => format.apiValue == value,
      orElse: () => ImageOutputFormat.png,
    );
  }
}

enum ImageComplexity {
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高');

  const ImageComplexity(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ImageComplexity? fromApiValue(String? value) {
    for (final complexity in values) {
      if (complexity.apiValue == value) return complexity;
    }
    return null;
  }
}

class GenerationRequest {
  const GenerationRequest({
    required this.prompt,
    required this.imagePaths,
    required this.sizePreset,
    required this.customWidth,
    required this.customHeight,
    required this.quality,
    this.outputFormat = ImageOutputFormat.png,
    this.frameCount = 9,
    this.frameDurationMs = 200,
    this.complexity,
    required this.count,
    required this.apiProfileId,
  });

  final String prompt;
  final List<String> imagePaths;
  final SizePreset sizePreset;
  final int customWidth;
  final int customHeight;
  final ImageQuality quality;
  final ImageOutputFormat outputFormat;
  final int frameCount;
  final int frameDurationMs;
  final ImageComplexity? complexity;
  final int count;
  final String apiProfileId;

  bool get hasAttachments => imagePaths.isNotEmpty;

  bool get isAutoSize => sizePreset == SizePreset.auto;

  int get resolvedWidth =>
      sizePreset == SizePreset.custom ? customWidth : sizePreset.width;

  int get resolvedHeight =>
      sizePreset == SizePreset.custom ? customHeight : sizePreset.height;

  String? get apiSize => isAutoSize ? null : '${resolvedWidth}x$resolvedHeight';

  /// Validate before submitting a paid request, including from the CLI.
  String? validate({required bool usesResponsesApi}) {
    if (usesResponsesApi && complexity != null) {
      return '规划复杂度需要使用 Images API，请切换 API 协议。';
    }
    if (imagePaths.any((path) => path.toLowerCase().endsWith('.svg'))) {
      return 'SVG 不支持作为图生图参考图，请先导出为 PNG。';
    }
    if (!outputFormat.requiresImagesGeneration) return null;
    if (hasAttachments) {
      return '${outputFormat.label} 仅支持文生图，请移除参考图或选择 PNG/JPEG/WEBP。';
    }
    if (usesResponsesApi) {
      return '${outputFormat.label} 需要使用 Images API，请切换 API 协议。';
    }
    if (outputFormat == ImageOutputFormat.gif) {
      if (frameCount < 2 || frameCount > 64) {
        return 'GIF 帧数必须在 2–64 之间。';
      }
      if (frameDurationMs < 20 || frameDurationMs > 2000) {
        return 'GIF 每帧时长必须在 20–2000 毫秒之间。';
      }
      if (!isAutoSize &&
          (resolvedWidth <= 0 ||
              resolvedHeight <= 0 ||
              resolvedWidth % 16 != 0 ||
              resolvedHeight % 16 != 0)) {
        return 'GIF 每帧宽高必须为 16 的正整数倍，或选择自动尺寸。';
      }
    }
    return null;
  }

  GenerationRequest copyWith({
    String? prompt,
    List<String>? imagePaths,
    SizePreset? sizePreset,
    int? customWidth,
    int? customHeight,
    ImageQuality? quality,
    ImageOutputFormat? outputFormat,
    int? frameCount,
    int? frameDurationMs,
    ImageComplexity? complexity,
    int? count,
    String? apiProfileId,
  }) {
    return GenerationRequest(
      prompt: prompt ?? this.prompt,
      imagePaths: imagePaths ?? this.imagePaths,
      sizePreset: sizePreset ?? this.sizePreset,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      quality: quality ?? this.quality,
      outputFormat: outputFormat ?? this.outputFormat,
      frameCount: frameCount ?? this.frameCount,
      frameDurationMs: frameDurationMs ?? this.frameDurationMs,
      complexity: complexity ?? this.complexity,
      count: count ?? this.count,
      apiProfileId: apiProfileId ?? this.apiProfileId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'imagePaths': imagePaths,
      'sizePreset': sizePreset.storageKey,
      'customWidth': customWidth,
      'customHeight': customHeight,
      'quality': quality.apiValue,
      'outputFormat': outputFormat.apiValue,
      'frameCount': frameCount,
      'frameDurationMs': frameDurationMs,
      if (complexity != null) 'complexity': complexity!.apiValue,
      'count': count,
      'apiProfileId': apiProfileId,
    };
  }

  factory GenerationRequest.fromJson(Map<String, dynamic> json) {
    return GenerationRequest(
      prompt: json['prompt'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item as String)
          .toList(),
      sizePreset: SizePreset.fromStorageKey(
        json['sizePreset'] as String? ?? SizePreset.square1k.storageKey,
      ),
      customWidth: json['customWidth'] as int? ?? 1024,
      customHeight: json['customHeight'] as int? ?? 1024,
      quality: ImageQuality.fromApiValue(
        json['quality'] as String? ?? ImageQuality.auto.apiValue,
      ),
      outputFormat: ImageOutputFormat.fromApiValue(
        json['outputFormat'] as String? ?? ImageOutputFormat.png.apiValue,
      ),
      frameCount: json['frameCount'] as int? ?? 9,
      frameDurationMs: json['frameDurationMs'] as int? ?? 200,
      complexity: ImageComplexity.fromApiValue(json['complexity'] as String?),
      count: json['count'] as int? ?? 1,
      apiProfileId: json['apiProfileId'] as String? ?? '',
    );
  }
}
