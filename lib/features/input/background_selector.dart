import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/model_capabilities.dart';
import '../../shared/theme.dart';
import 'selector_chip_label.dart';

/// 「背景」选项：点开弹出三选（自动 / 透明 / 不透明）。
///
/// 用弹层而不是一键开关，是因为「自动」到底算透明还是不透明说不清楚：
/// - 自动：不发 background 字段，由模型自己决定；
/// - 透明：背景镂空，需要 PNG / WEBP（JPEG 没有 alpha 通道）；
/// - 不透明：明确要求实底背景。
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

  IconData get _icon {
    if (!_transparentSupported) {
      return Icons.grid_on;
    }
    return switch (background) {
      ImageBackground.transparent => Icons.grid_on,
      ImageBackground.opaque => Icons.crop_square,
      ImageBackground.auto => Icons.auto_awesome_outlined,
    };
  }

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
    final isPreview =
        _transparentSupported &&
        ModelCapabilities.isTransparentBackgroundPreview(model);
    return Tooltip(
      message: isPreview ? '$_tooltip（当前模型为预览支持）' : _tooltip,
      child: GestureDetector(
        onTap: () => _showSheet(context),
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
                _icon,
                size: 13,
                color: _transparentSupported
                    ? AppThemeTokens.primaryStrong
                    : AppThemeTokens.textSecondary,
              ),
              const SizedBox(width: 4),
              SelectorChipLabel(prefix: '背景', value: background.label),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<ImageBackground>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '背景',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppThemeTokens.textPrimary,
                ),
              ),
            ),
            _BackgroundTile(
              icon: Icons.auto_awesome_outlined,
              title: '自动',
              subtitle: '不指定背景，由模型自己决定（默认，通常是实底）',
              selected: background == ImageBackground.auto,
              onTap: () => Navigator.of(sheetContext).pop(ImageBackground.auto),
            ),
            _BackgroundTile(
              icon: Icons.grid_on,
              title: '透明',
              subtitle: _transparentSupported
                  ? '背景镂空，只保留主体（PNG / WEBP）'
                  : '不可用：$_unsupportedReason',
              selected: _active,
              onTap: _transparentSupported
                  ? () => Navigator.of(
                      sheetContext,
                    ).pop(ImageBackground.transparent)
                  : null,
            ),
            _BackgroundTile(
              icon: Icons.crop_square,
              title: '不透明',
              subtitle: '明确要求纯实底背景',
              selected: background == ImageBackground.opaque,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageBackground.opaque),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != background) {
      onSelected(selected);
    }
  }
}

class _BackgroundTile extends StatelessWidget {
  const _BackgroundTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? AppThemeTokens.textPrimary
        : AppThemeTokens.textSecondary;
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: enabled ? AppThemeTokens.primaryStrong : color,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppThemeTokens.textSecondary,
        ),
      ),
      trailing: selected
          ? const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppThemeTokens.primaryStrong,
            )
          : null,
    );
  }
}
