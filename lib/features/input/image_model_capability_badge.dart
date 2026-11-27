import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// A quiet, consistent model requirement marker for advanced image settings.
class ImageModelCapabilityBadge extends StatelessWidget {
  const ImageModelCapabilityBadge({
    super.key,
    required this.feature,
    this.details,
  });

  final String feature;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final message =
        '$feature 需 GPT Image 2.6 或兼容模型支持。'
        '${details == null ? '' : '\n$details'}'
        '\n实际可用能力以当前 API 服务商为准。';
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeTokens.textPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.5,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppThemeTokens.border.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text(
          '2.6',
          style: TextStyle(
            fontSize: 10,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: AppThemeTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
