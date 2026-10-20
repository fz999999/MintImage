import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/model_capabilities.dart';
import '../../shared/theme.dart';
import 'selector_chip_label.dart';

class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.selectedQuality,
    required this.onSelected,
    this.model = '',
  });

  final ImageQuality selectedQuality;
  final ValueChanged<ImageQuality> onSelected;

  /// 当前使用的模型，用来决定是否解锁 xhigh / max 两档。
  final String model;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: SelectorChipShell(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.high_quality_outlined,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            const SizedBox(width: AppSpace.xxs),
            SelectorChipLabel(value: selectedQuality.label),
          ],
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final b = Theme.of(ctx).brightness;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageQuality.values
                .where(
                  (q) =>
                      ModelCapabilities.supportedQualities(model).contains(q),
                )
                .map((q) {
                  final active = q == selectedQuality;
                  return ListTile(
                    leading: Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: active
                          ? AppColors.primary(b)
                          : AppColors.textTertiary(b),
                    ),
                    title: Text(q.label),
                    subtitle: q == ImageQuality.xhigh || q == ImageQuality.max
                        ? const Text('仅 gpt-image-2.5 支持')
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSelected(q);
                    },
                  );
                })
                .toList(),
          ),
        );
      },
    );
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
  }
}
