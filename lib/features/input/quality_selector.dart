import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';
import 'quality_settings_modal.dart';

class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.selectedQuality,
    required this.selectedComplexity,
    required this.showComplexity,
    required this.onSelected,
  });

  final ImageQuality selectedQuality;
  final ImageComplexity? selectedComplexity;
  final bool showComplexity;
  final ValueChanged<QualitySettingsSelection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '质量与生成设置',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('quality-settings-button'),
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
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: AppThemeTokens.primaryStrong,
                ),
                const SizedBox(width: 4),
                Text(
                  selectedQuality.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.primaryStrong,
                  ),
                ),
                if (showComplexity && selectedComplexity != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· 规划${selectedComplexity!.label}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ],
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
    final result = await showQualitySettingsModal(
      context,
      quality: selectedQuality,
      complexity: selectedComplexity,
      showComplexity: showComplexity,
    );
    if (result != null) onSelected(result);
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
  }
}
