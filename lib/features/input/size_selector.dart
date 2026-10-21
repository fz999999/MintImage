import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/desktop/desktop_menu.dart';

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

    return SelectorChipTrigger(
      onOpen: (context) async {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          final entries = <(int, int), String>{(0, 0): '自动'};
          if (currentWidth > 0 && currentHeight > 0) {
            entries[(currentWidth, currentHeight)] =
                '当前 $currentWidth×$currentHeight';
          }
          for (final entry in const [
            ((1024, 1024), '1:1 · 1K'),
            ((1536, 1024), '3:2 · 1K'),
            ((1024, 1536), '2:3 · 1K'),
            ((1920, 1088), '16:9 · 1K'),
            ((1088, 1920), '9:16 · 1K'),
          ]) {
            entries.putIfAbsent(entry.$1, () => entry.$2);
          }
          final picked = await showDesktopMenu<(int, int)>(
            context: context,
            title: '图像尺寸',
            anchorRect: selectorChipAnchor(context),
            items: [
              for (final entry in entries.entries)
                DesktopMenuItem(
                  value: entry.key,
                  label: entry.value,
                  selected: entry.key == (currentWidth, currentHeight),
                ),
              const DesktopMenuItem(value: (-1, -1), label: '更多尺寸…'),
            ],
          );
          if (!context.mounted || picked == null) return;
          if (picked != (-1, -1)) {
            onSizeSelected(picked.$1, picked.$2);
            return;
          }
          final result = await showSizePickerModal(
            context,
            currentWidth: currentWidth,
            currentHeight: currentHeight,
          );
          if (context.mounted && result != null) {
            onSizeSelected(result.$1, result.$2);
          }
          return;
        }
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
              label: '尺寸',
              value: currentWidth == 0 ? '自动' : '$currentWidth×$currentHeight',
            ),
          ],
        ),
      ),
    );
  }
}
