import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import 'selector_chip_label.dart';
import 'size_picker_modal.dart';

class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.currentWidth,
    required this.currentHeight,
    required this.onSizeSelected,
  });

  final int currentWidth;
  final int currentHeight;
  final void Function(int width, int height) onSizeSelected;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return GestureDetector(
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus(
          disposition: UnfocusDisposition.scope,
        );
        final result = await showSizePickerModal(
          context,
          currentWidth: currentWidth,
          currentHeight: currentHeight,
        );
        if (result != null) {
          onSizeSelected(result.$1, result.$2);
        }
        if (context.mounted) {
          FocusManager.instance.primaryFocus?.unfocus(
            disposition: UnfocusDisposition.scope,
          );
        }
      },
      child: SelectorChipShell(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.aspect_ratio,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            const SizedBox(width: AppSpace.xxs),
            SelectorChipLabel(
              value: currentWidth == 0 ? '自动' : '$currentWidth×$currentHeight',
            ),
          ],
        ),
      ),
    );
  }
}
