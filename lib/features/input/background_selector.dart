import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/desktop/desktop_menu.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/model_capabilities.dart';
import '../../shared/theme.dart';
import 'selector_chip_label.dart';

/// 「背景」选项：点开弹层三选（自动 / 透明 / 不透明）。
///
/// 弹层的样式与「质量」「渠道」保持一致：标题 + ListTile（选中项打勾）。
/// 用弹层而不是一键开关，是因为「自动」到底算不算透明说不清楚：
/// - 自动：不发 background 字段，由模型自己决定（默认，通常实底）；
/// - 透明：背景镂空，需要 PNG / WEBP（JPEG 没有 alpha 通道）；
/// - 不透明：明确要求纯实底背景。
///
/// 注意：所有图标都必须在这里**内联常量**写死。Flutter release 构建会做图标
/// tree-shaking，只保留在 `Icon(常量)` 位置出现过的图标；如果图标从变量/getter
/// 或参数里传进来，运行时就是空白（debug 和测试里看不出来）。
class BackgroundSelector extends StatelessWidget {
  const BackgroundSelector({
    super.key,
    required this.background,
    required this.outputFormat,
    required this.onSelected,
    this.model = '',
  });

  final ImageBackground background;
  final ImageOutputFormat outputFormat;
  final ValueChanged<ImageBackground> onSelected;

  /// 当前使用的模型名，用来判断是否支持透明背景。
  final String model;

  bool get _formatSupported => outputFormat != ImageOutputFormat.jpeg;

  bool get _modelSupported =>
      ModelCapabilities.supportsTransparentBackground(model);

  bool get _transparentSupported => _formatSupported && _modelSupported;

  /// 当前值是否落在「透明」这一档（只有支持时才算生效）。
  bool get _active =>
      background == ImageBackground.transparent && _transparentSupported;

  String get _unsupportedReason {
    if (!_modelSupported) {
      return '当前模型不支持透明背景';
    }
    return 'JPEG 没有透明通道，请改用 PNG 或 WEBP';
  }

  String get _tooltip {
    if (background == ImageBackground.transparent && !_transparentSupported) {
      return _unsupportedReason;
    }
    return '背景：自动由模型决定，透明需要 PNG / WEBP，不透明是纯实底';
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isPreview =
        _transparentSupported &&
        ModelCapabilities.isTransparentBackgroundPreview(model);
    return Tooltip(
      message: isPreview ? '$_tooltip（当前模型为预览支持）' : _tooltip,
      child: SelectorChipTrigger(
        onOpen: _showSheet,
        child: SelectorChipShell(
          active: _active,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 内联常量图标：和尺寸/质量/格式/数量四个按钮完全一致。
              Icon(
                Icons.wallpaper_rounded,
                size: AppIconSize.sm,
                color: AppColors.primaryStrong(b),
              ),
              const SizedBox(width: AppSpace.xxs),
              SelectorChipLabel(label: '背景', value: background.label),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final selected = await showDesktopMenu<ImageBackground>(
        context: context,
        title: '选择背景',
        width: 360,
        anchorRect: selectorChipAnchor(context),
        items: [
          DesktopMenuItem(
            value: ImageBackground.auto,
            label: '自动',
            subtitle: '不指定背景，由模型自己决定（通常是实底）',
            selected: background == ImageBackground.auto,
          ),
          DesktopMenuItem(
            value: ImageBackground.transparent,
            label: '透明',
            enabled: _transparentSupported,
            selected: _active,
            subtitle: _transparentSupported
                ? '背景镂空，只保留主体（需 PNG / WEBP）'
                : '不可用：$_unsupportedReason',
          ),
          DesktopMenuItem(
            value: ImageBackground.opaque,
            label: '不透明',
            subtitle: '明确要求纯实底背景',
            selected: background == ImageBackground.opaque,
          ),
        ],
      );
      if (context.mounted && selected != null && selected != background) {
        onSelected(selected);
      }
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );

    final selected = await showModalBottomSheet<ImageBackground>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final b = Theme.of(ctx).brightness;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '选择背景',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  background == ImageBackground.auto
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: background == ImageBackground.auto
                      ? AppColors.primary(b)
                      : AppColors.textTertiary(b),
                ),
                title: const Text('自动'),
                subtitle: const Text('不指定背景，由模型自己决定（通常是实底）'),
                onTap: () => Navigator.of(ctx).pop(ImageBackground.auto),
              ),
              ListTile(
                enabled: _transparentSupported,
                leading: Icon(
                  _active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: _active
                      ? AppColors.primary(b)
                      : AppColors.textTertiary(b),
                ),
                title: const Text('透明'),
                subtitle: Text(
                  _transparentSupported
                      ? '背景镂空，只保留主体（需 PNG / WEBP）'
                      : '不可用：$_unsupportedReason',
                ),
                onTap: _transparentSupported
                    ? () => Navigator.of(ctx).pop(ImageBackground.transparent)
                    : null,
              ),
              ListTile(
                leading: Icon(
                  background == ImageBackground.opaque
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: background == ImageBackground.opaque
                      ? AppColors.primary(b)
                      : AppColors.textTertiary(b),
                ),
                title: const Text('不透明'),
                subtitle: const Text('明确要求纯实底背景'),
                onTap: () => Navigator.of(ctx).pop(ImageBackground.opaque),
              ),
            ],
          ),
        );
      },
    );

    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
    if (selected != null && selected != background) {
      onSelected(selected);
    }
  }
}
