import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';
import 'image_format_settings_modal.dart';

class ImageFormatSelector extends StatelessWidget {
  const ImageFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.frameCount,
    required this.frameDurationMs,
    required this.onSelected,
    this.svgOptions,
  });

  final ImageOutputFormat selectedFormat;
  final int frameCount;
  final int frameDurationMs;
  final SvgOptions? svgOptions;
  final ValueChanged<ImageFormatSettingsSelection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '图片格式与动画设置',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('format-settings-button'),
          onTap: () => _showSettings(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppThemeTokens.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppThemeTokens.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_rounded,
                  size: 13,
                  color: AppThemeTokens.primaryStrong,
                ),
                const SizedBox(width: 4),
                Text(
                  selectedFormat.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.primaryStrong,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: AppThemeTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    final result = await showImageFormatSettingsModal(
      context,
      format: selectedFormat,
      frameCount: frameCount,
      frameDurationMs: frameDurationMs,
      svgOptions: svgOptions,
    );
    if (result != null) onSelected(result);
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
  }
}
