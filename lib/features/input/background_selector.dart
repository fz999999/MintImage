import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/model_capabilities.dart';
import '../../shared/theme.dart';
import 'selector_chip_label.dart';

/// 「背景」选项：一键切换自动 / 透明背景。
///
/// 可用性同时受两件事限制：
/// 1. 输出格式必须是 PNG / WEBP（JPEG 没有 alpha 通道，接口会拒）；
/// 2. 模型得支持 `background` 参数（DALL·E 系列不支持）。
/// 任一条件不满足时按钮退化为灰色不可用，点击给出提示。
class BackgroundSelector extends StatelessWidget {
  const BackgroundSelector({
    super.key,
    required this.background,
    required this.outputFormat,
    required this.onSelected,
    this.model = '',
    this.onUnsupported,
  });

  final ImageBackground background;
  final ImageOutputFormat outputFormat;
  final ValueChanged<ImageBackground> onSelected;

  /// 当前使用的模型名，用来判断是否支持透明背景。
  final String model;

  /// 当前格式或模型不支持透明背景时点击的提示回调。
  final VoidCallback? onUnsupported;

  bool get _formatSupported => outputFormat != ImageOutputFormat.jpeg;

  bool get _modelSupported =>
      ModelCapabilities.supportsTransparentBackground(model);

  bool get _supported => _formatSupported && _modelSupported;

  bool get _active => _supported && background.isTransparent;

  /// 不支持时的原因说明，用于 Tooltip。
  String get _unsupportedReason {
    if (!_modelSupported) {
      return '当前模型不支持透明背景';
    }
    return 'JPEG 没有透明通道，请改用 PNG 或 WEBP';
  }

  @override
  Widget build(BuildContext context) {
    final value = _active ? '透明' : '自动';
    final isPreview =
        _supported && ModelCapabilities.isTransparentBackgroundPreview(model);
    return Tooltip(
      message: _supported
          ? '切换背景（透明仅 PNG / WEBP 支持${isPreview ? '，当前模型为预览支持' : ''}）'
          : _unsupportedReason,
      child: GestureDetector(
        onTap: () {
          if (!_supported) {
            onUnsupported?.call();
            return;
          }
          onSelected(
            _active ? ImageBackground.auto : ImageBackground.transparent,
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: _active
                ? AppThemeTokens.primarySoft.withValues(alpha: 0.55)
                : AppThemeTokens.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _active
                  ? AppThemeTokens.primary.withValues(alpha: 0.55)
                  : AppThemeTokens.border.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _active ? Icons.layers_clear_rounded : Icons.layers_outlined,
                size: 13,
                color: _supported
                    ? AppThemeTokens.primaryStrong
                    : AppThemeTokens.textSecondary,
              ),
              const SizedBox(width: 4),
              SelectorChipLabel(prefix: '背景', value: value),
            ],
          ),
        ),
      ),
    );
  }
}
